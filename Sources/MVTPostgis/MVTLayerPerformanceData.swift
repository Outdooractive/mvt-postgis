import Foundation

/// Statistics about the performance of a single PostGIS layer query.
public struct MVTLayerPerformanceData: Sendable {

    /// The total query runtime (Postgis + parsing).
    public let runtime: TimeInterval
    /// The received WKB geometry bytes from the db server.
    public let wkbBytes: Int64
    /// The number of features in a layer.
    public let features: Int
    /// The number of invalid features in a layer.
    public let invalidFeatures: Int
    /// The SQL query used.
    public let sqlQuery: String

    /// Creates a performance data record.
    /// - Parameters:
    ///   - runtime: The total query runtime in seconds (PostGIS + parsing).
    ///   - wkbBytes: The total WKB geometry bytes received from the database.
    ///   - features: The number of features returned.
    ///   - invalidFeatures: The number of features that could not be parsed.
    ///   - sqlQuery: The SQL query that was executed.
    public init(
        runtime: TimeInterval,
        wkbBytes: Int64,
        features: Int,
        invalidFeatures: Int,
        sqlQuery: String
    ) {
        self.runtime = runtime
        self.wkbBytes = wkbBytes
        self.features = features
        self.invalidFeatures = invalidFeatures
        self.sqlQuery = sqlQuery
    }

}
