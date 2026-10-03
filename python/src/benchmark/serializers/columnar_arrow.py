"""Arrow IPC, Parquet, and ORC on the columnar suite types.

Schema objects are built once. Turning suite rows into columns happens inside
serialize, which is the timed path. ``table_project`` deserialize returns
``f_float_0`` only.
"""

from __future__ import annotations

import io
from typing import Any

import pyarrow as pa
import pyarrow.ipc as pa_ipc
import pyarrow.orc as pa_orc
import pyarrow.parquet as pa_parquet

from .base import Serializer

_FLOATS = [pa.field(f"f_float_{i}", pa.float64()) for i in range(16)]
_INTS = [pa.field(f"f_int_{i}", pa.int64()) for i in range(4)]
_STRINGS = [pa.field("f_str_0", pa.string()), pa.field("f_str_1", pa.string())]

TABLE_SCHEMA = pa.schema(_FLOATS + _INTS + _STRINGS)

_NESTED_META = pa.struct([("region", pa.string()), ("version", pa.int32())])
_NESTED_ITEM = pa.struct(
    [("sku", pa.string()), ("qty", pa.int32()), ("price_minor", pa.int64())]
)
NESTED_SCHEMA = pa.schema(
    [
        ("id", pa.string()),
        ("status", pa.int32()),
        ("meta", _NESTED_META),
        ("items", pa.list_(_NESTED_ITEM)),
    ]
)

_SIGNAL_LEG = pa.struct(
    [("leg_id", pa.int64()), ("leg_qty", pa.int32()), ("leg_pad", pa.int32())]
)
SIGNAL_SCHEMA = pa.schema(
    [
        ("seq", pa.int64()),
        ("ts", pa.int64()),
        ("price_mantissa", pa.int64()),
        ("qty", pa.int32()),
        ("flags", pa.int32()),
        ("symbol", pa.string()),
        ("venue", pa.string()),
        ("legs", pa.list_(_SIGNAL_LEG)),
    ]
)

_SCHEMAS = {
    "table": TABLE_SCHEMA,
    "table_project": TABLE_SCHEMA,
    "nested_table": NESTED_SCHEMA,
    "signal": SIGNAL_SCHEMA,
}

_TYPE_IDS = frozenset(_SCHEMAS)


def _as_dict(row: Any) -> dict[str, Any]:
    if isinstance(row, dict):
        return row
    to_dict = getattr(row, "to_dict", None)
    if callable(to_dict):
        return to_dict()
    raise TypeError(f"columnar row must be a dict or dataclass, got {type(row)!r}")


class _ColumnarSerializer(Serializer):
    """Shared row→column conversion. Subclasses own the byte format."""

    package_name = "pyarrow"
    native_kind = "table"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._type_id = "table"
        self._schema = TABLE_SCHEMA
        self._batch = False

    def supports(self, test_data_name: str) -> bool:
        return test_data_name in _TYPE_IDS

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._type_id = test_data_name
        self._schema = _SCHEMAS[test_data_name]

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        # Keep domain rows. Column conversion is serialize work.
        self._type_id = test_data_name
        self._schema = _SCHEMAS[test_data_name]
        self._batch = isinstance(obj, list)
        return obj

    def _table(self, obj: Any) -> pa.Table:
        rows = obj if isinstance(obj, list) else [obj]
        return pa.Table.from_pylist([_as_dict(row) for row in rows], schema=self._schema)

    def _materialize(self, table: pa.Table) -> Any:
        if self._type_id == "table_project":
            # One column, including N=1. Do not to_pylist the other 21 columns.
            return table.column("f_float_0").to_pylist()
        rows = table.to_pylist()
        if not self._batch:
            return rows[0]
        return rows

    def _write(self, table: pa.Table) -> bytes:
        raise NotImplementedError

    def _read(self, data: bytes, columns: list[str] | None) -> pa.Table:
        raise NotImplementedError

    def serialize_bytes(self, obj: Any) -> bytes:
        # Row-to-column conversion is on the clock. Each call writes one
        # complete IPC stream or file; these writers have no reset that
        # keeps a previous file's footer valid for the next payload.
        return self._write(self._table(obj))

    def deserialize_bytes(self, data: bytes) -> Any:
        columns = ["f_float_0"] if self._type_id == "table_project" else None
        return self._materialize(self._read(data, columns))

    def serialize_stream(self, obj: Any, stream: io.BytesIO) -> None:
        stream.write(self.serialize_bytes(obj))

    def deserialize_stream(self, stream: io.BytesIO) -> Any:
        stream.seek(0)
        return self.deserialize_bytes(stream.read())


class ArrowIpcSerializer(_ColumnarSerializer):
    @property
    def name(self) -> str:
        return "arrow-ipc"

    def _write(self, table: pa.Table) -> bytes:
        sink = pa.BufferOutputStream()
        with pa_ipc.new_stream(sink, table.schema) as writer:
            writer.write_table(table)
        return sink.getvalue().to_pybytes()

    def _read(self, data: bytes, columns: list[str] | None) -> pa.Table:
        options = None
        if columns:
            options = pa_ipc.IpcReadOptions(
                included_fields=[self._schema.get_field_index(name) for name in columns]
            )
        reader = pa_ipc.open_stream(pa.py_buffer(data), options=options)
        return reader.read_all()


class ParquetSerializer(_ColumnarSerializer):
    """Library-default Parquet write (Snappy page compression)."""

    @property
    def name(self) -> str:
        return "parquet"

    def _write(self, table: pa.Table) -> bytes:
        sink = pa.BufferOutputStream()
        pa_parquet.write_table(table, sink)
        return sink.getvalue().to_pybytes()

    def _read(self, data: bytes, columns: list[str] | None) -> pa.Table:
        return pa_parquet.read_table(pa.BufferReader(data), columns=columns)


class ParquetUncompressedSerializer(ParquetSerializer):
    """Same writer with page compression turned off. Encodings stay at the default."""

    @property
    def name(self) -> str:
        return "parquet-uncompressed"

    def _write(self, table: pa.Table) -> bytes:
        sink = pa.BufferOutputStream()
        pa_parquet.write_table(table, sink, compression="NONE")
        return sink.getvalue().to_pybytes()


class OrcSerializer(_ColumnarSerializer):
    """pyarrow ORC write with no compression argument.

    ``pyarrow.orc.write_table`` defaults to uncompressed. Apache ORC's own
    C++ and Java writers default to Zlib. This row follows pyarrow.
    """

    @property
    def name(self) -> str:
        return "orc"

    def _write(self, table: pa.Table) -> bytes:
        sink = pa.BufferOutputStream()
        pa_orc.write_table(table, sink)
        return sink.getvalue().to_pybytes()

    def _read(self, data: bytes, columns: list[str] | None) -> pa.Table:
        return pa_orc.read_table(pa.BufferReader(data), columns=columns)


class OrcUncompressedSerializer(OrcSerializer):
    """Same writer with compression set to uncompressed.

    On current pyarrow that codec is also the default, so the bytes match
    ``orc``. The name stays for languages whose ORC default is Zlib.
    """

    @property
    def name(self) -> str:
        return "orc-uncompressed"

    def _write(self, table: pa.Table) -> bytes:
        sink = pa.BufferOutputStream()
        pa_orc.write_table(table, sink, compression="uncompressed")
        return sink.getvalue().to_pybytes()
