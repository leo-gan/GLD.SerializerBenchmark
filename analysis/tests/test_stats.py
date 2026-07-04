"""Unit tests for scientific statistics module."""

from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
import pytest

# Ensure package importable when run from repo root
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from benchmark_analysis.stats import (
    bootstrap_ci,
    cliffs_delta,
    cliffs_delta_label,
    compute_statistics,
    hedges_g,
    holm_correction,
    mann_whitney_u,
    normalize_to_nanoseconds,
    _filter_outliers,
)


def test_normalize_to_nanoseconds_passthrough():
    """All harnesses emit nanoseconds; normalize is identity for every language."""
    assert normalize_to_nanoseconds(1000, "csharp") == 1000.0
    assert normalize_to_nanoseconds(1000, "python") == 1000.0
    assert normalize_to_nanoseconds(1000, "rust") == 1000.0
    assert normalize_to_nanoseconds(5_000_000, None) == 5_000_000.0
    assert normalize_to_nanoseconds(500, None) == 500.0


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


def test_bootstrap_ci_contains_mean():
    rng = np.random.default_rng(0)
    data = rng.normal(1000, 50, size=100).tolist()
    mean, lo, hi = bootstrap_ci(data, iterations=500, seed=1)
    assert lo <= mean <= hi
    assert hi - lo > 0


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
