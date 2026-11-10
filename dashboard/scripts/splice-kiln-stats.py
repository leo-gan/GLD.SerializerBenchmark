#!/usr/bin/env python3
"""Append gld-kiln suite and tensor groups to the published dashboard snapshots."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from snapshot_io import write_json_gz
from splice_rows import (
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

NAME = "gld-kiln"
MIN_REPS = 100
CSHARP_SIZE = {"tensor": 5_592_424, "tensor_view": 5_592_424, "prompt": 32_796, "shard": 2_448_080, "request": 32_832}
WIRE_SIZE = {"tensor": 4_194_316, "tensor_view": 4_194_316, "prompt": 24_596, "shard": 1_836_060, "request": 24_623}
RUNS = {
    "c": {"suite": "logs/c/2026-10-21-kiln-c-suite.csv", "tensor": "logs/c/2026-10-21-kiln-c-tensor.csv"},
    "cpp": {"suite": "logs/cpp/2026-10-21-kiln-cpp-suite.csv", "tensor": "logs/cpp/2026-10-21-kiln-cpp-tensor.csv"},
    "csharp": {"suite": "logs/csharp/2026-10-19-222030.csv", "tensor": "logs/csharp/2026-10-19-223813.csv"},
    "go": {"suite": "logs/go/2026-10-21-kiln-go-suite.csv", "tensor": "logs/go/2026-10-21-kiln-go-tensor.csv"},
    "java": {"suite": "logs/java/2026-10-21-kiln-suite-pin.csv", "tensor": "logs/java/2026-10-21-kiln-tensor-hot.csv"},
    "javascript": {"suite": "logs/javascript/2026-10-20-191908.csv", "tensor": "logs/javascript/2026-10-20-191910.csv"},
    "mojo": {"suite": "logs/mojo/2026-10-20-192824.csv", "tensor": "logs/mojo/2026-10-20-192855.csv"},
    "python": {"suite": "logs/python/2026-10-20-191915.csv", "tensor": "logs/python/2026-10-20-193042.csv"},
    "rust": {"suite": "logs/rust/2026-10-20-191702.csv", "tensor": "logs/rust/2026-10-20-191723.csv"},
    "swift": {"suite": "logs/swift/2026-10-21-kiln-swift-suite.csv", "tensor": "logs/swift/2026-10-21-kiln-swift-tensor.csv"},
    "zig": {"suite": "logs/zig/2026-10-21-kiln-zig-suite.csv", "tensor": "logs/zig/2026-10-21-kiln-zig-tensor.csv"},
}


def _census(groups: list) -> dict[tuple, int]:
    out: dict[tuple, int] = {}
    for g in groups:
        if str(g.get("serializer") or "") != NAME:
            key = (str(g.get("serializer") or ""), _base(g.get("test_data")), _norm(g.get("data_type_instance_count")))
            out[key] = out.get(key, 0) + 1
    return out


def _check_sizes(lang: str, csv_path: Path, kind: str) -> None:
    if kind != "tensor":
        return
    expected = CSHARP_SIZE if lang == "csharp" else WIRE_SIZE
    with csv_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    found: dict[str, set[str]] = {}
    for row in rows:
        found.setdefault(row.get("TestDataName") or "", set()).add(row.get("Size") or "")
    for type_id, size in expected.items():
        if found.get(type_id) != {str(size)}:
            raise SystemExit(f"{csv_path}: {type_id} size {found.get(type_id)} != {size}")


def _analyze(lang: str, csv_path: Path, kind: str) -> tuple[list, dict]:
    _check_sizes(lang, csv_path, kind)
    records, reps = validate_csv_records(csv_path, lang, MIN_REPS)
    allowed = SUITE_TYPES if kind == "suite" else TENSOR_TYPES
    want_n = {1, 100} if kind == "suite" else {1}
    if (
        {str(r.get("SerializerName") or "") for r in records} != {NAME}
        or {_base(r.get("TestDataName")) for r in records} != set(allowed)
        or {_norm(r.get("DataTypeInstanceCount")) for r in records} != want_n
        or {str(r.get("SerializerVersion") or "").strip() for r in records} != {"0.2.0"}
    ):
        raise SystemExit(f"{csv_path}: invalid kiln rows")
    fresh = export_stats(records, lang)
    groups = list(fresh.get("groups") or [])
    for group in groups:
        for metrics in (group.get("variants") or {}).values():
            if isinstance(metrics, dict):
                for key in [k for k in metrics if k == "fastest_in_group" or str(k).startswith("effect_vs_fastest")]:
                    metrics.pop(key, None)
    return groups, {"rows": len(records), "reps": reps, "version": "0.2.0"}


def _validate(lang: str, groups: list, published: list, kind: str) -> None:
    allowed = set(SUITE_TYPES if kind == "suite" else TENSOR_TYPES)
    want_n = {1, 100} if kind == "suite" else {1}
    if not published:
        raise SystemExit(f"{lang}: published snapshot has no groups")
    expected_policies = set((published[0].get("variants") or {}))
    cells = set()
    for group in groups:
        validate_group_variants(lang, group, expected_policies, MIN_REPS)
        type_id = _base(group.get("test_data"))
        n = _norm(group.get("data_type_instance_count"))
        if (
            group.get("serializer") != NAME
            or group.get("standard") != "kiln"
            or type_id not in allowed
            or group.get("data_set") != ("suite" if kind == "suite" else "tensor")
            or str(group.get("serializer_version") or "") != "0.2.0"
            or n not in want_n
        ):
            raise SystemExit(f"{lang}: invalid kiln group {type_id}")
        cell = (type_id, n)
        if cell in cells:
            raise SystemExit(f"{lang}: duplicate {cell}")
        cells.add(cell)
    if cells != {(t, n) for t in allowed for n in want_n}:
        raise SystemExit(f"{lang}: {kind} cells mismatch")


def splice_language(lang: str, *, dry_run: bool) -> None:
    paths = RUNS[lang]
    suite_csv, tensor_csv = (REPO / paths["suite"]).resolve(), (REPO / paths["tensor"]).resolve()
    for path in (suite_csv, tensor_csv):
        if not path.is_file():
            raise SystemExit(f"CSV not found: {path}")
    stats_path, stats, published = load_published_stats(lang)
    suite_groups, suite_meta = _analyze(lang, suite_csv, "suite")
    tensor_groups, tensor_meta = _analyze(lang, tensor_csv, "tensor")
    _validate(lang, suite_groups, published, "suite")
    _validate(lang, tensor_groups, published, "tensor")
    new_groups = suite_groups + tensor_groups
    before = _census(published)
    stats_keep = [g for g in published if str(g.get("serializer") or "") != NAME]
    replaced = len(published) - len(stats_keep)
    print(f"{lang}: suite {suite_meta['rows']} rows, tensor {tensor_meta['rows']} rows, {len(new_groups)} groups, replace {replaced}")
    if dry_run:
        return
    stats["groups"] = stats_keep + new_groups
    stats["kiln_splice"] = {
        "suite_csv": str(suite_csv.relative_to(REPO)),
        "tensor_csv": str(tensor_csv.relative_to(REPO)),
        "analyzed_at": now_iso(),
        "suite_rows": suite_meta["rows"],
        "tensor_rows": tensor_meta["rows"],
        "reps": MIN_REPS,
        "serializer": NAME,
        "version": "0.2.0",
        "groups_added": len(new_groups),
        "groups_replaced": replaced,
        "note": (
            "gld-kiln groups were measured in separate full-mode runs "
            "(suite at N=1 and N=100, tensor at N=1, 100 repetitions) and appended. "
            "Other serializers were not recomputed."
        ),
    }
    if _census(stats["groups"]) != before:
        raise SystemExit(f"{lang}: other serializers changed")
    write_json_gz(stats_path, stats)
    print(f"{lang}: wrote {len(new_groups)} gld-kiln groups")


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
