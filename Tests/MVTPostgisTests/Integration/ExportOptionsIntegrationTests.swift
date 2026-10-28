import Foundation
import GISTools
@testable import MVTPostgis
import MVTTools
import Testing

@Suite(.serialized, .enabled(if: IntegrationEnvironment.isAvailable))
struct ExportOptionsIntegrationTests {

    private static let tile = MapTile(x: 8715, y: 5688, z: 14)

    private static let geometryNames = [
        "point",
        "multipoint",
        "linestring",
        "multilinestring",
        "polygon",
        "polygon_hole",
        "multipolygon",
        "triangle",
    ]

    private func configuration(trackRuntimes: Bool = false) -> MVTPostgisConfiguration {
        MVTPostgisConfiguration(
            clipping: { _, _ in .none },
            trackRuntimes: trackRuntimes)
    }

    private func withPostgis<T>(
        _ source: PostgisSource,
        configuration: MVTPostgisConfiguration,
        _ body: (MVTPostgis) async throws -> T,
    ) async throws -> T {
        let postgis = try MVTPostgis(source: source, configuration: configuration)
        do {
            let result = try await body(postgis)
            await postgis.shutdown()
            return result
        }
        catch {
            await postgis.shutdown()
            throw error
        }
    }

    private func geometryLayer(_ fixture: IntegrationFixture, name: String) -> PostgisLayer {
        fixture.layer(
            id: name,
            table: "geometry_edge_cases",
            fields: ["id": "", "name": "", "kind": "", "geom": ""],
            srid: .epsg4326,
            sql: """
            (SELECT * FROM "\(fixture.schema)".geometry_edge_cases WHERE name = '\(name)') AS data
            """)
    }

    @Test(.timeLimit(.minutes(2)))
    func roundTripsAllSupportedGeometries() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layers = Self.geometryNames.map { geometryLayer(fixture, name: $0) }

            try await withPostgis(
                fixture.source(layers: layers),
                configuration: configuration())
            { postgis in
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
                    #expect(tile.features(for: "point").first?.geometry is Point)
                    #expect(tile.features(for: "multipoint").first?.geometry is MultiPoint)
                    #expect(tile.features(for: "linestring").first?.geometry is LineString)
                    #expect(tile.features(for: "multilinestring").first?.geometry is MultiLineString)
                    #expect(tile.features(for: "polygon").first?.geometry is Polygon)
                    #expect((tile.features(for: "polygon_hole").first?.geometry as? Polygon)?.coordinates.count == 2)
                    #expect((tile.features(for: "multipolygon").first?.geometry as? MultiPolygon)?.polygons.count == 2)
                    #expect(tile.features(for: "triangle").first?.geometry is Polygon)
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func bufferOptionsKeepFeaturesOutsideTheTile() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "buffer",
                table: "clip_edge_features",
                fields: ["id": "", "name": "", "geom": ""],
                srid: .epsg4326,
                properties: PostgisLayer.Properties(bufferSize: 8),
                sql: "(SELECT * FROM \"\(fixture.schema)\".clip_edge_features WHERE geom && !bbox!) AS data")

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let options: [VectorTile.ExportOptions] = [
                    VectorTile.ExportOptions(bufferSize: .no),
                    VectorTile.ExportOptions(bufferSize: .extent(64)),
                    VectorTile.ExportOptions(bufferSize: .pixel(64)),
                    VectorTile.ExportOptions(bufferSize: .extent(1024)),
                ]

                for option in options {
                    let data = try await postgis.data(
                        forTile: MapTile(x: 0, y: 0, z: 1),
                        format: .mvt,
                        options: option)
                    let tile = try VectorTile(
                        mvtData: #require(data.data),
                        tile: Self.tile)
                    let names = Set(tile.features(for: "buffer").compactMap {
                        $0.properties["name"] as? String
                    })

                    if case .no = option.bufferSize {
                        #expect(names.contains("just_outside") == false)
                    }
                    else {
                        #expect(names.contains("just_outside"))
                    }
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func compressionLevelsDecode() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = geometryLayer(fixture, name: "polygon_hole")

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let options: [VectorTile.ExportOptions.CompressionOptions] = [
                    .no,
                    .default,
                    .level(0),
                    .level(1),
                    .level(5),
                    .level(9),
                ]

                for compression in options {
                    let data = try await postgis.data(
                        forTile: Self.tile,
                        format: .mvt,
                        options: VectorTile.ExportOptions(compression: compression))
                    let tile = try VectorTile(
                        mvtData: #require(data.data),
                        tile: Self.tile)

                    #expect(tile.features(for: "polygon_hole").count == 1)
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func simplificationOptionsReduceVertices() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "simplify",
                table: "simplify_features",
                fields: ["id": "", "name": "", "geom": ""],
                srid: .epsg4326,
                sql: "(SELECT * FROM \"\(fixture.schema)\".simplify_features) AS data")

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let options: [(String, VectorTile.ExportOptions)] = [
                    ("none", VectorTile.ExportOptions(simplifyFeatures: .no)),
                    ("extent", VectorTile.ExportOptions(simplifyFeatures: .extent(64))),
                    ("meters", VectorTile.ExportOptions(simplifyFeatures: .meters(10000))),
                ]

                var counts: [String: Int] = [:]
                let simplificationTile = MapTile(x: 1, y: 0, z: 1)
                for (label, option) in options {
                    let data = try await postgis.data(
                        forTile: simplificationTile,
                        format: .mvt,
                        options: option)
                    let tile = try VectorTile(
                        mvtData: #require(data.data),
                        tile: simplificationTile)
                    let line = try #require(tile.features(for: "simplify").first?.geometry as? LineString)
                    counts[label] = line.coordinates.count
                }

                let noCount = try #require(counts["none"])
                let extentCount = try #require(counts["extent"])
                let meterCount = try #require(counts["meters"])
                #expect(extentCount < noCount)
                #expect(meterCount < noCount)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func idsAndPropertiesSurviveBothFormats() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "properties",
                table: "features",
                fields: [
                    "id": "",
                    "name": "",
                    "kind": "",
                    "answer": "",
                    "flag": "",
                    "geom": "",
                ],
                srid: .epsg4326,
                sql: """
                (SELECT id, name, kind, 42::int8 AS answer, true AS flag, geom
                 FROM "\(fixture.schema)".features WHERE id = 1) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let mvt = try await postgis.data(
                    forTile: Self.tile,
                    format: .mvt,
                    options: VectorTile.ExportOptions())
                let mlt = try await postgis.data(
                    forTile: Self.tile,
                    format: .mlt,
                    options: VectorTile.ExportOptions())

                for data in try [#require(mvt.data), #require(mlt.data)] {
                    let tile = data == mvt.data
                        ? try VectorTile(mvtData: data, tile: Self.tile)
                        : try VectorTile(mltData: data, tile: Self.tile)
                    let feature = try #require(tile.features(for: "properties").first)

                    #expect(feature.id == .int(1) || feature.id == .uint(1))
                    #expect(feature.properties["name"] as? String == "point")
                    #expect(feature.properties["kind"] as? String == "point")
                    let answer = feature.properties["answer"] as? Int
                        ?? (feature.properties["answer"] as? Int64).map(Int.init)
                    #expect(answer == 42)
                    #expect(feature.properties["flag"] as? Bool == true)
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func emptyAndDeterministicOutput() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let empty = fixture.layer(
                id: "empty",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: "(SELECT * FROM \"\(fixture.schema)\".features WHERE false) AS data")

            try await withPostgis(
                fixture.source(layers: [empty]),
                configuration: configuration())
            { postgis in
                let first = try await postgis.data(
                    forTile: Self.tile,
                    format: .mvt,
                    options: VectorTile.ExportOptions())
                let second = try await postgis.data(
                    forTile: Self.tile,
                    format: .mvt,
                    options: VectorTile.ExportOptions())

                // Empty layers may encode to nil or to a valid, empty tile.
                if let data = first.data {
                    let tile = try VectorTile(mvtData: data, tile: Self.tile)
                    #expect(tile.features(for: "empty").isEmpty)
                }
                #expect(first.data == second.data)
            }
        }
    }

}
