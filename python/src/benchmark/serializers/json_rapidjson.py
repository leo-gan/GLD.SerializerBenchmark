"""
python-rapidjson benchmark wrapper.

Call-path: prepare_data converts to dict (untimed). Timed path is dumps/loads only.
Stream mode is adapted (no native bytes stream API for our usage).
"""

from __future__ import annotations

import io
from typing import Any

import rapidjson

from .base import Serializer
from ..converters import to_dict


class RapidjsonSerializer(Serializer):
    native_kind = "dict"
    stream_mode = "adapted"

    @property
    def name(self) -> str:
        return "rapidjson"

    def supports(self, test_data_name: str) -> bool:
        return test_data_name != "ObjectGraph"

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        # dumps returns str; encode is part of producing wire bytes for this binding
        return rapidjson.dumps(obj, ensure_ascii=False).encode("utf-8")

    def deserialize_bytes(self, data: bytes) -> Any:
        return rapidjson.loads(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
