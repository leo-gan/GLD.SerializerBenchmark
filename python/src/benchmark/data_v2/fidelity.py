"""Semantic fidelity for v2 instances (dataclass, dict, list batch, protobuf, msgspec)."""

from __future__ import annotations

import math
from collections.abc import Mapping
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
    # amazon.ion IonPyDict is a Mapping and not a dict.
    if isinstance(obj, Mapping):
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


def _is_node(obj: Any) -> bool:
    return is_dataclass(obj) and not isinstance(obj, type)


def _graph_pair(a: Any, b: Any, memo_a: dict[int, int], memo_b: dict[int, int]) -> bool:
    """Structural compare that treats shared nodes and cycles as identity.

    Two visits of the same object must land on the same token on the other side.
    Scalars compare by value. Lists compare in order and do not become nodes.
    """
    if a is None or b is None:
        return a is None and b is None
    if _is_node(a) or _is_node(b):
        if not (_is_node(a) and _is_node(b)):
            return False
        id_a, id_b = id(a), id(b)
        seen_a = id_a in memo_a
        seen_b = id_b in memo_b
        if seen_a or seen_b:
            return seen_a and seen_b and memo_a[id_a] == memo_b[id_b]
        token = len(memo_a)
        memo_a[id_a] = token
        memo_b[id_b] = token
        fields_a = [f.name for f in fields(a)]
        fields_b = [f.name for f in fields(b)]
        if fields_a != fields_b:
            return False
        for name in fields_a:
            if not _graph_pair(getattr(a, name), getattr(b, name), memo_a, memo_b):
                return False
        return True
    if isinstance(a, (list, tuple)) or isinstance(b, (list, tuple)):
        if not isinstance(a, (list, tuple)) or not isinstance(b, (list, tuple)):
            return False
        if len(a) != len(b):
            return False
        return all(_graph_pair(x, y, memo_a, memo_b) for x, y in zip(a, b))
    if isinstance(a, bool) or isinstance(b, bool):
        return isinstance(a, bool) and isinstance(b, bool) and a is b
    if isinstance(a, float) or isinstance(b, float):
        try:
            return math.isclose(float(a), float(b), rel_tol=1e-9, abs_tol=1e-9)
        except (TypeError, ValueError):
            return False
    return a == b


def fidelity_graph(expected: Any, actual: Any) -> float:
    """Identity fidelity for one graph or a batch of independent graphs."""
    if isinstance(expected, list):
        if not isinstance(actual, list) or len(expected) != len(actual):
            return 0.0
        ok = all(_graph_pair(a, b, {}, {}) for a, b in zip(expected, actual))
        return 1.0 if ok else 0.0
    return 1.0 if _graph_pair(expected, actual, {}, {}) else 0.0


def fidelity_for(type_id: str, expected: Any, actual: Any) -> float:
    """Dispatch fidelity. ``graph`` must not use the structural walk."""
    if type_id == "graph":
        return fidelity_graph(expected, actual)
    return fidelity_v2(expected, actual)


def project_f_float_0(decoded: Any) -> list[float]:
    """Pull ``f_float_0`` from a full table row, a batch, or a batch protobuf message."""
    if hasattr(decoded, "DESCRIPTOR") and getattr(decoded, "DESCRIPTOR", None) is not None:
        name = decoded.DESCRIPTOR.name or ""
        if name.startswith("Batch"):
            return [float(item.f_float_0) for item in decoded.items]
        return [float(decoded.f_float_0)]
    if isinstance(decoded, list):
        return [float(_row_field(row, "f_float_0")) for row in decoded]
    return [float(_row_field(decoded, "f_float_0"))]


def _row_field(row: Any, name: str) -> Any:
    if isinstance(row, Mapping):
        return row[name]
    return getattr(row, name)


def expected_for_fidelity(type_id: str, instances: list[Any]) -> Any:
    """Value compared after deserialize.

    ``table_project`` serializes the full row and deserializes ``f_float_0`` only,
    including when N is 1. Other types compare the single instance or the batch list.
    """
    if type_id == "table_project":
        return [float(getattr(row, "f_float_0")) for row in instances]
    if len(instances) == 1:
        return instances[0]
    return list(instances)
