import Foundation
import GISTools
@testable import MVTPostgis
import Testing

@Suite(.serialized, .enabled(if: IntegrationEnvironment.isAvailable))
struct PoolOutageIntegrationTests {

    private struct TimedOut: Error {}

    private static let tile = MapTile(x: 8715, y: 5688, z: 14)

    private func withBoundedResult<T: Sendable>(
        timeout: Duration = .seconds(8),
        _ operation: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw TimedOut()
            }

            guard let result = try await group.next() else {
                throw TimedOut()
            }

            group.cancelAll()
            return result
        }
    }

    @Test(.timeLimit(.minutes(2)))
    func terminatingAllPoolBackendsRecovers() async throws {
        try await IntegrationFixture.withFixture { fixture in
            let layer = fixture.layer(
                id: "outage",
                table: "features",
                fields: ["id": "", "name": "", "kind": "", "geom": ""],
                srid: .epsg4326,
                sql: "(SELECT * FROM \"\(fixture.schema)\".features WHERE id = 1) AS data")

            let configuration = MVTPostgisConfiguration(
                applicationName: "MVTPostgisOutageTests",
                queryTimeout: 5.0,
                tileTimeout: 5.0,
                poolSize: 1,
                clipping: { _, _ in .none })

            let postgis = try MVTPostgis(
                source: fixture.source(layers: [layer]),
                configuration: configuration)
            do {
                let initial = try await postgis.vectorTile(forTile: Self.tile)
                #expect(initial.tile.features(for: "outage").count == 1)

                for cycle in 0 ..< 2 {
                    let terminated = try await fixture.database.queryInt("""
                    SELECT count(pg_terminate_backend(pid))::int AS value
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND pid <> pg_backend_pid()
                      AND application_name LIKE 'MVTPostgisOutageTests%'
                    """)
                    #expect((terminated ?? 0) >= 1, "cycle \(cycle)")

                    try await Task.sleep(for: .milliseconds(300))
                    await postgis.shutdown()

                    let recovered = try await withBoundedResult {
                        try await postgis.vectorTile(forTile: Self.tile)
                    }
                    #expect(recovered.tile.features(for: "outage").count == 1, "cycle \(cycle)")
                }

                await postgis.shutdown()
            }
            catch {
                await postgis.shutdown()
                throw error
            }
        }
    }

}
