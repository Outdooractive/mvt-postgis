import Foundation
import GISTools

/// A  Layer, part of a Postgis source.
public struct PostgisLayer: Codable {

    public struct Properties: Codable {

        /// The buffer around a tile in pixels.
        public let bufferSize: Int

    }

    // MARK: -

    public let id: String
    public let description: String
    public let projection: Projection
    public let fields: [String: String]
    public let properties: Properties

    public let datasource: PostgisDatasource


}
