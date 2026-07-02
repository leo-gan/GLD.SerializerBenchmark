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
    # NOTE: report_* flags (mean/median/std/...) are declared in config for
    # documentation but are currently always computed (rich output is the
    # design goal). Changing them has no effect yet.
    "report_mean": True,
    "report_median": True,
    "report_std": True,
    "report_mad": True,
    "report_cv": True,
    "report_min_max": True,
    "bootstrap": {
        "enabled": True,
        "iterations": 2000,
        "confidence_level": 0.95,
        "seed": 42,
        # Only "percentile" is implemented. "bca" is accepted in config
        # but silently falls back to percentile.
        "method": "percentile",
    },
    "effect_sizes": {
        "enabled": True,
        # "methods" key accepted from config but both cliffs+hedges are always run.
        "methods": ["cliffs_delta", "hedges_g"],
        "cliffs_delta_thresholds": {
            "negligible": 0.147,
            "small": 0.33,
            "medium": 0.474,
        },
    },
    "hypothesis_tests": {
        "enabled": True,
        # Only mann_whitney_u is implemented.
        "method": "mann_whitney_u",
        "alpha": 0.05,
        "multiple_comparison_correction": "holm",
    },
    # throughput_from is documented but derivation is always 1e9/mean_time_ns.
    "throughput_from": "mean_time_ns",
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

    # Surface limitations for declared-but-unimplemented settings
    boot = cfg.get("bootstrap") or {}
    if boot.get("method") not in (None, "percentile"):
        print(f"Note: bootstrap.method={boot.get('method')} requested but only 'percentile' is implemented; using percentile.")
    eff = cfg.get("effect_sizes") or {}
    if eff.get("methods") and set(eff["methods"]) != {"cliffs_delta", "hedges_g"}:
        print("Note: effect_sizes.methods partially supported; both cliffs_delta and hedges_g are always computed when enabled.")
    ht = cfg.get("hypothesis_tests") or {}
    if ht.get("method") and ht["method"] != "mann_whitney_u":
        print(f"Note: hypothesis_tests.method={ht['method']} requested; only mann_whitney_u is implemented.")
    # csv_schema.time_unit and paths.* are intentionally not read here;
    # time normalization uses Language + heuristic; CLI discovers logs.
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
    """Percentile bootstrap CI. Returns (point_estimate, ci_low, ci_high).

    The caller should pass a *per-group* seed (derived from a stable hash of the
    group key + configured base seed) so that resamples are independent across
    different serializers / test cases. Using a constant seed for every group
    makes the CIs artificially correlated.
    """
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


def _derive_seed(base_seed: int, *key_parts: Any) -> int:
    """Derive a stable per-group seed from base seed + group identity.

    Ensures bootstrap replicates are independent across (serializer, data, mode, ...)
    while remaining fully reproducible given the same inputs.
    """
    import hashlib
    h = hashlib.sha256()
    h.update(str(base_seed).encode("utf-8"))
    for part in key_parts:
        h.update(str(part).encode("utf-8"))
        h.update(b"|")
    # Fold to a positive 32-bit int suitable for np.random.default_rng
    digest = int.from_bytes(h.digest()[:8], "little")
    return digest & 0xFFFFFFFF


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
    """Two-sided Mann-Whitney U with tie correction and continuity correction.

    Returns (U, p_value). Uses normal approximation with proper tie-adjusted
    variance (required when there are duplicate timings, common in benchmarks)
    and a continuity correction for better discrete approximation.

    If scipy is available, it is used for the authoritative result (it implements
    the exact tie correction); otherwise we fall back to our corrected formula.
    """
    a = np.asarray(x, dtype=float)
    b = np.asarray(y, dtype=float)
    n1, n2 = len(a), len(b)
    if n1 == 0 or n2 == 0:
        return 0.0, 1.0
    if n1 < 2 or n2 < 2:
        # Degenerate; not enough data for meaningful test
        return 0.0, 1.0

    # Try scipy first (authoritative, handles ties + exact options if wanted)
    try:
        from scipy.stats import mannwhitneyu as scipy_mwu
        # use='asymptotic' + method gives the normal approx we were doing; ties handled internally
        res = scipy_mwu(a, b, alternative="two-sided", method="asymptotic")
        return float(res.statistic), float(res.pvalue)
    except Exception:
        pass  # fall through to our implementation

    # --- Pure numpy implementation with full tie correction + continuity corr. ---
    combined = np.concatenate([a, b])
    N = n1 + n2
    order = combined.argsort(kind="mergesort")  # stable for tie detection
    ranks = np.empty_like(order, dtype=float)
    ranks[order] = np.arange(1, N + 1, dtype=float)

    # Average ties and accumulate tie correction sum(t^3 - t)
    sorted_vals = combined[order]
    tie_sum = 0.0
    i = 0
    while i < N:
        j = i
        while j < N and sorted_vals[j] == sorted_vals[i]:
            j += 1
        t = j - i
        if t > 1:
            avg = (i + 1 + j) / 2.0
            ranks[order[i:j]] = avg
            tie_sum += (t ** 3 - t)
        i = j

    r1 = float(np.sum(ranks[:n1]))
    u1 = r1 - n1 * (n1 + 1) / 2.0
    u2 = n1 * n2 - u1
    u = min(u1, u2)
    mu = n1 * n2 / 2.0

    # Tie-corrected variance
    # sigma^2 = (n1*n2/12) * ( (N+1) - sum(t^3-t)/(N*(N-1)) )
    var = (n1 * n2 / 12.0) * ( (N + 1) - tie_sum / (N * (N - 1) if N > 1 else 0) )
    if var <= 0:
        return float(u), 1.0
    sigma = np.sqrt(var)

    # Continuity correction for normal approximation of discrete U
    # z = ( |U - mu| - 0.5 ) / sigma
    z = (abs(u - mu) - 0.5) / sigma if sigma > 0 else 0.0

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
    group_key: Optional[Tuple] = None,
) -> Dict[str, float]:
    """Compute descriptive + bootstrap stats for one timing series.

    group_key (if given) is used together with the configured base seed to
    derive an independent per-group bootstrap seed.
    """
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
        base_seed = int(boot_cfg.get("seed", 42))
        if group_key is not None:
            per_group_seed = _derive_seed(base_seed, group_key, prefix)
        else:
            per_group_seed = base_seed
        _, lo, hi = bootstrap_ci(
            values,
            iterations=int(boot_cfg.get("iterations", 2000)),
            confidence_level=float(boot_cfg.get("confidence_level", 0.95)),
            seed=per_group_seed,
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
        raw_ser = data["times_ser"]
        raw_deser = data["times_deser"]
        raw_total = data["times_total"]

        # Filter *once* using the primary metric (total), then apply the *same*
        # kept indices to ser/deser/total. This preserves row correspondence
        # for paired (ser, deser) measurements from the same repetition.
        if outlier_method == "none" or len(raw_total) < min_out:
            times_total = raw_total
            times_ser = raw_ser
            times_deser = raw_deser
            rem_t = 0
        else:
            arr_t = np.asarray(raw_total, dtype=float)
            if outlier_method == "winsorize":
                lo, hi = np.percentile(arr_t, [5, 95])
                # Winsorize total; to keep correspondence we winsorize in place on copies
                times_total = np.clip(arr_t, lo, hi).tolist()
                times_ser = raw_ser[:]  # winsorize does not drop rows
                times_deser = raw_deser[:]
                rem_t = 0
            else:
                # IQR on total -> mask -> subset the three aligned series
                q1 = float(np.percentile(arr_t, 25))
                q3 = float(np.percentile(arr_t, 75))
                iqr = q3 - q1
                if iqr == 0:
                    times_total = raw_total
                    times_ser = raw_ser
                    times_deser = raw_deser
                    rem_t = 0
                else:
                    lower = q1 - iqr_k * iqr
                    upper = q3 + iqr_k * iqr
                    mask = (arr_t >= lower) & (arr_t <= upper)
                    times_total = arr_t[mask].tolist()
                    times_ser = [v for v, m in zip(raw_ser, mask) if m]
                    times_deser = [v for v, m in zip(raw_deser, mask) if m]
                    rem_t = int((~mask).sum())

        total_outliers += rem_t

        ser_stats = _summarize_series(times_ser, cfg, "ser", group_key=key)
        deser_stats = _summarize_series(times_deser, cfg, "deser", group_key=key)
        total_stats = _summarize_series(times_total, cfg, "total", group_key=key)

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


