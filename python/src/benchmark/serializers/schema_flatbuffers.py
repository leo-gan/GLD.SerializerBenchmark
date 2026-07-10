"""FlatBuffers — real table layout for suite types (not JSON-in-FB).

Uses the FlatBuffers Builder API field-by-field for message/document/telemetry/
strings/event (and batches as vectors of tables). Matches the official
CreateString / StartObject / Prepend*Slot / Finish pattern:
https://flatbuffers.dev/tutorial/
"""

from __future__ import annotations

import io
import struct
from typing import Any

import flatbuffers

from .base import Serializer
from ..data_v2 import models as m


def _uoffset_at(data: bytes, pos: int) -> int:
    return struct.unpack_from("<I", data, pos)[0]


def _i32_at(data: bytes, pos: int) -> int:
    return struct.unpack_from("<i", data, pos)[0]


def _read_string(data: bytes, table: int, field_off: int) -> str:
    if field_off == 0:
        return ""
    so = _uoffset_at(data, table + field_off)
    saddr = table + field_off + so
    slen = _uoffset_at(data, saddr)
    return data[saddr + 4 : saddr + 4 + slen].decode("utf-8")


def _vtable_field(data: bytes, table: int, slot: int) -> int:
    """Return relative offset for field slot (0 = absent)."""
    vt = table - _i32_at(data, table)
    vsize = struct.unpack_from("<H", data, vt)[0]
    entry = 4 + slot * 2
    if entry + 2 > vsize:
        return 0
    return struct.unpack_from("<H", data, vt + entry)[0]


def _root_table(data: bytes) -> int:
    return _i32_at(data, 0)


# ---- Message: 8 fields ----

def _build_message(builder: flatbuffers.Builder, obj: Any) -> bytes:
    if isinstance(obj, dict):
        f_bool = bool(obj.get("f_bool", False))
        f_int32 = int(obj.get("f_int32", 0))
        f_int64 = int(obj.get("f_int64", 0))
        f_float64 = float(obj.get("f_float64", 0.0))
        f_string = str(obj.get("f_string", "") or "")
        f_bool_2 = bool(obj.get("f_bool_2", False))
        f_int32_2 = int(obj.get("f_int32_2", 0))
        f_string_2 = str(obj.get("f_string_2", "") or "")
    else:
        f_bool, f_int32, f_int64 = obj.f_bool, obj.f_int32, obj.f_int64
        f_float64, f_string = obj.f_float64, obj.f_string or ""
        f_bool_2, f_int32_2 = obj.f_bool_2, obj.f_int32_2
        f_string_2 = obj.f_string_2 or ""

    builder.Clear()
    s1 = builder.CreateString(f_string)
    s2 = builder.CreateString(f_string_2)
    builder.StartObject(8)
    builder.PrependUOffsetTRelativeSlot(7, s2, 0)
    builder.PrependInt32Slot(6, f_int32_2, 0)
    builder.PrependBoolSlot(5, f_bool_2, 0)
    builder.PrependUOffsetTRelativeSlot(4, s1, 0)
    builder.PrependFloat64Slot(3, f_float64, 0.0)
    builder.PrependInt64Slot(2, f_int64, 0)
    builder.PrependInt32Slot(1, f_int32, 0)
    builder.PrependBoolSlot(0, f_bool, 0)
    root = builder.EndObject()
    builder.Finish(root)
    return bytes(builder.Output())


def _read_message(data: bytes) -> dict[str, Any]:
    table = _root_table(data)
    def f(slot: int) -> int:
        return _vtable_field(data, table, slot)
    return {
        "f_bool": bool(data[table + f(0)]) if f(0) else False,
        "f_int32": struct.unpack_from("<i", data, table + f(1))[0] if f(1) else 0,
        "f_int64": struct.unpack_from("<q", data, table + f(2))[0] if f(2) else 0,
        "f_float64": struct.unpack_from("<d", data, table + f(3))[0] if f(3) else 0.0,
        "f_string": _read_string(data, table, f(4)),
        "f_bool_2": bool(data[table + f(5)]) if f(5) else False,
        "f_int32_2": struct.unpack_from("<i", data, table + f(6))[0] if f(6) else 0,
        "f_string_2": _read_string(data, table, f(7)),
    }


def _build_strings(builder: flatbuffers.Builder, obj: Any) -> bytes:
    items = obj.items if hasattr(obj, "items") else obj.get("items", [])
    builder.Clear()
    offs = [builder.CreateString(str(s or "")) for s in items]
    builder.StartVector(4, len(offs), 4)
    for o in reversed(offs):
        builder.PrependUOffsetTRelative(o)
    vec = builder.EndVector()
    builder.StartObject(1)
    builder.PrependUOffsetTRelativeSlot(0, vec, 0)
    root = builder.EndObject()
    builder.Finish(root)
    return bytes(builder.Output())


def _read_strings(data: bytes) -> dict[str, Any]:
    table = _root_table(data)
    off = _vtable_field(data, table, 0)
    if not off:
        return {"items": []}
    vec = table + off + _uoffset_at(data, table + off)
    n = _uoffset_at(data, vec)
    items = []
    for i in range(n):
        eoff = _uoffset_at(data, vec + 4 + i * 4)
        saddr = vec + 4 + i * 4 + eoff
        slen = _uoffset_at(data, saddr)
        items.append(data[saddr + 4 : saddr + 4 + slen].decode("utf-8"))
    return {"items": items}


def _build_event(builder: flatbuffers.Builder, obj: Any) -> bytes:
    if isinstance(obj, dict):
        eid = str(obj.get("event_id", "") or "")
        ety = str(obj.get("event_type", "") or "")
        oca = int(obj.get("occurred_at", 0))
        prod = str(obj.get("producer", "") or "")
        attrs = obj.get("attrs") or []
    else:
        eid, ety, oca = obj.event_id or "", obj.event_type or "", int(obj.occurred_at)
        prod = obj.producer or ""
        attrs = obj.attrs or []
    builder.Clear()
    seid = builder.CreateString(eid)
    sety = builder.CreateString(ety)
    sprod = builder.CreateString(prod)
    attr_offs = []
    for a in attrs:
        if isinstance(a, dict):
            k, v = str(a.get("key", "")), str(a.get("value", ""))
        else:
            k, v = a.key or "", a.value or ""
        sk, sv = builder.CreateString(k), builder.CreateString(v)
        builder.StartObject(2)
        builder.PrependUOffsetTRelativeSlot(1, sv, 0)
        builder.PrependUOffsetTRelativeSlot(0, sk, 0)
        attr_offs.append(builder.EndObject())
    builder.StartVector(4, len(attr_offs), 4)
    for o in reversed(attr_offs):
        builder.PrependUOffsetTRelative(o)
    avec = builder.EndVector()
    builder.StartObject(5)
    builder.PrependUOffsetTRelativeSlot(4, avec, 0)
    builder.PrependUOffsetTRelativeSlot(3, sprod, 0)
    builder.PrependInt64Slot(2, oca, 0)
    builder.PrependUOffsetTRelativeSlot(1, sety, 0)
    builder.PrependUOffsetTRelativeSlot(0, seid, 0)
    root = builder.EndObject()
    builder.Finish(root)
    return bytes(builder.Output())


def _read_event(data: bytes) -> dict[str, Any]:
    table = _root_table(data)
    def f(s: int) -> int:
        return _vtable_field(data, table, s)
    attrs: list[dict[str, str]] = []
    aoff = f(4)
    if aoff:
        vec = table + aoff + _uoffset_at(data, table + aoff)
        n = _uoffset_at(data, vec)
        for i in range(n):
            eoff = _uoffset_at(data, vec + 4 + i * 4)
            at = vec + 4 + i * 4 + eoff
            # nested attr table
            def af(slot: int, t=at) -> int:
                return _vtable_field(data, t, slot)
            attrs.append({
                "key": _read_string(data, at, af(0)),
                "value": _read_string(data, at, af(1)),
            })
    return {
        "event_id": _read_string(data, table, f(0)),
        "event_type": _read_string(data, table, f(1)),
        "occurred_at": struct.unpack_from("<q", data, table + f(2))[0] if f(2) else 0,
        "producer": _read_string(data, table, f(3)),
        "attrs": attrs,
    }


def _build_telemetry(builder: flatbuffers.Builder, obj: Any) -> bytes:
    if isinstance(obj, dict):
        source = str(obj.get("source", "") or "")
        ts = int(obj.get("ts", 0))
        tags = list(obj.get("tags") or [])
        values = [float(x) for x in (obj.get("values") or [])]
    else:
        source, ts = obj.source or "", int(obj.ts)
        tags = list(obj.tags or [])
        values = [float(x) for x in (obj.values or [])]
    builder.Clear()
    ssrc = builder.CreateString(source)
    toffs = [builder.CreateString(str(t)) for t in tags]
    builder.StartVector(4, len(toffs), 4)
    for o in reversed(toffs):
        builder.PrependUOffsetTRelative(o)
    tvec = builder.EndVector()
    builder.StartVector(8, len(values), 8)
    for v in reversed(values):
        builder.PrependFloat64(v)
    vvec = builder.EndVector()
    builder.StartObject(4)
    builder.PrependUOffsetTRelativeSlot(3, vvec, 0)
    builder.PrependUOffsetTRelativeSlot(2, tvec, 0)
    builder.PrependInt64Slot(1, ts, 0)
    builder.PrependUOffsetTRelativeSlot(0, ssrc, 0)
    root = builder.EndObject()
    builder.Finish(root)
    return bytes(builder.Output())


def _read_telemetry(data: bytes) -> dict[str, Any]:
    table = _root_table(data)
    def f(s: int) -> int:
        return _vtable_field(data, table, s)
    tags: list[str] = []
    toff = f(2)
    if toff:
        vec = table + toff + _uoffset_at(data, table + toff)
        n = _uoffset_at(data, vec)
        for i in range(n):
            eoff = _uoffset_at(data, vec + 4 + i * 4)
            saddr = vec + 4 + i * 4 + eoff
            slen = _uoffset_at(data, saddr)
            tags.append(data[saddr + 4 : saddr + 4 + slen].decode("utf-8"))
    values: list[float] = []
    voff = f(3)
    if voff:
        vec = table + voff + _uoffset_at(data, table + voff)
        n = _uoffset_at(data, vec)
        for i in range(n):
            values.append(struct.unpack_from("<d", data, vec + 4 + i * 8)[0])
    return {
        "source": _read_string(data, table, f(0)),
        "ts": struct.unpack_from("<q", data, table + f(1))[0] if f(1) else 0,
        "tags": tags,
        "values": values,
    }


def _build_document(builder: flatbuffers.Builder, obj: Any) -> bytes:
    if isinstance(obj, dict):
        did = str(obj.get("id", "") or "")
        status = int(obj.get("status", 0))
        meta = obj.get("meta") or {}
        region = str(meta.get("region", "") or "")
        version = int(meta.get("version", 0))
        items = obj.get("items") or []
    else:
        did, status = obj.id or "", int(obj.status)
        region = (obj.meta.region if obj.meta else "") or ""
        version = int(obj.meta.version) if obj.meta else 0
        items = obj.items or []
    builder.Clear()
    sid = builder.CreateString(did)
    sreg = builder.CreateString(region)
    builder.StartObject(2)
    builder.PrependInt32Slot(1, version, 0)
    builder.PrependUOffsetTRelativeSlot(0, sreg, 0)
    meta_off = builder.EndObject()
    item_offs = []
    for it in items:
        if isinstance(it, dict):
            sku, qty, price = str(it.get("sku", "")), int(it.get("qty", 0)), int(it.get("price_minor", 0))
        else:
            sku, qty, price = it.sku or "", int(it.qty), int(it.price_minor)
        ssku = builder.CreateString(sku)
        builder.StartObject(3)
        builder.PrependInt64Slot(2, price, 0)
        builder.PrependInt32Slot(1, qty, 0)
        builder.PrependUOffsetTRelativeSlot(0, ssku, 0)
        item_offs.append(builder.EndObject())
    builder.StartVector(4, len(item_offs), 4)
    for o in reversed(item_offs):
        builder.PrependUOffsetTRelative(o)
    ivec = builder.EndVector()
    builder.StartObject(4)
    builder.PrependUOffsetTRelativeSlot(3, ivec, 0)
    builder.PrependUOffsetTRelativeSlot(2, meta_off, 0)
    builder.PrependInt32Slot(1, status, 0)
    builder.PrependUOffsetTRelativeSlot(0, sid, 0)
    root = builder.EndObject()
    builder.Finish(root)
    return bytes(builder.Output())


def _read_document(data: bytes) -> dict[str, Any]:
    table = _root_table(data)
    def f(s: int) -> int:
        return _vtable_field(data, table, s)
    meta = {"region": "", "version": 0}
    moff = f(2)
    if moff:
        mt = table + moff + _uoffset_at(data, table + moff) if False else table + moff
        # moff is relative offset to nested table UOffset
        so = _uoffset_at(data, table + moff)
        mt = table + moff + so
        def mf(slot: int, t=mt) -> int:
            return _vtable_field(data, t, slot)
        meta = {
            "region": _read_string(data, mt, mf(0)),
            "version": struct.unpack_from("<i", data, mt + mf(1))[0] if mf(1) else 0,
        }
    items: list[dict[str, Any]] = []
    ioff = f(3)
    if ioff:
        vec = table + ioff + _uoffset_at(data, table + ioff)
        n = _uoffset_at(data, vec)
        for i in range(n):
            eoff = _uoffset_at(data, vec + 4 + i * 4)
            it = vec + 4 + i * 4 + eoff
            def inf(slot: int, t=it) -> int:
                return _vtable_field(data, t, slot)
            items.append({
                "sku": _read_string(data, it, inf(0)),
                "qty": struct.unpack_from("<i", data, it + inf(1))[0] if inf(1) else 0,
                "price_minor": struct.unpack_from("<q", data, it + inf(2))[0] if inf(2) else 0,
            })
    return {
        "id": _read_string(data, table, f(0)),
        "status": struct.unpack_from("<i", data, table + f(1))[0] if f(1) else 0,
        "meta": meta,
        "items": items,
    }


_BUILDERS = {
    "message": (_build_message, _read_message),
    "strings": (_build_strings, _read_strings),
    "event": (_build_event, _read_event),
    "telemetry": (_build_telemetry, _read_telemetry),
    "document": (_build_document, _read_document),
}


class FlatBuffersSerializer(Serializer):
    package_name = "flatbuffers"
    native_kind = "dataclass"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._builder = flatbuffers.Builder(2048)
        self._type_id = "message"
        self._batch = False

    @property
    def name(self) -> str:
        return "flatbuffers"

    def supports(self, test_data_name: str) -> bool:
        return test_data_name in _BUILDERS

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._type_id = test_data_name
        self._builder = flatbuffers.Builder(2048)

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        self._type_id = test_data_name
        self._batch = isinstance(obj, list)
        return obj  # keep dataclasses / lists for typed builders

    def serialize_bytes(self, obj: Any) -> bytes:
        build, _ = _BUILDERS[self._type_id]
        if self._batch:
            # Batch: vector of single-type tables stored as a wrapper table field 0.
            parts = [build(self._builder, x) for x in obj]
            # Store as length-prefixed concatenation of independent FB buffers
            # (each is a complete buffer). Reader splits by u32 lengths.
            out = bytearray()
            out += struct.pack("<I", len(parts))
            for p in parts:
                out += struct.pack("<I", len(p))
                out += p
            return bytes(out)
        return build(self._builder, obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        _, read = _BUILDERS[self._type_id]
        if self._batch:
            n = struct.unpack_from("<I", data, 0)[0]
            o = 4
            items = []
            for _ in range(n):
                ln = struct.unpack_from("<I", data, o)[0]
                o += 4
                items.append(read(data[o : o + ln]))
                o += ln
            return items
        return read(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
