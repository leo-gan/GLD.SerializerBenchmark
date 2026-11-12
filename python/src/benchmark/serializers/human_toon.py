"""TOON text codecs.

TOON is a UTF-8 encoding of the JSON data model. The timed path is encode
and decode of that text. The Size column is the UTF-8 byte length. A token
count is a different measure and is not timed here.

https://github.com/toon-format/toon-python
https://github.com/alesanfra/toons
"""

from __future__ import annotations

import io
from typing import Any

import toons
from toon_format import decode, encode

from .base import Serializer
from ..converters import to_dict


class _ToonTextSerializer(Serializer):
    native_kind = "dict"
    stream_mode = "adapted"

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return self._encode(obj).encode("utf-8")

    def deserialize_bytes(self, data: bytes) -> Any:
        return self._decode(data.decode("utf-8"))

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())

    def _encode(self, obj: Any) -> str:
        raise NotImplementedError

    def _decode(self, text: str) -> Any:
        raise NotImplementedError


class ToonFormatSerializer(_ToonTextSerializer):
    """Official Python TOON codec. encode/decode are the reference names."""

    package_name = "toon-format"

    @property
    def name(self) -> str:
        return "toon-format"

    def _encode(self, obj: Any) -> str:
        return encode(obj)

    def _decode(self, text: str) -> Any:
        return decode(text)


class ToonsSerializer(_ToonTextSerializer):
    """Python TOON codec with a Rust core. loads/dumps follow the json module."""

    package_name = "toons"

    @property
    def name(self) -> str:
        return "toons"

    def _encode(self, obj: Any) -> str:
        return toons.dumps(obj)

    def _decode(self, text: str) -> Any:
        return toons.loads(text)


class CtoonSerializer(_ToonTextSerializer):
    """C-backed Python binding of ctoon. dumps and loads are the text API."""

    package_name = "ctoon"

    @property
    def name(self) -> str:
        return "ctoon"

    def _encode(self, obj: Any) -> str:
        import ctoon

        return ctoon.dumps(obj)

    def _decode(self, text: str) -> Any:
        import ctoon

        return ctoon.loads(text)
