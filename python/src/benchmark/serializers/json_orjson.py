"""
orjson benchmark wrapper.

Call-path: prepare_data converts dataclasses to JSON-friendly dicts (untimed).
Timed path only runs orjson.dumps / orjson.loads on native dict/list/scalars.

orjson's documented high-performance path is dumps/loads on plain dicts (Rust
core). OPT_SERIALIZE_DATACLASS is slower for our fixtures once conversion is
untimed, so we keep the dict path.
"""

from __future__ import annotations

import io
from typing import Any

import orjson

from .base import Serializer
from ..converters import to_dict


class OrjsonSerializer(Serializer):
    native_kind = "dict"
    stream_mode = "adapted"

    @property
    def name(self) -> str:
        return "orjson"

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        # Flat document (index edges) serializes as a plain dict like other fixtures.
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        # obj is already a JSON-friendly dict/list/scalar from prepare_data
        return orjson.dumps(obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        return orjson.loads(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
