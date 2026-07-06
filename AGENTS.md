# AGENTS.md

# mvt-postgis — Vector Tiles from PostGIS

A Swift library that creates [Mapbox Vector Tiles (MVT)](https://github.com/mapbox/vector-tile-spec/tree/master/2.1)
directly from [PostGIS](https://postgis.net/) databases, following the
[Mapnik PostGIS datasource](https://github.com/mapnik/mapnik/wiki/PostGIS) conventions.

Sources can be defined in YML (Mapnik), XML (Mapnik/Mapbox Studio), or JSON format.

One product:
- **`MVTPostgis`** — library target: reads PostGIS datasource configurations, queries PostgreSQL/PostGIS databases,
  builds MVT tiles with configurable clipping, simplification, validation, connection pooling, and runtime tracking.

Key source areas:
- **`MVTPostgis.swift`** — Main entry point: `MVTPostgis` class. Accepts source definitions (YML/XML/JSON),
  manages database connection pools, orchestrates tile creation via `mvt(forTile:options:)` and `data(forTile:options:)`.
- **`MVTPostgisConfiguration.swift`** — Global configuration: connection pool size, timeouts, clipping/simplification/validation
  strategies (per-zoom-level closures), feature mapping callback, runtime tracking.
- **`Postgis/PostgisSource.swift`** — Source definition model: parses YML/XML/JSON datasource files into a structured
  `PostgisSource` with layers, projections, and connection parameters.
- **`Postgis/PostgisLayer.swift`** — Layer definition: table/query, geometry field, srid, extent, feature mapping rules.
- **`Postgis/PostgisDatasource.swift`** — Datasource connection parameters: host, port, database, user, password, pool size.
- **`Postgis/Mapnik/MapnikYMLSource.swift`** — YML source parser (Mapnik `datasource` format).
- **`Postgis/Mapnik/MapnikXMLSource.swift`** — XML source parser (Mapnik/Mapbox Studio format).
- **`Pool/PoolDistributor.swift`** — Connection pool distributor: manages per-database `PostgresConnectionPool` instances,
  assigns connections to layers respecting batch limits.
- **`MVTLayerPerformanceData.swift`** — Per-layer runtime statistics: query time, WKB bytes, feature count, invalid feature count.
- **`MVTPostgisError.swift`** — Error types: connection failures, invalid sources, tile bounds, cancellation.
- **`Extensions/`** — Thread-safe collectors (`ThreadSafeArrayCollector`, `ThreadSafeObjectCollector`), task extensions,
  numeric helpers.

Dependencies:
- **MVTTools** — `VectorTile`, MVT encode/decode, `ExportOptions`
- **GISTools** — geometry types (`Feature`, `Coordinate3D`, `BoundingBox`, `MapTile`), projections, WKB coding
- **PostgresConnectionPool** — database connection pooling
- **PostgresNIO** — async PostgreSQL client
- **swift-collections** — `Deque` for batch management
- **SwiftyXMLParser** — XML source file parsing
- **Yams** — YAML source file parsing

## Build & test

```bash
swift build           # build library
swift test            # run all tests (Swift Testing)
```

## Code style conventions

Follow the same conventions as mvt-tools (4-space indentation, no tabs, DocC documentation,
Swift 6 concurrency, etc.). All new types must be `Sendable`.
