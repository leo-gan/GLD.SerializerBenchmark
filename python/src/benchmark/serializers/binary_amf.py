"""
Py3AMF benchmark wrapper.

Call-path: prepare_data converts dataclasses to dicts (untimed).
Timed path uses pyamf.encode / pyamf.decode. AMF0 stores every number as a
double. AMF3 can store a small integer more tightly. Neither path is a stream
codec, so stream mode copies the encoded buffer.
"""

from __future__ import annotations

import io
from typing import Any

import pyamf

from .base import Serializer
from ..converters import to_dict


class _PyAmfSerializer(Serializer):
    native_kind = "dict"
    stream_mode = "adapted"
    package_name = "Py3AMF"
    encoding = pyamf.AMF0

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return pyamf.encode(obj, encoding=self.encoding).getvalue()

    def deserialize_bytes(self, data: bytes) -> Any:
        return next(pyamf.decode(data, encoding=self.encoding))

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())


class PyAmf0Serializer(_PyAmfSerializer):
    encoding = pyamf.AMF0

    @property
    def name(self) -> str:
        return "py3amf-amf0"


class PyAmf3Serializer(_PyAmfSerializer):
    encoding = pyamf.AMF3

    @property
    def name(self) -> str:
        return "py3amf-amf3"
