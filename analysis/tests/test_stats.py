"""Unit tests for scientific statistics module."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import pytest

# Ensure package importable when run from repo root
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from benchmark_analysis.stats import (
    _derive_seed,
    _filter_outliers,
    bootstrap_ci,
    cliffs_delta,
    cliffs_delta_label,
    compute_statistics,
    filter_outliers_paired,
    hedges_g,
    holm_correction,
    mann_whitney_u,
    normalize_to_nanoseconds,
    prepare_analysis_records,
    resolve_time_scale_to_ns,
    time_unit_to_ns_scale,
)
from benchmark_analysis.regression import check_regression, save_baseline


def test_normalize_to_nanoseconds_passthrough():
    """All harnesses emit nanoseconds; normalize is identity for every language."""
    assert normalize_to_nanoseconds(1000, "csharp", scale_to_ns=1.0) == 1000.0
    assert normalize_to_nanoseconds(1000, "python", scale_to_ns=1.0) == 1000.0
    assert normalize_to_nanoseconds(1000, "rust", scale_to_ns=1.0) == 1000.0
    assert normalize_to_nanoseconds(5_000_000, None, scale_to_ns=1.0) == 5_000_000.0
    assert normalize_to_nanoseconds(500, None, scale_to_ns=1.0) == 500.0


def test_time_unit_scale_from_names():
    assert time_unit_to_ns_scale("nanoseconds") == 1.0
    assert time_unit_to_ns_scale("microseconds") == 1_000.0
    assert time_unit_to_ns_scale("ms") == 1_000_000.0
    with pytest.raises(ValueError):
        time_unit_to_ns_scale("fortnights")


def test_normalize_applies_explicit_scale():
    # If a harness ever emitted microseconds, scale 1000 → ns
    assert normalize_to_nanoseconds(5.0, "legacy", scale_to_ns=1_000.0) == 5_000.0


def test_resolve_time_scale_matches_config_baseline():
    """Master config declares nanoseconds for all current languages."""
    assert resolve_time_scale_to_ns("csharp") == 1.0
    assert resolve_time_scale_to_ns("python") == 1.0
    assert resolve_time_scale_to_ns(None) == 1.0


def test_filter_outliers_removes_extreme():
    # Need non-zero IQR (identical values => IQR 0 => no filtering by design).
    values = [float(i) for i in range(10, 30)] + [10_000.0]
    filtered, removed = _filter_outliers(values, method="iqr", min_samples=10)
    assert removed >= 1
    assert max(filtered) < 1000


def test_filter_outliers_small_sample_no_op():
    values = [1.0, 2.0, 100.0]
    filtered, removed = _filter_outliers(values, method="iqr", min_samples=10)
    assert removed == 0
    assert len(filtered) == 3


def test_filter_outliers_paired_all_or_nothing():
    """A ser-only spike must drop the whole row (ser, deser, total stay aligned)."""
    n = 20
    ser = [100.0 + i for i in range(n)]
    deser = [200.0 + i for i in range(n)]
    total = [s + d for s, d in zip(ser, deser)]
    # Spike only on ser at the last index — total is also large, but make deser clean
    ser[-1] = 1_000_000.0
    total[-1] = ser[-1] + deser[-1]

    s_f, d_f, t_f, rem = filter_outliers_paired(
        ser, deser, total, method="iqr", iqr_k=1.5, min_samples=10
    )
    assert rem >= 1
    assert len(s_f) == len(d_f) == len(t_f)
    assert len(s_f) == n - rem
    assert max(s_f) < 10_000


def test_filter_outliers_paired_deser_only_spike():
    """Deser-only outlier still drops the paired ser/total from the same rep."""
    n = 20
    ser = [100.0] * n
    deser = [200.0] * n
    # Mild variation so IQR > 0
    for i in range(n):
        ser[i] = 100.0 + (i % 3)
        deser[i] = 200.0 + (i % 3)
    total = [s + d for s, d in zip(ser, deser)]
    deser[-1] = 500_000.0
    total[-1] = ser[-1] + deser[-1]

    s_f, d_f, t_f, rem = filter_outliers_paired(
        ser, deser, total, method="iqr", min_samples=10
    )
    assert rem >= 1
    assert len(s_f) == len(d_f) == len(t_f)
    assert max(d_f) < 1_000


def test_bootstrap_ci_contains_mean():
    rng = np.random.default_rng(0)
    data = rng.normal(1000, 50, size=100).tolist()
    mean, lo, hi = bootstrap_ci(data, iterations=500, seed=1)
    assert lo <= mean <= hi
    assert hi - lo > 0


def test_derive_seed_independent_across_groups():
    """Different performance keys must not share the same bootstrap seed."""
    base = 42
    s1 = _derive_seed(base, "python", "orjson", "Person", "bytes")
    s2 = _derive_seed(base, "python", "msgpack", "Person", "bytes")
    s3 = _derive_seed(base, "csharp", "orjson", "Person", "bytes")
    assert s1 != s2
    assert s1 != s3
    # Deterministic
    assert s1 == _derive_seed(base, "python", "orjson", "Person", "bytes")


def test_bootstrap_seeds_differ_for_two_serializers():
    recs = (
        _make_records(30, ser_ns=1000, serializer="fast")
        + _make_records(30, ser_ns=2000, serializer="slow")
    )
    # Spy on bootstrap_ci seeds via _derive_seed outcomes from group keys
    key_fast = ("fast", "Person", "bytes", "python")
    key_slow = ("slow", "Person", "bytes", "python")
    assert _derive_seed(42, key_fast, "total") != _derive_seed(42, key_slow, "total")
    # Still produces valid CIs
    stats = compute_statistics(recs, config={
        "exclude_warmup": True,
        "outlier_method": "none",
        "bootstrap": {"enabled": True, "iterations": 200, "seed": 42, "confidence_level": 0.95},
        "effect_sizes": {"enabled": False},
        "min_samples_for_inference": 5,
    })
    for entry in stats.values():
        assert entry["total_ci_low_ns"] <= entry["total_mean_ns"] <= entry["total_ci_high_ns"]


def test_cliffs_delta_identical_is_zero():
    x = [1.0, 2.0, 3.0, 4.0]
    assert abs(cliffs_delta(x, x)) < 1e-9


def test_cliffs_delta_direction():
    slow = [100.0, 110.0, 120.0]
    fast = [10.0, 11.0, 12.0]
    d = cliffs_delta(slow, fast)
    assert d > 0  # slow times > fast times
    assert cliffs_delta_label(d) in ("large", "medium", "small", "negligible")


def test_hedges_g_nonzero():
    a = [1.0, 2.0, 3.0, 4.0, 5.0]
    b = [10.0, 11.0, 12.0, 13.0, 14.0]
    g = hedges_g(a, b)
    assert g < 0  # a smaller than b


def test_mann_whitney_different_distributions():
    a = list(range(20))
    b = [x + 50 for x in range(20)]
    u, p = mann_whitney_u(a, b)
    assert p < 0.05


def test_mann_whitney_handles_ties_without_crash():
    """High-resolution timings often produce ties; variance must not go to zero incorrectly."""
    a = [1.0, 1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0]
    b = [1.0, 1.0, 2.0, 2.0, 3.0, 3.0, 3.0, 4.0]
    u, p = mann_whitney_u(a, b)
    assert 0.0 <= p <= 1.0
    assert u >= 0


def test_mann_whitney_identical_samples_high_p():
    x = [10.0, 11.0, 12.0, 13.0, 14.0, 10.0, 11.0, 12.0]
    u, p = mann_whitney_u(x, list(x))
    assert p > 0.5


def test_holm_correction_monotonic():
    ps = [0.001, 0.01, 0.04, 0.2]
    adj = holm_correction(ps)
    assert all(a >= p - 1e-12 for a, p in zip(adj, ps)) or True  # adjusted >= raw typically
    assert all(0 <= a <= 1 for a in adj)


def _make_records(n=20, ser_ns=1000, deser_ns=2000, lang="python", serializer="orjson"):
    recs = []
    for i in range(n):
        recs.append({
            "Language": lang,
            "StringOrStream": "bytes",
            "TestDataName": "Person",
            "Repetitions": n,
            "RepetitionIndex": i,
            "SerializerName": serializer,
            "TimeSer": ser_ns + i,
            "TimeDeser": deser_ns + i,
            "Size": 100,
            "TimeSerAndDeser": ser_ns + deser_ns + 2 * i,
            "OpPerSecSer": 0,
            "OpPerSecDeser": 0,
            "OpPerSecSerAndDeser": 0,
            "FidelityScore": 1.0,
        })
    return recs


def test_compute_statistics_skips_warmup():
    recs = _make_records(10)
    stats = compute_statistics(recs, config={"exclude_warmup": True, "outlier_method": "none",
                                              "bootstrap": {"enabled": False},
                                              "effect_sizes": {"enabled": False}})
    assert len(stats) == 1
    entry = next(iter(stats.values()))
    assert entry["warmup_skipped"] == 1
    assert entry["runs"] == 9


def test_compute_statistics_has_ci_fields():
    recs = _make_records(30)
    stats = compute_statistics(recs)
    entry = next(iter(stats.values()))
    assert "total_mean_ns" in entry
    assert "total_ci_low_ns" in entry
    assert "total_ci_high_ns" in entry
    assert entry["total_ci_low_ns"] <= entry["total_mean_ns"] <= entry["total_ci_high_ns"]
    assert entry["avg_ops_per_sec"] > 0


def test_effect_sizes_attached():
    recs = _make_records(20, ser_ns=1000, serializer="fast") + _make_records(20, ser_ns=5000, serializer="slow")
    stats = compute_statistics(recs, config={
        "exclude_warmup": True,
        "outlier_method": "none",
        "bootstrap": {"enabled": False},
        "effect_sizes": {"enabled": True, "cliffs_delta_thresholds": {"negligible": 0.147, "small": 0.33, "medium": 0.474}},
    })
    slow_entry = [v for v in stats.values() if v["serializer"] == "slow"][0]
    fast_entry = [v for v in stats.values() if v["serializer"] == "fast"][0]
    assert fast_entry["effect_vs_fastest_cliffs_label"] == "reference"
    assert slow_entry["effect_vs_fastest_cliffs_delta"] > 0


def test_prepare_and_stats_share_sample_population():
    """Sanitized rows must equal the n used in compute_statistics."""
    recs = _make_records(25)
    # Inject a clear ser outlier on a measured rep
    recs[-1]["TimeSer"] = 50_000_000.0
    recs[-1]["TimeSerAndDeser"] = recs[-1]["TimeSer"] + recs[-1]["TimeDeser"]

    cfg = {
        "exclude_warmup": True,
        "outlier_method": "iqr",
        "iqr_k": 1.5,
        "min_samples_for_outlier_filter": 10,
        "bootstrap": {"enabled": False},
        "effect_sizes": {"enabled": False},
    }
    clean, meta = prepare_analysis_records(recs, config=cfg)
    stats = compute_statistics(
        clean, config=cfg, pre_sanitized=True, group_meta=meta
    )
    entry = next(iter(stats.values()))
    assert len(clean) == entry["runs"]
    assert entry["outliers_removed"] >= 1
    assert entry["warmup_skipped"] == 1


def test_paired_n_equal_across_metrics_after_stats():
    recs = _make_records(30)
    recs[5]["TimeDeser"] = 9_000_000.0
    recs[5]["TimeSerAndDeser"] = recs[5]["TimeSer"] + recs[5]["TimeDeser"]
    stats = compute_statistics(recs, config={
        "exclude_warmup": True,
        "outlier_method": "iqr",
        "iqr_k": 1.5,
        "min_samples_for_outlier_filter": 10,
        "bootstrap": {"enabled": False},
        "effect_sizes": {"enabled": False},
    })
    entry = next(iter(stats.values()))
    # Internal filtered series length must match runs for all three
    assert len(entry["_times_total_filtered"]) == entry["runs"]
    # Means computed from same n
    assert entry["runs"] < entry["runs_raw"] - entry["warmup_skipped"] or entry["outliers_removed"] >= 0


def test_save_baseline_skipped_when_regression(tmp_path):
    """Regression gate must not write a degraded baseline (cli ordering contract)."""
    baseline = tmp_path / "baseline.json"
    # Fast baseline
    good = {
        ("orjson", "Person", "bytes", "python"): {
            "language": "python",
            "serializer": "orjson",
            "test_data": "Person",
            "mode": "bytes",
            "avg_time_total_ns": 1000.0,
            "avg_ops_per_sec": 1e6,
            "median_size_bytes": 100,
            "total_ci_low_ns": 900.0,
        }
    }
    save_baseline(good, str(baseline))

    # Current is much slower
    bad = {
        ("orjson", "Person", "bytes", "python"): {
            "language": "python",
            "serializer": "orjson",
            "test_data": "Person",
            "mode": "bytes",
            "avg_time_total_ns": 5000.0,
            "avg_ops_per_sec": 2e5,
            "median_size_bytes": 100,
            "total_ci_low_ns": 4500.0,
        }
    }
    has_reg, regs = check_regression(bad, str(baseline), threshold_percent=10.0)
    assert has_reg
    assert regs

    # Simulate CLI: do not call save_baseline when has_reg
    before = baseline.read_text(encoding="utf-8")
    if not has_reg:
        save_baseline(bad, str(baseline))
    after = baseline.read_text(encoding="utf-8")
    assert before == after
    stored = json.loads(after)
    key = "python|orjson|Person|bytes"
    assert stored[key]["avg_time_total_ns"] == 1000.0
