"""Metric importance catalog for multi-way vs pairwise publication surfaces.

See docs/analysis/METRICS.md and config/benchmark_config.yaml ``metrics:``.
"""

from __future__ import annotations

from typing import Any, Dict, Iterable, List, Optional, Sequence, Set

# Defaults if master config is missing
_DEFAULT_IMPORTANCE: Dict[str, str] = {
    "total_median_ns": "high",
    "ser_median_ns": "high",
    "deser_median_ns": "high",
    "avg_time_total_ns": "medium",
    "avg_time_ser_ns": "medium",
    "avg_time_deser_ns": "medium",
    "total_mean_ns": "medium",
    "avg_ops_per_sec": "high",
    "median_size_bytes": "high",
    "mean_fidelity": "high",
    "serializer_version": "high",
    "runs": "high",
    "total_ci_low_ns": "medium",
    "total_ci_high_ns": "medium",
    "total_p95_ns": "medium",
    "total_p99_ns": "medium",
    "total_cv": "medium",
    "effect_vs_fastest_cliffs_delta": "medium",
    "effect_vs_fastest_cliffs_label": "medium",
    "effect_vs_fastest_hedges_g": "low",
}

_DEFAULT_MULTI_WAY = ["high"]
_DEFAULT_PAIRWISE = ["high", "medium", "low"]


def load_metrics_config(config_path: Optional[str] = None) -> Dict[str, Any]:
    out: Dict[str, Any] = {
        "catalog_version": "1",
        "multi_way": {"include_importance": list(_DEFAULT_MULTI_WAY), "rank_by": "total_median_ns"},
        "pairwise": {"include_importance": list(_DEFAULT_PAIRWISE)},
        "importance": dict(_DEFAULT_IMPORTANCE),
    }
    try:
        from .config_loader import load_master_config

        data = load_master_config(config_path)
        m = data.get("metrics") or {}
        if m.get("catalog_version"):
            out["catalog_version"] = str(m["catalog_version"])
        if isinstance(m.get("multi_way"), dict):
            out["multi_way"].update(m["multi_way"])
        if isinstance(m.get("pairwise"), dict):
            out["pairwise"].update(m["pairwise"])
        if isinstance(m.get("importance"), dict):
            merged = dict(out["importance"])
            merged.update({str(k): str(v).lower() for k, v in m["importance"].items()})
            out["importance"] = merged
    except Exception:
        pass
    return out


def importance_of(field_id: str, metrics_cfg: Optional[Dict[str, Any]] = None) -> str:
    cfg = metrics_cfg or load_metrics_config()
    imp = (cfg.get("importance") or {}).get(field_id)
    if imp:
        return str(imp).lower()
    return _DEFAULT_IMPORTANCE.get(field_id, "medium")


def allowed_importance(profile: str, metrics_cfg: Optional[Dict[str, Any]] = None) -> Set[str]:
    """Return set of importance levels included for a profile."""
    cfg = metrics_cfg or load_metrics_config()
    profile = (profile or "multi_way").lower()
    if profile in ("full", "all"):
        return {"high", "medium", "low"}
    if profile in ("pairwise", "pair", "ab", "a/b"):
        levels = (cfg.get("pairwise") or {}).get("include_importance") or _DEFAULT_PAIRWISE
    else:
        levels = (cfg.get("multi_way") or {}).get("include_importance") or _DEFAULT_MULTI_WAY
    return {str(x).lower() for x in levels}


def filter_field_ids(
    field_ids: Iterable[str],
    profile: str = "multi_way",
    metrics_cfg: Optional[Dict[str, Any]] = None,
) -> List[str]:
    cfg = metrics_cfg or load_metrics_config()
    allowed = allowed_importance(profile, cfg)
    return [f for f in field_ids if importance_of(f, cfg) in allowed]


def rank_by_field(metrics_cfg: Optional[Dict[str, Any]] = None) -> str:
    cfg = metrics_cfg or load_metrics_config()
    return str((cfg.get("multi_way") or {}).get("rank_by") or "total_median_ns")


# Columns for multi-way scientific summary (order matters for display)
MULTI_WAY_SUMMARY_FIELDS: Sequence[tuple] = (
    # (field_id, display title, is_time_ns, higher_is_better)
    ("total_median_ns", "Median total (µs)", True, False),
    ("ser_median_ns", "Median ser (µs)", True, False),
    ("deser_median_ns", "Median deser (µs)", True, False),
    ("avg_ops_per_sec", "Ops/s (from mean)", False, True),
    ("median_size_bytes", "Median size (B)", False, False),
    ("runs", "n", False, True),
    ("serializer_version", "Version", False, None),
    ("mean_fidelity", "Fidelity", False, True),
    ("effect_vs_fastest_cliffs_label", "δ vs fastest", False, None),
)
