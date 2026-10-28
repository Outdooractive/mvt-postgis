import Foundation
import GISTools
@testable import MVTPostgis
import MVTTools
import Testing

@Suite(.serialized, .enabled(if: IntegrationEnvironment.isAvailable))
struct DifferentialIntegrationTests {

    private static let tile = MapTile(x: 8715, y: 5688, z: 14)

    @Test(.timeLimit(.minutes(2)))
    func featureContentMatchesPostgisStAsMvt() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let bounds = Self.tile.boundingBox(projection: .epsg4326)
            let envelope = """
            ST_MakeEnvelope(\(bounds.southWest.longitude), \(bounds.southWest.latitude), \(bounds.northEast.longitude), \(bounds.northEast.latitude), 4326)
            """

            let referenceMVT = try #require(
                try await fixture.database.queryData("""
                SELECT ST_AsMVT(q, 'diff') AS value
                FROM (
                    SELECT id, name, kind,
                           ST_AsMVTGeom(
                               ST_Force2D(geom),
                               \(envelope),
                               4096,
                               0,
                               true) AS geom
                    FROM "\(fixture.schema)".features
                    WHERE id <= 3 AND geom && \(envelope)
                ) AS q
                """),
            )

            let referenceTile = try VectorTile(
                mvtData: referenceMVT,
                tile: Self.tile)

            let layer = fixture.layer(
                id: "diff",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT * FROM "\(fixture.schema)".features
                 WHERE id <= 3 AND geom && !bbox!) AS data
                """)

            let postgis = try MVTPostgis(
                source: fixture.source(layers: [layer]),
                configuration: MVTPostgisConfiguration(clipping: { _, _ in .none }))
            do {
                let generated = try await postgis.data(
                    forTile: Self.tile,
                    format: .mvt,
                    options: VectorTile.ExportOptions())
                let generatedTile = try VectorTile(
                    mvtData: #require(generated.data),
                    tile: Self.tile)

                let referenceFeatures = referenceTile.features(for: "diff")
                let generatedFeatures = generatedTile.features(for: "diff")

                #expect(generatedFeatures.count == referenceFeatures.count)

                let referenceNames = Set(referenceFeatures.compactMap {
                    $0.properties["name"] as? String
                })
                let generatedNames = Set(generatedFeatures.compactMap {
                    $0.properties["name"] as? String
                })
                #expect(generatedNames == referenceNames)

                await postgis.shutdown()
            }
            catch {
                await postgis.shutdown()
                throw error
            }
        }
    }

}
