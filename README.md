[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FOutdooractive%2Fmvt-postgis%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Outdooractive/mvt-postgis)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FOutdooractive%2Fmvt-postgis%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Outdooractive/mvt-postgis)

# MVTPostgis

Creates Mapbox Vector Tiles (MVT) and MapLibre Tiles (MLT) from PostGIS databases, using configurable Mapnik-style datasource definitions.

This library handles the full pipeline: parse source configurations (YML, XML, or JSON), connect to PostgreSQL/PostGIS,
execute spatial queries with per-zoom-level SQL generation, decode WKB geometries, clip and simplify features,
and assemble MVT tiles — with connection pooling, configurable timeouts, and runtime performance tracking.

## Requirements

This package requires Swift 6.3 or higher (at least Xcode 15), and compiles on macOS (\>= macOS 15) as well as Linux.

## Installation with Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Outdooractive/mvt-postgis", from: "2.0.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "MVTPostgis", package: "mvt-postgis"),
    ]),
]
```

This project builds on two other libraries that handle the heavy lifting:
- [**gis-tools**](https://github.com/Outdooractive/gis-tools) — geometry types, projections, WKB coding, R-Tree
- [**mvt-tools**](https://github.com/Outdooractive/mvt-tools) — VectorTile model, MVT encode/decode, ExportOptions

## Features

- **Source parsing** — load datasource configurations from YML (Mapnik), XML (Mapnik/Mapbox Studio), or JSON
- **Connection pooling** — per-database pools with configurable size, idle connection limits, and timeouts
- **Configurable clipping** — clip features in PostGIS (`ST_ClipByBox2D`), locally before adding to the tile, or at MVT encode time
- **Configurable simplification** — simplify in PostGIS (`ST_Simplify`), locally, or with per-zoom meter tolerances
- **Geometry validation** — apply `ST_MakeValid` with `default`, `linework`, or `structure` algorithm
- **Feature mapping** — transform features after creation (before clipping/simplification) via a callback
- **Runtime tracking** — per-layer query times, WKB byte counts, feature counts, and invalid feature counts
- **Batch query execution** — layers are split into batches and queried concurrently with `TaskGroup`
- **Cancellation support** — tile creation can be cancelled mid-flight via `Task.cancel()`
- **Per-zoom configuration** — clipping, simplification, and validation strategies can vary by zoom level
- **Mapnik compatibility** — follows the Mapnik PostGIS datasource conventions for layer definitions, extent calculations, and scale denominators

## Usage

### Configuration

Set up the global configuration before creating any instances:

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

### Initialize from a source file

```swift
let mvtPostgis = try MVTPostgis(sourceURL: URL(fileURLWithPath: "datasource.yml"))
// or from XML:
let mvtPostgis = try MVTPostgis(sourceURL: URL(fileURLWithPath: "datasource.xml"))
```

### Create a tile

```swift
let tile = MapTile(x: 8716, y: 8015, z: 14)

// Get the VectorTile directly for further processing
let (vectorTile, performance) = try await mvtPostgis.vectorTile(forTile: tile)

// Encode to MVT data
let (mvtData, performance) = try await mvtPostgis.data(
    forTile: tile,
    format: .mvt,
    options: VectorTile.ExportOptions(
        bufferSize: .pixel(4),
        compression: .default))

// Encode to MLT data
let (mltData, performance) = try await mvtPostgis.data(
    forTile: tile,
    format: .mlt,
    options: VectorTile.ExportOptions(
        bufferSize: .pixel(4)))
```

### YML source format (Mapnik-compatible)

```yml
name: my-datasource
minzoom: 0
maxzoom: 20
layers:
  - id: roads
    datasource:
      type: postgis
      host: localhost
      port: 5432
      dbname: gis
      user: reader
      password: secret
      table: (
        SELECT osm_id, highway, name, way
        FROM planet_osm_roads
        WHERE way && !bbox!
      ) AS roads
    geometry_field: way
    srid: 3857
    extent: -20037508.34,-20037508.34,20037508.34,20037508.34
```

### XML source format (Mapnik/Mapbox Studio)

```xml
<Layer name="roads" srs="+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0.0 +k=1.0 +units=m +nadgrids=@null +wktext +no_defs">
    <StyleName>roads</StyleName>
    <Datasource>
        <Parameter name="type">postgis</Parameter>
        <Parameter name="host">localhost</Parameter>
        <Parameter name="port">5432</Parameter>
        <Parameter name="dbname">gis</Parameter>
        <Parameter name="user">reader</Parameter>
        <Parameter name="password">secret</Parameter>
        <Parameter name="table">(SELECT * FROM roads WHERE way && !bbox!) AS roads</Parameter>
        <Parameter name="geometry_field">way</Parameter>
        <Parameter name="srid">3857</Parameter>
        <Parameter name="extent">-20037508.34,-20037508.34,20037508.34,20037508.34</Parameter>
    </Datasource>
</Layer>
```

### JSON source format

The JSON format mirrors the `PostgisSource` → `PostgisLayer` → `PostgisDatasource` Codable structure:

```json
{
  "name": "Test Source",
  "description": "A test source for testing",
  "attribution": "Here goes the copyright",
  "center": [10.22, 47.56],
  "defaultZoom": 10,
  "minZoom": 1,
  "maxZoom": 16,
  "layers": [
    {
      "id": "First layer",
      "description": "Optional layer description",
      "fields": {
        "type": "Description of the type field",
        "geometry": ""
      },
      "properties": {
        "bufferSize": 128
      },
      "datasource": {
        "user": "postgres",
        "password": "secret",
        "host": "localhost",
        "port": 5432,
        "databaseName": "gis",
        "geometryField": "geometry",
        "boundingBox": [10, 47, 11, 48],
        "srid": 4326,
        "type": "postgis",
        "sql": "(SELECT type, geometry FROM some_table WHERE geometry && !bbox!) AS data"
      }
    }
  ]
}
```

| Field | Type | Description |
|---|---|---|
| `name` | string | Source name |
| `description` | string | Source description |
| `attribution` | string | Copyright attribution |
| `center` | [lon, lat] | Default center coordinate |
| `defaultZoom` | integer | Default zoom level |
| `minZoom` | integer | Minimum zoom |
| `maxZoom` | integer | Maximum zoom |
| `layers[]` | array | Array of layer definitions |
| `layers[].id` | string | Layer name |
| `layers[].description` | string? | Optional layer description |
| `layers[].fields` | object | Map of field names to descriptions |
| `layers[].properties.bufferSize` | integer | Tile buffer in pixels |
| `layers[].datasource.user` | string | PostgreSQL user |
| `layers[].datasource.password` | string | PostgreSQL password |
| `layers[].datasource.host` | string | PostgreSQL hostname |
| `layers[].datasource.port` | integer | PostgreSQL port |
| `layers[].datasource.databaseName` | string | Database name |
| `layers[].datasource.geometryField` | string? | Geometry column name (default: `"geometry"`) |
| `layers[].datasource.boundingBox` | [minLon, minLat, maxLon, maxLat]? | Datasource extent |
| `layers[].datasource.srid` | integer | SRID (4326 or 3857) |
| `layers[].datasource.type` | string | Must be `"postgis"` |
| `layers[].datasource.sql` | string | SQL query with `!bbox!` placeholder |

The SQL query **must** contain a `!bbox!` placeholder — it is replaced with the tile's bounding box at query time.

### Shutdown

Always call `shutdown()` when done to close all database connections:

``` swift
try await mvtPostgis.shutdown()
```

## See also

- [API documentation](https://swiftpackageindex.com/Outdooractive/mvt-postgis/main/documentation/mvtpostgis)
- [gis-tools](https://github.com/Outdooractive/gis-tools) — geometry types, projections, WKB coding
- [mvt-tools](https://github.com/Outdooractive/mvt-tools) — VectorTile model, MVT encode/decode
- [Mapnik PostGIS documentation](https://github.com/mapnik/mapnik/wiki/PostGIS)
- [Optimize rendering with PostGIS](https://github.com/mapnik/mapnik/wiki/OptimizeRenderingWithPostGIS)

## License

MIT

## Author

Thomas Rasch, Outdooractive
