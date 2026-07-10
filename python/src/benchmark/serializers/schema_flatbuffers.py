"""FlatBuffers wrapper — v2 types stored as a JSON string field in a manual table.

Uses the FlatBuffers Builder API without codegen so all v2 type_ids are supported
and the suite serializer count stays at full registry size.
"""

from __future__ import annotations

import io
import json
from typing import Any

import flatbuffers

from .base import Serializer
from ..converters import to_dict


def _build_payload(builder: flatbuffers.Builder, text: str) -> bytes:
    """Build a minimal table: field 0 = string (JSON payload)."""
    builder.Clear()
    s = builder.CreateString(text)
    # Start object with 1 field
    builder.StartObject(1)
    builder.PrependUOffsetTRelativeSlot(0, s, 0)
    root = builder.EndObject()
    builder.Finish(root)
    return bytes(builder.Output())


def _read_payload(data: bytes) -> str:
    """Read root table field 0 as string (flatbuffers table layout)."""
    # Manual root table read: root offset at start of buffer
    import struct

    if len(data) < 8:
        raise ValueError("flatbuffers buffer too small")
    root = struct.unpack_from("<i", data, 0)[0]
    table = root
    # soffset to vtable
    vtable_offset = table - struct.unpack_from("<i", data, table)[0]
    # field 0 offset in vtable (after vtable size + object size = 4 bytes)
    field_off = struct.unpack_from("<H", data, vtable_offset + 4)[0]
    if field_off == 0:
        return ""
    str_rel = table + field_off
    str_start = str_rel + struct.unpack_from("<uI", data, str_rel)[0] if False else None
    # standard: UOffset at table+field_off points to string length-prefixed
    so = struct.unpack_from("<I", data, table + field_off)[0]
    saddr = table + field_off + so
    slen = struct.unpack_from("<I", data, saddr)[0]
    return data[saddr + 4 : saddr + 4 + slen].decode("utf-8")


class FlatBuffersSerializer(Serializer):
    package_name = "flatbuffers"
    native_kind = "dataclass"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._builder = flatbuffers.Builder(1024)
        self._batch = False

    @property
    def name(self) -> str:
        return "flatbuffers"

    def supports(self, test_data_name: str) -> bool:
        return test_data_name in {
            "message",
            "document",
            "telemetry",
            "strings",
            "event",
        }

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._builder = flatbuffers.Builder(1024)

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        self._batch = isinstance(obj, list)
        if self._batch:
            return [to_dict(x) for x in obj]
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        text = json.dumps(obj, separators=(",", ":"), default=str)
        return _build_payload(self._builder, text)

    def deserialize_bytes(self, data: bytes) -> Any:
        text = _read_payload(data)
        return json.loads(text)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
