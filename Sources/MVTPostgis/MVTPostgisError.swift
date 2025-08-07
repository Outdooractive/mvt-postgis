import Foundation
import PostgresNIO

/// Possible errors thrown from the *MVTPostgis* library.
public enum MVTPostgisError: Error {

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
