#!/usr/bin/env python3
"""Turn Experiment 12 CSVs into tables people can read and JSON a dashboard can load."""

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
    return summarize_language_for(
        language, csv_path, catalog, analysis, mode="n_io", empty_noun="listed-library"
    )


def write_language_markdown(language: str, pack: dict) -> str:
    return render_grouped_language_markdown(
        12,
        language,
        pack,
        sample_desc="one order-like record (`document`), 1 record per write",
        conv_intro=(
            "We do not name a single winner. This sample is one small order. "
            "A different record can change who is first. Holding one library still "
            "is not a claim about every writer of that format."
        ),
    )


def write_combined_markdown(cfg: dict, languages: dict) -> str:
    return render_n_io_combined_markdown(
        cfg,
        languages,
        intro_paragraphs=[
            "Times in two languages are **not** one contest. Read each row as "
            "an answer inside that language only.",
            "We do not name a single winner. This sample is one small order. "
            "A different record can change who is first. **Similar** means we "
            "cannot tell the library apart from the fastest in the comparison set "
            "on this sample. **Close** means a small gap. Holding one library still "
            "is not a claim about every writer of that format.",
        ],
        include_100_table=False,
        in_memory_intro=(
            "Every listed library (same library across formats, and same format across libraries). "
            "Times are middle values in microseconds. Lower is better **inside that language**."
        ),
        footer_lines=[
            "## What we saw",
            "",
            "On this one order, the **library** often moves time more than the **format** "
            "does. Times are not one contest across languages.",
            "",
            "- **Java:** `jsoniter` (JSON) is not clearly slower (about 49 µs, 440 bytes). "
            "Jackson JSON is about 110 µs and the same size. Inside Jackson, Smile is "
            "smaller (233 bytes) and similar in time to Jackson JSON. Jackson MessagePack "
            "is slower than Jackson JSON. `gson` sits between `jsoniter` and Jackson.",
            "- **C++:** All five nlohmann formats sit in a tight time band (about 9–10 µs). "
            "JSON is fastest. MessagePack and CBOR are smaller. BSON is **larger** than JSON.",
            "- **Go:** `goccy/go-json` is fastest (about 2.89 µs, 448 bytes). Inside ugorji, "
            "MessagePack is a bit faster and smaller than JSON. `encoding/json` is about "
            "three times slower than `goccy/go-json`. The three MessagePack libraries "
            "are closer to each other than the three JSON libraries are.",
            "- **C#:** Bond Fast is fastest and writes a larger file (376 bytes). Bond "
            "Compact is smaller (208 bytes). Both protobuf libraries write 208 bytes "
            "and are slower than Bond. Fast vs Compact is the size trade Microsoft wrote down.",
            "- **JavaScript:** All three Protocol Buffers libraries write 155 bytes. "
            "`google-protobuf` is about 16 µs; `protobuf-es` is about 69 µs — same format, "
            "about four times the time.",
            "",
            "“Move to binary” without naming the library is not a plan.",
            "",
            "## What this page is not",
            "",
            "- It is not a ranking of languages.",
            "- It is not a world ranking of formats.",
            "- It is not a claim about every MessagePack (or JSON) library — "
            "only the one library we held still, and the extra names listed for that format.",
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
