#!/usr/bin/env python3
"""Append tensor.yaml groups onto the published snapshot."""

from __future__ import annotations

import argparse
from pathlib import Path

from snapshot_io import write_json_gz
from splice_rows import (
    ARRAY_TYPES,
    REPO,
    SUITE_TYPES,
    TENSOR_TYPES,
    as_whole as _norm,
    base_type as _base,
    count_bases as _counts,
    export_stats,
    load_published_stats,
    now_iso,
    validate_csv_records,
    validate_group_variants,
)

LANGUAGE = "python"
MATRIX = {"arrow-ipc": TENSOR_TYPES, "flatbuffers": TENSOR_TYPES}
STANDARDS = {"arrow-ipc": "arrow", "flatbuffers": "flatbuffers"}
REMOVED: tuple[str, ...] = ("h5py", "netCDF4", "adios2", "protobuf")
MIN_REPS = 100


def select_language(language: str) -> None:
    global LANGUAGE, MATRIX, STANDARDS, REMOVED
    LANGUAGE = language
    if language in ("mojo", "csharp"):
        MATRIX = {"gld-kiln": TENSOR_TYPES}
        STANDARDS = {"gld-kiln": "kiln"}
        REMOVED = ()
        return
    if language != "python":
        raise SystemExit(f"unsupported language {language}")


def _analyze(csv_path: Path) -> tuple[dict, dict]:
    records, reps = validate_csv_records(csv_path, LANGUAGE, MIN_REPS)
    versions: dict[str, str] = {}
    indexes: dict[tuple, set[int]] = {}
    for row in records:
        name = str(row.get("SerializerName") or "")
        if name not in MATRIX:
            raise SystemExit(f"{csv_path}: unexpected serializer {name!r}")
        version = str(row.get("SerializerVersion") or "").strip()
        if not version or versions.setdefault(name, version) != version:
            raise SystemExit(f"{csv_path}: invalid or changing version for {name}")
        type_id = _base(row.get("TestDataName"))
        if (
            type_id not in MATRIX[name]
            or _norm(row.get("DataTypeInstanceCount")) != 1
            or str(row.get("StringOrStream") or "") != "bytes"
            or str(row.get("StreamMode") or "").strip() not in ("", "adapted")
        ):
            raise SystemExit(f"{csv_path}: invalid tensor row {name} {type_id}")
        indexes.setdefault((name, type_id), set()).add(int(row.get("RepetitionIndex") or 0))
    for name, type_ids in MATRIX.items():
        for type_id in type_ids:
            if indexes.get((name, type_id)) != set(range(MIN_REPS)):
                raise SystemExit(f"{csv_path}: {(name, type_id)} repetition indexes are not 0..{MIN_REPS - 1}")
    return export_stats(records, LANGUAGE), {
        "reps": reps,
        "serializers": sorted(versions),
        "versions": versions,
        "rows": len(records),
    }


def _validate_fresh(fresh: dict, published_groups: list) -> list:
    groups = list(fresh.get("groups") or [])
    if not published_groups:
        raise SystemExit(f"{LANGUAGE}: published snapshot has no groups to append to")
    expected_policies = set((published_groups[0].get("variants") or {}))
    cells = set()
    for group in groups:
        validate_group_variants(LANGUAGE, group, expected_policies, MIN_REPS)
        name = str(group.get("serializer") or "")
        type_id = _base(group.get("test_data"))
        if (
            name not in MATRIX
            or type_id not in MATRIX[name]
            or group.get("data_set") != "tensor"
            or group.get("standard") != STANDARDS[name]
            or _norm(group.get("data_type_instance_count")) != 1
        ):
            raise SystemExit(f"{LANGUAGE}: unexpected tensor cell {name} {type_id}")
        cell = (name, type_id)
        if cell in cells:
            raise SystemExit(f"{LANGUAGE}: duplicate group {cell}")
        cells.add(cell)
    expected = {(name, type_id) for name, type_ids in MATRIX.items() for type_id in type_ids}
    if cells != expected:
        raise SystemExit(f"{LANGUAGE}: tensor cells {sorted(cells)} != {sorted(expected)}")
    return groups


def splice(csv_path: Path, *, dry_run: bool) -> None:
    stats_path, stats, published = load_published_stats(LANGUAGE)
    fresh, meta = _analyze(csv_path)
    new_groups = _validate_fresh(fresh, published)
    stats_keep = [
        g
        for g in published
        if not (_base(g.get("test_data")) in TENSOR_TYPES and str(g.get("serializer") or "") in (*MATRIX, *REMOVED))
    ]
    replaced = len(published) - len(stats_keep)
    before_suite = _counts(stats_keep, SUITE_TYPES)
    before_array = _counts(stats_keep, ARRAY_TYPES)
    print(f"{LANGUAGE}: {meta['rows']} rows, {len(new_groups)} groups, replace {replaced}")
    if dry_run:
        return
    stats["groups"] = stats_keep + new_groups
    stats["tensor_splice"] = {
        "source_csv": str(csv_path.relative_to(REPO)),
        "run_config": "config/library/tensor.yaml",
        "analyzed_at": now_iso(),
        **meta,
        "groups_added": len(new_groups),
        "groups_replaced": replaced,
        "note": (
            "Tensor groups were measured in a separate full-mode run "
            "(config/library/tensor.yaml, 100 repetitions) and appended. "
            "Suite, columnar, graph, and array groups were not recomputed."
        ),
    }
    if _counts(stats["groups"], SUITE_TYPES) != before_suite or _counts(stats["groups"], ARRAY_TYPES) != before_array:
        raise SystemExit(f"{LANGUAGE}: suite or array counts changed")
    write_json_gz(stats_path, stats)
    print(f"{LANGUAGE}: wrote {len(new_groups)} tensor groups")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", default="python", choices=("python", "mojo", "csharp"))
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    select_language(args.language)
    csv_path = (args.csv if args.csv.is_absolute() else REPO / args.csv).resolve()
    if not csv_path.is_file():
        raise SystemExit(f"CSV not found: {csv_path}")
    splice(csv_path, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
