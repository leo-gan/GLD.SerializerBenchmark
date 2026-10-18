"""Map v2 dataclasses ↔ generated benchmark.v2 protobuf messages."""

from __future__ import annotations

import os
import sys
from typing import Any, List, Type, Union

from .models import (
    Document,
    DocumentItem,
    DocumentMeta,
    Event,
    EventAttr,
    InferenceRequest,
    Message,
    NestedRow,
    Prompt,
    Shard,
    Signal,
    Strings,
    TableRow,
    Telemetry,
    TensorMatrix,
)

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

try:
    from generated.v2 import tensor_pb2 as tpb  # type: ignore
except ImportError:
    try:
        from v2 import tensor_pb2 as tpb  # type: ignore
    except ImportError:
        tpb = None  # type: ignore


def available() -> bool:
    return pb2 is not None


def tensor_available() -> bool:
    return tpb is not None


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
        ("table", False): pb2.Table,
        ("table", True): pb2.BatchTable,
        # table_project encodes the same Table. The runner expects f_float_0 only.
        ("table_project", False): pb2.Table,
        ("table_project", True): pb2.BatchTable,
        ("nested_table", False): pb2.NestedRow,
        ("nested_table", True): pb2.BatchNestedRow,
        ("signal", False): pb2.Signal,
        ("signal", True): pb2.BatchSignal,
    }
    if tpb is not None and not batch:
        tensor_table = {
            "tensor": tpb.TensorMatrix,
            "prompt": tpb.Prompt,
            "shard": tpb.Shard,
            "request": tpb.InferenceRequest,
        }
        if type_id in tensor_table:
            return tensor_table[type_id]
    return table.get((type_id, batch))


def to_pb(obj: Any) -> Any:
    if pb2 is None:
        raise RuntimeError("v2 protobuf stubs not available")
    if isinstance(obj, (TensorMatrix, Prompt, Shard, InferenceRequest)):
        return _tensor_to_pb(obj)
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
    if isinstance(obj, TableRow):
        m = pb2.Table()
        for i in range(16):
            setattr(m, f"f_float_{i}", getattr(obj, f"f_float_{i}"))
        for i in range(4):
            setattr(m, f"f_int_{i}", getattr(obj, f"f_int_{i}"))
        m.f_str_0 = obj.f_str_0
        m.f_str_1 = obj.f_str_1
        return m
    if isinstance(obj, NestedRow):
        d = pb2.NestedRow()
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
    if isinstance(obj, Signal):
        m = pb2.Signal()
        m.seq = obj.seq
        m.ts = obj.ts
        m.price_mantissa = obj.price_mantissa
        m.qty = obj.qty
        m.flags = obj.flags
        m.symbol = obj.symbol
        m.venue = obj.venue
        for leg in obj.legs:
            row = m.legs.add()
            row.leg_id = leg.leg_id
            row.leg_qty = leg.leg_qty
            row.leg_pad = leg.leg_pad
        return m
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
    if isinstance(item, TableRow):
        return pb2.BatchTable()
    if isinstance(item, NestedRow):
        return pb2.BatchNestedRow()
    if isinstance(item, Signal):
        return pb2.BatchSignal()
    raise TypeError(type(item))


def _tensor_to_pb(obj: Any) -> Any:
    if tpb is None:
        raise RuntimeError("tensor protobuf stubs not available")
    if isinstance(obj, TensorMatrix):
        msg = tpb.TensorMatrix()
        msg.rows = obj.rows
        msg.cols = obj.cols
        msg.values.extend(obj.values)
        return msg
    if isinstance(obj, Prompt):
        return _prompt_to_pb(obj)
    if isinstance(obj, Shard):
        msg = tpb.Shard()
        msg.vocab = obj.vocab
        msg.hidden = obj.hidden
        msg.ffn = obj.ffn
        msg.tok_emb.extend(obj.tok_emb)
        msg.attn.extend(obj.attn)
        msg.ffn_weight.extend(obj.ffn_weight)
        msg.norm.extend(obj.norm)
        return msg
    if isinstance(obj, InferenceRequest):
        msg = tpb.InferenceRequest()
        msg.request_id = obj.request_id
        msg.model = obj.model
        msg.temperature = obj.temperature
        msg.inputs.CopyFrom(_prompt_to_pb(obj.inputs))
        return msg
    raise TypeError(type(obj))


def _prompt_to_pb(obj: Prompt) -> Any:
    msg = tpb.Prompt()
    msg.batch = obj.batch
    msg.seq = obj.seq
    msg.input_ids.extend(obj.input_ids)
    msg.attention_mask.extend(obj.attention_mask)
    msg.position_ids.extend(obj.position_ids)
    return msg


def tensor_from_pb(msg: Any) -> Any:
    name = msg.DESCRIPTOR.name if getattr(msg, "DESCRIPTOR", None) else ""
    if name == "TensorMatrix":
        return TensorMatrix(rows=msg.rows, cols=msg.cols, values=[float(v) for v in msg.values])
    if name == "Prompt":
        return _prompt_from_pb(msg)
    if name == "Shard":
        return Shard(
            vocab=msg.vocab,
            hidden=msg.hidden,
            ffn=msg.ffn,
            tok_emb=[float(v) for v in msg.tok_emb],
            attn=[float(v) for v in msg.attn],
            ffn_weight=[float(v) for v in msg.ffn_weight],
            norm=[float(v) for v in msg.norm],
        )
    if name == "InferenceRequest":
        return InferenceRequest(
            request_id=int(msg.request_id),
            model=msg.model,
            temperature=float(msg.temperature),
            inputs=_prompt_from_pb(msg.inputs),
        )
    raise TypeError(name)


def _prompt_from_pb(msg: Any) -> Prompt:
    return Prompt(
        batch=msg.batch,
        seq=msg.seq,
        input_ids=[int(v) for v in msg.input_ids],
        attention_mask=[int(v) for v in msg.attention_mask],
        position_ids=[int(v) for v in msg.position_ids],
    )
