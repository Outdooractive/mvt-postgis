import Foundation
import PostgresNIO
import PostgresConnectionPool

actor PoolDistributor {

    private var pools: [String: PostgresConnectionPool] = [:]

    private let logger: Logger
    private let configuration: MVTPostgisConfiguration

    init(configuration: MVTPostgisConfiguration, logger: Logger) {
        self.logger = logger
        self.configuration = configuration
    }

    func pool(forLayer layer: PostgisLayer) async -> PostgresConnectionPool {
        if let pool = pools[layer.uniqueDatabaseKey] {
            return pool
        }

        let postgresConfiguration = PostgresConnection.Configuration(
            host: layer.datasource.host,
            port: layer.datasource.port,
            username: layer.datasource.user,
            password: layer.datasource.password,
            database: layer.datasource.databaseName,
            tls: .disable)
        let poolConfiguration = PoolConfiguration(
            applicationName: configuration.applicationName,
            postgresConfiguration: postgresConfiguration,
            connectTimeout: configuration.connectTimeout,
            queryTimeout: configuration.queryTimeout,
            poolSize: configuration.poolSize,
            maxIdleConnections: configuration.maxIdleConnections,
            onOpenConnection: { connection, logger in
                try await connection.query(PostgresQuery(stringLiteral: "SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY"), logger: logger)
            })

        // Note: Do not make PostgresConnectionPool.init async,
        // or there will be a race condition here.
        let pool = PostgresConnectionPool(configuration: poolConfiguration, logger: logger)
        pools[layer.uniqueDatabaseKey] = pool
        return pool
    }

    func connection(
        forLayer layer: PostgisLayer,
        batchId: Int,
        callback: @Sendable (PostgresConnectionWrapper) async throws -> Void
    ) async throws {
        let pool = await pool(forLayer: layer)

        do {
            try await pool.connection(batchId: batchId, callback)

            if Task.isCancelled {
                await abortBatch(batchId)
                throw MVTPostgisError.cancelled
            }
        }
        catch PoolError.cancelled {
            await abortBatch(batchId)
            throw MVTPostgisError.cancelled
        }
        catch {
            await abortBatch(batchId)

            logger.debug("Layer '\(layer.id)': Failed to get a connection for batchId '\(batchId)': \(error)")

            throw error
        }
    }

    func abortBatch(_ batchId: Int) async {
        for pool in pools.values {
            await pool.abortBatch(batchId)
        }
    }

    /// Forcibly close all idle connections in all pools.
    func closeIdleConnections() async {
        for pool in pools.values {
            await pool.closeIdleConnections()
        }
    }

    /// It's actually no problem to continue the PoolDistributor after calling shutdown(),
    /// `shutdown` will just close all pools.
    func shutdown() async {
        for pool in pools.values {
            await pool.shutdown()
        }
        pools.removeAll()
    }

    func poolInfos(batchId: Int? = nil) async -> [PoolInfo] {
        var poolInfos: [PoolInfo] = []
        for pool in pools.values {
            let poolInfo = await pool.poolInfo(batchId: batchId)
            poolInfos.append(poolInfo)
        }
        return poolInfos
    }

}

fileprivate extension PostgisLayer {

    var uniqueDatabaseKey: String {
        [
            datasource.host,
            String(datasource.port),
            datasource.user,
            datasource.databaseName
        ].joined(separator: ",")
    }

}
