"""
msgspec benchmark wrappers.

The shared benchmark fixtures are stdlib dataclasses. For the msgspec entries we
convert those fixtures to array-like msgspec.Struct models before timing,
matching the documented high-performance usage pattern instead of measuring
dataclass support.

The dataclass-to-Struct conversion is intentionally outside the timed loop. This
models an application written with msgspec's recommended Struct types, while
still letting the shared benchmark generator own the canonical input data.
Struct types are generated from the canonical dataclasses in benchmark.data.models
with msgspec.defstruct to keep the benchmark schema in sync with the shared models.
Using array-like Structs also matches schema-oriented serializers in this suite
that rely on field order/IDs rather than repeating field names in each payload.
For example, protobuf writes numbered field tags and the Avro wrapper uses
schemaless encoding with a shared schema.
"""

from __future__ import annotations

import io
from dataclasses import fields, is_dataclass
from types import UnionType
from typing import Any, Union, get_args, get_origin, get_type_hints

import msgspec

from .base import Serializer
from ..data import models


_UNSUPPORTED_STRUCT_TYPES: set[type[Any]] = {models.GraphNode}
_STRUCT_TYPES: dict[type[Any], type[msgspec.Struct]] = {}


def _model_dataclasses() -> set[type[Any]]:
    return {
        value
        for value in vars(models).values()
        if isinstance(value, type)
        and is_dataclass(value)
        and value.__module__ == models.__name__
        and value not in _UNSUPPORTED_STRUCT_TYPES
    }


def _dataclass_dependencies(typ: Any, candidates: set[type[Any]]) -> set[type[Any]]:
    if typ in candidates:
        return {typ}

    deps: set[type[Any]] = set()
    for arg in get_args(typ):
        deps.update(_dataclass_dependencies(arg, candidates))
    return deps


def _ordered_model_dataclasses(candidates: set[type[Any]]) -> list[type[Any]]:
    ordered: list[type[Any]] = []
    visiting: set[type[Any]] = set()
    visited: set[type[Any]] = set()

    def visit(cls: type[Any]) -> None:
        if cls in visited:
            return
        if cls in visiting:
            raise TypeError(f"Recursive dataclass model is not supported for msgspec Struct generation: {cls!r}")

        visiting.add(cls)
        hints = get_type_hints(cls)
        for field in fields(cls):
            for dependency in _dataclass_dependencies(hints[field.name], candidates):
                if dependency is not cls:
                    visit(dependency)
        visiting.remove(cls)
        visited.add(cls)
        ordered.append(cls)

    for cls in sorted(candidates, key=lambda c: c.__name__):
        visit(cls)

    return ordered


def _translate_type(typ: Any) -> Any:
    """Translate dataclass annotations to their generated Struct equivalents."""
    if typ in _STRUCT_TYPES:
        return _STRUCT_TYPES[typ]

    origin = get_origin(typ)
    args = get_args(typ)

    if origin is list:
        return list[_translate_type(args[0])]

    if origin in (Union, UnionType):
        return Union[tuple(_translate_type(arg) for arg in args)]

    if is_dataclass(typ):
        raise TypeError(
            f"No generated msgspec Struct for dataclass type {typ!r}; "
            "ensure it is defined in benchmark.data.models and not excluded"
        )

    return typ


def _build_struct_types() -> None:
    for cls in _ordered_model_dataclasses(_model_dataclasses()):
        hints = get_type_hints(cls)
        struct_fields = [
            (field.name, _translate_type(hints[field.name]))
            for field in fields(cls)
        ]
        _STRUCT_TYPES[cls] = msgspec.defstruct(
            f"Msgspec{cls.__name__}",
            struct_fields,
            module=__name__,
            array_like=True,
        )


_build_struct_types()


class _MsgspecStructSerializer(Serializer):
    codec_name = "msgspec"

    def __init__(self) -> None:
        super().__init__()
        self._encoder = self._make_encoder()
        self._decoders: dict[Any, Any] = {}
        self._decoder = self._decoder_for(Any)
        self._buffer = bytearray()

    @property
    def name(self) -> str:
        return self.codec_name

    def supports(self, test_data_name: str) -> bool:
        return test_data_name != "ObjectGraph"

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        self._decoder = self._decoder_for(_msgspec_type_for(test_data_type))
        self._buffer = bytearray()

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return _to_msgspec_struct(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        return self._encoder.encode(obj)

    def deserialize_bytes(self, data: bytes) -> Any:
        return self._decoder.decode(data)

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        self._encoder.encode_into(obj, self._buffer)
        view = memoryview(self._buffer)
        try:
            stream.write(view)
        finally:
            view.release()

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        view = stream.getbuffer()
        try:
            data = view[:stream.tell()]
            try:
                return self._decoder.decode(data)
            finally:
                data.release()
        finally:
            view.release()

    def _make_encoder(self) -> Any:
        raise NotImplementedError

    def _make_decoder(self, typ: Any) -> Any:
        raise NotImplementedError

    def _decoder_for(self, typ: Any) -> Any:
        decoder = self._decoders.get(typ)
        if decoder is None:
            decoder = self._make_decoder(typ)
            self._decoders[typ] = decoder
        return decoder


class MsgspecSerializer(_MsgspecStructSerializer):
    codec_name = "msgspec"

    def _make_encoder(self) -> msgspec.json.Encoder:
        return msgspec.json.Encoder()

    def _make_decoder(self, typ: Any) -> msgspec.json.Decoder:
        return msgspec.json.Decoder(type=typ)


class MsgspecMessagePackSerializer(_MsgspecStructSerializer):
    codec_name = "msgspec-msgpack"

    def _make_encoder(self) -> msgspec.msgpack.Encoder:
        return msgspec.msgpack.Encoder()

    def _make_decoder(self, typ: Any) -> msgspec.msgpack.Decoder:
        return msgspec.msgpack.Decoder(type=typ)


def _msgspec_type_for(typ: type) -> Any:
    return _STRUCT_TYPES.get(typ, typ)


def _to_msgspec_struct(obj: Any) -> Any:
    if isinstance(obj, list):
        return [_to_msgspec_struct(item) for item in obj]

    if is_dataclass(obj) and not isinstance(obj, type):
        typ = _msgspec_type_for(type(obj))
        if typ is type(obj):
            raise TypeError(f"Unsupported type for msgspec Struct conversion: {type(obj)}")
        return typ(*(
            _to_msgspec_struct(getattr(obj, field.name))
            for field in fields(obj)
        ))

    return obj
