import Foundation
import GISTools

/// A PostGIS datasource with connection parameters and SQL query.
///
/// Defines how to connect to a PostgreSQL database and what query to execute
/// to retrieve features. Part of a ``PostgisLayer``.
public struct PostgisDatasource: Codable, Sendable {

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
    /// The name of the geometry field to use. Default is 'geometry'.
    public let geometryField: String?

    /// The extent of the datasource.
    public let boundingBox: BoundingBox?
    /// The datasource's SRID.
    public let srid: Projection
    /// The datasource's type. MUST be ' postgis' for now.
    public let type: String
    /// The SQL query.
    public let sql: String

}
