"""
mashumaro benchmark wrapper (orjson codec backend).

prepare builds typed encoders/decoders. Timed path is encode/decode only on
canonical dataclasses (mashumaro's supported model style).
"""

from __future__ import annotations

import io
from typing import Any

from mashumaro.codecs.orjson import ORJSONDecoder, ORJSONEncoder

from .base import Serializer


class MashumaroSerializer(Serializer):
    native_kind = "dataclass"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._encoder: Any = None
        self._decoder: Any = None

    @property
    def name(self) -> str:
        return "mashumaro"

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._encoder = ORJSONEncoder(test_data_type)
        self._decoder = ORJSONDecoder(test_data_type)

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        # mashumaro codecs operate on the annotated dataclass / scalar directly
        return obj

    def serialize_bytes(self, obj: Any) -> bytes:
        return self._encoder.encode(obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        return self._decoder.decode(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
