import Foundation
import GISTools

/// A Postgis source as parsed from a Mapnik YML or XML file.
public struct PostgisSource {

    public let name: String
    public let description: String
    public let attribution: String

    public let center: Coordinate3D

    public let defaultZoom: Int
    public let minZoom: Int
    public let maxZoom: Int

    public let layers: [PostgisLayer]

    /// Load a source from an URL, can be either Mapnik YML or XML.
    public static func load(
        from url: URL,
        layerWhitelist: [String]?)
        throws -> PostgisSource
    {
        let data = try Data(contentsOf: url)
        return try load(from: data, layerWhitelist: layerWhitelist)
    }

    /// Load a source from an URL, can be either Mapnik YML or XML.
    public static func load(
        from data: Data,
        layerWhitelist: [String]?)
        throws -> PostgisSource
    {
        if data.starts(with: [0x3C, 0x3F, 0x78, 0x6D, 0x6C, 0x20]) {
            return try MapnikXMLSource.load(from: data, layerAllowlist: layerWhitelist ?? [])
        }
        else {
            return try MapnikYMLSource.load(from: data, layerAllowlist: layerWhitelist ?? [])
        }
    }

}
