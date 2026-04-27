"""
Semantic equality checker for roundtrip validation.

The C# suite uses deep object comparison. Python serializers have very
different type fidelity (e.g., JSON stores datetime as ISO strings, msgpack
converts tuples to lists). This module implements *semantic* equality:
values are considered equal if they represent the same logical data, even if
their Python types differ.
"""

from __future__ import annotations

import datetime
import math
from dataclasses import fields, is_dataclass
from enum import Enum
from typing import Any, Dict, List, Optional, Set, Tuple


# Sentinel for missing fields
_MISSING = object()


def _is_float(value: Any) -> bool:
    return isinstance(value, (float, int)) and not isinstance(value, bool)


def _coerce_datetime(value: Any) -> Optional[datetime.datetime]:
    """Try to interpret `value` as a datetime."""
    if isinstance(value, datetime.datetime):
        return value
    if isinstance(value, str):
        # Common ISO formats
        for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%d %H:%M:%S"):
            try:
                return datetime.datetime.strptime(value.split("+")[0].split("Z")[0], fmt)
            except ValueError:
                continue
    if isinstance(value, int):
        # Unix timestamp (seconds or milliseconds)
        try:
            if value > 1_000_000_000_000:
                return datetime.datetime.utcfromtimestamp(value / 1000.0)
            return datetime.datetime.utcfromtimestamp(value)
        except (ValueError, OSError):
            pass
    if isinstance(value, float):
        try:
            return datetime.datetime.utcfromtimestamp(value)
        except (ValueError, OSError):
            pass
    return None


def _compare_scalar(expected: Any, actual: Any, path: str, errors: List[str]) -> bool:
    """Compare two scalar-ish values with type coercion."""
    # Exact match (fast path)
    if expected == actual:
        return True

    # Enum values
    if isinstance(expected, Enum):
        if isinstance(actual, Enum):
            if expected.value == actual.value:
                return True
            errors.append(f"{path}: enum mismatch {expected.name} vs {actual.name}")
            return False
        # Enum stored as its name string (e.g., JSON, msgpack)
        if actual == expected.name:
            return True
        if expected.value == actual:
            return True
        errors.append(f"{path}: enum/value mismatch {expected.name} vs {actual!r}")
        return False

    # Numeric tolerance
    if _is_float(expected) and _is_float(actual):
        if math.isclose(float(expected), float(actual), rel_tol=1e-9, abs_tol=1e-12):
            return True
        errors.append(f"{path}: float mismatch {expected} vs {actual}")
        return False

    # Datetime coercion with millisecond tolerance (schema serializers truncate μs)
    dt_expected = _coerce_datetime(expected)
    dt_actual = _coerce_datetime(actual)
    if dt_expected is not None and dt_actual is not None:
        delta = abs((dt_expected - dt_actual).total_seconds())
        if delta <= 0.001:  # 1 ms tolerance
            return True
        errors.append(f"{path}: datetime mismatch {dt_expected} vs {dt_actual} (delta={delta}s)")
        return False

    # Int/bool cross-type
    if type(expected) is bool or type(actual) is bool:
        if expected != actual:
            errors.append(f"{path}: bool mismatch {expected} vs {actual}")
            return False
        return True

    # Generic mismatch
    errors.append(f"{path}: type/value mismatch {type(expected).__name__}({expected!r}) vs {type(actual).__name__}({actual!r})")
    return False


def _compare_sequence(
    expected: Any,
    actual: Any,
    path: str,
    errors: List[str],
    visited: Set[Tuple[int, int]],
) -> bool:
    """Compare list/tuple/set-like sequences."""
    expected_seq: List[Any] = list(expected)
    actual_seq: List[Any] = list(actual)

    if len(expected_seq) != len(actual_seq):
        errors.append(f"{path}: length mismatch {len(expected_seq)} vs {len(actual_seq)}")
        return False

    ok = True
    for i, (e, a) in enumerate(zip(expected_seq, actual_seq)):
        if not _deep_equal_impl(e, a, f"{path}[{i}]", errors, visited):
            ok = False
    return ok


def _compare_mapping(
    expected: Any,
    actual: Any,
    path: str,
    errors: List[str],
    visited: Set[Tuple[int, int]],
) -> bool:
    """Compare dict-like mappings."""
    expected_dict: Dict[Any, Any] = dict(expected)
    actual_dict: Dict[Any, Any] = dict(actual)

    if set(expected_dict.keys()) != set(actual_dict.keys()):
        errors.append(f"{path}: key mismatch {set(expected_dict.keys())} vs {set(actual_dict.keys())}")
        return False

    ok = True
    for k in expected_dict:
        if not _deep_equal_impl(expected_dict[k], actual_dict[k], f"{path}[{k!r}]", errors, visited):
            ok = False
    return ok


def _compare_dataclass(
    expected: Any,
    actual: Any,
    path: str,
    errors: List[str],
    visited: Set[Tuple[int, int]],
) -> bool:
    """Compare two dataclass instances field-by-field."""
    # Handle circular references: track by id pairs
    pair = (id(expected), id(actual))
    if pair in visited:
        return True
    visited.add(pair)

    expected_fields = {f.name: getattr(expected, f.name, _MISSING) for f in fields(expected)}

    # If actual is a dataclass of a *different* type, still compare by field names
    if is_dataclass(actual):
        actual_fields = {f.name: getattr(actual, f.name, _MISSING) for f in fields(actual)}
    elif isinstance(actual, dict):
        actual_fields = actual
    else:
        # Maybe a protobuf/avro generated object? Try attribute access for common field names
        actual_fields = {}
        for name in expected_fields:
            if hasattr(actual, name):
                actual_fields[name] = getattr(actual, name, _MISSING)
            elif hasattr(actual, f"_{name}"):  # Avro sometimes prefixes
                actual_fields[name] = getattr(actual, f"_{name}", _MISSING)
            else:
                actual_fields[name] = _MISSING

    ok = True
    for name, e_val in expected_fields.items():
        a_val = actual_fields.get(name, _MISSING)
        if e_val is _MISSING and a_val is _MISSING:
            continue
        if e_val is _MISSING:
            errors.append(f"{path}.{name}: expected missing, actual present")
            ok = False
            continue
        if a_val is _MISSING:
            errors.append(f"{path}.{name}: expected present, actual missing")
            ok = False
            continue
        if not _deep_equal_impl(e_val, a_val, f"{path}.{name}", errors, visited):
            ok = False

    return ok


def _deep_equal_impl(
    expected: Any,
    actual: Any,
    path: str,
    errors: List[str],
    visited: Set[Tuple[int, int]],
) -> bool:
    """Recursive semantic equality check."""
    if expected is actual:
        return True

    # None handling
    if expected is None or actual is None:
        if expected is None and actual is None:
            return True
        errors.append(f"{path}: None mismatch {expected!r} vs {actual!r}")
        return False

    # Dataclass comparison (fast path for common case)
    if is_dataclass(expected):
        return _compare_dataclass(expected, actual, path, errors, visited)

    # If actual is a dataclass but expected isn't, still try field-by-field
    if is_dataclass(actual):
        return _compare_dataclass(expected, actual, path, errors, visited)

    # Sequence-like
    if isinstance(expected, (list, tuple)) and isinstance(actual, (list, tuple)):
        return _compare_sequence(expected, actual, path, errors, visited)

    # Mapping-like
    if isinstance(expected, dict) and isinstance(actual, dict):
        return _compare_mapping(expected, actual, path, errors, visited)

    # Scalar
    return _compare_scalar(expected, actual, path, errors)


def compare(expected: Any, actual: Any) -> Tuple[bool, str]:
    """
    Compare `expected` and `actual` for semantic equality.

    Returns (is_equal, error_text).
    """
    errors: List[str] = []
    visited: Set[Tuple[int, int]] = set()
    ok = _deep_equal_impl(expected, actual, "root", errors, visited)
    if ok:
        return True, ""
    if not errors:
        # Safety net: every False path should append, but if one is missed,
        # emit a generic diagnostic.
        errors.append(f"root: semantic mismatch (expected {type(expected).__name__}, got {type(actual).__name__})")
    return False, "; ".join(errors)
