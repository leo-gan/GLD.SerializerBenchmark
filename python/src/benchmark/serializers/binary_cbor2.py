"""
cbor2 benchmark wrapper.

Call-path: prepare_data converts dataclasses to dicts (untimed).
Timed path uses dumps/loads (and native dump/load for stream mode).
"""

from __future__ import annotations

import io
from typing import Any

import cbor2

from .base import Serializer
from ..converters import to_dict


class Cbor2Serializer(Serializer):
    native_kind = "dict"
    stream_mode = "native"

    @property
    def name(self) -> str:
        return "cbor2"

    def supports(self, test_data_name: str) -> bool:
        # Reconstructing cyclic dataclasses from schemaless CBOR is out of scope.
        return test_data_name != "ObjectGraph"

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return cbor2.dumps(obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        return cbor2.loads(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        cbor2.dump(obj, stream)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return cbor2.load(stream)
