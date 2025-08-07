import Foundation
import GISTools

/// A Postgis source, from JSON or as parsed from a Mapnik YML or XML file.
public struct PostgisSource: Codable {

    /// The source's name.
    public let name: String
    /// The source's description.
    public let description: String
    /// Attribution/copyright.
    public let attribution: String

    /// The default center coordinate, mostly interesting for viewers.
    public let center: Coordinate3D
    /// The default zoom level, mostly interesting for viewers.
    public let defaultZoom: Int

    /// The source's minimum zoom level.
    public let minZoom: Int
    /// The source's maximum zoom level.
    public let maxZoom: Int

    /// The source's layers with the Postgis configuration and SQL.
    public let layers: [PostgisLayer]

    // MARK: -

    /// Load a source from an URL, can either be JSON, or Mapnik YML or XML.
    public static func load(
        from url: URL,
        layerWhitelist: [String]?
    ) throws -> PostgisSource {
        let data = try Data(contentsOf: url)
        return try load(from: data, layerWhitelist: layerWhitelist)
    }

    /// Load a source from a Data object, can either be JSON, or Mapnik YML or XML.
    public static func load(
        from data: Data,
        layerWhitelist: [String]?
    ) throws -> PostgisSource {
        if data.starts(with: [0x7B]) {
            return try JSONDecoder().decode(PostgisSource.self, from: data)
        }
        else if data.starts(with: [0x3C, 0x3F, 0x78, 0x6D, 0x6C, 0x20]) {
            return try MapnikXMLSource.load(from: data, layerAllowlist: layerWhitelist ?? [])
        }
        else {
            return try MapnikYMLSource.load(from: data, layerAllowlist: layerWhitelist ?? [])
        }
    }

}
