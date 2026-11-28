#!/usr/bin/env python3
"""Append gld-kiln-asm groups to the published dashboard snapshots.

Each language is measured on only the data sets listed for gld-kiln-asm in
config/benchmark_config.yaml. The CSVs are full-mode runs (100 repetitions)
with a non-timestamp stem, so sync-data.py does not treat them as the latest
suite snapshot. Other serializers in the snapshot are left unchanged.
"""

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
    export_stats,
    load_published_stats,
    now_iso,
    validate_csv_records,
    validate_group_variants,
)

NAME = "gld-kiln-asm"
VERSION = "0.2.0"
MIN_REPS = 100

# Data sets from serializer_data_sets.gld-kiln-asm. PHP has no adapter.
RUNS: dict[str, tuple[str, ...]] = {
    "c": ("suite", "columnar", "array", "tensor"),
    "cpp": ("suite", "columnar", "array", "tensor"),
    "csharp": ("suite", "columnar", "array", "tensor"),
    "fortran": ("suite", "array"),
    "go": ("suite", "columnar", "tensor"),
    "java": ("suite", "columnar", "tensor"),
    "javascript": ("suite", "columnar", "array", "tensor"),
    "kotlin": ("suite", "columnar"),
    "mojo": ("suite", "columnar", "array", "tensor"),
    "python": ("suite", "columnar", "array", "tensor"),
    "rust": ("suite", "columnar", "array", "tensor"),
    "swift": ("suite", "tensor"),
    "zig": ("suite", "tensor"),
}

_COLUMNAR_N = {
    "table": (1, 100, 10000),
    "table_project": (1, 100, 10000),
    "nested_table": (1, 100),
    "signal": (1, 100),
}


def _cells(kind: str) -> set[tuple[str, int]]:
    if kind == "suite":
        return {(t, n) for t in SUITE_TYPES for n in (1, 100)}
    if kind == "columnar":
        return {(t, n) for t, counts in _COLUMNAR_N.items() for n in counts}
    if kind == "array":
        return {(t, 1) for t in ARRAY_TYPES}
    if kind == "tensor":
        return {(t, 1) for t in TENSOR_TYPES}
    raise SystemExit(f"unknown data set {kind}")


def _csv(lang: str, kind: str) -> Path:
    return REPO / "logs" / lang / f"kiln-asm-{kind}.csv"


def _census(groups: list) -> dict[tuple, int]:
    out: dict[tuple, int] = {}
    for group in groups:
        if str(group.get("serializer") or "") == NAME:
            continue
        key = (
            str(group.get("serializer") or ""),
            _base(group.get("test_data")),
            _norm(group.get("data_type_instance_count")),
            str(group.get("io_mode") or group.get("mode") or ""),
        )
        out[key] = out.get(key, 0) + 1
    return out


def _analyze(lang: str, csv_path: Path, kind: str) -> tuple[list, dict]:
    records, reps = validate_csv_records(csv_path, lang, MIN_REPS)
    want = _cells(kind)
    names = {str(r.get("SerializerName") or "") for r in records}
    got = {(_base(r.get("TestDataName")), _norm(r.get("DataTypeInstanceCount"))) for r in records}
    versions = {str(r.get("SerializerVersion") or "").strip() for r in records}
    if names != {NAME} or got != want or versions != {VERSION}:
        raise SystemExit(
            f"{csv_path}: invalid {kind} rows names={names} cells={sorted(got)} versions={versions}"
        )
    fresh = export_stats(records, lang)
    groups = list(fresh.get("groups") or [])
    for group in groups:
        for metrics in (group.get("variants") or {}).values():
            if isinstance(metrics, dict):
                for key in [k for k in metrics if k == "fastest_in_group" or str(k).startswith("effect_vs_fastest")]:
                    metrics.pop(key, None)
    return groups, {"rows": len(records), "reps": reps}


def _validate(lang: str, groups: list, published: list, kind: str) -> None:
    want = _cells(kind)
    if not published:
        raise SystemExit(f"{lang}: published snapshot has no groups")
    expected_policies = set(published[0].get("variants") or {})
    cells = set()
    for group in groups:
        validate_group_variants(lang, group, expected_policies, MIN_REPS)
        type_id = _base(group.get("test_data"))
        n = _norm(group.get("data_type_instance_count"))
        if (
            group.get("serializer") != NAME
            or group.get("standard") != "kiln"
            or group.get("data_set") != kind
            or str(group.get("serializer_version") or "") != VERSION
            or (type_id, n) not in want
        ):
            raise SystemExit(f"{lang}: invalid {kind} group {type_id} n={n} standard={group.get('standard')}")
        cell = (type_id, n)
        if cell in cells:
            raise SystemExit(f"{lang}: duplicate {kind} {cell}")
        cells.add(cell)
    if cells != want:
        raise SystemExit(f"{lang}: {kind} cells {sorted(cells)} != {sorted(want)}")


def splice_language(lang: str, *, dry_run: bool) -> None:
    kinds = RUNS[lang]
    paths = [_csv(lang, kind) for kind in kinds]
    for path in paths:
        if not path.is_file():
            raise SystemExit(f"CSV not found: {path}")
    stats_path, stats, published = load_published_stats(lang)
    new_groups: list = []
    meta: list[str] = []
    for kind, path in zip(kinds, paths):
        groups, info = _analyze(lang, path, kind)
        _validate(lang, groups, published, kind)
        new_groups.extend(groups)
        meta.append(f"{kind} {info['rows']} rows")
    before = _census(published)
    stats_keep = [g for g in published if str(g.get("serializer") or "") != NAME]
    replaced = len(published) - len(stats_keep)
    print(f"{lang}: {', '.join(meta)}; {len(new_groups)} groups, replace {replaced}")
    if dry_run:
        return
    stats["groups"] = stats_keep + new_groups
    stats["kiln_asm_splice"] = {
        "csvs": [str(p.relative_to(REPO)) for p in paths],
        "analyzed_at": now_iso(),
        "reps": MIN_REPS,
        "serializer": NAME,
        "version": VERSION,
        "groups_added": len(new_groups),
        "groups_replaced": replaced,
        "note": (
            "gld-kiln-asm groups were measured in separate full-mode runs "
            "(100 repetitions, seed 42) and appended. Other serializers were not recomputed."
        ),
    }
    if _census(stats["groups"]) != before:
        raise SystemExit(f"{lang}: other serializers changed")
    write_json_gz(stats_path, stats)
    print(f"{lang}: wrote {len(new_groups)} gld-kiln-asm groups")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", action="append", choices=sorted(RUNS))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    for lang in args.language or list(RUNS):
        splice_language(lang, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
