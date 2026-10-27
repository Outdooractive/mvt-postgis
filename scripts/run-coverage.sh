#!/usr/bin/env bash
#
# Run the test suite with code coverage and print the MVTPostgis coverage
# summary. SwiftPM 6.3 can exit non-zero while exporting its codecov JSON even
# though all tests passed and the profdata was written; the coverage report
# below uses the profdata directly.
#
# Usage: scripts/run-coverage.sh [minimum-line-coverage]

set -euo pipefail

MINIMUM="${1:-60}"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

set +e
swift test --enable-code-coverage > "$LOG" 2>&1
STATUS=$?
set -e

cat "$LOG"

if grep -q '✘ Test run with .* failed' "$LOG"; then
    exit 1
fi

if ! grep -q '✔ Test run with .* passed' "$LOG"; then
    echo "Coverage test run did not complete successfully" >&2
    exit "$STATUS"
fi

python3 scripts/coverage.py --minimum "$MINIMUM"
