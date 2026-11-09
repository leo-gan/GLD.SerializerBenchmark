"""Identity helpers shared by the dashboard splice scripts.

The type id is the test name before ``@n=``. A whole number that arrived as
a float compares equal to an int. A non-finite metric is not publishable.
"""

from __future__ import annotations

import csv
import math
from pathlib import Path


def base_type(test_data: object) -> str:
    return str(test_data or "").split("@n=")[0]


def as_whole(value):
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def require_finite(value, path: str) -> None:
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


def export_stats(records: list, language: str) -> dict:
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


def count_bases(groups: list, names: tuple[str, ...]) -> dict[str, int]:
    out = {name: 0 for name in names}
    for group in groups:
        base = base_type(group.get("test_data"))
        if base in out:
            out[base] += 1
    return out
