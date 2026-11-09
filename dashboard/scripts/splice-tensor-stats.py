#!/usr/bin/env python3
"""Append tensor.yaml groups onto the published Python snapshot.

The CSV name is not YYYY-MM-DD-HHMMSS, so sync-data.py does not select it.
This script analyzes that full run and appends tensor, tensor_view, prompt,
shard, and request. It replaces previous groups only for those type ids.
Suite, columnar, graph, and array groups stay.
"""

from __future__ import annotations

import argparse
import csv
import sys
from datetime import datetime, timezone
from pathlib import Path

from snapshot_io import load_json_gz, write_json_gz

from splice_rows import (
    load_records,
    refuse_error_rows,
    export_stats,
    as_whole as _norm,
    base_type as _base,
    count_bases as _counts,
    require_finite as _finite,
)

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "analysis" / "src"))


DATA = REPO / "dashboard" / "public" / "data"
LANGUAGE = "python"
TENSOR_TYPES = ("tensor", "tensor_view", "prompt", "shard", "request")
# Every name runs every type. A partial row is not on this data set.
MATRIX = {
    "arrow-ipc": TENSOR_TYPES,
    "flatbuffers": TENSOR_TYPES,
}
STANDARDS = {
    "arrow-ipc": "arrow",
    "flatbuffers": "flatbuffers",
}
# Earlier publish listed these on tensor while they skipped a type.
REMOVED = ("h5py", "netCDF4", "adios2", "protobuf")
SUITE_TYPES = ("message", "document", "telemetry", "strings", "event")
ARRAY_TYPES = ("grid", "grid_window")
MIN_REPS = 100


def _analyze(csv_path: Path) -> tuple[dict, dict]:
    refuse_error_rows(csv_path)
    records = load_records(csv_path, LANGUAGE)
    reps = sorted({int(row.get("Repetitions") or 0) for row in records})
    if reps != [MIN_REPS]:
        raise SystemExit(f"{csv_path}: repetitions {reps}; expected {MIN_REPS}")

    versions: dict[str, str] = {}
    indexes: dict[tuple, set[int]] = {}
    for row in records:
        name = str(row.get("SerializerName") or "")
        if name not in MATRIX:
            raise SystemExit(f"{csv_path}: unexpected serializer {name!r}")
        version = str(row.get("SerializerVersion") or "").strip()
        if not version:
            raise SystemExit(f"{csv_path}: {name} has an empty version")
        previous = versions.setdefault(name, version)
        if previous != version:
            raise SystemExit(f"{csv_path}: {name} version changed from {previous!r} to {version!r}")
        type_id = _base(row.get("TestDataName"))
        if type_id not in MATRIX[name]:
            raise SystemExit(f"{csv_path}: {name} is not measured on {type_id}")
        if _norm(row.get("DataTypeInstanceCount")) != 1:
            raise SystemExit(f"{csv_path}: refusing instance count {row.get('DataTypeInstanceCount')!r}")
        if str(row.get("StringOrStream") or "") != "bytes":
            raise SystemExit(f"{csv_path}: {name} I/O mode {row.get('StringOrStream')!r}")
        stream_mode = str(row.get("StreamMode") or "").strip()
        if stream_mode not in ("", "adapted"):
            raise SystemExit(f"{csv_path}: {name} StreamMode {stream_mode!r}")
        if str(row.get("Language") or "") != LANGUAGE:
            raise SystemExit(f"{csv_path}: row language {row.get('Language')!r}")
        fidelity = row.get("FidelityScore")
        if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
            raise SystemExit(f"{csv_path}: fidelity {fidelity!r} for {name} {type_id}")
        indexes.setdefault((name, type_id), set()).add(int(row.get("RepetitionIndex") or 0))

    for name, type_ids in MATRIX.items():
        for type_id in type_ids:
            if indexes.get((name, type_id)) != set(range(MIN_REPS)):
                raise SystemExit(f"{csv_path}: {(name, type_id)} repetition indexes are not 0..{MIN_REPS - 1}")

    fresh = export_stats(records, LANGUAGE)
    meta = {"reps": reps, "serializers": sorted(versions), "versions": versions, "rows": len(records)}
    return fresh, meta


def _validate_fresh(fresh: dict, published_groups: list) -> list:
    groups = list(fresh.get("groups") or [])
    if not published_groups:
        raise SystemExit("python: published snapshot has no groups to append to")
    expected_policies = set((published_groups[0].get("variants") or {}))
    cells = set()
    for group in groups:
        _finite(group, f"python/{group.get('serializer')}")
        name = str(group.get("serializer") or "")
        type_id = _base(group.get("test_data"))
        if name not in MATRIX or type_id not in MATRIX[name]:
            raise SystemExit(f"python: unexpected cell {name} {type_id}")
        if group.get("language") != LANGUAGE:
            raise SystemExit(f"python: analysis group language is {group.get('language')!r}")
        if group.get("data_set") != "tensor":
            raise SystemExit(f"python: {name} data_set is {group.get('data_set')!r}")
        if group.get("standard") != STANDARDS[name]:
            raise SystemExit(f"python: {name} standard is {group.get('standard')!r}")
        if group.get("mode") != "published":
            raise SystemExit(f"python: {name} mode is {group.get('mode')!r}")
        if _norm(group.get("data_type_instance_count")) != 1:
            raise SystemExit(f"python: {name} instance count {group.get('data_type_instance_count')!r}")
        cell = (name, type_id)
        if cell in cells:
            raise SystemExit(f"python: duplicate group {cell}")
        cells.add(cell)
        variants = group.get("variants") or {}
        if set(variants) != expected_policies:
            raise SystemExit(f"python: {name} policies {sorted(variants)} != {sorted(expected_policies)}")
        for policy, metrics in variants.items():
            fidelity = metrics.get("mean_fidelity")
            if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
                raise SystemExit(f"python: {name} {policy} fidelity {fidelity!r}")
            filt = metrics.get("filter") or {}
            if int(filt.get("runs_raw") or 0) != MIN_REPS:
                raise SystemExit(f"python: {name} {policy} runs_raw {filt.get('runs_raw')!r}")
    expected = {(name, type_id) for name, type_ids in MATRIX.items() for type_id in type_ids}
    if cells != expected:
        raise SystemExit(f"python: tensor cells {sorted(cells)} != {sorted(expected)}")
    return groups


def _split(groups: list) -> tuple[list, list]:
    keep, old = [], []
    for group in groups:
        name = str(group.get("serializer") or "")
        base = _base(group.get("test_data"))
        if base in TENSOR_TYPES and (name in MATRIX or name in REMOVED):
            old.append(group)
        else:
            keep.append(group)
    return keep, old


def select_language(language: str) -> None:
    global LANGUAGE, MATRIX, STANDARDS, REMOVED
    LANGUAGE = language
    if language == "mojo":
        MATRIX = {"gld-kiln": TENSOR_TYPES}
        STANDARDS = {"gld-kiln": "kiln"}
        REMOVED = ()
        return
    if language != "python":
        raise SystemExit(f"unsupported language {language}")


def splice(csv_path: Path, *, dry_run: bool) -> None:
    stats_path = DATA / f"stats_{LANGUAGE}_latest.json.gz"
    stats = load_json_gz(stats_path)
    fresh, meta = _analyze(csv_path)
    new_groups = _validate_fresh(fresh, list(stats.get("groups") or []))
    stats_keep, stats_old = _split(list(stats.get("groups") or []))
    before_suite = _counts(stats_keep, SUITE_TYPES)
    before_array = _counts(stats_keep, ARRAY_TYPES)
    note = {
        "source_csv": str(csv_path.relative_to(REPO)),
        "run_config": "config/library/tensor.yaml",
        "analyzed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "rows": meta["rows"],
        "reps": meta["reps"],
        "serializers": meta["serializers"],
        "versions": meta["versions"],
        "groups_added": len(new_groups),
        "groups_replaced": len(stats_old),
        "note": (
            "Tensor groups were measured in a separate full-mode run "
            "(config/library/tensor.yaml, 100 repetitions) and appended. "
            "Suite, columnar, graph, and array groups were not recomputed."
        ),
    }
    print(f"{LANGUAGE}: {meta['rows']} rows, {len(new_groups)} groups, replace {len(stats_old)}")
    if dry_run:
        print(f"{LANGUAGE}: dry-run, snapshots not written")
        return
    stats["groups"] = stats_keep + new_groups
    stats["tensor_splice"] = note
    if _counts(stats["groups"], SUITE_TYPES) != before_suite:
        raise SystemExit("python: suite counts changed")
    if _counts(stats["groups"], ARRAY_TYPES) != before_array:
        raise SystemExit("python: array counts changed")
    write_json_gz(stats_path, stats)
    print(f"{LANGUAGE}: wrote {len(new_groups)} tensor groups")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", default="python", choices=("python", "mojo"))
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    select_language(args.language)
    csv_path = args.csv if args.csv.is_absolute() else REPO / args.csv
    csv_path = csv_path.resolve()
    if not csv_path.is_file():
        raise SystemExit(f"CSV not found: {csv_path}")
    splice(csv_path, dry_run=args.dry_run)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
