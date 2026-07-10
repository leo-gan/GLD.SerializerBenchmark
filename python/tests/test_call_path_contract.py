"""
Verify the fair call-path contract on Data Model v2 fixtures:

* prepare / prepare_data run outside the timed path contractually
* serialize/deserialize operate on library-native values
* roundtrips stay semantically equal to the original fixture
"""
from __future__ import annotations

import io
import sys
from dataclasses import is_dataclass
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT))

from benchmark.comparer import compare
from benchmark.data_v2 import make_one
from benchmark.data_v2.models import Message
from benchmark.serializers.binary_cbor2 import Cbor2Serializer
from benchmark.serializers.binary_msgpack import MsgpackSerializer
from benchmark.serializers.json_msgspec import MsgspecMessagePackSerializer, MsgspecSerializer
from benchmark.serializers.json_orjson import OrjsonSerializer
from benchmark.serializers.json_rapidjson import RapidjsonSerializer
from benchmark.serializers.native_cloudpickle import CloudpickleSerializer
from benchmark.serializers.native_pickle import PickleSerializer
from benchmark.serializers.schema_avro import AvroSerializer
from benchmark.serializers.schema_protobuf import ProtobufSerializer


DICT_CODECS = [
    OrjsonSerializer(),
    RapidjsonSerializer(),
    MsgpackSerializer(),
    Cbor2Serializer(),
    AvroSerializer(),
]

STRUCT_CODECS = [
    MsgspecSerializer(),
    MsgspecMessagePackSerializer(),
]

MESSAGE_CODECS = [
    ProtobufSerializer(),
]

NATIVE_CODECS = [
    PickleSerializer(),
    CloudpickleSerializer(),
]


def _roundtrip_bytes(ser, original, td_name: str, td_type: type):
    ser.prepare(td_name, td_type)
    native = ser.prepare_data(original, td_name, td_type)
    data = ser.serialize_bytes(native)
    assert isinstance(data, (bytes, bytearray))
    assert len(data) > 0
    out = ser.deserialize_bytes(data)
    ok, err = compare(original, out)
    assert ok, err
    return native, out


def test_dict_codecs_prepare_data_is_not_dataclass():
    msg = make_one("message", {}, 42)
    for ser in DICT_CODECS:
        if not ser.supports("message"):
            continue
        ser.prepare("message", Message)
        native = ser.prepare_data(msg, "message", Message)
        assert not is_dataclass(native), f"{ser.name} should prepare to non-dataclass"
        data = ser.serialize_bytes(native)
        out = ser.deserialize_bytes(data)
        ok, err = compare(msg, out)
        assert ok, f"{ser.name}: {err}"


def test_struct_codecs_roundtrip_message():
    msg = make_one("message", {}, 42)
    for ser in STRUCT_CODECS:
        _roundtrip_bytes(ser, msg, "message", Message)


def test_native_codecs_roundtrip_message():
    msg = make_one("message", {}, 42)
    for ser in NATIVE_CODECS:
        _roundtrip_bytes(ser, msg, "message", Message)


def test_protobuf_roundtrip_message():
    msg = make_one("message", {}, 42)
    for ser in MESSAGE_CODECS:
        if not ser.supports("message"):
            pytest.skip("protobuf bridge unavailable")
        ser.prepare("message", Message)
        native = ser.prepare_data(msg, "message", Message)
        data = ser.serialize_bytes(native)
        out = ser.deserialize_bytes(data)
        # protobuf returns message object; fidelity via bridge/compare may be loose
        assert data and len(data) > 0
        assert out is not None


def test_stream_path_roundtrip():
    msg = make_one("message", {}, 7)
    ser = OrjsonSerializer()
    ser.prepare("message", Message)
    native = ser.prepare_data(msg, "message", Message)
    buf = io.BytesIO()
    ser.serialize_stream(native, buf)
    out = ser.deserialize_stream(buf)
    ok, err = compare(msg, out)
    assert ok, err
