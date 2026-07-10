"""Semantic fidelity for v2 instances (dataclass, dict, list batch, protobuf, msgspec)."""

from __future__ import annotations

import math
from dataclasses import asdict, fields, is_dataclass
from typing import Any


def _pb_to_plain(msg: Any) -> Any:
    from google.protobuf.json_format import MessageToDict
    from google.protobuf.message import Message

    if isinstance(msg, Message):
        # Only unwrap suite Batch_* wrappers (name starts with Batch), not Document.items etc.
        name = msg.DESCRIPTOR.name if msg.DESCRIPTOR else ""
        if name.startswith("Batch") and any(f.name == "items" for f in msg.DESCRIPTOR.fields):
            return [_pb_to_plain(x) for x in msg.items]
        try:
            return MessageToDict(
                msg,
                preserving_proto_field_name=True,
                including_default_value_fields=True,
            )
        except TypeError:
            return MessageToDict(msg, preserving_proto_field_name=True)
    return msg


def _norm(obj: Any) -> Any:
    if obj is None:
        return None
    if hasattr(obj, "DESCRIPTOR") and hasattr(obj, "ListFields"):
        return _norm(_pb_to_plain(obj))
    if hasattr(obj, "__struct_fields__"):
        # Prefer named fields; array-like may still expose names
        try:
            return {name: _norm(getattr(obj, name)) for name in obj.__struct_fields__}
        except Exception:
            pass
    if is_dataclass(obj) and not isinstance(obj, type):
        return {f.name: _norm(getattr(obj, f.name)) for f in fields(obj)}
    if isinstance(obj, dict):
        return {str(k): _norm(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_norm(v) for v in obj]
    if isinstance(obj, float):
        return float(obj)
    if isinstance(obj, bool):
        return obj
    if isinstance(obj, int):
        return int(obj)
    if isinstance(obj, str):
        return obj
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


def _as_int(x: Any) -> Any:
    if isinstance(x, bool):
        return x
    if isinstance(x, int):
        return x
    if isinstance(x, str) and x.lstrip("-").isdigit():
        return int(x)
    if isinstance(x, float) and x == int(x):
        return int(x)
    return x


def _eq(a: Any, b: Any) -> bool:
    a, b = _norm(a), _norm(b)

    # msgspec array-like: dict (named) vs list (positional values in field order)
    if isinstance(a, dict) and isinstance(b, list):
        vals = list(a.values())
        if len(vals) != len(b):
            return False
        return all(_eq(x, y) for x, y in zip(vals, b))
    if isinstance(a, list) and isinstance(b, dict):
        return _eq(b, a)

    if isinstance(a, float) or isinstance(b, float):
        try:
            return math.isclose(float(a), float(b), rel_tol=1e-9, abs_tol=1e-9)
        except (TypeError, ValueError):
            return False

    # protobuf JSON often encodes int64 as string
    ai, bi = _as_int(a), _as_int(b)
    if ai is not a or bi is not b:
        if isinstance(ai, int) and isinstance(bi, int) and not isinstance(ai, bool) and not isinstance(bi, bool):
            return ai == bi

    if isinstance(a, dict) and isinstance(b, dict):
        for k, v in a.items():
            if k not in b:
                # proto3 JSON may omit default-ish values
                if v in (False, 0, 0.0, "", None, [], {}):
                    continue
                return False
            if not _eq(v, b[k]):
                return False
        return True

    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return False
        return all(_eq(x, y) for x, y in zip(a, b))

    return a == b


def fidelity_v2(expected: Any, actual: Any) -> float:
    return 1.0 if _eq(expected, actual) else 0.0
