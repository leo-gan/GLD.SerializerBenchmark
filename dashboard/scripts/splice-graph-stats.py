#!/usr/bin/env python3
"""Append graph.yaml groups onto the published dashboard snapshots."""

from __future__ import annotations

import argparse
import copy
from pathlib import Path

from snapshot_io import write_json_gz
from splice_rows import (
    ALLOWED_STREAM_MODES,
    COLUMNAR_TYPES,
    DAGR_VERSION,
    GRAPH_TYPES,
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

DAGR_NAMES = ("dagr-regular", "dagr-frozen")
PYTHON_EXTRA = {"pickle": "python-3.14.0", "cloudpickle": "3.1.2"}
INSTANCE_COUNTS = (1, 100)
MIN_REPS = 100
DEFAULT_CSVS = {
    lang: REPO / f"logs/{lang}/2026-10-19-{lang}-graph-full.csv"
    for lang in ("python", "cpp", "rust", "go", "javascript", "mojo", "swift")
}


def _allowed_version(lang: str, name: str) -> str:
    if name in DAGR_NAMES:
        return DAGR_VERSION
    if lang == "python" and name in PYTHON_EXTRA:
        return PYTHON_EXTRA[name]
    raise SystemExit(f"{lang}: serializer {name!r} is not on the graph allow-list")


def _analyze(lang: str, csv_path: Path) -> tuple[dict, dict]:
    records, reps = validate_csv_records(csv_path, lang, MIN_REPS)
    indexes: dict[tuple, set[int]] = {}
    for row in records:
        name = str(row.get("SerializerName") or "")
        version = _allowed_version(lang, name)
        if str(row.get("SerializerVersion") or "") != version:
            raise SystemExit(f"{csv_path}: {name} version {row.get('SerializerVersion')!r} != {version}")
        type_id = _base(row.get("TestDataName"))
        count = _norm(row.get("DataTypeInstanceCount"))
        if type_id not in GRAPH_TYPES or count not in INSTANCE_COUNTS or str(row.get("StringOrStream") or "") != "bytes":
            raise SystemExit(f"{csv_path}: invalid graph row {name} {type_id} n={count}")
        if str(row.get("StreamMode") or "").strip() not in ALLOWED_STREAM_MODES:
            raise SystemExit(f"{csv_path}: unexpected StreamMode {row.get('StreamMode')!r}")
        indexes.setdefault((name, count), set()).add(int(row.get("RepetitionIndex") or 0))
    names = {name for name, _ in indexes}
    if any(name not in names for name in DAGR_NAMES):
        raise SystemExit(f"{csv_path}: missing Dagr rows")
    for key, seen in indexes.items():
        if seen != set(range(MIN_REPS)):
            raise SystemExit(f"{csv_path}: {key} repetition indexes are not 0..{MIN_REPS - 1}")
    return export_stats(records, lang), {"reps": reps, "serializers": sorted(names), "rows": len(records)}


def _validate_fresh(lang: str, fresh: dict, published_groups: list) -> list:
    groups = list(fresh.get("groups") or [])
    if not published_groups:
        raise SystemExit(f"{lang}: published snapshot has no groups to append to")
    expected_policies = set((published_groups[0].get("variants") or {}))
    cells = set()
    for group in groups:
        validate_group_variants(lang, group, expected_policies, MIN_REPS)
        name = str(group.get("serializer") or "")
        count = _norm(group.get("data_type_instance_count"))
        if (
            _base(group.get("test_data")) != "graph"
            or group.get("data_set") != "graph"
            or group.get("standard") != "custom"
            or str(group.get("serializer_version") or "") != _allowed_version(lang, name)
        ):
            raise SystemExit(f"{lang}: invalid graph group {name}")
        cell = (name, count)
        if cell in cells:
            raise SystemExit(f"{lang}: duplicate group {cell}")
        cells.add(cell)
    if not all((name, count) in cells for name in DAGR_NAMES for count in INSTANCE_COUNTS):
        raise SystemExit(f"{lang}: Dagr graph cells are incomplete: {sorted(cells)}")
    return groups


def splice_language(lang: str, csv_path: Path, *, dry_run: bool) -> None:
    stats_path, stats, stats_groups = load_published_stats(lang)
    fresh, meta = _analyze(lang, csv_path)
    new_groups = _validate_fresh(lang, fresh, stats_groups)
    stats_keep = [g for g in stats_groups if _base(g.get("test_data")) != "graph"]
    replaced = len(stats_groups) - len(stats_keep)
    before_suite = _counts(stats_keep, SUITE_TYPES)
    before_columnar = _counts(stats_keep, COLUMNAR_TYPES)
    print(f"{lang}: {meta['rows']} rows, {len(new_groups)} groups, replace {replaced}")
    if dry_run:
        return
    dagr_note = copy.deepcopy(stats.get("dagr_splice"))
    columnar_note = copy.deepcopy(stats.get("columnar_splice"))
    stats["groups"] = stats_keep + new_groups
    stats["graph_splice"] = {
        "source_csv": str(csv_path.relative_to(REPO)),
        "run_config": "config/library/graph.yaml",
        "analyzed_at": now_iso(),
        **meta,
        "groups_added": len(new_groups),
        "groups_replaced": replaced,
        "note": (
            "Graph groups were measured in a separate full-mode run "
            "(config/library/graph.yaml, 100 repetitions) and appended. "
            "Existing suite and columnar groups were not recomputed."
        ),
    }
    if _counts(stats["groups"], SUITE_TYPES) != before_suite or _counts(stats["groups"], COLUMNAR_TYPES) != before_columnar:
        raise SystemExit(f"{lang}: suite or columnar counts changed")
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
