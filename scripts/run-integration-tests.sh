#!/usr/bin/env bash
#
# Run the PostGIS integration suite against a disposable local PostGIS
# container. The unit tests do not need this container.
#
# Requires a working Docker daemon.

set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

CONTAINER="${MVT_POSTGIS_TEST_CONTAINER:-mvt-postgis-test}"
HOST_PORT="${MVT_POSTGIS_TEST_PORT:-5432}"
IMAGE="${MVT_POSTGIS_TEST_IMAGE:-postgis/postgis:16-3.4}"

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required to run the PostGIS integration tests" >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "The Docker daemon is not reachable" >&2
    exit 1
fi

cleanup() {
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run --rm -d \
    --name "$CONTAINER" \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=mvt_test \
    -e TZ=UTC \
    -p "${HOST_PORT}:5432" \
    "$IMAGE" >/dev/null

for _ in $(seq 1 60); do
    if docker exec "$CONTAINER" pg_isready -U postgres -d mvt_test >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! docker exec "$CONTAINER" pg_isready -U postgres -d mvt_test >/dev/null 2>&1; then
    echo "PostGIS did not become ready" >&2
    exit 1
fi

export MVT_POSTGIS_TEST_HOST=127.0.0.1
export MVT_POSTGIS_TEST_PORT="$HOST_PORT"
export MVT_POSTGIS_TEST_USER=postgres
export MVT_POSTGIS_TEST_PASSWORD=postgres
export MVT_POSTGIS_TEST_DATABASE=mvt_test

swift test --filter PostGISIntegrationTests
