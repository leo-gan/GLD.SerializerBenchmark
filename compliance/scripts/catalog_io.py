#!/usr/bin/env python3
"""Shared compact-row JSON writer for compliance/data/ catalog files."""

from __future__ import annotations

import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"


def dumps_compliance_catalog(doc: dict, *, ensure_ascii: bool = False) -> str:
    """Format a compliance catalog with 2-space outer indent and one line per case."""
    clone = copy.deepcopy(doc)
    inline_map: dict[str, str] = {}
    idx = 0
    cases = clone.get("cases")
    if isinstance(cases, list):
        new_cases = []
        for item in cases:
            token = f"__CASE_{idx}__"
            idx += 1
            inline_map[f'"{token}"'] = json.dumps(
                item, separators=(",", ":"), ensure_ascii=ensure_ascii
            )
            new_cases.append(token)
        clone["cases"] = new_cases
    out = json.dumps(clone, indent=2, ensure_ascii=ensure_ascii)
    for k, v in inline_map.items():
        out = out.replace(k, v)
    return out + "\n"


def dump_catalog(rel: str, doc: dict, *, ensure_ascii: bool = False) -> Path:
    path = DATA / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        dumps_compliance_catalog(doc, ensure_ascii=ensure_ascii), encoding="utf-8"
    )
    print(f"wrote {path.relative_to(ROOT)} ({len(doc.get('cases') or [])} cases)")
    return path
