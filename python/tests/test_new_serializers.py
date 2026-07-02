"""Roundtrip and contract tests for contemporary serializers added in Phase 2."""
from __future__ import annotations

import io
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT))

from benchmark.comparer import compare
from benchmark.data.generator import generate_test_data
from benchmark.data.models import Person, SimpleObject
from benchmark.serializers.json_mashumaro import MashumaroSerializer
from benchmark.serializers.json_pydantic import PydanticSerializer
from benchmark.serializers.json_serpyco import SerpycoSerializer
from benchmark.serializers.json_stdlib import StdlibJsonSerializer
from benchmark.serializers.native_dill import DillSerializer


NEW_SERIALIZERS = [
    StdlibJsonSerializer(),
    PydanticSerializer(),
    MashumaroSerializer(),
    SerpycoSerializer(),
    DillSerializer(),
]


@pytest.mark.parametrize("ser", NEW_SERIALIZERS, ids=lambda s: s.name)
def test_constructible_and_named(ser):
    assert ser.name
    assert ser.native_kind in ("dict", "dataclass", "model", "struct", "message")
    assert ser.stream_mode in ("native", "adapted")


@pytest.mark.parametrize("ser", NEW_SERIALIZERS, ids=lambda s: s.name)
@pytest.mark.parametrize("td_name, td_type", [
    ("Person", Person),
    ("SimpleObject", SimpleObject),
])
def test_roundtrip_person_simple(ser, td_name, td_type):
    if not ser.supports(td_name):
        pytest.skip("unsupported")
    original = generate_test_data(td_name)
    ser.prepare(td_name, td_type)
    native = ser.prepare_data(original, td_name, td_type)
    data = ser.serialize_bytes(native)
    assert isinstance(data, (bytes, bytearray)) and len(data) > 0
    out = ser.deserialize_bytes(data)
    ok, err = compare(original, out)
    assert ok, err

    stream = io.BytesIO()
    ser.serialize_stream(native, stream)
    out2 = ser.deserialize_stream(stream)
    ok, err = compare(original, out2)
    assert ok, err


def test_pydantic_prepare_data_is_basemodel():
    from pydantic import BaseModel

    original = generate_test_data("Person")
    ser = PydanticSerializer()
    ser.prepare("Person", Person)
    native = ser.prepare_data(original, "Person", Person)
    assert isinstance(native, BaseModel)


def test_stdlib_json_prepare_data_is_dict():
    original = generate_test_data("Person")
    ser = StdlibJsonSerializer()
    ser.prepare("Person", Person)
    native = ser.prepare_data(original, "Person", Person)
    assert isinstance(native, dict)


def test_dill_supports_object_graph():
    assert DillSerializer().supports("ObjectGraph") is True
    original = generate_test_data("ObjectGraph")
    ser = DillSerializer()
    from benchmark.data.models import GraphNode
    ser.prepare("ObjectGraph", GraphNode)
    native = ser.prepare_data(original, "ObjectGraph", GraphNode)
    data = ser.serialize_bytes(native)
    out = ser.deserialize_bytes(data)
    ok, err = compare(original, out)
    assert ok, err


def test_serpyco_rejects_object_graph_and_integer():
    ser = SerpycoSerializer()
    assert ser.supports("ObjectGraph") is False
    assert ser.supports("Integer") is False


def test_runner_registry_includes_new_names():
    from benchmark.runner import ALL_SERIALIZERS

    names = {s.name for s in ALL_SERIALIZERS}
    for expected in ("json", "pydantic", "mashumaro", "serpyco-rs", "dill"):
        assert expected in names, f"missing {expected} in registry"
