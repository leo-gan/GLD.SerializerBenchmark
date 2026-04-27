"""
pickle benchmark wrapper.

Python's native `pickle` is the baseline for Python-native serialization.
It handles dataclasses, enums, datetime, and even circular references natively.
"""

from __future__ import annotations

import io
import pickle
from typing import Any

from .base import Serializer


class PickleSerializer(Serializer):
    @property
    def name(self) -> str:
        return "pickle"

    def supports(self, test_data_name: str) -> bool:
        # pickle handles everything including circular references
        return True

    def serialize_bytes(self, obj: Any) -> bytes:
        return pickle.dumps(obj, protocol=pickle.HIGHEST_PROTOCOL)

    def deserialize_bytes(self, data: bytes) -> Any:
        return pickle.loads(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        pickle.dump(obj, stream, protocol=pickle.HIGHEST_PROTOCOL)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return pickle.load(stream)
