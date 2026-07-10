"""Pydantic v2 models derived from data_v2 dataclasses."""

from __future__ import annotations

import io
import json
from dataclasses import fields, is_dataclass
from typing import Any, Dict, Type

from pydantic import BaseModel, ConfigDict, create_model

from .base import Serializer
from ..converters import to_dict
from ..data_v2 import models as v2models


class _Cfg(BaseModel):
    model_config = ConfigDict(from_attributes=True)


def _models_from_dataclasses() -> Dict[Type[Any], Type[BaseModel]]:
    out: Dict[Type[Any], Type[BaseModel]] = {}
    for name, cls in vars(v2models).items():
        if not (isinstance(cls, type) and is_dataclass(cls) and cls.__module__ == v2models.__name__):
            continue
        field_defs = {f.name: (f.type, ...) for f in fields(cls)}
        out[cls] = create_model(f"{name}Model", __base__=_Cfg, **field_defs)  # type: ignore[arg-type]
    return out


_MODEL_MAP = _models_from_dataclasses()


class PydanticSerializer(Serializer):
    package_name = "pydantic"
    native_kind = "model"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._model: Type[BaseModel] | None = None

    @property
    def name(self) -> str:
        return "pydantic"

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._model = None if test_data_type is list else _MODEL_MAP.get(test_data_type)

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        if isinstance(obj, list):
            if obj and self._model is None:
                self._model = _MODEL_MAP.get(type(obj[0]))
            if self._model:
                return [self._model.model_validate(to_dict(x)) for x in obj]
            return to_dict(obj)
        if self._model is None:
            self._model = _MODEL_MAP.get(type(obj))
        if self._model is None:
            return to_dict(obj)
        return self._model.model_validate(to_dict(obj))

    def serialize_bytes(self, obj: Any) -> bytes:
        if isinstance(obj, list):
            return json.dumps(
                [x.model_dump() if isinstance(x, BaseModel) else x for x in obj]
            ).encode()
        if isinstance(obj, BaseModel):
            return obj.model_dump_json().encode()
        return json.dumps(obj).encode()

    def deserialize_bytes(self, data: bytes) -> Any:
        raw = json.loads(data)
        if self._model is None:
            return raw
        if isinstance(raw, list):
            return [self._model.model_validate(x) for x in raw]
        return self._model.model_validate(raw)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())
