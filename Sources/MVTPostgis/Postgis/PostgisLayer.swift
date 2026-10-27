import Foundation
import GISTools

/// A vector tile layer backed by a PostGIS datasource.
///
/// Defines the layer name, fields, tile buffer size, and the associated
/// ``PostgisDatasource`` with connection parameters and SQL query.
public struct PostgisLayer: Codable, Sendable {

    /// Some layer properties.
    public struct Properties: Codable, Sendable {

        /// The buffer around a tile in pixels. Negative values are clamped to zero.
        public let bufferSize: Int

        /// Creates layer properties.
        /// - Parameter bufferSize: The buffer around a tile in pixels.
        public init(bufferSize: Int = 0) {
            self.bufferSize = max(0, bufferSize)
        }

        private enum CodingKeys: String, CodingKey {

            case bufferSize

        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let bufferSize = try container.decodeIfPresent(Int.self, forKey: .bufferSize) ?? 0
            self.init(bufferSize: bufferSize)
        }

    }

    // MARK: -

    /// The layer's name.
    public let id: String
    /// The layer's description, mostly interesting for viewers.
    public let description: String?
    /// The SQL fields from the query with a description. Must be complete.
    public let fields: [String: String]
    /// Some layer properties.
    public let properties: Properties

    /// The layer's datasource.
    public let datasource: PostgisDatasource

    /// Creates a layer definition.
    public init(
        id: String,
        description: String? = nil,
        fields: [String: String] = [:],
        properties: Properties = Properties(),
        datasource: PostgisDatasource,
    ) {
        self.id = id
        self.description = description
        self.fields = fields
        self.properties = properties
        self.datasource = datasource
    }

    private enum CodingKeys: String, CodingKey {

        case id, description, fields, properties, datasource

    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.fields = try container.decodeIfPresent([String: String].self, forKey: .fields) ?? [:]
        self.properties = try container.decodeIfPresent(Properties.self, forKey: .properties) ?? Properties()
        self.datasource = try container.decode(PostgisDatasource.self, forKey: .datasource)
    }

}
