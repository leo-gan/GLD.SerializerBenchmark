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
    "python": REPO / "logs/python/2026-10-09-python-graph-full.csv",
    "cpp": REPO / "logs/cpp/2026-10-09-cpp-graph-full.csv",
    "rust": REPO / "logs/rust/2026-10-09-rust-graph-full.csv",
    "go": REPO / "logs/go/2026-10-09-go-graph-full.csv",
    "javascript": REPO / "logs/javascript/2026-10-09-javascript-graph-full.csv",
    "mojo": REPO / "logs/mojo/2026-10-09-mojo-graph-full.csv",
    "swift": REPO / "logs/swift/2026-10-09-swift-graph-full.csv",
}


def _base(test_data: object) -> str:
    return str(test_data or "").split("@n=")[0]


def _norm(value):
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


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


def _allowed_version(lang: str, name: str) -> str:
    if name in DAGR_NAMES:
        return DAGR_VERSION
    if lang == "python" and name in PYTHON_EXTRA:
        return PYTHON_EXTRA[name]
    raise SystemExit(f"{lang}: serializer {name!r} is not on the graph allow-list")


def _error_rows(csv_path: Path) -> int:
    err_path = csv_path.with_name(csv_path.stem + ".errors.csv")
    if not err_path.is_file():
        return 0
    with err_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.reader(handle))
    return max(0, len(rows) - 1) if rows else 0


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
    payload_path = DATA / f"{lang}_latest.json.gz"
    stats_path = DATA / f"stats_{lang}_latest.json.gz"
    if not payload_path.is_file() or not stats_path.is_file():
        raise SystemExit(f"{lang}: missing published snapshot")
    payload = _load_gz(payload_path)
    stats = _load_gz(stats_path)
    embedded = payload.get("stats")
    if not isinstance(embedded, dict):
        raise SystemExit(f"{lang}: payload has no stats object")

    stats_groups = list(stats.get("groups") or [])
    payload_groups = list(embedded.get("groups") or [])
    fresh, meta = _analyze(lang, csv_path)
    new_groups = _validate_fresh(lang, fresh, stats_groups)
    stats_keep, stats_old = _split(stats_groups)
    payload_keep, payload_old = _split(payload_groups)
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
    embedded["groups"] = payload_keep + copy.deepcopy(new_groups)
    embedded["graph_splice"] = copy.deepcopy(note)
    payload["graph_splice"] = copy.deepcopy(note)
    if _counts(stats["groups"], SUITE_TYPES) != before_suite:
        raise SystemExit(f"{lang}: suite counts changed")
    if _counts(stats["groups"], COLUMNAR_TYPES) != before_columnar:
        raise SystemExit(f"{lang}: columnar counts changed")
    if stats.get("dagr_splice") != dagr_note or stats.get("columnar_splice") != columnar_note:
        raise SystemExit(f"{lang}: an existing splice note changed")
    if len(stats_old) != len(payload_old):
        raise SystemExit(f"{lang}: stats/payload graph groups diverged before splice")
    _write_gz(stats_path, stats)
    _write_gz(payload_path, payload)
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
