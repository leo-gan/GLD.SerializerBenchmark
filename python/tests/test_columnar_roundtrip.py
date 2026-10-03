"""Round-trip the columnar codecs and the Python peer allow-list.

``table_project`` must come back as ``f_float_0`` only. Column conversion
for Arrow, Parquet, and ORC stays inside serialize.
"""

from __future__ import annotations

import io
import sys
from pathlib import Path

import pyarrow.orc as pa_orc
import pyarrow.parquet as pa_parquet
import pytest

_PYTHON_ROOT = Path(__file__).resolve().parents[1]
_REPO = _PYTHON_ROOT.parent
sys.path.insert(0, str(_PYTHON_ROOT / "src"))
sys.path.insert(0, str(_REPO / "analysis" / "src"))

from benchmark_analysis.run_config_v2 import load_catalog, resolve_type_config

from benchmark.data_v2 import instances_for_cell
from benchmark.data_v2.fidelity import expected_for_fidelity, fidelity_v2
from benchmark.runner_v2 import serializer_selected
from benchmark.serializers.columnar_arrow import (
    ArrowIpcSerializer,
    OrcSerializer,
    OrcUncompressedSerializer,
    ParquetSerializer,
    ParquetUncompressedSerializer,
)
from benchmark.serializers.json_orjson import OrjsonSerializer
from benchmark.serializers.schema_avro import AvroSerializer
from benchmark.serializers.schema_flatbuffers import FlatBuffersSerializer
from benchmark.serializers.schema_protobuf import ProtobufSerializer

_CATALOG = load_catalog(_REPO / "schemas" / "data_catalog_v2.yaml")
_TYPES = ("table", "table_project", "nested_table", "signal")
_COLUMNAR = (
    ArrowIpcSerializer,
    ParquetSerializer,
    ParquetUncompressedSerializer,
    OrcSerializer,
    OrcUncompressedSerializer,
)
_PEERS = (
    OrjsonSerializer,
    ProtobufSerializer,
    FlatBuffersSerializer,
    AvroSerializer,
)
_ALLOW = "arrow-ipc,parquet,orc,orjson,protobuf,flatbuffers,avro"


def _instances(type_id: str, n: int):
    cfg = resolve_type_config(type_id, {}, _CATALOG)
    return instances_for_cell(type_id, cfg, seed=42, data_type_instance_count=n)


def _roundtrip(ser, type_id: str, n: int):
    instances = _instances(type_id, n)
    payload = instances[0] if n == 1 else list(instances)
    expected = expected_for_fidelity(type_id, instances)
    ser.prepare(type_id, type(instances[0]))
    native = ser.prepare_data(payload, type_id, type(instances[0]))
    data = ser.serialize_bytes(native)
    actual = ser.deserialize_bytes(data)
    return instances, native, data, actual, expected


@pytest.mark.parametrize("factory", _COLUMNAR)
def test_columnar_supports_only_the_new_types(factory):
    ser = factory()
    for type_id in _TYPES:
        assert ser.supports(type_id)
    assert ser.supports("message") is False
    assert ser.supports("document") is False


@pytest.mark.parametrize("factory", _PEERS)
def test_peers_support_the_new_types(factory):
    ser = factory()
    for type_id in _TYPES:
        assert ser.supports(type_id), ser.name


@pytest.mark.parametrize("factory", _COLUMNAR + _PEERS)
@pytest.mark.parametrize("type_id", _TYPES)
@pytest.mark.parametrize("n", (1, 100))
def test_roundtrip_fidelity(factory, type_id, n):
    ser = factory()
    _instances_rows, native, data, actual, expected = _roundtrip(ser, type_id, n)
    assert isinstance(data, (bytes, bytearray))
    assert len(data) > 0
    assert fidelity_v2(expected, actual) == 1.0, ser.name
    if type_id == "table_project":
        assert isinstance(actual, list)
        assert len(actual) == n
        assert all(isinstance(v, float) for v in actual)
        assert not isinstance(actual[0], dict)
    if factory in _COLUMNAR and type_id != "table_project":
        # Domain rows stay domain rows until serialize.
        assert not hasattr(native, "schema")


def test_table_project_full_row_fails_fidelity():
    instances = _instances("table_project", 3)
    expected = expected_for_fidelity("table_project", instances)
    assert fidelity_v2(expected, [row.to_dict() for row in instances]) == 0.0


def test_columnar_prepare_does_not_build_a_table():
    ser = ArrowIpcSerializer()
    instances = _instances("table", 2)
    payload = list(instances)
    ser.prepare("table", type(instances[0]))
    native = ser.prepare_data(payload, "table", type(instances[0]))
    assert native is payload


def test_signal_leg_pad_survives_orc():
    ser = OrcSerializer()
    _, _, _, actual, _ = _roundtrip(ser, "signal", 1)
    assert actual["legs"][0]["leg_pad"] == 0
    assert set(actual) >= {"seq", "ts", "price_mantissa", "qty", "flags", "symbol", "venue", "legs"}


def test_page_compression_labels():
    instances = _instances("table", 4)
    payload = list(instances)

    def written(factory):
        ser = factory()
        ser.prepare("table", type(instances[0]))
        native = ser.prepare_data(payload, "table", type(instances[0]))
        return ser.serialize_bytes(native)

    parquet = pa_parquet.ParquetFile(io.BytesIO(written(ParquetSerializer)))
    plain = pa_parquet.ParquetFile(io.BytesIO(written(ParquetUncompressedSerializer)))
    assert parquet.metadata.row_group(0).column(0).compression == "SNAPPY"
    assert plain.metadata.row_group(0).column(0).compression == "UNCOMPRESSED"

    orc_default = pa_orc.ORCFile(io.BytesIO(written(OrcSerializer)))
    orc_plain = pa_orc.ORCFile(io.BytesIO(written(OrcUncompressedSerializer)))
    assert orc_default.compression == "UNCOMPRESSED"
    assert orc_plain.compression == "UNCOMPRESSED"


def test_arrow_ipc_project_reads_one_column():
    ser = ArrowIpcSerializer()
    instances = _instances("table_project", 5)
    payload = list(instances)
    ser.prepare("table_project", type(instances[0]))
    native = ser.prepare_data(payload, "table_project", type(instances[0]))
    data = ser.serialize_bytes(native)
    table = ser._read(data, ["f_float_0"])
    assert table.schema.names == ["f_float_0"]


def test_adapted_stream_roundtrip():
    ser = ParquetSerializer()
    instances, native, _, _, expected = _roundtrip(ser, "nested_table", 2)
    buf = io.BytesIO()
    ser.serialize_stream(native, buf)
    assert fidelity_v2(expected, ser.deserialize_stream(buf)) == 1.0
    assert instances


def test_columnar_allow_list_does_not_select_the_old_matrix():
    selected = {
        "arrow-ipc",
        "parquet",
        "parquet-uncompressed",
        "orc",
        "orc-uncompressed",
        "orjson",
        "protobuf",
        "flatbuffers",
        "avro",
    }
    for name in selected:
        assert serializer_selected(name, _ALLOW)
    for name in ("json", "yaml", "pickle", "msgspec", "cbor2", "rapidjson"):
        assert serializer_selected(name, _ALLOW) is False
    # A single token still uses substring match.
    assert serializer_selected("parquet-uncompressed", "parquet")
    assert serializer_selected("orjson", "json")
    assert serializer_selected("yaml", None)
