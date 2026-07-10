"""Protobuf — Data Model v2 messages (schemas/v2). Serializer kept; V1 Person mapping removed."""

from __future__ import annotations

import io
from typing import Any

from .base import Serializer
from ..data_v2 import protobuf_bridge


class ProtobufSerializer(Serializer):
    package_name = "protobuf"
    native_kind = "message"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._msg_cls = None

    @property
    def name(self) -> str:
        return "protobuf"

    def supports(self, test_data_name: str) -> bool:
        return test_data_name in {
            "message", "document", "telemetry", "strings", "event",
        } and protobuf_bridge.available()

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._msg_cls = protobuf_bridge.message_class_for(test_data_name, batch=False)

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        batch = isinstance(obj, list)
        self._msg_cls = protobuf_bridge.message_class_for(test_data_name, batch=batch)
        if self._msg_cls is None:
            raise TypeError(f"no protobuf mapping for {test_data_name}")
        return protobuf_bridge.to_pb(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return obj.SerializeToString()

    def deserialize_bytes(self, data: bytes) -> Any:
        if self._msg_cls is None:
            raise RuntimeError("prepare required")
        msg = self._msg_cls()
        msg.ParseFromString(data)
        return msg

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
