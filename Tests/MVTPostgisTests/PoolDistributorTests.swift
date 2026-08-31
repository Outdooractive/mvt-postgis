import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import GISTools
import Logging
@testable import MVTPostgis
import PostgresConnectionPool
import Testing

struct PoolDistributorTests {

    @Test
    func poolDistributorShutdownClearsPools() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        await distributor.shutdown()
        let infos = await distributor.poolInfos()
        #expect(infos.isEmpty)
    }

    @Test
    func poolInfosBeforeAnyConnectionIsEmpty() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        let infos = await distributor.poolInfos()
        #expect(infos.isEmpty)
    }

    @Test
    func closeIdleConnectionsOnEmptyDistributor() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        await distributor.closeIdleConnections()
    }

    @Test
    func abortBatchOnEmptyDistributor() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        await distributor.abortBatch(42)
    }

    // MARK: - Pool recreation after a database outage

    /// A minimal layer pointing at a closed localhost port — connect always
    /// fails with ECONNREFUSED, which is all these tests need: the pool fails
    /// on first use, and the distributor must not hand out the same dead pool
    /// forever.
    static let unreachableLayer: PostgisLayer = layer(host: "127.0.0.1", port: 1)

    /// A layer for a port with a live TCP listener: the reachability probe
    /// succeeds so recreation proceeds. Nothing speaks Postgres on it, but
    /// the probe only checks TCP connectability.
    static func localListenerLayer(port: Int) -> PostgisLayer {
        layer(host: "127.0.0.1", port: port)
    }

    private static func layer(host: String, port: Int) -> PostgisLayer {
        let json = """
        {
          "id": "testlayer",
          "description": "",
          "fields": {},
          "properties": {"bufferSize": 8},
          "datasource": {
            "user": "u", "password": "p", "host": "\(host)",
            "port": \(port), "databaseName": "db",
            "srid": 3857, "type": "postgis",
            "sql": "(SELECT geometry FROM t WHERE geometry && !bbox!) AS data"
          }
        }
        """
        return try! JSONDecoder().decode(PostgisLayer.self, from: Data(json.utf8))
    }

    @Test
    func shutDownPoolIsRecreatedOnceDatabaseIsReachable() async throws {
        let config = MVTPostgisConfiguration()
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        let listener = try LocalListener()
        defer { listener.close() }
        let layer = Self.localListenerLayer(port: listener.port)

        let distributor = PoolDistributor(configuration: config, logger: logger)

        // First call creates and caches a pool.
        let pool1 = await distributor.pool(forLayer: layer)
        #expect(await !pool1.isShutdown)

        // Simulate a database outage: the pool shuts itself down on fatal
        // connection errors.
        await pool1.shutdown()
        let info = await pool1.poolInfo()
        #expect(info.isShutdown)

        // The next request must NOT return the dead pool — the probe against
        // the still-listening port succeeds, so the distributor builds a
        // fresh pool.
        let pool2 = await distributor.pool(forLayer: layer)
        #expect(await !pool2.isShutdown)
        #expect(pool2 !== pool1)

        await distributor.shutdown()
    }

    @Test
    func shutDownPoolIsKeptWhileDatabaseIsUnreachable() async {
        let config = MVTPostgisConfiguration()
        var logger = Logger(label: "test")
        logger.logLevel = .critical
        let distributor = PoolDistributor(configuration: config, logger: logger)

        // Port 1 on localhost is closed — the probe fails, so the dead pool
        // is kept and every request fails fast (this is what bounds the file
        // descriptor usage during a real outage).
        let pool1 = await distributor.pool(forLayer: Self.unreachableLayer)
        await pool1.shutdown()

        let pool2 = await distributor.pool(forLayer: Self.unreachableLayer)
        #expect(pool2 === pool1)
        let info = await pool2.poolInfo()
        #expect(info.isShutdown)

        await distributor.shutdown()
    }

    @Test
    func requestStormDuringOutageNeverRecreates() async throws {
        // Regression test for the production crash: ~40 blind recreations
        // during an outage exhausted the file descriptors (each pool owns an
        // event loop group with one fd per thread). With the probe gate, a
        // storm of concurrent requests against an unreachable database must
        // observe exactly ONE pool identity — the dead one — and never
        // allocate a new pool while the database is down.
        let config = MVTPostgisConfiguration()
        var logger = Logger(label: "test")
        logger.logLevel = .critical
        let distributor = PoolDistributor(configuration: config, logger: logger)

        let pool1 = await distributor.pool(forLayer: Self.unreachableLayer)
        await pool1.shutdown()

        let collected = ThreadSafeArrayCollector<PostgresConnectionPool>()
        let distributorCopy = distributor
        let unreachableLayer = Self.unreachableLayer
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 32 {
                group.addTask {
                    for _ in 0 ..< 32 {
                        let pool = await distributorCopy.pool(forLayer: unreachableLayer)
                        collected.append(pool)
                    }
                }
            }
        }

        let identities = Set(collected.items.map { ObjectIdentifier($0) })
        #expect(identities.count == 1, "request storm allocated \(identities.count) distinct pools instead of reusing the dead one")

        await distributor.shutdown()
    }

    @Test
    func healthyPoolIsReused() async {
        let config = MVTPostgisConfiguration()
        var logger = Logger(label: "test")
        logger.logLevel = .critical
        let distributor = PoolDistributor(configuration: config, logger: logger)

        let listener = try? LocalListener()
        let layer = listener.map { Self.localListenerLayer(port: $0.port) } ?? Self.unreachableLayer
        defer { listener?.close() }

        let pool1 = await distributor.pool(forLayer: layer)
        let pool2 = await distributor.pool(forLayer: layer)

        #expect(pool1 === pool2)

        await distributor.shutdown()
    }

    @Test
    func connectionAgainstUnreachableHostThrowsButPoolRecovers() async throws {
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        // A live TCP port: the probe succeeds, so the distributor recreates
        // the pool, and the retry throws a *real* connection error (nothing
        // speaks Postgres) instead of `poolDestroyed` forever.
        let listener = try? LocalListener()
        let layer = listener.map { Self.localListenerLayer(port: $0.port) } ?? Self.unreachableLayer
        defer { listener?.close() }

        let distributor = PoolDistributor(configuration: MVTPostgisConfiguration(), logger: logger)

        // First attempt: fails (nothing speaks Postgres on that port), and
        // the pool will eventually shut itself down due to the error.
        do {
            try await distributor.connection(forLayer: layer, batchId: 1) { _ in }
        }
        catch {
            // Expected — connection refused / timeout / pool destroyed.
        }

        // Whatever happened to the first pool, a later request must get a
        // usable (not shut-down) pool.
        let pool = await distributor.pool(forLayer: layer)
        #expect(await !pool.isShutdown)

        await distributor.shutdown()
    }

    @Test
    func reachabilityProbeDetectsOpenAndClosedPorts() async throws {
        let listener = try LocalListener()
        defer { listener.close() }

        // Open port: probe must succeed.
        let open = await PoolDistributor.isReachable(
            host: "127.0.0.1",
            port: listener.port,
            timeout: 1.0)
        #expect(open)

        // Closed port: probe must fail (fast).
        let closed = await PoolDistributor.isReachable(
            host: "127.0.0.1",
            port: 1,
            timeout: 0.5)
        #expect(!closed)
    }

}

// MARK: - Local TCP listener helper

private enum ListenerError: Error {
    case couldNotCreateSocket
    case couldNotBind
}

/// A bound+listening TCP socket on an ephemeral localhost port. Used as the
/// reachability probe target; nothing speaks Postgres on it, which is fine —
/// the probe checks TCP connectability only.
private final class LocalListener {
    let descriptor: Int32
    let port: Int

    init() throws {
        let fd = socket(AF_INET, Platform.streamSocketType, 0)
        guard fd >= 0 else { throw ListenerError.couldNotCreateSocket }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr = in_addr(s_addr: INADDR_LOOPBACK.bigEndian)
        addr.sin_port = 0  // let the OS pick a free port

        var bindResult: Int32 = -1
        withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bindResult = Platform.bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0, Platform.listen(fd, 8) == 0 else {
            Platform.close(fd)
            throw ListenerError.couldNotBind
        }

        var boundAddr = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Platform.getSockName(fd, sockaddrPointer, &length)
            }
        }
        guard nameResult == 0 else {
            Platform.close(fd)
            throw ListenerError.couldNotBind
        }

        self.descriptor = fd
        // sin_port is in network byte order — one single swap to host order.
        self.port = Int(UInt16(bigEndian: boundAddr.sin_port))
    }

    func close() {
        Platform.close(descriptor)
    }
}

// MARK: - POSIX shims (Linux Glibc vs. macOS Darwin differences)

/// Namespace for the platform-specific socket functions.
private enum Platform {

    /// `SOCK_STREAM` as an `Int32`: a raw-value enum case on Linux/Glibc, a
    /// plain `Int32` constant on Darwin.
    static var streamSocketType: Int32 {
        #if canImport(Glibc)
        return Int32(SOCK_STREAM.rawValue)
        #elseif canImport(Darwin)
        return SOCK_STREAM
        #endif
    }

    /// `INADDR_LOOPBACK` in network byte order (the Darwin constant is
    /// already in the right representation; on Glibc it needs `.bigEndian`).
    static var loopbackAddress: in_addr_t {
        #if canImport(Glibc)
        return INADDR_LOOPBACK.bigEndian
        #else
        return UInt32(INADDR_LOOPBACK).bigEndian
        #endif
    }

    static func close(_ fd: Int32) {
        #if canImport(Glibc)
        Glibc.close(fd)
        #elseif canImport(Darwin)
        Darwin.close(fd)
        #endif
    }

    static func bind(_ fd: Int32, _ addr: UnsafePointer<sockaddr>, _ length: socklen_t) -> Int32 {
        #if canImport(Glibc)
        return Glibc.bind(fd, addr, length)
        #elseif canImport(Darwin)
        return Darwin.bind(fd, addr, length)
        #endif
    }

    static func listen(_ fd: Int32, _ backlog: Int32) -> Int32 {
        #if canImport(Glibc)
        return Glibc.listen(fd, backlog)
        #elseif canImport(Darwin)
        return Darwin.listen(fd, backlog)
        #endif
    }

    static func getSockName(_ fd: Int32, _ addr: UnsafeMutablePointer<sockaddr>, _ length: inout socklen_t) -> Int32 {
        #if canImport(Glibc)
        return Glibc.getsockname(fd, addr, &length)
        #elseif canImport(Darwin)
        return Darwin.getsockname(fd, addr, &length)
        #endif
    }

}
