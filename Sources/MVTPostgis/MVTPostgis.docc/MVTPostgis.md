# ``MVTPostgis``

Create Mapbox Vector Tiles (MVT) and MapLibre Tiles (MLT) directly from
PostGIS databases using Mapnik-style datasource definitions.

## Overview

`MVTPostgis` parses a source definition, connects to one or more PostgreSQL
databases, runs the configured spatial queries, decodes the WKB geometries,
and assembles a `VectorTile`. Clipping, simplification, validation and feature
mapping are configurable per zoom level.

```swift
import MVTPostgis

MVTPostgis.configuration = MVTPostgisConfiguration(
    applicationName: "MyTileServer",
    poolSize: 8,
    trackRuntimes: true)

let postgis = try MVTPostgis(sourceURL: sourceURL)
let (tile, performance) = try await postgis.vectorTile(
    forTile: MapTile(x: 8716, y: 8015, z: 14))
let data = tile.mvtData()

await postgis.shutdown()
```

Always call ``MVTPostgis/shutdown()`` when the instance is no longer needed.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:SourceConfiguration>

### Tile generation

- <doc:TilesAndOptions>

### Runtime behaviour

- <doc:PerformanceAndPooling>
- <doc:Limitations>
