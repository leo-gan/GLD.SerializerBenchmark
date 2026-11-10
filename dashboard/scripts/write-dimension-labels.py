#!/usr/bin/env python3
"""Refresh explanations and optional_io inside dashboard/public/data/dimension-labels.json.

Membership maps (data_sets, standards) stay as they are. The explanation
text and optional_io/file_only rules are read from the configs and written
into dimension-labels.json so the dashboard does not duplicate them.

    python3 dashboard/scripts/write-dimension-labels.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "analysis" / "src"))

from benchmark_analysis.dimensions import load_dimensions  # noqa: E402
from benchmark_analysis.explanations import load_dashboard_explanations  # noqa: E402
from benchmark_analysis.fold_io import load_file_only  # noqa: E402

OUT = ROOT / "dashboard" / "public" / "data" / "dimension-labels.json"


def build_optional_io_payload() -> dict:
    dims = load_dimensions()
    opt_io = dims.get("optional_io") or {}
    opt_in = [
        {
            "language": str(row["language"]),
            "serializer": str(row["serializer"]),
            "level": str(row["level"]),
        }
        for row in (opt_io.get("opt_in") or [])
    ]
    file_only = [
        {"language": str(lang), "serializer": str(name)}
        for lang, name in sorted(load_file_only())
    ]
    return {
        "opt_in": opt_in,
        "file_only": file_only,
        "base64_size_ratio": float(opt_io.get("base64_size_ratio", 0.75)),
        "base64_size_tolerance": float(opt_io.get("base64_size_tolerance", 0.05)),
    }


def main() -> int:
    data = json.loads(OUT.read_text(encoding="utf-8"))
    data["explanations"] = load_dashboard_explanations()
    data["optional_io"] = build_optional_io_payload()
    OUT.write_text(
        json.dumps(data, separators=(",", ":"), ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
