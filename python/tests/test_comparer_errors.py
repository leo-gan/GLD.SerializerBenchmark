"""Comparer error-path smoke tests using v2 Message fixtures."""
from __future__ import annotations

import sys
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
