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
        # cbor2 6.0+ supports circular references via value_sharing=True.
        # However, reconstructing cyclic dataclasses from schemaless CBOR 
        # requires complex custom tag handling that exceeds this benchmark's scope.
        return test_data_name != "ObjectGraph"

    def serialize_bytes(self, obj: Any) -> bytes:
        return cbor2.dumps(obj, default=_encode, value_sharing=True, timezone=datetime.timezone.utc)

    def deserialize_bytes(self, data: bytes) -> Any:
        return cbor2.loads(data, object_hook=_decode_hook)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        # cbor2 has native stream API via dump/load
        cbor2.dump(obj, stream, default=_encode, value_sharing=True, timezone=datetime.timezone.utc)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return cbor2.load(stream, object_hook=_decode_hook)


from dataclasses import fields
from enum import Enum

@cbor2.shareable_encoder
def _encode(encoder: cbor2.CBOREncoder, obj: Any) -> None:
    """
    cbor2 default callback. 
    In 6.0+, it still receives (encoder, obj).
    The @shareable_encoder decorator is required for circular reference support.
    """
    if hasattr(obj, "__dataclass_fields__"):
        # Shallow conversion to dict to let cbor2 handle recursion and cycles.
        # This avoids the recursive to_dict() which would crash on cycles.
        d = {f.name: getattr(obj, f.name) for f in fields(obj)}
        encoder.encode(d)
        return
    if isinstance(obj, datetime.datetime):
        # cbor2 6.0+ requires timezone-aware datetimes for native tagging.
        # The benchmark data is naive, so we attach UTC if missing.
        if obj.tzinfo is None:
            obj = obj.replace(tzinfo=datetime.timezone.utc)
        encoder.encode(obj)
        return
    if isinstance(obj, Enum):
        encoder.encode(obj.name)
        return
    raise TypeError(f"Type {type(obj)} not serializable")


def _decode_hook(decoder: Any, d: Any) -> Any:
    """
    cbor2 6.0+ object_hook signature is (d, immutable).
    
    The purpose of this hook is:
    1. Reconstruct datetime objects from ISO strings (if produced by other components).
    2. Strip timezone information from native CBOR datetimes to match the 
       benchmark's naive datetime data for fidelity comparison.
    """
    if isinstance(d, dict):
        for k, v in d.items():
            if isinstance(v, datetime.datetime) and v.tzinfo is not None:
                d[k] = v.replace(tzinfo=None)
            elif isinstance(v, str) and ("T" in v or "Z" in v):
                for fmt in ("%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S"):
                    try:
                        d[k] = datetime.datetime.strptime(v.split("+")[0].split("Z")[0], fmt)
                    except ValueError:
                        continue
    return d
