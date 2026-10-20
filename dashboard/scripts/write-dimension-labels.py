#!/usr/bin/env python3
"""Refresh explanations inside dashboard/public/data/dimension-labels.json.

Membership maps (data_sets, standards) stay as they are. The explanation
text is read from the configs and written under ``explanations``.

    python3 dashboard/scripts/write-dimension-labels.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "analysis" / "src"))

from benchmark_analysis.explanations import load_dashboard_explanations  # noqa: E402

OUT = ROOT / "dashboard" / "public" / "data" / "dimension-labels.json"


def main() -> int:
    data = json.loads(OUT.read_text(encoding="utf-8"))
    data["explanations"] = load_dashboard_explanations()
    OUT.write_text(
        json.dumps(data, separators=(",", ":"), ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
