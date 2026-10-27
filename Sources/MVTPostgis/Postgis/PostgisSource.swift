import Foundation
import GISTools

/// A datasource definition parsed from JSON, Mapnik YML, or Mapnik XML.
///
/// Contains the source metadata (name, attribution, center, zoom range) and
/// an array of ``PostgisLayer`` instances, each with its own ``PostgisDatasource``.
public struct PostgisSource: Codable, Sendable {

    /// The file format the source was parsed from.
    public enum Origin: String, Codable, Sendable {

        /// JSON.
        case json
        /// Mapnik YML.
        case yml
        /// Mapnik XML.
        case xml

    }

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

    /// The source's layers with the PostGIS configuration and SQL.
    public let layers: [PostgisLayer]

    /// The file format this source was parsed from.
    public private(set) var origin: Origin

    /// Creates a source definition.
    public init(
        name: String,
        description: String = "",
        attribution: String = "",
        center: Coordinate3D = .zero,
        defaultZoom: Int = 14,
        minZoom: Int = 0,
        maxZoom: Int = 20,
        layers: [PostgisLayer],
        origin: Origin = .json,
    ) {
        self.name = name
        self.description = description
        self.attribution = attribution
        self.center = center
        self.defaultZoom = defaultZoom
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.layers = layers
        self.origin = origin
    }

    // MARK: -

    /// Load a source from a URL. The file can be JSON, Mapnik YML, or Mapnik XML.
    ///
    /// - Parameters:
    ///   - url: The source file URL.
    ///   - layerAllowlist: Optional list of layer names to include. When `nil`
    ///     or empty, all layers are included.
    /// - Returns: The parsed source.
    /// - Throws: Decoding or XML parsing errors.
    public static func load(
        from url: URL,
        layerAllowlist: [String]?,
    ) throws -> PostgisSource {
        let data = try Data(contentsOf: url)
        return try load(from: data, layerAllowlist: layerAllowlist)
    }

    /// Load a source from raw data. The data can be JSON, Mapnik YML, or Mapnik XML.
    ///
    /// - Parameters:
    ///   - data: The raw source data.
    ///   - layerAllowlist: Optional list of layer names to include. When `nil`
    ///     or empty, all layers are included.
    /// - Returns: The parsed source.
    /// - Throws: Decoding or XML parsing errors.
    public static func load(
        from data: Data,
        layerAllowlist: [String]?,
    ) throws -> PostgisSource {
        let payload = data.trimmingLeadingConfigurationWhitespace()

        if payload.first == 0x7B {
            var source = try JSONDecoder().decode(PostgisSource.self, from: payload)
            source.origin = .json

            guard let layerAllowlist,
                  layerAllowlist.isNotEmpty
            else { return source }

            return PostgisSource(
                name: source.name,
                description: source.description,
                attribution: source.attribution,
                center: source.center,
                defaultZoom: source.defaultZoom,
                minZoom: source.minZoom,
                maxZoom: source.maxZoom,
                layers: source.layers.filter { layerAllowlist.contains($0.id) },
                origin: .json)
        }
        else if payload.first == 0x3C {
            return try MapnikXMLSource.load(from: payload, layerAllowlist: layerAllowlist ?? [])
        }
        else {
            return try MapnikYMLSource.load(from: payload, layerAllowlist: layerAllowlist ?? [])
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {

        case name, description, attribution, center, defaultZoom, minZoom, maxZoom, layers

    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.attribution = try container.decodeIfPresent(String.self, forKey: .attribution) ?? ""
        self.center = try container.decodeIfPresent(Coordinate3D.self, forKey: .center) ?? .zero
        self.defaultZoom = try container.decodeIfPresent(Int.self, forKey: .defaultZoom) ?? 14
        self.minZoom = try container.decodeIfPresent(Int.self, forKey: .minZoom) ?? 0
        self.maxZoom = try container.decodeIfPresent(Int.self, forKey: .maxZoom) ?? 20
        self.layers = try container.decodeIfPresent([PostgisLayer].self, forKey: .layers) ?? []
        self.origin = .json
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(attribution, forKey: .attribution)
        try container.encode(center, forKey: .center)
        try container.encode(defaultZoom, forKey: .defaultZoom)
        try container.encode(minZoom, forKey: .minZoom)
        try container.encode(maxZoom, forKey: .maxZoom)
        try container.encode(layers, forKey: .layers)
    }

}

// MARK: - Private

extension Data {

    /// Removes a UTF-8 BOM and leading whitespace before format detection.
    fileprivate func trimmingLeadingConfigurationWhitespace() -> Data {
        var bytes = [UInt8](self)
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            bytes.removeFirst(3)
        }
        let start = bytes.firstIndex { byte in
            byte != 0x20 && byte != 0x09 && byte != 0x0A && byte != 0x0D
        } ?? bytes.endIndex
        return Data(bytes[start...])
    }

}
