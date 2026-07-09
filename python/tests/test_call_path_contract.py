"""
Verify the fair call-path contract:

* prepare / prepare_data run outside the timed path contractually
* serialize/deserialize operate on library-native values (no live dataclasses
  for dict/message codecs after prepare_data)
* roundtrips stay semantically equal to the original fixture

These tests assert *structure* of the API (what types enter the timed path),
not absolute performance numbers.
"""
from __future__ import annotations

import inspect
import io
import sys
from dataclasses import is_dataclass
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT))

from benchmark.comparer import compare
from benchmark.data.generator import generate_test_data
from benchmark.data.models import Person, SimpleObject
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
    person = generate_test_data("Person")
    for ser in DICT_CODECS:
        if not ser.supports("Person"):
            continue
        ser.prepare("Person", Person)
        native = ser.prepare_data(person, "Person", Person)
        assert not is_dataclass(native) or isinstance(native, type), (
            f"{ser.name}: prepare_data must not leave a dataclass for dict codecs, got {type(native)}"
        )
        assert isinstance(native, dict), f"{ser.name}: expected dict native, got {type(native)}"


def test_struct_codecs_prepare_data_is_msgspec_struct():
    import msgspec

    person = generate_test_data("Person")
    for ser in STRUCT_CODECS:
        ser.prepare("Person", Person)
        native = ser.prepare_data(person, "Person", Person)
        assert isinstance(native, msgspec.Struct), f"{ser.name}: expected Struct, got {type(native)}"


def test_message_codecs_prepare_data_is_protobuf_message():
    person = generate_test_data("Person")
    for ser in MESSAGE_CODECS:
        ser.prepare("Person", Person)
        native = ser.prepare_data(person, "Person", Person)
        assert hasattr(native, "SerializeToString"), f"{ser.name}: expected Message"
        assert hasattr(native, "DESCRIPTOR")


def test_native_codecs_prepare_data_identity():
    person = generate_test_data("Person")
    for ser in NATIVE_CODECS:
        ser.prepare("Person", Person)
        native = ser.prepare_data(person, "Person", Person)
        assert native is person


@pytest.mark.parametrize(
    "ser",
    DICT_CODECS + STRUCT_CODECS + MESSAGE_CODECS + NATIVE_CODECS,
    ids=lambda s: s.name,
)
def test_person_roundtrip_bytes_and_stream(ser):
    if not ser.supports("Person"):
        pytest.skip("unsupported")
    original = generate_test_data("Person")
    _roundtrip_bytes(ser, original, "Person", Person)

    ser.prepare("Person", Person)
    native = ser.prepare_data(original, "Person", Person)
    stream = io.BytesIO()
    ser.serialize_stream(native, stream)
    assert stream.tell() > 0
    out = ser.deserialize_stream(stream)
    ok, err = compare(original, out)
    assert ok, err


@pytest.mark.parametrize("td_name, td_type", [
    ("SimpleObject", SimpleObject),
    ("Integer", int),
])
def test_orjson_and_msgpack_on_simple_payloads(td_name, td_type):
    original = generate_test_data(td_name)
    for ser in (OrjsonSerializer(), MsgpackSerializer(), Cbor2Serializer()):
        if not ser.supports(td_name):
            continue
        _roundtrip_bytes(ser, original, td_name, td_type)


def test_serialize_bytes_source_has_no_to_dict_call_for_dict_codecs():
    """Sanity on implementation: timed methods should not call converters.to_dict."""
    from benchmark.serializers import json_orjson, binary_msgpack, json_rapidjson, binary_cbor2

    for mod in (json_orjson, binary_msgpack, json_rapidjson, binary_cbor2):
        src = inspect.getsource(mod)
        # prepare_data may reference to_dict; serialize_bytes must not
        ser_src = inspect.getsource(mod.__dict__[
            [n for n in dir(mod) if n.endswith("Serializer") and not n.startswith("_")][0]
        ].serialize_bytes)
        assert "to_dict" not in ser_src, f"{mod.__name__}.serialize_bytes still uses to_dict"
        assert "_to_protobuf" not in ser_src
        assert "_to_avro" not in ser_src


def test_protobuf_serialize_source_is_codec_only():
    src = inspect.getsource(ProtobufSerializer.serialize_bytes)
    assert "SerializeToString" in src
    assert "_to_protobuf" not in src
    deser = inspect.getsource(ProtobufSerializer.deserialize_bytes)
    assert "ParseFromString" in deser
    assert "_from_protobuf" not in deser


def test_avro_serialize_source_is_codec_only():
    src = inspect.getsource(AvroSerializer.serialize_bytes)
    assert "schemaless_writer" in src
    assert "_to_avro" not in src


def test_stream_mode_metadata_declared():
    assert OrjsonSerializer.stream_mode == "adapted"
    assert MsgpackSerializer.stream_mode == "native"
    assert PickleSerializer.stream_mode == "native"
    assert ProtobufSerializer.stream_mode == "adapted"
    assert MsgspecSerializer.native_kind == "struct"
    assert OrjsonSerializer.native_kind == "dict"


def test_msgpack_uses_reused_packer_not_packb():
    """Documented optimal path: Packer.pack reuses encoder state (~25% faster than packb)."""
    src = inspect.getsource(MsgpackSerializer.serialize_bytes)
    assert "packb" not in src
    assert "pack" in src
    ser = MsgpackSerializer()
    assert hasattr(ser, "_packer")
