"""FlatBuffers schema serializer tests."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "generated" / "flatbuffers_gen"))
sys.path.insert(0, str(ROOT))

from benchmark.comparer import compare
from benchmark.data.generator import generate_test_data
from benchmark.data.models import EDI835, Person, SimpleObject, StringArrayObject, TelemetryData
from benchmark.serializers.schema_flatbuffers import FlatBuffersSerializer


@pytest.mark.parametrize("td_name, td_type", [
    ("Person", Person),
    ("SimpleObject", SimpleObject),
    ("StringArray", StringArrayObject),
    ("Telemetry", TelemetryData),
    ("EDI_835", EDI835),
])
def test_flatbuffers_roundtrip(td_name, td_type):
    ser = FlatBuffersSerializer()
    assert ser.supports(td_name)
    original = generate_test_data(td_name)
    ser.prepare(td_name, td_type)
    native = ser.prepare_data(original, td_name, td_type)
    data = ser.serialize_bytes(native)
    assert isinstance(data, (bytes, bytearray)) and len(data) > 0
    out = ser.deserialize_bytes(data)
    ok, err = compare(original, out)
    assert ok, err


def test_flatbuffers_rejects_integer_supports_object_graph():
    ser = FlatBuffersSerializer()
    assert ser.supports("Integer") is False
    assert ser.supports("ObjectGraph") is True


def test_flatbuffers_object_graph_roundtrip():
    from benchmark.data.models import ObjectGraph

    ser = FlatBuffersSerializer()
    original = generate_test_data("ObjectGraph")
    ser.prepare("ObjectGraph", ObjectGraph)
    native = ser.prepare_data(original, "ObjectGraph", ObjectGraph)
    data = ser.serialize_bytes(native)
    out = ser.deserialize_bytes(data)
    ok, err = compare(original, out)
    assert ok, err


def test_flatbuffers_in_runner_registry():
    from benchmark.runner import ALL_SERIALIZERS

    assert any(s.name == "flatbuffers" for s in ALL_SERIALIZERS)
