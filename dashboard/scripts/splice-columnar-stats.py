#!/usr/bin/env python3
"""Append columnar.yaml groups onto the published five-type dashboard snapshots.

sync-data.py publishes only logs named YYYY-MM-DD-HHMMSS.csv, and it replaces
the whole language snapshot. The columnar full runs use other filenames on
purpose. Several timestamped files under logs/ are columnar smokes; publishing
those would erase the five-type matrix. This script does not call sync-data.

It analyzes one columnar CSV with the same statistics pipeline as
analyze-benchmarks, then appends schema-2.2 groups whose identity is not
already in the snapshot. On a collision the published group stays. Row-type
groups (message, document, telemetry, strings, event) are not recomputed.

Both dashboard/public/data/<lang>_latest.json.gz and stats_<lang>_latest.json.gz
are rewritten so Overview and Compliance see the same roster.
"""
from __future__ import annotations

import argparse
import gzip
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "analysis" / "src"))

from benchmark_analysis.parser import parse_csv_file  # noqa: E402
from benchmark_analysis.stats import (  # noqa: E402
    _EXPORT_IDENTITY_KEYS,
    build_stats_export_payload,
    compute_statistics_multi_policy,
    load_stats_config,
)

DATA = REPO / "dashboard" / "public" / "data"
COLUMNAR_TYPES = ("table", "table_project", "nested_table", "signal")
ROW_TYPES = ("message", "document", "telemetry", "strings", "event")
MIN_REPS = 50

# Full columnar CSVs. Names must not match sync-data's latest-run regex.
DEFAULT_CSVS = {
    "python": REPO / "logs/python/2026-10-02-py-columnar-full.csv",
    "cpp": REPO / "logs/cpp/2026-10-02-cpp-columnar-full.csv",
    "csharp": REPO / "logs/csharp/2026-10-02-csharp-columnar-full.csv",
    "go": REPO / "logs/go/2026-10-02-go-columnar-full.csv",
    "java": REPO / "logs/java/2026-10-02-java-columnar-full.csv",
    "rust": REPO / "logs/rust/2026-10-02-rust-columnar-full.csv",
    "javascript": REPO / "logs/javascript/2026-10-03-js-columnar-full.csv",
    "kotlin": REPO / "logs/kotlin/2026-10-03-kt-columnar-full.csv",
}
CORE = ("python", "cpp", "csharp", "go", "java", "rust")


def _base(test_data: object) -> str:
    return str(test_data or "").split("@n=")[0]


def _norm(value):
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def _ident(group: dict) -> tuple:
    return tuple(_norm(group.get(key)) for key in _EXPORT_IDENTITY_KEYS) + (
        _norm(group.get("StreamMode")),
    )


def _counts(groups: list) -> dict[str, int]:
    out = {name: 0 for name in ROW_TYPES}
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


def _write_gz(path: Path, payload: dict, *, compact: bool) -> None:
    separators = (",", ":") if compact else (", ", ": ")
    raw = json.dumps(payload, separators=separators).encode("utf-8")
    tmp = path.with_suffix(path.suffix + ".tmp")
    with gzip.open(tmp, "wb", compresslevel=9) as handle:
        handle.write(raw)
    tmp.replace(path)


def _analyze(lang: str, csv_path: Path) -> tuple[dict, dict]:
    records, skipped = parse_csv_file(str(csv_path), language_hint=lang)
    if skipped:
        raise SystemExit(f"{csv_path}: refusing to publish; parser skipped {skipped} row(s)")
    if not records:
        raise SystemExit(f"{csv_path}: no records")
    reps = sorted({int(row.get("Repetitions") or 0) for row in records})
    if not reps or min(reps) < MIN_REPS:
        raise SystemExit(
            f"{csv_path}: repetitions {reps} are below {MIN_REPS}; refusing a smoke snapshot"
        )
    bases = {_base(row.get("TestDataName")) for row in records}
    foreign = sorted(base for base in bases if base not in COLUMNAR_TYPES)
    if foreign:
        raise SystemExit(f"{csv_path}: refusing non-columnar types {foreign}")
    config = load_stats_config()
    by_policy = compute_statistics_multi_policy(records, config=config, language_hint=lang)
    fresh = build_stats_export_payload(by_policy, lang)
    if fresh.get("schema_version") != "2.2":
        raise SystemExit(f"analysis produced schema {fresh.get('schema_version')}, expected 2.2")
    meta = {
        "reps": reps,
        "serializers": sorted({str(row.get("SerializerName") or "") for row in records if row.get("SerializerName")}),
        "types": sorted(bases),
        "rows": len(records),
    }
    return fresh, meta


def splice_language(lang: str, csv_path: Path) -> None:
    payload_path = DATA / f"{lang}_latest.json.gz"
    stats_path = DATA / f"stats_{lang}_latest.json.gz"
    if not payload_path.is_file() or not stats_path.is_file():
        raise SystemExit(f"{lang}: missing {payload_path.name} or {stats_path.name}")
    payload = _load_gz(payload_path)
    standalone = _load_gz(stats_path)
    embedded = payload.get("stats")
    if not isinstance(embedded, dict) or embedded.get("groups") != standalone.get("groups"):
        raise SystemExit(f"{lang}: payload stats and stats_{lang}_latest.json.gz groups differ; not splicing")
    if embedded.get("schema_version") != "2.2":
        raise SystemExit(f"{lang}: published schema is {embedded.get('schema_version')}, expected 2.2")

    before_groups = list(embedded.get("groups") or [])
    before_counts = _counts(before_groups)
    had_columnar = any(_base(group.get("test_data")) in COLUMNAR_TYPES for group in before_groups)
    fresh, meta = _analyze(lang, csv_path)

    seen = {_ident(group) for group in before_groups}
    added = []
    kept = 0
    for group in fresh.get("groups") or []:
        base = _base(group.get("test_data"))
        if base not in COLUMNAR_TYPES:
            raise SystemExit(f"{lang}: analysis emitted non-columnar group {group.get('serializer')} {group.get('test_data')}")
        if not group.get("language"):
            group["language"] = lang
        if group.get("language") != lang:
            raise SystemExit(f"{lang}: analysis group language is {group.get('language')}")
        key = _ident(group)
        if key in seen:
            kept += 1
            continue
        seen.add(key)
        added.append(group)

    if not added and not had_columnar:
        raise SystemExit(f"{lang}: analysis produced no new columnar groups")

    # Keep the published filter-policy catalog. New groups carry their own variants.
    embedded["groups"] = before_groups + added
    after_counts = _counts(embedded["groups"])
    if after_counts != before_counts:
        raise SystemExit(f"{lang}: row-type counts changed {before_counts} -> {after_counts}")

    note = {
        "source_csv": str(csv_path.relative_to(REPO)),
        "run_config": "config/library/columnar.yaml",
        "analyzed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "rows": meta["rows"],
        "reps": meta["reps"],
        "types": meta["types"],
        "serializers": meta["serializers"],
        "groups_added": len(added),
        "groups_already_present": kept,
        "row_group_counts": after_counts,
        "note": (
            "Columnar groups were measured in a separate columnar.yaml run and appended. "
            "Groups for message, document, telemetry, strings, and event are the previously "
            "published snapshot and were not recomputed."
        ),
    }
    embedded["columnar_splice"] = note
    payload["columnar_splice"] = note
    payload["stats"] = embedded

    _write_gz(stats_path, embedded, compact=True)
    _write_gz(payload_path, payload, compact=False)
    print(
        f"{lang}: added {len(added)} groups, kept {kept} collisions, "
        f"row counts {after_counts}, serializers {meta['serializers']}"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--language",
        action="append",
        default=[],
        help="Language id to splice. Repeatable. Default: every known CSV that exists.",
    )
    parser.add_argument("--csv", default="", help="CSV path, only with a single --language.")
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
        jobs = []
        for lang, path in DEFAULT_CSVS.items():
            if path.is_file():
                jobs.append((lang, path))
            else:
                print(f"{lang}: skip, CSV not present ({path.relative_to(REPO)})")

    for lang, path in jobs:
        splice_language(lang, path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
