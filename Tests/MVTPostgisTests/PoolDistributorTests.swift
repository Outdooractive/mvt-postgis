import Foundation
import GISTools
import Logging
@testable import MVTPostgis
import PostgresConnectionPool
import Testing
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

struct PoolDistributorTests {

    @Test
    func `pool distributor shutdown clears pools`() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        await distributor.shutdown()
        let infos = await distributor.poolInfos()
        #expect(infos.isEmpty)
    }

    @Test
    func `pool infos before any connection is empty`() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        let infos = await distributor.poolInfos()
        #expect(infos.isEmpty)
    }

    @Test
    func `close idle connections on empty distributor`() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        await distributor.closeIdleConnections()
    }

    @Test
    func `abort batch on empty distributor`() async {
        let config = MVTPostgisConfiguration()
        let logger = Logger(label: "test")
        let distributor = PoolDistributor(configuration: config, logger: logger)

        await distributor.abortBatch(42)
    }

    // MARK: - Pool recreation after a permanent failure

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
    func `shut down pool is recreated once database is reachable`() async throws {
        let config = MVTPostgisConfiguration()
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        let listener = try LocalListener()
        defer { listener.close() }
        let layer = Self.localListenerLayer(port: listener.port)

        let distributor = PoolDistributor(configuration: config, logger: logger)

        // First call creates and caches a pool.
        let pool1 = await distributor.pool(forLayer: layer)
        #expect(await pool1.isShutdown == false)

        // Simulate a permanently destroyed pool (e.g. an authentication
        // failure or an explicit shutdown).
        await pool1.shutdown()
        let info = await pool1.poolInfo()
        #expect(info.isShutdown)

        // The next request must NOT return the dead pool — the probe against
        // the still-listening port succeeds, so the distributor builds a
        // fresh pool.
        let pool2 = await distributor.pool(forLayer: layer)
        #expect(await pool2.isShutdown == false)
        #expect(pool2 !== pool1)

        await distributor.shutdown()
    }

    @Test
    func `shut down pool is kept while database is unreachable`() async {
        let config = MVTPostgisConfiguration()
        var logger = Logger(label: "test")
        logger.logLevel = .critical
        let distributor = PoolDistributor(configuration: config, logger: logger)

        // Port 1 on localhost is closed — the probe fails, so the dead pool
        // is kept and every request fails fast (this bounds pool/connection
        // churn while the database is unreachable).
        let pool1 = await distributor.pool(forLayer: Self.unreachableLayer)
        await pool1.shutdown()

        let pool2 = await distributor.pool(forLayer: Self.unreachableLayer)
        #expect(pool2 === pool1)
        let info = await pool2.poolInfo()
        #expect(info.isShutdown)

        await distributor.shutdown()
    }

    @Test
    func `request storm during outage never recreates`() async {
        // Regression test for a production crash where blind recreations
        // created too many pools/connections. With the probe gate, a storm
        // of concurrent requests against an unreachable database must
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
    func `healthy pool is reused`() async {
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
    func `connection against unreachable host throws but pool recovers`() async throws {
        var logger = Logger(label: "test")
        logger.logLevel = .critical

        // A live TCP port: nothing speaks Postgres there, so the request
        // fails with a transient connection error. The pool itself remains
        // alive.
        let listener = try? LocalListener()
        let layer = listener.map { Self.localListenerLayer(port: $0.port) } ?? Self.unreachableLayer
        defer { listener?.close() }

        let distributor = PoolDistributor(configuration: MVTPostgisConfiguration(), logger: logger)

        // First attempt: fails because nothing speaks Postgres on that port.
        // A transient failure does not shut the pool down.
        do {
            try await distributor.connection(forLayer: layer, batchId: 1) { _ in }
        }
        catch {
            // Expected — transient connection failure.
        }

        // Whatever happened to the first pool, a later request must get a
        // usable (not shut-down) pool.
        let pool = await distributor.pool(forLayer: layer)
        #expect(await pool.isShutdown == false)

        await distributor.shutdown()
    }

    @Test
    func `reachability probe detects open and closed ports`() async throws {
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
        #expect(closed == false)
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
        addr.sin_port = 0 // let the OS pick a free port

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
        INADDR_LOOPBACK.bigEndian
        #else
        UInt32(INADDR_LOOPBACK).bigEndian
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
