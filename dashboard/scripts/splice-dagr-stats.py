#!/usr/bin/env python3
"""Append Dagr suite groups onto the published dashboard snapshots."""

from __future__ import annotations

import argparse
import copy
from pathlib import Path

from snapshot_io import load_json_gz, write_json_gz
from splice_rows import (
    ALLOWED_STREAM_MODES,
    COLUMNAR_TYPES,
    DAGR_SERIALIZERS,
    DAGR_VERSION,
    REPO,
    SUITE_TYPES,
    as_whole as _norm,
    base_type as _base,
    count_bases as _counts,
    export_stats,
    load_published_stats,
    now_iso,
    validate_csv_records,
    validate_group_variants,
)

DAGR_SET = set(DAGR_SERIALIZERS)
SUITE_SET = set(SUITE_TYPES)
INSTANCE_COUNTS = (1, 100)
MIN_REPS = 100
EXPECTED_CELLS = {
    (name, type_id, count)
    for name in DAGR_SERIALIZERS
    for type_id in SUITE_TYPES
    for count in INSTANCE_COUNTS
}
DEFAULT_CSVS = {
    lang: REPO / f"logs/{lang}/2026-10-08-{lang}-dagr-full.csv"
    for lang in ("python", "cpp", "rust", "go", "javascript", "mojo", "swift")
}


def _cell(group: dict) -> tuple:
    return (
        str(group.get("serializer") or ""),
        _base(group.get("test_data")),
        _norm(group.get("data_type_instance_count")),
    )


def _analyze(lang: str, csv_path: Path) -> tuple[dict, dict]:
    records, reps = validate_csv_records(csv_path, lang, MIN_REPS)
    indexes: dict[tuple, set[int]] = {}
    stream_modes: dict[tuple, set[str]] = {}
    for row in records:
        name = str(row.get("SerializerName") or "")
        type_id = _base(row.get("TestDataName"))
        count = _norm(row.get("DataTypeInstanceCount"))
        stream_mode = str(row.get("StreamMode") or "").strip()
        if (
            name not in DAGR_SET
            or type_id not in SUITE_SET
            or count not in INSTANCE_COUNTS
            or str(row.get("StringOrStream") or "") != "bytes"
            or str(row.get("SerializerVersion") or "") != DAGR_VERSION
            or stream_mode not in ALLOWED_STREAM_MODES
        ):
            raise SystemExit(f"{csv_path}: invalid Dagr row {name} {type_id} n={count}")
        key = (name, type_id, count)
        indexes.setdefault(key, set()).add(int(row.get("RepetitionIndex") or 0))
        stream_modes.setdefault(key, set()).add(stream_mode)
    if set(indexes) != EXPECTED_CELLS:
        raise SystemExit(f"{csv_path}: cells mismatch")
    for key, seen in indexes.items():
        if seen != set(range(MIN_REPS)) or len(stream_modes.get(key) or {""}) != 1:
            raise SystemExit(f"{csv_path}: {key} repetition or StreamMode check failed")
    return export_stats(records, lang), {
        "reps": reps,
        "serializers": sorted({str(r.get("SerializerName") or "") for r in records}),
        "types": sorted({_base(r.get("TestDataName")) for r in records}),
        "rows": len(records),
        "version": DAGR_VERSION,
    }


def _validate_fresh(lang: str, fresh: dict, published_groups: list) -> list:
    groups = list(fresh.get("groups") or [])
    if len(groups) != len(EXPECTED_CELLS) or not published_groups:
        raise SystemExit(f"{lang}: invalid group count or empty published snapshot")
    expected_policies = set((published_groups[0].get("variants") or {}))
    cells = set()
    for group in groups:
        validate_group_variants(
            lang,
            group,
            expected_policies,
            MIN_REPS,
            require_warmup_1=True,
            require_positive_size_and_time=True,
        )
        name = str(group.get("serializer") or "")
        count = _norm(group.get("data_type_instance_count"))
        if (
            name not in DAGR_SET
            or group.get("test_data") not in SUITE_SET
            or group.get("standard") != "custom"
            or group.get("data_set") != "suite"
            or group.get("io_parent") != "single"
            or group.get("optional") not in ([], None)
            or str(group.get("StreamMode") or "") not in ALLOWED_STREAM_MODES
            or str(group.get("serializer_version") or "") != DAGR_VERSION
            or not str(group.get("type_config_hash") or "")
            or count not in INSTANCE_COUNTS
        ):
            raise SystemExit(f"{lang}: invalid Dagr group {name}")
        cell = (name, str(group.get("test_data")), count)
        if cell in cells:
            raise SystemExit(f"{lang}: duplicate group {cell}")
        cells.add(cell)
    if cells != EXPECTED_CELLS:
        raise SystemExit(f"{lang}: group cells do not match the matrix")
    return groups


def splice_language(lang: str, csv_path: Path, *, dry_run: bool) -> None:
    stats_path, stats, stats_groups = load_published_stats(lang)
    for index, group in enumerate(stats_groups):
        if not group.get("standard") or not group.get("data_set"):
            raise SystemExit(f"{lang}: stats group {index} {group.get('serializer')} has no standard")
    fresh, meta = _analyze(lang, csv_path)
    new_groups = _validate_fresh(lang, fresh, stats_groups)
    stats_keep, stats_old = [], []
    for group in stats_groups:
        name = str(group.get("serializer") or "")
        if name.lower().startswith("dagr") and name not in DAGR_SET:
            raise SystemExit(f"{lang}: refusing to touch unexpected serializer {name!r}")
        (stats_old if name in DAGR_SET else stats_keep).append(group)
    before_columnar = _counts(stats_keep, COLUMNAR_TYPES)
    before_suite = _counts(stats_keep, SUITE_TYPES)
    print(f"{lang}: {meta['rows']} rows, {len(new_groups)} groups, replace {len(stats_old)}, version {meta['version']}")
    if dry_run:
        return
    columnar_stats = copy.deepcopy(stats.get("columnar_splice"))
    stats["groups"] = stats_keep + new_groups
    stats["dagr_splice"] = {
        "source_csv": str(csv_path.relative_to(REPO)),
        "run_config": "config/library/default.yaml",
        "analyzed_at": now_iso(),
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
    if (
        _counts(stats["groups"], COLUMNAR_TYPES) != before_columnar
        or stats.get("columnar_splice") != columnar_stats
        or {_cell(g) for g in stats["groups"] if g.get("serializer") in DAGR_SET} != EXPECTED_CELLS
    ):
        raise SystemExit(f"{lang}: post-splice validation failed")
    write_json_gz(stats_path, stats)
    if load_json_gz(stats_path).get("groups") != stats["groups"]:
        raise SystemExit(f"{lang}: reread stats groups do not match the write")
    print(f"{lang}: wrote {len(new_groups)} Dagr groups into {stats_path.name}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", action="append", required=True)
    parser.add_argument("--csv", default="")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    if args.csv and len(args.language) != 1:
        raise SystemExit("--csv requires exactly one --language")
    for lang in args.language:
        if lang not in DEFAULT_CSVS and not args.csv:
            raise SystemExit(f"unknown language {lang}; known: {sorted(DEFAULT_CSVS)}")
        path = Path(args.csv) if args.csv else DEFAULT_CSVS[lang]
        if not path.is_file():
            raise SystemExit(f"{lang}: CSV not found: {path}")
        splice_language(lang, path if path.is_absolute() else REPO / path, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
