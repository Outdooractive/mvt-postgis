import Foundation
import GISTools

/// A PostGIS datasource with connection parameters and SQL query.
///
/// Defines how to connect to a PostgreSQL database and what query to execute
/// to retrieve features. Part of a ``PostgisLayer``.
public struct PostgisDatasource: Codable, Sendable {

    /// The PostgreSQL user.
    public let user: String
    /// The PostgreSQL password. May be empty when the server uses trust or
    /// another passwordless authentication method.
    public let password: String
    /// The PostgreSQL hostname.
    public let host: String
    /// The PostgreSQL port.
    public let port: Int

    /// The database name.
    public let databaseName: String
    /// The name of the geometry field to use. Default is `"geometry"`.
    public let geometryField: String?

    /// The extent of the datasource.
    public let boundingBox: BoundingBox?
    /// The datasource's SRID.
    public let srid: Projection
    /// The datasource's type. Must be `"postgis"`.
    public let type: String
    /// The SQL query.
    public let sql: String

    /// Creates a datasource definition.
    public init(
        user: String,
        password: String = "",
        host: String,
        port: Int = 5432,
        databaseName: String,
        geometryField: String? = nil,
        boundingBox: BoundingBox? = nil,
        srid: Projection,
        type: String,
        sql: String,
    ) {
        self.user = user
        self.password = password
        self.host = host
        self.port = port
        self.databaseName = databaseName
        self.geometryField = geometryField
        self.boundingBox = boundingBox
        self.srid = srid
        self.type = type
        self.sql = sql
    }

    private enum CodingKeys: String, CodingKey {

        case user, password, host, port, databaseName, geometryField, boundingBox, srid, type, sql

    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.user = try container.decode(String.self, forKey: .user)
        self.password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        self.host = try container.decode(String.self, forKey: .host)
        self.port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 5432
        self.databaseName = try container.decode(String.self, forKey: .databaseName)
        self.geometryField = try container.decodeIfPresent(String.self, forKey: .geometryField)
        self.boundingBox = try container.decodeIfPresent(BoundingBox.self, forKey: .boundingBox)
        self.srid = try container.decode(Projection.self, forKey: .srid)
        self.type = try container.decode(String.self, forKey: .type)
        self.sql = try container.decode(String.self, forKey: .sql)
    }

}
