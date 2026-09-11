"""Semantic equality for decoded catalog values."""

from __future__ import annotations

from math import isnan
from typing import Any


def values_equal(expected: Any, observed: Any) -> bool:
    """Compare a case ``decoded`` field to a library result.

    Special expected forms:

    * ``{"$hex": "00ff"}`` — observed must be ``bytes`` with that content
    * ``{"$float": "nan"|"inf"|"-inf"}`` — IEEE specials
    """
    if isinstance(expected, dict) and len(expected) == 1:
        if "$hex" in expected:
            if not isinstance(observed, (bytes, bytearray)):
                return False
            return bytes(observed) == bytes.fromhex("".join(str(expected["$hex"]).split()))
        if "$float" in expected:
            token = str(expected["$float"]).lower()
            if token == "nan":
                return isinstance(observed, float) and isnan(observed)
            if token == "inf":
                return observed == float("inf")
            if token == "-inf":
                return observed == float("-inf")
    if expected is None:
        return observed is None
    if isinstance(expected, bool) or isinstance(observed, bool):
        return expected is observed or expected == observed
    if isinstance(expected, (int, float)) and isinstance(observed, (int, float)):
        if isinstance(expected, float) and isnan(expected):
            return isinstance(observed, float) and isnan(observed)
        return float(expected) == float(observed)
    if isinstance(expected, str):
        if isinstance(observed, bytes):
            try:
                return observed.decode("utf-8") == expected
            except UnicodeDecodeError:
                return False
        return expected == observed
    if isinstance(expected, list):
        if not isinstance(observed, list):
            return False
        if len(expected) != len(observed):
            return False
        return all(values_equal(a, b) for a, b in zip(expected, observed))
    if isinstance(expected, dict):
        if not isinstance(observed, dict):
            return False
        if set(expected) != set(observed):
            return False
        return all(values_equal(expected[k], observed[k]) for k in expected)
    return expected == observed


def preview(value: Any, *, limit: int = 120) -> str:
    text = repr(value)
    if len(text) > limit:
        return text[: limit - 3] + "..."
    return text
