"""PyYAML — the usual Python YAML library (already a suite dependency).

Call-path: prepare_data → dict (untimed). Timed path is yaml.safe_dump / safe_load.
Stream uses the same dump/load on a file-like object (text-on-stream).
https://pyyaml.org/
"""

from __future__ import annotations

import io
from typing import Any

import yaml

from .base import Serializer
from ..converters import to_dict


class PyYamlSerializer(Serializer):
    native_kind = "dict"
    stream_mode = "text_on_stream"
    package_name = "PyYAML"

    @property
    def name(self) -> str:
        return "yaml"

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return yaml.safe_dump(
            obj,
            allow_unicode=True,
            default_flow_style=False,
            sort_keys=False,
        ).encode("utf-8")

    def deserialize_bytes(self, data: bytes) -> Any:
        return yaml.safe_load(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        text = io.TextIOWrapper(stream, encoding="utf-8", write_through=True)
        yaml.safe_dump(
            obj,
            text,
            allow_unicode=True,
            default_flow_style=False,
            sort_keys=False,
        )
        text.detach()

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return yaml.safe_load(stream)
