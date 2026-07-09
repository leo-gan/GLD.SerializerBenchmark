"""
ObjectGraph suite tests: flat node table + integer edges.

Portable cycle encoding used by C/Rust/JS/Python. Every capable serializer
must support ObjectGraph; live pointer cycles are intentionally not used.
"""
from __future__ import annotations

import io
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "generated" / "flatbuffers_gen"))
sys.path.insert(0, str(ROOT))

from benchmark.comparer import compare
from benchmark.data.generator import generate_object_graph, generate_test_data
from benchmark.data.models import GRAPH_NULL, GraphNodeData, ObjectGraph
from benchmark.runner import ALL_SERIALIZERS


def test_object_graph_topology():
    g = generate_object_graph()
    assert g.root == 0
    assert len(g.nodes) == 3
    root, c1, c2 = g.nodes
    assert root.Name == "Root"
    assert root.Parent == GRAPH_NULL
    assert root.Related == GRAPH_NULL
    assert root.Children == [1, 2]
    assert c1.Name == "Child1" and c1.Parent == 0 and c1.Related == 2
    assert c2.Name == "Child2" and c2.Parent == 0 and c2.Related == 1
    # Sibling cycle via indices (not live pointers)
    assert g.nodes[c1.Related].Name == "Child2"
    assert g.nodes[c2.Related].Name == "Child1"


def test_generate_test_data_object_graph():
    g = generate_test_data("ObjectGraph")
    assert isinstance(g, ObjectGraph)
    assert all(isinstance(n, GraphNodeData) for n in g.nodes)


@pytest.mark.parametrize("ser", ALL_SERIALIZERS, ids=lambda s: s.name)
def test_all_serializers_support_object_graph(ser):
    assert ser.supports("ObjectGraph") is True


@pytest.mark.parametrize("ser", ALL_SERIALIZERS, ids=lambda s: s.name)
def test_object_graph_roundtrip_bytes(ser):
    original = generate_test_data("ObjectGraph")
    ser.prepare("ObjectGraph", ObjectGraph)
    native = ser.prepare_data(original, "ObjectGraph", ObjectGraph)
    data = ser.serialize_bytes(native)
    assert isinstance(data, (bytes, bytearray)) and len(data) > 0
    out = ser.deserialize_bytes(data)
    ok, err = compare(original, out)
    assert ok, f"{ser.name}: {err}"


@pytest.mark.parametrize("ser", ALL_SERIALIZERS, ids=lambda s: s.name)
def test_object_graph_roundtrip_stream(ser):
    original = generate_test_data("ObjectGraph")
    ser.prepare("ObjectGraph", ObjectGraph)
    native = ser.prepare_data(original, "ObjectGraph", ObjectGraph)
    stream = io.BytesIO()
    ser.serialize_stream(native, stream)
    assert stream.tell() > 0
    out = ser.deserialize_stream(stream)
    ok, err = compare(original, out)
    assert ok, f"{ser.name}: {err}"


def test_object_graph_dict_codec_prepare_is_dict():
    from benchmark.serializers.json_orjson import OrjsonSerializer
    from benchmark.serializers.binary_msgpack import MsgpackSerializer

    original = generate_test_data("ObjectGraph")
    for ser in (OrjsonSerializer(), MsgpackSerializer()):
        ser.prepare("ObjectGraph", ObjectGraph)
        native = ser.prepare_data(original, "ObjectGraph", ObjectGraph)
        assert isinstance(native, dict)
        assert "root" in native and "nodes" in native
        assert native["nodes"][1]["Related"] == 2


def test_object_graph_protobuf_prepare_is_message():
    from benchmark.serializers.schema_protobuf import ProtobufSerializer

    original = generate_test_data("ObjectGraph")
    ser = ProtobufSerializer()
    ser.prepare("ObjectGraph", ObjectGraph)
    native = ser.prepare_data(original, "ObjectGraph", ObjectGraph)
    assert hasattr(native, "SerializeToString")
    assert native.root == 0
    assert len(native.nodes) == 3
    assert list(native.nodes[0].Children) == [1, 2]


def test_object_graph_msgspec_prepare_is_struct():
    import msgspec
    from benchmark.serializers.json_msgspec import MsgspecSerializer

    original = generate_test_data("ObjectGraph")
    ser = MsgspecSerializer()
    ser.prepare("ObjectGraph", ObjectGraph)
    native = ser.prepare_data(original, "ObjectGraph", ObjectGraph)
    assert isinstance(native, msgspec.Struct)
