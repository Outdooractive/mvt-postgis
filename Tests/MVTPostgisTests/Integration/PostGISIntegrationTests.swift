import Foundation
import GISTools
@testable import MVTPostgis
import MVTTools
import PostgresConnectionPool
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
        "hstore_value": "",
        "unsupported_time": "",
        "interval_value": "",
        "interval_array": "",
        "unsupported_inet": "",
        "unsupported_cidr": "",
        "unsupported_macaddr": "",
        "unsupported_bit": "",
        "unsupported_int4range": "",
        "tsrange_value": "",
        "tstzrange_value": "",
        "daterange_value": "",
        "empty_range": "",
        "unbounded_range": "",
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

    private static let ogcGeometryNames = [
        "point",
        "multipoint",
        "linestring",
        "multilinestring",
        "polygon",
        "polygon_hole",
        "multipolygon",
        "collection_homogeneous",
        "collection_mixed",
        "collection_nested",
        "point_empty",
        "linestring_empty",
        "polygon_empty",
        "multipoint_empty",
        "multilinestring_empty",
        "multipolygon_empty",
        "collection_empty",
        "point_z",
        "linestring_z",
        "polygon_z",
        "point_m",
        "linestring_m",
        "polygon_m",
        "point_zm",
        "circularstring",
        "compoundcurve",
        "curvepolygon",
        "multicurve",
        "multisurface",
        "triangle",
        "tin",
        "polyhedralsurface",
    ]

    private static let ogcGeometryFields = ["id": "", "name": "", "kind": "", "geom": ""]

    private static let propertyEdgeFields: [String: String] = [
        "case_name": "",
        "text_empty": "",
        "text_unicode": "",
        "text_control": "",
        "text_long": "",
        "char_padded": "",
        "na.me": "",
        "ümlaut": "",
        "int2_min": "",
        "int2_max": "",
        "int4_min": "",
        "int4_max": "",
        "int8_min": "",
        "int8_max": "",
        "int8_above_2_53": "",
        "numeric_high": "",
        "numeric_nan": "",
        "numeric_infinity": "",
        "numeric_neg_infinity": "",
        "float4_nan": "",
        "float4_infinity": "",
        "float4_neg_infinity": "",
        "float4_min_subnormal": "",
        "float4_max": "",
        "float8_nan": "",
        "float8_infinity": "",
        "float8_neg_infinity": "",
        "float8_min_subnormal": "",
        "float8_max": "",
        "date_bc": "",
        "date_after_9999": "",
        "date_infinity": "",
        "date_neg_infinity": "",
        "timestamp_infinity": "",
        "timestamp_neg_infinity": "",
        "timestamptz_infinity": "",
        "timestamptz_neg_infinity": "",
        "timestamp_micros": "",
        "timestamptz_dst": "",
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
    func loadsAllGeometryTypes() async throws {
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
    func decodesPropertyTypes() async throws {
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
    func decodesExtendedPropertyTypes() async throws {
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
                #expect(properties["hstore_value"] as? [String: String] == [
                    "name": "München",
                    "population": "1500000",
                ])

                #expect(properties["interval_value"] as? String == "1 day 02:03:04")
                #expect(properties["interval_array"] as? [String] == ["1 day", "02:00:00"])
                #expect(properties["tsrange_value"] as? String == "[2024-01-02T03:04:05Z,2024-01-03T04:05:06Z)")
                #expect(properties["tstzrange_value"] as? String == "[2024-01-02T03:04:05Z,2024-01-03T04:05:06Z)")
                #expect(properties["daterange_value"] as? String == "[2024-01-02T00:00:00Z,2024-01-05T00:00:00Z)")
                #expect(properties["empty_range"] as? String == "empty")
                #expect(properties["unbounded_range"] as? String == "(,2024-01-05T00:00:00Z)")

                #expect(properties["unsupported_time"] == nil)
                #expect(properties["unsupported_inet"] == nil)
                #expect(properties["unsupported_cidr"] == nil)
                #expect(properties["unsupported_macaddr"] == nil)
                #expect(properties["unsupported_bit"] == nil)
                #expect(properties["unsupported_int4range"] == nil)
                #expect(properties["domain_value"] as? Int == 42)
                #expect(properties["unsupported_composite"] == nil)

                #expect(result.performance?["Integration.\(IntegrationEnvironment.databaseName).extended"]?.invalidFeatures == 0)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func decodesArrayEdgeCases() async throws {
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
    func loadsMultiGeometries() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "multi",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT * FROM "\(fixture.schema)".features
                 WHERE id IN (8, 9) AND geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let features = result.tile.features(for: "multi")
                let byId = Dictionary(uniqueKeysWithValues: features.compactMap { feature in
                    (feature.id, feature)
                })

                #expect(features.count == 2)
                #expect(byId[.int(8)]?.geometry is MultiPoint)
                #expect(byId[.int(9)]?.geometry is MultiLineString)
                #expect((byId[.int(8)]?.geometry as? MultiPoint)?.coordinates.count == 2)
                #expect((byId[.int(9)]?.geometry as? MultiLineString)?.coordinates.count == 2)

                let mvt = try await postgis.data(forTile: Self.tile, format: .mvt, options: VectorTile.ExportOptions())
                let mlt = try await postgis.data(forTile: Self.tile, format: .mlt, options: VectorTile.ExportOptions())
                let mvtTile = try VectorTile(mvtData: #require(mvt.data), tile: Self.tile)
                let mltTile = try VectorTile(mltData: #require(mlt.data), tile: Self.tile)

                #expect(mvtTile.features(for: "multi").count == 2)
                #expect(mltTile.features(for: "multi").count == 2)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func loadsGeographyGeometryColumn() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "geography",
                table: "geography_features",
                fields: ["id": "", "name": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT * FROM "\(fixture.schema)".geography_features) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let features = result.tile.features(for: "geography")
                let byId = Dictionary(uniqueKeysWithValues: features.compactMap { feature in
                    (feature.id, feature)
                })

                #expect(features.count == 3)
                #expect(byId[.int(1)]?.geometry is Point)
                #expect(byId[.int(2)]?.geometry is LineString)
                #expect(byId[.int(3)]?.geometry is Polygon)

                let point = try #require(byId[.int(1)]?.geometry as? Point)
                #expect(abs(point.coordinate.longitude - 11.5) < 0.01)
                #expect(abs(point.coordinate.latitude - 48.1) < 0.01)

                let mvt = try await postgis.data(forTile: Self.tile, format: .mvt, options: VectorTile.ExportOptions())
                let mvtTile = try VectorTile(mvtData: #require(mvt.data), tile: Self.tile)
                #expect(mvtTile.features(for: "geography").count == 3)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func decodesPropertyValueEdgeCases() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "property_edges",
                table: "property_edge_cases",
                fields: Self.propertyEdgeFields,
                srid: .epsg4326)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let feature = try #require(result.tile.features(for: "property_edges").first)
                let properties = feature.properties

                let unicode = "emoji 😀 combining e\u{0301} RTL \u{202E}abc\u{202C} non-BMP 𝄞"

                #expect(properties["text_empty"] as? String == "")
                #expect(properties["text_unicode"] as? String == unicode)
                #expect(properties["text_control"] as? String == "line1\nline2\ttab")
                #expect((properties["text_long"] as? String)?.count == 1_000_000)
                #expect(properties["char_padded"] as? String == "AB    ")
                #expect(properties["na.me"] as? String == "dotted")
                #expect(properties["ümlaut"] as? String == "umlaut")

                #expect(properties["int2_min"] as? Int == -32768)
                #expect(properties["int2_max"] as? Int == 32767)
                #expect(properties["int4_min"] as? Int == -2_147_483_648)
                #expect(properties["int4_max"] as? Int == 2_147_483_647)
                #expect(properties["int8_min"] as? Int == Int.min)
                #expect(properties["int8_max"] as? Int == Int.max)
                #expect(properties["int8_above_2_53"] as? Int == 9_007_199_254_740_993)

                #expect(properties["numeric_high"] as? Double == 1.2345678901234567e19)
                #expect((properties["numeric_nan"] as? Double)?.isNaN == true)
                #expect(properties["numeric_infinity"] as? Double == .infinity)
                #expect(properties["numeric_neg_infinity"] as? Double == -.infinity)

                #expect((properties["float4_nan"] as? Double)?.isNaN == true)
                #expect(properties["float4_infinity"] as? Double == .infinity)
                #expect(properties["float4_neg_infinity"] as? Double == -.infinity)
                #expect(properties["float4_min_subnormal"] as? Double == 1.401298464324817e-45)
                #expect(properties["float4_max"] as? Double == 3.4028234663852886e38)

                #expect((properties["float8_nan"] as? Double)?.isNaN == true)
                #expect(properties["float8_infinity"] as? Double == .infinity)
                #expect(properties["float8_neg_infinity"] as? Double == -.infinity)
                #expect(properties["float8_min_subnormal"] as? Double == 5e-324)
                #expect(properties["float8_max"] as? Double == 1.7976931348623157e308)

                #expect((properties["date_bc"] as? String)?.hasPrefix("-4712") == true)
                #expect((properties["date_after_9999"] as? String)?.hasPrefix("10000") == true)
                #expect(properties["date_infinity"] as? String != nil)
                #expect(properties["date_neg_infinity"] as? String != nil)
                #expect(properties["timestamp_infinity"] as? String != nil)
                #expect(properties["timestamp_neg_infinity"] as? String != nil)
                #expect(properties["timestamptz_infinity"] as? String != nil)
                #expect(properties["timestamptz_neg_infinity"] as? String != nil)
                #expect(properties["timestamp_micros"] as? String == "2024-01-02T03:04:05.123456Z")
                #expect(properties["timestamptz_dst"] as? String == "2024-03-31T01:30:00.000000Z")
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func propertyEdgeValuesRoundTrip() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let fields = [
                "text_unicode": "",
                "int8_max": "",
                "int8_above_2_53": "",
                "numeric_high": "",
                "timestamp_micros": "",
                "float8_nan": "",
                "char_padded": "",
                "geom": "",
            ]
            let layer = fixture.layer(
                id: "roundtrip",
                table: "property_edge_cases",
                fields: fields,
                srid: .epsg4326,
                sql: """
                (SELECT text_unicode, int8_max, int8_above_2_53, numeric_high,
                        timestamp_micros, float8_nan, char_padded, geom
                 FROM "\(fixture.schema)".property_edge_cases
                 WHERE case_name = 'all' AND geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let mvt = try await postgis.data(forTile: Self.tile, format: .mvt, options: VectorTile.ExportOptions())
                let mlt = try await postgis.data(forTile: Self.tile, format: .mlt, options: VectorTile.ExportOptions())
                let mvtTile = try VectorTile(mvtData: #require(mvt.data), tile: Self.tile)
                let mltTile = try VectorTile(mltData: #require(mlt.data), tile: Self.tile)

                for tile in [mvtTile, mltTile] {
                    let feature = try #require(tile.features(for: "roundtrip").first)
                    let properties = feature.properties
                    let unicode = "emoji 😀 combining e\u{0301} RTL \u{202E}abc\u{202C} non-BMP 𝄞"

                    #expect(properties["text_unicode"] as? String == unicode)
                    #expect(Self.integer(properties["int8_max"]) == Int.max)
                    #expect(Self.integer(properties["int8_above_2_53"]) == 9_007_199_254_740_993)
                    #expect(properties["numeric_high"] as? Double == 1.2345678901234567e19)
                    #expect(properties["timestamp_micros"] as? String == "2024-01-02T03:04:05.123456Z")
                    #expect((properties["float8_nan"] as? Double)?.isNaN == true)
                    #expect(properties["char_padded"] as? String == "AB    ")
                }
            }
        }
    }

    private func idLayer(
        fixture: IntegrationFixture,
        caseName: String,
        cast: String,
    ) -> PostgisLayer {
        let idExpression = cast == "text" ? "id_text" : "id_text::\(cast)"
        return fixture.layer(
            id: "ids",
            table: "id_edge_cases",
            fields: ["id": "", "label": "", "geom": ""],
            srid: .epsg4326,
            sql: """
            (SELECT \(idExpression) AS id, label, geom
             FROM "\(fixture.schema)".id_edge_cases
             WHERE case_name = '\(caseName)' AND geom && !bbox!) AS data
            """)
    }

    @Test(.timeLimit(.minutes(2)))
    func nonNegativeIntegerIdsBecomeFeatureIds() async throws {
        let cases: [(caseName: String, cast: String, expected: Int)] = [
            ("int2_max", "int2", 32767),
            ("int4_max", "int4", 2_147_483_647),
            ("int8_max", "int8", Int.max),
            ("int8_above_2_53", "int8", 9_007_199_254_740_993),
            ("zero", "int8", 0),
        ]

        try await IntegrationFixture.withFixture { fixture in
            for item in cases {
                let layer = idLayer(fixture: fixture, caseName: item.caseName, cast: item.cast)

                try await withPostgis(
                    fixture.source(layers: [layer]),
                    configuration: configuration())
                { postgis in
                    let result = try await postgis.vectorTile(forTile: Self.tile)
                    let feature = try #require(result.tile.features(for: "ids").first)

                    #expect(feature.id == .int(item.expected))
                    #expect(feature.properties["id"] == nil)
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func largeIntegerIdsRoundTrip() async throws {
        let cases: [(caseName: String, expected: Int)] = [
            ("int8_max", Int.max),
            ("int8_above_2_53", 9_007_199_254_740_993),
            ("zero", 0),
        ]

        try await IntegrationFixture.withFixture { fixture in
            for item in cases {
                let layer = idLayer(fixture: fixture, caseName: item.caseName, cast: "int8")

                try await withPostgis(
                    fixture.source(layers: [layer]),
                    configuration: configuration())
                { postgis in
                    let mvt = try await postgis.data(forTile: Self.tile, format: .mvt, options: VectorTile.ExportOptions())
                    let mlt = try await postgis.data(forTile: Self.tile, format: .mlt, options: VectorTile.ExportOptions())
                    let mvtTile = try VectorTile(mvtData: #require(mvt.data), tile: Self.tile)
                    let mltTile = try VectorTile(mltData: #require(mlt.data), tile: Self.tile)

                    for tile in [mvtTile, mltTile] {
                        let feature = try #require(tile.features(for: "ids").first)
                        #expect(feature.id?.uint64Value == UInt64(item.expected))
                    }
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func negativeAndNonIntegerIdsRemainProperties() async throws {
        let cases: [(caseName: String, cast: String)] = [
            ("int2_min", "int2"),
            ("int4_min", "int4"),
            ("int8_min", "int8"),
            ("text", "text"),
            ("uuid", "uuid"),
            ("float", "float8"),
            ("bool", "boolean"),
            ("array", "int4[]"),
            ("json", "jsonb"),
            ("numeric", "numeric"),
            ("oversized", "text"),
        ]

        try await IntegrationFixture.withFixture { fixture in
            for item in cases {
                let layer = idLayer(fixture: fixture, caseName: item.caseName, cast: item.cast)

                try await withPostgis(
                    fixture.source(layers: [layer]),
                    configuration: configuration())
                { postgis in
                    let result = try await postgis.vectorTile(forTile: Self.tile)
                    let feature = try #require(result.tile.features(for: "ids").first)
                    let idProperty = feature.properties["id"]

                    switch item.caseName {
                    case "int2_min":
                        #expect(idProperty as? Int == -32768)
                    case "int4_min":
                        #expect(idProperty as? Int == -2_147_483_648)
                    case "int8_min":
                        #expect(idProperty as? Int == Int.min)
                    case "text":
                        #expect(idProperty as? String == "abc")
                    case "uuid":
                        #expect(idProperty as? String == "00000000-0000-0000-0000-000000000042")
                    case "float":
                        #expect(idProperty as? Double == 1.5)
                    case "bool":
                        #expect(idProperty as? Bool == true)
                    case "array":
                        #expect(idProperty as? [Int] == [1, 2])
                    case "json":
                        #expect(Self.jsonObject(idProperty)?["a"] as? Int == 1)
                    case "numeric":
                        #expect(idProperty as? Double == 1.2345678901234567e19)
                    case "oversized":
                        #expect(idProperty as? String == "9223372036854775808")
                    default:
                        Issue.record("Unexpected ID case \(item.caseName)")
                    }

                    // Only positive integer IDs are used as feature IDs. The
                    // remaining values keep a generated in-memory string ID.
                    #expect(feature.id?.int64Value == nil)
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func duplicateIdsArePreserved() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "duplicates",
                table: "id_edge_cases",
                fields: ["id": "", "label": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT id_text::int8 AS id, label, geom
                 FROM "\(fixture.schema)".id_edge_cases
                 WHERE case_name IN ('dup1', 'dup2') AND geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let features = result.tile.features(for: "duplicates")

                #expect(features.count == 2)
                #expect(features.allSatisfy { $0.id == .int(1) })
                #expect(Set(features.compactMap { $0.properties["label"] as? String }) == ["dup1", "dup2"])

                let mvt = try await postgis.data(forTile: Self.tile, format: .mvt, options: VectorTile.ExportOptions())
                let mvtTile = try VectorTile(mvtData: #require(mvt.data), tile: Self.tile)
                #expect(mvtTile.features(for: "duplicates").count == 2)
                #expect(mvtTile.features(for: "duplicates").allSatisfy { $0.id?.uint64Value == 1 })
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func missingIdIsAbsent() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "missing_id",
                table: "id_edge_cases",
                fields: ["label": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT label, geom FROM "\(fixture.schema)".id_edge_cases
                 WHERE case_name = 'text' AND geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration())
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let feature = try #require(result.tile.features(for: "missing_id").first)

                #expect(feature.properties["id"] == nil)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func nullAndAbsentPropertiesAreBothAbsent() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let nullLayer = fixture.layer(
                id: "null_prop",
                table: "property_edge_cases",
                fields: ["null_prop": "", "case_name": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT NULL::text AS null_prop, case_name, geom
                 FROM "\(fixture.schema)".property_edge_cases
                 WHERE case_name = 'all' AND geom && !bbox!) AS data
                """)
            let absentLayer = fixture.layer(
                id: "absent_prop",
                table: "property_edge_cases",
                fields: ["case_name": "", "geom": ""],
                srid: .epsg4326,
                sql: """
                (SELECT case_name, geom FROM "\(fixture.schema)".property_edge_cases
                 WHERE case_name = 'all' AND geom && !bbox!) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [nullLayer, absentLayer]),
                configuration: configuration())
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                let nullFeature = try #require(result.tile.features(for: "null_prop").first)
                let absentFeature = try #require(result.tile.features(for: "absent_prop").first)

                #expect(nullFeature.properties["null_prop"] == nil)
                #expect(absentFeature.properties["null_prop"] == nil)
            }
        }
    }

    private func ogcGeometryLayers(_ fixture: IntegrationFixture, names: [String], sql: String? = nil) -> [PostgisLayer] {
        names.map { name in
            fixture.layer(
                id: name,
                table: "geometry_edge_cases",
                fields: Self.ogcGeometryFields,
                srid: .epsg4326,
                sql: sql ?? """
                (SELECT * FROM "\(fixture.schema)".geometry_edge_cases
                 WHERE name = '\(name)') AS data
                """)
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func loadsOgcGeometryTypes() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layers = ogcGeometryLayers(fixture, names: Self.ogcGeometryNames)

            try await withPostgis(
                fixture.source(layers: layers),
                configuration: configuration(trackRuntimes: true))
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)

                func feature(_ name: String) -> Feature? {
                    result.tile.features(for: name).first
                }

                func invalid(_ name: String) -> Int? {
                    result.performance?["Integration.\(IntegrationEnvironment.databaseName).\(name)"]?.invalidFeatures
                }

                #expect(feature("point")?.geometry is Point)
                #expect(feature("multipoint")?.geometry is MultiPoint)
                #expect(feature("linestring")?.geometry is LineString)
                #expect(feature("multilinestring")?.geometry is MultiLineString)
                #expect(feature("polygon")?.geometry is Polygon)
                #expect((feature("polygon_hole")?.geometry as? Polygon)?.coordinates.count == 2)
                #expect((feature("multipolygon")?.geometry as? MultiPolygon)?.polygons.count == 2)

                #expect((feature("collection_homogeneous")?.geometry as? GeometryCollection)?.geometries.count == 2)
                #expect((feature("collection_mixed")?.geometry as? GeometryCollection)?.geometries.count == 2)
                let nested = feature("collection_nested")?.geometry as? GeometryCollection
                #expect(nested?.geometries.count == 2)
                #expect(nested?.geometries.contains { $0 is GeometryCollection } == true)

                #expect(feature("point_empty")?.geometry is MultiPoint)
                #expect((feature("point_empty")?.geometry as? MultiPoint)?.coordinates.isEmpty == true)
                #expect(invalid("point_empty") == 0)
                #expect((feature("linestring_empty")?.geometry as? LineString)?.coordinates.isEmpty == true)
                #expect((feature("polygon_empty")?.geometry as? Polygon)?.coordinates.isEmpty == true)
                #expect((feature("multipoint_empty")?.geometry as? MultiPoint)?.coordinates.isEmpty == true)
                #expect((feature("multilinestring_empty")?.geometry as? MultiLineString)?.coordinates.isEmpty == true)
                #expect((feature("multipolygon_empty")?.geometry as? MultiPolygon)?.polygons.isEmpty == true)
                #expect((feature("collection_empty")?.geometry as? GeometryCollection)?.geometries.isEmpty == true)

                #expect(feature("point_z")?.geometry is Point)
                #expect((feature("point_z")?.geometry as? Point)?.coordinate.altitude == nil)
                #expect(feature("linestring_z")?.geometry is LineString)
                #expect(feature("polygon_z")?.geometry is Polygon)
                #expect(feature("point_m")?.geometry is Point)
                #expect(feature("linestring_m")?.geometry is LineString)
                #expect(feature("polygon_m")?.geometry is Polygon)
                #expect(feature("point_zm")?.geometry is Point)
                #expect((feature("point_zm")?.geometry as? Point)?.coordinate.altitude == nil)

                #expect(feature("triangle")?.geometry is Polygon)

                #expect(feature("circularstring")?.geometry is LineString)
                #expect(feature("compoundcurve")?.geometry is LineString)
                #expect(feature("curvepolygon")?.geometry is Polygon)
                #expect(feature("multicurve")?.geometry is MultiLineString)
                #expect(feature("multisurface")?.geometry is MultiPolygon)
                #expect((feature("tin")?.geometry as? MultiPolygon)?.polygons.count == 1)
                #expect((feature("polyhedralsurface")?.geometry as? MultiPolygon)?.polygons.count == 1)

                for name in Self.ogcGeometryNames {
                    #expect(invalid(name) == 0)
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func convertsCurvedGeometriesWithStCurveToLine() async throws {
        let names = ["circularstring", "compoundcurve", "curvepolygon", "multicurve", "multisurface"]

        try await IntegrationFixture.withFixture { fixture in
            let layers = names.map { name in
                fixture.layer(
                    id: name,
                    table: "geometry_edge_cases",
                    fields: Self.ogcGeometryFields,
                    srid: .epsg4326,
                    sql: """
                    (SELECT id, name, kind, ST_CurveToLine(geom) AS geom
                     FROM "\(fixture.schema)".geometry_edge_cases
                     WHERE name = '\(name)') AS data
                    """)
            }

            try await withPostgis(
                fixture.source(layers: layers),
                configuration: configuration(trackRuntimes: true))
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                func feature(_ name: String) -> Feature? {
                    result.tile.features(for: name).first
                }
                func invalid(_ name: String) -> Int? {
                    result.performance?["Integration.\(IntegrationEnvironment.databaseName).\(name)"]?.invalidFeatures
                }

                #expect(feature("circularstring")?.geometry is LineString)
                #expect(feature("compoundcurve")?.geometry is LineString)
                #expect(feature("curvepolygon")?.geometry is Polygon)
                #expect(feature("multicurve")?.geometry is MultiLineString)
                #expect(feature("multisurface")?.geometry is MultiPolygon)
                for name in names {
                    #expect(invalid(name) == 0)
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func roundTripsSupportedGeometryTypes() async throws {
        let names = [
            "point",
            "multipoint",
            "linestring",
            "multilinestring",
            "polygon",
            "polygon_hole",
            "multipolygon",
            "point_z",
            "triangle",
            "circularstring",
            "curvepolygon",
            "multicurve",
            "multisurface",
            "tin",
            "polyhedralsurface",
        ]

        try await IntegrationFixture.withFixture { fixture in
            let layers = ogcGeometryLayers(fixture, names: names)

            try await withPostgis(
                fixture.source(layers: layers),
                configuration: configuration())
            { postgis in
                let mvt = try await postgis.data(forTile: Self.tile, format: .mvt, options: VectorTile.ExportOptions())
                let mlt = try await postgis.data(forTile: Self.tile, format: .mlt, options: VectorTile.ExportOptions())
                let mvtTile = try VectorTile(mvtData: #require(mvt.data), tile: Self.tile)
                let mltTile = try VectorTile(mltData: #require(mlt.data), tile: Self.tile)

                func isSinglePolygon(_ geometry: GeoJsonGeometry?) -> Bool {
                    if let polygon = geometry as? Polygon {
                        return polygon.coordinates.count == 1
                    }
                    if let multiPolygon = geometry as? MultiPolygon {
                        return multiPolygon.polygons.count == 1
                    }
                    return false
                }

                for tile in [mvtTile, mltTile] {
                    #expect(tile.features(for: "point").first?.geometry is Point)
                    #expect((tile.features(for: "multipoint").first?.geometry as? MultiPoint)?.coordinates.count == 2)
                    #expect(tile.features(for: "linestring").first?.geometry is LineString)
                    #expect((tile.features(for: "multilinestring").first?.geometry as? MultiLineString)?.coordinates.count == 2)
                    #expect(tile.features(for: "polygon").first?.geometry is Polygon)
                    #expect((tile.features(for: "polygon").first?.geometry as? Polygon)?.coordinates.first?.count == 5)
                    #expect((tile.features(for: "polygon_hole").first?.geometry as? Polygon)?.coordinates.count == 2)
                    #expect((tile.features(for: "multipolygon").first?.geometry as? MultiPolygon)?.polygons.count == 2)
                    #expect(tile.features(for: "point_z").first?.geometry is Point)
                    #expect((tile.features(for: "point_z").first?.geometry as? Point)?.coordinate.altitude == nil)
                    #expect(tile.features(for: "triangle").first?.geometry is Polygon)
                    #expect(tile.features(for: "circularstring").first?.geometry is LineString)
                    #expect(tile.features(for: "curvepolygon").first?.geometry is Polygon)
                    // Single-part multi-geometries may decode as their singular
                    // type or stay a one-part multi-geometry.
                    #expect(tile.features(for: "multicurve").first?.geometry is LineString)
                    #expect(isSinglePolygon(tile.features(for: "multisurface").first?.geometry))
                    #expect(isSinglePolygon(tile.features(for: "tin").first?.geometry))
                    #expect(isSinglePolygon(tile.features(for: "polyhedralsurface").first?.geometry))
                }
            }
        }
    }

    private func checkSupportedGeometryTypes(
        clipping: MVTClippingOption,
        simplification: MVTSimplificationOption,
        label: String,
    ) async throws {
        let names = [
            "point",
            "multipoint",
            "linestring",
            "multilinestring",
            "polygon",
            "polygon_hole",
            "multipolygon",
            "triangle",
        ]

        try await IntegrationFixture.withFixture { fixture in
            let layers = ogcGeometryLayers(fixture, names: names)

            try await withPostgis(
                fixture.source(layers: layers),
                configuration: configuration(
                    clipping: clipping,
                    simplification: simplification,
                    trackRuntimes: true))
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)

                for name in names {
                    #expect(result.tile.features(for: name).first?.geometry != nil, "\(label): \(name)")
                    #expect(
                        result.performance?["Integration.\(IntegrationEnvironment.databaseName).\(name)"]?.invalidFeatures == 0,
                        "\(label): \(name)",
                    )
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func postgisClippingKeepsSupportedGeometryTypes() async throws {
        try await checkSupportedGeometryTypes(
            clipping: .postgis,
            simplification: .none,
            label: "postgis clipping")
    }

    @Test(.timeLimit(.minutes(2)))
    func localClippingKeepsSupportedGeometryTypes() async throws {
        try await checkSupportedGeometryTypes(
            clipping: .local,
            simplification: .none,
            label: "local clipping")
    }

    @Test(.timeLimit(.minutes(2)))
    func localSimplificationKeepsSupportedGeometryTypes() async throws {
        try await checkSupportedGeometryTypes(
            clipping: .none,
            simplification: .local,
            label: "local simplification")
    }

    @Test(.timeLimit(.minutes(2)))
    func postgisSimplificationKeepsSupportedGeometryTypes() async throws {
        try await checkSupportedGeometryTypes(
            clipping: .none,
            simplification: .postgis(preserveCollapsed: false),
            label: "postgis simplification")
    }

    @Test(.timeLimit(.minutes(2)))
    func roundTripDropsCollectionsAndEmptyGeometries() async throws {
        let names = [
            "collection_homogeneous",
            "collection_mixed",
            "collection_nested",
            "point_empty",
            "linestring_empty",
            "polygon_empty",
            "multipoint_empty",
            "multilinestring_empty",
            "multipolygon_empty",
            "collection_empty",
        ]

        try await IntegrationFixture.withFixture { fixture in
            let layers = ogcGeometryLayers(fixture, names: names)

            try await withPostgis(
                fixture.source(layers: layers),
                configuration: configuration())
            { postgis in
                let mvt = try await postgis.data(forTile: Self.tile, format: .mvt, options: VectorTile.ExportOptions())
                let mlt = try await postgis.data(forTile: Self.tile, format: .mlt, options: VectorTile.ExportOptions())
                let mvtTile = try VectorTile(mvtData: #require(mvt.data), tile: Self.tile)
                let mltTile = try VectorTile(mltData: #require(mlt.data), tile: Self.tile)

                for tile in [mvtTile, mltTile] {
                    for name in names {
                        #expect(tile.features(for: name).isEmpty)
                    }
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func skipsNullGeometry() async throws {
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
    func postgisClippingKeepsIntersectingFeatures() async throws {
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
    func localClippingRejectsOutsideFeature() async throws {
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
    func simplificationReducesVertices() async throws {
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
    func validationMakesInvalidPolygonValid() async throws {
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
    func perLayerProjectionReprojectsFeatures() async throws {
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
    func supportsUtmProjection() async throws {
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
    func validatesSql() async throws {
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
    func featureMappingAndBufferAreApplied() async throws {
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
    func dataRoundTripsMvtAndMlt() async throws {
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
    func tileTimeoutIsReported() async throws {
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
    func cancellationIsReported() async throws {
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
                catch let error as PoolError {
                    switch error {
                    case .cancelled, .connectionFailed, .queryCancelled:
                        break
                    default:
                        Issue.record("Unexpected pool error during cancellation: \(error)")
                    }
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

    private static func integer(_ value: Sendable?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let int64 = value as? Int64 {
            return Int(exactly: int64)
        }
        if let uint64 = value as? UInt64 {
            return Int(exactly: uint64)
        }
        return nil
    }

}
