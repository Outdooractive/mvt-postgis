#!/usr/bin/env python3
"""Build the MVTPostgis DocC catalog and reject documentation diagnostics."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Sources" / "MVTPostgis" / "MVTPostgis.docc"
SYMBOL_DIR = ROOT / ".build" / "symbol-graphs"
LOCAL_SYMBOL_DIR = ROOT / ".build" / "mvt-postgis-documentation-symbols"
DIAGNOSTICS = ROOT / ".build" / "documentation-diagnostics.json"


def docc_command() -> str | None:
    if shutil.which("docc") is not None:
        return "docc"
    if sys.platform == "darwin":
        try:
            return subprocess.check_output(
                ["xcrun", "--find", "docc"],
                cwd=ROOT,
                text=True,
            ).strip()
        except (OSError, subprocess.CalledProcessError):
            return None
    return None


def build_symbol_graph() -> Path:
    if SYMBOL_DIR.exists():
        shutil.rmtree(SYMBOL_DIR)
    SYMBOL_DIR.mkdir(parents=True)
    if LOCAL_SYMBOL_DIR.exists():
        shutil.rmtree(LOCAL_SYMBOL_DIR)
    LOCAL_SYMBOL_DIR.mkdir(parents=True)

    # SwiftPM needs to compile the target to emit its symbol graph. Touch the
    # sources so an incremental build cannot skip the emission step locally.
    for source in (ROOT / "Sources" / "MVTPostgis").rglob("*.swift"):
        source.touch()

    subprocess.run(
        [
            "swift",
            "build",
            "--target",
            "MVTPostgis",
            "-Xswiftc",
            "-emit-symbol-graph",
            "-Xswiftc",
            "-emit-symbol-graph-dir",
            "-Xswiftc",
            str(SYMBOL_DIR),
        ],
        cwd=ROOT,
        check=True,
    )

    local_symbols = sorted(SYMBOL_DIR.glob("MVTPostgis*.symbols.json"))
    if not local_symbols:
        raise SystemExit(f"No MVTPostgis symbol graph found in {SYMBOL_DIR}")
    for symbol in local_symbols:
        shutil.copy2(symbol, LOCAL_SYMBOL_DIR / symbol.name)
    return LOCAL_SYMBOL_DIR


def source_path(diagnostic: dict) -> Path | None:
    source = diagnostic.get("source")
    if not source:
        return None
    parsed = urlparse(source)
    if parsed.scheme != "file":
        return Path(source)
    return Path(unquote(parsed.path))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / ".build" / "documentation",
        help="DocC archive output directory",
    )
    args = parser.parse_args()

    docc = docc_command()
    if docc is None:
        print("docc is not installed or not on PATH", file=sys.stderr)
        sys.exit(2)

    symbols = build_symbol_graph()
    if DIAGNOSTICS.exists():
        DIAGNOSTICS.unlink()
    if args.output.exists():
        shutil.rmtree(args.output)

    process = subprocess.run(
        [
            docc,
            "convert",
            str(CATALOG),
            "--additional-symbol-graph-dir",
            str(symbols),
            "--output-dir",
            str(args.output),
            "--diagnostics-file",
            str(DIAGNOSTICS),
        ],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )

    diagnostics = []
    if DIAGNOSTICS.exists():
        diagnostics = json.loads(DIAGNOSTICS.read_text()).get("diagnostics", [])

    local_root = ROOT / "Sources" / "MVTPostgis"
    issues = []
    for diagnostic in diagnostics:
        if diagnostic.get("severity") not in ("warning", "error"):
            continue
        path = source_path(diagnostic)
        if path is not None and local_root not in path.parents:
            continue
        issues.append(diagnostic)

    for diagnostic in issues:
        path = source_path(diagnostic)
        location = ""
        if path is not None and "range" in diagnostic:
            start = diagnostic["range"]["start"]
            location = f"{path}:{start['line']}:{start['column']}: "
        print(
            f"{location}{diagnostic.get('severity', 'warning')}: "
            f"{diagnostic.get('summary', 'documentation diagnostic')}",
            file=sys.stderr,
        )

    if process.returncode != 0:
        if process.stdout:
            print(process.stdout, end="")
        if process.stderr:
            print(process.stderr, end="", file=sys.stderr)
        sys.exit(process.returncode)
    if issues:
        sys.exit(1)

    print(f"Documentation built at {args.output} with no diagnostics.")


if __name__ == "__main__":
    main()
