import Foundation
import GISTools
@testable import MVTPostgis
import MVTTools
import Testing

struct FakeLoaderTests {

    private func datasource(
        srid: Projection = .epsg4326,
    ) -> PostgisDatasource {
        PostgisDatasource(
            user: "u",
            host: "h",
            port: 5432,
            databaseName: "db",
            srid: srid,
            type: "postgis",
            sql: "(SELECT * FROM t WHERE geometry && !bbox!) AS data")
    }

    private func layer(
        id: String,
        srid: Projection = .epsg4326,
    ) -> PostgisLayer {
        PostgisLayer(id: id, datasource: datasource(srid: srid))
    }

    private func source(
        layers: [PostgisLayer],
    ) -> PostgisSource {
        PostgisSource(name: "Fake", layers: layers)
    }

    private func feature(
        id: Int,
        name: String,
    ) -> Feature {
        Feature(
            Point(Coordinate3D(latitude: 48.1, longitude: 11.5)),
            id: .int(id),
            properties: ["name": name] as [String: Sendable])
    }

    private func performance(sqlQuery: String) -> MVTLayerPerformanceData {
        MVTLayerPerformanceData(
            runtime: 0.125,
            wkbBytes: 42,
            features: 1,
            invalidFeatures: 0,
            sqlQuery: sqlQuery)
    }

    @Test
    func fakeLoaderDrivesMultipleLayersAndRuntimeTracking() async throws {
        let source = source(layers: [layer(id: "first"), layer(id: "second")])
        let postgis = try MVTPostgis(
            source: source,
            configuration: MVTPostgisConfiguration(trackRuntimes: true),
            layerLoader: { query, layer, _, _, _, _, _ in
                ([feature(id: layer.id == "first" ? 1 : 2, name: layer.id)], performance(sqlQuery: query))
            })

        let result = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))

        #expect(result.tile.layerNames == ["first", "second"])
        #expect(result.tile.features(for: "first").first?.id == .int(1))
        #expect(result.tile.features(for: "second").first?.id == .int(2))
        #expect(result.performance?.count == 2)
        #expect(result.performance?["Fake.db.first"]?.features == 1)
        #expect(result.performance?["Fake.db.second"]?.features == 1)
    }

    @Test
    func fakeLoaderReceivesFeatureMapping() async throws {
        let source = source(layers: [layer(id: "layer")])
        let postgis = try MVTPostgis(
            source: source,
            configuration: MVTPostgisConfiguration(
                featureMapping: { feature in
                    var mapped = feature
                    mapped.setProperty(true, for: "mapped")
                    return mapped
                }),
            layerLoader: { query, _, _, _, _, mapping, _ in
                var feature = feature(id: 1, name: "original")
                if let mapping {
                    feature = mapping(feature)
                }
                return ([feature], performance(sqlQuery: query))
            })

        let result = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))
        #expect(result.tile.features(for: "layer").first?.properties["mapped"] as? Bool == true)
    }

    @Test
    func fakeLoaderReceivesEachLayerProjection() async throws {
        let source = source(layers: [
            layer(id: "geographic", srid: .epsg4326),
            layer(id: "mercator", srid: .epsg3857),
        ])
        let projections = ThreadSafeArrayCollector<Projection>()
        let postgis = try MVTPostgis(
            source: source,
            layerLoader: { query, _, projection, _, _, _, _ in
                projections.append(projection)
                return ([], performance(sqlQuery: query))
            })

        _ = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))
        #expect(Set(projections.items) == [.epsg4326, .epsg3857])
    }

    @Test
    func fakeLoaderDataProducesMvtAndMlt() async throws {
        let source = source(layers: [layer(id: "layer")])
        let postgis = try MVTPostgis(
            source: source,
            layerLoader: { query, _, _, _, _, _, _ in
                ([feature(id: 1, name: "mapped")], performance(sqlQuery: query))
            })

        let mvt = try await postgis.data(
            forTile: MapTile(x: 0, y: 0, z: 0),
            format: .mvt,
            options: VectorTile.ExportOptions())
        let mlt = try await postgis.data(
            forTile: MapTile(x: 0, y: 0, z: 0),
            format: .mlt,
            options: VectorTile.ExportOptions())

        #expect(mvt.data != nil)
        #expect(mlt.data != nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func tileTimeoutIsReported() async throws {
        let source = source(layers: [layer(id: "slow")])
        let postgis = try MVTPostgis(
            source: source,
            configuration: MVTPostgisConfiguration(tileTimeout: 1.0),
            layerLoader: { _, _, _, _, _, _, _ in
                try await Task.sleep(for: .seconds(10))
                return ([], performance(sqlQuery: "slow"))
            })

        do {
            _ = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))
            Issue.record("Expected tile timeout")
        }
        catch let error as MVTPostgisError {
            guard case .tileTimedOut = error else {
                Issue.record("Expected tileTimedOut, got \(error)")
                return
            }
        }
    }

    @Test
    func loaderErrorIsPropagated() async throws {
        struct LoaderError: Equatable, Error {

            let message: String

        }

        let source = source(layers: [layer(id: "layer")])
        let postgis = try MVTPostgis(
            source: source,
            layerLoader: { _, _, _, _, _, _, _ in
                throw LoaderError(message: "failed")
            })

        do {
            _ = try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))
            Issue.record("Expected loader error")
        }
        catch let error as LoaderError {
            #expect(error.message == "failed")
        }
    }

    @Test
    func cancelledTaskThrowsCancelledBeforeLoading() async throws {
        let source = source(layers: [layer(id: "layer")])
        let postgis = try MVTPostgis(
            source: source,
            layerLoader: { _, _, _, _, _, _, _ in
                ([], performance(sqlQuery: "unused"))
            })

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await postgis.vectorTile(forTile: MapTile(x: 0, y: 0, z: 0))
        }

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        }
        catch let error as MVTPostgisError {
            #expect(error == .cancelled)
        }
    }

}
