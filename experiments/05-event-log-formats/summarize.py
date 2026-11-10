#!/usr/bin/env python3
"""Turn Experiment 5 CSVs into tables people can read and JSON a dashboard can load."""

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
    render_grouped_language_markdown,
    render_n_io_combined_markdown,
    run_summarize_cli,
    summarize_language_for,
    write_aggregate_for,
    write_outputs_for,
)

def _load_cfg(path: Path | None = None) -> dict:
    return load_experiment(path or (HERE / CONFIG_NAME))


def _latest_csv(language: str) -> Path | None:
    return latest_csv(HERE, language)

def _assign_top_groups(rows: list[dict], samples: dict, analysis: dict) -> list[dict]:
    return assign_top_groups_by(rows, samples, analysis, mode="n_io")


def summarize_language(language: str, csv_path: Path, catalog: dict, analysis: dict) -> dict:
    return summarize_language_for(language, csv_path, catalog, analysis, mode="n_io")


def write_language_markdown(language: str, pack: dict) -> str:
    return render_grouped_language_markdown(
        5,
        language,
        pack,
        sample_desc="one event (`event`), 1 and 100 records per write",
        conv_intro=(
            "We do not name a single winner. This sample is one event. "
            "Groups are computed **separately** for 1 record and for 100 records. "
            "Speed cannot override a failed compatibility story."
        ),
    )


def write_combined_markdown(cfg: dict, languages: dict) -> str:
    return render_n_io_combined_markdown(
        cfg,
        languages,
        intro_paragraphs=[
            "Times in two languages are **not** one contest. Read each row as "
            "an answer inside that language only.",
            "We do not name a single winner. This sample is one event. "
            "**Similar** means we cannot tell the library apart from the fastest "
            "in the comparison set on this sample. **Close** means a small gap. "
            "Groups for 1 record and for 100 records are separate. "
            "Speed cannot override a failed compatibility story.",
        ],
        include_100_table=True,
        in_memory_intro=(
            "Every listed library (JSON, Avro, Protocol Buffers). "
            "Times are middle values in microseconds. Lower is better **inside that language**."
        ),
        footer_lines=[
            "## What we saw",
            "",
            "Avro and Protocol Buffers write about half the bytes of JSON "
            "(about 105 and 123 versus 257 on one event). Times are not one contest.",
            "",
            "- **Python:** `orjson` is fastest at one record (about 2.78 µs, 257 bytes). "
            "Protocol Buffers is smaller and next (4.32 µs, 123 bytes). Avro is smallest "
            "(105 bytes) and much slower (19 µs write+read; write about 12 µs). "
            "At 100 records, Protocol Buffers is fastest; Avro is far slower.",
            "- **Java:** `protobuf` is fastest at 1 and 100. Avro is smaller (105 vs 123) "
            "and slower. Jackson JSON is larger (254 bytes).",
            "- **Go:** `hamba/avro` is fastest at 1 and 100 (about 2.08 µs, 107 bytes). "
            "`linkedin/goavro` writes the same small file and is slower, especially at 100. "
            "If you already chose Avro, pick the faster library inside Avro.",
            "",
            "Use the size cut in the disk budget. Still pick Avro vs Protocol Buffers "
            "on process grounds (who may add a field, and when).",
            "",
            "## What this page is not",
            "",
            "- It is not a ranking of languages.",
            "- It is not a compatibility test (an old reader vs a new field).",
            "- It is not an analytics store. Column files such as Parquet are a different job.",
            "- Speed cannot override a failed compatibility story.",
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
