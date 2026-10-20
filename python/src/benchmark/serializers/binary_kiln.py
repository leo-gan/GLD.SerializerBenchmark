"""gld-kiln benchmark wrapper.

prepare_data converts dataclasses to dicts (untimed).
The timed path is Writer.encode / decode on a positional schema.
A batch is one list of that struct.
"""

from __future__ import annotations

import struct
from typing import Any

from kiln import Writer, decode, encode

from ..converters import to_dict
from .base import Serializer

_BOOL = ("bool",)
_I32 = ("i32",)
_I64 = ("i64",)
_F64 = ("f64",)
_STR = ("str",)

_MESSAGE = (
    "struct",
    [
        ("f_bool", _BOOL),
        ("f_int32", _I32),
        ("f_int64", _I64),
        ("f_float64", _F64),
        ("f_string", _STR),
        ("f_bool_2", _BOOL),
        ("f_int32_2", _I32),
        ("f_string_2", _STR),
    ],
)
_DOCUMENT = (
    "struct",
    [
        ("id", _STR),
        ("status", _I32),
        ("meta", ("struct", [("region", _STR), ("version", _I32)])),
        (
            "items",
            ("list", ("struct", [("sku", _STR), ("qty", _I32), ("price_minor", _I64)])),
        ),
    ],
)
_TELEMETRY = (
    "struct",
    [
        ("source", _STR),
        ("ts", _I64),
        ("tags", ("list", _STR)),
        ("values", ("list", _F64)),
    ],
)
_STRINGS = ("struct", [("items", ("list", _STR))])
_EVENT = (
    "struct",
    [
        ("event_id", _STR),
        ("event_type", _STR),
        ("occurred_at", _I64),
        ("producer", _STR),
        ("attrs", ("list", ("struct", [("key", _STR), ("value", _STR)]))),
    ],
)
# Same field order as Mojo TensorValue, PromptValue, ShardValue, RequestValue.
_TENSOR = (
    "struct",
    [
        ("rows", _I32),
        ("cols", _I32),
        ("values", ("list", ("f32",))),
    ],
)
_PROMPT = (
    "struct",
    [
        ("batch", _I32),
        ("seq", _I32),
        ("input_ids", ("list", _I64)),
        ("attention_mask", ("list", _I64)),
        ("position_ids", ("list", _I64)),
    ],
)
_SHARD = (
    "struct",
    [
        ("vocab", _I32),
        ("hidden", _I32),
        ("ffn", _I32),
        ("tok_emb", ("list", ("f32",))),
        ("attn", ("list", ("f32",))),
        ("ffn_weight", ("list", ("f32",))),
        ("norm", ("list", ("f32",))),
    ],
)
_REQUEST = (
    "struct",
    [
        ("request_id", _I64),
        ("model", _STR),
        ("temperature", ("f32",)),
        ("inputs", _PROMPT),
    ],
)
_SCHEMAS = {
    "message": _MESSAGE,
    "document": _DOCUMENT,
    "telemetry": _TELEMETRY,
    "strings": _STRINGS,
    "event": _EVENT,
    "tensor": _TENSOR,
    "tensor_view": _TENSOR,
    "prompt": _PROMPT,
    "shard": _SHARD,
    "request": _REQUEST,
}


class KilnSerializer(Serializer):
    """Positional Kiln wire for the five suite types."""

    native_kind = "dict"
    stream_mode = "adapted"
    package_name = "gld-kiln"

    def __init__(self) -> None:
        self._writer = Writer()
        self._schema: tuple | None = None
        self._borrow = False

    @property
    def name(self) -> str:
        return "gld-kiln"

    def supports(self, test_data_name: str) -> bool:
        return test_data_name in _SCHEMAS

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        base = _SCHEMAS[test_data_name]
        origin = getattr(test_data_type, "__origin__", None)
        self._borrow = test_data_name == "tensor_view"
        self._schema = ("list", base) if origin is list else base

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        return to_dict(obj)

    def serialize_bytes(self, obj: Any) -> bytes:
        if self._schema is None:
            raise RuntimeError("gld-kiln prepare was not called")
        return bytes(self._writer.encode(self._schema, obj))

    def deserialize_bytes(self, data: bytes) -> Any:
        if self._schema is None:
            raise RuntimeError("gld-kiln prepare was not called")
        if self._borrow:
            return _borrow_matrix(data)
        return decode(self._schema, data)


def _borrow_matrix(data: bytes) -> dict[str, Any]:
    """tensor_view: rows, cols, and a float32 view of the payload bytes."""
    view = memoryview(data)
    rows, cols, count = struct.unpack_from("<iiI", view, 0)
    start = 12
    end = start + count * 4
    if end != len(view):
        raise ValueError("gld-kiln tensor_view length")
    return {"rows": rows, "cols": cols, "values": view[start:end].cast("f")}
