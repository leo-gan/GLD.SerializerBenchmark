#!/usr/bin/env python3
"""Helper commands for scripts/run-compliance.sh:

- merge: merge partial compliance JSON files (C#, Zig, Mojo) into one report
- split-mojo: split compliance/data/**/*.json into Mojo runner chunks
- timeout-mojo: emit error rows when a Mojo compliance chunk times out
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def merge_part_files(
    parts_dir: Path,
    out_path: Path,
    language: str,
    *,
    pattern: str = "*.json",
) -> dict:
    parts = sorted(parts_dir.glob(pattern))
    rows: list[dict] = []
    errs: list = []
    fmts: set[str] = set()
    for p in parts:
        d = json.loads(p.read_text(encoding="utf-8"))
        part_rows = d.get("results") or []
        rows.extend(part_rows)
        errs.extend(d.get("serializer_errors") or [])
        for r in part_rows:
            if r.get("format"):
                fmts.add(r["format"])
    passed = sum(1 for r in rows if r.get("outcome") == "pass")
    failed = sum(1 for r in rows if r.get("outcome") == "fail")
    skipped = sum(1 for r in rows if r.get("outcome") == "skip")
    errors = len(rows) - passed - failed - skipped
    doc = {
        "schema": "gld.dashboard.compliance/1",
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "language": language,
        "languages": [language],
        "policy": "report-only",
        "scope": {"formats": sorted(fmts)},
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "errors": errors,
        "catalog_errors": [],
        "serializer_errors": errs,
        "results": rows,
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(doc), encoding="utf-8")
    n_sers = len({r.get("serializer") for r in rows})
    print(f"  {passed} pass  {failed} fail  {len(rows)} total  {n_sers} serializers")
    return doc


def split_mojo_catalogs(data_root: Path, dest_dir: Path) -> int:
    """Split compliance/data catalogs into Mojo-sized chunks."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    for src in sorted(data_root.rglob("*.json")):
        if src.name.startswith("_"):
            continue
        rel = src.relative_to(data_root)
        if rel.as_posix() == "kiln/v2.json":
            continue
        step = (
            20
            if src.parent.name == "yaml"
            else 4
            if src.parent.name == "toml"
            else 1
            if src.parent.name == "smile"
            else 0
        )
        if step:
            doc = json.loads(src.read_text(encoding="utf-8"))
            cases = doc.get("cases") or []
            meta = {k: v for k, v in doc.items() if k != "cases"}
            prefix = src.parent.name
            for i in range(0, len(cases), step):
                chunk = dict(meta)
                chunk["cases"] = cases[i : i + step]
                out = dest_dir / f"{prefix}-{src.stem}-{i:04d}.json"
                out.write_text(json.dumps(chunk, separators=(",", ":")), encoding="utf-8")
                written += 1
        else:
            (dest_dir / f"{rel.parent}-{src.stem}.json").write_text(
                src.read_text(encoding="utf-8"), encoding="utf-8"
            )
            written += 1
    print("mojo catalog chunks ready")
    return written


def record_mojo_timeout(chunk_path: Path, out_path: Path, standards_path: Path) -> list[dict]:
    suite = json.loads(chunk_path.read_text(encoding="utf-8"))
    standards = json.loads(standards_path.read_text(encoding="utf-8"))
    fmt = suite.get("format") or ""
    version = suite.get("version") or ""
    names = [
        name
        for name, fmts in (standards.get("languages") or {}).get("mojo", {}).items()
        if fmt in (fmts or [])
    ]
    rows: list[dict] = []
    for case in suite.get("cases") or []:
        for name in names or [""]:
            rows.append(
                {
                    "id": case.get("id") or "",
                    "language": "mojo",
                    "serializer": name,
                    "serializer_version": "0.2.0" if name == "mojo-smile" else "",
                    "format": fmt,
                    "standard": suite.get("standard") or "",
                    "standard_url": suite.get("standard_url") or "",
                    "version": version,
                    "version_key": f"{fmt}.{version}" if fmt else "",
                    "requirement": case.get("requirement") or "",
                    "expect": case.get("expect") or "",
                    "section": "",
                    "section_title": "",
                    "section_url": case.get("section_url") or "",
                    "paragraph": "",
                    "title": "",
                    "input": "",
                    "input_encoding": "",
                    "detail": "decoder did not finish within 25s",
                    "observed": "timeout",
                    "outcome": "error",
                }
            )
    out_path.write_text(json.dumps({"results": rows}), encoding="utf-8")
    print(f"  recorded {len(rows)} timeout error(s)")
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    m = sub.add_parser("merge")
    m.add_argument("parts_dir", type=Path)
    m.add_argument("out_path", type=Path)
    m.add_argument("--lang", required=True)
    m.add_argument("--pattern", default="*.json")

    s = sub.add_parser("split-mojo")
    s.add_argument("data_root", type=Path)
    s.add_argument("dest_dir", type=Path)

    t = sub.add_parser("timeout-mojo")
    t.add_argument("chunk_path", type=Path)
    t.add_argument("out_path", type=Path)
    t.add_argument("standards_path", type=Path)

    args = ap.parse_args()
    if args.cmd == "merge":
        merge_part_files(args.parts_dir, args.out_path, args.lang, pattern=args.pattern)
        return 0
    if args.cmd == "split-mojo":
        split_mojo_catalogs(args.data_root, args.dest_dir)
        return 0
    if args.cmd == "timeout-mojo":
        record_mojo_timeout(args.chunk_path, args.out_path, args.standards_path)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
