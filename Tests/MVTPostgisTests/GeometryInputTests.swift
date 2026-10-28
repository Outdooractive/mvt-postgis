import Foundation
import GISTools
@testable import MVTPostgis
import Testing

struct GeometryInputTests {

    private static func data(hex: String) -> Data? {
        var bytes: [UInt8] = []
        var index = hex.startIndex

        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else {
                return nil
            }

            bytes.append(byte)
            index = next
        }

        return Data(bytes)
    }

    @Test
    func decodesPlainAndExtendedWKB() throws {
        // PostGIS: ST_AsBinary('POINT(1 2)'::geometry)
        let plain = try #require(Self.data(hex: "0101000000000000000000F03F0000000000000040"))
        // PostGIS: ST_AsEWKB('POINT(1 2)'::geometry)
        let extended = try #require(Self.data(hex: "0101000020E6100000000000000000F03F0000000000000040"))

        for data in [plain, extended] {
            let feature = try #require(
                Feature(
                    wkb: data,
                    sourceProjection: .epsg4326,
                    targetProjection: .epsg4326),
            )

            let point = try #require(feature.geometry as? Point)
            #expect(point.coordinate.longitude == 1)
            #expect(point.coordinate.latitude == 2)
        }
    }

    @Test
    func decodesHexEWKB() throws {
        let data = try #require(Self.data(hex: "0101000020E6100000000000000000F03F0000000000000040"))
        let feature = try #require(
            Feature(
                wkb: data,
                sourceProjection: .epsg4326,
                targetProjection: .epsg4326),
        )

        #expect(feature.geometry is Point)
    }

}
