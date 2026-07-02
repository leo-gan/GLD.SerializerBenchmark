"""Regression: cbor2 stream path on StringArray (and similar string-heavy payloads)."""
from __future__ import annotations

import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT))

from benchmark.comparer import compare
from benchmark.data.generator import generate_test_data
from benchmark.data.models import Person, StringArrayObject, TelemetryData
from benchmark.serializers.binary_cbor2 import Cbor2Serializer


def _roundtrip_stream(td_name: str, td_type: type) -> None:
    original = generate_test_data(td_name)
    ser = Cbor2Serializer()
    ser.prepare(td_name, td_type)
    native = ser.prepare_data(original, td_name, td_type)
    stream = io.BytesIO()
    ser.serialize_stream(native, stream)
    assert stream.tell() > 0
    out = ser.deserialize_stream(stream)
    ok, err = compare(original, out)
    assert ok, err


def test_cbor2_stream_string_array():
    _roundtrip_stream("StringArray", StringArrayObject)


def test_cbor2_stream_person_and_telemetry():
    _roundtrip_stream("Person", Person)
    _roundtrip_stream("Telemetry", TelemetryData)


def test_cbor2_bytes_and_stream_payloads_match_for_string_array():
    original = generate_test_data("StringArray")
    ser = Cbor2Serializer()
    ser.prepare("StringArray", StringArrayObject)
    native = ser.prepare_data(original, "StringArray", StringArrayObject)
    b = ser.serialize_bytes(native)
    stream = io.BytesIO()
    ser.serialize_stream(native, stream)
    assert stream.getvalue() == b
