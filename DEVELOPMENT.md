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

CI runs the integration tests through a `postgis/postgis:16-3.4` service in the
Linux coverage job.
