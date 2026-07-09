"""
msgpack benchmark wrapper.

Call-path: prepare_data converts dataclasses to dicts (untimed).
Timed path reuses a msgpack.Packer (documented high-performance path — avoids
per-call Packer allocation inside packb) and unpackb for bytes decode.
Stream mode uses native pack/unpack.
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

    def __init__(self) -> None:
        super().__init__()
        # Reused Packer: packb() constructs a new Packer every call (~25–30% slower).
        self._packer = msgpack.Packer(use_bin_type=True)

    @property
    def name(self) -> str:
        return "msgpack"

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        # Fresh packer per data type (state is otherwise fine to reuse).
        self._packer = msgpack.Packer(use_bin_type=True)

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return self._packer.pack(obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        return msgpack.unpackb(data, strict_map_key=False)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        # Reuse Packer; pack() allocates a new Packer each call.
        stream.write(self._packer.pack(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return msgpack.unpack(stream, strict_map_key=False)
