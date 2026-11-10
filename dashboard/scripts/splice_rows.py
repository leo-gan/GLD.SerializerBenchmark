"""Shared validation, splicing engine, and splice guards for dashboard snapshots.

The type id is the test name before ``@n=``. A whole number that arrived as
a float compares equal to an int. A non-finite metric is not publishable.
"""

from __future__ import annotations

import argparse
import copy
import csv
import math
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

SCRIPT_DIR = Path(__file__).resolve().parent
REPO = SCRIPT_DIR.parents[1]
DATA = REPO / "dashboard" / "public" / "data"
if str(REPO / "analysis" / "src") not in sys.path:
    sys.path.insert(0, str(REPO / "analysis" / "src"))

SUITE_TYPES = ("message", "document", "telemetry", "strings", "event")
COLUMNAR_TYPES = ("table", "table_project", "nested_table", "signal")
GRAPH_TYPES = ("graph",)
ARRAY_TYPES = ("grid", "grid_window")
TENSOR_TYPES = ("tensor", "tensor_view", "prompt", "shard", "request")
DAGR_SERIALIZERS = (
    "dagr-frozen",
    "dagr-frozen-packed",
    "dagr-packed",
    "dagr-regular",
)
DAGR_VERSION = "2026.10.1"
ALLOWED_STREAM_MODES = {"", "native", "adapted", "text_on_stream", "text"}

SPLICE_GUARDS = (
    ("DASHBOARD_REPLACE_COLUMNAR", set(COLUMNAR_TYPES), None, "columnar types", "splice-columnar-stats.py"),
    ("DASHBOARD_REPLACE_DAGR", None, set(DAGR_SERIALIZERS), "Dagr serializers", "splice-dagr-stats.py"),
    ("DASHBOARD_REPLACE_GRAPH", set(GRAPH_TYPES), None, "graph types", "splice-graph-stats.py"),
    ("DASHBOARD_REPLACE_ARRAY", set(ARRAY_TYPES), None, "array types", "splice-array-stats.py"),
    ("DASHBOARD_REPLACE_TENSOR", set(TENSOR_TYPES), None, "tensor types", "splice-tensor-stats.py"),
)


def base_type(test_data: object) -> str:
    return str(test_data or "").split("@n=")[0]


def as_whole(value: Any) -> Any:
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def require_finite(value: Any, path: str) -> None:
    if isinstance(value, float):
        if not math.isfinite(value):
            raise SystemExit(f"non-finite number at {path}")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            require_finite(item, f"{path}.{key}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            require_finite(item, f"{path}[{index}]")


def error_row_count(csv_path: Path) -> int:
    err_path = Path(csv_path).with_name(Path(csv_path).stem + ".errors.csv")
    if not err_path.is_file():
        return 0
    with err_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.reader(handle))
    return max(0, len(rows) - 1) if rows else 0


def refuse_error_rows(csv_path: Path | str) -> None:
    """A sidecar errors.csv with any data row means the run is not publishable."""
    count = error_row_count(Path(csv_path))
    if count:
        raise SystemExit(f"{csv_path}: refusing to publish; {count} error row(s)")


def load_records(csv_path: Path | str, language: str) -> list[dict[str, Any]]:
    """Parse a splice CSV. Skipped rows and an empty file are not publishable."""
    from benchmark_analysis.parser import parse_csv_file

    records, skipped = parse_csv_file(str(csv_path), language_hint=language)
    if skipped:
        raise SystemExit(
            f"{csv_path}: refusing to publish; parser skipped {skipped} row(s)"
        )
    if not records:
        raise SystemExit(f"{csv_path}: no records")
    return records


def export_stats(records: list[dict[str, Any]], language: str) -> dict[str, Any]:
    """Turn clean rows into the schema 2.2 document the dashboard publishes."""
    from benchmark_analysis.stats import (
        build_stats_export_payload,
        compute_statistics_multi_policy,
        load_stats_config,
    )

    config = load_stats_config()
    by_policy = compute_statistics_multi_policy(
        records, config=config, language_hint=language
    )
    fresh = build_stats_export_payload(by_policy, language)
    if fresh.get("schema_version") != "2.2":
        raise SystemExit(
            f"analysis produced schema {fresh.get('schema_version')}, expected 2.2"
        )
    return fresh


def count_bases(groups: list[dict[str, Any]], names: tuple[str, ...]) -> dict[str, int]:
    out = {name: 0 for name in names}
    for group in groups:
        base = base_type(group.get("test_data"))
        if base in out:
            out[base] += 1
    return out


def _base_types_set(stats: dict[str, Any] | None) -> set[str]:
    return {
        base_type(g.get("test_data"))
        for g in (stats or {}).get("groups") or []
        if base_type(g.get("test_data"))
    }


def _serializer_names_set(stats: dict[str, Any] | None) -> set[str]:
    return {
        str(g.get("serializer") or "")
        for g in (stats or {}).get("groups") or []
        if g.get("serializer")
    }


def _replace_flag(name: str) -> bool:
    return os.environ.get(name, "").strip().lower() in ("1", "true", "yes")


def carry_spliced_groups(
    lang: str, existing_stats: dict[str, Any] | None, new_stats: dict[str, Any] | None
) -> None:
    """Keep publication splices the suite CSV does not measure."""
    if not existing_stats or not new_stats or not new_stats.get("groups"):
        return
    new_types = _base_types_set(new_stats)
    new_names = _serializer_names_set(new_stats)
    keep_types: set[str] = set()
    for env, types, _, _, _ in SPLICE_GUARDS:
        if types is not None and not _replace_flag(env):
            keep_types |= types
    keep_dagr = not _replace_flag("DASHBOARD_REPLACE_DAGR")
    carried = []
    for group in existing_stats.get("groups") or []:
        base = base_type(group.get("test_data"))
        name = str(group.get("serializer") or "")
        if base in keep_types and base not in new_types:
            carried.append(group)
        elif keep_dagr and name in DAGR_SERIALIZERS and name not in new_names:
            carried.append(group)
    if not carried:
        return
    new_stats.setdefault("groups", []).extend(carried)
    print(f"{lang}: carried {len(carried)} spliced groups from the previous snapshot")


def refuse_splice_loss(
    lang: str, existing_stats: dict[str, Any] | None, new_stats: dict[str, Any] | None
) -> None:
    """Abort when a sync would erase groups a splice script published."""
    for env, types, names, label, script in SPLICE_GUARDS:
        if types is not None:
            lost = (_base_types_set(existing_stats) & types) - _base_types_set(new_stats)
        else:
            lost = (_serializer_names_set(existing_stats) & (names or set())) - _serializer_names_set(new_stats)
        if not lost:
            continue
        if _replace_flag(env):
            print(f"WARNING: {lang} replacing snapshot and dropping {label} {sorted(lost)}")
            continue
        print(f"ERROR: {lang} snapshot has {label} {sorted(lost)} that this sync would drop.")
        print(f"That snapshot was built by {script}. Refusing to overwrite.")
        print(f"Set {env}=1 to replace the snapshot anyway.")
        sys.exit(1)


def validate_group_variants(
    lang: str,
    group: dict[str, Any],
    expected_policies: set[str],
    min_reps: int,
    *,
    require_warmup_1: bool = False,
    require_positive_size_and_time: bool = False,
) -> None:
    """Validate common schema 2.2 group variant invariants across splice scripts."""
    require_finite(group, f"{lang}/{group.get('serializer')}")
    name = str(group.get("serializer") or "")
    if group.get("language") != lang:
        raise SystemExit(f"{lang}: analysis group language is {group.get('language')!r}")
    if group.get("mode") != "published":
        raise SystemExit(f"{lang}: {name} mode is {group.get('mode')!r}")
    variants = group.get("variants") or {}
    if set(variants) != expected_policies:
        raise SystemExit(
            f"{lang}: {name} policies {sorted(variants)} != {sorted(expected_policies)}"
        )
    for policy, metrics in variants.items():
        if not isinstance(metrics, dict):
            raise SystemExit(f"{lang}: {name} policy {policy} is not an object")
        fidelity = metrics.get("mean_fidelity")
        if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
            raise SystemExit(f"{lang}: {name} {policy} fidelity {fidelity!r}")
        filt = metrics.get("filter") or {}
        runs_raw = filt.get("runs_raw") if "runs_raw" in filt else metrics.get("runs_raw")
        if int(runs_raw or 0) != min_reps:
            raise SystemExit(f"{lang}: {name} {policy} runs_raw {runs_raw!r}")
        if require_warmup_1:
            ws = filt.get("warmup_skipped") if "warmup_skipped" in filt else metrics.get("warmup_skipped")
            if int(ws or 0) != 1:
                raise SystemExit(f"{lang}: {name} {policy} warmup_skipped {ws!r}")
        if require_positive_size_and_time:
            size = metrics.get("median_size_bytes")
            if not isinstance(size, (int, float)) or size <= 0:
                raise SystemExit(f"{lang}: {name} {policy} median_size_bytes {size!r}")
            total = metrics.get("avg_time_total_ns")
            if not isinstance(total, (int, float)) or total <= 0:
                raise SystemExit(f"{lang}: {name} {policy} avg_time_total_ns {total!r}")


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_published_stats(lang: str) -> tuple[Path, dict[str, Any], list[dict[str, Any]]]:
    from snapshot_io import load_json_gz

    stats_path = DATA / f"stats_{lang}_latest.json.gz"
    if not stats_path.is_file():
        raise SystemExit(f"{lang}: missing {stats_path.name}")
    stats = load_json_gz(stats_path)
    if stats.get("schema_version") != "2.2":
        raise SystemExit(f"{lang}: published schema is {stats.get('schema_version')}, expected 2.2")
    return stats_path, stats, list(stats.get("groups") or [])


def validate_csv_records(
    csv_path: Path,
    lang: str,
    min_reps: int = 100,
) -> tuple[list[dict[str, Any]], list[int]]:
    """Load and validate common full-run CSV constraints (no error rows, exact reps, lang, fidelity=1)."""
    refuse_error_rows(csv_path)
    records = load_records(csv_path, lang)
    reps = sorted({int(row.get("Repetitions") or 0) for row in records})
    if reps != [min_reps]:
        raise SystemExit(f"{csv_path}: repetitions {reps}; expected {min_reps}")
    for row in records:
        if str(row.get("Language") or "") != lang:
            raise SystemExit(f"{csv_path}: row language {row.get('Language')!r} != {lang}")
        fidelity = row.get("FidelityScore")
        if not isinstance(fidelity, (int, float)) or abs(float(fidelity) - 1.0) > 1e-9:
            raise SystemExit(
                f"{csv_path}: fidelity {fidelity!r} for {row.get('SerializerName')} {row.get('TestDataName')}"
            )
    return records, reps
