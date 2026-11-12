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
    experiment_payload_for,
    latest_csv,
    render_single_combined_markdown,
    render_single_language_markdown,
    run_summarize_cli,
    summarize_language_for,
    write_aggregate_for,
    write_outputs_for,
)

def _load_cfg(path: Path | None = None) -> dict:
    return load_experiment(path or (HERE / CONFIG_NAME))


def _latest_csv(language: str) -> Path | None:
    return latest_csv(HERE, language)

def summarize_language(language: str, csv_path: Path, catalog: dict, analysis: dict) -> dict:
    return summarize_language_for(language, csv_path, catalog, analysis, mode="single")


def write_language_markdown(language: str, pack: dict) -> str:
    return render_single_language_markdown(15, language, pack)


def write_combined_markdown(cfg: dict, languages: dict) -> str:
    return render_single_combined_markdown(
        cfg,
        languages,
        intro_paragraphs=[
            "Times in two languages are **not** one contest. Read each row as "
            "an answer inside that language only.",
            "We do not name a single winner. This sample is one small order. "
            "A different record can change who is first. **Similar** means we "
            "cannot tell the library apart from the fastest named-JSON library "
            "on this sample. **Close** means a small gap.",
        ],
        section_heading="Named JSON, in memory, by language",
        section_intro=(
            "Only libraries that write ordinary named fields, in-memory call. "
            "Times are middle values in microseconds. Lower is better **inside that language**."
        ),
        empty_msg="No named-JSON in-memory rows.",
        include_role=False,
        footer_lines=[
            "## What this page is not",
            "",
            "- It is not a ranking of languages.",
            "- It is not a ranking of formats. Everyone here writes JSON text.",
            "- It is not a promise that the same names stay on top if you change the record.",
            "",
        ],
    )


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
