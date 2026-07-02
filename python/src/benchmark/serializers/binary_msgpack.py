"""
msgpack benchmark wrapper.

Call-path: prepare_data converts dataclasses to dicts (untimed).
Timed path uses packb/unpackb (and native pack/unpack for stream mode).
"""

from __future__ import annotations

import io
from typing import Any

import msgpack

from .base import Serializer
from ..converters import to_dict


class MsgpackSerializer(Serializer):
    native_kind = "dict"
    stream_mode = "native"

    @property
    def name(self) -> str:
        return "msgpack"

    def supports(self, test_data_name: str) -> bool:
        return test_data_name != "ObjectGraph"

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return msgpack.packb(obj, use_bin_type=True)

    def deserialize_bytes(self, data: bytes) -> Any:
        return msgpack.unpackb(data, strict_map_key=False)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        msgpack.pack(obj, stream, use_bin_type=True)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return msgpack.unpack(stream, strict_map_key=False)
