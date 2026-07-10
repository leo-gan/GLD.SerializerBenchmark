"""FlatBuffers wrapper — serializer kept; V1 .fbs schemas removed.

V2 FlatBuffers schema is not generated yet. supports() is False so the
runner skips this codec until schemas/v2 flatbuffers land.
"""

from __future__ import annotations

import io
from typing import Any

from .base import Serializer


class FlatBuffersSerializer(Serializer):
    package_name = "flatbuffers"
    native_kind = "dataclass"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()

    @property
    def name(self) -> str:
        return "flatbuffers"

    def supports(self, test_data_name: str) -> bool:
        return False

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        raise TypeError("FlatBuffers V2 schema not generated yet")

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return obj

    def serialize_bytes(self, obj: Any) -> bytes:
        raise NotImplementedError("FlatBuffers V2 not wired")

    def deserialize_bytes(self, data: bytes) -> Any:
        raise NotImplementedError("FlatBuffers V2 not wired")

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
