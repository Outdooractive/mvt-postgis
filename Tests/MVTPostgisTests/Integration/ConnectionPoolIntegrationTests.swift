import Foundation
import GISTools
@testable import MVTPostgis
import PostgresNIO
import Testing

@Suite(.serialized, .enabled(if: IntegrationEnvironment.isAvailable))
struct ConnectionPoolIntegrationTests {

    private static let tile = MapTile(x: 8715, y: 5688, z: 14)

    private func configuration(
        applicationName: String = "MVTPostgisPoolTests",
        poolSize: Int = 10,
        maxIdleConnections: Int? = nil,
        queryTimeout: TimeInterval = 10.0,
        tileTimeout: TimeInterval = 60.0,
    ) -> MVTPostgisConfiguration {
        MVTPostgisConfiguration(
            applicationName: applicationName,
            queryTimeout: queryTimeout,
            tileTimeout: tileTimeout,
            poolSize: poolSize,
            maxIdleConnections: maxIdleConnections,
            clipping: { _, _ in .none })
    }

    private func withPostgis<T>(
        _ source: PostgisSource,
        configuration: MVTPostgisConfiguration,
        _ body: (MVTPostgis) async throws -> T,
    ) async throws -> T {
        let postgis = try MVTPostgis(source: source, configuration: configuration)
        do {
            let result = try await body(postgis)
            await postgis.shutdown()
            return result
        }
        catch {
            await postgis.shutdown()
            throw error
        }
    }

    private func layer(
        _ fixture: IntegrationFixture,
        id: String = "pool",
        sql: String? = nil,
    ) -> PostgisLayer {
        fixture.layer(
            id: id,
            table: "features",
            fields: ["id": "", "name": "", "kind": "", "geom": ""],
            srid: .epsg4326,
            sql: sql ?? """
            (SELECT * FROM "\(fixture.schema)".features WHERE id = 1) AS data
            """)
    }

    @Test(.timeLimit(.minutes(2)))
    func concurrentTilesCompleteWithPoolSizeOne() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = layer(fixture)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(poolSize: 1))
            { postgis in
                let counts = try await withThrowingTaskGroup(of: Int.self) { group in
                    for _ in 0 ..< 4 {
                        group.addTask {
                            try await postgis
                                .vectorTile(forTile: Self.tile)
                                .tile
                                .features(for: "pool")
                                .count
                        }
                    }

                    var counts: [Int] = []
                    for try await count in group {
                        counts.append(count)
                    }
                    return counts
                }

                #expect(counts == [1, 1, 1, 1])

                let infos = await postgis.poolInfos()
                #expect(infos.count == 1)
                #expect(infos[0].openConnections <= 1)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func layersShareOnePoolPerDatabase() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let first = layer(fixture, id: "first")
            let second = layer(fixture, id: "second")

            try await withPostgis(
                fixture.source(layers: [first, second]),
                configuration: configuration(poolSize: 2))
            { postgis in
                let result = try await postgis.vectorTile(forTile: Self.tile)
                #expect(result.tile.features(for: "first").count == 1)
                #expect(result.tile.features(for: "second").count == 1)

                let infos = await postgis.poolInfos()
                #expect(infos.count == 1)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func cancellingWaitingRequestLeavesRunningTileAlone() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = layer(
                fixture,
                sql: """
                (SELECT f.id, f.name, f.kind, f.geom
                 FROM "\(fixture.schema)".features f,
                      LATERAL (SELECT pg_sleep(2)) sleep
                 WHERE f.id = 1) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(poolSize: 1))
            { postgis in
                let running = Task {
                    try await postgis.vectorTile(forTile: Self.tile)
                }

                try await Task.sleep(for: .milliseconds(200))

                let waiting = Task {
                    try await postgis.vectorTile(forTile: Self.tile)
                }
                try await Task.sleep(for: .milliseconds(200))
                waiting.cancel()

                let result = try await running.value
                #expect(result.tile.features(for: "pool").count == 1)

                do {
                    _ = try await waiting.value
                    Issue.record("Expected the waiting request to be cancelled")
                }
                catch {
                    // Cancellation is expected; the running tile must not be
                    // affected by aborting the waiting batch.
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func shutdownFailsInFlightAndAllowsNewRequests() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = layer(
                fixture,
                sql: """
                (SELECT f.id, f.name, f.kind, f.geom
                 FROM "\(fixture.schema)".features f,
                      LATERAL (SELECT pg_sleep(3)) sleep
                 WHERE f.id = 1) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(poolSize: 1))
            { postgis in
                let running = Task {
                    try await postgis.vectorTile(forTile: Self.tile)
                }

                try await Task.sleep(for: .milliseconds(200))
                await postgis.shutdown()

                do {
                    _ = try await running.value
                    Issue.record("Expected the in-flight request to fail")
                }
                catch {
                    // Expected: the pool was shut down.
                }

                // A new request after shutdown creates a fresh pool.
                let result = try await postgis.vectorTile(forTile: Self.tile)
                #expect(result.tile.features(for: "pool").count == 1)
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func authenticationFailuresAreReported() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let datasource = PostgisDatasource(
                user: "mvt_missing_role",
                password: "wrong",
                host: IntegrationEnvironment.host ?? "127.0.0.1",
                port: IntegrationEnvironment.port,
                databaseName: IntegrationEnvironment.databaseName,
                srid: .epsg4326,
                type: "postgis",
                sql: "(SELECT 1 AS id, 'x' AS name, 'point' AS kind, NULL::geometry AS geom) AS data")
            let layer = PostgisLayer(
                id: "auth",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                datasource: datasource)

            try await withPostgis(
                PostgisSource(name: "Auth", layers: [layer]),
                configuration: configuration())
            { postgis in
                do {
                    _ = try await postgis.vectorTile(forTile: Self.tile)
                    Issue.record("Expected an authentication error")
                }
                catch {
                    let description = String(reflecting: error)
                    #expect(
                        description.contains("password")
                            || description.contains("role")
                            || description.contains("authentication"),
                    )
                }
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func poolInfosReportsActiveAndWaitingRequests() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = layer(
                fixture,
                sql: """
                (SELECT f.id, f.name, f.kind, f.geom
                 FROM "\(fixture.schema)".features f,
                      LATERAL (SELECT pg_sleep(2)) sleep
                 WHERE f.id = 1) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(poolSize: 1))
            { postgis in
                let running = Task {
                    try await postgis.vectorTile(forTile: Self.tile)
                }
                try await Task.sleep(for: .milliseconds(300))

                let active = await postgis.poolInfos().first
                #expect(active?.activeConnections == 1)
                #expect(active?.connections.first?.batchId != nil)
                #expect(active?.connections.first?.query?.contains("pg_sleep") == true)

                let waiting = Task {
                    try await postgis.vectorTile(forTile: Self.tile)
                }
                try await Task.sleep(for: .milliseconds(300))

                let queued = await postgis.poolInfos().first
                #expect(queued?.waitingRequests == 1)

                waiting.cancel()
                _ = try await running.value
            }
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func parallelValidateAndCloseIdleConnections() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = layer(
                fixture,
                sql: """
                (SELECT f.id, f.name, f.kind, f.geom
                 FROM "\(fixture.schema)".features f,
                      LATERAL (SELECT pg_sleep(2)) sleep
                 WHERE f.id = 1) AS data
                """)

            try await withPostgis(
                fixture.source(layers: [layer]),
                configuration: configuration(poolSize: 2))
            { postgis in
                let running = Task {
                    try await postgis.vectorTile(forTile: Self.tile)
                }
                try await Task.sleep(for: .milliseconds(300))

                let error = await postgis.validate(
                    sql: "SELECT 1",
                    forLayer: layer)
                #expect(error == nil)

                await postgis.closeIdleConnections()
                let result = try await running.value
                #expect(result.tile.features(for: "pool").count == 1)
            }
        }
    }

}
