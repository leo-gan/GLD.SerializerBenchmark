#!/usr/bin/env python3
"""Run the Fortran json-fortran and toml-f compliance probes.

The Fortran program only parses. This script loads the corpora, packs the
inputs, and scores accept / reject / any the way the JavaScript adapter does.
When a case carries ``decoded``, the library's re-serialized text is loaded
back and compared. JSON numbers compare by value. TOML uses tomllib.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "compliance" / "data"
FORTRAN = ROOT / "fortran"

ADAPTERS = {
    "json": ("json-fortran", "9.3.1"),
    "toml": ("toml-f", "0.5.2"),
}


def values_equal(expected, observed) -> bool:
    if isinstance(expected, bool) or isinstance(observed, bool):
        return isinstance(expected, bool) and isinstance(observed, bool) and expected == observed
    if isinstance(expected, (int, float)) and isinstance(observed, (int, float)) and not isinstance(expected, bool):
        if isinstance(expected, float) and math.isnan(expected):
            return isinstance(observed, float) and math.isnan(observed)
        return float(expected) == float(observed)
    if isinstance(expected, str) or isinstance(observed, str):
        return expected == observed
    if expected is None or observed is None:
        return expected is None and observed is None
    if isinstance(expected, list):
        return (
            isinstance(observed, list)
            and len(expected) == len(observed)
            and all(values_equal(a, b) for a, b in zip(expected, observed))
        )
    if isinstance(expected, dict):
        if not isinstance(observed, dict) or set(expected) != set(observed):
            return False
        return all(values_equal(expected[k], observed[k]) for k in expected)
    return expected == observed


def load_suites(formats: set[str]) -> list[tuple[dict, list[dict]]]:
    out = []
    for fmt in ("json", "toml"):
        if formats and fmt not in formats:
            continue
        folder = DATA / fmt
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.json")):
            if path.name.startswith("_"):
                continue
            doc = json.loads(path.read_text(encoding="utf-8"))
            cases = list(doc.get("cases") or [])
            out.append((doc, cases))
    return out


def pack_cases(cases: list[dict], dest: Path) -> None:
    blob = bytearray()
    blob += struct.pack("<i", len(cases))
    for case in cases:
        raw = case.get("input")
        if not isinstance(raw, str):
            raw = "" if raw is None else str(raw)
        data = raw.encode("utf-8")
        blob += struct.pack("<i", len(data))
        blob += data
    dest.write_bytes(blob)


def run_probe(exe: Path, fmt: str, cases: list[dict], work: Path, tag: str) -> tuple[int, list[tuple[int, str]] | None]:
    cases_path = work / f"{tag}.bin"
    out_path = work / f"{tag}.out"
    pack_cases(cases, cases_path)
    proc = subprocess.run([str(exe), fmt, str(cases_path), str(out_path)], cwd=FORTRAN)
    if proc.returncode != 0 or not out_path.is_file():
        return proc.returncode, None
    try:
        return 0, read_outcomes(out_path, len(cases))
    except RuntimeError:
        return 1, None


def probe_cases(exe: Path, fmt: str, cases: list[dict], work: Path, tag: str) -> list[tuple[int, str]]:
    """One aborting input must not discard the rest of the corpus file."""
    rc, rows = run_probe(exe, fmt, cases, work, tag)
    if rows is not None:
        return rows
    if len(cases) == 1:
        return [(-1, "parser aborted")]
    mid = max(1, len(cases) // 2)
    left = probe_cases(exe, fmt, cases[:mid], work, tag + "a")
    right = probe_cases(exe, fmt, cases[mid:], work, tag + "b")
    return left + right


def read_outcomes(path: Path, n: int) -> list[tuple[int, str]]:
    data = path.read_bytes()
    view = memoryview(data)
    off = 0
    rows = []
    for _ in range(n):
        if off + 8 > len(view):
            raise RuntimeError("short outcome file")
        ok, dlen = struct.unpack_from("<ii", view, off)
        off += 8
        if dlen < 0 or off + dlen > len(view):
            raise RuntimeError("bad outcome length")
        text = bytes(view[off : off + dlen]).decode("utf-8", errors="replace")
        off += dlen
        rows.append((ok, text))
    return rows


def score(case: dict, ok: int, dumped: str, fmt: str) -> tuple[str, str, str]:
    expect = case.get("expect") or "accept"
    parsed = ok == 1
    aborted = ok < 0
    if expect == "any":
        observed = dumped[:240] if parsed else ("parser aborted" if aborted else "rejected")
        return "pass", observed, "implementation-defined (recorded, not scored)"
    if expect == "reject":
        if not parsed:
            return "pass", "parser aborted" if aborted else "rejected", ""
        return "fail", f"accepted as {dumped[:180]}", "parser accepted input the spec requires to be rejected"
    if not parsed:
        return "fail", "rejected", "parser rejected input the spec requires to accept"
    if "decoded" in case:
        try:
            if fmt == "json":
                observed = json.loads(dumped)
            else:
                import tomllib

                observed = tomllib.loads(dumped)
        except Exception as exc:  # noqa: BLE001 - the library text is the observation
            return "fail", f"{type(exc).__name__}: {exc}", "re-serialized text could not be loaded for comparison"
        if not values_equal(case["decoded"], observed):
            return (
                "fail",
                f"got {dumped[:180]}",
                "decoded value does not match the catalog case",
            )
        return "pass", dumped[:180], ""
    return "pass", dumped[:180], ""


def result_row(suite: dict, case: dict, name: str, version: str, outcome: str, observed: str, detail: str) -> dict:
    fmt = str(suite.get("format") or "")
    version_key = f"{fmt}.{suite.get('version') or ''}"
    return {
        "id": case.get("id") or "",
        "language": "fortran",
        "serializer": name,
        "serializer_version": version,
        "format": fmt,
        "standard": suite.get("standard") or "",
        "standard_url": suite.get("standard_url") or "",
        "version": str(suite.get("version") or ""),
        "version_key": version_key,
        "requirement": case.get("requirement") or "",
        "expect": case.get("expect") or "",
        "section": case.get("section") or "",
        "section_title": case.get("section_title") or "",
        "section_url": case.get("section_url") or "",
        "paragraph": case.get("paragraph") or "",
        "title": case.get("title") or "",
        "input": case.get("input") if isinstance(case.get("input"), str) else "",
        "input_encoding": case.get("input_encoding") or "utf-8",
        "detail": detail,
        "observed": observed,
        "outcome": outcome,
    }


def binary_path() -> Path:
    probe = subprocess.run(
        [
            "bash",
            "-lc",
            "source scripts/fpm-env.sh && fpm run --profile release --runner echo compliance_fortran",
        ],
        cwd=FORTRAN,
        check=True,
        capture_output=True,
        text=True,
    )
    line = probe.stdout.strip().splitlines()[-1].strip()
    path = Path(line)
    if not path.is_absolute():
        path = FORTRAN / path
    if not path.is_file():
        raise RuntimeError(f"compliance binary not found: {line}")
    return path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--format", action="append", default=[])
    parser.add_argument("--serializer", action="append", default=[])
    parser.add_argument("--work", type=Path, default=Path("/tmp/gld-fortran-compliance"))
    args = parser.parse_args()
    formats = set(args.format)
    wanted = set(args.serializer)
    suites = load_suites(formats)
    if not suites:
        print("no fortran compliance suites selected", file=sys.stderr)
        return 0
    exe = binary_path()
    work = args.work
    work.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    for suite, cases in suites:
        fmt = str(suite.get("format") or "")
        name, version = ADAPTERS.get(fmt, ("", ""))
        if not name:
            continue
        if wanted and name not in wanted:
            continue
        tag = f"{fmt}-{suite.get('version')}"
        outcomes = probe_cases(exe, fmt, cases, work, tag)
        for case, (ok, dumped) in zip(cases, outcomes):
            outcome, observed, detail = score(case, ok, dumped, fmt)
            rows.append(result_row(suite, case, name, version, outcome, observed, detail))
        print(f"  {fmt} {suite.get('version')}: {len(cases)} cases", flush=True)
    passed = sum(1 for r in rows if r["outcome"] == "pass")
    failed = sum(1 for r in rows if r["outcome"] == "fail")
    skipped = sum(1 for r in rows if r["outcome"] == "skip")
    errors = sum(1 for r in rows if r["outcome"] not in ("pass", "fail", "skip"))
    doc = {
        "schema": "gld.dashboard.compliance/1",
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "language": "fortran",
        "languages": ["fortran"],
        "policy": "report-only",
        "scope": {"formats": sorted({r["format"] for r in rows if r.get("format")})},
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "errors": errors,
        "catalog_errors": [],
        "serializer_errors": [],
        "results": rows,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(doc), encoding="utf-8")
    print(f"  {passed} pass  {failed} fail  {errors} error  {len(rows)} total")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
