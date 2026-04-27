"""
Shared conversion utilities.

Most Python serializers do not natively understand dataclasses or datetime
objects. This module provides canonical `to_dict` / `from_dict` conversions
that maximize type fidelity for JSON and binary serializers.

Schema-based serializers (Protobuf, Avro) have their own dedicated conversion
functions in their wrapper modules.
"""

from __future__ import annotations

import datetime
from dataclasses import asdict, fields, is_dataclass
from enum import Enum
from typing import Any, Dict, List, Type, TypeVar, get_args, get_origin, get_type_hints

T = TypeVar("T")


def _is_list_type(t: Any) -> bool:
    origin = get_origin(t)
    return origin is list or origin is List


def _is_optional_type(t: Any) -> bool:
    args = get_args(t)
    if len(args) == 2:
        return type(None) in args
    return False


def _get_inner_type(t: Any) -> Any:
    args = get_args(t)
    if _is_optional_type(t):
        return next(a for a in args if a is not type(None))
    if args:
        return args[0]
    return Any


def to_dict(obj: Any) -> Any:
    """Recursively convert dataclasses, enums, and datetimes to JSON-friendly primitives."""
    if obj is None:
        return None
    if isinstance(obj, Enum):
        return obj.name
    if isinstance(obj, datetime.datetime):
        return obj.isoformat()
    if isinstance(obj, (list, tuple)):
        return [to_dict(v) for v in obj]
    if isinstance(obj, dict):
        return {k: to_dict(v) for k, v in obj.items()}
    if is_dataclass(obj) and not isinstance(obj, type):
        return {k: to_dict(v) for k, v in asdict(obj).items()}
    return obj


def from_dict(data: Any, cls: Type[T]) -> T:
    """Recursively reconstruct a dataclass from JSON-friendly primitives."""
    if data is None:
        return None  # type: ignore[return-value]

    # Scalar passthrough
    if cls in (int, float, str, bool, bytes, Any) or cls is Any:
        return data  # type: ignore[return-value]

    # Enum reconstruction
    if issubclass(cls, Enum):
        return cls[data]  # type: ignore[return-value]

    # datetime reconstruction
    if cls is datetime.datetime:
        if isinstance(data, datetime.datetime):
            return data  # type: ignore[return-value]
        if isinstance(data, str):
            # Try ISO format parsing
            for fmt in ("%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S"):
                try:
                    return datetime.datetime.strptime(data.split("+")[0].split("Z")[0], fmt)  # type: ignore[return-value]
                except ValueError:
                    continue
        if isinstance(data, (int, float)):
            return datetime.datetime.utcfromtimestamp(data)  # type: ignore[return-value]
        raise ValueError(f"Cannot parse datetime from {data!r}")

    # List reconstruction
    origin = get_origin(cls)
    if origin in (list, List):
        inner = _get_inner_type(cls)
        return [from_dict(item, inner) for item in data]  # type: ignore[return-value]

    # Optional reconstruction
    if _is_optional_type(cls):
        inner = _get_inner_type(cls)
        return from_dict(data, inner)

    # Dataclass reconstruction
    if is_dataclass(cls):
        type_hints = get_type_hints(cls)
        kwargs = {}
        for field_name in type_hints:
            if field_name in data:
                kwargs[field_name] = from_dict(data[field_name], type_hints[field_name])
        return cls(**kwargs)  # type: ignore[return-value]

    return data  # type: ignore[return-value]
