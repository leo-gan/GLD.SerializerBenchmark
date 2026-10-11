"""Round-trip the array data set through h5py, netCDF4, and adios2."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

_PYTHON_ROOT = Path(__file__).resolve().parents[1]
_REPO = _PYTHON_ROOT.parent
sys.path.insert(0, str(_PYTHON_ROOT / "src"))
sys.path.insert(0, str(_REPO / "analysis" / "src"))

from benchmark.data_v2.fidelity import expected_for_fidelity, fidelity_for
from benchmark.data_v2.generator import make_one
from benchmark_analysis.run_config_v2 import load_catalog, resolve_type_config

from benchmark.serializers.array_scientific import (
    Adios2Serializer,
    H5pySerializer,
    NetCdf4Serializer,
)

_CATALOG = load_catalog(_REPO / "schemas" / "data_catalog_v2.yaml")


def _grid(type_id: str):
    cfg = resolve_type_config(type_id, {}, _CATALOG)
    return make_one(type_id, cfg, seed=42, instance_index=0)


@pytest.mark.parametrize(
    "factory",
    [H5pySerializer, NetCdf4Serializer, Adios2Serializer],
)
@pytest.mark.parametrize("type_id", ["grid", "grid_window"])
def test_array_roundtrip(factory, type_id: str):
    grid = _grid(type_id)
    ser = factory()
    assert ser.supports(type_id)
    assert ser.supports("message") is False
    ser.prepare(type_id, type(grid))
    native = ser.prepare_data(grid, type_id, type(grid))
    blob = ser.serialize_bytes(native)
    assert len(blob) > 2_000_000
    got = ser.deserialize_bytes(blob)
    expected = expected_for_fidelity(type_id, [grid])
    assert fidelity_for(type_id, expected, got) == 1.0
    if type_id == "grid_window":
        assert len(got) == 32768
    else:
        assert len(got) == 262144
