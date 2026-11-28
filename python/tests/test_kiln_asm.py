"""Unit, roundtrip, zero-copy view, and compliance tests for Python gld-kiln-asm."""

from __future__ import annotations

import io
import sys
from pathlib import Path

import pytest

_PYTHON_ROOT = Path(__file__).resolve().parents[1]
_REPO = _PYTHON_ROOT.parent
sys.path.insert(0, str(_PYTHON_ROOT / "src"))
sys.path.insert(0, str(_REPO / "analysis" / "src"))

from benchmark.data_v2 import instances_for_cell
from benchmark.data_v2.fidelity import expected_for_fidelity, fidelity_for
from benchmark.serializers.binary_kiln_asm import KilnAsmSerializer
from benchmark.serializers.tensor_payload import _payload_ptr, _span
from benchmark_analysis.run_config_v2 import load_catalog, resolve_type_config

_CATALOG = load_catalog(_REPO / "schemas" / "data_catalog_v2.yaml")

_ALL_TYPES = [
    ("message", 1),
    ("message", 10),
    ("document", 1),
    ("document", 5),
    ("telemetry", 1),
    ("telemetry", 5),
    ("strings", 1),
    ("strings", 5),
    ("event", 1),
    ("event", 5),
    ("table", 1),
    ("table", 50),
    ("table_project", 1),
    ("table_project", 50),
    ("nested_table", 1),
    ("nested_table", 20),
    ("signal", 1),
    ("signal", 20),
    ("grid", 1),
    ("grid_window", 1),
    ("tensor", 1),
    ("tensor_view", 1),
    ("prompt", 1),
    ("shard", 1),
    ("request", 1),
]


@pytest.mark.parametrize("type_id,n", _ALL_TYPES)
def test_kiln_asm_roundtrip_all_datasets(type_id: str, n: int):
    overrides = {}
    if type_id in ("tensor", "tensor_view"):
        overrides = {"rows": 16, "cols": 16}
    elif type_id == "prompt":
        overrides = {"batch": 2, "seq": 8, "vocab": 64}
    elif type_id == "shard":
        overrides = {"vocab": 16, "hidden": 8, "ffn": 12}
    elif type_id == "request":
        overrides = {"batch": 2, "seq": 8, "vocab": 64}
    elif type_id == "grid":
        overrides = {"nx": 32, "ny": 32}
    elif type_id == "grid_window":
        overrides = {"nx": 32, "ny": 32, "window": {"x0": 4, "y0": 6, "wx": 12, "wy": 10}}

    cfg = resolve_type_config(type_id, overrides, _CATALOG)
    instances = instances_for_cell(type_id, cfg, seed=42, data_type_instance_count=n)
    payload = instances[0] if n == 1 else list(instances)
    expected = expected_for_fidelity(type_id, instances)

    ser = KilnAsmSerializer()
    assert ser.supports(type_id)
    assert ser.version == "0.2.0"

    td_type = type(instances[0]) if n == 1 else list[type(instances[0])]
    ser.prepare(type_id, td_type)
    native = ser.prepare_data(payload, type_id, td_type)
    wire = ser.serialize_bytes(native)
    assert isinstance(wire, bytes) and len(wire) > 0

    decoded = ser.deserialize_bytes(wire)
    assert fidelity_for(type_id, expected, decoded) == 1.0

    if type_id == "table_project":
        assert isinstance(decoded, list)
        assert len(decoded) == n
        assert all(isinstance(v, float) for v in decoded)
    elif type_id == "tensor_view":
        mv = decoded["values"]
        assert isinstance(mv, memoryview)
        ptr, owns = _payload_ptr(mv)
        assert owns is False
        start, size = _span(wire)
        assert start <= ptr < start + size

    # Adapted stream path round-trip
    buf = io.BytesIO()
    ser.serialize_stream(native, buf)
    decoded_stream = ser.deserialize_stream(buf)
    assert fidelity_for(type_id, expected, decoded_stream) == 1.0


def test_kiln_asm_compliance_v2():
    from compliance.runner import run_suites

    scored = run_suites(formats=["kiln"], adapter_names=["gld-kiln-asm"])
    assert scored.catalog_errors == []
    assert scored.passed == 46
    assert scored.failed == 0
    assert scored.errors == 0
