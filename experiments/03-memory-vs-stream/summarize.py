#!/usr/bin/env python3
"""Turn Experiment 3 CSVs into tables people can read and JSON a dashboard can load."""

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
        11,
        language,
        pack,
        sample_desc="one flat record (`message`), 1 record per write",
        conv_intro=(
            "We do not name a single winner. This sample is one small flat record. "
            "A different record can change who is first. A faster one-language "
            "library is not proof that the store is safe."
        ),
    )


def write_combined_markdown(cfg: dict, languages: dict) -> str:
    return render_n_io_combined_markdown(
        cfg,
        languages,
        intro_paragraphs=[
            "Times in two languages are **not** one contest. Read each row as "
            "an answer inside that language only.",
            "We do not name a single winner. This sample is one small flat record. "
            "A different record can change who is first. **Similar** means we "
            "cannot tell the library apart from the fastest in the comparison set "
            "on this sample. **Close** means a small gap. A faster one-language "
            "library is not proof that the store is safe.",
        ],
        include_100_table=False,
        in_memory_intro=(
            "Every listed library (one-language, and libraries other languages can read). "
            "Times are middle values in microseconds. Lower is better **inside that language**."
        ),
        footer_lines=[
            "## What we saw",
            "",
            "On this tiny flat record, the one-language libraries are **slower**, "
            "not faster, than a library another language can read.",
            "",
            "- **Python:** `orjson` is fastest (about 1.70 µs). `msgspec-msgpack` "
            "is close and smaller. `pickle` is about four times slower and larger. "
            "`cloudpickle` and `dill` are slower still.",
            "- **Java:** `protobuf` is fastest. `kryo` is smaller but slower. "
            "`java-serialization` is about four and a half times slower than `protobuf`.",
            "- **Go:** `protobuf` is fastest. `encoding/gob` is about thirteen times slower.",
            "",
            "This sample has only ordinary fields. It does not contain a class, "
            "a function, or another value that JSON cannot hold. That is the case "
            "people mean by “just pickle the cache.”",
            "",
            "## What this page is not",
            "",
            "- It is not a ranking of languages.",
            "- It is not a promise that the same names stay on top if you change the record.",
            "- It is not a safety test. This program does not attack the reader.",
            "- A small time gap on this tiny record is not a reason to put "
            "one-language bytes in a store another program might open.",
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
