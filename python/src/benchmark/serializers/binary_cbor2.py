"""
cbor2 benchmark wrapper.

cbor2 is a binary serialization format (CBOR — Concise Binary Object Representation).
Custom hooks handle dataclasses and datetime objects.
"""

from __future__ import annotations

import datetime
import io
from typing import Any

import cbor2

from .base import Serializer
from ..converters import to_dict


class Cbor2Serializer(Serializer):
    @property
    def name(self) -> str:
        return "cbor2"

    def supports(self, test_data_name: str) -> bool:
        # cbor2 does not support circular references
        return test_data_name != "ObjectGraph"

    def serialize_bytes(self, obj: Any) -> bytes:
        return cbor2.dumps(obj, default=_encode)

    def deserialize_bytes(self, data: bytes) -> Any:
        return cbor2.loads(data, object_hook=_decode_hook)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        # cbor2 has native stream API via dump/load
        cbor2.dump(obj, stream, default=_encode)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return cbor2.load(stream, object_hook=_decode_hook)


def _encode(encoder: cbor2.CBOREncoder, obj: Any) -> None:
    """cbor2 default callback receives (encoder, value) and mutates the encoder."""
    if hasattr(obj, "__dataclass_fields__"):
        encoder.encode(to_dict(obj))
        return
    if isinstance(obj, datetime.datetime):
        encoder.encode(obj.timestamp())
        return
    raise TypeError(f"Type {type(obj)} not serializable")


def _decode_hook(decoder: cbor2.CBORDecoder, d: dict) -> Any:
    # cbor2 passes (decoder, obj) to object_hook
    if isinstance(d, dict):
        for k, v in d.items():
            if isinstance(v, str) and ("T" in v or "Z" in v):
                for fmt in ("%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S"):
                    try:
                        d[k] = datetime.datetime.strptime(v.split("+")[0].split("Z")[0], fmt)
                    except ValueError:
                        continue
    return d
