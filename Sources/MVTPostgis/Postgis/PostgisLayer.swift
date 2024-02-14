import Foundation

/// A  Layer, part of a Postgis source.
public struct PostgisLayer {

    public let id: String
    public let description: String
    public let srs: String
    public let fields: [String: String]

    public let datasource: PostgisDatasource

    /// The buffer around a tile in pixels.
    public let bufferSize: Int

}
