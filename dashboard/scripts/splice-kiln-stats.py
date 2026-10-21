#!/usr/bin/env python3
"""Append gld-kiln suite and tensor groups to the published dashboard snapshots.

The Kiln CSVs are filtered to gld-kiln. sync-data.py would treat the newest
timestamped file as the whole language and drop every other serializer.
This script analyzes those runs and appends only the gld-kiln groups.

Suite, columnar, graph, and array groups for every other serializer stay.
Existing tensor groups for other serializers stay. A previous gld-kiln block
for that language is replaced.
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
NAME = "gld-kiln"
SUITE_TYPES = ("message", "document", "telemetry", "strings", "event")
TENSOR_TYPES = ("tensor", "tensor_view", "prompt", "shard", "request")
MIN_REPS = 100
# C# bytes mode records the Base64 text length. The wire size is the other languages.
CSHARP_SIZE = {
    "tensor": 5_592_424,
    "tensor_view": 5_592_424,
    "prompt": 32_796,
    "shard": 2_448_080,
    "request": 32_832,
}
WIRE_SIZE = {
    "tensor": 4_194_316,
    "tensor_view": 4_194_316,
    "prompt": 24_596,
    "shard": 1_836_060,
    "request": 24_623,
}

# Full runs already checked: fidelity 1, 100 repetitions, catalog wire size.
RUNS = {
    "c": {
        "suite": "logs/c/2026-10-19-221848.csv",
        "tensor": "logs/c/2026-10-19-225833.csv",
    },
    "cpp": {
        "suite": "logs/cpp/2026-10-20-191747.csv",
        "tensor": "logs/cpp/2026-10-20-191756.csv",
    },
    "csharp": {
        "suite": "logs/csharp/2026-10-19-222030.csv",
        "tensor": "logs/csharp/2026-10-19-223813.csv",
    },
    "go": {
        "suite": "logs/go/2026-10-19-221528.csv",
        "tensor": "logs/go/2026-10-19-223729.csv",
    },
    "java": {
        "suite": "logs/java/2026-10-21-kiln-suite-pin.csv",
        "tensor": "logs/java/2026-10-21-kiln-tensor-hot.csv",
    },
    "javascript": {
        "suite": "logs/javascript/2026-10-20-191908.csv",
        "tensor": "logs/javascript/2026-10-20-191910.csv",
    },
    "mojo": {
        "suite": "logs/mojo/2026-10-20-192824.csv",
        "tensor": "logs/mojo/2026-10-20-192855.csv",
    },
    "python": {
        "suite": "logs/python/2026-10-20-191915.csv",
        "tensor": "logs/python/2026-10-20-193042.csv",
    },
    "rust": {
        "suite": "logs/rust/2026-10-20-191702.csv",
        "tensor": "logs/rust/2026-10-20-191723.csv",
    },
    "swift": {
        "suite": "logs/swift/2026-10-20-192404.csv",
        "tensor": "logs/swift/2026-10-20-192723.csv",
    },
    "zig": {
        "suite": "logs/zig/2026-10-19-221613.csv",
        "tensor": "logs/zig/2026-10-19-224847.csv",
    },
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


def _write_gz(path: Path, payload: dict) -> None:
    raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
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


def _census(groups: list) -> dict[tuple, int]:
    out: dict[tuple, int] = {}
    for group in groups:
        if str(group.get("serializer") or "") == NAME:
            continue
        key = (
            str(group.get("serializer") or ""),
            _base(group.get("test_data")),
            _norm(group.get("data_type_instance_count")),
        )
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
        got = found.get(type_id)
        if got != {str(size)}:
            raise SystemExit(f"{csv_path}: {type_id} size {got} != {size}")


def _analyze(lang: str, csv_path: Path, kind: str) -> tuple[list, dict]:
    if _error_rows(csv_path):
        raise SystemExit(f"{csv_path}: refusing to publish; error rows present")
    _check_sizes(lang, csv_path, kind)
    allowed = SUITE_TYPES if kind == "suite" else TENSOR_TYPES
    want_n = {1, 100} if kind == "suite" else {1}
    records, skipped = parse_csv_file(str(csv_path), language_hint=lang)
    if skipped:
        raise SystemExit(f"{csv_path}: parser skipped {skipped} row(s)")
    if not records:
        raise SystemExit(f"{csv_path}: no records")
    names = {str(row.get("SerializerName") or "") for row in records}
    if names != {NAME}:
        raise SystemExit(f"{csv_path}: serializers {sorted(names)}")
    reps = sorted({int(row.get("Repetitions") or 0) for row in records})
    if reps != [MIN_REPS]:
        raise SystemExit(f"{csv_path}: repetitions {reps}; expected {MIN_REPS}")
    bases = {_base(row.get("TestDataName")) for row in records}
    if bases != set(allowed):
        raise SystemExit(f"{csv_path}: types {sorted(bases)} != {list(allowed)}")
    counts = {_norm(row.get("DataTypeInstanceCount")) for row in records}
    if counts != want_n:
        raise SystemExit(f"{csv_path}: instance counts {sorted(counts)} != {sorted(want_n)}")
    versions = {str(row.get("SerializerVersion") or "").strip() for row in records}
    if versions != {"0.2.0"}:
        raise SystemExit(f"{csv_path}: version {versions}")
    for row in records:
        fidelity = row.get("FidelityScore")
        if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
            raise SystemExit(f"{csv_path}: fidelity {fidelity!r}")
        if str(row.get("Language") or "") != lang:
            raise SystemExit(f"{csv_path}: language {row.get('Language')!r}")

    config = load_stats_config()
    by_policy = compute_statistics_multi_policy(records, config=config, language_hint=lang)
    fresh = build_stats_export_payload(by_policy, lang)
    if fresh.get("schema_version") != "2.2":
        raise SystemExit(f"{csv_path}: schema {fresh.get('schema_version')}")
    groups = list(fresh.get("groups") or [])
    meta = {"rows": len(records), "reps": reps, "version": "0.2.0"}
    return groups, meta


def _drop_cohort_effects(groups: list) -> None:
    """These runs contain only gld-kiln, so 'fastest in group' is not a comparison."""
    for group in groups:
        for metrics in (group.get("variants") or {}).values():
            if not isinstance(metrics, dict):
                continue
            for key in list(metrics):
                if key == "fastest_in_group" or str(key).startswith("effect_vs_fastest"):
                    metrics.pop(key, None)


def _validate(lang: str, groups: list, published: list, kind: str) -> None:
    allowed = set(SUITE_TYPES if kind == "suite" else TENSOR_TYPES)
    want_n = {1, 100} if kind == "suite" else {1}
    if not published:
        raise SystemExit(f"{lang}: published snapshot has no groups")
    expected_policies = set((published[0].get("variants") or {}))
    cells = set()
    for group in groups:
        _finite(group, f"{lang}/{group.get('serializer')}")
        if group.get("serializer") != NAME:
            raise SystemExit(f"{lang}: unexpected serializer {group.get('serializer')!r}")
        if group.get("language") != lang:
            raise SystemExit(f"{lang}: group language {group.get('language')!r}")
        if group.get("standard") != "kiln":
            raise SystemExit(f"{lang}: standard {group.get('standard')!r}")
        type_id = _base(group.get("test_data"))
        if type_id not in allowed:
            raise SystemExit(f"{lang}: type {type_id}")
        data_set = "suite" if kind == "suite" else "tensor"
        if group.get("data_set") != data_set:
            raise SystemExit(f"{lang}: {type_id} data_set {group.get('data_set')!r}")
        if group.get("mode") != "published":
            raise SystemExit(f"{lang}: mode {group.get('mode')!r}")
        if str(group.get("serializer_version") or "") != "0.2.0":
            raise SystemExit(f"{lang}: version {group.get('serializer_version')!r}")
        n = _norm(group.get("data_type_instance_count"))
        if n not in want_n:
            raise SystemExit(f"{lang}: instance count {n!r}")
        cell = (type_id, n)
        if cell in cells:
            raise SystemExit(f"{lang}: duplicate {cell}")
        cells.add(cell)
        variants = group.get("variants") or {}
        if set(variants) != expected_policies:
            raise SystemExit(
                f"{lang}: policies {sorted(variants)} != {sorted(expected_policies)}"
            )
        for policy, metrics in variants.items():
            fidelity = metrics.get("mean_fidelity")
            if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
                raise SystemExit(f"{lang}: {policy} fidelity {fidelity!r}")
            filt = metrics.get("filter") or {}
            if int(filt.get("runs_raw") or 0) != MIN_REPS:
                raise SystemExit(f"{lang}: {policy} runs_raw {filt.get('runs_raw')!r}")
    expected = {(type_id, n) for type_id in allowed for n in want_n}
    if cells != expected:
        raise SystemExit(f"{lang}: {kind} cells {sorted(cells)} != {sorted(expected)}")


def splice_language(lang: str, *, dry_run: bool) -> None:
    paths = RUNS[lang]
    suite_csv = (REPO / paths["suite"]).resolve()
    tensor_csv = (REPO / paths["tensor"]).resolve()
    for path in (suite_csv, tensor_csv):
        if not path.is_file():
            raise SystemExit(f"CSV not found: {path}")
    payload_path = DATA / f"{lang}_latest.json.gz"
    stats_path = DATA / f"stats_{lang}_latest.json.gz"
    payload = _load_gz(payload_path)
    stats = _load_gz(stats_path)
    embedded = payload.get("stats")
    if not isinstance(embedded, dict):
        raise SystemExit(f"{lang}: payload has no stats object")
    published = list(stats.get("groups") or [])
    suite_groups, suite_meta = _analyze(lang, suite_csv, "suite")
    tensor_groups, tensor_meta = _analyze(lang, tensor_csv, "tensor")
    _drop_cohort_effects(suite_groups)
    _drop_cohort_effects(tensor_groups)
    _validate(lang, suite_groups, published, "suite")
    _validate(lang, tensor_groups, published, "tensor")
    new_groups = suite_groups + tensor_groups
    before = _census(published)
    payload_before = _census(list(embedded.get("groups") or []))
    if before != payload_before:
        raise SystemExit(f"{lang}: stats and payload disagree before the splice")

    def _keep(groups: list) -> tuple[list, int]:
        kept = [group for group in groups if str(group.get("serializer") or "") != NAME]
        return kept, len(groups) - len(kept)

    stats_keep, stats_old = _keep(published)
    payload_keep, payload_old = _keep(list(embedded.get("groups") or []))
    if stats_old != payload_old:
        raise SystemExit(f"{lang}: existing gld-kiln groups diverged")
    note = {
        "suite_csv": str(suite_csv.relative_to(REPO)),
        "tensor_csv": str(tensor_csv.relative_to(REPO)),
        "analyzed_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "suite_rows": suite_meta["rows"],
        "tensor_rows": tensor_meta["rows"],
        "reps": MIN_REPS,
        "serializer": NAME,
        "version": "0.2.0",
        "groups_added": len(new_groups),
        "groups_replaced": stats_old,
        "note": (
            "gld-kiln groups were measured in separate full-mode runs "
            "(suite at N=1 and N=100, tensor at N=1, 100 repetitions) and appended. "
            "Other serializers were not recomputed."
        ),
    }
    print(
        f"{lang}: suite {suite_meta['rows']} rows, tensor {tensor_meta['rows']} rows, "
        f"{len(new_groups)} groups, replace {stats_old}"
    )
    if dry_run:
        return
    stats["groups"] = stats_keep + new_groups
    stats["kiln_splice"] = note
    embedded["groups"] = payload_keep + copy.deepcopy(new_groups)
    embedded["kiln_splice"] = copy.deepcopy(note)
    payload["kiln_splice"] = copy.deepcopy(note)
    if _census(stats["groups"]) != before:
        raise SystemExit(f"{lang}: other serializers changed")
    if _census(embedded["groups"]) != before:
        raise SystemExit(f"{lang}: payload other serializers changed")
    _write_gz(stats_path, stats)
    _write_gz(payload_path, payload)
    print(f"{lang}: wrote {len(new_groups)} gld-kiln groups")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", action="append", choices=sorted(RUNS))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    langs = args.language or list(RUNS)
    for lang in langs:
        splice_language(lang, dry_run=args.dry_run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
