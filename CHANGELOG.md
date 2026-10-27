# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to semantic versioning.

## Unreleased

### Added

- A deterministic PostGIS integration suite with checked-in SQL fixtures,
  Docker/CI database setup, fake-loader pipeline tests, and a 90% coverage gate.
- Public initializers for `PostgisSource`, `PostgisLayer`,
  `PostgisLayer.Properties` and `PostgisDatasource`.
- DocC catalog with getting-started, source-format, tile-option, pooling and
  limitations articles.
- Linux, coverage and DocC CI jobs, plus `scripts/run-coverage.sh` and
  `scripts/check_documentation.py`.
- Tests for SQL generation, source defaults, URL loading, XML errors,
  initialization validation and skipped-layer orchestration.

### Changed

- CI and the local integration runner now use PostgreSQL 18 / PostGIS 3.6,
  the minimum supported production version.
- Updated to `mvt-tools` 3.0.0-beta.5, `gis-tools` 3.0.0-beta.5,
  `gis-tools-csv` 3.0.0-beta.6 and `postgres-nio` 1.33.2.
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
