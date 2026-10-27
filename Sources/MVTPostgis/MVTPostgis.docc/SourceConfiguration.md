# Source configuration

Sources can be written as JSON, Mapnik YML, or Mapnik XML.

## Model

A ``PostgisSource`` contains metadata and one or more ``PostgisLayer`` values.
Each layer owns a ``PostgisDatasource`` with connection parameters and SQL.

```swift
let datasource = PostgisDatasource(
    user: "reader",
    password: "secret",
    host: "localhost",
    port: 5432,
    databaseName: "gis",
    geometryField: "way",
    srid: .epsg3857,
    type: "postgis",
    sql: "(SELECT * FROM roads WHERE way && !bbox!) AS roads")

let layer = PostgisLayer(
    id: "roads",
    fields: ["name": "Road name"],
    properties: .init(bufferSize: 64),
    datasource: datasource)

let source = PostgisSource(
    name: "roads-source",
    center: Coordinate3D(latitude: 48.1, longitude: 11.5),
    defaultZoom: 14,
    layers: [layer])
```

The JSON format mirrors these types directly. The YML and XML readers accept
the corresponding Mapnik datasource syntax.

## SQL placeholders

The SQL query should contain `!bbox!`. It is replaced with an
`ST_MakeEnvelope` expression for the tile bounds and the layer's SRID.

The following Mapnik placeholders are also supported:

| Placeholder | Replacement |
|---|---|
| `!bbox!` | Tile bounding box as `ST_MakeEnvelope` |
| `!scale_denominator!` | Mapnik-style scale denominator for the zoom |
| `!pixel_width!` | Tile pixel width in the layer's map units |

The SQL is used as the `FROM` expression, so it should normally be a
parenthesized subquery with an alias.

## Projections

Each layer can use any planar or geographic projection registered in GISTools.
The tile's projection is taken from the first layer, and features from layers
with a different projection are reprojected when they are appended to the
tile.

Geocentric projections such as EPSG:4978 and `noSRID` are rejected.

## Optional values

JSON fields such as `description`, `attribution`, `center`, `fields`,
`properties`, `password`, `port`, `geometryField` and `boundingBox` have
defaults. YML and XML sources are equally tolerant of omitted metadata.

The `boundingBox` is an optional prefilter: layers whose datasource extent does
not intersect the tile are skipped without opening a database connection.

The `bufferSize` is the layer buffer in pixels. Negative values are clamped to
zero.
