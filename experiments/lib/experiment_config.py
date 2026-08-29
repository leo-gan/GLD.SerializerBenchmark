"""Load one experiment.yaml and write the runner's run.yaml from it.

Each experiment folder has its own experiment.yaml. A later editor or UI
should change that file only. This module is shared.

    uv run python -m experiment_config write-run experiments/01-.../experiment.yaml
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import yaml

SCHEMA = "gld.experiment.config/1"

# Language id → script the host already has. Not part of an experiment file.
RUNNERS: dict[str, str] = {
    "python": "python/scripts/run-benchmarks.sh",
    "go": "go/scripts/run-benchmarks.sh",
    "java": "java/scripts/run-benchmarks.sh",
    "javascript": "javascript/scripts/run-benchmarks.sh",
    "rust": "rust/scripts/run-benchmarks.sh",
    "c": "c/scripts/run-benchmarks.sh",
    "cpp": "cpp/scripts/run-benchmarks.sh",
    "csharp": "c-sharp/scripts/run-benchmarks.sh",
    "swift": "swift/scripts/run-benchmarks.sh",
    "kotlin": "kotlin/scripts/run-benchmarks.sh",
    "php": "php/scripts/run-benchmarks.sh",
    "zig": "zig/scripts/run-benchmarks.sh",
}


class ExperimentConfigError(ValueError):
    pass


def load_experiment(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise ExperimentConfigError(f"missing experiment config: {path}")
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ExperimentConfigError(f"experiment config must be a map: {path}")
    schema = data.get("schema")
    if schema != SCHEMA:
        raise ExperimentConfigError(
            f"{path}: schema must be {SCHEMA!r}, got {schema!r}"
        )
    for key in ("id", "question", "sample", "run", "languages"):
        if key not in data:
            raise ExperimentConfigError(f"{path}: missing {key!r}")
    langs = data["languages"]
    if not isinstance(langs, list) or not langs:
        raise ExperimentConfigError(f"{path}: languages must be a non-empty list")
    for i, row in enumerate(langs):
        if not isinstance(row, dict) or not row.get("id"):
            raise ExperimentConfigError(f"{path}: languages[{i}] needs an id")
        if "libraries" not in row or not isinstance(row["libraries"], list):
            raise ExperimentConfigError(f"{path}: languages[{i}].libraries must be a list")
    return data


def enabled_languages(cfg: dict[str, Any]) -> list[str]:
    return [str(row["id"]) for row in cfg["languages"] if row.get("enabled", True)]


def libraries_by_language(cfg: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    return {
        str(row["id"]): list(row.get("libraries") or [])
        for row in cfg["languages"]
        if row.get("enabled", True)
    }


def runner_script(language: str) -> str | None:
    return RUNNERS.get(language)


def _type_rows(sample: dict[str, Any]) -> list[dict[str, Any]]:
    """One runner type per kind, and per points value when settings.points is a list.

    ``sample.kind`` may be one name or a list (Experiments 8, 9, 10, 13).
    ``points`` is only applied to telemetry cells so other kinds do not
    inherit a sensor-list knob.
    """
    kinds = sample["kind"]
    if isinstance(kinds, str):
        kinds = [kinds]
    settings = dict(sample.get("settings") or {})
    points = settings.get("points")
    rows: list[dict[str, Any]] = []
    for kind in kinds:
        cell = dict(settings)
        if kind != "telemetry":
            cell.pop("points", None)
        if kind == "telemetry" and isinstance(points, list):
            for p in points:
                one = dict(cell)
                one["points"] = int(p)
                rows.append({"type_id": kind, "type_config": one})
        else:
            rows.append({"type_id": kind, "type_config": cell})
    return rows


def to_run_yaml(cfg: dict[str, Any]) -> dict[str, Any]:
    """Shape the benchmark runner already understands (config/library/*.yaml)."""
    sample = cfg["sample"]
    run = cfg["run"]
    n = sample.get("records_per_write", 1)
    if isinstance(n, int):
        counts = [n]
    else:
        counts = list(n)
    return {
        "id": cfg["id"],
        "description": cfg.get("title") or cfg["question"],
        "data_model_version": 2,
        "types": _type_rows(sample),
        "data_type_instance_count": counts,
        "compression": {
            "mode": run.get("compression", "size_only"),
            "algorithms": list(run.get("compression_algorithms") or ["gzip_6", "zstd_3"]),
        },
        "execution": {
            "mode": run.get("mode", "full"),
            "io_modes": list(run.get("io_modes") or ["bytes", "stream"]),
        },
        "budget": {
            "soft_seconds_per_10_serializers": int(
                run.get("soft_seconds_per_10_serializers", 60)
            ),
            "hard_cap_seconds": int(run.get("hard_cap_seconds", 600)),
            "reps_fallback": int(run.get("reps_fallback", 50)),
        },
    }


def write_run_yaml(cfg: dict[str, Any], dest: Path) -> None:
    body = to_run_yaml(cfg)
    text = (
        "# Generated from experiment.yaml. Edit experiment.yaml, not this file.\n"
        + yaml.safe_dump(body, sort_keys=False, allow_unicode=True)
    )
    dest.write_text(text, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["write-run", "languages"])
    parser.add_argument("experiment_yaml", type=Path)
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Where to write run.yaml (default: next to experiment.yaml)",
    )
    args = parser.parse_args()
    cfg = load_experiment(args.experiment_yaml)
    if args.command == "write-run":
        dest = args.out or (args.experiment_yaml.parent / "run.yaml")
        write_run_yaml(cfg, dest)
        print(dest)
        return 0
    if args.command == "languages":
        print("\n".join(enabled_languages(cfg)))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
