import Foundation
import GISTools
@testable import MVTPostgis
import Testing

struct PostgisQueryBuilderTests {

    private func layer(
        id: String = "layer",
        fields: [String: String] = ["name": "", "geometry": ""],
        geometryField: String? = "geometry",
        sql: String = "(SELECT name, geometry FROM places WHERE geometry && !bbox!) AS places",
    ) -> PostgisLayer {
        PostgisLayer(
            id: id,
            fields: fields,
            datasource: PostgisDatasource(
                user: "user",
                host: "host",
                databaseName: "database",
                geometryField: geometryField,
                srid: .epsg3857,
                type: "postgis",
                sql: sql))
    }

    @Test
    func defaultClippingUsesOneClipCallAndExcludesGeometryField() {
        let builder = PostgisQueryBuilder(
            layer: layer(fields: [
                "name": "",
                "geometry": "",
                "weird\"column": "",
                "": "",
            ]),
            envelope: "ENVELOPE",
            simplificationTolerance: 2.5,
            clipping: .postgis,
            simplification: .none,
            validation: .none)

        #expect(builder.query == """
        SELECT "name","weird""column",ST_AsBinary(ST_ClipByBox2D(ST_Force2D("geometry"::geometry),ENVELOPE)) AS "geometry",ST_SRID("geometry") AS "__mvt_postgis_srid" FROM (SELECT name, geometry FROM places WHERE geometry && !bbox!) AS places
        """)
    }

    @Test
    func localClippingAndSimplificationStayInSwift() {
        let builder = PostgisQueryBuilder(
            layer: layer(),
            envelope: "ENVELOPE",
            simplificationTolerance: 2.5,
            clipping: .local,
            simplification: .local,
            validation: .none)

        #expect(builder.usesLocalSimplification)
        #expect(builder.query == """
        SELECT "name",ST_AsBinary(ST_Force2D("geometry"::geometry)) AS "geometry",ST_SRID("geometry") AS "__mvt_postgis_srid" FROM (SELECT name, geometry FROM places WHERE geometry && !bbox!) AS places
        """)
    }

    @Test
    func postgisSimplificationIncludesPreserveCollapsed() {
        let builder = PostgisQueryBuilder(
            layer: layer(),
            envelope: "ENVELOPE",
            simplificationTolerance: 2.5,
            clipping: .none,
            simplification: .postgis(preserveCollapsed: true),
            validation: .none)

        #expect(builder.query.contains("ST_AsBinary(ST_Simplify(ST_Force2D(\"geometry\"::geometry),2.5,true)) AS \"geometry\""))
    }

    @Test
    func meterSimplificationUsesItsOwnTolerance() {
        let builder = PostgisQueryBuilder(
            layer: layer(),
            envelope: "ENVELOPE",
            simplificationTolerance: 2.5,
            clipping: .none,
            simplification: .meters(10.0, preserveCollapsed: false),
            validation: .none)

        #expect(builder.query.contains("ST_AsBinary(ST_Simplify(ST_Force2D(\"geometry\"::geometry),10.0)) AS \"geometry\""))
    }

    @Test
    func structureValidationUsesPostgisArguments() {
        let builder = PostgisQueryBuilder(
            layer: layer(),
            envelope: "ENVELOPE",
            simplificationTolerance: 2.5,
            clipping: .none,
            simplification: .none,
            validation: .structure(keepCollapsed: false))

        #expect(builder.query.contains("ST_AsBinary(ST_MakeValid(ST_Force2D(\"geometry\"::geometry), 'method=structure keepcollapsed=false')) AS \"geometry\""))
    }

    @Test
    func allPostgisOptionsNestCorrectly() {
        let builder = PostgisQueryBuilder(
            layer: layer(),
            sql: "(SELECT geometry FROM places WHERE geometry && !bbox!) AS places",
            envelope: "ENVELOPE",
            simplificationTolerance: 2.5,
            clipping: .postgis,
            simplification: .postgis(preserveCollapsed: true),
            validation: .structure(keepCollapsed: false))

        #expect(builder.query.contains("ST_AsBinary(ST_MakeValid(ST_Simplify(ST_ClipByBox2D(ST_Force2D(\"geometry\"::geometry),ENVELOPE),2.5,true), 'method=structure keepcollapsed=false')) AS \"geometry\""))
    }

    @Test
    func emptyFieldsSelectOnlyGeometry() {
        let builder = PostgisQueryBuilder(
            layer: layer(fields: [:]),
            envelope: "ENVELOPE",
            simplificationTolerance: 2.5,
            clipping: .none,
            simplification: .none,
            validation: .none)

        #expect(builder.query == """
        SELECT ST_AsBinary(ST_Force2D("geometry"::geometry)) AS "geometry",ST_SRID("geometry") AS "__mvt_postgis_srid" FROM (SELECT name, geometry FROM places WHERE geometry && !bbox!) AS places
        """)
    }

    @Test
    func stripsTrailingSemicolonsFromSQL() {
        let builder = PostgisQueryBuilder(
            layer: layer(sql: "(SELECT name, geometry FROM places WHERE geometry && !bbox!) AS places;"),
            envelope: "ENVELOPE",
            simplificationTolerance: 2.5,
            clipping: .none,
            simplification: .none,
            validation: .none)

        #expect(builder.sql == "(SELECT name, geometry FROM places WHERE geometry && !bbox!) AS places")
        #expect(builder.query.hasSuffix(";") == false)
    }

    @Test
    func identifierQuotingEscapesEmbeddedQuotes() {
        #expect(PostgisQueryBuilder.quotedIdentifier("geometry") == "\"geometry\"")
        #expect(PostgisQueryBuilder.quotedIdentifier(#"a"b"#) == #""a""b""#)
    }

    @Test
    func geometryExpressionForcesTwoDimensionsAndCastsToGeometry() {
        let builder = PostgisQueryBuilder(
            layer: layer(
                fields: ["name": "", "shape": ""],
                geometryField: "shape",
                sql: "(SELECT name, shape FROM places WHERE shape && !bbox!) AS places"),
            envelope: "ENVELOPE",
            simplificationTolerance: 2.5,
            clipping: .none,
            simplification: .none,
            validation: .none)

        #expect(builder.query.contains("ST_AsBinary(ST_Force2D(\"shape\"::geometry)) AS \"shape\""))
        #expect(builder.query.contains("ST_SRID(\"shape\") AS \"__mvt_postgis_srid\""))
    }

    @Test
    func simplificationConvertsMetersForGeographicLayers() {
        let geographicLayer = PostgisLayer(
            id: "layer",
            fields: [:],
            datasource: PostgisDatasource(
                user: "user",
                host: "host",
                databaseName: "database",
                srid: .epsg4326,
                type: "postgis",
                sql: "(SELECT geometry FROM places WHERE geometry && !bbox!) AS places"))

        let postgisBuilder = PostgisQueryBuilder(
            layer: geographicLayer,
            envelope: "ENVELOPE",
            simplificationTolerance: GISTool.earthCircumference / 360.0,
            clipping: .none,
            simplification: .postgis(preserveCollapsed: false),
            validation: .none)
        #expect(postgisBuilder.query.contains("ST_AsBinary(ST_Simplify(ST_Force2D(\"geometry\"::geometry),1.0)) AS \"geometry\""))

        let meterBuilder = PostgisQueryBuilder(
            layer: geographicLayer,
            envelope: "ENVELOPE",
            simplificationTolerance: 10.0,
            clipping: .none,
            simplification: .meters(GISTool.earthCircumference / 360.0, preserveCollapsed: false),
            validation: .none)
        #expect(meterBuilder.query.contains("ST_AsBinary(ST_Simplify(ST_Force2D(\"geometry\"::geometry),1.0)) AS \"geometry\""))
    }

}
