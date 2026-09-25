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

from benchmark.data_v2.fidelity import fidelity_v2
from benchmark.data_v2.generator import instances_for_cell
from benchmark.serializers.schema_dagr import DagrSerializer

V2_TYPES = ("message", "document", "telemetry", "strings", "event")


def test_dagr_registered_with_generator_version():
    from benchmark.runner import ALL_SERIALIZERS

    ser = next(s for s in ALL_SERIALIZERS if s.name == "dagr")
    assert re.fullmatch(r"\d{4}\.\d+\.\d+", ser.version), ser.version


@pytest.mark.parametrize("type_id", V2_TYPES)
@pytest.mark.parametrize("n", (1, 3))
def test_dagr_roundtrip(type_id: str, n: int):
    ser = DagrSerializer()
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
