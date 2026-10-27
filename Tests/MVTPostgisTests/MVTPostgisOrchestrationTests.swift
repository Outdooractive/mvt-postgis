import Foundation
import GISTools
import Logging
@testable import MVTPostgis
import MVTTools
import Testing

struct MVTPostgisOrchestrationTests {

    private func makePostgis(trackRuntimes: Bool = false) throws -> MVTPostgis {
        let datasource = PostgisDatasource(
            user: "u",
            host: "127.0.0.1",
            port: 1,
            databaseName: "db",
            boundingBox: BoundingBox(
                southWest: Coordinate3D(latitude: 47.0, longitude: 10.0),
                northEast: Coordinate3D(latitude: 48.0, longitude: 11.0)),
            srid: .epsg4326,
            type: "postgis",
            sql: "(SELECT * FROM t WHERE geometry && !bbox!) AS data")
        let source = PostgisSource(
            name: "Skipped",
            layers: [PostgisLayer(id: "layer", datasource: datasource)])

        return try MVTPostgis(
            source: source,
            configuration: MVTPostgisConfiguration(
                clipping: { _, _ in .none },
                simplification: { _, _ in .none },
                validation: { _, _ in .none },
                trackRuntimes: trackRuntimes))
    }

    @Test
    func `all layers skipped returns empty tile without connecting`() async throws {
        let postgis = try makePostgis()
        let result = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 10))

        #expect(result.tile.isEmpty)
        #expect(result.performance == nil)

        await postgis.closeIdleConnections()
        #expect(await postgis.poolInfos().isEmpty)
        await postgis.shutdown()
    }

    @Test
    func `all layers skipped returns empty runtime map`() async throws {
        let postgis = try makePostgis(trackRuntimes: true)
        let result = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 10))

        #expect(result.tile.isEmpty)
        #expect(result.performance?.isEmpty == true)

        await postgis.shutdown()
    }

    @Test
    func `skipped layers still produce MVT data`() async throws {
        let postgis = try makePostgis()
        let result = try await postgis.data(
            forTile: MapTile(x: 0, y: 0, z: 10),
            format: .mvt,
            options: VectorTile.ExportOptions())

        #expect(result.data != nil)
        #expect(result.performance == nil)

        await postgis.shutdown()
    }

    @Test
    func `skipped layers produce MLT data`() async throws {
        let postgis = try makePostgis()
        let result = try await postgis.data(
            forTile: MapTile(x: 0, y: 0, z: 10),
            format: .mlt,
            options: VectorTile.ExportOptions())

        #expect(result.data != nil)

        await postgis.shutdown()
    }

    @Test(.timeLimit(.minutes(1)))
    func `validate returns connection error for unreachable database`() async throws {
        let datasource = PostgisDatasource(
            user: "u",
            host: "127.0.0.1",
            port: 1,
            databaseName: "db",
            srid: .epsg4326,
            type: "postgis",
            sql: "(SELECT * FROM t WHERE geometry && !bbox!) AS data")
        let layer = PostgisLayer(id: "layer", datasource: datasource)
        let source = PostgisSource(name: "Unreachable", layers: [layer])
        var logger = Logger(label: "test")
        logger.logLevel = .critical
        let postgis = try MVTPostgis(
            source: source,
            configuration: MVTPostgisConfiguration(
                connectTimeout: 1.0,
                queryTimeout: 1.0,
                tileTimeout: 1.0),
            logger: logger)

        let error = await postgis.validate(sql: "SELECT * FROM missing_table", forLayer: layer)
        #expect(error != nil)

        await postgis.shutdown()
    }

    @Test
    func `skipped layer with buffer still returns immediately`() async throws {
        let datasource = PostgisDatasource(
            user: "u",
            host: "127.0.0.1",
            port: 1,
            databaseName: "db",
            boundingBox: BoundingBox(
                southWest: Coordinate3D(latitude: 47.0, longitude: 10.0),
                northEast: Coordinate3D(latitude: 48.0, longitude: 11.0)),
            srid: .epsg4326,
            type: "postgis",
            sql: "(SELECT * FROM t WHERE geometry && !bbox!) AS data")
        let source = PostgisSource(
            name: "Buffered",
            layers: [
                PostgisLayer(
                    id: "layer",
                    properties: .init(bufferSize: 128),
                    datasource: datasource),
            ])
        let postgis = try MVTPostgis(
            source: source,
            configuration: MVTPostgisConfiguration(
                clipping: { _, _ in .none },
                simplification: { _, _ in .none },
                validation: { _, _ in .none }))

        let result = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 10))
        #expect(result.tile.isEmpty)
        await postgis.shutdown()
    }

}
