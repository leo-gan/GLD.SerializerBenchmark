"""Dagr (generated pure-Python typed API) round-trips every v2 type at fidelity 1.0."""
from __future__ import annotations

import io
import re
import sys
from dataclasses import is_dataclass
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from benchmark.data_v2.fidelity import fidelity_graph, fidelity_v2
from benchmark.data_v2.generator import instances_for_cell
from benchmark.serializers.base import Serializer
from benchmark.serializers.native_pickle import PickleSerializer
from benchmark.serializers.schema_dagr import DagrSerializer

V2_TYPES = ("message", "document", "telemetry", "strings", "event")
FLAVOURS = ("dagr-packed", "dagr-regular", "dagr-frozen", "dagr-frozen-packed")


@pytest.mark.parametrize("flavour", FLAVOURS)
def test_dagr_registered_with_generator_version(flavour: str):
    from benchmark.runner import ALL_SERIALIZERS

    names = [s.name for s in ALL_SERIALIZERS]
    assert names.count(flavour) == 1, names
    ser = next(s for s in ALL_SERIALIZERS if s.name == flavour)
    assert re.fullmatch(r"\d{4}\.\d+\.\d+", ser.version), ser.version


def test_dagr_flavours_registered_after_dagr_in_order():
    from benchmark.runner import ALL_SERIALIZERS

    names = [s.name for s in ALL_SERIALIZERS]
    i = names.index("dagr-packed")
    assert tuple(names[i:i + len(FLAVOURS)]) == FLAVOURS


def test_dagr_unknown_flavour_rejected():
    with pytest.raises(ValueError):
        DagrSerializer("dagr-bogus")


@pytest.mark.parametrize("type_id", V2_TYPES)
def test_dagr_flavours_use_distinct_graphs(type_id: str):
    """Each row imports its own layout's module, so the four encodings differ."""
    instances = instances_for_cell(type_id, {}, 42, 1)
    encodings = {}
    for flavour in FLAVOURS:
        ser = DagrSerializer(flavour)
        ser.prepare(type_id, type(instances[0]))
        native = ser.prepare_data(instances[0], type_id, type(instances[0]))
        assert type(native).__module__.startswith(type_id + "_")
        encodings[flavour] = (type(native).__module__, ser.serialize_bytes(native))
    assert len({mod for mod, _ in encodings.values()}) == len(FLAVOURS)


@pytest.mark.parametrize("flavour", FLAVOURS)
@pytest.mark.parametrize("type_id", V2_TYPES)
@pytest.mark.parametrize("n", (1, 3))
def test_dagr_roundtrip(flavour: str, type_id: str, n: int):
    ser = DagrSerializer(flavour)
    assert ser.supports(type_id)
    instances = instances_for_cell(type_id, {}, 42, n)
    payload = instances[0] if n == 1 else instances
    ser.prepare(type_id, type(instances[0]))
    native = ser.prepare_data(payload, type_id, type(instances[0]))
    # prepare_data converts to the generated typed nodes (untimed), not the suite model.
    first = native if n == 1 else native[0]
    assert is_dataclass(first) and hasattr(first, "_dagr_type")

    data = ser.serialize_bytes(native)
    assert isinstance(data, bytes) and data
    assert fidelity_v2(payload, ser.deserialize_bytes(data)) == 1.0

    buf = io.BytesIO()
    ser.serialize_stream(native, buf)
    assert buf.tell() == len(data)
    assert fidelity_v2(payload, ser.deserialize_stream(buf)) == 1.0


@pytest.mark.parametrize("flavour", ("dagr-regular", "dagr-frozen"))
@pytest.mark.parametrize("n", (1, 3))
def test_dagr_graph_roundtrip_preserves_aliases(flavour: str, n: int):
    ser = DagrSerializer(flavour)
    assert ser.supports("graph")
    instances = instances_for_cell("graph", {}, 42, n)
    payload = instances[0] if n == 1 else instances
    ser.prepare("graph", type(instances[0]))
    native = ser.prepare_data(payload, "graph", type(instances[0]))
    data = ser.serialize_bytes(native)
    assert fidelity_graph(payload, ser.deserialize_bytes(data)) == 1.0


@pytest.mark.parametrize("flavour", ("dagr-packed", "dagr-frozen-packed"))
def test_dagr_packed_layouts_skip_graph(flavour: str):
    assert DagrSerializer(flavour).supports("graph") is False


def test_pickle_graph_roundtrip_and_tree_codecs_skip():
    book = instances_for_cell("graph", {}, 7, 1)[0]
    ser = PickleSerializer()
    assert ser.supports("graph")
    blob = ser.serialize_bytes(book)
    assert fidelity_graph(book, ser.deserialize_bytes(blob)) == 1.0

    class _Tree(Serializer):
        @property
        def name(self) -> str:
            return "tree"

        def serialize_bytes(self, obj):
            return b""

        def deserialize_bytes(self, data):
            return None

        def serialize_stream(self, obj, stream):
            return None

        def deserialize_stream(self, stream):
            return None

    assert _Tree().supports("graph") is False
