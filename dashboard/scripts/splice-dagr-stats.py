#!/usr/bin/env python3
"""Append Dagr suite groups onto the published dashboard snapshots.

sync-data.py publishes only logs named YYYY-MM-DD-HHMMSS.csv, and it replaces
the whole language snapshot. Dagr full runs use other filenames on purpose
(2026-10-08-<lang>-dagr-full.csv). This script does not call sync-data.

It analyzes one Dagr CSV with the same statistics pipeline as analyze-benchmarks,
then appends schema-2.2 groups for the four Dagr layouts. On a re-run those
layouts replace the previously spliced Dagr groups. Every other group stays.

Both dashboard/public/data/<lang>_latest.json.gz and stats_<lang>_latest.json.gz
gain the same 40 groups (4 layouts x 5 suite types x n=1 and n=100). The stats
file is what Overview loads. Its groups already carry standard and data_set.
The language payload's embedded groups are the same rows without those two
fields; this script leaves that existing shape alone and only appends.
"""
from __future__ import annotations

import argparse
import copy
import csv
import gzip
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "analysis" / "src"))

from benchmark_analysis.parser import parse_csv_file  # noqa: E402
from benchmark_analysis.stats import (  # noqa: E402
    build_stats_export_payload,
    compute_statistics_multi_policy,
    load_stats_config,
)

DATA = REPO / "dashboard" / "public" / "data"
DAGR_SERIALIZERS = (
    "dagr-frozen",
    "dagr-frozen-packed",
    "dagr-packed",
    "dagr-regular",
)
DAGR_SET = set(DAGR_SERIALIZERS)
SUITE_TYPES = ("message", "document", "telemetry", "strings", "event")
SUITE_SET = set(SUITE_TYPES)
COLUMNAR_TYPES = ("table", "table_project", "nested_table", "signal")
INSTANCE_COUNTS = (1, 100)
MIN_REPS = 100
EXPECTED_VERSION = "2026.10.1"
EXPECTED_CELLS = {
    (name, type_id, count)
    for name in DAGR_SERIALIZERS
    for type_id in SUITE_TYPES
    for count in INSTANCE_COUNTS
}
# Bytes rows still carry the harness honesty label. It is not a second I/O level.
ALLOWED_STREAM_MODES = {"", "native", "adapted", "text_on_stream", "text"}

# Full Dagr CSVs. Names must not match sync-data's latest-run regex.
DEFAULT_CSVS = {
    "python": REPO / "logs/python/2026-10-08-python-dagr-full.csv",
    "cpp": REPO / "logs/cpp/2026-10-08-cpp-dagr-full.csv",
    "rust": REPO / "logs/rust/2026-10-08-rust-dagr-full.csv",
    "go": REPO / "logs/go/2026-10-08-go-dagr-full.csv",
    "javascript": REPO / "logs/javascript/2026-10-08-javascript-dagr-full.csv",
    "mojo": REPO / "logs/mojo/2026-10-08-mojo-dagr-full.csv",
    "swift": REPO / "logs/swift/2026-10-08-swift-dagr-full.csv",
}


def _base(test_data: object) -> str:
    return str(test_data or "").split("@n=")[0]


def _norm(value):
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def _core(group: dict) -> tuple:
    """Identity shared by the labeled stats file and the unlabeled payload."""
    return (
        group.get("serializer"),
        group.get("test_data"),
        group.get("type_config_hash"),
        _norm(group.get("data_type_instance_count")),
        group.get("mode"),
        group.get("language"),
        str(group.get("serializer_version") or ""),
    )


def _cell(group: dict) -> tuple:
    return (
        str(group.get("serializer") or ""),
        _base(group.get("test_data")),
        _norm(group.get("data_type_instance_count")),
    )


def _counts(groups: list, names: tuple[str, ...]) -> dict[str, int]:
    out = {name: 0 for name in names}
    for group in groups:
        base = _base(group.get("test_data"))
        if base in out:
            out[base] += 1
    return out


def _load_gz(path: Path) -> dict:
    with gzip.open(path, "rt", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise SystemExit(f"{path} is not a JSON object")
    return data


def _dump(payload: dict) -> str:
    # Match the published files: compact, default ensure_ascii, no trailing newline.
    return json.dumps(payload, separators=(",", ":"))


def _write_gz(path: Path, payload: dict) -> None:
    raw = _dump(payload).encode("utf-8")
    tmp = path.with_suffix(path.suffix + ".tmp")
    with gzip.open(tmp, "wb", compresslevel=9) as handle:
        handle.write(raw)
    tmp.replace(path)


def _finite(value, path: str) -> None:
    if isinstance(value, float):
        if not math.isfinite(value):
            raise SystemExit(f"non-finite number at {path}")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            _finite(item, f"{path}.{key}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            _finite(item, f"{path}[{index}]")


def _error_rows(csv_path: Path) -> int:
    err_path = csv_path.with_name(csv_path.stem + ".errors.csv")
    if not err_path.is_file():
        return 0
    with err_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.reader(handle))
    if not rows:
        return 0
    return max(0, len(rows) - 1)


def _analyze(lang: str, csv_path: Path) -> tuple[dict, dict]:
    error_rows = _error_rows(csv_path)
    if error_rows:
        raise SystemExit(f"{csv_path}: refusing to publish; {error_rows} error row(s)")
    records, skipped = parse_csv_file(str(csv_path), language_hint=lang)
    if skipped:
        raise SystemExit(f"{csv_path}: refusing to publish; parser skipped {skipped} row(s)")
    if not records:
        raise SystemExit(f"{csv_path}: no records")

    reps = sorted({int(row.get("Repetitions") or 0) for row in records})
    if reps != [MIN_REPS]:
        raise SystemExit(
            f"{csv_path}: repetitions {reps}; refusing unless every row is a {MIN_REPS}-rep full run"
        )

    indexes: dict[tuple, set[int]] = {}
    stream_modes: dict[tuple, set[str]] = {}
    for row in records:
        name = str(row.get("SerializerName") or "")
        if name not in DAGR_SET:
            raise SystemExit(f"{csv_path}: refusing non-Dagr serializer {name!r}")
        type_id = _base(row.get("TestDataName"))
        if type_id not in SUITE_SET:
            raise SystemExit(f"{csv_path}: refusing non-suite type {type_id!r}")
        count = _norm(row.get("DataTypeInstanceCount"))
        if count not in INSTANCE_COUNTS:
            raise SystemExit(f"{csv_path}: refusing instance count {count!r}")
        mode = str(row.get("StringOrStream") or "")
        if mode != "bytes":
            raise SystemExit(f"{csv_path}: refusing I/O mode {mode!r}; Dagr publishes bytes only")
        language = str(row.get("Language") or "")
        if language != lang:
            raise SystemExit(f"{csv_path}: row language {language!r} != {lang}")
        version = str(row.get("SerializerVersion") or "")
        if version != EXPECTED_VERSION:
            raise SystemExit(f"{csv_path}: serializer version {version!r} != {EXPECTED_VERSION}")
        fidelity = row.get("FidelityScore")
        if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
            raise SystemExit(f"{csv_path}: fidelity {fidelity!r} for {name} {type_id} n={count}")
        stream_mode = str(row.get("StreamMode") or "").strip()
        if stream_mode not in ALLOWED_STREAM_MODES:
            raise SystemExit(f"{csv_path}: unexpected StreamMode {stream_mode!r}")
        key = (name, type_id, count)
        indexes.setdefault(key, set()).add(int(row.get("RepetitionIndex") or 0))
        stream_modes.setdefault(key, set()).add(stream_mode)

    missing = sorted(EXPECTED_CELLS - set(indexes))
    extra = sorted(set(indexes) - EXPECTED_CELLS)
    if missing or extra:
        raise SystemExit(f"{csv_path}: cells missing={missing[:8]} extra={extra[:8]}")
    for key, seen in indexes.items():
        if seen != set(range(MIN_REPS)):
            raise SystemExit(f"{csv_path}: {key} repetition indexes are not 0..{MIN_REPS - 1}")
        modes = stream_modes.get(key) or {""}
        if len(modes) != 1:
            raise SystemExit(f"{csv_path}: {key} mixes StreamMode values {sorted(modes)}")

    config = load_stats_config()
    by_policy = compute_statistics_multi_policy(records, config=config, language_hint=lang)
    fresh = build_stats_export_payload(by_policy, lang)
    if fresh.get("schema_version") != "2.2":
        raise SystemExit(f"analysis produced schema {fresh.get('schema_version')}, expected 2.2")
    meta = {
        "reps": reps,
        "serializers": sorted({str(row.get("SerializerName") or "") for row in records}),
        "types": sorted({_base(row.get("TestDataName")) for row in records}),
        "rows": len(records),
        "version": EXPECTED_VERSION,
    }
    return fresh, meta


def _validate_fresh(lang: str, fresh: dict, published_groups: list) -> list:
    groups = list(fresh.get("groups") or [])
    if len(groups) != len(EXPECTED_CELLS):
        raise SystemExit(f"{lang}: analysis produced {len(groups)} groups, expected {len(EXPECTED_CELLS)}")
    if not published_groups:
        raise SystemExit(f"{lang}: published snapshot has no groups to append to")
    expected_policies = set((published_groups[0].get("variants") or {}))
    if not expected_policies:
        raise SystemExit(f"{lang}: published groups have no filter-policy variants")

    cells = set()
    for group in groups:
        _finite(group, f"{lang}/{group.get('serializer')}")
        name = str(group.get("serializer") or "")
        if name not in DAGR_SET:
            raise SystemExit(f"{lang}: analysis emitted non-Dagr serializer {name!r}")
        if group.get("language") != lang:
            raise SystemExit(f"{lang}: analysis group language is {group.get('language')!r}")
        if group.get("test_data") not in SUITE_SET:
            raise SystemExit(f"{lang}: analysis test_data {group.get('test_data')!r} is not a suite id")
        if group.get("standard") != "custom":
            raise SystemExit(f"{lang}: {name} standard is {group.get('standard')!r}, expected custom")
        if group.get("data_set") != "suite":
            raise SystemExit(f"{lang}: {name} data_set is {group.get('data_set')!r}, expected suite")
        if group.get("mode") != "published":
            raise SystemExit(f"{lang}: {name} mode is {group.get('mode')!r}, expected published")
        if group.get("io_parent") != "single":
            raise SystemExit(f"{lang}: {name} io_parent is {group.get('io_parent')!r}, expected single")
        if group.get("optional") not in ([], None):
            raise SystemExit(f"{lang}: {name} has optional I/O children")
        stream_mode = str(group.get("StreamMode") or "")
        if stream_mode not in ALLOWED_STREAM_MODES:
            raise SystemExit(f"{lang}: {name} has StreamMode {stream_mode!r}")
        if str(group.get("serializer_version") or "") != EXPECTED_VERSION:
            raise SystemExit(
                f"{lang}: {name} version {group.get('serializer_version')!r} != {EXPECTED_VERSION}"
            )
        if not str(group.get("type_config_hash") or ""):
            raise SystemExit(f"{lang}: {name} {group.get('test_data')} is missing type_config_hash")
        count = _norm(group.get("data_type_instance_count"))
        if count not in INSTANCE_COUNTS:
            raise SystemExit(f"{lang}: {name} instance count {count!r}")
        cell = (name, str(group.get("test_data")), count)
        if cell in cells:
            raise SystemExit(f"{lang}: duplicate group {cell}")
        cells.add(cell)

        variants = group.get("variants") or {}
        if set(variants) != expected_policies:
            raise SystemExit(
                f"{lang}: {name} policies {sorted(variants)} != published {sorted(expected_policies)}"
            )
        for policy, metrics in variants.items():
            if not isinstance(metrics, dict):
                raise SystemExit(f"{lang}: {name} policy {policy} is not an object")
            fidelity = metrics.get("mean_fidelity")
            if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
                raise SystemExit(f"{lang}: {name} {policy} fidelity {fidelity!r}")
            filt = metrics.get("filter") or {}
            if int(filt.get("runs_raw") or 0) != MIN_REPS:
                raise SystemExit(f"{lang}: {name} {policy} runs_raw {filt.get('runs_raw')!r}")
            if int(filt.get("warmup_skipped") or 0) != 1:
                raise SystemExit(
                    f"{lang}: {name} {policy} warmup_skipped {filt.get('warmup_skipped')!r}"
                )
            size = metrics.get("median_size_bytes")
            if not isinstance(size, (int, float)) or size <= 0:
                raise SystemExit(f"{lang}: {name} {policy} median_size_bytes {size!r}")
            total = metrics.get("avg_time_total_ns")
            if not isinstance(total, (int, float)) or total <= 0:
                raise SystemExit(f"{lang}: {name} {policy} avg_time_total_ns {total!r}")

    if cells != EXPECTED_CELLS:
        raise SystemExit(f"{lang}: group cells {sorted(cells - EXPECTED_CELLS)} do not match the matrix")
    return groups


def _split(lang: str, groups: list) -> tuple[list, list]:
    keep = []
    old = []
    for group in groups:
        name = str(group.get("serializer") or "")
        if name.lower().startswith("dagr") and name not in DAGR_SET:
            raise SystemExit(f"{lang}: refusing to touch unexpected serializer {name!r}")
        if name in DAGR_SET:
            old.append(group)
        else:
            keep.append(group)
    return keep, old


def _summary_line(group: dict) -> str:
    metrics = (group.get("variants") or {}).get("iqr_1.5") or {}
    ops = metrics.get("avg_ops_per_sec")
    size = metrics.get("median_size_bytes")
    ops_text = f"{ops:,.0f}" if isinstance(ops, (int, float)) else "?"
    size_text = f"{size:,.0f}" if isinstance(size, (int, float)) else "?"
    return (
        f"  {group.get('serializer'):<20} {group.get('test_data')} n={group.get('data_type_instance_count')} "
        f"ops={ops_text} size={size_text}"
    )


def splice_language(lang: str, csv_path: Path, *, dry_run: bool) -> None:
    payload_path = DATA / f"{lang}_latest.json.gz"
    stats_path = DATA / f"stats_{lang}_latest.json.gz"
    if not payload_path.is_file() or not stats_path.is_file():
        raise SystemExit(f"{lang}: missing {payload_path.name} or {stats_path.name}")
    payload = _load_gz(payload_path)
    stats = _load_gz(stats_path)
    embedded = payload.get("stats")
    if not isinstance(embedded, dict):
        raise SystemExit(f"{lang}: payload has no stats object")
    if embedded.get("schema_version") != "2.2" or stats.get("schema_version") != "2.2":
        raise SystemExit(f"{lang}: published schema is not 2.2")

    stats_groups = list(stats.get("groups") or [])
    payload_groups = list(embedded.get("groups") or [])
    if len(stats_groups) != len(payload_groups):
        raise SystemExit(
            f"{lang}: stats groups {len(stats_groups)} != payload groups {len(payload_groups)}"
        )
    for index, (left, right) in enumerate(zip(payload_groups, stats_groups)):
        if _core(left) != _core(right):
            raise SystemExit(f"{lang}: payload/stats group {index} diverged at {_core(left)} vs {_core(right)}")
        if not right.get("standard") or not right.get("data_set"):
            raise SystemExit(f"{lang}: stats group {index} {right.get('serializer')} has no standard")

    fresh, meta = _analyze(lang, csv_path)
    new_groups = _validate_fresh(lang, fresh, stats_groups)
    stats_keep, stats_old = _split(lang, stats_groups)
    payload_keep, payload_old = _split(lang, payload_groups)
    if [_core(group) for group in stats_keep] != [_core(group) for group in payload_keep]:
        raise SystemExit(f"{lang}: non-Dagr groups diverged between stats and payload")

    before_columnar = _counts(stats_keep, COLUMNAR_TYPES)
    before_suite = _counts(stats_keep, SUITE_TYPES)
    note = {
        "source_csv": str(csv_path.relative_to(REPO)),
        "run_config": "config/library/default.yaml",
        "analyzed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "rows": meta["rows"],
        "reps": meta["reps"],
        "serializer_version": meta["version"],
        "types": meta["types"],
        "serializers": meta["serializers"],
        "groups_added": len(new_groups),
        "groups_replaced": len(stats_old),
        "suite_group_counts_before": before_suite,
        "note": (
            "Dagr groups were measured in a separate full-mode run "
            "(config/library/default.yaml, serializer filter dagr, 100 repetitions) and appended. "
            "Existing suite and columnar groups were not recomputed. "
            "Effect sizes on the Dagr groups are within the Dagr cohort only."
        ),
    }
    print(
        f"{lang}: {meta['rows']} rows, {len(new_groups)} groups, "
        f"replace {len(stats_old)}, version {meta['version']}"
    )
    for group in new_groups:
        if group.get("test_data") == "message" and _norm(group.get("data_type_instance_count")) == 1:
            print(_summary_line(group))
    if dry_run:
        print(f"{lang}: dry-run, snapshots not written")
        return

    stats_before = copy.deepcopy(stats_keep)
    payload_before = copy.deepcopy(payload_keep)
    columnar_stats = copy.deepcopy(stats.get("columnar_splice"))
    columnar_payload = copy.deepcopy(payload.get("columnar_splice"))
    columnar_embedded = copy.deepcopy(embedded.get("columnar_splice"))
    payload_note = copy.deepcopy(note)
    embedded_note = copy.deepcopy(note)

    stats["groups"] = stats_keep + new_groups
    stats["dagr_splice"] = note
    embedded["groups"] = payload_keep + copy.deepcopy(new_groups)
    embedded["dagr_splice"] = embedded_note
    payload["dagr_splice"] = payload_note

    if stats["groups"][: len(stats_before)] != stats_before:
        raise SystemExit(f"{lang}: non-Dagr stats groups changed")
    if embedded["groups"][: len(payload_before)] != payload_before:
        raise SystemExit(f"{lang}: non-Dagr payload groups changed")
    if _counts(stats["groups"], COLUMNAR_TYPES) != before_columnar:
        raise SystemExit(f"{lang}: columnar counts changed")
    if _counts(stats_keep, SUITE_TYPES) != before_suite:
        raise SystemExit(f"{lang}: non-Dagr suite counts changed")
    if stats.get("columnar_splice") != columnar_stats:
        raise SystemExit(f"{lang}: columnar_splice on stats changed")
    if payload.get("columnar_splice") != columnar_payload:
        raise SystemExit(f"{lang}: columnar_splice on payload changed")
    if embedded.get("columnar_splice") != columnar_embedded:
        raise SystemExit(f"{lang}: columnar_splice inside payload stats changed")
    if len(stats["groups"]) != len(embedded["groups"]):
        raise SystemExit(f"{lang}: spliced lengths diverged")
    dagr_cells = {_cell(group) for group in stats["groups"] if group.get("serializer") in DAGR_SET}
    if dagr_cells != EXPECTED_CELLS:
        raise SystemExit(f"{lang}: spliced Dagr cells are incomplete")

    _write_gz(stats_path, stats)
    _write_gz(payload_path, payload)

    written_stats = _load_gz(stats_path)
    written_payload = _load_gz(payload_path)
    if written_stats.get("groups") != stats["groups"]:
        raise SystemExit(f"{lang}: reread stats groups do not match the write")
    if written_payload.get("stats", {}).get("groups") != embedded["groups"]:
        raise SystemExit(f"{lang}: reread payload groups do not match the write")
    if len(written_stats["groups"]) != len(written_payload["stats"]["groups"]):
        raise SystemExit(f"{lang}: written group counts diverged")
    print(f"{lang}: wrote {len(new_groups)} Dagr groups into {stats_path.name} and {payload_path.name}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--language",
        action="append",
        required=True,
        help="Language id to splice. Repeatable.",
    )
    parser.add_argument("--csv", default="", help="CSV path, only with a single --language.")
    parser.add_argument("--dry-run", action="store_true", help="Validate and print. Do not write gz files.")
    args = parser.parse_args(argv)

    if args.csv and len(args.language) != 1:
        raise SystemExit("--csv requires exactly one --language")

    jobs = []
    for lang in args.language:
        if lang not in DEFAULT_CSVS and not args.csv:
            raise SystemExit(f"unknown language {lang}; known: {sorted(DEFAULT_CSVS)}")
        path = Path(args.csv) if args.csv else DEFAULT_CSVS[lang]
        if not path.is_file():
            raise SystemExit(f"{lang}: CSV not found: {path}")
        jobs.append((lang, path if path.is_absolute() else (REPO / path)))

    for lang, path in jobs:
        splice_language(lang, path, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
