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

## MVT and MLT are lossy

MVT and MLT quantize geometry to the tile grid. A round trip does not preserve
altitude, GeoJSON `m` values, string feature IDs, or foreign members.

## No HTTP server

`MVTPostgis` creates tile data. Serving HTTP, caching, authentication, and tile
routing are the responsibility of the consuming application.

## Timeouts

`queryTimeout` applies to individual queries and `tileTimeout` applies to the
whole tile. A timed-out tile is reported as
``MVTPostgisError/tileTimedOut(queries:)``.

## Database availability

Connection pools are recreated after a database outage only when a TCP probe
succeeds. During an outage, requests fail fast rather than reconnecting on
every request.
