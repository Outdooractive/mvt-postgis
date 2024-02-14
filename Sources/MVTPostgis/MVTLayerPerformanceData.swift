import Foundation

/// Some statistics about query performance of one (Postgis) layer.
public struct MVTLayerPerformanceData {

    /// The total query runtime (Postgis + parsing).
    public let runtime: TimeInterval
    /// The received WKB geometry bytes from the db server.
    public let wkbBytes: Int64
    /// The number of features in a layer.
    public let features: Int
    /// The number of invslid features in a layer.
    public let invalidFeatures: Int

    public init(
        runtime: TimeInterval,
        wkbBytes: Int64,
        features: Int,
        invalidFeatures: Int)
    {
        self.runtime = runtime
        self.wkbBytes = wkbBytes
        self.features = features
        self.invalidFeatures = invalidFeatures
    }

}
