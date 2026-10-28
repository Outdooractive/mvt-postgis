import Foundation
import GISTools
@testable import MVTPostgis
import MVTTools
import Testing

struct GenerativeTests {

    private struct SeededGenerator: RandomNumberGenerator {

        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }

    }

    private static let tile = MapTile(x: 8715, y: 5688, z: 14)

    private func randomCoordinate(using generator: inout SeededGenerator) -> Coordinate3D {
        Coordinate3D(
            latitude: Double.random(in: 48.094 ... 48.106, using: &generator),
            longitude: Double.random(in: 11.493 ... 11.512))
    }

    private func randomPoint(using generator: inout SeededGenerator) -> Point {
        Point(randomCoordinate(using: &generator))
    }

    private func randomLineString(using generator: inout SeededGenerator) -> LineString {
        let count = Int.random(in: 2 ... 6, using: &generator)
        let coordinates = (0 ..< count).map { _ in randomCoordinate(using: &generator) }
        return LineString(coordinates) ?? LineString()
    }

    private func randomPolygon(using generator: inout SeededGenerator) -> Polygon {
        let origin = randomCoordinate(using: &generator)
        let width = Double.random(in: 0.0001 ... 0.001, using: &generator)
        let height = Double.random(in: 0.0001 ... 0.001, using: &generator)

        let ring = [
            origin,
            Coordinate3D(
                latitude: origin.latitude,
                longitude: origin.longitude + width),
            Coordinate3D(
                latitude: origin.latitude + height,
                longitude: origin.longitude + width),
            Coordinate3D(
                latitude: origin.latitude + height,
                longitude: origin.longitude),
            origin,
        ]

        guard let ring = Ring(ring) else { return Polygon() }

        return Polygon([ring]) ?? Polygon()
    }

    @Test
    func randomGeometriesSurviveWKBRoundTrip() throws {
        var generator = SeededGenerator(seed: 0xC0FF_EE00)

        for index in 0 ..< 60 {
            let geometry: GeoJsonGeometry =
                switch index % 3 {
                case 0: randomPoint(using: &generator)
                case 1: randomLineString(using: &generator)
                default: randomPolygon(using: &generator)
                }

            let data = try #require(geometry.asWKB)
            let feature = try #require(
                Feature(
                    wkb: data,
                    sourceProjection: .epsg4326,
                    targetProjection: .epsg4326),
            )

            #expect(feature.geometry != nil)
            #expect(feature.geometry?.allCoordinates.allSatisfy {
                $0.longitude.isFinite && $0.latitude.isFinite
            } == true)
            #expect(feature.geometry?.allCoordinates.count == geometry.allCoordinates.count)
        }
    }

    @Test
    func randomFeaturesSurviveMVTAndMLTRoundTrip() throws {
        var generator = SeededGenerator(seed: 0xBAD5EED)

        var features: [Feature] = []
        for _ in 0 ..< 10 {
            let geometry: GeoJsonGeometry =
                switch Int.random(in: 0 ... 2, using: &generator) {
                case 0: randomPoint(using: &generator)
                case 1: randomLineString(using: &generator)
                default: randomPolygon(using: &generator)
                }

            features.append(
                Feature(
                    geometry,
                    id: .int(Int.random(in: 0 ... 1000, using: &generator)),
                    properties: [
                        "index": Int.random(in: -1000 ... 1000, using: &generator),
                        "ratio": Double.random(in: 0 ... 1, using: &generator),
                        "flag": Bool.random(using: &generator),
                        "label": "value-\(Int.random(in: 0 ... 100, using: &generator))",
                    ]))
        }

        var tile = try VectorTile(
            x: Self.tile.x,
            y: Self.tile.y,
            z: Self.tile.z,
            projection: .epsg4326)
        let added = tile.setFeatures(features, for: "generated")
        #expect(added)

        let mvt = try #require(tile.mvtData())
        let mlt = try #require(tile.mltData())
        let mvtTile = try VectorTile(mvtData: mvt, tile: Self.tile)
        let mltTile = try VectorTile(mltData: mlt, tile: Self.tile)

        for decoded in [mvtTile, mltTile] {
            let decodedFeatures = decoded.features(for: "generated")
            #expect(decodedFeatures.count == features.count)

            for feature in decodedFeatures {
                #expect(feature.id != nil)
                #expect(feature.properties["index"] != nil)
                #expect(feature.properties["ratio"] != nil)
                #expect(feature.properties["flag"] != nil)
                #expect(feature.properties["label"] != nil)
            }
        }
    }

    @Test
    func randomBytesNeverCrashWKBParser() {
        var generator = SeededGenerator(seed: 0xDEAD_BEEF)

        for _ in 0 ..< 500 {
            let count = Int.random(in: 0 ... 64, using: &generator)
            let data = Data((0 ..< count).map { _ in
                UInt8.random(in: 0 ... 255, using: &generator)
            })

            _ = Feature(
                wkb: data,
                sourceProjection: .epsg4326,
                targetProjection: .epsg4326)
        }
    }

    @Test
    func randomSourceDocumentsFailCleanly() {
        var generator = SeededGenerator(seed: 0x5EED_1234)

        for _ in 0 ..< 200 {
            let count = Int.random(in: 0 ... 200, using: &generator)
            let data = Data((0 ..< count).map { _ in
                UInt8.random(in: 0 ... 255, using: &generator)
            })

            _ = try? PostgisSource.load(from: data, layerAllowlist: nil)
        }

        // Valid documents truncated at every byte boundary must not crash.
        let json = """
        {"name":"n","layers":[{"id":"l","fields":{},"datasource":{
        "user":"u","host":"h","databaseName":"d","srid":4326,
        "type":"postgis","sql":"SELECT 1"}}]}
        """
        let yml = """
        name: n
        layers:
          - id: l
            fields: {}
            datasource:
              user: u
              host: h
              databaseName: d
              srid: 4326
              type: postgis
              sql: SELECT 1
        """
        let xml = """
        <Map><Layer name="l"><Datasource><Parameter name="type">postgis</Parameter>
        </Datasource></Layer></Map>
        """

        for document in [json, yml, xml] {
            let data = Data(document.utf8)
            for length in stride(from: 0, through: data.count, by: 7) {
                _ = try? PostgisSource.load(
                    from: data.prefix(length),
                    layerAllowlist: nil)
            }
        }
    }

    @Test
    func queryBuilderHandlesUnusualSQLWithoutCrashing() {
        var generator = SeededGenerator(seed: 0x1234_ABCD)
        let fragments = [
            "SELECT 1",
            "!bbox!",
            "!scale_denominator!",
            "!pixel_width!",
            "-- comment",
            "'literal'",
            "\"quoted\"",
            "WITH cte AS (SELECT 1)",
            "(",
            ")",
            ";",
            "UNION ALL",
        ]

        let layer = PostgisLayer(
            id: "generated",
            fields: ["name": ""],
            datasource: PostgisDatasource(
                user: "u",
                host: "h",
                databaseName: "d",
                srid: .epsg4326,
                type: "postgis",
                sql: "SELECT 1 AS name"))

        for _ in 0 ..< 200 {
            let fragmentCount = Int.random(in: 0 ... 5, using: &generator)
            let sql = (0 ..< fragmentCount)
                .lazy
                .map { _ in fragments.randomElement(using: &generator) ?? "" }
                .joined(separator: " ")

            let builder = PostgisQueryBuilder(
                layer: layer,
                sql: sql,
                envelope: "ENVELOPE",
                simplificationTolerance: 1.0,
                clipping: .none,
                simplification: .none,
                validation: .none)
            #expect(builder.query.hasPrefix("SELECT "))
        }
    }

}
