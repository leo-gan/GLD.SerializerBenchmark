"""
python-rapidjson benchmark wrapper.

rapidjson is a C++ JSON library binding. It does not natively understand
Python dataclasses or datetime objects, so we provide custom encoder/decoder
hooks and convert via the shared to_dict/from_dict utilities.
"""

from __future__ import annotations

import datetime
import io
from typing import Any

import rapidjson

from .base import Serializer
from ..converters import from_dict, to_dict


class RapidjsonSerializer(Serializer):
    @property
    def name(self) -> str:
        return "rapidjson"

    def supports(self, test_data_name: str) -> bool:
        # rapidjson does not support circular references
        return test_data_name != "ObjectGraph"

    def serialize_bytes(self, obj: Any) -> bytes:
        return rapidjson.dumps(obj, default=_encode, ensure_ascii=False).encode("utf-8")

    def deserialize_bytes(self, data: bytes) -> Any:
        d = rapidjson.loads(data, object_hook=_decode_hook)
        return d

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())


def _encode(obj: Any) -> Any:
    if hasattr(obj, "__dataclass_fields__"):
        return to_dict(obj)
    if isinstance(obj, datetime.datetime):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")


def _decode_hook(d: dict) -> Any:
    # Try to restore datetime strings
    for k, v in d.items():
        if isinstance(v, str) and ("T" in v or "Z" in v):
            for fmt in ("%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S"):
                try:
                    d[k] = datetime.datetime.strptime(v.split("+")[0].split("Z")[0], fmt)
                except ValueError:
                    continue
    return d
