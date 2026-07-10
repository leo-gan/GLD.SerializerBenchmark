"""Semantic fidelity for v2 instances (dataclass vs dict vs list batch)."""

from __future__ import annotations

import math
from dataclasses import asdict, is_dataclass
from typing import Any


def _norm(obj: Any) -> Any:
    if obj is None:
        return None
    if is_dataclass(obj) and not isinstance(obj, type):
        return _norm(asdict(obj))
    if isinstance(obj, dict):
        # protobuf Message has ListFields — prefer asdict path only for dataclasses
        if hasattr(obj, "DESCRIPTOR") and hasattr(obj, "ListFields"):
            return _pb_to_dict(obj)
        return {k: _norm(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_norm(v) for v in obj]
    if isinstance(obj, float):
        return obj
    if isinstance(obj, (int, str, bool)):
        return obj
    # pydantic / msgspec / generic objects with __dict__
    if hasattr(obj, "model_dump"):
        return _norm(obj.model_dump())
    if hasattr(obj, "dict") and callable(obj.dict):
        try:
            return _norm(obj.dict())
        except Exception:
            pass
    if hasattr(obj, "__dict__") and not isinstance(obj, type):
        d = {k: v for k, v in vars(obj).items() if not k.startswith("_")}
        if d:
            return _norm(d)
    return obj


def _pb_to_dict(msg: Any) -> Any:
    from google.protobuf.json_format import MessageToDict

    return MessageToDict(msg, preserving_proto_field_name=True)


def _eq(a: Any, b: Any, path: str = "") -> bool:
    a, b = _norm(a), _norm(b)
    if isinstance(a, float) or isinstance(b, float):
        try:
            return math.isclose(float(a), float(b), rel_tol=1e-9, abs_tol=1e-9)
        except (TypeError, ValueError):
            return False
    if isinstance(a, dict) and isinstance(b, dict):
        # allow key case differences loosely: exact keys first
        if set(a.keys()) != set(b.keys()):
            # protobuf may omit empty; require all expected keys present in actual
            for k, v in a.items():
                if k not in b:
                    return False
                if not _eq(v, b[k], path + "." + k):
                    return False
            return True
        return all(_eq(a[k], b[k], path + "." + k) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return False
        return all(_eq(x, y, path + f"[{i}]") for i, (x, y) in enumerate(zip(a, b)))
    return a == b


def fidelity_v2(expected: Any, actual: Any) -> float:
    return 1.0 if _eq(expected, actual) else 0.0
