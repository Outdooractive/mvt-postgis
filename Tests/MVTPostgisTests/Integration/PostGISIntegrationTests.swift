import Foundation
import GISTools
@testable import MVTPostgis
import MVTTools
import Testing

@Suite(.serialized, .enabled(if: IntegrationEnvironment.isAvailable))
struct PostGISIntegrationTests {

    /// A tile that contains the fixture coordinates around Munich.
    private static let tile = MapTile(x: 8715, y: 5688, z: 14)

    private static let propertyFields: [String: String] = [
        "id": "",
        "text_value": "",
        "char_value": "",
        "uuid_value": "",
        "int2_value": "",
        "int4_value": "",
        "int8_value": "",
        "int2_array": "",
        "int4_array": "",
        "int8_array": "",
        "float4_value": "",
        "float8_value": "",
        "numeric_value": "",
        "float4_array": "",
        "float8_array": "",
        "bool_value": "",
        "bool_array": "",
        "date_value": "",
        "timestamp_value": "",
        "timestamptz_value": "",
        "text_array": "",
        "varchar_value": "",
        "varchar_array": "",
        "inet_value": "",
        "geom": "",
    ]

    private static let extendedTypeFields: [String: String] = [
        "id": "",
        "json_value": "",
        "jsonb_value": "",
        "json_array": "",
        "jsonb_array": "",
        "bytea_value": "",
        "bytea_array": "",
        "xml_value": "",
        "xml_array": "",
        "money_value": "",
        "money_array": "",
        "oid_value": "",
        "regproc_value": "",
        "regproc_array": "",
        "regclass_value": "",
        "regclass_array": "",
        "regtype_value": "",
        "regtype_array": "",
        "numeric_array": "",
        "bpchar_array": "",
        "name_value": "",
        "name_array": "",
        "uuid_array": "",
        "date_array": "",
        "timestamp_array": "",
        "timestamptz_array": "",
        "enum_value": "",
        "unsupported_time": "",
        "unsupported_interval": "",
        "unsupported_inet": "",
        "unsupported_cidr": "",
        "unsupported_macaddr": "",
        "unsupported_bit": "",
        "unsupported_range": "",
        "domain_value": "",
        "unsupported_composite": "",
        "geom": "",
    ]

    private static let arrayEdgeCaseFields: [String: String] = [
        "id": "",
        "empty_int_array": "",
        "null_int_array": "",
        "int_array_with_null": "",
        "text_array_with_null": "",
        "multi_int_array": "",
        "geom": "",
    ]

    private func configuration(
        clipping: MVTClippingOption = .none,
        simplification: MVTSimplificationOption = .none,
        validation: MVTMakeValidOption = .none,
        trackRuntimes: Bool = false,
        tileTimeout: TimeInterval = 60.0,
        featureMapping: (@Sendable (Feature) -> Feature)? = nil,
    ) -> MVTPostgisConfiguration {
        MVTPostgisConfiguration(
            tileTimeout: tileTimeout,
            clipping: { _, _ in clipping },
            simplification: { _, _ in simplification },
            validation: { _, _ in validation },
            featureMapping: featureMapping,
            trackRuntimes: trackRuntimes)
    }

    /// Creates a ``MVTPostgis`` instance and guarantees that its pools are shut
    /// down, even when the body throws or an expectation fails.
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
    func `loads all geometry types`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "features",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT * FROM "\(fixture.schema)".features
                 WHERE id <= 5 AND geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(trackRuntimes: true))
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let features = result.tile.features(for: "features")

                #expect(features.count == 5)
                #expect(features.compactMap(\.id) == [.int(1), .int(2), .int(3), .int(4), .int(5)])

                let byId = Dictionary(uniqueKeysWithValues: features.compactMap { feature in
                    (feature.id, feature)
                })
                #expect(byId[.int(1)]?.geometry is Point)
                #expect(byId[.int(2)]?.geometry is LineString)
                #expect(byId[.int(3)]?.geometry is Polygon)
                #expect(byId[.int(4)]?.geometry is MultiPolygon)
                #expect(byId[.int(5)]?.geometry is GeometryCollection)

                #expect(byId[.int(1)]?.properties["name"] as? String == "point")
                #expect(byId[.int(2)]?.properties["kind"] as? String == "line")

                let performance = try #require(result.performance?["Integration.\(IntegrationEnvironment.databaseName).features"])
                #expect(performance.features == 5)
                #expect(performance.wkbBytes > 0)
                #expect(performance.runtime >= 0)
                #expect(performance.invalidFeatures == 0)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `decodes property types`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "properties",
                table: "property_types",
                fields: Self.propertyFields,
                srid: .epsg4326)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let feature = try #require(result.tile.features(for: "properties").first)
                let properties = feature.properties

                #expect(feature.id == .int(1))
                #expect(properties["text_value"] as? String == "text")
                #expect((properties["char_value"] as? String)?.hasPrefix("AB") == true)
                #expect(properties["uuid_value"] as? String == "00000000-0000-0000-0000-000000000001")
                #expect(properties["int2_value"] as? Int == -2)
                #expect(properties["int4_value"] as? Int == -4)
                #expect(properties["int8_value"] as? Int == -8)
                #expect(properties["int2_array"] as? [Int] == [1, 2])
                #expect(properties["int4_array"] as? [Int] == [3, 4])
                #expect(properties["int8_array"] as? [Int] == [5, 6])
                #expect(properties["float4_value"] as? Double == 1.25)
                #expect(properties["float8_value"] as? Double == 2.5)
                #expect(properties["numeric_value"] as? Double == 12.5)
                #expect(properties["float4_array"] as? [Double] == [1.5, 2.5])
                #expect(properties["float8_array"] as? [Double] == [3.5, 4.5])
                #expect(properties["bool_value"] as? Bool == true)
                #expect(properties["bool_array"] as? [Bool] == [true, false])
                #expect((properties["date_value"] as? String)?.hasPrefix("2024-01-02") == true)
                #expect((properties["timestamp_value"] as? String)?.hasPrefix("2024-01-02T03:04:05") == true)
                #expect((properties["timestamptz_value"] as? String)?.hasPrefix("2024-01-02T03:04:05") == true)
                #expect(properties["text_array"] as? [String] == ["a", "b"])
                #expect(properties["varchar_value"] as? String == "varchar")
                #expect(properties["varchar_array"] as? [String] == ["x", "y"])
                #expect(properties["inet_value"] == nil)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `decodes extended property types`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "extended",
                table: "extended_types",
                fields: Self.extendedTypeFields,
                srid: .epsg4326)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(trackRuntimes: true))
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let feature = try #require(result.tile.features(for: "extended").first)
                let properties = feature.properties

                #expect(feature.id == .int(1))

                #expect(Self.jsonObject(properties["json_value"])?["a"] as? Int == 1)
                #expect(Self.jsonObject(properties["jsonb_value"])?["b"] as? [Int] == [1, 2])

                let jsonArray = try #require(properties["json_array"] as? [String])
                #expect(jsonArray.count == 2)
                #expect(Self.jsonObject(jsonArray[0])?["c"] as? Int == 3)
                #expect(Self.jsonObject(jsonArray[1])?["d"] as? Int == 4)

                let jsonbArray = try #require(properties["jsonb_array"] as? [String])
                #expect(jsonbArray.count == 2)
                #expect(Self.jsonObject(jsonbArray[0])?["e"] as? Int == 5)
                #expect(Self.jsonObject(jsonbArray[1])?["f"] as? Int == 6)

                #expect(properties["bytea_value"] as? String == Data([0xDE, 0xAD, 0xBE, 0xEF]).base64EncodedString())
                #expect(properties["bytea_array"] as? [String] == [
                    Data([0x01, 0x02]).base64EncodedString(),
                    Data([0x03, 0x04]).base64EncodedString(),
                ])

                #expect((properties["xml_value"] as? String)?.contains("<root>") == true)
                #expect((properties["xml_array"] as? [String])?.count == 2)

                #expect(properties["money_value"] as? String == "12.34")
                #expect(properties["money_array"] as? [String] == ["1.23", "4.56"])
                #expect(properties["oid_value"] as? Int == 1234)
                #expect((properties["regproc_value"] as? Int ?? 0) > 0)
                #expect((properties["regproc_array"] as? [Int])?.count == 2)
                #expect((properties["regclass_value"] as? Int ?? 0) > 0)
                #expect((properties["regclass_array"] as? [Int])?.count == 2)
                #expect((properties["regtype_value"] as? Int ?? 0) > 0)
                #expect((properties["regtype_array"] as? [Int])?.count == 2)

                #expect(properties["numeric_array"] as? [Double] == [1.5, 2.5])
                #expect((properties["bpchar_array"] as? [String])?.map { $0.trimmingCharacters(in: .whitespaces) } == ["A", "B"])
                #expect(properties["name_value"] as? String == "a_name")
                #expect(properties["name_array"] as? [String] == ["x", "y"])
                #expect(properties["uuid_array"] as? [String] == [
                    "00000000-0000-0000-0000-000000000001",
                    "00000000-0000-0000-0000-000000000002",
                ])
                #expect((properties["date_array"] as? [String])?.first?.hasPrefix("2024-01-02") == true)
                #expect((properties["timestamp_array"] as? [String])?.first?.hasPrefix("2024-01-02T03:04:05") == true)
                #expect((properties["timestamptz_array"] as? [String])?.first?.hasPrefix("2024-01-02T03:04:05") == true)
                #expect(properties["enum_value"] as? String == "happy")

                #expect(properties["unsupported_time"] == nil)
                #expect(properties["unsupported_interval"] == nil)
                #expect(properties["unsupported_inet"] == nil)
                #expect(properties["unsupported_cidr"] == nil)
                #expect(properties["unsupported_macaddr"] == nil)
                #expect(properties["unsupported_bit"] == nil)
                #expect(properties["unsupported_range"] == nil)
                #expect(properties["domain_value"] as? Int == 42)
                #expect(properties["unsupported_composite"] == nil)

                #expect(result.performance?["Integration.\(IntegrationEnvironment.databaseName).extended"]?.invalidFeatures == 0)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `decodes array edge cases`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "array_edges",
                table: "array_edge_cases",
                fields: Self.arrayEdgeCaseFields,
                srid: .epsg4326)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(trackRuntimes: true))
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let feature = try #require(result.tile.features(for: "array_edges").first)
                let properties = feature.properties

                #expect(properties["empty_int_array"] as? [Int] == [])
                #expect(properties["null_int_array"] == nil)
                #expect(properties["int_array_with_null"] as? [Int] == [1, 3])
                #expect(properties["text_array_with_null"] as? [String] == ["a", "b"])
                #expect(properties["multi_int_array"] == nil)

                #expect(result.performance?["Integration.\(IntegrationEnvironment.databaseName).array_edges"]?.invalidFeatures == 0)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `skips null geometry`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "null_geometry",
                table: "null_geometry",
                fields: ["id": "", "name": "", "geom": ""],
                srid: .epsg4326)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(trackRuntimes: true))
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let features = result.tile.features(for: "null_geometry")

                #expect(features.count == 1)
                #expect(features.first?.id == .int(2))
                #expect(result.performance?["Integration.\(IntegrationEnvironment.databaseName).null_geometry"]?.invalidFeatures == 0)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `postgis clipping keeps intersecting features`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "clip",
                table: "clip_features",
                fields: ["id": "", "name": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT * FROM "\(fixture.schema)".clip_features
                 WHERE id <> 4 AND geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(clipping: .postgis, trackRuntimes: true))
            { postgis in
                let result = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 1))
                let names = Set(result.tile.features(for: "clip").compactMap {
                    $0.properties["name"] as? String
                })

                #expect(names == ["crossing-line", "crossing-polygon", "inside-point", "inside-line"])
                #expect(result.performance?["Integration.\(IntegrationEnvironment.databaseName).clip"]?.invalidFeatures == 0)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `local clipping rejects outside feature`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "clip",
                table: "clip_features",
                fields: ["id": "", "name": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT * FROM "\(fixture.schema)".clip_features) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(clipping: .local, trackRuntimes: true))
            { postgis in
                let result = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 1))
                let names = Set(result.tile.features(for: "clip").compactMap {
                    $0.properties["name"] as? String
                })

                #expect(names.contains("outside-point") == false)
                #expect(result.performance?["Integration.\(IntegrationEnvironment.databaseName).clip"]?.invalidFeatures == 1)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `simplification reduces vertices`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "simplify",
                table: "simplify_features",
                fields: ["id": "", "name": "", "geom": ""],
                srid: .epsg4326)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(simplification: .meters(100_000, preserveCollapsed: false)))
            { postgis in
                let result = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))
                let line = try #require(result.tile.features(for: "simplify").first?.geometry as? LineString)

                #expect(line.coordinates.count < 7)
            }

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(simplification: .local))
            { postgis in
                let result = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))
                let line = try #require(result.tile.features(for: "simplify").first?.geometry as? LineString)

                #expect(line.coordinates.count < 7)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `validation makes invalid polygon valid`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "invalid",
                table: "invalid_geometry",
                fields: ["id": "", "name": "", "geom": ""],
                srid: .epsg4326)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(validation: .default))
            { postgis in
                let result = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))
                let feature = try #require(result.tile.features(for: "invalid").first)

                #expect(feature.isValid)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `per layer projection reprojects features`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let geographic = fixture.layer(
                id: "geographic",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT * FROM "\(fixture.schema)".features WHERE id = 1 AND geom && !bbox!) AS data
                """)
            let mercator = fixture.layer(
                id: "mercator",
                table: "features_3857",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg3857,
                sql: """
                (SELECT * FROM "\(fixture.schema)".features_3857 WHERE id = 1 AND geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [geographic, mercator]),
                configuration: configuration())
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                #expect(result.tile.projection == .epsg4326)
                #expect(result.tile.features(for: "geographic").count == 1)
                #expect(result.tile.features(for: "mercator").count == 1)

                let point = try #require(result.tile.features(for: "mercator").first?.geometry as? Point)
                #expect(point.coordinate.projection == .epsg4326)
                #expect(abs(point.coordinate.longitude - 11.5) < 0.01)
                #expect(abs(point.coordinate.latitude - 48.1) < 0.01)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `supports utm projection`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "utm",
                table: "features_utm",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg32633)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                #expect(result.tile.projection == .epsg32633)
                #expect(result.tile.features(for: "utm").count == 2)

                let point = try #require(result.tile.features(for: "utm").first?.geometry as? Point)
                #expect(point.coordinate.projection == .epsg32633)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `validates SQL`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "features",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let validSQL = """
                (SELECT * FROM "\(fixture.schema)".features WHERE geom && !bbox!) AS data
                """
                #expect(await postgis.validate(sql: validSQL, forLayer: layer) == nil)
                #expect(await postgis.validate(
                    sql: "SELECT * FROM \"\(fixture.schema)\".features",
                    forLayer: layer) == nil)
                #expect(await postgis.validate(sql: "SELECT * FROM missing_table", forLayer: layer) != nil)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `feature mapping and buffer are applied`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "features",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT * FROM "\(fixture.schema)".features WHERE id = 1 AND geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(
                    featureMapping: { feature in
                        var mapped = feature
                        mapped.setProperty(true, for: "mapped")
                        return mapped
                    })) { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let feature = try #require(result.tile.features(for: "features").first)
                #expect(feature.properties["mapped"] as? Bool == true)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `data round trips MVT and MLT`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "features",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT * FROM "\(fixture.schema)".features WHERE id <= 3 AND geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let mvt = try await postgis.data(forTile: Self.tile, format: .mvt, options: VectorTile.ExportOptions())
                let mlt = try await postgis.data(forTile: Self.tile, format: .mlt, options: VectorTile.ExportOptions())

                let mvtTile = try VectorTile(mvtData: #require(mvt.data), tile: Self.tile)
                let mltTile = try VectorTile(mltData: #require(mlt.data), tile: Self.tile)

                #expect(mvtTile.features(for: "features").count == 3)
                #expect(mltTile.features(for: "features").count == 3)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `tile timeout is reported`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "slow",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT f.id, f.name, f.kind, f.geom
                 FROM "\(fixture.schema)".features f,
                      LATERAL (SELECT pg_sleep(5)) sleep
                 WHERE f.geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(tileTimeout: 1.0))
            { postgis in
                do {
                    _ = try await postgis.vectorTile(forTile: Self.tile)
                    Issue.record("Expected tile timeout")
                }
                catch let error as MVTPostgisError {
                    guard case .tileTimedOut = error else {
                        Issue.record("Expected tileTimedOut, got \(error)")
                        return
                    }
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func `cancellation is reported`() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "slow",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT f.id, f.name, f.kind, f.geom
                 FROM "\(fixture.schema)".features f,
                      LATERAL (SELECT pg_sleep(5)) sleep
                 WHERE f.geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(tileTimeout: 30.0))
            { postgis in
                let task = Task {
                    try await postgis.vectorTile(forTile: Self.tile)
                }
                try await Task.sleep(for: .milliseconds(200))
                task.cancel()

                do {
                    _ = try await task.value
                    Issue.record("Expected cancellation")
                }
                catch let error as MVTPostgisError {
                    #expect(error == .cancelled)
                }
                catch is CancellationError {
                    // Cancellation may surface directly while the query is in flight.
                }
            }
        }
    }

    private static func jsonObject(_ value: Any?) -> [String: Any]? {
        guard let string = value as? String,
              let data = string.data(using: .utf8)
        else { return nil }

        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

}
