# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to semantic versioning.

## 3.0.0-beta.6 - 2026-10-29

### Added

- Decoding for JSON/JSONB, XML, bytea (base64), money, hstore, interval,
  temporal ranges (`tsrange`, `tstzrange`, `daterange`), OID/reg* types and
  additional array types (JSON, bytea, XML, money, numeric, bpchar, name,
  UUID, date, timestamp, timestamptz, interval). Enums and text-like
  user-defined types are preserved as text; domains over supported scalars use
  the base type.
- Safe handling of empty, NULL-containing and multidimensional arrays.
- Deterministic property and feature-ID edge-case fixtures covering empty,
  long and Unicode text, control characters, integer/numeric/float extremes,
  temporal boundaries, duplicate IDs, missing IDs and non-integer IDs.
- OGC geometry coverage for `Point`, `MultiPoint`, `LineString`,
  `MultiLineString`, polygons with holes, `MultiPolygon`, homogeneous, mixed
  and nested `GeometryCollection`s, empty variants, `Z`/`M`/`ZM` variants,
  curved geometries, `Triangle`, `TIN` and `PolyhedralSurface`, including MVT
  and MLT round-trip assertions.
- Native decoding for curved geometries, `TIN`, `PolyhedralSurface` and empty
  points through `gis-tools` 3.0.0-beta.6. Curves load as their linearized
  types, `TIN`/`PolyhedralSurface` as `MultiPolygon`, and `POINT EMPTY` as an
  empty `MultiPoint`; SQL conversions are no longer required.
- A deterministic PostGIS integration suite with checked-in SQL fixtures,
  Docker/CI database setup, fake-loader pipeline tests, and a 90% coverage gate.
- Public initializers for `PostgisSource`, `PostgisLayer`,
  `PostgisLayer.Properties` and `PostgisDatasource`.
- DocC catalog with getting-started, source-format, tile-option, pooling and
  limitations articles.
- Linux, coverage and DocC CI jobs, plus `scripts/run-coverage.sh` and
  `scripts/check_documentation.py`.
- SwiftPM dependency caching in CI to reduce build time across jobs.
- Tests for SQL generation, source defaults, URL loading, XML errors,
  initialization validation and skipped-layer orchestration.
- A curated mutation-testing campaign for the query builder, feature-ID policy
  and SRID filtering, run by a separate scheduled workflow.
- End-to-end configuration coverage for clipping/simplification/validation
  combinations, buffer sizes, zoom-dependent closures, layer bounds, runtime
  tracking, feature mapping and export buffers.
- Connection-pool concurrency coverage for a single-connection pool, shared
  pools across layers, cancellation of a waiting request, shutdown with an
  in-flight request and authentication failures.
- MVT/MLT export-option coverage for all supported geometries, buffers,
  compression levels, simplification, feature IDs/properties, empty output and
  deterministic decoded results.
- Seeded generative tests for WKB and MVT/MLT invariants, malformed WKB and
  source documents, and arbitrary SQL fragments.
- `MVTPostgisConfiguration.flattenGeometryCollections` flattens nested
  `GeometryCollection`s into one feature per member before clipping and
  encoding, preserving properties and foreign members. The first member keeps
  the original ID; later members receive generated string IDs.
- Coverage for administrative backend termination followed by an explicit
  `shutdown()` and pool recreation.
- Differential feature-content test against PostGIS `ST_AsMVT` for a
  representative tile.
- Differential geometry assertions for the `ST_AsMVT` oracle: decoded type,
  coordinate count, polygon ring count and bounding boxes.

### Changed

- Only a non-negative integer `id` property is used as the feature ID.
  Negative, text, UUID, floating-point, boolean, array/JSON and oversized
  numeric IDs remain properties instead of being silently dropped or converted
  to an unsigned MVT ID.
- CI and the local integration runner now use PostgreSQL 18 / PostGIS 3.6,
  the minimum supported production version.
- Documented the PostgreSQL 18 / PostGIS 3.6 support matrix and added a
  workflow-dispatch image override plus a weekly integration schedule.
- Updated `PostgresConnectionPool` to 1.1.2. A connection that finishes
  opening while a pool is shutting down is closed and discarded, and idle
  connections whose backend was terminated are replaced instead of hanging the
  next request.
- Updated to `mvt-tools` 3.0.0-beta.6, `gis-tools` 3.0.0-beta.6,
  `gis-tools-csv` 3.0.0-beta.7 and `postgres-nio` 1.33.2.
- Rows whose geometry SRID differs from the datasource-declared SRID are
  skipped and counted in `invalidFeatures` instead of being decoded in the
  wrong coordinate system. The query builder selects `ST_SRID(...)` for this
  check.
- Datasource SQL may end with a trailing semicolon; the query builder trims it
  before wrapping the statement.
- Added direct `swift-log` and `swift-atomics` dependencies and removed the
  unused direct `swift-collections` dependency.
- Layers may use any planar or geographic projection registered in GISTools;
  features are reprojected into the tile projection when appended.
- JSON, YML and XML source readers now use defaults for optional metadata,
  fields, properties, passwords, ports, geometry fields and extents.
- XML parsing finds the `Datasource` element even when a `StyleName` comes
  first, uses the map-level `srs` as a fallback, and reports malformed layers
  explicitly.
- Mapnik SRS matching accepts common Mercator variants with or without
  `+over`.

### Fixed

- PostgreSQL `numeric` `NaN`, `Infinity` and `-Infinity` were previously decoded
  as `0.0`; they are now preserved.
- Geometries are converted to 2D with `ST_Force2D` before WKB decoding, so
  columns with `Z`, `M` or `ZM` coordinates load instead of being reported as
  invalid. `geography` columns are cast to `geometry` for the same reason.
- Timestamps now keep microsecond precision, and `timestamptz` values are
  rendered consistently in UTC.
- `validate(sql:forLayer:)` now explains Mapnik-style `(SELECT ...) AS data`
  queries correctly instead of reporting a syntax error for valid SQL.
- Integer, floating-point and boolean array properties drop `NULL` elements
  instead of failing to decode as native arrays.

- Fixed invalid generated SQL caused by a duplicated `ST_ClipByBox2D(` call.
- Geometry metadata fields are no longer selected twice when the configured
  fields include the geometry column.
- SQL identifiers are quoted correctly, including embedded double quotes.
- Tiles where every layer is skipped by its bounding box now return an empty
  tile immediately instead of waiting for the tile timeout.
- Metre simplification tolerances are converted to degrees for geographic
  layers before being passed to `ST_Simplify`.
- Layer ids are validated, and unsupported projections are rejected at
  initialization.
