import Foundation
import GISTools

/// A  Layer, part of a Postgis source.
public struct PostgisLayer: Codable {

    /// Some layer properties.
    public struct Properties: Codable {
        /// The buffer around a tile in pixels.
        public let bufferSize: Int
    }

    // MARK: -

    /// The layer's name.
    public let id: String
    /// The layer's description, mostly interesting for viewers.
    public let description: String?
    /// The SQL fields from the query. Must be complete.
    public let fields: [String: String]
    /// Some layer properties.
    public let properties: Properties

    /// The layer's datasource.
    public let datasource: PostgisDatasource

}
