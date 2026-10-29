# Development

## Unit tests

```bash
swift build
swift test
```

These run without a database. PostGIS integration tests are skipped unless
`MVT_POSTGIS_TEST_HOST` is set.

## Coverage

```bash
scripts/run-coverage.sh 90
```

The script runs all tests, uses the generated profdata directly and enforces the
line-coverage gate.

## PostgreSQL/PostGIS support matrix

| PostgreSQL | PostGIS | Status |
| --- | --- | --- |
| 18.x | 3.6.x | Supported and exercised in CI |
| < 18 | any | Unsupported |

PostgreSQL 18 / PostGIS 3.6 is the minimum supported baseline. Older server
majors and PostGIS releases are not tested and are not supported.

CI runs the coverage and integration suite against
`postgis/postgis:18-3.6`. The workflow can be dispatched manually with a
different `postgis_image` input, and the local runner accepts the same override:

```bash
MVT_POSTGIS_TEST_IMAGE=postgis/postgis:18-3.6 scripts/run-integration-tests.sh
```

The integration tests use PostgreSQL's binary protocol and do not depend on
`DateStyle`, `IntervalStyle`, `TimeZone` or locale for decoding correctness.
The environment suite exercises session-level `TimeZone`, `DateStyle`,
`IntervalStyle` and `extra_float_digits` settings explicitly.

## PostGIS integration tests

The integration suite uses a real PostGIS database and deterministic SQL
fixtures from `Tests/MVTPostgisTests/Integration/Fixtures/fixtures.sql`.

Run it with a disposable Docker container:

```bash
scripts/run-integration-tests.sh
```

The script waits for PostGIS, sets the required environment variables, runs the
integration suite and removes the container afterwards.

The connection can also be supplied manually:

```bash
export MVT_POSTGIS_TEST_HOST=127.0.0.1
export MVT_POSTGIS_TEST_PORT=5432
export MVT_POSTGIS_TEST_USER=postgres
export MVT_POSTGIS_TEST_PASSWORD=postgres
export MVT_POSTGIS_TEST_DATABASE=mvt_test

swift test --filter PostGISIntegrationTests
```

Each test creates a unique schema, applies the fixture script and drops the
schema during teardown. Only the schema name is random; all geometry, property,
UUID, date and array values are fixed.

CI runs the integration tests through a `postgis/postgis:18-3.6` service in the
Linux coverage job.

CI caches SwiftPM checkouts and artifacts under `.build/checkouts` and
`.build/artifacts`, keyed by `Package.resolved`. The fast unit jobs and the
PostGIS coverage job share the same cache layout.

## Mutation testing

A small curated mutation campaign runs in a separate scheduled workflow:

```bash
MVT_POSTGIS_TEST_HOST=127.0.0.1 python3 scripts/mutation_test.py
```

It mutates the query builder, feature-ID policy and SRID filtering, runs the
relevant tests and fails when a mutant survives. Database-backed mutants are
skipped when `MVT_POSTGIS_TEST_HOST` is not set.
