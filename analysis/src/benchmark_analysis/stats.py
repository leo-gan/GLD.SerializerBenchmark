"""Scientific statistics computation for benchmark data.

Designed for publication-quality reporting:
- Warmup exclusion
- IQR outlier filtering (configurable)
- Mean/median/std/MAD/CV/percentiles
- Non-parametric bootstrap confidence intervals
- Cliff's delta and Hedges' g effect sizes
- Mann-Whitney U with Holm correction (optional A/B)
"""

from __future__ import annotations

from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

import numpy as np

# ---------------------------------------------------------------------------
# Config helpers (optional YAML; safe defaults if PyYAML / file missing)
# ---------------------------------------------------------------------------

_DEFAULT_STATS_CFG: Dict[str, Any] = {
    "exclude_warmup": True,
    "outlier_method": "iqr",
    "iqr_k": 1.5,
    "min_samples_for_outlier_filter": 10,
    "min_samples_for_inference": 5,
    "report_percentiles": [5, 25, 50, 75, 95, 99],
    "bootstrap": {
        "enabled": True,
        "iterations": 2000,
        "confidence_level": 0.95,
        "seed": 42,
        "method": "percentile",
    },
    "effect_sizes": {
        "enabled": True,
        "cliffs_delta_thresholds": {
            "negligible": 0.147,
            "small": 0.33,
            "medium": 0.474,
        },
    },
    "hypothesis_tests": {
        "enabled": True,
        "alpha": 0.05,
        "multiple_comparison_correction": "holm",
    },
}


def load_stats_config(config_path: Optional[str] = None) -> Dict[str, Any]:
    """Load statistics section from benchmark_config.yaml if available."""
    cfg = dict(_DEFAULT_STATS_CFG)
    candidates = []
    if config_path:
        candidates.append(Path(config_path))
    # Walk up from this file / cwd
    here = Path(__file__).resolve()
    for parent in [here.parent, *here.parents]:
        candidates.append(parent / "config" / "benchmark_config.yaml")
        candidates.append(parent.parent / "config" / "benchmark_config.yaml")
        candidates.append(parent.parent.parent / "config" / "benchmark_config.yaml")
    candidates.append(Path("config/benchmark_config.yaml"))
    candidates.append(Path("../config/benchmark_config.yaml"))
    candidates.append(Path("../../config/benchmark_config.yaml"))

    for path in candidates:
        try:
            if path.is_file():
                try:
                    import yaml  # type: ignore
                except ImportError:
                    break
                with open(path, encoding="utf-8") as f:
                    data = yaml.safe_load(f) or {}
                stats = data.get("statistics") or {}
                # Shallow-merge top-level keys; deep-merge known subdicts
                for k, v in stats.items():
                    if isinstance(v, dict) and isinstance(cfg.get(k), dict):
                        merged = dict(cfg[k])
                        merged.update(v)
                        cfg[k] = merged
                    else:
                        cfg[k] = v
                break
        except OSError:
            continue
        except Exception as exc:  # malformed YAML should not break analysis defaults
            print(f"Warning: could not load stats config from {path}: {exc}")
            continue
    return cfg


# ---------------------------------------------------------------------------
# Time unit normalization
# ---------------------------------------------------------------------------

def normalize_to_nanoseconds(value: float, language: Optional[str] = None) -> float:
    """Convert a raw timing value (from CSV) to nanoseconds.

    Prefers explicit Language column (or hint). Falls back to numeric heuristic
    only for legacy data without language info. This is the single source of
    truth for time-unit normalization so that stats and plots agree.
    """
    if language:
        lang = language.lower().strip()
        if lang in ("csharp", "c#", "cs", "dotnet", "c-sharp"):
            return float(value) * 100.0
        if lang in ("python", "rust", "c", "javascript", "js", "node", "go", "java", "cpp"):
            return float(value)
    # Heuristic fallback (legacy CSVs without Language column)
    v = float(value)
    if v > 1_000_000:
        return v * 100.0  # C# ticks
    return v


def _detect_time_unit(time_value: int, language: Optional[str] = None) -> float:
    """Deprecated wrapper kept for test compatibility. Use normalize_to_nanoseconds."""
    return normalize_to_nanoseconds(time_value, language)


# ---------------------------------------------------------------------------
# Outlier filtering
# ---------------------------------------------------------------------------

def _filter_outliers(
    values: List[float],
    method: str = "iqr",
    iqr_k: float = 1.5,
    min_samples: int = 10,
) -> Tuple[List[float], int]:
    """Remove outliers; returns (filtered_values, removed_count)."""
    if method == "none" or len(values) < min_samples:
        return values, 0

    arr = np.asarray(values, dtype=float)
    if method == "winsorize":
        lo, hi = np.percentile(arr, [5, 95])
        wins = np.clip(arr, lo, hi)
        # Winsorization clips extreme values rather than removing them;
        # the sample size stays the same, so removed count is 0.
        return wins.tolist(), 0

    # IQR (default)
    q1 = float(np.percentile(arr, 25))
    q3 = float(np.percentile(arr, 75))
    iqr = q3 - q1
    lower = q1 - iqr_k * iqr
    upper = q3 + iqr_k * iqr
    mask = (arr >= lower) & (arr <= upper)
    if iqr == 0 or not mask.any():
        return values, 0
    filtered = arr[mask].tolist()
    return filtered, len(values) - len(filtered)


# ---------------------------------------------------------------------------
# Bootstrap CI
# ---------------------------------------------------------------------------

def bootstrap_ci(
    values: Sequence[float],
    iterations: int = 2000,
    confidence_level: float = 0.95,
    seed: int = 42,
    statistic: str = "mean",
) -> Tuple[float, float, float]:
    """Percentile bootstrap CI. Returns (point_estimate, ci_low, ci_high)."""
    arr = np.asarray(values, dtype=float)
    n = len(arr)
    if n == 0:
        return 0.0, 0.0, 0.0
    if n == 1:
        v = float(arr[0])
        return v, v, v

    rng = np.random.default_rng(seed)
    if statistic == "median":
        point = float(np.median(arr))
        stat_fn = np.median
    else:
        point = float(np.mean(arr))
        stat_fn = np.mean

    # Vectorized bootstrap
    idx = rng.integers(0, n, size=(iterations, n))
    samples = arr[idx]
    boot_stats = stat_fn(samples, axis=1)
    alpha = 1.0 - confidence_level
    lo = float(np.percentile(boot_stats, 100 * alpha / 2))
    hi = float(np.percentile(boot_stats, 100 * (1 - alpha / 2)))
    return point, lo, hi


# ---------------------------------------------------------------------------
# Effect sizes
# ---------------------------------------------------------------------------

def cliffs_delta(x: Sequence[float], y: Sequence[float]) -> float:
    """Cliff's delta: P(x > y) - P(x < y). Range [-1, 1].

    Positive => x tends to be larger than y (x is slower if x=times).
    """
    a = np.asarray(x, dtype=float)
    b = np.asarray(y, dtype=float)
    if len(a) == 0 or len(b) == 0:
        return 0.0
    # Efficient pairwise via broadcasting for moderate n
    if len(a) * len(b) <= 2_000_000:
        diff = a[:, None] - b[None, :]
        gt = np.sum(diff > 0)
        lt = np.sum(diff < 0)
        return float((gt - lt) / (len(a) * len(b)))
    # Fallback sampling for huge arrays
    rng = np.random.default_rng(0)
    n_pairs = 100_000
    ia = rng.integers(0, len(a), n_pairs)
    ib = rng.integers(0, len(b), n_pairs)
    d = a[ia] - b[ib]
    gt = np.sum(d > 0)
    lt = np.sum(d < 0)
    return float((gt - lt) / n_pairs)


def cliffs_delta_label(delta: float, thresholds: Optional[Dict[str, float]] = None) -> str:
    thr = thresholds or {"negligible": 0.147, "small": 0.33, "medium": 0.474}
    ad = abs(delta)
    if ad < thr["negligible"]:
        return "negligible"
    if ad < thr["small"]:
        return "small"
    if ad < thr["medium"]:
        return "medium"
    return "large"


def hedges_g(x: Sequence[float], y: Sequence[float]) -> float:
    """Hedges' g (bias-corrected Cohen's d) for two independent samples."""
    a = np.asarray(x, dtype=float)
    b = np.asarray(y, dtype=float)
    n1, n2 = len(a), len(b)
    if n1 < 2 or n2 < 2:
        return 0.0
    m1, m2 = float(np.mean(a)), float(np.mean(b))
    s1, s2 = float(np.std(a, ddof=1)), float(np.std(b, ddof=1))
    pooled_var = ((n1 - 1) * s1 ** 2 + (n2 - 1) * s2 ** 2) / (n1 + n2 - 2)
    if pooled_var <= 0:
        return 0.0
    d = (m1 - m2) / np.sqrt(pooled_var)
    # Small-sample correction
    df = n1 + n2 - 2
    if df > 0:
        j = 1.0 - (3.0 / (4.0 * df - 1.0))
        d *= j
    return float(d)


# ---------------------------------------------------------------------------
# Hypothesis tests
# ---------------------------------------------------------------------------

def mann_whitney_u(x: Sequence[float], y: Sequence[float]) -> Tuple[float, float]:
    """Two-sided Mann-Whitney U; returns (U, p_value). Uses normal approx."""
    a = np.asarray(x, dtype=float)
    b = np.asarray(y, dtype=float)
    n1, n2 = len(a), len(b)
    if n1 == 0 or n2 == 0:
        return 0.0, 1.0
    # Rank all
    combined = np.concatenate([a, b])
    order = combined.argsort()
    ranks = np.empty_like(order, dtype=float)
    ranks[order] = np.arange(1, len(combined) + 1, dtype=float)
    # Average ties
    sorted_vals = combined[order]
    i = 0
    while i < len(sorted_vals):
        j = i
        while j < len(sorted_vals) and sorted_vals[j] == sorted_vals[i]:
            j += 1
        if j - i > 1:
            avg = (i + 1 + j) / 2.0
            ranks[order[i:j]] = avg
        i = j
    r1 = float(np.sum(ranks[:n1]))
    u1 = r1 - n1 * (n1 + 1) / 2.0
    u2 = n1 * n2 - u1
    u = min(u1, u2)
    mu = n1 * n2 / 2.0
    sigma = np.sqrt(n1 * n2 * (n1 + n2 + 1) / 12.0)
    if sigma == 0:
        return float(u), 1.0
    z = (u - mu) / sigma
    # Two-sided normal p-value
    from math import erfc, sqrt
    p = erfc(abs(z) / sqrt(2.0))
    return float(u), float(min(1.0, p))


def holm_correction(p_values: List[float]) -> List[float]:
    """Holm–Bonferroni step-down adjusted p-values."""
    m = len(p_values)
    if m == 0:
        return []
    indexed = sorted(enumerate(p_values), key=lambda t: t[1])
    adjusted = [0.0] * m
    prev = 0.0
    for rank, (orig_i, p) in enumerate(indexed):
        adj = (m - rank) * p
        adj = max(prev, min(1.0, adj))
        adjusted[orig_i] = adj
        prev = adj
    return adjusted


# ---------------------------------------------------------------------------
# Core aggregation
# ---------------------------------------------------------------------------

def _mad(values: np.ndarray) -> float:
    med = np.median(values)
    return float(np.median(np.abs(values - med)))


def _summarize_series(
    values: List[float],
    cfg: Dict[str, Any],
    prefix: str,
) -> Dict[str, float]:
    """Compute descriptive + bootstrap stats for one timing series."""
    out: Dict[str, float] = {}
    if not values:
        out[f"{prefix}_mean_ns"] = 0.0
        out[f"{prefix}_median_ns"] = 0.0
        out[f"{prefix}_std_ns"] = 0.0
        out[f"{prefix}_mad_ns"] = 0.0
        out[f"{prefix}_cv"] = 0.0
        out[f"{prefix}_ci_low_ns"] = 0.0
        out[f"{prefix}_ci_high_ns"] = 0.0
        out[f"{prefix}_min_ns"] = 0.0
        out[f"{prefix}_max_ns"] = 0.0
        return out

    arr = np.asarray(values, dtype=float)
    mean_v = float(np.mean(arr))
    med_v = float(np.median(arr))
    std_v = float(np.std(arr, ddof=1)) if len(arr) > 1 else 0.0
    mad_v = _mad(arr)
    cv = std_v / mean_v if mean_v > 0 else 0.0

    out[f"{prefix}_mean_ns"] = mean_v
    out[f"{prefix}_median_ns"] = med_v
    out[f"{prefix}_std_ns"] = std_v
    out[f"{prefix}_mad_ns"] = mad_v
    out[f"{prefix}_cv"] = cv
    out[f"{prefix}_min_ns"] = float(np.min(arr))
    out[f"{prefix}_max_ns"] = float(np.max(arr))

    for p in cfg.get("report_percentiles", [5, 25, 50, 75, 95, 99]):
        out[f"{prefix}_p{int(p)}_ns"] = float(np.percentile(arr, p))

    boot_cfg = cfg.get("bootstrap") or {}
    if boot_cfg.get("enabled", True) and len(arr) >= cfg.get("min_samples_for_inference", 5):
        _, lo, hi = bootstrap_ci(
            values,
            iterations=int(boot_cfg.get("iterations", 2000)),
            confidence_level=float(boot_cfg.get("confidence_level", 0.95)),
            seed=int(boot_cfg.get("seed", 42)),
            statistic="mean",
        )
        out[f"{prefix}_ci_low_ns"] = lo
        out[f"{prefix}_ci_high_ns"] = hi
    else:
        out[f"{prefix}_ci_low_ns"] = mean_v
        out[f"{prefix}_ci_high_ns"] = mean_v

    return out


def compute_statistics(
    records: List[Dict],
    config: Optional[Dict[str, Any]] = None,
    language_hint: Optional[str] = None,
) -> Dict:
    """Compute aggregate statistics by (serializer, test_data, mode) [+ language]."""
    cfg = config or load_stats_config()
    stats = defaultdict(lambda: {
        "times_ser": [],
        "times_deser": [],
        "times_total": [],
        "sizes": [],
        "fidelity": [],
        "memory_peak": [],
        "warmup_skipped": 0,
        "language": None,
        "serializer_version": None,
    })

    exclude_warmup = cfg.get("exclude_warmup", True)

    for r in records:
        lang = r.get("Language") or language_hint or ""
        key = (r["SerializerName"], r["TestDataName"], r["StringOrStream"], lang or "unknown")

        if exclude_warmup and r.get("RepetitionIndex", 0) == 0:
            stats[key]["warmup_skipped"] += 1
            continue

        time_ser_ns = normalize_to_nanoseconds(float(r["TimeSer"]), lang or None)
        time_deser_ns = normalize_to_nanoseconds(float(r["TimeDeser"]), lang or None)
        time_total_ns = normalize_to_nanoseconds(
            float(r.get("TimeSerAndDeser", r["TimeSer"] + r["TimeDeser"])), lang or None
        )

        stats[key]["times_ser"].append(time_ser_ns)
        stats[key]["times_deser"].append(time_deser_ns)
        stats[key]["times_total"].append(time_total_ns)
        stats[key]["sizes"].append(float(r["Size"]))
        stats[key]["language"] = lang or "unknown"
        if r.get("SerializerVersion"):
            stats[key]["serializer_version"] = r["SerializerVersion"]
        if "FidelityScore" in r and r["FidelityScore"] is not None:
            try:
                stats[key]["fidelity"].append(float(r["FidelityScore"]))
            except (TypeError, ValueError):
                pass
        if "MemoryPeakBytes" in r and r["MemoryPeakBytes"] is not None:
            try:
                stats[key]["memory_peak"].append(float(r["MemoryPeakBytes"]))
            except (TypeError, ValueError):
                pass

    outlier_method = cfg.get("outlier_method", "iqr")
    iqr_k = float(cfg.get("iqr_k", 1.5))
    min_out = int(cfg.get("min_samples_for_outlier_filter", 10))
    total_outliers = 0
    results: Dict = {}

    for key, data in stats.items():
        times_total, rem_t = _filter_outliers(
            data["times_total"], outlier_method, iqr_k, min_out
        )
        times_ser, _ = _filter_outliers(data["times_ser"], outlier_method, iqr_k, min_out)
        times_deser, _ = _filter_outliers(data["times_deser"], outlier_method, iqr_k, min_out)
        total_outliers += rem_t

        ser_stats = _summarize_series(times_ser, cfg, "ser")
        deser_stats = _summarize_series(times_deser, cfg, "deser")
        total_stats = _summarize_series(times_total, cfg, "total")

        avg_time_total_ns = total_stats["total_mean_ns"]
        avg_ops_per_sec = 1e9 / avg_time_total_ns if avg_time_total_ns > 0 else 0.0
        min_ops = 1e9 / total_stats["total_max_ns"] if total_stats["total_max_ns"] > 0 else 0.0
        max_ops = 1e9 / total_stats["total_min_ns"] if total_stats["total_min_ns"] > 0 else 0.0

        sizes = data["sizes"]
        entry = {
            "serializer": key[0],
            "test_data": key[1],
            "mode": key[2],
            "language": key[3],
            "serializer_version": data["serializer_version"],
            # Backward-compatible primary metrics
            "avg_time_ser_ns": ser_stats["ser_mean_ns"],
            "avg_time_deser_ns": deser_stats["deser_mean_ns"],
            "avg_time_total_ns": avg_time_total_ns,
            "median_size_bytes": float(np.median(sizes)) if sizes else 0.0,
            "avg_ops_per_sec": avg_ops_per_sec,
            "min_ops_per_sec": min_ops,
            "max_ops_per_sec": max_ops,
            "runs": len(times_total),
            "runs_raw": len(data["times_total"]) + data["warmup_skipped"],
            "warmup_skipped": data["warmup_skipped"],
            "outliers_removed": rem_t,
            # Extended scientific metrics
            **ser_stats,
            **deser_stats,
            **total_stats,
            "mean_fidelity": float(np.mean(data["fidelity"])) if data["fidelity"] else None,
            "mean_memory_peak_bytes": float(np.mean(data["memory_peak"])) if data["memory_peak"] else None,
            # Retain raw filtered series for effect-size / A-B (not serialized to JSON by default consumers)
            "_times_total_filtered": times_total,
        }
        results[key] = entry

    # Effect sizes: within (language, test_data, mode) compare each serializer to fastest mean
    if (cfg.get("effect_sizes") or {}).get("enabled", True):
        _attach_effect_sizes(results, cfg)

    total_warmup = sum(d["warmup_skipped"] for d in stats.values())
    if total_warmup:
        print(f"Skipped {total_warmup} warmup measurements (RepetitionIndex 0)")
    if total_outliers:
        print(f"Removed {total_outliers} outlier measurements ({outlier_method} filter)")
    return results


def _attach_effect_sizes(results: Dict, cfg: Dict[str, Any]) -> None:
    """Attach effect size vs fastest serializer in same (lang, data, mode) group."""
    thr = (cfg.get("effect_sizes") or {}).get("cliffs_delta_thresholds")
    groups: Dict[Tuple, List[Any]] = defaultdict(list)
    for key, entry in results.items():
        gkey = (entry["language"], entry["test_data"], entry["mode"])
        groups[gkey].append((key, entry))

    for gkey, items in groups.items():
        if len(items) < 2:
            for _, entry in items:
                entry["effect_vs_fastest_cliffs_delta"] = 0.0
                entry["effect_vs_fastest_cliffs_label"] = "reference"
                entry["effect_vs_fastest_hedges_g"] = 0.0
                entry["fastest_in_group"] = entry["serializer"]
            continue
        fastest_key, fastest_entry = min(items, key=lambda t: t[1]["avg_time_total_ns"] or float("inf"))
        fast_times = fastest_entry.get("_times_total_filtered") or []
        for key, entry in items:
            entry["fastest_in_group"] = fastest_entry["serializer"]
            if key == fastest_key:
                entry["effect_vs_fastest_cliffs_delta"] = 0.0
                entry["effect_vs_fastest_cliffs_label"] = "reference"
                entry["effect_vs_fastest_hedges_g"] = 0.0
                continue
            mine = entry.get("_times_total_filtered") or []
            cd = cliffs_delta(mine, fast_times)
            hg = hedges_g(mine, fast_times)
            entry["effect_vs_fastest_cliffs_delta"] = cd
            entry["effect_vs_fastest_cliffs_label"] = cliffs_delta_label(cd, thr)
            entry["effect_vs_fastest_hedges_g"] = hg


def compare_versions(
    stats_a: Dict,
    stats_b: Dict,
    config: Optional[Dict[str, Any]] = None,
) -> List[Dict[str, Any]]:
    """Compare two result sets (e.g., serializer v1 vs v2) with Mann-Whitney + effect sizes.

    Keys are matched on (serializer, test_data, mode, language).
    """
    cfg = config or load_stats_config()
    ht = cfg.get("hypothesis_tests") or {}
    alpha = float(ht.get("alpha", 0.05))
    comparisons: List[Dict[str, Any]] = []
    p_vals: List[float] = []

    common_keys = set(stats_a.keys()) & set(stats_b.keys())
    for key in sorted(common_keys, key=str):
        a, b = stats_a[key], stats_b[key]
        ta = a.get("_times_total_filtered") or []
        tb = b.get("_times_total_filtered") or []
        if len(ta) < 2 or len(tb) < 2:
            continue
        u, p = mann_whitney_u(ta, tb)
        cd = cliffs_delta(ta, tb)
        hg = hedges_g(ta, tb)
        ratio = (a["avg_time_total_ns"] / b["avg_time_total_ns"]) if b["avg_time_total_ns"] else float("inf")
        rec = {
            "key": key,
            "serializer": a["serializer"],
            "test_data": a["test_data"],
            "mode": a["mode"],
            "language": a.get("language"),
            "mean_a_ns": a["avg_time_total_ns"],
            "mean_b_ns": b["avg_time_total_ns"],
            "ratio_a_over_b": ratio,
            "pct_change": (ratio - 1.0) * 100.0 if ratio != float("inf") else None,
            "mann_whitney_u": u,
            "p_value": p,
            "cliffs_delta": cd,
            "cliffs_label": cliffs_delta_label(cd, (cfg.get("effect_sizes") or {}).get("cliffs_delta_thresholds")),
            "hedges_g": hg,
            "significant": p < alpha,
        }
        comparisons.append(rec)
        p_vals.append(p)

    if ht.get("multiple_comparison_correction") == "holm" and p_vals:
        adjusted = holm_correction(p_vals)
        for rec, adj in zip(comparisons, adjusted):
            rec["p_value_holm"] = adj
            rec["significant_holm"] = adj < alpha

    return comparisons


