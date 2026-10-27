import Atomics
import Foundation
import GISTools
import MVTTools
import PostgresConnectionPool
import PostgresNIO

// https://github.com/mapnik/mapnik/wiki/PostGIS
// https://github.com/mapnik/mapnik/wiki/OptimizeRenderingWithPostGIS
// https://github.com/mapnik/mapnik/blob/master/plugins/input/postgis/postgis_datasource.cpp
// https://github.com/mapnik/mapnik/blob/master/test/unit/datasource/postgis.cpp

/// A tool for creating vector tiles from Postgis datasources.
/// Accepts YML and XML sources (as used by Mapnik and the old Mapbox Studio), and new JSON sources.
public final class MVTPostgis: Sendable {

    typealias LayerLoader = @Sendable (
        _ query: String,
        _ layer: PostgisLayer,
        _ projection: Projection,
        _ clipBounds: BoundingBox?,
        _ simplificationTolerance: Double?,
        _ featureMapping: (@Sendable (Feature) -> Feature)?,
        _ batchId: Int,
    ) async throws -> (features: [Feature], performance: MVTLayerPerformanceData)

    /// The default configuration for new ``MVTPostgis`` instances.
    ///
    /// Used when no explicit ``configuration`` is passed to the initializer.
    /// Changes after the first instance is created have no effect on existing instances.
    /// See ``MVTPostgisConfiguration``.
    public nonisolated(unsafe) static var configuration: MVTPostgisConfiguration = .init()

    private static let postgisDatasourceTypeCode = "postgis"
    private static let batchId: ManagedAtomic<Int> = .init(0)

    /// The minimum zoom of the datasource.
    public let minZoom: Int
    /// The maximum zoom of the datasource.
    public let maxZoom: Int

    /// The source.
    public let source: PostgisSource
    /// The source's projection, taken from the first layer.
    ///
    /// Planar and geographic projections registered in GISTools are supported.
    /// Geocentric projections and `noSRID` are rejected.
    public let projection: Projection

    /// Some external name that users can coose to distinguish this
    /// instance from other instances. Used e.g. in runtime tracking
    /// and some error messages.
    public let externalName: String?

    // ===

    private let configuration: MVTPostgisConfiguration
    private let logger: Logger
    private let poolDistributor: PoolDistributor
    private let customLayerLoader: LayerLoader?

    // MARK: -

    /// Initialize a ``MVTPostgis`` instance from a source file URL.
    ///
    /// The source can be in JSON, Mapnik YML, or Mapnik XML format.
    ///
    /// - Parameters:
    ///   - sourceURL: The file URL of the datasource definition.
    ///   - externalName: An optional name used in runtime tracking and log messages.
    ///   - layerAllowlist: Optional list of layer names to include. When `nil`, all layers are included.
    ///   - logger: An optional logger. If `nil`, a default logger is created.
    /// - Throws: ``MVTPostgisError`` or decoding errors from the source file.
    public convenience init(
        sourceURL: URL,
        externalName: String? = nil,
        layerAllowlist: [String]? = nil,
        logger: Logger? = nil,
    ) throws {
        let source = try PostgisSource.load(
            from: sourceURL,
            layerAllowlist: layerAllowlist)

        try self.init(
            source: source,
            externalName: externalName,
            logger: logger)
    }

    /// Initialize a ``MVTPostgis`` instance from raw datasource data.
    ///
    /// The data can be in JSON, Mapnik YML, or Mapnik XML format.
    ///
    /// - Parameters:
    ///   - sourceData: The datasource definition as raw data.
    ///   - externalName: An optional name used in runtime tracking and log messages.
    ///   - layerAllowlist: Optional list of layer names to include. When `nil`, all layers are included.
    ///   - logger: An optional logger. If `nil`, a default logger is created.
    /// - Throws: ``MVTPostgisError`` or decoding errors from the source data.
    public convenience init(
        sourceData: Data,
        externalName: String? = nil,
        layerAllowlist: [String]? = nil,
        logger: Logger? = nil,
    ) throws {
        let source = try PostgisSource.load(
            from: sourceData,
            layerAllowlist: layerAllowlist)

        try self.init(
            source: source,
            externalName: externalName,
            logger: logger)
    }

    /// Initialize a ``MVTPostgis`` instance with a pre-parsed ``PostgisSource``.
    ///
    /// This is the designated initializer. All other initializers delegate to this one.
    ///
    /// - Parameters:
    ///   - source: A parsed datasource definition.
    ///   - externalName: An optional name used in runtime tracking and log messages.
    ///   - configuration: Optional instance-specific configuration. When `nil`, ``MVTPostgis/configuration`` is used.
    ///   - logger: An optional logger. If `nil`, a default logger is created.
    /// - Throws: ``MVTPostgisError/needLayers`` if the source has no layers,
    ///   `MVTPostgisError/wrongDatasourceType(message:)` if a layer is not of type `"postgis"`,
    ///   or ``MVTPostgisError/unsupportedSRID`` if the datasource uses an unsupported projection.
    public convenience init(
        source: PostgisSource,
        externalName: String? = nil,
        configuration: MVTPostgisConfiguration? = nil,
        logger: Logger? = nil,
    ) throws {
        try self.init(
            source: source,
            externalName: externalName,
            configuration: configuration,
            logger: logger,
            layerLoader: nil)
    }

    init(
        source: PostgisSource,
        externalName: String? = nil,
        configuration: MVTPostgisConfiguration? = nil,
        logger: Logger? = nil,
        layerLoader: LayerLoader?,
    ) throws {
        guard source.layers.isEmpty == false else { throw MVTPostgisError.needLayers }
        guard source.layers.allSatisfy(\.id.isNotEmpty) else {
            throw MVTPostgisError.invalidLayerId
        }
        guard source.layers.allSatisfy({ $0.datasource.type == MVTPostgis.postgisDatasourceTypeCode }) else {
            throw MVTPostgisError.wrongDatasourceType(message: "All datasources must be of type '\(MVTPostgis.postgisDatasourceTypeCode)'")
        }
        guard source.layers.allSatisfy({
            $0.datasource.srid.hasSRID
                && ($0.datasource.srid.kind == .planar || $0.datasource.srid.kind == .geographic)
        }) else {
            throw MVTPostgisError.unsupportedSRID
        }

        let layer = source.layers[0]
        self.projection = layer.datasource.srid

        self.source = source
        self.externalName = externalName
        self.configuration = configuration ?? MVTPostgis.configuration
        self.minZoom = source.minZoom
        self.maxZoom = source.maxZoom

        let appName = self.configuration.applicationName
        self.logger = logger ?? {
            var logger = Logger(label: "\(appName).\(externalName ?? source.name)")
            logger.logLevel = .info
            return logger
        }()
        self.poolDistributor = PoolDistributor(
            configuration: self.configuration,
            logger: self.logger)
        self.customLayerLoader = layerLoader
    }

    /// Close all database connections and shut down all connection pools.
    ///
    /// **MUST** be called when done with all ``MVTPostgis`` instances.
    /// After this call, new tile requests will re-create connections as needed.
    public func shutdown() async {
        await poolDistributor.shutdown()
    }

    /// Forcibly close all idle connections in all database pools.
    ///
    /// Active connections are not affected.
    public func closeIdleConnections() async {
        await poolDistributor.closeIdleConnections()
    }

    /// Returns information about all active database pools and their connections.
    /// - Returns: An array of `PoolInfo` structs, one per database pool.
    public func poolInfos() async -> [PoolInfo] {
        await poolDistributor.poolInfos()
    }

    // MARK: - SQL Validation

    /// Validates the SQL query for a layer by running `EXPLAIN` against the
    /// layer's database.
    ///
    /// This reuses the existing connection pool (read-only sessions) — no
    /// separate Postgres client is needed. The mapnik placeholders `!bbox!`,
    /// `!scale_denominator!`, and `!pixel_width!` are replaced with dummy
    /// values so the query can be parsed and planned without a real tile
    /// bounding box.
    ///
    /// - Parameters:
    ///   - sql: The SQL query (with `!bbox!` etc. tokens) to validate.
    ///   - layer: The layer whose datasource provides the connection
    ///     parameters. The layer must already be part of this source (or at
    ///     least have matching connection params).
    /// - Returns: `nil` if the query is valid, or the full error message
    ///   (via `String(reflecting:)`) if the query fails — syntax error,
    ///   missing table/column, connection failure, etc.
    public func validate(
        sql: String,
        forLayer layer: PostgisLayer,
    ) async -> String? {
        let preparedSQL = sql
            .replacing(
                "!bbox!",
                with: "ST_MakeEnvelope(0, 0, 1, 1, \(layer.datasource.srid.hasSRID ? layer.datasource.srid.srid : 3857))")
            .replacing("!scale_denominator!", with: "1000")
            .replacing("!pixel_width!", with: "1")
        let explainSQL = "EXPLAIN \(preparedSQL)"
        let batchId = MVTPostgis.batchId.loadThenWrappingIncrement(by: 1, ordering: .relaxed)

        do {
            try await poolDistributor.connection(
                forLayer: layer,
                batchId: batchId,
                callback: { connection in
                    let rows = try await connection.query(
                        PostgresQuery(unsafeSQL: explainSQL),
                        logger: self.logger)
                    // Drain the row sequence — we only care that it doesn't throw.
                    for try await _ in rows {}
                })
            return nil
        }
        catch {
            return String(reflecting: error)
        }
    }

    // MARK: -

    /// Return tile data at the given z/x/y coordinate in the specified format.
    ///
    /// - Parameters:
    ///   - tile: The map tile to render.
    ///   - format: The output format (`.mvt` or `.mlt`).
    ///   - options: Export options controlling buffering and compression.
    /// - Returns: A tuple of optional encoded tile data and optional per-layer performance statistics.
    public func data(
        forTile tile: MapTile,
        format: TileOutputFormat,
        options: VectorTile.ExportOptions,
    ) async throws -> (data: Data?, performance: [String: MVTLayerPerformanceData]?) {
        let result = try await vectorTile(forTile: tile, options: options)
        let data: Data? =
            switch format {
            case .mvt: result.tile.mvtData(options: options)
            case .mlt: result.tile.mltData(options: options)
            }
        return (data, result.performance)
    }

    /// Create a tile at the given z/x/y coordinate by querying all configured layers.
    ///
    /// Returns a `VectorTile` that can be encoded to any output format
    /// via `mvtData(options:)` or `mltData(options:)`.
    ///
    /// - Parameters:
    ///   - tile: The map tile to render.
    ///   - options: Export options controlling buffering (other options like compression are applied during encoding).
    /// - Returns: A tuple of the generated `VectorTile` and optional per-layer performance statistics.
    /// - Throws: ``MVTPostgisError`` if the tile is out of bounds, the request is cancelled, or a query times out.
    public func vectorTile(
        forTile tile: MapTile,
        options: VectorTile.ExportOptions? = nil,
    ) async throws -> (tile: VectorTile, performance: [String: MVTLayerPerformanceData]?) {
        if Task.isCancelled {
            throw MVTPostgisError.cancelled
        }

        let nextBatchId = MVTPostgis.batchId.loadThenWrappingIncrement(by: 1, ordering: .relaxed)

        return try await withThrowingTaskGroup(
            of: (String, String, [Feature], MVTLayerPerformanceData).self,
            body: { group -> (tile: VectorTile, performance: [String: MVTLayerPerformanceData]?) in
                var tileVar = try VectorTile(tile: tile, projection: projection)

                let layerLoader = self.customLayerLoader ?? { [self] query, layer, projection, clipBounds, simplificationTolerance, featureMapping, batchId in
                    try await load(
                        query: query,
                        layer: layer,
                        projection: projection,
                        clipBounds: clipBounds,
                        simplificationTolerance: simplificationTolerance,
                        featureMapping: featureMapping,
                        batchId: batchId)
                }

                // https://github.com/mapnik/mapnik/blob/master/src/scale_denominator.cpp
                // https://github.com/openstreetmap/mapnik-stylesheets/blob/master/zoom-to-scale.txt
                // 0.0293611270703125 ? (in nodejs/wms-client)
                let pixelSize = 0.00028 // 0.28mm, in meters
                let tileSize = GISTool.tileSideLength // 256px
                let scaleDenominator = GISTool.earthCircumference / ((tileSize * pow(2.0, Double(tile.z))) * pixelSize)
                let pixelWidth = tile.metersPerPixel
                let simplificationTolerance = simplificationTolerance(pixelWidth: pixelWidth, atZoom: tile.z)

                let deadline = Date(timeIntervalSinceNow: self.configuration.tileTimeout)
                var queryTasksCount = 0
                var finishedTasksCount = 0

                for layer in source.layers {
                    let layerProjection = layer.datasource.srid
                    let bounds = try queryBounds(
                        tile: tile,
                        tileSize: VectorTile.ExportOptions.tileSize, // pixels
                        bufferSize: layer.properties.bufferSize, // pixels
                        projection: layerProjection)

                    // Skip layers whose bounding box doesn't intersect the tile
                    if let projectedBox = layer.datasource.boundingBox?.projected(to: layerProjection),
                       projectedBox.intersects(bounds) == false
                    {
                        continue
                    }

                    let envelope = "ST_MakeEnvelope(\(bounds.southWest.longitude), \(bounds.southWest.latitude), \(bounds.northEast.longitude), \(bounds.northEast.latitude), \(bounds.projection.srid))"

                    let sql = layer.datasource
                        .sql
                        .replacing("!bbox!", with: envelope)
                        .replacing("!scale_denominator!", with: String(scaleDenominator))
                        .replacing("!pixel_width!", with: String(pixelWidth))

                    let simplificationOption = self.configuration.simplification(tile.z, self.source)
                    let clippingOption = self.configuration.clipping(tile.z, self.source)
                    let validationOption = self.configuration.validation(tile.z, self.source)

                    let builder = PostgisQueryBuilder(
                        layer: layer,
                        sql: sql,
                        envelope: envelope,
                        simplificationTolerance: simplificationTolerance,
                        clipping: clippingOption,
                        simplification: simplificationOption,
                        validation: validationOption)

                    let clipBounds = (clippingOption == .local ? bounds : nil)
                    let localSimplificationTolerance = (builder.usesLocalSimplification ? simplificationTolerance : nil)

                    queryTasksCount += 1
                    group.addTask {
                        let (features, performanceData) = try await layerLoader(
                            builder.query,
                            layer,
                            layerProjection,
                            clipBounds,
                            localSimplificationTolerance,
                            self.configuration.featureMapping,
                            nextBatchId)
                        return (layer.id, layer.datasource.databaseName, features, performanceData)
                    }
                }

                var layerIdToRuntimeMapping: [String: MVTLayerPerformanceData]?
                if self.configuration.trackRuntimes {
                    layerIdToRuntimeMapping = [:]
                }

                guard queryTasksCount > 0 else {
                    return (tileVar, layerIdToRuntimeMapping)
                }

                // Add a timeout for the whole tile/batch
                let poolDistributor = self.poolDistributor
                let logger = self.logger
                let sourceName = source.name
                let externalName = externalName

                group.addTask {
                    let interval = deadline.timeIntervalSinceNow
                    if interval > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    }
                    guard Task.isCancelled == false else {
                        return ("", "", [], MVTLayerPerformanceData(runtime: 0.0, wkbBytes: 0, features: 0, invalidFeatures: 0, sqlQuery: ""))
                    }

                    let timedOutQueries = await poolDistributor
                        .poolInfos(batchId: nextBatchId)
                        .flatMap({ pool in
                            pool.connections.compactMap({ connection -> String? in
                                let query = connection.query ?? "<unknown>"
                                let runtime = connection.queryRuntime ?? 0.0
                                return "Query runtime: \(Int(runtime))s\n\(query)"
                            })
                        })

                    logger.info("\(externalName ?? sourceName): Batch \(nextBatchId) (\(tile.z)/\(tile.x)/\(tile.y)) timed out after \(self.configuration.tileTimeout) seconds:\n\(timedOutQueries.joined(separator: "\n"))")
                    throw MVTPostgisError.tileTimedOut(queries: timedOutQueries)
                }

                do {
                    for try await (layerId, databaseName, features, performanceData) in group {
                        guard layerId.isNotEmpty else { continue }

                        tileVar.appendFeatures(features, to: layerId)

                        if self.configuration.trackRuntimes {
                            layerIdToRuntimeMapping?["\(externalName ?? source.name).\(databaseName).\(layerId)"] = performanceData
                        }

                        finishedTasksCount += 1
                        if finishedTasksCount == queryTasksCount {
                            group.cancelAll()
                        }
                    }
                }
                catch {
                    group.cancelAll()
                    await poolDistributor.abortBatch(nextBatchId)
                    throw error
                }

                return (tileVar, layerIdToRuntimeMapping)
            })
    }

    // MARK: - Private

    private func queryBounds(
        tile: MapTile,
        tileSize: Int,
        bufferSize: Int,
        projection: Projection,
    ) throws -> BoundingBox {
        guard projection.hasSRID,
              projection.kind == .planar || projection.kind == .geographic
        else {
            throw MVTPostgisError.unsupportedSRID
        }

        var bounds = tile.boundingBox(projection: projection)

        if bufferSize != 0 {
            let sqrt2 = 2.0.squareRoot()
            let diagonal = Double(tileSize) * sqrt2
            let bufferDiagonal = Double(bufferSize) * sqrt2
            let factor = bufferDiagonal / diagonal

            let diagonalLength = bounds.southWest.distance(from: bounds.northEast)
            let distance = diagonalLength * factor

            bounds = bounds.expanded(byDistance: distance)
        }

        return bounds
    }

    private func simplificationTolerance(
        pixelWidth: Double,
        atZoom zoom: Int,
    ) -> Double {
        // pixelWidth at zoom 10
        pixelWidth * ((((0.6 - 1.4) / 20.0) * Double(zoom)) + 1.4)
    }

    /// The resulting features are in the layer's projection. The caller
    /// projects them into the tile projection when appending them.
    private func load(
        query: String,
        layer: PostgisLayer,
        projection: Projection,
        clipBounds: BoundingBox?,
        simplificationTolerance: Double?,
        featureMapping: (@Sendable (_ feature: Feature) -> Feature)?,
        batchId: Int,
    ) async throws -> (features: [Feature], performance: MVTLayerPerformanceData) {
        if Task.isCancelled {
            throw MVTPostgisError.cancelled
        }

        let features = ThreadSafeArrayCollector<Feature>()
        let runtime = ThreadSafeObjectCollector<TimeInterval>(0.0)
        let wkbBytes = ThreadSafeObjectCollector<Int64>(0)
        let invalidFeatures = ThreadSafeObjectCollector<Int>(0)

        let geometryColumn = layer.datasource.geometryField?.nilIfEmpty ?? "geometry"
        try await poolDistributor.connection(
            forLayer: layer,
            batchId: batchId,
            callback: { connection in
                let startTimestamp = Date()

                let rowSequence = try await connection.query(PostgresQuery(stringLiteral: query), logger: logger)

                // Probably a long running connection
                guard connection.isClosed == false else {
                    throw MVTPostgisError.connectionFailed
                }

                for try await serialRow in rowSequence {
                    let row = serialRow.makeRandomAccess()

                    guard row.contains(geometryColumn) else {
                        // TODO: Throw error or find a suitable column
                        logger.warning("\(externalName ?? source.name): Couldn't find the geometry column '\(geometryColumn)' in layer \(layer.id)")
                        break
                    }
                    guard let geometryBytes = row[data: geometryColumn].value else { continue }

                    let geometryData = Data(buffer: geometryBytes)

                    var properties: [String: Sendable] = [:]
                    for field in row {
                        guard field.columnName != geometryColumn else { continue }

                        switch field.dataType {
                        case .bpchar, .text, .varchar:
                            properties[field.columnName] = row[data: field.columnName].string

                        case .textArray, .varcharArray:
                            if let array = row[data: field.columnName].array {
                                properties[field.columnName] = array.compactMap(\.string)
                            }

                        case .uuid:
                            properties[field.columnName] = row[data: field.columnName].string

                        case .uuidArray:
                            if let array = row[data: field.columnName].array {
                                properties[field.columnName] = array.compactMap(\.string)
                            }

                        case .int2, .int4, .int8:
                            properties[field.columnName] = row[data: field.columnName].int

                        case .int2Array, .int4Array, .int8Array:
                            if let array = row[data: field.columnName].array {
                                properties[field.columnName] = array.compactMap(\.int)
                            }

                        case .float4, .float8, .numeric:
                            properties[field.columnName] = row[data: field.columnName].double

                        case .float4Array, .float8Array:
                            if let array = row[data: field.columnName].array {
                                properties[field.columnName] = array.compactMap(\.double)
                            }

                        case .bool:
                            properties[field.columnName] = row[data: field.columnName].bool

                        case .boolArray:
                            if let array = row[data: field.columnName].array {
                                properties[field.columnName] = array.compactMap(\.bool)
                            }

                        case .date, .timestamp, .timestamptz:
                            properties[field.columnName] = row[data: field.columnName].date?.ISO8601Format()

                        case .dateArray, .timestampArray, .timestamptzArray:
                            if let array = row[data: field.columnName].array {
                                properties[field.columnName] = array.compactMap({ $0.date?.ISO8601Format })
                            }

                        default:
                            // select * from pg_type where oid = ?;
                            // Please open an issue if you need more
                            logger.debug("\(externalName ?? source.name): Unknown type OID \(field.dataType.rawValue) for column '\(field.columnName)' in layer '\(layer.id)'")
                        }
                    }

                    wkbBytes.set(wkbBytes.item + Int64(geometryData.count))

                    // The vector tile spec only allows Int ids
                    var featureId: Feature.Identifier?
                    if properties["id"] is Int {
                        featureId = .init(value: properties.removeValue(forKey: "id"))
                    }

                    let feature = Feature(
                        wkb: geometryData,
                        sourceProjection: projection,
                        targetProjection: projection,
                        id: featureId,
                        properties: properties)

                    guard var feature else {
                        invalidFeatures.set(invalidFeatures.item + 1)
                        continue
                    }

                    if let featureMapping {
                        feature = featureMapping(feature)
                    }

                    if let clipBounds, let simplificationTolerance {
                        guard let clippedFeature = feature.clipped(to: clipBounds) else {
                            invalidFeatures.set(invalidFeatures.item + 1)
                            continue
                        }

                        features.append(clippedFeature.simplified(tolerance: simplificationTolerance))
                    }
                    else if let clipBounds {
                        guard let clippedFeature = feature.clipped(to: clipBounds) else {
                            invalidFeatures.set(invalidFeatures.item + 1)
                            continue
                        }

                        features.append(clippedFeature)
                    }
                    else if let simplificationTolerance {
                        features.append(feature.simplified(tolerance: simplificationTolerance))
                    }
                    else {
                        features.append(feature)
                    }
                }

                runtime.set(fabs(startTimestamp.timeIntervalSinceNow))
            })

        logger.debug("\(externalName ?? source.name).\(layer.datasource.databaseName).\(layer.id): \(features.count) feature(s) (\(invalidFeatures.item) invalid) in \((runtime.item).rounded(toPlaces: 3))s (\(wkbBytes.item) bytes)")

//        if invalidFeatures.item > 0, logger.logLevel > .debug {
//            logger.info("\(externalName ?? source.name).\(layer.datasource.databaseName).\(layer.id): \(invalidFeatures.item) invalid features")
//        }

        // Features will be projected to EPSG:4326
        return (features.items, MVTLayerPerformanceData(runtime: runtime.item, wkbBytes: wkbBytes.item, features: features.count, invalidFeatures: invalidFeatures.item, sqlQuery: query))
    }

}
