"""
msgspec benchmark wrapper.

msgspec natively supports dataclasses, enums, and datetime objects
since v0.18, making it one of the most "Python-native" JSON serializers.
"""

from __future__ import annotations

import io
from typing import Any

import msgspec

from .base import Serializer


class MsgspecSerializer(Serializer):
    @property
    def name(self) -> str:
        return "msgspec"

    def supports(self, test_data_name: str) -> bool:
        # msgspec does not support circular references in JSON mode
        return test_data_name != "ObjectGraph"

    def serialize_bytes(self, obj: Any) -> bytes:
        return msgspec.json.encode(obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        return msgspec.json.decode(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        # msgspec has no native stream API; write bytes to BytesIO
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
