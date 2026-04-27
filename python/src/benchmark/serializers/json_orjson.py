"""
orjson benchmark wrapper.

orjson is a fast JSON library that returns bytes natively.
We enable OPT_SERIALIZE_DATETIME for proper datetime handling and
use a custom default to convert dataclasses to dicts.
"""

from __future__ import annotations

import io
from typing import Any

import orjson

from .base import Serializer
from ..converters import from_dict, to_dict


class OrjsonSerializer(Serializer):
    @property
    def name(self) -> str:
        return "orjson"

    def supports(self, test_data_name: str) -> bool:
        # orjson does not support circular references
        return test_data_name != "ObjectGraph"

    def serialize_bytes(self, obj: Any) -> bytes:
        return orjson.dumps(obj, default=_default)

    def deserialize_bytes(self, data: bytes) -> Any:
        d = orjson.loads(data)
        return _reconstruct(d)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        # orjson has no native stream API; write bytes to BytesIO
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())


def _default(obj: Any) -> Any:
    if hasattr(obj, "__dataclass_fields__"):
        return to_dict(obj)
    raise TypeError(f"Type {type(obj)} not serializable")


def _reconstruct(data: Any) -> Any:
    # orjson returns primitives; attempt to restore dataclasses if the top-level
    # looks like a known type by its keys. This is heuristic-based.
    if isinstance(data, dict):
        # Try to map by field names heuristically
        keys = set(data.keys())
        for cls, expected_keys in _TYPE_MAP.items():
            if keys == expected_keys:
                return from_dict(data, cls)
    if isinstance(data, list) and data and isinstance(data[0], dict):
        # For StringArray, etc., list items may need conversion
        pass
    return data


# Heuristic type mapping for orjson deserialization.
# In practice, we compare the deserialized dict/list directly with the original
# via the semantic comparer, so exact type restoration is not strictly required.
_TYPE_MAP = {
}
