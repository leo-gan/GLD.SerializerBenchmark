"""gld-kiln benchmark wrapper.

prepare_data converts dataclasses to dicts and numeric lists to array.array
(untimed). The timed path writes and reads the positional wire directly.
Numeric lists are one little-endian copy. tensor_view borrows the payload.
A batch is one list of that struct.
"""

from __future__ import annotations

import array
import struct
import sys
from typing import Any

from ..converters import to_dict
from .base import Serializer

_CAP = 16_777_216
_LE = sys.byteorder == "little"
_POD = {"f32": ("f", 4), "f64": ("d", 8), "i64": ("q", 8), "i32": ("i", 4)}

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


def _fail(kind: str) -> None:
    raise ValueError(f"gld-kiln: {kind}")


def _pack(schema: tuple, value: Any) -> Any:
    """Turn numeric lists into array.array once, outside the timer."""
    kind = schema[0]
    if kind == "list":
        elem = schema[1]
        code = _POD.get(elem[0])
        if code is not None:
            typecode = code[0]
            if isinstance(value, array.array) and value.typecode == typecode:
                return value
            return array.array(typecode, value)
        return [_pack(elem, item) for item in value]
    if kind == "struct":
        return {name: _pack(field, value[name]) for name, field in schema[1]}
    return value


def _pod_block(value: Any, typecode: str) -> array.array:
    if isinstance(value, array.array) and value.typecode == typecode:
        return value
    return array.array(typecode, value)


def _wire_size(schema: tuple, value: Any) -> int:
    kind = schema[0]
    if kind == "bool":
        return 1
    if kind in ("i32", "f32"):
        return 4
    if kind in ("i64", "f64"):
        return 8
    if kind == "str":
        return 4 + len(value.encode("utf-8"))
    if kind == "list":
        elem = schema[1]
        pod = _POD.get(elem[0])
        if pod is not None:
            return 4 + len(value) * pod[1]
        return 4 + sum(_wire_size(elem, item) for item in value)
    if kind == "struct":
        return sum(_wire_size(field, value[name]) for name, field in schema[1])
    _fail("TYPE")
    raise AssertionError


class _Out:
    """One exact-sized buffer. Numeric payloads are copied once into it."""

    __slots__ = ("buf", "i")

    def __init__(self, size: int) -> None:
        self.buf = bytearray(size)
        self.i = 0

    def _put(self, fmt: str, value: Any, width: int) -> None:
        struct.pack_into(fmt, self.buf, self.i, value)
        self.i += width

    def u8(self, value: int) -> None:
        self.buf[self.i] = value & 0xFF
        self.i += 1

    def u32(self, value: int) -> None:
        self._put("<I", value, 4)

    def i32(self, value: int) -> None:
        self._put("<i", value, 4)

    def i64(self, value: int) -> None:
        self._put("<q", value, 8)

    def f32(self, value: float) -> None:
        self._put("<f", float(value), 4)

    def f64(self, value: float) -> None:
        self._put("<d", float(value), 8)

    def raw(self, data: bytes | memoryview) -> None:
        end = self.i + len(data)
        memoryview(self.buf)[self.i : end] = data
        self.i = end

    def string(self, value: str) -> None:
        raw = value.encode("utf-8")
        if len(raw) > _CAP:
            _fail("LIMIT")
        self.u32(len(raw))
        if raw:
            self.raw(raw)

    def pods(self, value: Any, typecode: str, width: int) -> None:
        if not _LE:
            _fail("numeric copy requires a little-endian host")
        block = _pod_block(value, typecode)
        if len(block) > _CAP or block.itemsize != width:
            _fail("LIMIT" if len(block) > _CAP else "TYPE")
        self.u32(len(block))
        if block:
            self.raw(memoryview(block).cast("B"))


def _write(out: _Out, schema: tuple, value: Any) -> None:
    kind = schema[0]
    if kind == "bool":
        out.u8(1 if value else 0)
        return
    if kind == "i32":
        out.i32(int(value))
        return
    if kind == "i64":
        out.i64(int(value))
        return
    if kind == "f32":
        out.f32(value)
        return
    if kind == "f64":
        out.f64(value)
        return
    if kind == "str":
        out.string(value)
        return
    if kind == "list":
        elem = schema[1]
        pod = _POD.get(elem[0])
        if pod is not None:
            out.pods(value, pod[0], pod[1])
            return
        if len(value) > _CAP:
            _fail("LIMIT")
        out.u32(len(value))
        for item in value:
            _write(out, elem, item)
        return
    if kind == "struct":
        for name, field in schema[1]:
            _write(out, field, value[name])
        return
    _fail("TYPE")


class _In:
    __slots__ = ("buf", "i", "n")

    def __init__(self, data: bytes | bytearray | memoryview) -> None:
        self.buf = data if isinstance(data, memoryview) else memoryview(data)
        self.i = 0
        self.n = len(self.buf)

    def need(self, size: int) -> None:
        if size < 0 or self.i + size > self.n:
            _fail("EOF")

    def u8(self) -> int:
        self.need(1)
        value = self.buf[self.i]
        self.i += 1
        return value

    def u32(self) -> int:
        self.need(4)
        value = struct.unpack_from("<I", self.buf, self.i)[0]
        self.i += 4
        return value

    def count(self, width: int) -> int:
        count = self.u32()
        if count > _CAP:
            _fail("LIMIT")
        if width and count > (self.n - self.i) // width:
            _fail("EOF")
        return count

    def boolean(self) -> bool:
        value = self.u8()
        if value > 1:
            _fail("TYPE")
        return value == 1

    def i32(self) -> int:
        self.need(4)
        value = struct.unpack_from("<i", self.buf, self.i)[0]
        self.i += 4
        return value

    def i64(self) -> int:
        self.need(8)
        value = struct.unpack_from("<q", self.buf, self.i)[0]
        self.i += 8
        return value

    def f32(self) -> float:
        self.need(4)
        value = struct.unpack_from("<f", self.buf, self.i)[0]
        self.i += 4
        return value

    def f64(self) -> float:
        self.need(8)
        value = struct.unpack_from("<d", self.buf, self.i)[0]
        self.i += 8
        return value

    def string(self) -> str:
        length = self.count(1)
        self.need(length)
        raw = self.buf[self.i : self.i + length]
        self.i += length
        try:
            return str(raw, "utf-8")
        except UnicodeDecodeError as exc:
            raise ValueError("gld-kiln: UTF8") from exc

    def pods(self, typecode: str, width: int) -> array.array:
        if not _LE:
            _fail("numeric copy requires a little-endian host")
        count = self.count(width)
        nbytes = count * width
        self.need(nbytes)
        block = array.array(typecode)
        block.frombytes(self.buf[self.i : self.i + nbytes])
        self.i += nbytes
        return block

    def finish(self) -> None:
        if self.i != self.n:
            _fail("TRAILING")


def _read(src: _In, schema: tuple) -> Any:
    kind = schema[0]
    if kind == "bool":
        return src.boolean()
    if kind == "i32":
        return src.i32()
    if kind == "i64":
        return src.i64()
    if kind == "f32":
        return src.f32()
    if kind == "f64":
        return src.f64()
    if kind == "str":
        return src.string()
    if kind == "list":
        elem = schema[1]
        pod = _POD.get(elem[0])
        if pod is not None:
            return src.pods(pod[0], pod[1])
        count = src.count(1)
        return [_read(src, elem) for _ in range(count)]
    if kind == "struct":
        return {name: _read(src, field) for name, field in schema[1]}
    _fail("TYPE")
    raise AssertionError


class KilnSerializer(Serializer):
    """Positional Kiln wire for the suite and tensor types."""

    native_kind = "dict"
    stream_mode = "adapted"
    package_name = "gld-kiln"

    def __init__(self) -> None:
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
        if self._schema is None:
            raise RuntimeError("gld-kiln prepare was not called")
        return _pack(self._schema, to_dict(obj))

    def serialize_bytes(self, obj: Any) -> bytearray:
        if self._schema is None:
            raise RuntimeError("gld-kiln prepare was not called")
        out = _Out(_wire_size(self._schema, obj))
        _write(out, self._schema, obj)
        if out.i != len(out.buf):
            _fail("FRAME")
        return out.buf

    def deserialize_bytes(self, data: bytes) -> Any:
        if self._schema is None:
            raise RuntimeError("gld-kiln prepare was not called")
        if self._borrow:
            return _borrow_matrix(data)
        src = _In(data)
        value = _read(src, self._schema)
        src.finish()
        return value


def _borrow_matrix(data: bytes) -> dict[str, Any]:
    """tensor_view: rows, cols, and a float32 view of the payload bytes."""
    view = memoryview(data)
    rows, cols, count = struct.unpack_from("<iiI", view, 0)
    start = 12
    end = start + count * 4
    if end != len(view) or count > _CAP:
        raise ValueError("gld-kiln tensor_view length")
    return {"rows": rows, "cols": cols, "values": view[start:end].cast("f")}
