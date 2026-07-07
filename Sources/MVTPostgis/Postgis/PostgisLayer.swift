import Foundation
import GISTools

/// A vector tile layer backed by a PostGIS datasource.
///
/// Defines the layer name, fields, tile buffer size, and the associated
/// ``PostgisDatasource`` with connection parameters and SQL query.
public struct PostgisLayer: Codable, Sendable {

    /// Some layer properties.
    public struct Properties: Codable, Sendable {
        /// The buffer around a tile in pixels.
        public let bufferSize: Int
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

}
