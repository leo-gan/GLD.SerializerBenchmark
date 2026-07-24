#!/usr/bin/env python3
"""Query config/benchmark_config.yaml for shell benchmark runners and orchestration.

Examples:
  scripts/read-config.py modes.smoke.repetitions
  scripts/read-config.py --mode-reps smoke
  scripts/read-config.py --seed
  scripts/read-config.py --enabled-langs
  scripts/read-config.py --lang-runners   # id|runner_dir|runner_script
  scripts/read-config.py --logs-root
  scripts/read-config.py --run-config-for-mode smoke
  scripts/read-config.py paths.reports_root
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Prefer installed / local analysis package; fall back to loading sibling module path.
_REPO = Path(__file__).resolve().parent.parent
_ANALYSIS_SRC = _REPO / "analysis" / "src"
if _ANALYSIS_SRC.is_dir() and str(_ANALYSIS_SRC) not in sys.path:
    sys.path.insert(0, str(_ANALYSIS_SRC))

from benchmark_analysis.config_loader import (  # noqa: E402
    default_config_path,
    dig,
    enabled_languages,
    load_master_config,
    logs_root,
    mode_repetitions,
    random_seed,
    reports_root,
    repo_root,
)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("key", nargs="?", help="Dotted key path (e.g. modes.full.repetitions)")
    ap.add_argument("--config", default=None, help="Path to benchmark_config.yaml")
    ap.add_argument("--mode-reps", metavar="MODE", help="Print repetitions for mode")
    ap.add_argument("--seed", action="store_true", help="Print reproducibility.random_seed")
    ap.add_argument("--enabled-langs", action="store_true", help="Space-separated enabled language ids")
    ap.add_argument(
        "--lang-runners",
        action="store_true",
        help="Print enabled langs as id|runner_dir|runner_script (one per line)",
    )
    ap.add_argument("--logs-root", action="store_true", help="Print absolute logs root")
    ap.add_argument("--reports-root", action="store_true", help="Print absolute reports root")
    ap.add_argument(
        "--valid-modes",
        action="store_true",
        help="Space-separated mode names from modes:",
    )
    ap.add_argument(
        "--run-config-for-mode",
        metavar="MODE",
        help=(
            "Absolute path to library run config YAML for mode "
            "(smoke → data_model_v2.smoke_run_config; else default_run_config)"
        ),
    )
    args = ap.parse_args()
    cfg_path = args.config or str(default_config_path())

    if args.mode_reps:
        print(mode_repetitions(args.mode_reps, cfg_path))
        return 0
    if args.seed:
        print(random_seed(cfg_path))
        return 0
    if args.enabled_langs:
        print(" ".join(e["id"] for e in enabled_languages(cfg_path)))
        return 0
    if args.lang_runners:
        for e in enabled_languages(cfg_path):
            print(f"{e['id']}|{e['runner_dir']}|{e['runner_script']}")
        return 0
    if args.logs_root:
        print(logs_root(cfg_path))
        return 0
    if args.reports_root:
        print(reports_root(cfg_path))
        return 0
    if args.valid_modes:
        cfg = load_master_config(cfg_path)
        modes = cfg.get("modes") or {}
        print(" ".join(str(k) for k in modes.keys()))
        return 0
    if args.run_config_for_mode:
        mode = str(args.run_config_for_mode).strip().lower()
        cfg = load_master_config(cfg_path)
        if mode == "smoke":
            rel = dig(cfg, "data_model_v2.smoke_run_config") or dig(
                cfg, "data_model.smoke_run_config", "config/library/smoke.yaml"
            )
        else:
            rel = dig(cfg, "data_model_v2.default_run_config") or dig(
                cfg, "data_model.default_run_config", "config/library/default.yaml"
            )
        rel = str(rel or "config/library/default.yaml")
        p = Path(rel)
        if not p.is_absolute():
            p = repo_root() / p
        print(p.resolve())
        return 0
    if args.key:
        cfg = load_master_config(cfg_path)
        val = dig(cfg, args.key)
        if val is None:
            print(f"error: key not found: {args.key}", file=sys.stderr)
            return 1
        if isinstance(val, (dict, list)):
            import json

            print(json.dumps(val))
        else:
            print(val)
        return 0

    ap.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
