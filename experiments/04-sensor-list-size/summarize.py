#!/usr/bin/env python3
"""Turn Experiment 4 CSVs into tables people can read and JSON a dashboard can load."""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
LIB = REPO / "experiments" / "lib"
if str(LIB) not in sys.path:
    sys.path.insert(0, str(LIB))

from experiment_config import load_experiment, libraries_by_language
from summarize_core import (
    CONFIG_NAME,
    assign_top_groups_by,
    experiment_payload_for,
    latest_csv,
    points_by_hash,
    render_grouped_language_markdown,
    render_points_io_combined_markdown,
    run_summarize_cli,
    summarize_language_for,
    write_aggregate_for,
    write_outputs_for,
)

def _load_cfg(path: Path | None = None) -> dict:
    return load_experiment(path or (HERE / CONFIG_NAME))


def _latest_csv(language: str) -> Path | None:
    return latest_csv(HERE, language)

def _points_by_hash() -> dict[str, int]:
    return points_by_hash(HERE)


def _assign_top_groups(rows: list[dict], samples: dict, analysis: dict) -> list[dict]:
    return assign_top_groups_by(rows, samples, analysis, mode="points_io")


def summarize_language(language: str, csv_path: Path, catalog: dict, analysis: dict) -> dict:
    return summarize_language_for(
        language, csv_path, catalog, analysis, mode="points_io", hash_to_points=_points_by_hash()
    )


def write_language_markdown(language: str, pack: dict) -> str:
    return render_grouped_language_markdown(
        4,
        language,
        pack,
        sample_desc="one sensor record (`telemetry`), list lengths 8, 32, 128, 512",
        conv_intro=(
            "We do not name a single winner. Groups are separate for each list length. "
            "Size is the first number we care about."
        ),
        mode="points_io",
    )


def write_combined_markdown(cfg: dict, languages: dict) -> str:
    return render_points_io_combined_markdown(cfg, languages)


def experiment_payload(cfg: dict, languages: dict) -> dict:
    return experiment_payload_for(HERE, cfg, languages)


def write_outputs(language: str, pack: dict) -> None:
    write_outputs_for(HERE, language, pack, write_language_markdown)


def write_aggregate(cfg: dict, languages: dict) -> Path:
    return write_aggregate_for(HERE, cfg, languages, experiment_payload, write_combined_markdown)


def main(argv: list[str] | None = None) -> int:
    return run_summarize_cli(globals(), argv)


if __name__ == "__main__":
    raise SystemExit(main())
