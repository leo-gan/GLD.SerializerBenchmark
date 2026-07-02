"""Comparer error text must include real expected/actual values."""
from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from benchmark.comparer import compare
from benchmark.data.generator import generate_test_data
from benchmark.data.models import Person


def test_missing_field_shows_expected_value():
    person = generate_test_data("Person")
    # Empty dict → every field "missing" on actual
    ok, err = compare(person, {})
    assert ok is False
    assert "expected present" not in err
    assert "actual present" not in err
    assert "actual <missing>" in err
    # Real FirstName value must appear
    assert person.FirstName in err or repr(person.FirstName) in err
    assert "FirstName" in err


def test_value_mismatch_shows_both_values():
    person = generate_test_data("Person")
    bad = generate_test_data("Person")
    bad.Age = person.Age + 999
    ok, err = compare(person, bad)
    assert ok is False
    assert str(person.Age) in err
    assert str(bad.Age) in err


def test_unexpected_extra_on_actual_shows_actual_value():
    @dataclass
    class Tiny:
        x: int = 1

    # Compare Tiny expected to an object that only has a different attr set via dict path
    # expected field x=1 vs actual missing x (empty dict)
    ok, err = compare(Tiny(x=42), {})
    assert ok is False
    assert "42" in err
    assert "actual <missing>" in err
