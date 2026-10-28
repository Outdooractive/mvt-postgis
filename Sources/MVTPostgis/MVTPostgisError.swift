import Foundation
import PostgresNIO

/// Possible errors thrown from the *MVTPostgis* library.
public enum MVTPostgisError: Error, Equatable, Sendable {

    /// The request was cancelled.
    case cancelled
    /// The connection to the database was unexpectedly closed.
    case connectionFailed
    /// The source doesn't contain any layers.
    case needLayers
    /// A layer has an empty id.
    case invalidLayerId
    /// The result set does not contain the configured geometry column.
    case missingGeometryColumn(layer: String, column: String)
    /// The z/x/y coordinates of the tile are invalid.
    case tileOutOfBounds
    /// The tile timed out, i.e. not all queries return in time.
    case tileTimedOut(queries: [String])
    /// The datasource uses an unsupported projection. Only planar or
    /// geographic projections with an SRID are supported.
    case unsupportedSRID
    /// The Mapnik SRS string could not be mapped to a registered projection.
    case unsupportedSRS
    /// All datasources must be of type "postgis".
    case wrongDatasourceType(message: String)
    /// XML parsing error, see `message` for more details.
    case xmlError(message: String)

}

// MARK: - CustomStringConvertible

extension MVTPostgisError: CustomStringConvertible {

    public var description: String {
        switch self {
        case .cancelled:
            return "Cancelled"

        case .connectionFailed:
            return "Connection failed"

        case .needLayers:
            return "Need layers"

        case .invalidLayerId:
            return "Invalid layer id"

        case let .missingGeometryColumn(layer, column):
            return "Missing geometry column '\(column)' in layer '\(layer)'"

        case .tileOutOfBounds:
            return "Tile out of bounds"

        case let .tileTimedOut(queries):
            let queryLines = queries.enumerated().map { index, query in
                "Query #\(index + 1):\n\(query)"
            }
            return "Tile timed out:\n\(queryLines.joined(separator: "\n"))"

        case .unsupportedSRID:
            return "Unsupported SRID"

        case .unsupportedSRS:
            return "Unsupported SRS"

        case let .wrongDatasourceType(message):
            return "Wrong datasource type: \(message)"

        case let .xmlError(message):
            return "XML error: \(message)"
        }
    }

}
