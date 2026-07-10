#!/usr/bin/env python3
"""Expand a Data Model v2 run config into resolved cells (JSON on stdout).

Examples:
  ./scripts/resolve_run_config.py config/library/default.yaml
  ./scripts/resolve_run_config.py config/library/smoke.yaml --pretty
  ./scripts/resolve_run_config.py config/library/default.yaml --seed 42
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parent.parent
_ANALYSIS_SRC = _REPO / "analysis" / "src"
if _ANALYSIS_SRC.is_dir() and str(_ANALYSIS_SRC) not in sys.path:
    sys.path.insert(0, str(_ANALYSIS_SRC))

from benchmark_analysis.run_config_v2 import (  # noqa: E402
    RunConfigError,
    resolve_run_config,
    soft_budget_seconds,
)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("run_config", type=Path, help="Path to run config YAML")
    ap.add_argument(
        "--catalog",
        type=Path,
        default=None,
        help="Path to data_catalog_v2.yaml (default: schemas/data_catalog_v2.yaml)",
    )
    ap.add_argument("--seed", type=int, default=None, help="Override seed in output")
    ap.add_argument("--pretty", action="store_true", help="Indent JSON")
    ap.add_argument(
        "--soft-budget-for",
        type=int,
        metavar="N_SER",
        default=None,
        help="Print soft_budget_seconds for N serializers and exit (uses run config budget knobs if present)",
    )
    args = ap.parse_args()
    try:
        resolved = resolve_run_config(
            args.run_config,
            catalog_path=args.catalog,
            seed=args.seed,
        )
    except RunConfigError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    if args.soft_budget_for is not None:
        per10 = int(
            (resolved.get("budget") or {}).get("soft_seconds_per_10_serializers") or 60
        )
        print(soft_budget_seconds(args.soft_budget_for, per10))
        return 0

    indent = 2 if args.pretty else None
    json.dump(resolved, sys.stdout, indent=indent, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
