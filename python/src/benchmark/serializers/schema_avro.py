"""Avro (fastavro) — Data Model v2 schemas. Serializer kept; V1 Person schemas removed."""

from __future__ import annotations

import io
import json
import os
from typing import Any, Dict, List, Optional

import fastavro

from .base import Serializer
from ..converters import to_dict

_SCHEMA_DIR = os.path.join(os.path.dirname(__file__), "..", "schemas", "avro")


def _load_schema(name: str) -> Dict[str, Any]:
    path = os.path.join(_SCHEMA_DIR, f"{name}.avsc")
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


_SCHEMAS = {
    "message": _load_schema("message"),
    "document": _load_schema("document"),
    "telemetry": _load_schema("telemetry"),
    "strings": _load_schema("strings"),
    "event": _load_schema("event"),
}
_PARSED = {k: fastavro.parse_schema(v) for k, v in _SCHEMAS.items()}


class AvroSerializer(Serializer):
    package_name = "fastavro"
    native_kind = "dict"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._schema = None
        self._batch = False

    @property
    def name(self) -> str:
        return "avro"

    def supports(self, test_data_name: str) -> bool:
        return test_data_name in _PARSED

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._schema = _PARSED[test_data_name]
        self._name = test_data_name

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        self._batch = isinstance(obj, list)
        if self._batch:
            return [to_dict(x) for x in obj]
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        buf = io.BytesIO()
        if self._batch:
            # array of records: write count + records
            for rec in obj:
                fastavro.schemaless_writer(buf, self._schema, rec)
        else:
            fastavro.schemaless_writer(buf, self._schema, obj)
        return buf.getvalue()

    def deserialize_bytes(self, data: bytes) -> Any:
        bio = io.BytesIO(data)
        if self._batch:
            out: List[Any] = []
            while bio.tell() < len(data):
                out.append(fastavro.schemaless_reader(bio, self._schema))
            return out
        return fastavro.schemaless_reader(bio, self._schema)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
