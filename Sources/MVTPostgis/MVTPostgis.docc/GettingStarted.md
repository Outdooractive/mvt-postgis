# Getting started

Install the package, configure it once, load a source and create a tile.

## Add the package

```swift
dependencies: [
    .package(url: "https://github.com/Outdooractive/mvt-postgis", from: "2.0.0"),
],
targets: [
    .target(
        name: "MyTileServer",
        dependencies: [
            .product(name: "MVTPostgis", package: "mvt-postgis"),
        ]),
]
```

## Configure

``MVTPostgis/configuration`` is the default configuration for new instances.
Set it before creating the first instance:

```swift
import MVTPostgis

MVTPostgis.configuration = MVTPostgisConfiguration(
    applicationName: "MyTileServer",
    connectTimeout: 5.0,
    queryTimeout: 10.0,
    tileTimeout: 60.0,
    poolSize: 10,
    maxIdleConnections: 5,
    clipping: { zoom, _ in zoom > 10 ? .local : .postgis },
    simplification: { zoom, _ in zoom < 12 ? .postgis(preserveCollapsed: true) : .none },
    validation: { zoom, _ in zoom > 15 ? .default : .none },
    trackRuntimes: true)
```

An individual instance can override the default:

```swift
let postgis = try MVTPostgis(
    sourceURL: sourceURL,
    configuration: MVTPostgisConfiguration(poolSize: 4))
```

## Load a source and create a tile

```swift
let postgis = try MVTPostgis(sourceURL: URL(fileURLWithPath: "datasource.yml"))
let tile = MapTile(x: 8716, y: 8015, z: 14)

let (vectorTile, performance) = try await postgis.vectorTile(forTile: tile)
let (mvtData, _) = try await postgis.data(
    forTile: tile,
    format: .mvt,
    options: VectorTile.ExportOptions(
        bufferSize: .pixel(4),
        compression: .default))
```

## Shut down

```swift
await postgis.shutdown()
```

`shutdown()` closes every connection pool owned by the instance. A later
request will create pools again when needed.
