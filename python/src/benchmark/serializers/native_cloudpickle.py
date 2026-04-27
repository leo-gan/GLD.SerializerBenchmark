"""
cloudpickle benchmark wrapper.

cloudpickle extends pickle to support closures, lambdas, and dynamic objects.
It is the de facto standard for distributed Python computing (Dask, Ray, etc.).
"""

from __future__ import annotations

import io
from typing import Any

import cloudpickle

from .base import Serializer


class CloudpickleSerializer(Serializer):
    @property
    def name(self) -> str:
        return "cloudpickle"

    def supports(self, test_data_name: str) -> bool:
        return True

    def serialize_bytes(self, obj: Any) -> bytes:
        return cloudpickle.dumps(obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        return cloudpickle.loads(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        cloudpickle.dump(obj, stream)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return cloudpickle.load(stream)
