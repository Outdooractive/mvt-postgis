import Foundation
import GISTools

/// A  datasource, part of Postgis layers.
public struct PostgisDatasource: Codable {

    /// The PostgreSQL user.
    public let user: String
    /// The PostgreSQL password.
    public let password: String
    /// The PostgreSQL hostname.
    public let host: String
    /// The PostgreSQL port.
    public let port: Int

    /// The database name.
    public let databaseName: String
    /// The name of the geometry field to use.
    public let geometryField: String

    /// The extent of the datasource.
    public let boundingBox: BoundingBox?
    /// The datasource's SRID.
    public let srid: Projection
    /// The datasource's type. MUST be ' postgis' for now.
    public let type: String
    /// The SQL query.
    public let sql: String

}
