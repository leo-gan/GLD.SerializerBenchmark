"""Round-trip the tensor data set through the Python allow-list."""

from __future__ import annotations

import struct
import sys
from pathlib import Path

import pytest

_PYTHON_ROOT = Path(__file__).resolve().parents[1]
_REPO = _PYTHON_ROOT.parent
sys.path.insert(0, str(_PYTHON_ROOT / "src"))
sys.path.insert(0, str(_REPO / "analysis" / "src"))

from benchmark.data_v2.fidelity import fidelity_for
from benchmark.data_v2.generator import make_one
from benchmark.serializers.array_scientific import H5pySerializer
from benchmark.serializers.columnar_arrow import ArrowIpcSerializer
from benchmark.serializers.schema_flatbuffers import FlatBuffersSerializer
from benchmark.serializers.schema_protobuf import ProtobufSerializer
from benchmark_analysis.run_config_v2 import load_catalog, resolve_type_config

_CATALOG = load_catalog(_REPO / "schemas" / "data_catalog_v2.yaml")
_SMALL = {
    "tensor": {"rows": 4, "cols": 4},
    "tensor_view": {"rows": 4, "cols": 4},
    "prompt": {"batch": 2, "seq": 4, "vocab": 32},
    "shard": {"vocab": 4, "hidden": 3, "ffn": 5},
    "request": {"batch": 2, "seq": 4, "vocab": 32, "string_len": {"min": 4, "max": 6}},
}


def _one(type_id: str):
    cfg = resolve_type_config(type_id, _SMALL[type_id], _CATALOG)
    return make_one(type_id, cfg, seed=42, instance_index=0)


def _roundtrip(factory, type_id: str) -> None:
    obj = _one(type_id)
    ser = factory()
    assert ser.supports(type_id)
    ser.prepare(type_id, type(obj))
    native = ser.prepare_data(obj, type_id, type(obj))
    blob = ser.serialize_bytes(native)
    assert isinstance(blob, (bytes, bytearray)) and len(blob) > 0
    got = ser.deserialize_bytes(blob)
    assert fidelity_for(type_id, obj, got) == 1.0


@pytest.mark.parametrize("factory", [ArrowIpcSerializer, FlatBuffersSerializer])
@pytest.mark.parametrize("type_id", ["tensor", "tensor_view", "prompt", "shard", "request"])
def test_arrow_and_flatbuffers_roundtrip(factory, type_id: str):
    _roundtrip(factory, type_id)


def test_flatbuffers_request_and_view_borrows():
    _roundtrip(FlatBuffersSerializer, "request")
    obj = _one("tensor_view")
    ser = FlatBuffersSerializer()
    ser.prepare("tensor_view", type(obj))
    blob = ser.serialize_bytes(ser.prepare_data(obj, "tensor_view", type(obj)))
    got = ser.deserialize_bytes(blob)
    assert fidelity_for("tensor_view", obj, got) == 1.0


def test_partial_codecs_are_not_on_the_tensor_set():
    for type_id in ("tensor", "tensor_view", "prompt", "shard", "request"):
        assert H5pySerializer().supports(type_id) is False
        assert ProtobufSerializer().supports(type_id) is False
        assert ArrowIpcSerializer().supports(type_id) is True
        assert FlatBuffersSerializer().supports(type_id) is True


def test_tensor_view_matches_tensor_and_pins_specials():
    cfg = resolve_type_config("tensor", {}, _CATALOG)
    matrix = make_one("tensor", cfg, seed=7, instance_index=0)
    view = make_one("tensor_view", cfg, seed=7, instance_index=0)
    def bits(values: list[float]) -> list[int]:
        return [struct.unpack("<I", struct.pack("<f", v))[0] for v in values]

    assert bits(matrix.values) == bits(view.values)
    assert len(matrix.values) == 1024 * 1024
    assert bits(matrix.values)[0] == 0x80000000
    assert bits(matrix.values)[1] == 0x7FC00000


def test_prompt_shape_and_padding():
    prompt = _one("prompt")
    assert len(prompt.input_ids) == 8
    assert prompt.position_ids == [0, 1, 2, 3, 0, 1, 2, 3]
    assert set(prompt.attention_mask) <= {0, 1}
    for token, mask in zip(prompt.input_ids, prompt.attention_mask):
        if mask == 1:
            assert 1 <= token <= 31
        else:
            assert token == 0
