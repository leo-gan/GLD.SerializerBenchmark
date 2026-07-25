"""A-4 regression gate: AND vs OR, baseline v2, key migration."""

from __future__ import annotations

import json

from benchmark_analysis.regression import (
    baseline_key,
    check_regression,
    load_baseline,
    load_regression_config,
    save_baseline,
)


def _stat(
    *,
    lang="python",
    ser="orjson",
    data="message",
    mode="bytes",
    mean=1000.0,
    median=1000.0,
    ci_low=900.0,
    n=1,
    samples=None,
):
    return {
        "language": lang,
        "serializer": ser,
        "test_data": data,
        "mode": mode,
        "data_type_instance_count": n,
        "type_config_hash": "abc",
        "avg_time_total_ns": mean,
        "total_median_ns": median,
        "total_ci_low_ns": ci_low,
        "total_ci_high_ns": mean * 1.1,
        "avg_ops_per_sec": 1e9 / mean if mean else 0,
        "median_size_bytes": 100,
        "runs": len(samples or [1, 2, 3]),
        "_times_total_filtered": samples
        or [mean * 0.9, mean, mean * 1.1, mean * 0.95, mean * 1.05],
    }


def test_and_does_not_fail_on_mean_alone(tmp_path):
    """Noisy mean +10% but CI still overlaps band → not a regression under AND."""
    baseline = tmp_path / "b.json"
    good = {("k",): _stat(mean=1000.0, median=1000.0, ci_low=900.0)}
    save_baseline(good, str(baseline), config={"store_samples": False})

    # Mean/median +15% but CI low still below baseline*1.1 (band) → practical only
    # baseline 1000, factor 1.1 → band 1100. ci_low=1050 overlaps.
    bad = {
        ("k",): _stat(mean=1150.0, median=1150.0, ci_low=1050.0)
    }
    cfg = load_regression_config()
    cfg["combine"] = "and"
    cfg["threshold_percent"] = 10.0
    cfg["metric"] = "total_median_ns"
    has_reg, msgs = check_regression(bad, str(baseline), config=cfg)
    assert not has_reg
    assert any(m.startswith("UNCLEAR") for m in msgs)


def test_and_fails_when_ci_also_supports(tmp_path):
    baseline = tmp_path / "b.json"
    good = {("k",): _stat(mean=1000.0, median=1000.0, ci_low=900.0)}
    save_baseline(good, str(baseline), config={"store_samples": False})

    # +50% and CI low still way above band
    bad = {("k",): _stat(mean=1500.0, median=1500.0, ci_low=1400.0)}
    cfg = {"combine": "and", "threshold_percent": 10.0, "metric": "total_median_ns",
           "cliffs_delta": {"enabled": False}, "store_samples": False}
    has_reg, msgs = check_regression(bad, str(baseline), config=cfg)
    assert has_reg
    assert any(m.startswith("REGRESSION") for m in msgs)


def test_or_fails_on_mean_alone(tmp_path):
    baseline = tmp_path / "b.json"
    good = {("k",): _stat(mean=1000.0, median=1000.0, ci_low=900.0)}
    save_baseline(good, str(baseline), config={"store_samples": False})
    bad = {("k",): _stat(mean=1150.0, median=1150.0, ci_low=1050.0)}
    cfg = {"combine": "or", "threshold_percent": 10.0, "metric": "total_median_ns",
           "cliffs_delta": {"enabled": False}}
    has_reg, _ = check_regression(bad, str(baseline), config=cfg)
    assert has_reg


def test_baseline_key_includes_instance_count():
    k1 = baseline_key("python", "orjson", "message", "bytes", instance_count=1, type_config_hash="h")
    k100 = baseline_key("python", "orjson", "message", "bytes", instance_count=100, type_config_hash="h")
    assert k1 != k100
    assert "|1|" in k1 and "|100|" in k100


def test_legacy_v1_baseline_still_readable(tmp_path):
    path = tmp_path / "legacy.json"
    # v1 flat format
    path.write_text(
        json.dumps(
            {
                "python|orjson|message|bytes": {
                    "avg_time_total_ns": 1000.0,
                    "avg_ops_per_sec": 1e6,
                    "median_size_bytes": 50,
                }
            }
        ),
        encoding="utf-8",
    )
    entries = load_baseline(str(path))
    assert "python|orjson|message|bytes" in entries

    cur = {
        ("x",): _stat(mean=2000.0, median=2000.0, ci_low=1800.0, n=1)
    }
    # legacy lookup uses language|ser|data|mode without instance
    has_reg, _ = check_regression(
        cur,
        str(path),
        config={"combine": "and", "threshold_percent": 10.0, "cliffs_delta": {"enabled": False}},
    )
    assert has_reg


def test_cliffs_delta_when_samples_stored(tmp_path):
    baseline = tmp_path / "b.json"
    fast = [100.0, 102.0, 98.0, 101.0, 99.0] * 5
    slow = [200.0, 210.0, 190.0, 205.0, 195.0] * 5
    good = {("k",): _stat(mean=100.0, median=100.0, ci_low=95.0, samples=fast)}
    save_baseline(
        good,
        str(baseline),
        config={"store_samples": True, "max_samples_stored": 500},
    )
    loaded = load_baseline(str(baseline))
    key = next(iter(loaded))
    assert "samples_total_ns" in loaded[key]

    bad = {("k",): _stat(mean=200.0, median=200.0, ci_low=180.0, samples=slow)}
    cfg = {
        "combine": "and",
        "threshold_percent": 10.0,
        "metric": "total_median_ns",
        "cliffs_delta": {"enabled": True, "min_delta": 0.147, "require_for_fail": False},
    }
    has_reg, _ = check_regression(bad, str(baseline), config=cfg)
    assert has_reg
    details = check_regression.last_details
    assert details and details[0].get("cliffs_delta") is not None
    assert details[0]["cliffs_delta"] > 0  # current slower


def test_save_baseline_v2_schema(tmp_path):
    path = tmp_path / "b.json"
    stats = {("k",): _stat(n=100)}
    save_baseline(stats, str(path), config={"store_samples": True})
    raw = json.loads(path.read_text(encoding="utf-8"))
    assert raw["schema_version"] == 2
    assert "entries" in raw
    assert any("|100|" in k for k in raw["entries"])
