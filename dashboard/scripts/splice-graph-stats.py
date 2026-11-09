#!/usr/bin/env python3
"""Append graph.yaml groups onto the published dashboard snapshots.

sync-data.py publishes only logs named YYYY-MM-DD-HHMMSS.csv. Graph full runs
use names like 2026-10-09-<lang>-graph-full.csv. This script analyzes one of
those CSVs and appends the graph data type. On a re-run it replaces previously
spliced graph groups. Suite and columnar groups are not recomputed.
"""
from __future__ import annotations

import argparse
import copy
import csv
import sys
from datetime import datetime, timezone
from pathlib import Path

from snapshot_io import load_json_gz, write_json_gz

from splice_rows import (
    as_whole as _norm,
    base_type as _base,
    count_bases as _counts,
    error_row_count as _error_rows,
    require_finite as _finite,
)

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "analysis" / "src"))

from benchmark_analysis.parser import parse_csv_file  # noqa: E402
from benchmark_analysis.stats import (  # noqa: E402
    build_stats_export_payload,
    compute_statistics_multi_policy,
    load_stats_config,
)

DATA = REPO / "dashboard" / "public" / "data"
GRAPH_TYPES = ("graph",)
DAGR_NAMES = ("dagr-regular", "dagr-frozen")
# Python's comma filter is a substring match, so "pickle" also selects cloudpickle.
PYTHON_EXTRA = {"pickle": "python-3.14.0", "cloudpickle": "3.1.2"}
DAGR_VERSION = "2026.10.1"
INSTANCE_COUNTS = (1, 100)
MIN_REPS = 100
ALLOWED_STREAM_MODES = {"", "native", "adapted", "text_on_stream", "text"}
COLUMNAR_TYPES = ("table", "table_project", "nested_table", "signal")
SUITE_TYPES = ("message", "document", "telemetry", "strings", "event")

DEFAULT_CSVS = {
    "python": REPO / "logs/python/2026-10-19-python-graph-full.csv",
    "cpp": REPO / "logs/cpp/2026-10-19-cpp-graph-full.csv",
    "rust": REPO / "logs/rust/2026-10-19-rust-graph-full.csv",
    "go": REPO / "logs/go/2026-10-19-go-graph-full.csv",
    "javascript": REPO / "logs/javascript/2026-10-19-javascript-graph-full.csv",
    "mojo": REPO / "logs/mojo/2026-10-19-mojo-graph-full.csv",
    "swift": REPO / "logs/swift/2026-10-19-swift-graph-full.csv",
}


def _core(group: dict) -> tuple:
    return (
        group.get("serializer"),
        group.get("test_data"),
        group.get("type_config_hash"),
        _norm(group.get("data_type_instance_count")),
        group.get("mode"),
        group.get("language"),
        str(group.get("serializer_version") or ""),
    )


def _allowed_version(lang: str, name: str) -> str:
    if name in DAGR_NAMES:
        return DAGR_VERSION
    if lang == "python" and name in PYTHON_EXTRA:
        return PYTHON_EXTRA[name]
    raise SystemExit(f"{lang}: serializer {name!r} is not on the graph allow-list")


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
        raise SystemExit(f"{csv_path}: repetitions {reps}; expected {MIN_REPS}")

    indexes: dict[tuple, set[int]] = {}
    for row in records:
        name = str(row.get("SerializerName") or "")
        version = _allowed_version(lang, name)
        if str(row.get("SerializerVersion") or "") != version:
            raise SystemExit(
                f"{csv_path}: {name} version {row.get('SerializerVersion')!r} != {version}"
            )
        type_id = _base(row.get("TestDataName"))
        if type_id not in GRAPH_TYPES:
            raise SystemExit(f"{csv_path}: refusing non-graph type {type_id!r}")
        count = _norm(row.get("DataTypeInstanceCount"))
        if count not in INSTANCE_COUNTS:
            raise SystemExit(f"{csv_path}: refusing instance count {count!r}")
        if str(row.get("StringOrStream") or "") != "bytes":
            raise SystemExit(f"{csv_path}: refusing I/O mode {row.get('StringOrStream')!r}")
        if str(row.get("Language") or "") != lang:
            raise SystemExit(f"{csv_path}: row language {row.get('Language')!r} != {lang}")
        fidelity = row.get("FidelityScore")
        if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
            raise SystemExit(f"{csv_path}: fidelity {fidelity!r} for {name} n={count}")
        stream_mode = str(row.get("StreamMode") or "").strip()
        if stream_mode not in ALLOWED_STREAM_MODES:
            raise SystemExit(f"{csv_path}: unexpected StreamMode {stream_mode!r}")
        indexes.setdefault((name, count), set()).add(int(row.get("RepetitionIndex") or 0))

    names = {name for name, _count in indexes}
    missing = [name for name in DAGR_NAMES if name not in names]
    if missing:
        raise SystemExit(f"{csv_path}: missing Dagr rows {missing}")
    for key, seen in indexes.items():
        if seen != set(range(MIN_REPS)):
            raise SystemExit(f"{csv_path}: {key} repetition indexes are not 0..{MIN_REPS - 1}")

    config = load_stats_config()
    by_policy = compute_statistics_multi_policy(records, config=config, language_hint=lang)
    fresh = build_stats_export_payload(by_policy, lang)
    if fresh.get("schema_version") != "2.2":
        raise SystemExit(f"analysis produced schema {fresh.get('schema_version')}, expected 2.2")
    meta = {
        "reps": reps,
        "serializers": sorted(names),
        "rows": len(records),
    }
    return fresh, meta


def _validate_fresh(lang: str, fresh: dict, published_groups: list) -> list:
    groups = list(fresh.get("groups") or [])
    if not published_groups:
        raise SystemExit(f"{lang}: published snapshot has no groups to append to")
    expected_policies = set((published_groups[0].get("variants") or {}))
    if not expected_policies:
        raise SystemExit(f"{lang}: published groups have no filter-policy variants")
    cells = set()
    for group in groups:
        _finite(group, f"{lang}/{group.get('serializer')}")
        name = str(group.get("serializer") or "")
        if group.get("language") != lang:
            raise SystemExit(f"{lang}: analysis group language is {group.get('language')!r}")
        if _base(group.get("test_data")) != "graph":
            raise SystemExit(f"{lang}: analysis test_data {group.get('test_data')!r}")
        if group.get("data_set") != "graph":
            raise SystemExit(f"{lang}: {name} data_set is {group.get('data_set')!r}")
        if group.get("standard") != "custom":
            raise SystemExit(f"{lang}: {name} standard is {group.get('standard')!r}")
        if group.get("mode") != "published":
            raise SystemExit(f"{lang}: {name} mode is {group.get('mode')!r}")
        if str(group.get("serializer_version") or "") != _allowed_version(lang, name):
            raise SystemExit(f"{lang}: {name} version {group.get('serializer_version')!r}")
        count = _norm(group.get("data_type_instance_count"))
        cell = (name, count)
        if cell in cells:
            raise SystemExit(f"{lang}: duplicate group {cell}")
        cells.add(cell)
        variants = group.get("variants") or {}
        if set(variants) != expected_policies:
            raise SystemExit(f"{lang}: {name} policies {sorted(variants)} != {sorted(expected_policies)}")
        for policy, metrics in variants.items():
            fidelity = metrics.get("mean_fidelity")
            if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
                raise SystemExit(f"{lang}: {name} {policy} fidelity {fidelity!r}")
            filt = metrics.get("filter") or {}
            if int(filt.get("runs_raw") or 0) != MIN_REPS:
                raise SystemExit(f"{lang}: {name} {policy} runs_raw {filt.get('runs_raw')!r}")
    if not all((name, count) in cells for name in DAGR_NAMES for count in INSTANCE_COUNTS):
        raise SystemExit(f"{lang}: Dagr graph cells are incomplete: {sorted(cells)}")
    return groups


def _split(groups: list) -> tuple[list, list]:
    keep, old = [], []
    for group in groups:
        if _base(group.get("test_data")) == "graph":
            old.append(group)
        else:
            keep.append(group)
    return keep, old


def splice_language(lang: str, csv_path: Path, *, dry_run: bool) -> None:
    stats_path = DATA / f"stats_{lang}_latest.json.gz"
    if not stats_path.is_file():
        raise SystemExit(f"{lang}: missing {stats_path.name}")
    stats = load_json_gz(stats_path)

    stats_groups = list(stats.get("groups") or [])
    fresh, meta = _analyze(lang, csv_path)
    new_groups = _validate_fresh(lang, fresh, stats_groups)
    stats_keep, stats_old = _split(stats_groups)
    before_suite = _counts(stats_keep, SUITE_TYPES)
    before_columnar = _counts(stats_keep, COLUMNAR_TYPES)
    note = {
        "source_csv": str(csv_path.relative_to(REPO)),
        "run_config": "config/library/graph.yaml",
        "analyzed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "rows": meta["rows"],
        "reps": meta["reps"],
        "serializers": meta["serializers"],
        "groups_added": len(new_groups),
        "groups_replaced": len(stats_old),
        "note": (
            "Graph groups were measured in a separate full-mode run "
            "(config/library/graph.yaml, 100 repetitions) and appended. "
            "Existing suite and columnar groups were not recomputed."
        ),
    }
    print(f"{lang}: {meta['rows']} rows, {len(new_groups)} groups, replace {len(stats_old)}")
    if dry_run:
        print(f"{lang}: dry-run, snapshots not written")
        return

    dagr_note = copy.deepcopy(stats.get("dagr_splice"))
    columnar_note = copy.deepcopy(stats.get("columnar_splice"))
    stats["groups"] = stats_keep + new_groups
    stats["graph_splice"] = note
    if _counts(stats["groups"], SUITE_TYPES) != before_suite:
        raise SystemExit(f"{lang}: suite counts changed")
    if _counts(stats["groups"], COLUMNAR_TYPES) != before_columnar:
        raise SystemExit(f"{lang}: columnar counts changed")
    if stats.get("dagr_splice") != dagr_note or stats.get("columnar_splice") != columnar_note:
        raise SystemExit(f"{lang}: an existing splice note changed")
    write_json_gz(stats_path, stats)
    print(f"{lang}: wrote {len(new_groups)} graph groups")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", action="append", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    for lang in args.language:
        path = DEFAULT_CSVS.get(lang)
        if path is None or not path.is_file():
            raise SystemExit(f"{lang}: CSV not found: {path}")
        splice_language(lang, path, dry_run=args.dry_run)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
