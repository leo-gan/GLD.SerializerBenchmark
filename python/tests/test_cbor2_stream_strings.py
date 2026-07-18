"""cbor2 stream path on v2 strings fixture."""
from __future__ import annotations

import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from benchmark.comparer import compare
from benchmark.data_v2 import make_one
from benchmark.data_v2.models import Message, Strings
from benchmark.serializers.binary_cbor2 import Cbor2Serializer


def test_cbor2_bytes_message():
    msg = make_one("message", {}, 1)
    ser = Cbor2Serializer()
    ser.prepare("message", Message)
    native = ser.prepare_data(msg, "message", Message)
    data = ser.serialize_bytes(native)
    out = ser.deserialize_bytes(data)
    ok, err = compare(msg, out)
    assert ok, err


def test_cbor2_stream_strings():
    s = make_one("strings", {"count": 16}, 2)
    ser = Cbor2Serializer()
    ser.prepare("strings", Strings)
    native = ser.prepare_data(s, "strings", Strings)
    buf = io.BytesIO()
    ser.serialize_stream(native, buf)
    out = ser.deserialize_stream(buf)
    ok, err = compare(s, out)
    assert ok, err
