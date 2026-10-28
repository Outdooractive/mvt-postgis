# Limitations

## Supported projections

PostGIS layers must use a planar or geographic projection registered in
GISTools (for example EPSG:4326, EPSG:3857, or a UTM zone). Geocentric
projections such as EPSG:4978 and `noSRID` are rejected with
``MVTPostgisError/unsupportedSRID``.

## SQL is trusted configuration

The SQL query and field/geometry names come from the source configuration. The
library quotes identifiers, but it does not sanitize or restrict the SQL
expression. Treat source files as trusted configuration.

The Mapnik placeholders `!bbox!`, `!scale_denominator!` and `!pixel_width!` are
replaced textually, including when they appear inside string literals or
comments. A trailing semicolon on the datasource SQL is ignored.

Layer queries run in read-only sessions. `INSERT`, `UPDATE`, `DELETE`, DDL and
`SELECT ... FOR UPDATE` are rejected by PostgreSQL.

## Simplification units

Simplification tolerances are configured in metres. For planar projections
they are passed to PostGIS unchanged. For geographic projections they are
converted to degrees with the spherical metres-per-degree constant; longitude
distortion at high latitudes makes that conversion approximate.

## Property types

The following PostgreSQL property types are decoded:

- `text`, `varchar`, `bpchar`, `name`
- `uuid`
- `int2`, `int4`, `int8`, `oid`, `regproc`, `regclass`, `regtype`
- `float4`, `float8`, `numeric`
- `boolean`
- `date`, `timestamp`, `timestamptz` (ISO 8601 strings; timestamps keep microsecond precision and `timestamptz` is rendered in UTC)
- `json`, `jsonb` (JSON text)
- `xml` (text)
- `bytea` (base64)
- `money` (decimal string)
- `hstore` (dictionary; `NULL` values are omitted)
- `interval` (readable string)
- temporal ranges `tsrange`, `tstzrange`, `daterange` (range string)
- one-dimensional arrays of the above; `NULL` elements are dropped and empty
  arrays are preserved. `oid[]` is not supported because PostgresNIO currently
  reports it in text format.
- enums and text-like user-defined types
- domains over a supported scalar type (decoded as the base type)

Not yet supported; the property is omitted and a debug message is logged:

- `time`, `timetz`
- `inet`, `cidr`, `macaddr`, `macaddr8`
- `bit`, `varbit`
- numeric and integer ranges, and multiranges
- composite types
- multidimensional arrays

`numeric` values are converted to `Double`, so very high-precision values can
lose precision. PostgreSQL `NaN`, `Infinity` and `-Infinity` are preserved.
Multi-dimensional arrays are rejected before decoding because PostgresNIO's
array decoder only supports zero- and one-dimensional arrays.

PostgreSQL `infinity` and `-infinity` timestamps decode to PostgresNIO's
sentinel dates rather than the strings `infinity` / `-infinity`.

## Feature IDs

Only a **non-negative integer** property named `id` is used as the feature ID. It is
removed from the properties. Negative, text, UUID, floating-point, boolean,
array/JSON and oversized numeric `id` values remain regular properties, and the
in-memory feature receives a generated string ID.

MVT and MLT feature IDs are unsigned integers. Non-numeric IDs are therefore
not encoded as feature IDs, and duplicate numeric IDs are allowed.

## MVT and MLT are lossy

MVT and MLT quantize geometry to the tile grid. A round trip does not preserve
altitude, GeoJSON `m` values, string feature IDs, or foreign members.

## Geometry types

The query builder loads every PostGIS geometry value that GISTools can decode:

- `Point`, `MultiPoint`, `LineString`, `MultiLineString`
- `Polygon` (with or without holes) and `MultiPolygon`
- `GeometryCollection` with homogeneous, mixed or nested contents
- `Triangle`, which is loaded as a `Polygon`
- Curved geometries, which are linearized:
  - `CircularString` and `CompoundCurve` become `LineString`
  - `CurvePolygon` becomes `Polygon`
  - `MultiCurve` becomes `MultiLineString`
  - `MultiSurface` becomes `MultiPolygon`
- `TIN` and `PolyhedralSurface`, which become `MultiPolygon` with one
  `Polygon` per triangle or patch

Linearization is lossy. Re-encoding emits the linear geometry type; the
original curve or surface type and TIN topology are not preserved.

Geometries with `Z`, `M` or `ZM` coordinates are converted to 2D with
`ST_Force2D` before WKB decoding, so they load normally but altitude and
measure values are discarded. `geography` columns are cast to `geometry` first
and load the same way. MVT and MLT do not carry `Z` or `M` values.

Empty geometries load as empty geometries; an empty `Point` loads as an empty
`MultiPoint`. All empty geometries are dropped when encoding MVT or MLT because
neither format has an empty geometry type.

## SRIDs

Every row's geometry must use the SRID declared by the datasource. The loader
selects `ST_SRID(...)` alongside the WKB and skips rows whose SRID differs; they
are counted in `invalidFeatures`. This prevents plain WKB, which carries no
SRID, from being interpreted in the wrong coordinate system. A `NULL` geometry
is skipped without being counted as invalid.

## Clipping at tile boundaries

Local clipping uses strict containment, so points exactly on the tile boundary
and points outside the tile are dropped. PostGIS clipping (`ST_ClipByBox2D`)
turns boundary and outside points into empty geometries; those empty features
remain in the in-memory tile and are dropped by the MVT/MLT encoders.

## Geometry columns

The configured geometry field must exist in the result set and contain a
geometry or geography value. A missing column, a non-castable column or an
ambiguous duplicate column name fails the layer query with a Postgres error;
the failure is surfaced to the caller instead of crashing the process.

## Geometry collections

MVT and MLT have no geometry-collection type. By default `GeometryCollection`
features are kept in the in-memory `VectorTile` but dropped when encoding MVT or
MLT.

Set `MVTPostgisConfiguration.flattenGeometryCollections` to `true` to turn every
collection member into a separate feature before clipping and encoding. Nested
collections are flattened recursively. Each resulting feature keeps the original
properties, foreign members and ID, so IDs can be duplicated. Alternatively,
split collections in SQL with `ST_CollectionExtract` or `ST_Dump`.

## Multi-geometry round trips

A single-part `MultiPoint`, `MultiLineString`, `MultiPolygon`, `MultiCurve`
or `MultiSurface` may decode as its singular type. Multi-part geometries are
preserved. Polygon holes, `MultiPolygon`, `Triangle`, `TIN` and
`PolyhedralSurface` survive a round trip, and curves re-encode as their
linearized type. Assert the decoded geometry type if your consumer depends on
it.

## No HTTP server

`MVTPostgis` creates tile data. Serving HTTP, caching, authentication, and tile
routing are the responsibility of the consuming application.

## Timeouts

`queryTimeout` applies to individual queries and `tileTimeout` applies to the
whole tile. A timed-out tile is reported as
``MVTPostgisError/tileTimedOut(queries:)``.

## Pool shutdown and concurrency

`shutdown()` closes all pools. Requests that are already in flight fail, and a
later request creates a fresh pool. Concurrent tiles share one pool per
database key; `poolSize` limits the number of open connections and additional
requests wait for a free connection.

## Database availability

Transient database failures fail the current request and keep the pool alive;
the next request retries after the connection cooldown. A pool permanently shut
down by an authentication, TLS or database-name error is recreated only when a
TCP probe succeeds, so an outage cannot trigger an unbounded number of pools.
