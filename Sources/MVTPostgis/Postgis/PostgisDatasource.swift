import Foundation

/// A  datasource, part of Postgis layers.
public struct PostgisDatasource {

    public let user: String
    public let password: String
    public let host: String
    public let port: Int

    public let databaseName: String
    public let geometryField: String
    public let geometryTable: String
    public let keyField: String
    public let keyFieldAsAttribute: String

    public let extent: String
    public let srid: String
    public let type: String
    public let maxSize: Int
    public let sql: String

}
