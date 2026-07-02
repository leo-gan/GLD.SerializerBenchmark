"""benchmark_ts resolution for environment.json sidecars."""
from __future__ import annotations

import os
from pathlib import Path

from benchmark_analysis.environment import _resolve_benchmark_ts, capture_environment


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


def test_capture_writes_benchmark_ts_from_csv_stem(monkeypatch, tmp_path: Path):
    monkeypatch.delenv("BENCHMARK_TS", raising=False)
    csv = tmp_path / "2026-07-01-195234.csv"
    csv.write_text("x\n")
    env = capture_environment(str(csv))
    assert env["benchmark_ts"] == "2026-07-01-195234"
    out = tmp_path / "2026-07-01-195234.environment.json"
    assert out.is_file()
    text = out.read_text()
    assert '"benchmark_ts": "2026-07-01-195234"' in text
