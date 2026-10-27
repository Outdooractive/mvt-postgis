# Performance and pooling

Each `MVTPostgis` instance owns a `PoolDistributor` that caches one
`PostgresConnectionPool` per database connection key.

## Configuration

Relevant ``MVTPostgisConfiguration`` values:

- `poolSize`: maximum connections per database pool.
- `maxIdleConnections`: maximum idle connections over a 60-second period.
- `connectTimeout`: timeout for opening a connection.
- `queryTimeout`: per-query timeout; `nil` disables it.
- `tileTimeout`: total time allowed for one tile.
- `trackRuntimes`: return per-layer statistics with each tile.

## Runtime information

```swift
let pools = await postgis.poolInfos()
let (tile, performance) = try await postgis.vectorTile(forTile: tile)

for (layer, data) in performance ?? [:] {
    print(layer, data.runtime, data.features, data.wkbBytes)
}
```

``MVTLayerPerformanceData`` contains the query runtime, WKB bytes, feature
count, invalid-feature count and the SQL query.

## Connection lifecycle

```swift
await postgis.closeIdleConnections()  // close idle connections only
await postgis.shutdown()              // close all pools
```

If a pool shuts itself down after a database outage, the distributor performs
a cheap TCP reachability check before creating a replacement. While the
database is unreachable, requests fail fast against the dead pool instead of
allocating a new event loop group for every request.
