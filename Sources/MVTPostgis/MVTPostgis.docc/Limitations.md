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
- `date`, `timestamp`, `timestamptz` (ISO 8601 strings)
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
lose precision. Multi-dimensional arrays are rejected before decoding because
PostgresNIO's array decoder only supports zero- and one-dimensional arrays.

## MVT and MLT are lossy

MVT and MLT quantize geometry to the tile grid. A round trip does not preserve
altitude, GeoJSON `m` values, string feature IDs, or foreign members.

## Multi-geometry round trips

The in-memory `VectorTile` preserves `MultiPoint` and `MultiLineString`
geometries. MVT/MLT encoders and decoders may flatten them to `Point` or
`LineString` respectively; assert the decoded geometry type if your consumer
depends on it.

## No HTTP server

`MVTPostgis` creates tile data. Serving HTTP, caching, authentication, and tile
routing are the responsibility of the consuming application.

## Timeouts

`queryTimeout` applies to individual queries and `tileTimeout` applies to the
whole tile. A timed-out tile is reported as
``MVTPostgisError/tileTimedOut(queries:)``.

## Database availability

Transient database failures fail the current request and keep the pool alive;
the next request retries after the connection cooldown. A pool permanently shut
down by an authentication, TLS or database-name error is recreated only when a
TCP probe succeeds, so an outage cannot trigger an unbounded number of pools.
