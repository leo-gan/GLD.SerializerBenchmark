#!/usr/bin/env python3
"""Replace columnar.yaml groups on the published dashboard snapshots."""

from __future__ import annotations

import argparse
from pathlib import Path

from snapshot_io import write_json_gz
from splice_rows import (
    COLUMNAR_TYPES,
    REPO,
    SUITE_TYPES,
    base_type as _base,
    count_bases as _counts,
    export_stats,
    load_published_stats,
    load_records,
    now_iso,
)
from benchmark_analysis.serializer_data_sets import allow_list

MIN_REPS = 50
DEFAULT_CSVS = {
    lang: REPO / f"logs/{lang}/2026-10-19-{lang}-columnar-full.csv"
    for lang in ("python", "cpp", "csharp", "go", "java", "rust", "javascript", "kotlin", "mojo")
}
CORE = ("python", "cpp", "csharp", "go", "java", "rust")


def _analyze(lang: str, csv_path: Path) -> tuple[dict, dict]:
    records = load_records(csv_path, lang)
    reps = sorted({int(row.get("Repetitions") or 0) for row in records})
    if not reps or min(reps) < MIN_REPS:
        raise SystemExit(f"{csv_path}: repetitions {reps} are below {MIN_REPS}; refusing a smoke snapshot")
    bases = {_base(row.get("TestDataName")) for row in records}
    foreign = sorted(base for base in bases if base not in COLUMNAR_TYPES)
    if foreign:
        raise SystemExit(f"{csv_path}: refusing non-columnar types {foreign}")
    fresh = export_stats(records, lang)
    meta = {
        "reps": reps,
        "serializers": sorted({str(row.get("SerializerName") or "") for row in records if row.get("SerializerName")}),
        "types": sorted(bases),
        "rows": len(records),
    }
    return fresh, meta


def splice_language(lang: str, csv_path: Path) -> None:
    stats_path, stats, before_groups = load_published_stats(lang)
    before_counts = _counts(before_groups, SUITE_TYPES)
    fresh, meta = _analyze(lang, csv_path)
    expected = set(allow_list(lang, "columnar"))
    got = set(meta["serializers"])
    if got != expected:
        raise SystemExit(f"{lang}: columnar serializers {sorted(got)} != map {sorted(expected)}")

    added = []
    for group in fresh.get("groups") or []:
        if _base(group.get("test_data")) not in COLUMNAR_TYPES:
            raise SystemExit(f"{lang}: analysis emitted non-columnar group {group.get('serializer')} {group.get('test_data')}")
        group.setdefault("language", lang)
        if group.get("language") != lang:
            raise SystemExit(f"{lang}: analysis group language is {group.get('language')}")
        added.append(group)
    if not added:
        raise SystemExit(f"{lang}: analysis produced no columnar groups")

    kept = [g for g in before_groups if _base(g.get("test_data")) not in COLUMNAR_TYPES]
    replaced = len(before_groups) - len(kept)
    stats["groups"] = kept + added
    after_counts = _counts(stats["groups"], SUITE_TYPES)
    if after_counts != before_counts:
        raise SystemExit(f"{lang}: row-type counts changed {before_counts} -> {after_counts}")

    stats["columnar_splice"] = {
        "source_csv": str(csv_path.relative_to(REPO)),
        "run_config": "config/library/columnar.yaml",
        "analyzed_at": now_iso(),
        "rows": meta["rows"],
        "reps": meta["reps"],
        "types": meta["types"],
        "serializers": meta["serializers"],
        "groups_added": len(added),
        "groups_replaced": replaced,
        "row_group_counts": after_counts,
        "note": (
            "Columnar groups were measured in a separate columnar.yaml run and replaced. "
            "Groups for message, document, telemetry, strings, and event are the previously "
            "published snapshot and were not recomputed."
        ),
    }
    write_json_gz(stats_path, stats)
    print(f"{lang}: replaced {replaced} columnar groups with {len(added)}, row counts {after_counts}, serializers {meta['serializers']}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", action="append", default=[])
    parser.add_argument("--csv", default="")
    args = parser.parse_args(argv)
    if args.csv and len(args.language) != 1:
        raise SystemExit("--csv requires exactly one --language")
    if args.language:
        missing = [lang for lang in args.language if lang not in DEFAULT_CSVS and not args.csv]
        if missing:
            raise SystemExit(f"unknown language(s) {missing}; known: {sorted(DEFAULT_CSVS)}")
        jobs = []
        for lang in args.language:
            path = Path(args.csv) if args.csv else DEFAULT_CSVS[lang]
            if not path.is_file():
                raise SystemExit(f"{lang}: CSV not found: {path}")
            jobs.append((lang, path if path.is_absolute() else REPO / path))
    else:
        missing_core = [lang for lang in CORE if not DEFAULT_CSVS[lang].is_file()]
        if missing_core:
            raise SystemExit(f"missing core columnar CSV(s): {missing_core}")
        jobs = [(lang, path) for lang, path in DEFAULT_CSVS.items() if path.is_file()]
    for lang, path in jobs:
        splice_language(lang, path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
