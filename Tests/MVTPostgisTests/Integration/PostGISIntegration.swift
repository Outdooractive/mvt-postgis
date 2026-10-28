import Foundation
import GISTools
import Logging
@testable import MVTPostgis
import NIOPosix
import PostgresNIO

/// Environment configuration for the real PostGIS integration tests.
enum IntegrationEnvironment {

    static let environment = ProcessInfo.processInfo.environment

    static var host: String? {
        environment["MVT_POSTGIS_TEST_HOST"].flatMap { $0.isEmpty ? nil : $0 }
    }

    static var port: Int {
        Int(environment["MVT_POSTGIS_TEST_PORT"] ?? "") ?? 5432
    }

    static var user: String {
        environment["MVT_POSTGIS_TEST_USER"] ?? "postgres"
    }

    static var password: String {
        environment["MVT_POSTGIS_TEST_PASSWORD"] ?? "postgres"
    }

    static var databaseName: String {
        environment["MVT_POSTGIS_TEST_DATABASE"] ?? "mvt_test"
    }

    static var isAvailable: Bool {
        host != nil
    }

    static var configuration: PostgresConnection.Configuration {
        PostgresConnection.Configuration(
            host: host ?? "127.0.0.1",
            port: port,
            username: user,
            password: password,
            database: databaseName,
            tls: .disable)
    }

}

/// A single database connection used to create and clean up fixtures.
final class IntegrationDatabase {

    let group: MultiThreadedEventLoopGroup
    let connection: PostgresConnection

    private init(group: MultiThreadedEventLoopGroup, connection: PostgresConnection) {
        self.group = group
        self.connection = connection
    }

    static func connect() async throws -> IntegrationDatabase {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        do {
            let connection = try await PostgresConnection.connect(
                on: group.next(),
                configuration: IntegrationEnvironment.configuration,
                id: 1,
                logger: Logger(label: "mvt-postgis-integration"))
                .get()
            return IntegrationDatabase(group: group, connection: connection)
        }
        catch {
            try? await group.shutdownGracefully()
            throw error
        }
    }

    func execute(_ sql: String) async throws {
        _ = try await connection.simpleQuery(sql).get()
    }

    func executeScript(_ sql: String) async throws {
        for statement in sql.split(separator: ";") {
            let statement = statement.trimmingCharacters(in: .whitespacesAndNewlines)
            if statement.isEmpty {
                continue
            }
            try await execute(statement)
        }
    }

    /// Runs a query returning a single integer column aliased as `value`.
    func queryInt(_ sql: String) async throws -> Int? {
        let rows = try await connection.simpleQuery(sql).get()
        guard let row = rows.first else { return nil }

        return row.makeRandomAccess()[data: "value"].int
    }

    func close() async {
        try? await connection.close().get()
        try? await group.shutdownGracefully()
    }

}

/// A uniquely named schema seeded with the deterministic fixture data.
final class IntegrationFixture {

    let database: IntegrationDatabase
    let schema: String

    private init(database: IntegrationDatabase, schema: String) {
        self.database = database
        self.schema = schema
    }

    static func create() async throws -> IntegrationFixture {
        let database = try await IntegrationDatabase.connect()
        do {
            do {
                try await database.execute("CREATE EXTENSION IF NOT EXISTS postgis")
            }
            catch {
                // `CREATE EXTENSION IF NOT EXISTS` is not atomic. Parallel test
                // suites can race on the extension name index; the extension is
                // installed after the losing statement fails.
                let installed = try await database.queryInt(
                    "SELECT 1 AS value FROM pg_extension WHERE extname = 'postgis'")
                guard installed == 1 else { throw error }
            }

            let schema = "mvt_test_\(UUID().uuidString.replacing("-", with: ""))"
            try await database.execute("CREATE SCHEMA \"\(schema)\"")

            let fixtureURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("fixtures.sql")
            let sql = try String(contentsOf: fixtureURL, encoding: .utf8)
                .replacing("{{schema}}", with: schema)
            try await database.executeScript(sql)

            return IntegrationFixture(database: database, schema: schema)
        }
        catch {
            await database.close()
            throw error
        }
    }

    static func withFixture<T>(
        _ body: (IntegrationFixture) async throws -> T,
    ) async throws -> T {
        let fixture = try await create()
        do {
            let result = try await body(fixture)
            await fixture.shutdown()
            return result
        }
        catch {
            await fixture.shutdown()
            throw error
        }
    }

    func shutdown() async {
        try? await database.execute("DROP SCHEMA \"\(schema)\" CASCADE")
        await database.close()
    }

    func source(layers: [PostgisLayer]) -> PostgisSource {
        PostgisSource(name: "Integration", layers: layers)
    }

    func layer(
        id: String? = nil,
        table: String,
        fields: [String: String],
        srid: Projection,
        geometryField: String = "geom",
        boundingBox: BoundingBox? = nil,
        properties: PostgisLayer.Properties = PostgisLayer.Properties(),
        sql: String? = nil,
    ) -> PostgisLayer {
        let datasource = PostgisDatasource(
            user: IntegrationEnvironment.user,
            password: IntegrationEnvironment.password,
            host: IntegrationEnvironment.host ?? "127.0.0.1",
            port: IntegrationEnvironment.port,
            databaseName: IntegrationEnvironment.databaseName,
            geometryField: geometryField,
            boundingBox: boundingBox,
            srid: srid,
            type: "postgis",
            sql: sql ?? """
            (SELECT * FROM "\(schema)".\(table) WHERE "\(geometryField)" && !bbox!) AS data
            """)
        return PostgisLayer(
            id: id ?? table,
            fields: fields,
            properties: properties,
            datasource: datasource)
    }

}
