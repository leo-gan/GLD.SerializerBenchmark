"""Map v2 dataclasses ↔ generated benchmark.v2 protobuf messages."""

from __future__ import annotations

import os
import sys
from typing import Any, List, Type, Union

from .models import Document, DocumentItem, DocumentMeta, Event, EventAttr, Message, Strings, Telemetry

# python/generated is on path when running as package (same as v1 protobuf).
_gen_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "generated"))
if _gen_root not in sys.path:
    sys.path.insert(0, _gen_root)
_py_root = os.path.abspath(os.path.join(_gen_root, ".."))
if _py_root not in sys.path:
    sys.path.insert(0, _py_root)

try:
    from generated.v2 import benchmark_v2_pb2 as pb2  # type: ignore
except ImportError:
    try:
        from v2 import benchmark_v2_pb2 as pb2  # type: ignore
    except ImportError:
        pb2 = None  # type: ignore


def available() -> bool:
    return pb2 is not None


def message_class_for(type_id: str, batch: bool) -> Type[Any] | None:
    if pb2 is None:
        return None
    table = {
        ("message", False): pb2.Message,
        ("message", True): pb2.BatchMessage,
        ("document", False): pb2.Document,
        ("document", True): pb2.BatchDocument,
        ("telemetry", False): pb2.Telemetry,
        ("telemetry", True): pb2.BatchTelemetry,
        ("strings", False): pb2.Strings,
        ("strings", True): pb2.BatchStrings,
        ("event", False): pb2.Event,
        ("event", True): pb2.BatchEvent,
    }
    return table.get((type_id, batch))


def to_pb(obj: Any) -> Any:
    if pb2 is None:
        raise RuntimeError("v2 protobuf stubs not available")
    if isinstance(obj, list):
        if not obj:
            raise ValueError("empty batch")
        batch = _batch_for_item(obj[0])
        for item in obj:
            batch.items.append(to_pb(item))
        return batch
    if isinstance(obj, Message):
        m = pb2.Message()
        m.f_bool = obj.f_bool
        m.f_int32 = obj.f_int32
        m.f_int64 = obj.f_int64
        m.f_float64 = obj.f_float64
        m.f_string = obj.f_string
        m.f_bool_2 = obj.f_bool_2
        m.f_int32_2 = obj.f_int32_2
        m.f_string_2 = obj.f_string_2
        return m
    if isinstance(obj, Document):
        d = pb2.Document()
        d.id = obj.id
        d.status = obj.status
        d.meta.region = obj.meta.region
        d.meta.version = obj.meta.version
        for it in obj.items:
            row = d.items.add()
            row.sku = it.sku
            row.qty = it.qty
            row.price_minor = it.price_minor
        return d
    if isinstance(obj, Telemetry):
        t = pb2.Telemetry()
        t.source = obj.source
        t.ts = obj.ts
        t.tags.extend(obj.tags)
        t.values.extend(obj.values)
        return t
    if isinstance(obj, Strings):
        s = pb2.Strings()
        s.items.extend(obj.items)
        return s
    if isinstance(obj, Event):
        e = pb2.Event()
        e.event_id = obj.event_id
        e.event_type = obj.event_type
        e.occurred_at = obj.occurred_at
        e.producer = obj.producer
        for a in obj.attrs:
            row = e.attrs.add()
            row.key = a.key
            row.value = a.value
        return e
    raise TypeError(f"unsupported v2 type for protobuf: {type(obj)}")


def _batch_for_item(item: Any) -> Any:
    if isinstance(item, Message):
        return pb2.BatchMessage()
    if isinstance(item, Document):
        return pb2.BatchDocument()
    if isinstance(item, Telemetry):
        return pb2.BatchTelemetry()
    if isinstance(item, Strings):
        return pb2.BatchStrings()
    if isinstance(item, Event):
        return pb2.BatchEvent()
    raise TypeError(type(item))
