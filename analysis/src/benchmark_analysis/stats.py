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
    """Load ``statistics:`` from master ``config/benchmark_config.yaml`` if available."""
    cfg = dict(_DEFAULT_STATS_CFG)
    try:
        from .config_loader import default_config_path, load_master_config

        path = Path(config_path) if config_path else default_config_path()
        data = load_master_config(path)
        stats = data.get("statistics") or {}
        for k, v in stats.items():
            if isinstance(v, dict) and isinstance(cfg.get(k), dict):
                merged = dict(cfg[k])
                merged.update(v)
                cfg[k] = merged
            else:
                cfg[k] = v
    except Exception as exc:  # malformed YAML / missing file should not break analysis
        print(f"Warning: could not load stats config: {exc}")

    # Surface limitations for declared-but-unimplemented settings
    boot = cfg.get("bootstrap") or {}
    if boot.get("method") not in (None, "percentile"):
        print(f"Note: bootstrap.method={boot.get('method')} requested but only 'percentile' is implemented; using percentile.")
    eff = cfg.get("effect_sizes") or {}
    if eff.get("methods") and set(eff["methods"]) != {"cliffs_delta", "hedges_g"}:
        print("Note: effect_sizes.methods partially supported; both cliffs_delta and hedges_g are always computed when enabled.")
    ht = cfg.get("hypothesis_tests") or {}
    if ht.get("method") and ht["method"] != "mann_whitney_u":
        print(
            f"Note: hypothesis_tests.method={ht['method']} requested; "
            "only mann_whitney_u is implemented."
        )
    return cfg


# ---------------------------------------------------------------------------
# Time unit normalization (central config baseline)
# ---------------------------------------------------------------------------

# Canonical scales: multiply raw CSV values by this factor to obtain nanoseconds.
_TIME_UNIT_TO_NS: Dict[str, float] = {
    "nanoseconds": 1.0,
    "ns": 1.0,
    "nanosecond": 1.0,
    "microseconds": 1_000.0,
    "us": 1_000.0,
    "µs": 1_000.0,
    "μs": 1_000.0,
    "microsecond": 1_000.0,
    "milliseconds": 1_000_000.0,
    "ms": 1_000_000.0,
    "millisecond": 1_000_000.0,
    "seconds": 1_000_000_000.0,
    "s": 1_000_000_000.0,
    "second": 1_000_000_000.0,
}

# Cache of language -> scale resolved from master config (cleared in tests via clear).
_time_scale_cache: Dict[str, float] = {}


def clear_time_scale_cache() -> None:
    """Test helper: drop cached time-unit scales."""
    _time_scale_cache.clear()


def time_unit_to_ns_scale(unit: str) -> float:
    """Convert a unit name (e.g. ``nanoseconds``) to a multiply-to-ns factor."""
    key = (unit or "nanoseconds").strip().lower()
    if key not in _TIME_UNIT_TO_NS:
        raise ValueError(
            f"Unknown time unit {unit!r}. Expected one of: "
            f"{', '.join(sorted(set(_TIME_UNIT_TO_NS)))}"
        )
    return _TIME_UNIT_TO_NS[key]


def resolve_time_scale_to_ns(
    language: Optional[str] = None,
    config_path: Optional[str] = None,
) -> float:
    """Resolve the CSV → nanoseconds scale from the master config.

    Preference order:
    1. ``languages.<lang>.time_unit`` when *language* is known
    2. ``csv_schema.time_unit`` (suite baseline; default ``nanoseconds``)

    All current harnesses emit nanoseconds; this central resolution guarantees
    stats tables and violin plots apply the *same* conversion.
    """
    cache_key = f"{language or ''}|{config_path or ''}"
    if cache_key in _time_scale_cache:
        return _time_scale_cache[cache_key]

    unit = "nanoseconds"
    try:
        from .config_loader import dig, language_entries, load_master_config

        data = load_master_config(config_path)
        unit = dig(data, "csv_schema.time_unit", "nanoseconds") or "nanoseconds"
        if language:
            block = language_entries(config_path).get(str(language).lower()) or {}
            lang_unit = block.get("time_unit")
            if lang_unit:
                unit = lang_unit
    except Exception as exc:
        print(f"Warning: could not resolve time unit from config ({exc}); assuming nanoseconds")
        unit = "nanoseconds"

    try:
        scale = time_unit_to_ns_scale(str(unit))
    except ValueError as exc:
        print(f"Warning: {exc}; assuming nanoseconds")
        scale = 1.0

    _time_scale_cache[cache_key] = scale
    return scale


def normalize_to_nanoseconds(
    value: float,
    language: Optional[str] = None,
    *,
    scale_to_ns: Optional[float] = None,
    config_path: Optional[str] = None,
) -> float:
    """Normalize a harness timing value to nanoseconds.

    Scale is resolved once from the master config (see
    :func:`resolve_time_scale_to_ns`). Callers that process many rows should
    pass an explicit ``scale_to_ns`` to avoid repeated config lookups.
    """
    if scale_to_ns is None:
        scale_to_ns = resolve_time_scale_to_ns(language, config_path=config_path)
    return float(value) * float(scale_to_ns)


# ---------------------------------------------------------------------------
# Outlier filtering
# ---------------------------------------------------------------------------

def _iqr_keep_mask(
    values: Sequence[float],
    iqr_k: float = 1.5,
    min_samples: int = 10,
) -> np.ndarray:
    """Boolean mask of non-outlier observations (Tukey fences).

    Returns all-True when the sample is too small, IQR is zero, or the mask
    would drop every observation (never empty a group silently).
    """
    arr = np.asarray(values, dtype=float)
    n = len(arr)
    if n < min_samples:
        return np.ones(n, dtype=bool)
    q1 = float(np.percentile(arr, 25))
    q3 = float(np.percentile(arr, 75))
    iqr = q3 - q1
    if iqr == 0:
        return np.ones(n, dtype=bool)
    lower = q1 - iqr_k * iqr
    upper = q3 + iqr_k * iqr
    mask = (arr >= lower) & (arr <= upper)
    if not mask.any():
        return np.ones(n, dtype=bool)
    return mask


def _filter_outliers(
    values: List[float],
    method: str = "iqr",
    iqr_k: float = 1.5,
    min_samples: int = 10,
) -> Tuple[List[float], int]:
    """Remove outliers from a single series; returns (filtered_values, removed_count).

    Prefer :func:`filter_outliers_paired` for benchmark rows that carry
    ser/deser/total measurements from the same repetition.
    """
    if method == "none" or len(values) < min_samples:
        return values, 0

    arr = np.asarray(values, dtype=float)
    if method == "winsorize":
        lo, hi = np.percentile(arr, [5, 95])
        wins = np.clip(arr, lo, hi)
        # Winsorization clips extreme values rather than removing them;
        # the sample size stays the same, so removed count is 0.
        return wins.tolist(), 0

    mask = _iqr_keep_mask(arr, iqr_k=iqr_k, min_samples=min_samples)
    filtered = arr[mask].tolist()
    return filtered, len(values) - len(filtered)


def filter_outliers_paired(
    times_ser: List[float],
    times_deser: List[float],
    times_total: List[float],
    method: str = "iqr",
    iqr_k: float = 1.5,
    min_samples: int = 10,
) -> Tuple[List[float], List[float], List[float], int]:
    """All-or-nothing row filter across ser / deser / total.

    A repetition is discarded if it is an IQR outlier on *any* of the three
    metrics. This preserves paired-sample correspondence required for
    ser↔deser correlation and for consistent n across table columns.

    Winsorize mode clips each series independently but never drops rows.
    """
    n = len(times_total)
    if not (len(times_ser) == len(times_deser) == n):
        raise ValueError(
            "times_ser, times_deser, and times_total must have equal length "
            f"(got {len(times_ser)}, {len(times_deser)}, {n})"
        )
    if method == "none" or n < min_samples:
        return times_ser, times_deser, times_total, 0

    arr_s = np.asarray(times_ser, dtype=float)
    arr_d = np.asarray(times_deser, dtype=float)
    arr_t = np.asarray(times_total, dtype=float)

    if method == "winsorize":
        def _w(a: np.ndarray) -> np.ndarray:
            lo, hi = np.percentile(a, [5, 95])
            return np.clip(a, lo, hi)

        return _w(arr_s).tolist(), _w(arr_d).tolist(), _w(arr_t).tolist(), 0

    # IQR (default): union of outlier flags → keep only rows that pass all three
    mask = (
        _iqr_keep_mask(arr_s, iqr_k=iqr_k, min_samples=min_samples)
        & _iqr_keep_mask(arr_d, iqr_k=iqr_k, min_samples=min_samples)
        & _iqr_keep_mask(arr_t, iqr_k=iqr_k, min_samples=min_samples)
    )
    if not mask.any():
        return times_ser, times_deser, times_total, 0

    removed = int((~mask).sum())
    return (
        arr_s[mask].tolist(),
        arr_d[mask].tolist(),
        arr_t[mask].tolist(),
        removed,
    )


def paired_keep_mask(
    times_ser: Sequence[float],
    times_deser: Sequence[float],
    times_total: Sequence[float],
    method: str = "iqr",
    iqr_k: float = 1.5,
    min_samples: int = 10,
) -> np.ndarray:
    """Boolean keep-mask for the all-or-nothing paired filter (same rules as
    :func:`filter_outliers_paired`)."""
    n = len(times_total)
    if method == "none" or method == "winsorize" or n < min_samples:
        return np.ones(n, dtype=bool)
    arr_s = np.asarray(times_ser, dtype=float)
    arr_d = np.asarray(times_deser, dtype=float)
    arr_t = np.asarray(times_total, dtype=float)
    mask = (
        _iqr_keep_mask(arr_s, iqr_k=iqr_k, min_samples=min_samples)
        & _iqr_keep_mask(arr_d, iqr_k=iqr_k, min_samples=min_samples)
        & _iqr_keep_mask(arr_t, iqr_k=iqr_k, min_samples=min_samples)
    )
    if not mask.any():
        return np.ones(n, dtype=bool)
    return mask


# ---------------------------------------------------------------------------
# Unified sanitize pipeline (feeds both tables and plots)
# ---------------------------------------------------------------------------

def analysis_group_key(r: Dict[str, Any], language_hint: Optional[str] = None) -> Tuple:
    """Group key for v1 and v2 CSVs.

    v1: (SerializerName, TestDataName, "", "", StringOrStream, Language)
    v2: includes TypeConfigHash and DataTypeInstanceCount when present.
    """
    lang = r.get("Language") or language_hint or "unknown"
    ic = r.get("DataTypeInstanceCount")
    if ic is None or ic == "":
        ic_key: Any = ""
    else:
        ic_key = ic
    return (
        r["SerializerName"],
        r["TestDataName"],
        r.get("TypeConfigHash") or "",
        ic_key,
        r["StringOrStream"],
        lang,
    )


def prepare_analysis_records(
    records: List[Dict],
    config: Optional[Dict[str, Any]] = None,
    language_hint: Optional[str] = None,
) -> Tuple[List[Dict], Dict[Tuple, Dict[str, int]]]:
    """Single pre-processing step for all analysis consumers.

    1. Resolve and apply time-unit normalization (config baseline).
    2. Drop warmup rows (``RepetitionIndex == 0`` when enabled).
    3. All-or-nothing paired IQR (or configured method) per group.

    This function is the **only** place that should drop warmup / outliers for
    published tables and plots. Language harnesses must write complete raw CSVs
    (every successful rep, including index 0) with no filtering on disk.

    Returns
    -------
    sanitized
        Row dicts with ``TimeSer`` / ``TimeDeser`` / ``TimeSerAndDeser`` in ns.
        Ready for aggregation *or* violin melting — same sample population.
    group_meta
        Per ``(serializer, test_data, mode, language)`` counters:
        ``warmup_skipped``, ``outliers_removed``, ``runs_raw``.
    """
    cfg = config or load_stats_config()
    exclude_warmup = cfg.get("exclude_warmup", True)
    outlier_method = cfg.get("outlier_method", "iqr")
    iqr_k = float(cfg.get("iqr_k", 1.5))
    min_out = int(cfg.get("min_samples_for_outlier_filter", 10))

    # language -> scale (resolved once)
    scale_by_lang: Dict[str, float] = {}

    def _scale_for(lang: str) -> float:
        if lang not in scale_by_lang:
            scale_by_lang[lang] = resolve_time_scale_to_ns(lang or None)
        return scale_by_lang[lang]

    # Bucket non-warmup rows by analysis group key
    buckets: Dict[Tuple, List[Dict]] = defaultdict(list)
    group_meta: Dict[Tuple, Dict[str, int]] = defaultdict(
        lambda: {"warmup_skipped": 0, "outliers_removed": 0, "runs_raw": 0}
    )

    for r in records:
        lang = (r.get("Language") or language_hint or "unknown") or "unknown"
        key = analysis_group_key(r, lang)
        group_meta[key]["runs_raw"] += 1

        if exclude_warmup and r.get("RepetitionIndex", 0) == 0:
            group_meta[key]["warmup_skipped"] += 1
            continue

        scale = _scale_for(lang)
        time_ser = normalize_to_nanoseconds(float(r["TimeSer"]), lang, scale_to_ns=scale)
        time_deser = normalize_to_nanoseconds(float(r["TimeDeser"]), lang, scale_to_ns=scale)
        raw_total = r.get("TimeSerAndDeser", r["TimeSer"] + r["TimeDeser"])
        time_total = normalize_to_nanoseconds(float(raw_total), lang, scale_to_ns=scale)

        rec = dict(r)
        rec["Language"] = lang
        rec["TimeSer"] = time_ser
        rec["TimeDeser"] = time_deser
        rec["TimeSerAndDeser"] = time_total
        buckets[key].append(rec)

    sanitized: List[Dict] = []
    for key, recs in buckets.items():
        ser = [float(x["TimeSer"]) for x in recs]
        deser = [float(x["TimeDeser"]) for x in recs]
        total = [float(x["TimeSerAndDeser"]) for x in recs]

        if outlier_method == "winsorize" and len(recs) >= min_out:
            s_f, d_f, t_f, rem = filter_outliers_paired(
                ser, deser, total, method="winsorize", iqr_k=iqr_k, min_samples=min_out
            )
            group_meta[key]["outliers_removed"] = rem
            for rec, ts, td, tt in zip(recs, s_f, d_f, t_f):
                out = dict(rec)
                out["TimeSer"] = ts
                out["TimeDeser"] = td
                out["TimeSerAndDeser"] = tt
                sanitized.append(out)
            continue

        mask = paired_keep_mask(
            ser, deser, total, method=outlier_method, iqr_k=iqr_k, min_samples=min_out
        )
        rem = int((~mask).sum())
        group_meta[key]["outliers_removed"] = rem
        for rec, keep in zip(recs, mask):
            if keep:
                sanitized.append(rec)

    return sanitized, dict(group_meta)


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
    *,
    pre_sanitized: bool = False,
    group_meta: Optional[Dict[Tuple, Dict[str, int]]] = None,
) -> Dict:
    """Compute aggregate statistics by (serializer, test_data, mode) [+ language].

    By default runs the unified :func:`prepare_analysis_records` pipeline so
    summary tables and violin plots share the same sample population. Pass
    ``pre_sanitized=True`` with already-cleaned records (and optional
    ``group_meta`` from that prepare call) to avoid double-filtering when the
    CLI sanitizes once and fans out to multiple consumers.
    """
    cfg = config or load_stats_config()
    outlier_method = cfg.get("outlier_method", "iqr")

    if pre_sanitized:
        clean = records
        meta = group_meta or {}
    else:
        clean, meta = prepare_analysis_records(
            records, config=cfg, language_hint=language_hint
        )

    stats = defaultdict(lambda: {
        "times_ser": [],
        "times_deser": [],
        "times_total": [],
        "sizes": [],
        "fidelity": [],
        "memory_peak": [],
        "language": None,
        "serializer_version": None,
    })

    for r in clean:
        lang = r.get("Language") or language_hint or "unknown"
        key = analysis_group_key(r, lang)
        # Times are already normalized to ns by prepare_analysis_records
        stats[key]["times_ser"].append(float(r["TimeSer"]))
        stats[key]["times_deser"].append(float(r["TimeDeser"]))
        stats[key]["times_total"].append(
            float(r.get("TimeSerAndDeser", r["TimeSer"] + r["TimeDeser"]))
        )
        stats[key]["sizes"].append(float(r["Size"]))
        stats[key]["language"] = lang
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

    # Include groups that were entirely warmup so counters still surface
    for key, m in meta.items():
        if key not in stats and m.get("runs_raw", 0) > 0:
            _ = stats[key]  # create empty bucket
            stats[key]["language"] = key[5]

    total_outliers = 0
    results: Dict = {}

    for key, data in stats.items():
        times_ser = data["times_ser"]
        times_deser = data["times_deser"]
        times_total = data["times_total"]
        m = meta.get(key) or {}
        rem_t = int(m.get("outliers_removed", 0))
        warmup_skipped = int(m.get("warmup_skipped", 0))
        runs_raw = int(m.get("runs_raw", len(times_total) + warmup_skipped + rem_t))
        total_outliers += rem_t

        ser_stats = _summarize_series(times_ser, cfg, "ser", group_key=key)
        deser_stats = _summarize_series(times_deser, cfg, "deser", group_key=key)
        total_stats = _summarize_series(times_total, cfg, "total", group_key=key)

        avg_time_total_ns = total_stats["total_mean_ns"]
        avg_ops_per_sec = 1e9 / avg_time_total_ns if avg_time_total_ns > 0 else 0.0
        min_ops = 1e9 / total_stats["total_max_ns"] if total_stats["total_max_ns"] > 0 else 0.0
        max_ops = 1e9 / total_stats["total_min_ns"] if total_stats["total_min_ns"] > 0 else 0.0

        sizes = data["sizes"]
        # key: (serializer, test_data, type_config_hash, instance_count, mode, language)
        entry = {
            "serializer": key[0],
            "test_data": key[1],
            "type_config_hash": key[2] or None,
            "data_type_instance_count": key[3] if key[3] != "" else None,
            "mode": key[4],
            "language": key[5],
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
            "runs_raw": runs_raw,
            "warmup_skipped": warmup_skipped,
            "outliers_removed": rem_t,
            # Extended scientific metrics
            **ser_stats,
            **deser_stats,
            **total_stats,
            "mean_fidelity": float(np.mean(data["fidelity"])) if data["fidelity"] else None,
            "mean_memory_peak_bytes": float(np.mean(data["memory_peak"])) if data["memory_peak"] else None,
            # Retain filtered series for effect-size / A-B (not serialized by default consumers)
            "_times_total_filtered": times_total,
        }
        results[key] = entry

    # Effect sizes: within (language, test_data, mode) compare each serializer to fastest mean
    if (cfg.get("effect_sizes") or {}).get("enabled", True):
        _attach_effect_sizes(results, cfg)

    total_warmup = sum(int((meta.get(k) or {}).get("warmup_skipped", 0)) for k in meta)
    # Also count from results when meta empty (pre_sanitized without meta)
    if not meta:
        total_warmup = sum(int(e.get("warmup_skipped", 0)) for e in results.values())
    if total_warmup:
        print(f"Skipped {total_warmup} warmup measurements (RepetitionIndex 0)")
    if total_outliers:
        print(f"Removed {total_outliers} outlier measurements ({outlier_method} filter)")
    return results


def _attach_effect_sizes(results: Dict, cfg: Dict[str, Any]) -> None:
    """Attach effect size vs fastest serializer in same (lang, data, instance, mode) group."""
    thr = (cfg.get("effect_sizes") or {}).get("cliffs_delta_thresholds")
    groups: Dict[Tuple, List[Any]] = defaultdict(list)
    for key, entry in results.items():
        gkey = (
            entry["language"],
            entry["test_data"],
            entry.get("type_config_hash"),
            entry.get("data_type_instance_count"),
            entry["mode"],
        )
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


