"""Comparer error-path smoke tests using v2 Message fixtures."""
from __future__ import annotations

import datetime
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from benchmark.comparer import compare
from benchmark.data_v2 import make_one


def test_compare_equal_messages():
    a = make_one("message", {}, 1)
    b = make_one("message", {}, 1)
    ok, err = compare(a, b)
    assert ok, err


def test_compare_different_seeds():
    a = make_one("message", {}, 1)
    b = make_one("message", {}, 2)
    ok, err = compare(a, b)
    assert not ok
    assert err


@dataclass
class _When:
    name: str
    when: datetime.datetime


def test_coerce_datetime_accepts_iso_string_and_unix_seconds():
    expected = _When("a", datetime.datetime(2024, 1, 2, 3, 4, 5))
    ok, err = compare(expected, {"name": "a", "when": "2024-01-02T03:04:05"})
    assert ok, err
    ok, err = compare(expected, {"name": "a", "when": 1_704_164_645})
    assert ok, err


def test_coerce_datetime_rejects_far_timestamps():
    expected = _When("a", datetime.datetime(2024, 1, 2, 3, 4, 5))
    ok, err = compare(expected, {"name": "a", "when": "2024-01-02T03:04:07"})
    assert not ok
    assert "datetime mismatch" in err


def test_compare_mapping_reports_keys_only_on_one_side():
    ok, err = compare({"a": 1, "b": 2}, {"a": 1, "c": 3})
    assert not ok
    assert "only in expected" in err
    assert "only in actual" in err


def test_compare_dataclass_reports_missing_field():
    expected = _When("a", datetime.datetime(2024, 1, 2, 3, 4, 5))
    ok, err = compare(expected, {"name": "a"})
    assert not ok
    assert "when" in err
    assert "<missing>" in err
