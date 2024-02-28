import Foundation
import GISTools
import MVTTools
import PostgresNIO
import PostgresConnectionPool

// https://github.com/mapnik/mapnik/wiki/PostGIS
// https://github.com/mapnik/mapnik/wiki/OptimizeRenderingWithPostGIS
// https://github.com/mapnik/mapnik/blob/master/plugins/input/postgis/postgis_datasource.cpp
// https://github.com/mapnik/mapnik/blob/master/test/unit/datasource/postgis.cpp

/// A tool for creating vector tiles from Postgis datasources.
/// Accepts YML and XML sources (as used by Mapnik and the old Mapbox Studio), and new JSON sources.
public final class MVTPostgis {

    /// **MUST** be changed before first use. See ``MVTPostgisConfiguration``.
    public static var configuration: MVTPostgisConfiguration = MVTPostgisConfiguration()

    private static let postgisDatasourceTypeCode = "postgis"
    private static var batchId: Int = 0

    /// The minimum zoom of the datasource.
    public let minZoom: Int
    /// The maximum zoom of the datasource.
    public let maxZoom: Int

    /// The source.
    public let source: PostgisSource
    /// The source's projection (either EPSG:3857 or EPSG:4326).
    public let projection: Projection

    /// Some external name that users can coose to distinguish this
    /// instance from other instances. Used e.g. in runtime tracking
    /// and some error messages.
    public let externalName: String?

    // ===

    private let logger: Logger
    private let poolDistributor: PoolDistributor

    // MARK: -

    /// Initialize a MVT creator from a file or from the network.
    public convenience init(
        sourceURL: URL,
        externalName: String? = nil,
        layerWhitelist: [String]? = nil,
        logger: Logger? = nil)
        throws
    {
        let source = try PostgisSource.load(
            from: sourceURL,
            layerWhitelist: layerWhitelist)

        try self.init(
            source: source,
            externalName: externalName,
            logger: logger)
    }

    /// Initialize a MVT creator directly from a data object.
    public convenience init(
        sourceData: Data,
        externalName: String? = nil,
        layerWhitelist: [String]? = nil,
        logger: Logger? = nil)
        throws
    {
        let source = try PostgisSource.load(
            from: sourceData,
            layerWhitelist: layerWhitelist)

        try self.init(
            source: source,
            externalName: externalName,
            logger: logger)
    }

    /// Initialize a MVT creator directly with a parsed ``PostgisSource`` object.
    public init(
        source: PostgisSource,
        externalName: String? = nil,
        logger: Logger? = nil)
        throws
    {
        guard source.layers.count > 0 else { throw MVTPostgisError.needLayers }

        guard source.layers.allSatisfy({ $0.datasource.type == MVTPostgis.postgisDatasourceTypeCode }) else {
            throw MVTPostgisError.wrongDatasourceType(message: "All datasources must be of type '\(MVTPostgis.postgisDatasourceTypeCode)'")
        }

        let layer = source.layers[0]
        let datasource = layer.datasource

        projection = datasource.srid
        guard projection != .noSRID else { throw MVTPostgisError.unsupportedSRID }

        self.source = source
        self.externalName = externalName
        self.minZoom = source.minZoom
        self.maxZoom = source.maxZoom
        self.logger = logger ?? {
            var logger = Logger(label: "\(MVTPostgis.configuration.applicationName).\(externalName ?? source.name)")
            logger.logLevel = .info
            return logger
        }()
        self.poolDistributor = PoolDistributor(
            configuration: MVTPostgis.configuration,
            logger: self.logger)
    }

    /// Close all database connections.
    ///
    /// **MUST** be called when done with all MVTPostgis instances
    public func shutdown() async {
        await poolDistributor.shutdown()
    }

    /// Forcibly close all idle connections in all pools.
    public func closeIdleConnections() async {
        await poolDistributor.closeIdleConnections()
    }

    /// Information about database pools and open connections.
    public func poolInfos() async -> [PoolInfo] {
        await poolDistributor.poolInfos()
    }

    // MARK: -

    /// Return tile data at the given z/x/y coordinate.
    ///
    /// - Note: Only `bufferSize` from `options` will be used here.
    public func data(
        forTile tile: MapTile,
        options: VectorTileExportOptions)
        async throws -> (data: Data?, performance: [String: MVTLayerPerformanceData]?)
    {
        let tileAndPerformanceData = try await mvt(forTile: tile, options: options)
        return (tileAndPerformanceData.tile.data(options: options), tileAndPerformanceData.performance)
    }

    /// Create a tile at the given z/x/y coordinate.
    ///
    /// - Note: Only `bufferSize` from `options` will be used here.
    public func mvt(
        forTile tile: MapTile,
        options: VectorTileExportOptions? = nil)
        async throws -> (tile: VectorTile, performance: [String: MVTLayerPerformanceData]?)
    {
        if Task.isCancelled {
            throw MVTPostgisError.cancelled
        }

        // TODO: Serialize access
        let nextBatchId = MVTPostgis.batchId
        MVTPostgis.batchId += 1

        return try await withThrowingTaskGroup(
            of: (String, String, [Feature], MVTLayerPerformanceData).self,
            body: { group -> (tile: VectorTile, performance: [String: MVTLayerPerformanceData]?) in
                // Note: Geometries loaded from WKB will always be projected to EPSG:4326
                guard var mvt = VectorTile(tile: tile, projection: projection) else {
                    throw MVTPostgisError.tileOutOfBounds
                }

                // https://github.com/mapnik/mapnik/blob/master/src/scale_denominator.cpp
                // https://github.com/openstreetmap/mapnik-stylesheets/blob/master/zoom-to-scale.txt
                // 0.0293611270703125 ? (in nodejs/wms-client)
                let pixelSize = 0.00028 // 0.28mm, in meters
                let tileSize = GISTool.tileSideLength // 256px
                let scaleDenominator = GISTool.earthCircumference / ((tileSize * pow(2.0, Double(tile.z))) * pixelSize)
                let pixelWidth = tile.metersPerPixel
                let simplificationTolerance = simplificationTolerance(pixelWidth: pixelWidth, atZoom: tile.z)

                let deadline = Date(timeIntervalSinceNow: MVTPostgis.configuration.tileTimeout)
                let expectedTasksCount = source.layers.count
                var finishedTasksCount = 0

                for layer in source.layers {
                    let bounds = try queryBounds(
                        tile: tile,
                        tileSize: options?.tileSize ?? 256, // pixels
                        bufferSize: layer.properties.bufferSize) // pixels
                    let envelope = "ST_MakeEnvelope(\(bounds.southWest.longitude), \(bounds.southWest.latitude), \(bounds.northEast.longitude), \(bounds.northEast.latitude), \(bounds.projection.srid))"

                    let sql = layer.datasource.sql
                        .replacingOccurrences(of: "!bbox!", with: envelope)
                        .replacingOccurrences(of: "!scale_denominator!", with: String(scaleDenominator))
                        .replacingOccurrences(of: "!pixel_width!", with: String(pixelWidth))

                    let geometryField = layer.datasource.geometryField?.nilIfEmpty ?? "geometry"
                    let simplificationOption = MVTPostgis.configuration.simplification(tile.z, self.source)
                    let clippingOption = MVTPostgis.configuration.clipping(tile.z, self.source)
                    var columns = layer.fields.keys.map({ "\"\($0)\"" })
                    var useLocalSimplification = false

                    // Assemble the geometry query
                    var postgisGeometryColumn = "ST_AsBinary("
                    switch simplificationOption {
                    case .postgis, .meters(_, _): postgisGeometryColumn.append("ST_Simplify(")
                    case .local: useLocalSimplification = true
                    default: break
                    }
                    if clippingOption == .postgis {
                        postgisGeometryColumn.append("ST_ClipByBox2D(")
                    }
                    postgisGeometryColumn.append("\"\(geometryField)\"")
                    if clippingOption == .postgis {
                        postgisGeometryColumn.append(",\(envelope))")
                    }
                    if case let .postgis(preserveCollapsed) = simplificationOption {
                        postgisGeometryColumn.append(",\(simplificationTolerance)")
                        if preserveCollapsed {
                            postgisGeometryColumn.append(",true")
                        }
                        postgisGeometryColumn.append(")")
                    }
                    else if case let .meters(meters, preserveCollapsed) = simplificationOption {
                        postgisGeometryColumn.append(",\(meters)")
                        if preserveCollapsed {
                            postgisGeometryColumn.append(",true")
                        }
                        postgisGeometryColumn.append(")")
                    }
                    postgisGeometryColumn.append(") AS \"\(geometryField)\"")
                    columns.append(postgisGeometryColumn)

                    // The final query
                    let query = "SELECT \(columns.joined(separator: ",")) FROM \(sql)"

                    let clipBounds = (clippingOption == .local ? bounds : nil)
                    let localSimplificationTolerance = (useLocalSimplification ? simplificationTolerance : nil)

                    group.addTask {
                        let (features, performanceData) = try await self.load(
                            query: query,
                            layer: layer,
                            projection: self.projection,
                            clipBounds: clipBounds,
                            simplificationTolerance: localSimplificationTolerance,
                            batchId: nextBatchId)
                        return (layer.id, layer.datasource.databaseName, features, performanceData)
                    }
                }

                // Add a timeout for the whole tile/batch
                group.addTask { [weak self] in
                    let interval = deadline.timeIntervalSinceNow
                    if interval > 0 {
                        do {
                            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                        }
                        catch {}
                    }
                    guard Task.isCancelled else {
                        let timedOutQueries = await self?.poolDistributor
                            .poolInfos(batchId: nextBatchId)
                            .flatMap({ pool in
                                pool.connections.compactMap({ connection -> String? in
                                    let query = connection.query ?? "<unknown>"
                                    let runtime = connection.queryRuntime ?? 0.0
                                    return "Query runtime: \(Int(runtime))s\n\(query)"
                                })
                            }) ?? []

                        self?.logger.info("\(self?.externalName ?? self?.source.name ?? "n/a"): Batch \(nextBatchId) (\(tile.z)/\(tile.x)/\(tile.y)) timed out after \(MVTPostgis.configuration.tileTimeout) seconds:\n\(timedOutQueries.joined(separator: "\n"))")
                        throw MVTPostgisError.tileTimedOut(queries: timedOutQueries)
                    }
                    return ("", "", [], MVTLayerPerformanceData(runtime: 0.0, wkbBytes: 0, features: 0, invalidFeatures: 0))
                }

                var layerIdToRuntimeMapping: [String: MVTLayerPerformanceData]?
                if MVTPostgis.configuration.trackRuntimes {
                    layerIdToRuntimeMapping = [:]
                }

                do {
                    for try await (layerId, databaseName, features, performanceData) in group {
                        guard layerId.isNotEmpty else { continue }

                        mvt.appendFeatures(features, to: layerId)

                        if MVTPostgis.configuration.trackRuntimes {
                            layerIdToRuntimeMapping?["\(externalName ?? source.name).\(databaseName).\(layerId)"] = performanceData
                        }

                        // The last task to finish is (should be) the timeout task
                        finishedTasksCount += 1
                        if finishedTasksCount == expectedTasksCount {
                            group.cancelAll()
                        }
                    }
                }
                catch {
                    group.cancelAll()
                    await poolDistributor.abortBatch(nextBatchId)
                    throw error
                }

                return (mvt, layerIdToRuntimeMapping)
            })
    }

    // MARK: - Private

    private func queryBounds(
        tile: MapTile,
        tileSize: Int,
        bufferSize: Int) // pixels
        throws -> BoundingBox
    {
        var bounds: BoundingBox

        switch projection {
        case .noSRID:
            throw MVTPostgisError.unsupportedSRID
        case .epsg3857:
            bounds = tile.boundingBox(projection: .epsg3857)
        case .epsg4326:
            bounds = tile.boundingBox(projection: .epsg4326)
        }

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
        atZoom zoom: Int)
        -> Double
    {
        // pixelWidth at zoom 10
        pixelWidth * ((((0.6 - 1.4) / 20.0) * Double(zoom)) + 1.4)
    }

    // The resulting features will always be projected to EPSG:4326
    private func load(
        query: String,
        layer: PostgisLayer,
        projection: Projection,
        clipBounds: BoundingBox?,
        simplificationTolerance: Double?,
        batchId: Int)
        async throws -> (features: [Feature], performance: MVTLayerPerformanceData)
    {
        if Task.isCancelled {
            throw MVTPostgisError.cancelled
        }

        var features: [Feature] = []
        var runtime: TimeInterval = 0.0
        var wkbBytes: Int64 = 0
        var invalidFeatures: Int = 0

        let geometryColumn = layer.datasource.geometryField?.nilIfEmpty ?? "geometry"
        try await poolDistributor.connection(
            forLayer: layer,
            batchId: batchId,
            callback: { connection in
                let startTimestamp = Date()

                let rowSequence = try await connection.query(PostgresQuery(stringLiteral: query), logger: logger)

                // Probably a long running connection
                guard !connection.isClosed else {
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

                    var properties: [String: Any] = [:]
                    for field in row {
                        guard field.columnName != geometryColumn else { continue }

                        switch field.dataType {
                        case .bpchar, .varchar, .text:
                            properties[field.columnName] = row[data: field.columnName].string
                        case .varcharArray, .textArray:
                            if let array = row[data: field.columnName].array {
                                properties[field.columnName] = array.compactMap({ $0.string })
                            }

                        case .int2, .int4, .int8:
                            properties[field.columnName] = row[data: field.columnName].int
                        case .int2Array, .int4Array, .int8Array:
                            if let array = row[data: field.columnName].array {
                                properties[field.columnName] = array.map({ $0.int })
                            }

                        case .float4, .float8, .numeric:
                            properties[field.columnName] = row[data: field.columnName].double
                        case .float4Array, .float8Array:
                            if let array = row[data: field.columnName].array {
                                properties[field.columnName] = array.map({ $0.double })
                            }

                        case .bool:
                            properties[field.columnName] = row[data: field.columnName].bool
                        case .boolArray:
                            if let array = row[data: field.columnName].array {
                                properties[field.columnName] = array.map({ $0.bool })
                            }

                        default:
                            // select * from pg_type where oid = ?;
                            // Please open an issue if you need more
                            logger.debug("\(externalName ?? source.name): Unknown type OID \(field.dataType.rawValue) for column '\(field.columnName)' in layer '\(layer.id)'")
                        }
                    }

                    wkbBytes += Int64(geometryData.count)

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

                    guard let feature else {
                        invalidFeatures += 1
                        continue
                    }

                    if let clipBounds, let simplificationTolerance {
                        guard let clippedFeature = feature.clipped(to: clipBounds) else {
                            invalidFeatures += 1
                            continue
                        }
                        features.append(clippedFeature.simplified(tolerance: simplificationTolerance))
                    }
                    else if let clipBounds {
                        guard let clippedFeature = feature.clipped(to: clipBounds) else {
                            invalidFeatures += 1
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

                runtime = fabs(startTimestamp.timeIntervalSinceNow)
            })

        logger.debug("\(externalName ?? source.name).\(layer.datasource.databaseName).\(layer.id): \(features.count) feature(s) (\(invalidFeatures) invalid) in \(runtime.rounded(toPlaces: 3))s (\(wkbBytes) bytes)")

//        if invalidFeatures > 0, logger.logLevel > .debug {
//            logger.info("\(externalName ?? source.name).\(layer.datasource.databaseName).\(layer.id): \(invalidFeatures) invalid features")
//        }

        // Features will be projected to EPSG:4326
        return (features, MVTLayerPerformanceData(runtime: runtime, wkbBytes: wkbBytes, features: features.count, invalidFeatures: invalidFeatures))
    }

}
