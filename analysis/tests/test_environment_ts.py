"""benchmark_ts resolution and configs.json sidecars."""
from __future__ import annotations

import json
from pathlib import Path

from benchmark_analysis.environment import (
    _resolve_benchmark_ts,
    capture_environment,
    important_config_summary,
    load_run_config,
)
from benchmark_analysis.metrics_catalog import filter_field_ids, load_metrics_config


def test_resolve_from_env_var(monkeypatch):
    monkeypatch.setenv("BENCHMARK_TS", "2026-07-02-101618")
    assert _resolve_benchmark_ts("logs/python/other-name.csv") == "2026-07-02-101618"


def test_resolve_from_csv_stem_when_env_missing(monkeypatch, tmp_path: Path):
    monkeypatch.delenv("BENCHMARK_TS", raising=False)
    csv = tmp_path / "2026-07-02-101618.csv"
    csv.write_text("x\n")
    assert _resolve_benchmark_ts(str(csv)) == "2026-07-02-101618"


def test_resolve_empty_when_unknown(monkeypatch):
    monkeypatch.delenv("BENCHMARK_TS", raising=False)
    assert _resolve_benchmark_ts(None) == ""
    assert _resolve_benchmark_ts("/tmp/results.csv") == ""


def test_capture_writes_configs_json_from_csv_stem(monkeypatch, tmp_path: Path):
    monkeypatch.delenv("BENCHMARK_TS", raising=False)
    csv = tmp_path / "2026-07-01-195234.csv"
    csv.write_text(
        "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,"
        "SerializerName,SerializerVersion,TimeSer,TimeDeser,Size\n"
        "python,bytes,message,2,0,orjson,3.11.9,1,2,3\n",
        encoding="utf-8",
    )
    doc = capture_environment(str(csv))
    assert doc["benchmark_ts"] == "2026-07-01-195234"
    assert doc.get("schema_version") == 1
    assert "environment" in doc
    out = tmp_path / "2026-07-01-195234.configs.json"
    assert out.is_file()
    text = out.read_text()
    assert '"benchmark_ts": "2026-07-01-195234"' in text
    # serializers scraped from CSV when present
    assert doc.get("serializers", {}).get("count") == 1


def test_load_legacy_environment_json(tmp_path: Path):
    csv = tmp_path / "2026-07-01-100000.csv"
    csv.write_text("x\n")
    legacy = tmp_path / "2026-07-01-100000.environment.json"
    legacy.write_text(
        json.dumps({"benchmark_ts": "2026-07-01-100000", "os": {"system": "Linux"}}),
        encoding="utf-8",
    )
    doc = load_run_config(str(csv))
    assert doc is not None
    assert doc["environment"]["os"]["system"] == "Linux"
    summary = important_config_summary(doc)
    assert any("Linux" in s for s in summary)


def test_multi_way_filters_high_importance_only():
    cfg = load_metrics_config()
    fields = ["total_median_ns", "total_mean_ns", "effect_vs_fastest_hedges_g", "avg_ops_per_sec"]
    multi = filter_field_ids(fields, profile="multi_way", metrics_cfg=cfg)
    assert "total_median_ns" in multi
    assert "avg_ops_per_sec" in multi
    assert "effect_vs_fastest_hedges_g" not in multi  # low
    pair = filter_field_ids(fields, profile="pairwise", metrics_cfg=cfg)
    assert "effect_vs_fastest_hedges_g" in pair
