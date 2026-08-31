import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PostgresNIO
import PostgresConnectionPool

actor PoolDistributor {

    private var pools: [String: PostgresConnectionPool] = [:]

    /// Databases with a pool recreation currently in flight. While the flag
    /// is set, all other requests are handed the dead pool and fail fast —
    /// this closes an actor-reentrancy race where parallel requests could
    /// each recreate simultaneously.
    private var recreating: Set<String> = []

    private let logger: Logger
    private let configuration: MVTPostgisConfiguration

    init(configuration: MVTPostgisConfiguration, logger: Logger) {
        self.logger = logger
        self.configuration = configuration
    }

    func pool(forLayer layer: PostgisLayer) async -> PostgresConnectionPool {
        if let pool = pools[layer.uniqueDatabaseKey] {
            // A pool that shut itself down (e.g. after a PostGIS restart was
            // in progress when a connection was attempted — the pool treats
            // connection errors as fatal) never recovers on its own: every
            // later request would throw `poolDestroyed` forever.
            if await !pool.isShutdown {
                return pool
            }

            // The pool is dead. Recreating it allocates a new event loop
            // group (one kqueue/epoll fd per thread), so recreation must be
            // strictly bounded during an outage or the process dies with
            // "Too many open files". Two guards:
            //
            // 1. While a recreation is already in flight (the actor is
            //    suspended in the probe or pool shutdown below), other
            //    requests reuse the dead pool and fail fast (zero fd cost).
            // 2. Recreation only happens after a cheap TCP probe confirms
            //    the database actually accepts connections again — probing
            //    costs one socket, recreating blind costs an event loop
            //    group per attempt. Fail-fast + succeed-on-next-probe means
            //    an outage produces at most one pool per reachability flip.
            let key = layer.uniqueDatabaseKey
            if recreating.contains(key) {
                return pool
            }
            recreating.insert(key)
            defer { recreating.remove(key) }

            let reachable = await Self.isReachable(
                host: layer.datasource.host,
                port: layer.datasource.port,
                timeout: configuration.connectTimeout)
            guard reachable else {
                // Database still down. Keep the (already fully shut down)
                // pool; requests fail fast with `poolDestroyed` until the
                // next probe succeeds.
                logger.info("Database '\(key)' is unreachable, not recreating its pool yet")
                return pool
            }

            logger.info("Database '\(key)' is reachable again, recreating its shut-down pool")

            // Close the old pool before replacing it so nothing leaks.
            await pool.shutdown()
            pools[key] = nil
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
        // The pool can shut itself down at any moment (database outage —
        // connection errors are treated as fatal by `PostgresConnectionPool`
        // and permanently disable it). One retry through `pool(forLayer:)`
        // covers a race where the pool dies after being fetched: that
        // method detects the shut-down pool, probes the database, and
        // rebuilds the pool once it is reachable again.
        do {
            try await self.connectionOnce(forLayer: layer, batchId: batchId, callback: callback)
        }
        catch PoolError.poolDestroyed {
            logger.warning("Layer '\(layer.id)': Connection pool was destroyed (database outage?), retrying once with a new pool")

            try await self.connectionOnce(forLayer: layer, batchId: batchId, callback: callback)

            if Task.isCancelled {
                await abortBatch(batchId)
                throw MVTPostgisError.cancelled
            }
        }
    }

    /// Single connection attempt, no pool-recreation retry.
    private func connectionOnce(
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

    // MARK: - Reachability probe

    /// Cheap TCP connectivity check used before recreating a shut-down pool.
    ///
    /// A probe allocates exactly one socket that is closed immediately —
    /// orders of magnitude cheaper than constructing a pool (whose event
    /// loop group alone holds one kqueue/epoll fd per thread), so an outage
    /// can never exhaust file descriptors here. The probe uses a plain
    /// POSIX socket: `getaddrinfo` + non-blocking `connect` + `poll` for
    /// writability, then `SO_ERROR` to distinguish success from failure.
    static func isReachable(
        host: String,
        port: Int,
        timeout: TimeInterval
    ) async -> Bool {
        // SOCK_STREAM is a plain `Int32` on Darwin but a packed enum value on
        // Glibc — normalize via the platform shim.
        let descriptor = socket(AF_INET, Platform.streamSocketType, 0)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }

        // Non-blocking connect + poll for writability (or error).
        let flags = fcntl(descriptor, F_GETFL, 0)
        _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)

        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = Platform.streamSocketType
        hints.ai_protocol = Int32(IPPROTO_TCP)

        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &result) == 0, let first = result else {
            return false
        }
        defer { freeaddrinfo(result) }

        // `ai_addr` points into the allocated list — keep `first` alive and
        // pass the pointer fields directly (no copying of addrinfo structs).
        let connectResult = connect(descriptor, first.pointee.ai_addr, first.pointee.ai_addrlen)
        if connectResult == 0 {
            return true
        }

        // EINPROGRESS is expected for a non-blocking connect: wait for the
        // socket to become writable, then check SO_ERROR.
        let timeoutMillis = Int32((max(timeout, 0.1) * 1000).rounded())
        var pollFd = pollfd(fd: descriptor, events: Int16(Platform.pollOut), revents: 0)
        guard Platform.poll(&pollFd, 1, timeoutMillis) > 0 else { return false }

        var soError: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(descriptor, Platform.solSocket, Platform.soError, &soError, &length)
        return soError == 0
    }

}

/// POSIX shims for the reachability probe (Linux/Glibc vs. macOS/Darwin
/// naming and type differences: `SOCK_STREAM` is a raw-value enum on Linux
/// but an `Int32` on Darwin, and the C functions live in different modules).
private enum Platform {

    /// `SOCK_STREAM` normalized to the `Int32` both platforms' `socket()`
    /// expects.
    static var streamSocketType: Int32 {
        #if canImport(Glibc)
        return Int32(SOCK_STREAM.rawValue)
        #elseif canImport(Darwin)
        return SOCK_STREAM
        #endif
    }

    /// `POLLOUT` as an `Int16`.
    static var pollOut: Int32 {
        #if canImport(Glibc)
        return Int32(POLLOUT)
        #elseif canImport(Darwin)
        return Int32(POLLOUT)
        #endif
    }

    static var solSocket: Int32 {
        #if canImport(Glibc)
        return Int32(SOL_SOCKET)
        #elseif canImport(Darwin)
        return Int32(SOL_SOCKET)
        #endif
    }

    static var soError: Int32 {
        #if canImport(Glibc)
        return Int32(SO_ERROR)
        #elseif canImport(Darwin)
        return Int32(SO_ERROR)
        #endif
    }

    static func poll(
        _ fds: UnsafeMutablePointer<pollfd>,
        _ nfds: nfds_t,
        _ timeout: Int32
    ) -> Int32 {
        #if canImport(Glibc)
        return Glibc.poll(fds, nfds, timeout)
        #elseif canImport(Darwin)
        return Darwin.poll(fds, UInt32(nfds), timeout)
        #endif
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
