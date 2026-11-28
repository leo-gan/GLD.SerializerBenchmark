"""gld-kiln-asm 0.2.0 benchmark wrapper via thin CPython C-API extension.

Covers all four Data Sets:
  - suite:    message, document, telemetry, strings, event (single + batch)
  - columnar: table (TableColumns), table_project (KILN_OPT_EMBEDDED O(1) skip),
              nested_table, signal (single + batch; row->column transpose timed)
  - array:    grid, grid_window (KLNT v2 float64 [ny, nx] with strided window copy)
  - tensor:   tensor, tensor_view (zero-copy memoryview borrow of wire bytes),
              prompt, shard, request (KLNT v2)
"""

from __future__ import annotations

import array
from typing import Any

from ..converters import to_dict
from .base import Serializer

_SUITE = frozenset({"message", "document", "telemetry", "strings", "event"})
_COLUMNAR = frozenset({"table", "table_project", "nested_table", "signal"})
_ARRAY = frozenset({"grid", "grid_window"})
_TENSOR = frozenset({"tensor", "tensor_view", "prompt", "shard", "request"})
_SUPPORTED = _SUITE | _COLUMNAR | _ARRAY | _TENSOR


def _load_ext():
    from . import _kiln_asm_ext  # type: ignore[import-not-found]

    return _kiln_asm_ext


def _pack_array(values: Any, typecode: str) -> array.array:
    if isinstance(values, array.array) and values.typecode == typecode:
        return values
    return array.array(typecode, values)


def _prepare_suite_item(type_id: str, d: dict[str, Any]) -> dict[str, Any]:
    if type_id == "telemetry":
        return {
            "source": d["source"],
            "ts": d["ts"],
            "tags": d["tags"],
            "values": _pack_array(d["values"], "d"),
        }
    return d


class KilnAsmSerializer(Serializer):
    """Pure x86-64 Assembly Kiln Wire Format v2 codec via CPython C extension."""

    native_kind = "dict"
    stream_mode = "adapted"
    package_name = "gld-kiln-asm"

    def __init__(self) -> None:
        super().__init__()
        self._type_id: str = "message"
        self._batch: bool = False
        self._window: tuple[int, int, int, int] = (0, 0, 0, 0)
        self._ext: Any = None

    @property
    def name(self) -> str:
        return "gld-kiln-asm"

    @property
    def version(self) -> str:
        try:
            ext = self._ensure_ext()
            return str(ext.version())
        except Exception:
            return "0.2.0"

    def _ensure_ext(self) -> Any:
        if self._ext is None:
            self._ext = _load_ext()
        return self._ext

    def supports(self, test_data_name: str) -> bool:
        return test_data_name in _SUPPORTED

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._ensure_ext()
        self._type_id = test_data_name
        origin = getattr(test_data_type, "__origin__", None)
        self._batch = origin is list

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        self._ensure_ext()
        self._type_id = test_data_name
        self._batch = isinstance(obj, list)

        if test_data_name in _COLUMNAR:
            # Keep domain rows; row-to-column conversion stays inside serialize_bytes.
            return obj

        if test_data_name in _ARRAY:
            self._window = (obj.x0, obj.y0, obj.wx, obj.wy)
            return (obj.nx, obj.ny, _pack_array(obj.values, "d"))

        if test_data_name in ("tensor", "tensor_view"):
            return {
                "rows": obj.rows,
                "cols": obj.cols,
                "values": _pack_array(obj.values, "f"),
            }

        if test_data_name == "prompt":
            return {
                "batch": obj.batch,
                "seq": obj.seq,
                "input_ids": _pack_array(obj.input_ids, "q"),
                "attention_mask": _pack_array(obj.attention_mask, "q"),
                "position_ids": _pack_array(obj.position_ids, "q"),
            }

        if test_data_name == "shard":
            return {
                "vocab": obj.vocab,
                "hidden": obj.hidden,
                "ffn": obj.ffn,
                "tok_emb": _pack_array(obj.tok_emb, "f"),
                "attn": _pack_array(obj.attn, "f"),
                "ffn_weight": _pack_array(obj.ffn_weight, "f"),
                "norm": _pack_array(obj.norm, "f"),
            }

        if test_data_name == "request":
            p = obj.inputs
            return {
                "request_id": obj.request_id,
                "model": obj.model,
                "temperature": obj.temperature,
                "inputs": {
                    "batch": p.batch,
                    "seq": p.seq,
                    "input_ids": _pack_array(p.input_ids, "q"),
                    "attention_mask": _pack_array(p.attention_mask, "q"),
                    "position_ids": _pack_array(p.position_ids, "q"),
                },
            }

        # Suite types: convert dataclasses to dicts (and pack telemetry.values) once outside timing.
        raw = to_dict(obj)
        if self._batch:
            return [_prepare_suite_item(test_data_name, item) for item in raw]
        return _prepare_suite_item(test_data_name, raw)

    def serialize_bytes(self, obj: Any) -> bytes:
        ext = self._ensure_ext()
        tid = self._type_id
        batch = self._batch

        if tid == "message":
            return ext.encode_message(obj, batch)
        if tid == "document":
            return ext.encode_document(obj, batch)
        if tid == "telemetry":
            return ext.encode_telemetry(obj, batch)
        if tid == "strings":
            return ext.encode_strings(obj, batch)
        if tid == "event":
            return ext.encode_event(obj, batch)
        if tid in ("table", "table_project"):
            return ext.encode_table(obj, batch)
        if tid == "nested_table":
            return ext.encode_nested_table(obj, batch)
        if tid == "signal":
            return ext.encode_signal(obj, batch)
        if tid in ("grid", "grid_window"):
            nx, ny, vals = obj
            return ext.encode_grid(nx, ny, vals)
        if tid in ("tensor", "tensor_view"):
            return ext.encode_tensor(obj)
        if tid == "prompt":
            return ext.encode_prompt(obj)
        if tid == "shard":
            return ext.encode_shard(obj)
        if tid == "request":
            return ext.encode_request(obj)
        raise TypeError(f"Unsupported type_id for gld-kiln-asm: {tid!r}")

    def deserialize_bytes(self, data: bytes) -> Any:
        ext = self._ensure_ext()
        tid = self._type_id
        batch = self._batch

        if tid == "message":
            return ext.decode_message(data, batch)
        if tid == "document":
            return ext.decode_document(data, batch)
        if tid == "telemetry":
            return ext.decode_telemetry(data, batch)
        if tid == "strings":
            return ext.decode_strings(data, batch)
        if tid == "event":
            return ext.decode_event(data, batch)
        if tid == "table":
            return ext.decode_table(data, batch)
        if tid == "table_project":
            return ext.decode_table_project(data)
        if tid == "nested_table":
            return ext.decode_nested_table(data, batch)
        if tid == "signal":
            return ext.decode_signal(data, batch)
        if tid == "grid":
            return ext.decode_grid(data)
        if tid == "grid_window":
            x0, y0, wx, wy = self._window
            return ext.decode_grid_window(data, x0, y0, wx, wy)
        if tid == "tensor":
            return ext.decode_tensor(data)
        if tid == "tensor_view":
            return ext.decode_tensor_view(data)
        if tid == "prompt":
            return ext.decode_prompt(data)
        if tid == "shard":
            return ext.decode_shard(data)
        if tid == "request":
            return ext.decode_request(data)
        raise TypeError(f"Unsupported type_id for gld-kiln-asm: {tid!r}")
