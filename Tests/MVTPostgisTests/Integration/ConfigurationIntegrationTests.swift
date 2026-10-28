import Foundation
import GISTools
@testable import MVTPostgis
import MVTTools
import PostgresNIO
import Testing

@Suite(.serialized, .enabled(if: IntegrationEnvironment.isAvailable))
struct ConfigurationIntegrationTests {

    private static let tile = MapTile(x: 8715, y: 5688, z: 14)

    private func configuration(
        clipping: @escaping @Sendable (Int, PostgisSource) -> MVTClippingOption = { _, _ in .none },
        simplification: @escaping @Sendable (Int, PostgisSource) -> MVTSimplificationOption = { _, _ in .none },
        validation: @escaping @Sendable (Int, PostgisSource) -> MVTMakeValidOption = { _, _ in .none },
        trackRuntimes: Bool = false,
        featureMapping: (@Sendable (Feature) -> Feature)? = nil,
    ) -> MVTPostgisConfiguration {
        MVTPostgisConfiguration(
            clipping: clipping,
            simplification: simplification,
            validation: validation,
            featureMapping: featureMapping,
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

    @Test(.timeLimit(.minutes(2)))
    func runsRepresentativeStrategyCombinations() async throws {
        try await IntegrationFixture.withFixture { fixture in
            func layer(
                _ id: String,
                _ sql: String,
                fields: [String: String] = ["id": "", "name": "", "kind": "", "geom": ""],
            ) -> PostgisLayer {
                fixture.layer(
                    id: id,
                    table: "geometry_degeneracy_cases",
                    fields: fields,
                    srid: .epsg4326,
                    sql: sql)
            }

            let schema = fixture.schema
            let layers = [
                layer("polygon", "(SELECT * FROM \"\(schema)\".geometry_degeneracy_cases WHERE name = 'hole_correct') AS data"),
                layer("collapsed", "(SELECT * FROM \"\(schema)\".geometry_degeneracy_cases WHERE name = 'collapsed_polygon') AS data"),
                layer(
                    "invalid",
                    "(SELECT * FROM \"\(schema)\".invalid_geometry) AS data",
                    fields: ["id": "", "name": "", "geom": ""]),
            ]

            let strategies: [(String, MVTClippingOption, MVTSimplificationOption, MVTMakeValidOption)] = [
                ("postgis-all", .postgis, .postgis(preserveCollapsed: true), .structure(keepCollapsed: true)),
                ("local-all", .local, .local, .none),
                ("local-postgis", .local, .postgis(preserveCollapsed: false), .none),
                ("postgis-local", .postgis, .local, .none),
                ("structure-strict", .none, .none, .structure(keepCollapsed: false)),
                ("validation-local", .local, .none, .linework),
                ("validation-simplify", .none, .meters(10.0, preserveCollapsed: false), .default),
            ]

            for (label, clipping, simplification, validation) in strategies {
                try await withPostgis(
                    fixture.source(layers: layers),
                    configuration: configuration(
                        clipping: { _, _ in clipping },
                        simplification: { _, _ in simplification },
                        validation: { _, _ in validation },
                        trackRuntimes: true))
                { postgis in
                    let result = try await postgis.vectorTile(forTile: Self.tile)

                    #expect(result.tile.features(for: "polygon").count == 1)
                    #expect(
                        result.performance?["Integration.\(IntegrationEnvironment.databaseName).polygon"]?.invalidFeatures == 0,
                    )

                    let invalidCount = result.tile.features(for: "invalid").count
                    let invalidFeatures = result.performance?["Integration.\(IntegrationEnvironment.databaseName).invalid"]?.invalidFeatures
                    // The bow-tie is either kept as a (possibly empty) feature or
                    // dropped and counted invalid, depending on the strategy.
                    #expect(
                        (invalidCount == 0 && invalidFeatures == 1)
                            || (invalidCount == 1 && invalidFeatures == 0),
                        "\(label)",
                    )
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func bufferSizesExpandQueryBounds() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let schema = fixture.schema

            func layer(_ id: String, bufferSize: Int) -> PostgisLayer {
                fixture.layer(
                    id: id,
                    table: "clip_edge_features",
                    fields: ["id": "", "name": "", "geom": ""],
                    srid: .epsg4326,
                    properties: PostgisLayer.Properties(bufferSize: bufferSize),
                    sql: "(SELECT * FROM \"\(schema)\".clip_edge_features WHERE geom && !bbox!) AS data")
            }

            for bufferSize in [0, 1, 8, 64, 256, -10, 100_000] {
                let layer = layer("buffer-\(bufferSize)", bufferSize: bufferSize)
                try await withPostgis(
                    fixture.source(layers: [layer]),
                    configuration: configuration(trackRuntimes: true))
                { postgis in
                    let result = try await postgis.vectorTile(forTile: Self.tile)
                    let names = Set(result.tile.features(for: layer.id).compactMap {
                        $0.properties["name"] as? String
                    })

                    if bufferSize <= 0 {
                        #expect(names.contains("just_outside") == false, "\(bufferSize)")
                    }
                    else {
                        #expect(names.contains("just_outside"), "\(bufferSize)")
                    }

                    let sql = result.performance?["Integration.\(IntegrationEnvironment.databaseName).\(layer.id)"]?.sqlQuery
                    #expect(sql?.contains("ST_MakeEnvelope(") == true)
                }
            }

            // Negative buffers are clamped by Properties.
            #expect(PostgisLayer.Properties(bufferSize: -10).bufferSize == 0)
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func zoomClosuresAndSourceZoomRange() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let schema = fixture.schema
            let layer = fixture.layer(
                id: "zoom",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: "(SELECT * FROM \"\(schema)\".features WHERE id = 1) AS data")

            final class Recorder: @unchecked Sendable {

                private let lock = NSLock()
                private var values: [Int] = []

                func append(_ value: Int) {
                    lock.lock()
                    defer { lock.unlock() }
                    values.append(value)
                }

                var recorded: [Int] {
                    lock.lock()
                    defer { lock.unlock() }
                    return values
                }

            }

            let recorder = Recorder()
            let source = PostgisSource(
                name: "Zoom",
                minZoom: 2,
                maxZoom: 18,
                layers: [layer])

            try await withPostgis(
                source,
                configuration: configuration(
                    clipping: { zoom, _ in
                        recorder.append(zoom)
                        return .none
                    })) { postgis in
                _ = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))
                _ = try await postgis.vectorTile(forTile: Self.tile)
                _ = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 22))
            }

            #expect(recorder.recorded.contains(0))
            #expect(recorder.recorded.contains(14))
            #expect(recorder.recorded.contains(22))
            #expect(source.minZoom == 2)
            #expect(source.maxZoom == 18)
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func layerBoundsControlQueries() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let schema = fixture.schema
            let bbox = Self.tile.boundingBox(projection: .epsg4326)

            func layer(
                _ id: String,
                boundingBox: BoundingBox?,
            ) -> PostgisLayer {
                fixture.layer(
                    id: id,
                    table: "features",
                    fields: ["id": "", "name": "", "kind": "", "geom": ""],
                    srid: .epsg4326,
                    boundingBox: boundingBox,
                    sql: "(SELECT * FROM \"\(schema)\".features WHERE id = 1) AS data")
            }

            let layers = [
                layer("outside", boundingBox: BoundingBox(
                    southWest: Coordinate3D(latitude: 0, longitude: 0),
                    northEast: Coordinate3D(latitude: 1, longitude: 1))),
                layer("partial", boundingBox: BoundingBox(
                    southWest: Coordinate3D(
                        latitude: bbox.southWest.latitude,
                        longitude: bbox.southWest.longitude),
                    northEast: Coordinate3D(
                        latitude: bbox.northEast.latitude,
                        longitude: bbox.northEast.longitude))),
                layer("contains", boundingBox: BoundingBox(
                    southWest: Coordinate3D(latitude: 40, longitude: 0),
                    northEast: Coordinate3D(latitude: 60, longitude: 30))),
                layer("unbounded", boundingBox: nil),
            ]

            try await withPostgis(
                fixture.source(layers: layers),
                configuration: configuration(trackRuntimes: true))
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let keys = Set(result.performance?.map(\.key) ?? [])

                #expect(keys.contains("Integration.\(IntegrationEnvironment.databaseName).partial"))
                #expect(keys.contains("Integration.\(IntegrationEnvironment.databaseName).contains"))
                #expect(keys.contains("Integration.\(IntegrationEnvironment.databaseName).unbounded"))
                #expect(keys.contains("Integration.\(IntegrationEnvironment.databaseName).outside") == false)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func featureMappingAndRuntimeTracking() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let schema = fixture.schema
            let layer = fixture.layer(
                id: "mapping",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: "(SELECT * FROM \"\(schema)\".features WHERE id = 1) AS data")
            let secondLayer = fixture.layer(
                id: "mapping-2",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: "(SELECT * FROM \"\(schema)\".features WHERE id = 2) AS data")

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                #expect(result.performance == nil)
            }

            let mapped = Point(Coordinate3D(latitude: 48.1005, longitude: 11.5005))
            try await withPostgis(
                fixture.source(layers: [layer, secondLayer]),
                configuration: configuration(
                    trackRuntimes: true,
                    featureMapping: { feature in
                        var properties = feature.properties
                        properties["added"] = true
                        properties["name"] = "changed"
                        properties.removeValue(forKey: "kind")

                        return Feature(
                            mapped,
                            id: .int(999),
                            properties: properties)
                    })) { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let feature = try #require(result.tile.features(for: "mapping").first)

                #expect(feature.id == .int(999))
                #expect(feature.properties["added"] as? Bool == true)
                #expect(feature.properties["name"] as? String == "changed")
                #expect(feature.properties["kind"] == nil)
                #expect(feature.geometry is Point)
                #expect(result.performance?["Integration.\(IntegrationEnvironment.databaseName).mapping"] != nil)
                #expect(result.performance?["Integration.\(IntegrationEnvironment.databaseName).mapping-2"] != nil)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func exportBufferInteractsWithLayerBuffer() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let schema = fixture.schema
            let layer = fixture.layer(
                id: "export",
                table: "clip_edge_features",
                fields: ["id": "", "name": "", "geom": ""],
                srid: .epsg4326,
                properties: PostgisLayer.Properties(bufferSize: 8),
                sql: "(SELECT * FROM \"\(schema)\".clip_edge_features WHERE geom && !bbox!) AS data")

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let withoutBuffer = try await postgis.data(
                    forTile: Self.tile,
                    format: .mvt,
                    options: VectorTile.ExportOptions())
                let withBuffer = try await postgis.data(
                    forTile: Self.tile,
                    format: .mvt,
                    options: VectorTile.ExportOptions(bufferSize: .extent(64)))

                let withoutTile = try VectorTile(
                    mvtData: #require(withoutBuffer.data),
                    tile: Self.tile)
                let withTile = try VectorTile(
                    mvtData: #require(withBuffer.data),
                    tile: Self.tile)

                let withoutNames = Set(withoutTile.features(for: "export").compactMap {
                    $0.properties["name"] as? String
                })
                let withNames = Set(withTile.features(for: "export").compactMap {
                    $0.properties["name"] as? String
                })

                #expect(withoutNames.contains("just_outside") == false)
                #expect(withNames.contains("just_outside"))
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func sqlTokensAndExtremeTiles() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let schema = fixture.schema
            let layer = fixture.layer(
                id: "tokens",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": "", "scale": "", "pixel": ""],
                srid: .epsg4326,
                sql: """
                (SELECT *, !scale_denominator! AS scale, !pixel_width! AS pixel
                 FROM "\(schema)".features LIMIT 1) AS data
                """)

            try await withPostgis(
                PostgisSource(name: "Integration", minZoom: 0, maxZoom: 22, layers: [layer]),
                configuration: configuration(trackRuntimes: true))
            { postgis in
                let z0 = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))
                let z14 = try await postgis.vectorTile(forTile: Self.tile)

                let z0Feature = try #require(z0.tile.features(for: "tokens").first)
                let z14Feature = try #require(z14.tile.features(for: "tokens").first)

                let z0Scale = try #require(z0Feature.properties["scale"] as? Double)
                let z14Scale = try #require(z14Feature.properties["scale"] as? Double)
                let z0Pixel = try #require(z0Feature.properties["pixel"] as? Double)
                let z14Pixel = try #require(z14Feature.properties["pixel"] as? Double)

                #expect(z0Scale > 0)
                #expect(z14Scale > 0)
                #expect(z0Scale != z14Scale)
                #expect(z0Pixel > 0)
                #expect(z14Pixel > 0)
                #expect(z0Pixel != z14Pixel)

                let maximum = (1 << 22) - 1
                _ = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 22))
                _ = try await postgis.vectorTile(forTile: MapTile(x: maximum, y: maximum, z: 22))
            }
        }
    }

}
