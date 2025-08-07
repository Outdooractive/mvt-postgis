import Foundation

/// Some statistics about query performance of one (Postgis) layer.
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
