"""
amazon-ion benchmark wrapper.

Call-path: prepare_data converts dataclasses to dicts (untimed).
Timed path uses simpleion binary dumps/loads and dump/load on a stream.
https://github.com/amazon-ion/ion-python
"""

from __future__ import annotations

import io
from typing import Any

from amazon.ion import simpleion

from .base import Serializer
from ..converters import to_dict


class AmazonIonSerializer(Serializer):
    native_kind = "dict"
    stream_mode = "native"
    package_name = "amazon-ion"

    @property
    def name(self) -> str:
        return "amazon-ion"

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return simpleion.dumps(obj, binary=True)

    def deserialize_bytes(self, data: bytes) -> Any:
        return simpleion.loads(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        simpleion.dump(obj, stream, binary=True)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return simpleion.load(stream)
