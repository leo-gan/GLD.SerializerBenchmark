"""Tests for multi-session aggregation and CLI resolution."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from benchmark_analysis.multi_session import (
    aggregate_multi_session,
    multi_session_markdown,
)
from benchmark_analysis.cli import _resolve_multi_session_paths, _expand_multi_session_specs


def _entry(ser: str, median: float, lang: str = "python", mode: str = "bytes", n: int = 1):
    return {
        "language": lang,
        "serializer": ser,
        "test_data": "message",
        "type_config_hash": "h",
        "data_type_instance_count": n,
        "mode": mode,
        "total_median_ns": median,
        "avg_time_total_ns": median,
    }


def test_aggregate_rank_stability_and_l2_claim():
    # Three sessions, same machine; ser_a wins 2/3
    sessions = [
        {
            "run_id": "s1",
            "machine_id": "abcd1234",
            "stats": {
                "a": _entry("ser_a", 100),
                "b": _entry("ser_b", 200),
            },
        },
        {
            "run_id": "s2",
            "machine_id": "abcd1234",
            "stats": {
                "a": _entry("ser_a", 110),
                "b": _entry("ser_b", 90),
            },
        },
        {
            "run_id": "s3",
            "machine_id": "abcd1234",
            "stats": {
                "a": _entry("ser_a", 105),
                "b": _entry("ser_b", 180),
            },
        },
    ]
    report = aggregate_multi_session(sessions, language="python")
    assert report["n_sessions"] == 3
    assert report["claim_level"] == "L2_multi_session_same_host"
    assert report["machine_ids"] == ["abcd1234"]
    assert len(report["groups"]) == 2
    # ser_a medians 100,110,105 → median 105
    a = next(g for g in report["groups"] if g["serializer"] == "ser_a")
    assert a["n_sessions"] == 3
    assert a["median_of_session_medians_ns"] == pytest.approx(105.0)
    rank = report["rank_stability"][0]
    wins = {f["serializer"]: f["wins"] for f in rank["fastest_frequency"]}
    assert wins["ser_a"] == 2
    assert wins["ser_b"] == 1


def test_aggregate_l3_when_two_machines():
    sessions = [
        {"run_id": "s1", "machine_id": "host_a", "stats": {"a": _entry("ser_a", 100)}},
        {"run_id": "s2", "machine_id": "host_b", "stats": {"a": _entry("ser_a", 120)}},
    ]
    report = aggregate_multi_session(sessions, language="python")
    assert report["claim_level"] == "L3_multi_machine"
    assert set(report["machine_ids"]) == {"host_a", "host_b"}


def test_aggregate_l1_single_session():
    sessions = [
        {"run_id": "only", "machine_id": "m1", "stats": {"a": _entry("ser_a", 100)}},
    ]
    report = aggregate_multi_session(sessions, language="python")
    assert report["claim_level"] == "L1_single_session"


def test_aggregate_l2_host_unknown_when_no_machine_ids():
    sessions = [
        {"run_id": "s1", "machine_id": None, "stats": {"a": _entry("ser_a", 100)}},
        {"run_id": "s2", "machine_id": None, "stats": {"a": _entry("ser_a", 110)}},
        {"run_id": "s3", "machine_id": None, "stats": {"a": _entry("ser_a", 105)}},
    ]
    report = aggregate_multi_session(sessions, language="python")
    assert report["claim_level"] == "L2_multi_session_host_unknown"
    assert report["machine_ids"] == []


def test_multi_session_markdown_mentions_claim_level():
    report = aggregate_multi_session(
        [
            {"run_id": "s1", "machine_id": "m", "stats": {"a": _entry("a", 1), "b": _entry("b", 2)}},
            {"run_id": "s2", "machine_id": "m", "stats": {"a": _entry("a", 1), "b": _entry("b", 2)}},
            {"run_id": "s3", "machine_id": "m", "stats": {"a": _entry("a", 1), "b": _entry("b", 2)}},
        ],
        language="python",
    )
    md = multi_session_markdown(report)
    assert "L2_multi_session_same_host" in md
    assert "Rank stability" in md


def test_expand_multi_session_specs_commas():
    assert _expand_multi_session_specs(["a,b", "c"]) == ["a", "b", "c"]


def test_resolve_multi_session_paths_shorthand(tmp_path: Path):
    lang_dir = tmp_path / "python"
    lang_dir.mkdir()
    p1 = lang_dir / "2026-07-01-120000.csv"
    p2 = lang_dir / "2026-07-02-120000.csv"
    p1.write_text("x\n")
    p2.write_text("x\n")
    by = _resolve_multi_session_paths(
        ["python:2026-07-01", "python:2026-07-02"],
        logs_root=tmp_path,
    )
    assert "python" in by
    assert len(by["python"]) == 2
    assert all(Path(p).is_file() for p in by["python"])


def test_resolve_multi_session_paths_lang_eq_form(tmp_path: Path):
    lang_dir = tmp_path / "rust"
    lang_dir.mkdir()
    (lang_dir / "2026-06-01-100000.csv").write_text("x\n")
    (lang_dir / "2026-06-02-100000.csv").write_text("x\n")
    by = _resolve_multi_session_paths(
        ["rust=2026-06-01,rust=2026-06-02"],
        logs_root=tmp_path,
    )
    assert len(by["rust"]) == 2
