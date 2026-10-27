# Tiles and options

Tile creation is configured per zoom level through
``MVTPostgisConfiguration``.

## Clipping

``MVTClippingOption`` controls where features are clipped:

- `.none`: no clipping during loading; clipping happens later during MVT/MLT
  encoding. This can use a lot of memory.
- `.postgis`: clip with `ST_ClipByBox2D` in the database.
- `.local`: clip in Swift after loading.

## Simplification

``MVTSimplificationOption`` controls simplification:

- `.none`: no simplification.
- `.local`: simplify in Swift after loading.
- `.postgis(preserveCollapsed:)`: use `ST_Simplify` with a zoom-dependent
  tolerance.
- `.meters(_:preserveCollapsed:)`: pass a fixed tolerance to `ST_Simplify`.

The local simplification tolerance is derived from the tile's pixel width and
zoom.

## Validation

``MVTMakeValidOption`` controls `ST_MakeValid`:

- `.none`
- `.default`
- `.linework`
- `.structure(keepCollapsed:)`

## Feature mapping

`featureMapping` is an optional `@Sendable` closure that receives every
`Feature` after WKB decoding and before clipping or simplification:

```swift
MVTPostgis.configuration = MVTPostgisConfiguration(
    featureMapping: { feature in
        var mapped = feature
        mapped.setProperty("source", for: "postgis")
        return mapped
    })
```

## Output formats

``TileOutputFormat`` selects the encoder:

```swift
let (mvtData, _) = try await postgis.data(forTile: tile, format: .mvt, options: options)
let (mltData, _) = try await postgis.data(forTile: tile, format: .mlt, options: options)
```

`VectorTile.ExportOptions` controls buffering, compression and simplification
during encoding.

## Cancellation

`vectorTile(forTile:)` checks `Task.isCancelled` and also cancels outstanding
database work when the task group is cancelled. Handle
``MVTPostgisError/cancelled`` at the call site if cancellation is expected.
