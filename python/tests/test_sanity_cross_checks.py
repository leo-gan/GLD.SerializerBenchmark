"""Lightweight cross-checks on suite fixtures."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from benchmark.comparer import compare
from benchmark.data_v2 import make_one
from benchmark.serializers.json_stdlib import StdlibJsonSerializer
from benchmark.serializers.binary_msgpack import MsgpackSerializer
from benchmark.data_v2.models import Document, Message, Telemetry


def test_make_one_types():
    assert isinstance(make_one("message", {}, 1), Message)
    assert isinstance(make_one("document", {}, 1), Document)
    assert isinstance(make_one("telemetry", {}, 1), Telemetry)


def test_json_and_msgpack_agree_on_message():
    msg = make_one("message", {}, 99)
    for Ser in (StdlibJsonSerializer, MsgpackSerializer):
        ser = Ser()
        ser.prepare("message", Message)
        native = ser.prepare_data(msg, "message", Message)
        data = ser.serialize_bytes(native)
        out = ser.deserialize_bytes(data)
        ok, err = compare(msg, out)
        assert ok, f"{ser.name}: {err}"
