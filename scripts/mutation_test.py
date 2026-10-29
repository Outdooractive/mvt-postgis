#!/usr/bin/env python3
"""Run a small curated mutation-testing campaign.

Each mutant is applied to one Swift source file, the relevant test filter is
run, and the file is restored. A mutant is killed when the tests fail (including
compile failures) and survives when they pass.

The database-backed mutants are skipped unless MVT_POSTGIS_TEST_HOST is set.
The campaign is intentionally small and is meant for a scheduled/manual job,
not the fast pull-request suite.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

MUTANTS = [
    {
        "name": "drop-force2d",
        "file": "Sources/MVTPostgis/Postgis/PostgisQueryBuilder.swift",
        "old": 'geometryExpression.append("ST_Force2D(")',
        "new": "",
        "tests": "PostgisQueryBuilderTests",
        "database": False,
    },
    {
        "name": "skip-meter-conversion",
        "file": "Sources/MVTPostgis/Postgis/PostgisQueryBuilder.swift",
        "old": "return meters / Self.metersPerDegree",
        "new": "return meters",
        "tests": "PostgisQueryBuilderTests",
        "database": False,
    },
    {
        "name": "reject-zero-feature-id",
        "file": "Sources/MVTPostgis/MVTPostgis.swift",
        "old": 'if let id = properties["id"] as? Int, id >= 0 {',
        "new": 'if let id = properties["id"] as? Int, id > 0 {',
        "tests": "nonNegativeIntegerIdsBecomeFeatureIds",
        "database": True,
    },
    {
        "name": "accept-mismatched-srid",
        "file": "Sources/MVTPostgis/MVTPostgis.swift",
        "old": "rowSrid == projection.srid",
        "new": "rowSrid != projection.srid",
        "tests": "skipsFeaturesWithMismatchedSrid",
        "database": True,
    },
]


def database_available() -> bool:
    return bool(os.environ.get("MVT_POSTGIS_TEST_HOST"))


def run_mutant(mutant: dict) -> str:
    path = ROOT / mutant["file"]
    source = path.read_text()
    needle = mutant["old"]
    if source.count(needle) != 1:
        raise RuntimeError(
            f"{mutant['name']}: expected exactly one occurrence of {needle!r}, "
            f"found {source.count(needle)}")

    backup = tempfile.NamedTemporaryFile(delete=False)
    backup.close()
    shutil.copy2(path, backup.name)

    try:
        path.write_text(source.replace(needle, mutant["new"], 1))
        result = subprocess.run(
            ["swift", "test", "--filter", mutant["tests"]],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        return "killed" if result.returncode != 0 else "survived"
    finally:
        shutil.copy2(backup.name, path)
        Path(backup.name).unlink(missing_ok=True)


def main() -> int:
    has_database = database_available()
    survivors = []

    print(f"Running {len(MUTANTS)} mutants (database: {'yes' if has_database else 'no'})\n")
    print(f"{'mutant':34} {'status':10} result")
    print("-" * 64)

    for mutant in MUTANTS:
        if mutant["database"] and not has_database:
            print(f"{mutant['name']:34} {'skipped':10} needs MVT_POSTGIS_TEST_HOST")
            continue

        status = run_mutant(mutant)
        print(f"{mutant['name']:34} {'':10} {status}")
        if status == "survived":
            survivors.append(mutant["name"])

    if survivors:
        print("\nSurviving mutants: " + ", ".join(survivors))
        return 1

    print("\nAll run mutants were killed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
