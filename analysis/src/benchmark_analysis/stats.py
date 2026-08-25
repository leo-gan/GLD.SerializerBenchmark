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

# Named filter policies exported for dashboard outlier research.
# Keys are stable API ids; criteria are fixed (not taken from YAML outlier_method).
FILTER_POLICY_IDS: Tuple[str, ...] = (
    "all",
    "iqr_1.5",
    "iqr_3",
    "winsorize_5_95",
)
DEFAULT_FILTER_POLICY = "iqr_1.5"

FILTER_POLICY_SPECS: Dict[str, Dict[str, Any]] = {
    "all": {
        "label": "All trials (post-warmup)",
        "description": (
            "Every measured repetition after warmup exclusion. "
            "No IQR drop and no winsorization — includes GC and scheduler tails."
        ),
        "outlier_method": "none",
        "iqr_k": None,
        "winsorize_percentiles": None,
        "paired": None,
    },
    "iqr_1.5": {
        "label": "IQR k=1.5 (strict / default)",
        "description": (
            "Tukey fences with k=1.5 on serialize, deserialize, and total; "
            "a repetition is dropped if it is an outlier on any of the three (paired)."
        ),
        "outlier_method": "iqr",
        "iqr_k": 1.5,
        "winsorize_percentiles": None,
        "paired": True,
    },
    "iqr_3": {
        "label": "IQR k=3 (loose)",
        "description": (
            "Same paired IQR rule as iqr_1.5 but with k=3 so only extreme stalls "
            "are removed; bulk tail mass is retained."
        ),
        "outlier_method": "iqr",
        "iqr_k": 3.0,
        "winsorize_percentiles": None,
        "paired": True,
    },
    "winsorize_5_95": {
        "label": "Winsorize 5–95%",
        "description": (
            "Clip each of ser/deser/total independently at the 5th and 95th "
            "percentiles; sample size is unchanged (no rows dropped)."
        ),
        "outlier_method": "winsorize",
        "iqr_k": None,
        "winsorize_percentiles": [5.0, 95.0],
        "paired": False,
    },
}

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
        # Effect vs fastest within each (lang, data, n, mode) group
        "vs_fastest": {
            "reference": "median",  # mean | median
            "test": "mann_whitney_u",
            "multiple_comparison": "holm",  # none | holm
            "exploratory_in_multi_way": True,
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
                for sk, sv in v.items():
                    if isinstance(sv, dict) and isinstance(merged.get(sk), dict):
                        nested = dict(merged[sk])
                        nested.update(sv)
                        merged[sk] = nested
                    else:
                        merged[sk] = sv
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

    All current benchmark runners emit nanoseconds; this central resolution guarantees
    stats tables and latency distributions apply the *same* conversion.
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
    """Normalize a benchmark-runner timing value to nanoseconds.

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
    published tables and plots. Language benchmark runners must write complete raw CSVs
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
    group_meta: Dict[Tuple, Dict[str, Any]] = defaultdict(
        lambda: {
            "warmup_skipped": 0,
            "outliers_removed": 0,
            "values_clipped": 0,
            "runs_raw": 0,
            "fence_total_low_ns": None,
            "fence_total_high_ns": None,
            "fence_ser_low_ns": None,
            "fence_ser_high_ns": None,
            "fence_deser_low_ns": None,
            "fence_deser_high_ns": None,
        }
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

        if outlier_method == "iqr" and len(recs) >= min_out:
            for series, lo_k, hi_k in (
                (ser, "fence_ser_low_ns", "fence_ser_high_ns"),
                (deser, "fence_deser_low_ns", "fence_deser_high_ns"),
                (total, "fence_total_low_ns", "fence_total_high_ns"),
            ):
                lo, hi = _iqr_fence_bounds(series, iqr_k=iqr_k, min_samples=min_out)
                group_meta[key][lo_k] = lo
                group_meta[key][hi_k] = hi

        if outlier_method == "winsorize" and len(recs) >= min_out:
            s_f, d_f, t_f, rem = filter_outliers_paired(
                ser, deser, total, method="winsorize", iqr_k=iqr_k, min_samples=min_out
            )
            group_meta[key]["outliers_removed"] = rem  # always 0 for winsorize
            clipped_rows = sum(
                1
                for i in range(len(ser))
                if ser[i] != s_f[i] or deser[i] != d_f[i] or total[i] != t_f[i]
            )
            group_meta[key]["values_clipped"] = int(clipped_rows)
            # Store clip bounds from total (and ser/deser) for provenance
            for series, lo_k, hi_k in (
                (ser, "fence_ser_low_ns", "fence_ser_high_ns"),
                (deser, "fence_deser_low_ns", "fence_deser_high_ns"),
                (total, "fence_total_low_ns", "fence_total_high_ns"),
            ):
                arr = np.asarray(series, dtype=float)
                lo, hi = np.percentile(arr, [5, 95])
                group_meta[key][lo_k] = float(lo)
                group_meta[key][hi_k] = float(hi)
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
        group_meta[key]["values_clipped"] = 0
        for rec, keep in zip(recs, mask):
            if keep:
                sanitized.append(rec)

    return sanitized, dict(group_meta)


def _iqr_fence_bounds(
    values: Sequence[float],
    iqr_k: float = 1.5,
    min_samples: int = 10,
) -> Tuple[Optional[float], Optional[float]]:
    """Return (lower, upper) Tukey fences, or (None, None) if not applicable."""
    arr = np.asarray(values, dtype=float)
    n = len(arr)
    if n < min_samples:
        return None, None
    q1 = float(np.percentile(arr, 25))
    q3 = float(np.percentile(arr, 75))
    iqr = q3 - q1
    if iqr == 0:
        return None, None
    return q1 - iqr_k * iqr, q3 + iqr_k * iqr


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
    summary tables and latency distributions share the same sample population. Pass
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
        "stream_modes": [],
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
        if r.get("StreamMode"):
            stats[key]["stream_modes"].append(str(r["StreamMode"]).strip())
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
        values_clipped = int(m.get("values_clipped", 0))
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
            "values_clipped": values_clipped,
            # Extended scientific metrics
            **ser_stats,
            **deser_stats,
            **total_stats,
            "mean_fidelity": float(np.mean(data["fidelity"])) if data["fidelity"] else None,
            "mean_memory_peak_bytes": float(np.mean(data["memory_peak"])) if data["memory_peak"] else None,
            # Retain filtered series for effect-size / A-B (not serialized by default consumers)
            "_times_total_filtered": times_total,
        }
        entry["filter"] = _build_filter_block(
            policy_id=m.get("filter_policy"),
            cfg=cfg,
            entry=entry,
            meta=m,
        )
        # B-6: majority StreamMode label for this group (stream I/O rows)
        sms = [s for s in (data.get("stream_modes") or []) if s]
        if sms:
            # mode() for majority; stable fallback
            try:
                from collections import Counter

                entry["StreamMode"] = Counter(sms).most_common(1)[0][0]
            except Exception:
                entry["StreamMode"] = sms[0]
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


def config_for_filter_policy(
    base_config: Optional[Dict[str, Any]],
    policy_id: str,
) -> Dict[str, Any]:
    """Return a stats config with outlier settings forced to a named policy."""
    if policy_id not in FILTER_POLICY_SPECS:
        raise ValueError(
            f"Unknown filter policy {policy_id!r}; expected one of {list(FILTER_POLICY_SPECS)}"
        )
    cfg = dict(base_config or load_stats_config())
    spec = FILTER_POLICY_SPECS[policy_id]
    cfg["outlier_method"] = spec["outlier_method"]
    if spec.get("iqr_k") is not None:
        cfg["iqr_k"] = float(spec["iqr_k"])
    return cfg


def filter_policy_catalog() -> Dict[str, Dict[str, Any]]:
    """Public catalog of filter policies (no internal-only fields)."""
    out: Dict[str, Dict[str, Any]] = {}
    for pid, spec in FILTER_POLICY_SPECS.items():
        out[pid] = {
            "id": pid,
            "label": spec["label"],
            "description": spec["description"],
            "outlier_method": spec["outlier_method"],
            "iqr_k": spec.get("iqr_k"),
            "winsorize_percentiles": spec.get("winsorize_percentiles"),
            "paired": spec.get("paired"),
            "min_samples_for_outlier_filter": _DEFAULT_STATS_CFG[
                "min_samples_for_outlier_filter"
            ],
            "exclude_warmup": _DEFAULT_STATS_CFG["exclude_warmup"],
        }
    return out


def _infer_policy_id(cfg: Dict[str, Any]) -> Optional[str]:
    method = str(cfg.get("outlier_method") or "iqr").lower()
    if method == "none":
        return "all"
    if method == "winsorize":
        return "winsorize_5_95"
    if method == "iqr":
        k = float(cfg.get("iqr_k", 1.5))
        if abs(k - 1.5) < 1e-9:
            return "iqr_1.5"
        if abs(k - 3.0) < 1e-9:
            return "iqr_3"
    return None


# Group identity fields shared across filter-policy variants (schema 2.2).
_EXPORT_IDENTITY_KEYS: Tuple[str, ...] = (
    "serializer",
    "test_data",
    "type_config_hash",
    "data_type_instance_count",
    "mode",
    "language",
    "serializer_version",
)


def _build_filter_block(
    policy_id: Optional[str],
    cfg: Dict[str, Any],
    entry: Dict[str, Any],
    meta: Dict[str, Any],
    *,
    include_catalog_text: bool = False,
) -> Dict[str, Any]:
    """Provenance block describing how this group's sample was filtered.

    By default omits ``label`` / ``description`` (schema 2.2 recommendation D):
    those live once in ``filter_policies``. Pass ``include_catalog_text=True``
    for in-memory full blocks (e.g. multi_policy before export slim).
    """
    pid = policy_id or _infer_policy_id(cfg)
    spec = FILTER_POLICY_SPECS.get(pid or "", {})
    method = str(cfg.get("outlier_method") or spec.get("outlier_method") or "iqr")
    iqr_k = cfg.get("iqr_k") if method == "iqr" else spec.get("iqr_k")
    winsor = (
        list(spec.get("winsorize_percentiles") or [5.0, 95.0])
        if method == "winsorize"
        else None
    )
    paired = spec.get("paired")
    if paired is None and method == "iqr":
        paired = True
    if method == "winsorize":
        paired = False
    if method == "none":
        paired = None

    block: Dict[str, Any] = {
        "policy": pid,
        "method": method,
        "iqr_k": float(iqr_k) if iqr_k is not None and method == "iqr" else None,
        "winsorize_percentiles": winsor,
        "paired": paired,
        "exclude_warmup": bool(cfg.get("exclude_warmup", True)),
        "min_samples_for_outlier_filter": int(
            cfg.get("min_samples_for_outlier_filter", 10)
        ),
        "runs_raw": int(entry.get("runs_raw") or 0),
        "warmup_skipped": int(entry.get("warmup_skipped") or 0),
        "runs_kept": int(entry.get("runs") or 0),
        "outliers_removed": int(entry.get("outliers_removed") or 0),
        "values_clipped": int(entry.get("values_clipped") or 0),
        "fence_total_low_ns": meta.get("fence_total_low_ns"),
        "fence_total_high_ns": meta.get("fence_total_high_ns"),
        "fence_ser_low_ns": meta.get("fence_ser_low_ns"),
        "fence_ser_high_ns": meta.get("fence_ser_high_ns"),
        "fence_deser_low_ns": meta.get("fence_deser_low_ns"),
        "fence_deser_high_ns": meta.get("fence_deser_high_ns"),
    }
    if include_catalog_text:
        block["label"] = spec.get("label") or method
        block["description"] = spec.get("description")
    return block


def slim_filter_block(filter_block: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """Drop catalog-duplicated text from a per-group filter block (rec D)."""
    if not filter_block:
        return filter_block
    return {
        k: v
        for k, v in filter_block.items()
        if k not in ("label", "description")
    }


def public_stats_entry(entry: Dict[str, Any]) -> Dict[str, Any]:
    """Drop private underscore keys for JSON export."""
    return {k: v for k, v in entry.items() if not str(k).startswith("_")}


def compute_pareto_front(groups: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Classical 2D Pareto: minimize avg_time_total_ns and median_size_bytes."""
    front: List[Dict[str, Any]] = []
    workloads: Dict[Tuple[Any, Any], List[Dict[str, Any]]] = {}
    for g in groups:
        wkey = (g.get("test_data"), g.get("mode"))
        workloads.setdefault(wkey, []).append(g)
    for items in workloads.values():
        for item in items:
            t = item.get("avg_time_total_ns")
            s = item.get("median_size_bytes")
            if t is None or s is None:
                continue
            dominated = False
            for other in items:
                if other is item:
                    continue
                ot = other.get("avg_time_total_ns")
                os_ = other.get("median_size_bytes")
                if ot is None or os_ is None:
                    continue
                if (ot <= t and os_ < s) or (ot < t and os_ <= s):
                    dominated = True
                    break
            if not dominated:
                front.append(
                    {
                        "serializer": item.get("serializer"),
                        "test_data": item.get("test_data"),
                        "mode": item.get("mode"),
                        "time": t,
                        "size": s,
                        "filter_policy": (item.get("filter") or {}).get("policy"),
                    }
                )
    return front


def compute_statistics_multi_policy(
    records: List[Dict],
    config: Optional[Dict[str, Any]] = None,
    language_hint: Optional[str] = None,
    policies: Optional[Sequence[str]] = None,
) -> Dict[str, Dict]:
    """Compute full stats under each named filter policy.

    Returns ``{policy_id: {group_key: entry}}``. Each entry includes a
    ``filter`` provenance block. Effect sizes are recomputed per policy
    (comparisons only among groups sharing that sample set).
    """
    base = config or load_stats_config()
    policy_ids = list(policies) if policies is not None else list(FILTER_POLICY_IDS)
    result: Dict[str, Dict] = {}
    for pid in policy_ids:
        cfg = config_for_filter_policy(base, pid)
        clean, meta = prepare_analysis_records(
            records, config=cfg, language_hint=language_hint
        )
        # Tag meta so entries get the stable policy id
        for key in meta:
            meta[key]["filter_policy"] = pid
        stats = compute_statistics(
            clean,
            config=cfg,
            language_hint=language_hint,
            pre_sanitized=True,
            group_meta=meta,
        )
        # Ensure policy id is set even for empty-meta edge cases
        for entry in stats.values():
            fb = entry.get("filter") or {}
            fb["policy"] = pid
            entry["filter"] = slim_filter_block(fb)
        result[pid] = stats
    return result


def build_stats_export_payload(
    by_policy: Dict[str, Dict],
    language: str,
    default_policy: str = DEFAULT_FILTER_POLICY,
    generated: Optional[str] = None,
) -> Dict[str, Any]:
    """Assemble schema **2.2** compact multi-policy stats export.

    Size reductions vs 2.1:
    - **B** no duplicate flat ``groups`` list equal to default policy
    - **C** identity once + ``variants`` per policy (no ``groups_by_policy`` blow-up)
    - **D** filter blocks omit catalog ``label``/``description``
    - Pareto fronts omitted (dashboard recomputes from metrics)

    Dashboard expands variants client-side. Prefer publishing as
    ``stats_<lang>_latest.json.gz`` (recommendation A).
    """
    import datetime as _dt

    if default_policy not in by_policy and by_policy:
        default_policy = next(iter(by_policy))

    # Preserve policy order: FILTER_POLICY_IDS first, then any extras
    policy_order: List[str] = [p for p in FILTER_POLICY_IDS if p in by_policy]
    for p in by_policy:
        if p not in policy_order:
            policy_order.append(p)

    # Union of group keys across policies (stable sort for determinism)
    all_keys: List[Any] = sorted(
        {k for stats in by_policy.values() for k in stats.keys()},
        key=lambda k: tuple(str(x) for x in (k if isinstance(k, tuple) else (k,))),
    )

    catalog = filter_policy_catalog()
    slim_groups: List[Dict[str, Any]] = []

    for key in all_keys:
        # Identity from first available policy entry
        base_pub: Optional[Dict[str, Any]] = None
        for pid in policy_order:
            if key in by_policy[pid]:
                base_pub = public_stats_entry(by_policy[pid][key])
                break
        if not base_pub:
            continue

        identity: Dict[str, Any] = {
            k: base_pub.get(k) for k in _EXPORT_IDENTITY_KEYS
        }
        if base_pub.get("StreamMode") is not None:
            identity["StreamMode"] = base_pub.get("StreamMode")

        variants: Dict[str, Dict[str, Any]] = {}
        for pid in policy_order:
            if key not in by_policy[pid]:
                continue
            pub = public_stats_entry(by_policy[pid][key])
            metrics = {
                k: v
                for k, v in pub.items()
                if k not in _EXPORT_IDENTITY_KEYS and k != "StreamMode"
            }
            if isinstance(metrics.get("filter"), dict):
                metrics["filter"] = slim_filter_block(metrics["filter"])
            variants[pid] = metrics

            # Refresh catalog min_samples / warmup from first seen filter
            fb = metrics.get("filter") or {}
            if pid in catalog:
                if fb.get("min_samples_for_outlier_filter") is not None:
                    catalog[pid]["min_samples_for_outlier_filter"] = fb[
                        "min_samples_for_outlier_filter"
                    ]
                if fb.get("exclude_warmup") is not None:
                    catalog[pid]["exclude_warmup"] = fb["exclude_warmup"]

        slim_groups.append({**identity, "variants": variants})

    return {
        "schema_version": "2.2",
        "generated": generated or _dt.datetime.now().isoformat(),
        "language": language,
        "default_filter_policy": default_policy,
        "filter_policies": catalog,
        "questions": {
            "Q1": "How fast?",
            "Q2": "How compact?",
            "Q3": "How stable?",
            "Q4": "Under which workloads does it win?",
        },
        "groups": slim_groups,
    }


def _attach_effect_sizes(results: Dict, cfg: Dict[str, Any]) -> None:
    """Attach effect size + MWU vs fastest in same (lang, data, instance, mode) group.

    Multiplicity: Holm correction is applied **within each group only**.
    Multi-way Results treat these as exploratory; see methodology.
    """
    eff = cfg.get("effect_sizes") or {}
    thr = eff.get("cliffs_delta_thresholds")
    vs = eff.get("vs_fastest") or {}
    ref_mode = str(vs.get("reference") or "median").strip().lower()
    mcc = str(vs.get("multiple_comparison") or "holm").strip().lower()
    ht = cfg.get("hypothesis_tests") or {}
    alpha = float(ht.get("alpha", 0.05))
    run_test = bool(ht.get("enabled", True)) and str(vs.get("test") or "mann_whitney_u") == "mann_whitney_u"

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

    def _ref_score(entry: Dict[str, Any]) -> float:
        if ref_mode == "median":
            v = entry.get("total_median_ns")
            if v is not None and v == v:  # not NaN
                return float(v)
        return float(entry.get("avg_time_total_ns") or float("inf"))

    for gkey, items in groups.items():
        if len(items) < 2:
            for _, entry in items:
                entry["effect_vs_fastest_cliffs_delta"] = 0.0
                entry["effect_vs_fastest_cliffs_label"] = "reference"
                entry["effect_vs_fastest_hedges_g"] = 0.0
                entry["effect_vs_fastest_p_value"] = None
                entry["effect_vs_fastest_p_value_holm"] = None
                entry["effect_vs_fastest_significant_holm"] = None
                entry["fastest_in_group"] = entry["serializer"]
                entry["effect_vs_fastest_exploratory"] = True
            continue

        fastest_key, fastest_entry = min(items, key=lambda t: _ref_score(t[1]))
        fast_times = fastest_entry.get("_times_total_filtered") or []

        # Collect MWU p-values for non-reference members (stable order)
        non_ref: List[Tuple[Any, Dict[str, Any]]] = []
        raw_ps: List[float] = []
        for key, entry in items:
            if key == fastest_key:
                continue
            mine = entry.get("_times_total_filtered") or []
            p = 1.0
            if run_test and len(mine) >= 2 and len(fast_times) >= 2:
                _u, p = mann_whitney_u(mine, fast_times)
            raw_ps.append(float(p))
            non_ref.append((key, entry))

        if mcc == "holm" and raw_ps:
            adj_ps = holm_correction(raw_ps)
        else:
            adj_ps = list(raw_ps)

        for (key, entry), p_raw, p_adj in zip(non_ref, raw_ps, adj_ps):
            entry["fastest_in_group"] = fastest_entry["serializer"]
            entry["effect_vs_fastest_exploratory"] = True
            mine = entry.get("_times_total_filtered") or []
            cd = cliffs_delta(mine, fast_times) if mine and fast_times else 0.0
            hg = hedges_g(mine, fast_times) if mine and fast_times else 0.0
            entry["effect_vs_fastest_cliffs_delta"] = cd
            entry["effect_vs_fastest_cliffs_label"] = cliffs_delta_label(cd, thr)
            entry["effect_vs_fastest_hedges_g"] = hg
            if run_test and len(mine) >= 2 and len(fast_times) >= 2:
                entry["effect_vs_fastest_p_value"] = p_raw
                entry["effect_vs_fastest_p_value_holm"] = p_adj
                entry["effect_vs_fastest_significant_holm"] = bool(p_adj < alpha)
            else:
                entry["effect_vs_fastest_p_value"] = None
                entry["effect_vs_fastest_p_value_holm"] = None
                entry["effect_vs_fastest_significant_holm"] = None

        for key, entry in items:
            if key != fastest_key:
                continue
            entry["fastest_in_group"] = entry["serializer"]
            entry["effect_vs_fastest_cliffs_delta"] = 0.0
            entry["effect_vs_fastest_cliffs_label"] = "reference"
            entry["effect_vs_fastest_hedges_g"] = 0.0
            entry["effect_vs_fastest_p_value"] = None
            entry["effect_vs_fastest_p_value_holm"] = None
            entry["effect_vs_fastest_significant_holm"] = None
            entry["effect_vs_fastest_exploratory"] = True


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


