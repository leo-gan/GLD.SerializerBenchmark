"""Pydantic v2 — explicit models for data_v2 types (nested-safe)."""

from __future__ import annotations

import io
import json
from typing import Any, Dict, List, Type

from pydantic import BaseModel, ConfigDict, TypeAdapter

from .base import Serializer
from ..converters import to_dict
from ..data_v2.models import Document, Event, Message, Strings, Telemetry


class _Cfg(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class MessageModel(_Cfg):
    f_bool: bool
    f_int32: int
    f_int64: int
    f_float64: float
    f_string: str
    f_bool_2: bool
    f_int32_2: int
    f_string_2: str


class DocumentMetaModel(_Cfg):
    region: str
    version: int


class DocumentItemModel(_Cfg):
    sku: str
    qty: int
    price_minor: int


class DocumentModel(_Cfg):
    id: str
    status: int
    meta: DocumentMetaModel
    items: List[DocumentItemModel]


class TelemetryModel(_Cfg):
    source: str
    ts: int
    tags: List[str]
    values: List[float]


class StringsModel(_Cfg):
    items: List[str]


class EventAttrModel(_Cfg):
    key: str
    value: str


class EventModel(_Cfg):
    event_id: str
    event_type: str
    occurred_at: int
    producer: str
    attrs: List[EventAttrModel]


_MODEL_MAP: Dict[type, Type[BaseModel]] = {
    Message: MessageModel,
    Document: DocumentModel,
    Telemetry: TelemetryModel,
    Strings: StringsModel,
    Event: EventModel,
}


class PydanticSerializer(Serializer):
    package_name = "pydantic"
    native_kind = "model"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._model: Type[BaseModel] | None = None
        self._list_adapter: TypeAdapter | None = None

    @property
    def name(self) -> str:
        return "pydantic"

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._model = None if test_data_type is list else _MODEL_MAP.get(test_data_type)
        self._list_adapter = None

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        if isinstance(obj, list):
            if obj and self._model is None:
                self._model = _MODEL_MAP.get(type(obj[0]))
            if self._model:
                self._list_adapter = TypeAdapter(list[self._model])
                return [self._model.model_validate(to_dict(x)) for x in obj]
            return to_dict(obj)
        if self._model is None:
            self._model = _MODEL_MAP.get(type(obj))
        if self._model is None:
            return to_dict(obj)
        return self._model.model_validate(to_dict(obj))

    def serialize_bytes(self, obj: Any) -> bytes:
        if isinstance(obj, list):
            if self._list_adapter is not None:
                return self._list_adapter.dump_json(obj)
            return json.dumps(obj).encode()
        if isinstance(obj, BaseModel):
            return obj.model_dump_json().encode()
        return json.dumps(obj).encode()

    def deserialize_bytes(self, data: bytes) -> Any:
        if self._list_adapter is not None:
            return self._list_adapter.validate_json(data)
        if self._model is None:
            return json.loads(data)
        return self._model.model_validate_json(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
