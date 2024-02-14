import Foundation

/// Global configuration for the MVT Postgis adapter.
public struct MVTPostgisConfiguration {

    /// The name used for database connections and the default logger (default: 'MVTPostgis').
    public let applicationName: String

    /// Timeout for opening new connections to the PostgreSQL database, in seconds (default: 5 seconds).
    public let connectTimeout: TimeInterval

    /// TImeout for individual database queries, in seconds (default: 10 seconds).
    /// Can be disabled by setting to `nil`.
    public let queryTimeout: TimeInterval?

    /// Timeout for one tile, i.e. the time in which one tile must be finished, in seconds.
    public let tileTimeout: TimeInterval

    /// The pool size, per database. Each database connection is backed by a pool of this size (default: 10).
    public let poolSize: Int

    /// The maximum number of idle connections (over a 60 seconds period).
    public let maxIdleConnections: Int?

    /// Controls if and where the clipping of features happens.
    public let clipping: ((_ zoom: Int, _ source: PostgisSource) -> MVTClippingOption)

    /// Controls if and how much features are simplified.
    public let simplification: ((_ zoom: Int, _ source: PostgisSource) -> MVTSimplificationOption)

    /// Track SQL runtimes and return them together with the vector tile.
    public let trackRuntimes: Bool

    public init(
        applicationName: String = "MVTPostgis",
        connectTimeout: TimeInterval = 5.0,
        queryTimeout: TimeInterval? = 10.0,
        tileTimeout: TimeInterval = 60.0,
        poolSize: Int = 10,
        maxIdleConnections: Int? = nil,
        clipping: @escaping ((_ zoom: Int, _ source: PostgisSource) -> MVTClippingOption) = { _,_  in .postgis },
        simplification: @escaping ((_ zoom: Int, _ source: PostgisSource) -> MVTSimplificationOption) = { _,_  in .none },
        trackRuntimes: Bool = false)
    {
        self.applicationName = applicationName
        self.connectTimeout = connectTimeout.atLeast(1.0)
        self.queryTimeout = queryTimeout?.atLeast(1.0)
        self.tileTimeout = tileTimeout.atLeast(1.0)
        self.poolSize = poolSize.atLeast(1)
        self.maxIdleConnections = maxIdleConnections?.atLeast(0)
        self.clipping = clipping
        self.simplification = simplification
        self.trackRuntimes = trackRuntimes
    }

}

// MARK: - Clipping

/// Controls if and where the clipping of features happens.
public enum MVTClippingOption {

    /// No clipping, all features are added to the vector tile as they come from
    /// the database. Clipping will then be done when serializing the tile.
    /// Note: Might lead to memory explosion.
    case none
    /// Do the clipping in Postgis with `ST_ClipByBox2D`.
    case postgis
    /// Do the clipping locally, before adding features to the vector tile.
    case local

}

// MARK: - Simplification

/// Controls if and how much features are simplified.
public enum MVTSimplificationOption {

    /// No simplification will be done.
    case none
    /// Do the simplification locally, before adding features to the vector tile.
    case local
    /// Do the simplification in Postgis with `ST_Simplify`.
    case postgis(preserveCollapsed: Bool)
    /// Simplification distance in meters, forwarded to `ST_Simplify`.
    case meters(Double, preserveCollapsed: Bool)

}
