#!/usr/bin/env python3
"""Append array.yaml groups onto a published language snapshot.

The CSV name is not YYYY-MM-DD-HHMMSS, so sync-data.py does not select it.
This script analyzes that full run and appends grid and grid_window.
It replaces previous groups only for the array serializers of that language.
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
ARRAY_TYPES = ("grid", "grid_window")
LANGUAGE = "fortran"
ARRAY_NAMES = ("hdf5-fortran", "netcdf-fortran", "adios2")
SUITE_TYPES = ("message", "document", "telemetry", "strings", "event")
MIN_REPS = 100
DEFAULT_CSV = REPO / "logs/fortran/2026-10-10-fortran-array-full.csv"
STANDARDS = {
    "hdf5-fortran": "hdf5",
    "netcdf-fortran": "netcdf",
    "adios2": "adios2",
}
MODES = {
    "hdf5-fortran": "bytes",
    "netcdf-fortran": "stream",
    "adios2": "stream",
}


def _base(test_data: object) -> str:
    return str(test_data or "").split("@n=")[0]


def _norm(value):
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


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


def _error_rows(csv_path: Path) -> int:
    err_path = csv_path.with_name(csv_path.stem + ".errors.csv")
    if not err_path.is_file():
        return 0
    with err_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.reader(handle))
    return max(0, len(rows) - 1) if rows else 0


def _counts(groups: list, names: tuple[str, ...]) -> dict[str, int]:
    out = {name: 0 for name in names}
    for group in groups:
        base = _base(group.get("test_data"))
        if base in out:
            out[base] += 1
    return out


def _analyze(csv_path: Path) -> tuple[dict, dict]:
    error_rows = _error_rows(csv_path)
    if error_rows:
        raise SystemExit(f"{csv_path}: refusing to publish; {error_rows} error row(s)")
    records, skipped = parse_csv_file(str(csv_path), language_hint=LANGUAGE)
    if skipped:
        raise SystemExit(f"{csv_path}: refusing to publish; parser skipped {skipped} row(s)")
    if not records:
        raise SystemExit(f"{csv_path}: no records")

    reps = sorted({int(row.get("Repetitions") or 0) for row in records})
    if reps != [MIN_REPS]:
        raise SystemExit(f"{csv_path}: repetitions {reps}; expected {MIN_REPS}")

    versions: dict[str, str] = {}
    indexes: dict[tuple, set[int]] = {}
    for row in records:
        name = str(row.get("SerializerName") or "")
        if name not in STANDARDS:
            raise SystemExit(f"{csv_path}: unexpected serializer {name!r}")
        version = str(row.get("SerializerVersion") or "").strip()
        if not version:
            raise SystemExit(f"{csv_path}: {name} has an empty version")
        previous = versions.setdefault(name, version)
        if previous != version:
            raise SystemExit(f"{csv_path}: {name} version changed from {previous!r} to {version!r}")
        type_id = _base(row.get("TestDataName"))
        if type_id not in ARRAY_TYPES:
            raise SystemExit(f"{csv_path}: refusing type {type_id!r}")
        count = _norm(row.get("DataTypeInstanceCount"))
        if count != 1:
            raise SystemExit(f"{csv_path}: refusing instance count {count!r}")
        mode = str(row.get("StringOrStream") or "")
        if mode != MODES[name]:
            raise SystemExit(f"{csv_path}: {name} I/O mode {mode!r}")
        stream_mode = str(row.get("StreamMode") or "").strip()
        if MODES[name] == "stream" and stream_mode != "native":
            raise SystemExit(f"{csv_path}: {name} StreamMode {row.get('StreamMode')!r}")
        if MODES[name] == "bytes" and stream_mode not in ("", "adapted"):
            raise SystemExit(f"{csv_path}: {name} StreamMode {row.get('StreamMode')!r}")
        if str(row.get("Language") or "") != LANGUAGE:
            raise SystemExit(f"{csv_path}: row language {row.get('Language')!r}")
        fidelity = row.get("FidelityScore")
        if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
            raise SystemExit(f"{csv_path}: fidelity {fidelity!r} for {name} {type_id}")
        indexes.setdefault((name, type_id), set()).add(int(row.get("RepetitionIndex") or 0))

    for name in ARRAY_NAMES:
        for type_id in ARRAY_TYPES:
            seen = indexes.get((name, type_id))
            if seen != set(range(MIN_REPS)):
                raise SystemExit(f"{csv_path}: {(name, type_id)} repetition indexes are not 0..{MIN_REPS - 1}")

    config = load_stats_config()
    by_policy = compute_statistics_multi_policy(records, config=config, language_hint=LANGUAGE)
    fresh = build_stats_export_payload(by_policy, LANGUAGE)
    if fresh.get("schema_version") != "2.2":
        raise SystemExit(f"analysis produced schema {fresh.get('schema_version')}, expected 2.2")
    meta = {
        "reps": reps,
        "serializers": sorted(versions),
        "versions": versions,
        "rows": len(records),
    }
    return fresh, meta


def _validate_fresh(fresh: dict, published_groups: list) -> list:
    groups = list(fresh.get("groups") or [])
    if not published_groups:
        raise SystemExit("fortran: published snapshot has no groups to append to")
    expected_policies = set((published_groups[0].get("variants") or {}))
    cells = set()
    for group in groups:
        _finite(group, f"fortran/{group.get('serializer')}")
        name = str(group.get("serializer") or "")
        if name not in STANDARDS:
            raise SystemExit(f"fortran: unexpected serializer {name!r}")
        if group.get("language") != LANGUAGE:
            raise SystemExit(f"fortran: analysis group language is {group.get('language')!r}")
        if _base(group.get("test_data")) not in ARRAY_TYPES:
            raise SystemExit(f"fortran: analysis test_data {group.get('test_data')!r}")
        if group.get("data_set") != "array":
            raise SystemExit(f"fortran: {name} data_set is {group.get('data_set')!r}")
        if group.get("standard") != STANDARDS[name]:
            raise SystemExit(f"fortran: {name} standard is {group.get('standard')!r}")
        if group.get("mode") != "published":
            raise SystemExit(f"fortran: {name} mode is {group.get('mode')!r}")
        if _norm(group.get("data_type_instance_count")) != 1:
            raise SystemExit(f"fortran: {name} instance count {group.get('data_type_instance_count')!r}")
        cell = (name, _base(group.get("test_data")))
        if cell in cells:
            raise SystemExit(f"fortran: duplicate group {cell}")
        cells.add(cell)
        variants = group.get("variants") or {}
        if set(variants) != expected_policies:
            raise SystemExit(f"fortran: {name} policies {sorted(variants)} != {sorted(expected_policies)}")
        for policy, metrics in variants.items():
            fidelity = metrics.get("mean_fidelity")
            if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
                raise SystemExit(f"fortran: {name} {policy} fidelity {fidelity!r}")
            filt = metrics.get("filter") or {}
            if int(filt.get("runs_raw") or 0) != MIN_REPS:
                raise SystemExit(f"fortran: {name} {policy} runs_raw {filt.get('runs_raw')!r}")
    expected = {(name, type_id) for name in ARRAY_NAMES for type_id in ARRAY_TYPES}
    if cells != expected:
        raise SystemExit(f"fortran: array cells {sorted(cells)} != {sorted(expected)}")
    return groups


def _split(groups: list) -> tuple[list, list]:
    keep, old = [], []
    for group in groups:
        if str(group.get("serializer") or "") in STANDARDS:
            old.append(group)
        else:
            keep.append(group)
    return keep, old


def splice(csv_path: Path, *, dry_run: bool, language: str = "fortran") -> None:
    payload_path = DATA / f"{language}_latest.json.gz"
    stats_path = DATA / f"stats_{language}_latest.json.gz"
    if not payload_path.is_file() or not stats_path.is_file():
        raise SystemExit(f"{language}: missing published snapshot")
    payload = _load_gz(payload_path)
    stats = _load_gz(stats_path)
    embedded = payload.get("stats")
    if not isinstance(embedded, dict):
        raise SystemExit(f"{language}: payload has no stats object")

    fresh, meta = _analyze(csv_path)
    new_groups = _validate_fresh(fresh, list(stats.get("groups") or []))
    stats_keep, stats_old = _split(list(stats.get("groups") or []))
    payload_keep, payload_old = _split(list(embedded.get("groups") or []))
    before_suite = _counts(stats_keep, SUITE_TYPES)
    if LANGUAGE == "python":
        kept = (
            "Previous groups for h5py, netCDF4, and adios2 were removed. "
            "Suite, columnar, and graph groups for the other Python serializers were not recomputed."
        )
    else:
        kept = (
            "Suite rows for hdf5-fortran, netcdf-fortran, and adios2 were removed. "
            "The six interchange serializers were not recomputed."
        )
    note = {
        "source_csv": str(csv_path.relative_to(REPO)),
        "run_config": "config/library/array.yaml",
        "analyzed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "rows": meta["rows"],
        "reps": meta["reps"],
        "serializers": meta["serializers"],
        "versions": meta["versions"],
        "groups_added": len(new_groups),
        "groups_replaced": len(stats_old),
        "note": (
            "Array groups were measured in a separate full-mode run "
            "(config/library/array.yaml, 100 repetitions) and appended. "
            + kept
        ),
    }
    print(
        f"{language}: {meta['rows']} rows, {len(new_groups)} groups, "
        f"remove {len(stats_old)} previous groups for {', '.join(ARRAY_NAMES)}"
    )
    if dry_run:
        print(f"{language}: dry-run, snapshots not written")
        return
    if len(stats_old) != len(payload_old):
        raise SystemExit(f"{language}: stats/payload groups for these serializers diverged")
    stats["groups"] = stats_keep + new_groups
    stats["array_splice"] = note
    embedded["groups"] = payload_keep + copy.deepcopy(new_groups)
    embedded["array_splice"] = copy.deepcopy(note)
    payload["array_splice"] = copy.deepcopy(note)
    if _counts(stats["groups"], SUITE_TYPES) != before_suite:
        raise SystemExit(f"{language}: suite counts for the other serializers changed")
    if any(str(group.get("serializer") or "") in STANDARDS and group.get("data_set") != "array"
           for group in stats["groups"]):
        raise SystemExit(f"{language}: an array serializer still has a non-array group")
    _write_gz(stats_path, stats)
    _write_gz(payload_path, payload)
    print(f"{language}: wrote {len(new_groups)} array groups")


def _select_language(language: str) -> None:
    global ARRAY_NAMES, STANDARDS, MODES, LANGUAGE
    LANGUAGE = language
    if language == "fortran":
        return
    if language != "python":
        raise SystemExit(f"unsupported language {language}")
    ARRAY_NAMES = ("h5py", "netCDF4", "adios2")
    STANDARDS = {"h5py": "hdf5", "netCDF4": "netcdf", "adios2": "adios2"}
    MODES = {name: "bytes" for name in ARRAY_NAMES}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", default="fortran", choices=("fortran", "python"))
    parser.add_argument("--csv", type=Path, default=None)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    _select_language(args.language)
    csv_path = args.csv or (
        DEFAULT_CSV if args.language == "fortran"
        else REPO / "logs/python/2026-10-10-python-array-full.csv"
    )
    if not csv_path.is_absolute():
        csv_path = REPO / csv_path
    csv_path = csv_path.resolve()
    if not csv_path.is_file():
        raise SystemExit(f"CSV not found: {csv_path}")
    splice(csv_path, dry_run=args.dry_run, language=args.language)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
