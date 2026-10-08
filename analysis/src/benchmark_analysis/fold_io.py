"""Fold mandatory Stream/Bytes groups into one parent row.

Same-size opt-in pairs: the parent medians are the arithmetic mean of the two
levels, and both levels are children. C# Base64 pairs: the parent is the
raw-byte level and the string level is the child only when that serializer is
on the opt-in list. Every other serializer keeps a single in-memory row.
"""

from __future__ import annotations

import copy
from typing import Any

from benchmark_analysis.dimensions import load_dimensions, optional_io_index

_IN_MEMORY = {"bytes", "string", "buffer"}


def _mode(group: dict[str, Any]) -> str:
    return str(group.get("mode") or "").strip().lower()


def _policy_metrics(group: dict[str, Any], policy: str) -> dict[str, Any] | None:
    variants = group.get("variants")
    if isinstance(variants, dict) and policy in variants and isinstance(variants[policy], dict):
        return variants[policy]
    return None


def _size(group: dict[str, Any]) -> float:
    for policy in ("iqr_1.5", "all"):
        metrics = _policy_metrics(group, policy)
        if metrics and metrics.get("median_size_bytes"):
            return float(metrics["median_size_bytes"])
    variants = group.get("variants") or {}
    for metrics in variants.values():
        if isinstance(metrics, dict) and metrics.get("median_size_bytes"):
            return float(metrics["median_size_bytes"])
    return 0.0


def _is_base64_pair(levels: list[dict[str, Any]], ratio: float, tolerance: float) -> bool:
    sizes = [size for size in (_size(group) for group in levels) if size > 0]
    if len(sizes) < 2:
        return False
    small, large = min(sizes), max(sizes)
    return abs((small / large) - ratio) <= tolerance


def _in_memory(levels: list[dict[str, Any]]) -> dict[str, Any]:
    for group in levels:
        if _mode(group) in _IN_MEMORY:
            return group
    return levels[0]


def _raw_bytes(levels: list[dict[str, Any]]) -> dict[str, Any]:
    return min(levels, key=_size)


def _child(group: dict[str, Any], level: str) -> dict[str, Any]:
    child: dict[str, Any] = {
        "level": level,
        "mode": group.get("mode"),
        "variants": copy.deepcopy(group.get("variants") or {}),
    }
    if group.get("StreamMode"):
        child["StreamMode"] = group["StreamMode"]
    return child


def _average_metrics(parts: list[dict[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    keys: set[str] = set()
    for part in parts:
        keys.update(part)
    count = len(parts)
    for key in keys:
        if key == "filter" or key.startswith("effect_vs_fastest"):
            continue
        values: list[float] = []
        numeric = True
        for part in parts:
            value = part.get(key)
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                numeric = False
                break
            values.append(float(value))
        if numeric and len(values) == count:
            out[key] = sum(values) / count
    if parts and isinstance(parts[0].get("filter"), dict):
        out["filter"] = copy.deepcopy(parts[0]["filter"])
    total = out.get("avg_time_total_ns") or out.get("total_mean_ns")
    if isinstance(total, (int, float)) and total > 0:
        out["avg_ops_per_sec"] = 1e9 / float(total)
    if isinstance(out.get("total_max_ns"), (int, float)) and out["total_max_ns"] > 0:
        out["min_ops_per_sec"] = 1e9 / float(out["total_max_ns"])
    if isinstance(out.get("total_min_ns"), (int, float)) and out["total_min_ns"] > 0:
        out["max_ops_per_sec"] = 1e9 / float(out["total_min_ns"])
    return out


def _with_optional(group: dict[str, Any], optional: list[dict[str, Any]], how: str) -> dict[str, Any]:
    parent = copy.deepcopy(group)
    parent["optional"] = optional
    parent["io_parent"] = how
    parent["mode"] = "published"
    return parent


def _average_group(levels: list[dict[str, Any]]) -> dict[str, Any]:
    parent = copy.deepcopy(_in_memory(levels))
    policies: set[str] = set()
    for group in levels:
        policies.update((group.get("variants") or {}).keys())
    variants: dict[str, Any] = {}
    for policy in policies:
        parts = []
        for group in levels:
            metrics = _policy_metrics(group, policy)
            if metrics is not None:
                parts.append(metrics)
        if len(parts) == len(levels):
            variants[policy] = _average_metrics(parts)
    parent["variants"] = variants
    parent["optional"] = [
        _child(group, "stream" if _mode(group) == "stream" else (_mode(group) or "bytes"))
        for group in levels
    ]
    parent["io_parent"] = "average"
    parent["mode"] = "published"
    return parent


def fold_io_groups(
    groups: list[dict[str, Any]],
    dimensions: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """One parent group per serializer, data type, and instance count."""
    if dimensions is None:
        dimensions = load_dimensions()
    opt_in = optional_io_index(dimensions)
    io = dimensions.get("optional_io") or {}
    ratio = float(io.get("base64_size_ratio") or 0.75)
    tolerance = float(io.get("base64_size_tolerance") or 0.05)

    buckets: dict[tuple, list[dict[str, Any]]] = {}
    order: list[tuple] = []
    for group in groups:
        key = (
            group.get("language"),
            group.get("serializer"),
            group.get("test_data"),
            group.get("type_config_hash"),
            group.get("data_type_instance_count"),
        )
        if key not in buckets:
            order.append(key)
            buckets[key] = []
        buckets[key].append(group)

    folded: list[dict[str, Any]] = []
    for key in order:
        levels = buckets[key]
        language, serializer = key[0], key[1]
        if len(levels) == 1:
            folded.append(_with_optional(levels[0], [], "single"))
            continue
        chosen = opt_in.get((language, serializer))
        if language == "csharp" and _is_base64_pair(levels, ratio, tolerance):
            parent = _with_optional(_raw_bytes(levels), [], "raw_bytes")
            if chosen and chosen.get("level") == "string":
                string_level = next(group for group in levels if _mode(group) == "string")
                parent["optional"] = [_child(string_level, "string")]
            folded.append(parent)
            continue
        if chosen and chosen.get("level") == "stream":
            folded.append(_average_group(levels))
            continue
        folded.append(_with_optional(_in_memory(levels), [], "in_memory"))
    return folded
