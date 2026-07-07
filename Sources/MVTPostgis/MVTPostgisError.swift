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
    /// The z/x/y coordinates of the tile are invalid.
    case tileOutOfBounds
    /// The tile timed out, i.e. not all queries return in time.
    case tileTimedOut(queries: [String])
    /// This library only supports EPSG:3857 and EPSG:4326.
    case unsupportedSRID
    /// This library only supports EPSG:3857 and EPSG:4326.
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
        case .tileOutOfBounds:
            return "Tile out of bounds"
        case .tileTimedOut(let queries):
            let queryLines = queries.enumerated().map { index, query in
                "Query #\(index + 1):\n\(query)"
            }
            return "Tile timed out:\n\(queryLines.joined(separator: "\n"))"
        case .unsupportedSRID:
            return "Unsupported SRID"
        case .unsupportedSRS:
            return "Unsupported SRS"
        case .wrongDatasourceType(let message):
            return "Wrong datasource type: \(message)"
        case .xmlError(let message):
            return "XML error: \(message)"
        }
    }

}
