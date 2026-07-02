"""
dill benchmark wrapper — extended pickle used heavily in scientific Python.
"""

from __future__ import annotations

import io
from typing import Any

import dill

from .base import Serializer


class DillSerializer(Serializer):
    native_kind = "dataclass"
    stream_mode = "native"

    @property
    def name(self) -> str:
        return "dill"

    def supports(self, test_data_name: str) -> bool:
        return True

    def serialize_bytes(self, obj: Any) -> bytes:
        return dill.dumps(obj, protocol=dill.HIGHEST_PROTOCOL)

    def deserialize_bytes(self, data: bytes) -> Any:
        return dill.loads(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        dill.dump(obj, stream, protocol=dill.HIGHEST_PROTOCOL)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return dill.load(stream)
