"""
stdlib json baseline.

Call-path: prepare_data → dict (untimed). Timed path is json.dumps/loads only.
"""

from __future__ import annotations

import json
from typing import Any

from .base import Serializer
from ..converters import to_dict


class StdlibJsonSerializer(Serializer):
    native_kind = "dict"
    stream_mode = "adapted"

    @property
    def name(self) -> str:
        return "json"

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

    def deserialize_bytes(self, data: bytes) -> Any:
        return json.loads(data)

