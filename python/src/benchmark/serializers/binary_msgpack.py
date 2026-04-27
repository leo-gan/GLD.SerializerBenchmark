"""
msgpack benchmark wrapper.

msgpack is a binary serialization format. We use `use_bin_type=True` and
`strict_map_key=False` for modern Python compatibility. Custom hooks handle
dataclasses and datetime objects.
"""

from __future__ import annotations

import datetime
import io
from typing import Any

import msgpack

from .base import Serializer
from ..converters import from_dict, to_dict


class MsgpackSerializer(Serializer):
    @property
    def name(self) -> str:
        return "msgpack"

    def supports(self, test_data_name: str) -> bool:
        # msgpack does not support circular references by default
        return test_data_name != "ObjectGraph"

    def serialize_bytes(self, obj: Any) -> bytes:
        return msgpack.packb(obj, default=_encode, use_bin_type=True)

    def deserialize_bytes(self, data: bytes) -> Any:
        return msgpack.unpackb(data, object_hook=_decode_hook, strict_map_key=False)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        # msgpack has native stream API via pack/unpack
        msgpack.pack(obj, stream, default=_encode, use_bin_type=True)

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return msgpack.unpack(stream, object_hook=_decode_hook, strict_map_key=False)


def _encode(obj: Any) -> Any:
    if hasattr(obj, "__dataclass_fields__"):
        return to_dict(obj)
    if isinstance(obj, datetime.datetime):
        # Store as tagged timestamp
        return {"__dt__": obj.timestamp()}
    raise TypeError(f"Type {type(obj)} not serializable")


def _decode_hook(d: dict) -> Any:
    if "__dt__" in d and len(d) == 1:
        return datetime.datetime.utcfromtimestamp(d["__dt__"])
    # Attempt datetime string restoration
    for k, v in d.items():
        if isinstance(v, str) and ("T" in v or "Z" in v):
            for fmt in ("%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S"):
                try:
                    d[k] = datetime.datetime.strptime(v.split("+")[0].split("Z")[0], fmt)
                except ValueError:
                    continue
    return d
