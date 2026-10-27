import Foundation
import GISTools
@testable import MVTPostgis
import Testing

struct MVTPostgisInitializationTests {

    private func datasource(
        srid: Projection = .epsg4326,
        type: String = "postgis",
    ) -> PostgisDatasource {
        PostgisDatasource(
            user: "u",
            host: "h",
            databaseName: "db",
            srid: srid,
            type: type,
            sql: "(SELECT * FROM t WHERE geometry && !bbox!) AS data")
    }

    private func source(
        id: String = "layer",
        srid: Projection = .epsg4326,
        type: String = "postgis",
    ) -> PostgisSource {
        PostgisSource(
            name: "Source",
            layers: [
                PostgisLayer(
                    id: id,
                    datasource: datasource(srid: srid, type: type)),
            ])
    }

    @Test
    func `rejects empty source`() {
        let source = PostgisSource(name: "Empty", layers: [])
        #expect(throws: MVTPostgisError.needLayers) {
            try MVTPostgis(source: source)
        }
    }

    @Test
    func `rejects empty layer id`() {
        let source = source(id: "")
        #expect(throws: MVTPostgisError.invalidLayerId) {
            try MVTPostgis(source: source)
        }
    }

    @Test
    func `rejects non postgis datasource`() {
        let source = source(type: "mysql")
        #expect(throws: MVTPostgisError.wrongDatasourceType(message: "All datasources must be of type 'postgis'")) {
            try MVTPostgis(source: source)
        }
    }

    @Test
    func `rejects unsupported projection`() {
        let source = source(srid: .epsg4978)
        #expect(throws: MVTPostgisError.unsupportedSRID) {
            try MVTPostgis(source: source)
        }
    }

    @Test
    func `accepts mixed supported layer projections`() throws {
        let source = PostgisSource(
            name: "Mixed",
            layers: [
                PostgisLayer(id: "first", datasource: datasource(srid: .epsg4326)),
                PostgisLayer(id: "second", datasource: datasource(srid: .epsg3857)),
            ])

        let postgis = try MVTPostgis(source: source)
        #expect(postgis.projection == .epsg4326)
        #expect(postgis.minZoom == 0)
        #expect(postgis.maxZoom == 20)
    }

    @Test
    func `public initializers preserve values`() {
        let properties = PostgisLayer.Properties(bufferSize: -5)
        #expect(properties.bufferSize == 0)

        let datasource = PostgisDatasource(
            user: "reader",
            password: "secret",
            host: "localhost",
            port: 5433,
            databaseName: "gis",
            geometryField: "way",
            boundingBox: BoundingBox(
                southWest: Coordinate3D(latitude: 0, longitude: 0),
                northEast: Coordinate3D(latitude: 1, longitude: 1)),
            srid: .epsg3857,
            type: "postgis",
            sql: "(SELECT * FROM t) AS data")
        let layer = PostgisLayer(
            id: "roads",
            description: "Roads",
            fields: ["name": "Name"],
            properties: properties,
            datasource: datasource)

        #expect(layer.id == "roads")
        #expect(layer.description == "Roads")
        #expect(layer.fields == ["name": "Name"])
        #expect(layer.properties.bufferSize == 0)
        #expect(layer.datasource.port == 5433)
        #expect(layer.datasource.geometryField == "way")
    }

}
