#!/usr/bin/env python3
"""Build the shared experiment record from an experiment folder's experiment.yaml.

Writes sample.json next to experiment.yaml (one file for every language).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

LIB = Path(__file__).resolve().parent
REPO = LIB.parents[1]


def save_experiment_sample(
    experiment_dir: Path,
    argv: list[str] | None = None,
    *,
    about: str | None = None,
) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=None)
    args = parser.parse_args(argv)

    for extra in (REPO / "python" / "src", REPO / "analysis" / "src", LIB):
        s = str(extra)
        if s not in sys.path:
            sys.path.insert(0, s)

    from experiment_config import load_experiment, write_run_yaml
    from benchmark.data_v2.generator import instances_for_cell
    from benchmark_analysis.run_config_v2 import resolve_run_config

    cfg = load_experiment(experiment_dir / "experiment.yaml")
    sample = cfg["sample"]
    seed = args.seed if args.seed is not None else int(sample.get("seed") or 42)
    run_yaml = experiment_dir / "run.yaml"
    write_run_yaml(cfg, run_yaml)
    out_json = experiment_dir / (sample.get("saved_as") or "sample.json")

    catalog = REPO / "schemas" / "data_catalog_v2.yaml"
    resolved = resolve_run_config(run_yaml, catalog_path=catalog, seed=seed)

    cells = []
    for cell in resolved["cells"]:
        instances = instances_for_cell(
            cell["type_id"],
            cell["type_config"],
            seed,
            1,
        )
        cells.append(
            {
                "kind": cell["type_id"],
                "settings": cell["type_config"],
                "settings_hash": cell["type_config_hash"],
                "how_many_records": int(cell["data_type_instance_count"]),
                "seed": seed,
                "records": [obj.to_dict() for obj in instances[:1]],
            }
        )

    exp_id = cfg["id"]
    kind = sample.get("kind") or "record"
    about_text = about or (
        f"This is the shared {exp_id} record ({kind}). "
        "It was built from experiment.yaml with the same builder and "
        "seed as the benchmark. Do not edit by hand. If experiment.yaml "
        "changes, run python/save_sample.py again."
    )
    payload = {
        "about": about_text,
        "experiment": exp_id,
        "config": f"experiments/{exp_id}/experiment.yaml",
        "builder": "python/src/benchmark/data_v2/generator.py",
        "cells": cells,
    }
    out_json.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"Wrote {out_json}")
    return 0
