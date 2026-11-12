#!/usr/bin/env python3
"""Fail when a catalog standard has no Compliance column.

Every format id in config/compliance-catalog.json must have:

* docs/compliance/<id>.md
* that page in the MkDocs nav
* its standards.yaml label (or the id) in docs/compliance/index.md
* at least one case file under compliance/data/<id>/
* a scored cell in dashboard/public/data/compliance.json.gz
  (same format, total > 0)

A standard with serializers and no scored cell does not appear as a
column on Dashboard → Compliance. Run the language compliance runners
that implement the format, then sync-compliance.py, and run this again.
"""

from __future__ import annotations

import gzip
import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("check-standard-columns: PyYAML is required", file=sys.stderr)
    sys.exit(2)


def repo_root() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "config" / "compliance-catalog.json").is_file():
            return parent
    raise SystemExit("check-standard-columns: repo root not found")


def catalog_formats(root: Path) -> dict[str, set[str]]:
    """format id → languages that register a serializer for it."""
    rows = json.loads((root / "config" / "compliance-catalog.json").read_text(encoding="utf-8"))
    out: dict[str, set[str]] = {}
    for row in rows:
        lang = str(row.get("language") or "")
        for fmt in row.get("formats") or []:
            out.setdefault(str(fmt), set()).add(lang)
    return out


def labels(root: Path) -> dict[str, str]:
    raw = yaml.safe_load((root / "config" / "standards.yaml").read_text(encoding="utf-8")) or {}
    out: dict[str, str] = {}
    for key, row in (raw.get("standards") or {}).items():
        if isinstance(row, dict) and row.get("label"):
            out[str(key)] = str(row["label"])
    return out


def corpus_cases(root: Path, fmt: str) -> int:
    folder = root / "compliance" / "data" / fmt
    if not folder.is_dir():
        return 0
    count = 0
    for path in folder.glob("*.json"):
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        if str(doc.get("format") or "") != fmt:
            continue
        count += len(doc.get("cases") or [])
    return count


def scored_formats(root: Path) -> set[str]:
    path = root / "dashboard" / "public" / "data" / "compliance.json.gz"
    if not path.is_file():
        return set()
    doc = json.loads(gzip.open(path).read())
    found: set[str] = set()
    for cell in doc.get("matrix") or []:
        if not isinstance(cell, dict):
            continue
        total = cell.get("total")
        if isinstance(total, int) and total > 0:
            fmt = cell.get("format")
            if fmt:
                found.add(str(fmt))
    return found


def main() -> int:
    root = repo_root()
    formats = catalog_formats(root)
    name_of = labels(root)
    nav = (root / "mkdocs.yml").read_text(encoding="utf-8")
    index = (root / "docs" / "compliance" / "index.md").read_text(encoding="utf-8").lower()
    scored = scored_formats(root)
    problems: list[str] = []
    for fmt in sorted(formats):
        page = root / "docs" / "compliance" / f"{fmt}.md"
        if not page.is_file():
            problems.append(f"{fmt}: missing docs/compliance/{fmt}.md")
        if f"compliance/{fmt}.md" not in nav:
            problems.append(f"{fmt}: mkdocs.yml nav has no compliance/{fmt}.md")
        label = (name_of.get(fmt) or fmt).lower()
        if label not in index and fmt.lower() not in index:
            problems.append(f"{fmt}: docs/compliance/index.md does not name this standard")
        cases = corpus_cases(root, fmt)
        if cases == 0:
            problems.append(f"{fmt}: compliance/data/{fmt}/ has no cases")
        if fmt not in scored:
            langs = ", ".join(sorted(formats[fmt]))
            problems.append(
                f"{fmt}: Dashboard compliance.json.gz has no scored cell "
                f"(total > 0). Languages: {langs}. "
                f"Re-run ./scripts/run-compliance.sh for those languages."
            )
    if problems:
        print(f"check-standard-columns: {len(problems)} problem(s)", file=sys.stderr)
        for line in problems:
            print(f"  {line}", file=sys.stderr)
        return 1
    print(f"check-standard-columns: {len(formats)} standards have a scored Compliance column")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
