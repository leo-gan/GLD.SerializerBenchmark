"""
serpyco-rs benchmark wrapper.

serpyco-rs converts dataclasses ↔ dict; wire JSON uses orjson (common production
pairing). prepare builds the typed Serializer. Timed path:
  dump + orjson.dumps  /  orjson.loads + load
"""

from __future__ import annotations

import io
from typing import Any

import orjson
from serpyco_rs import Serializer as SerpycoCodec

from .base import Serializer


class SerpycoSerializer(Serializer):
    native_kind = "dataclass"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._codec: Any = None
        self._is_scalar = False

    @property
    def name(self) -> str:
        return "serpyco-rs"

    def supports(self, test_data_name: str) -> bool:
        # serpyco-rs targets structured types; bare int is not a useful case
        return test_data_name not in ("ObjectGraph", "Integer")

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._codec = SerpycoCodec(test_data_type)
        self._is_scalar = False

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return obj

    def serialize_bytes(self, obj: Any) -> bytes:
        return orjson.dumps(self._codec.dump(obj))

    def deserialize_bytes(self, data: bytes) -> Any:
        return self._codec.load(orjson.loads(data))

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
