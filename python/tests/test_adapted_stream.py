"""Adapted stream mode is the base class. Wrappers do not copy it."""

from __future__ import annotations

import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from benchmark.serializers.base import Serializer
from benchmark.serializers.columnar_arrow import (
    ArrowIpcSerializer,
    OrcSerializer,
    OrcUncompressedSerializer,
    ParquetSerializer,
    ParquetUncompressedSerializer,
)
from benchmark.serializers.json_mashumaro import MashumaroSerializer
from benchmark.serializers.json_orjson import OrjsonSerializer
from benchmark.serializers.json_pydantic import PydanticSerializer
from benchmark.serializers.json_rapidjson import RapidjsonSerializer
from benchmark.serializers.json_serpyco import SerpycoSerializer
from benchmark.serializers.json_stdlib import StdlibJsonSerializer
from benchmark.serializers.schema_avro import AvroSerializer
from benchmark.serializers.schema_flatbuffers import FlatBuffersSerializer
from benchmark.serializers.schema_protobuf import ProtobufSerializer

ADAPTED = (
    ArrowIpcSerializer,
    ParquetSerializer,
    ParquetUncompressedSerializer,
    OrcSerializer,
    OrcUncompressedSerializer,
    MashumaroSerializer,
    OrjsonSerializer,
    PydanticSerializer,
    RapidjsonSerializer,
    SerpycoSerializer,
    StdlibJsonSerializer,
    AvroSerializer,
    FlatBuffersSerializer,
    ProtobufSerializer,
)


def test_adapted_serializers_use_the_base_stream_methods():
    for cls in ADAPTED:
        assert cls.serialize_stream is Serializer.serialize_stream, cls.__name__
        assert cls.deserialize_stream is Serializer.deserialize_stream, cls.__name__


def test_base_stream_matches_bytes_and_rewinds():
    ser = StdlibJsonSerializer()
    native = {"a": 1}
    buf = io.BytesIO()
    ser.serialize_stream(native, buf)
    assert buf.getvalue() == ser.serialize_bytes(native)
    buf.seek(3)
    assert ser.deserialize_stream(buf) == native
