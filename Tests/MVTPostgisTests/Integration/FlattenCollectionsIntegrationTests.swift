import Foundation
import GISTools
@testable import MVTPostgis
import MVTTools
import Testing

@Suite(.serialized, .enabled(if: IntegrationEnvironment.isAvailable))
struct FlattenCollectionsIntegrationTests {

    private static let tile = MapTile(x: 8715, y: 5688, z: 14)

    private static let names = [
        "collection_homogeneous",
        "collection_mixed",
        "collection_nested",
        "collection_empty",
    ]

    private func layers(_ fixture: IntegrationFixture) -> [PostgisLayer] {
        Self.names.map { name in
            fixture.layer(
                id: name,
                table: "geometry_edge_cases",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT * FROM "\(fixture.schema)".geometry_edge_cases WHERE name = '\(name)') AS data
                """)
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func flattensCollectionsInMemoryAndInTiles() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let configuration = MVTPostgisConfiguration(
                clipping: { _, _ in .none },
                flattenGeometryCollections: true)

            let postgis = try MVTPostgis(
                source: fixture.source(layers: layers(fixture)),
                configuration: configuration)
            do {
                let result = try await postgis.vectorTile(forTile: Self.tile)

                let homogeneous = result.tile.features(for: "collection_homogeneous")
                #expect(homogeneous.count == 2)
                #expect(homogeneous.allSatisfy { $0.geometry is Point })
                #expect(homogeneous.allSatisfy { ($0.properties["name"] as? String) == "collection_homogeneous" })
                #expect(homogeneous.first?.id == .int(8))
                let restIds = homogeneous.dropFirst().compactMap(\.id)
                #expect(restIds.count == homogeneous.count - 1)
                #expect(Set(restIds).count == restIds.count)
                #expect(restIds.allSatisfy { $0 != .int(8) })

                let mixed = result.tile.features(for: "collection_mixed")
                #expect(mixed.count == 2)
                #expect(mixed.contains { $0.geometry is Point })
                #expect(mixed.contains { $0.geometry is LineString })

                let nested = result.tile.features(for: "collection_nested")
                #expect(nested.count == 2)
                #expect(nested.contains { $0.geometry is Point })
                #expect(nested.contains { $0.geometry is LineString })

                #expect(result.tile.features(for: "collection_empty").isEmpty)

                let mvt = try await postgis.data(
                    forTile: Self.tile,
                    format: .mvt,
                    options: VectorTile.ExportOptions())
                let mlt = try await postgis.data(
                    forTile: Self.tile,
                    format: .mlt,
                    options: VectorTile.ExportOptions())

                let mvtTile = try VectorTile(mvtData: #require(mvt.data), tile: Self.tile)
                let mltTile = try VectorTile(mltData: #require(mlt.data), tile: Self.tile)

                for tile in [mvtTile, mltTile] {
                    #expect(tile.features(for: "collection_homogeneous").count == 2)
                    #expect(tile.features(for: "collection_mixed").count == 2)
                    #expect(tile.features(for: "collection_nested").count == 2)
                    #expect(tile.features(for: "collection_empty").isEmpty)
                }

                await postgis.shutdown()
            }
            catch {
                await postgis.shutdown()
                throw error
            }
        }
    }

}
