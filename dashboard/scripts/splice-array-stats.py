#!/usr/bin/env python3
"""Append array.yaml groups onto a published language snapshot."""

from __future__ import annotations

import argparse
from pathlib import Path

from snapshot_io import write_json_gz
from splice_rows import (
    ARRAY_TYPES,
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

MIN_REPS = 100
PROFILES = {
    "fortran": (
        ("hdf5-fortran", "netcdf-fortran", "adios2", "gld-arrow"),
        {"hdf5-fortran": "hdf5", "netcdf-fortran": "netcdf", "adios2": "adios2", "gld-arrow": "arrow"},
        {"hdf5-fortran": "bytes", "netcdf-fortran": "stream", "adios2": "stream", "gld-arrow": "bytes"},
    ),
    "python": (("h5py", "netCDF4", "adios2"), {"h5py": "hdf5", "netCDF4": "netcdf", "adios2": "adios2"}, "bytes"),
    "c": (("hdf5",), {"hdf5": "hdf5"}, "bytes"),
    "cpp": (("highfive",), {"highfive": "hdf5"}, "bytes"),
    "rust": (("hdf5-metno",), {"hdf5-metno": "hdf5"}, "bytes"),
    "javascript": (("h5wasm",), {"h5wasm": "hdf5"}, "bytes"),
    "csharp": (("PureHDF",), {"PureHDF": "hdf5"}, "bytes"),
    "mojo": (("gld-hdf5",), {"gld-hdf5": "hdf5"}, "bytes"),
}
LANGUAGE = "fortran"
ARRAY_NAMES, STANDARDS, MODES = PROFILES["fortran"]


def _select_language(language: str) -> None:
    global ARRAY_NAMES, STANDARDS, MODES, LANGUAGE
    if language not in PROFILES:
        raise SystemExit(f"unsupported language {language}")
    LANGUAGE = language
    names, standards, mode = PROFILES[language]
    ARRAY_NAMES = names
    STANDARDS = standards
    MODES = mode if isinstance(mode, dict) else {name: mode for name in names}


def _analyze(csv_path: Path) -> tuple[dict, dict]:
    records, reps = validate_csv_records(csv_path, LANGUAGE, MIN_REPS)
    versions: dict[str, str] = {}
    indexes: dict[tuple, set[int]] = {}
    for row in records:
        name = str(row.get("SerializerName") or "")
        if name not in STANDARDS:
            raise SystemExit(f"{csv_path}: unexpected serializer {name!r}")
        version = str(row.get("SerializerVersion") or "").strip()
        if not version or versions.setdefault(name, version) != version:
            raise SystemExit(f"{csv_path}: invalid or changing version for {name}")
        type_id = _base(row.get("TestDataName"))
        if type_id not in ARRAY_TYPES or _norm(row.get("DataTypeInstanceCount")) != 1:
            raise SystemExit(f"{csv_path}: invalid type or count for {name} {type_id}")
        mode = str(row.get("StringOrStream") or "")
        if mode != MODES[name] and not (MODES[name] == "bytes" and mode == "string"):
            raise SystemExit(f"{csv_path}: {name} I/O mode {mode!r}")
        stream_mode = str(row.get("StreamMode") or "").strip()
        if (MODES[name] == "stream" and stream_mode != "native") or (
            MODES[name] == "bytes" and stream_mode not in ("", "adapted")
        ):
            raise SystemExit(f"{csv_path}: {name} StreamMode {row.get('StreamMode')!r}")
        indexes.setdefault((name, type_id), set()).add(int(row.get("RepetitionIndex") or 0))
    for name in ARRAY_NAMES:
        for type_id in ARRAY_TYPES:
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
            name not in STANDARDS
            or type_id not in ARRAY_TYPES
            or group.get("data_set") != "array"
            or group.get("standard") != STANDARDS[name]
            or _norm(group.get("data_type_instance_count")) != 1
        ):
            raise SystemExit(f"{LANGUAGE}: invalid array group {name} {type_id}")
        cell = (name, type_id)
        if cell in cells:
            raise SystemExit(f"{LANGUAGE}: duplicate group {cell}")
        cells.add(cell)
    expected = {(name, type_id) for name in ARRAY_NAMES for type_id in ARRAY_TYPES}
    if cells != expected:
        raise SystemExit(f"{LANGUAGE}: array cells {sorted(cells)} != {sorted(expected)}")
    return groups


def splice(csv_path: Path, *, dry_run: bool, language: str = "fortran") -> None:
    stats_path, stats, published = load_published_stats(language)
    fresh, meta = _analyze(csv_path)
    new_groups = _validate_fresh(fresh, published)
    stats_keep = [
        g for g in published if not (str(g.get("serializer") or "") in STANDARDS and _base(g.get("test_data")) in ARRAY_TYPES)
    ]
    replaced = len(published) - len(stats_keep)
    before_suite = _counts(stats_keep, SUITE_TYPES)
    kept = (
        "Suite rows for hdf5-fortran, netcdf-fortran, and adios2 were removed. The six interchange serializers were not recomputed."
        if LANGUAGE == "fortran"
        else f"Previous groups for {', '.join(ARRAY_NAMES)} were removed. Other groups for this language were not recomputed."
    )
    print(f"{language}: {meta['rows']} rows, {len(new_groups)} groups, remove {replaced} previous groups for {', '.join(ARRAY_NAMES)}")
    if dry_run:
        return
    stats["groups"] = stats_keep + new_groups
    stats["array_splice"] = {
        "source_csv": str(csv_path.relative_to(REPO)),
        "run_config": "config/library/array.yaml",
        "analyzed_at": now_iso(),
        **meta,
        "groups_added": len(new_groups),
        "groups_replaced": replaced,
        "note": f"Array groups were measured in a separate full-mode run (config/library/array.yaml, 100 repetitions) and appended. {kept}",
    }
    if _counts(stats["groups"], SUITE_TYPES) != before_suite:
        raise SystemExit(f"{language}: suite counts for the other serializers changed")
    if any(str(g.get("serializer") or "") in STANDARDS and g.get("data_set") not in ("array", "tensor") for g in stats["groups"]):
        raise SystemExit(f"{language}: an array serializer still has a group outside array and tensor")
    write_json_gz(stats_path, stats)
    print(f"{language}: wrote {len(new_groups)} array groups")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", default="fortran", choices=tuple(PROFILES))
    parser.add_argument("--csv", type=Path, default=None)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    _select_language(args.language)
    csv_path = args.csv or (REPO / f"logs/{args.language}/2026-10-19-{args.language}-array-full.csv")
    csv_path = (csv_path if csv_path.is_absolute() else REPO / csv_path).resolve()
    if not csv_path.is_file():
        raise SystemExit(f"CSV not found: {csv_path}")
    splice(csv_path, dry_run=args.dry_run, language=args.language)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
