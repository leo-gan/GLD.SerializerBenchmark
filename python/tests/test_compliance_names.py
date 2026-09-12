"""Compliance adapter names must match Overview / bench display names."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

# Historical splits that made All look like a subset (adapter name ≠ bench name).
FORBIDDEN_ADAPTER_NAMES = {
    "fastavro",  # bench name is avro
    "protobuf-net",  # C# bench name is ProtoBuf
    "JSON.parse",  # JS bench name is JSON.stringify
    "Foundation.JSONSerialization",  # Swift bench name is Foundation.JSONEncoder
}


def test_python_adapter_names_match_bench_when_both_exist():
    from benchmark.serializers.binary_cbor2 import Cbor2Serializer
    from benchmark.serializers.binary_msgpack import MsgpackSerializer
    from benchmark.serializers.human_yaml import PyYamlSerializer
    from benchmark.serializers.json_mashumaro import MashumaroSerializer
    from benchmark.serializers.json_msgspec import MsgspecMessagePackSerializer, MsgspecSerializer
    from benchmark.serializers.json_orjson import OrjsonSerializer
    from benchmark.serializers.json_pydantic import PydanticSerializer
    from benchmark.serializers.json_rapidjson import RapidjsonSerializer
    from benchmark.serializers.json_serpyco import SerpycoSerializer
    from benchmark.serializers.json_stdlib import StdlibJsonSerializer
    from benchmark.serializers.schema_avro import AvroSerializer
    from benchmark.serializers.schema_protobuf import ProtobufSerializer
    from compliance.adapters import builtin_adapters

    bench = {
        StdlibJsonSerializer().name,
        OrjsonSerializer().name,
        MsgspecSerializer().name,
        RapidjsonSerializer().name,
        PydanticSerializer().name,
        MashumaroSerializer().name,
        SerpycoSerializer().name,
        PyYamlSerializer().name,
        Cbor2Serializer().name,
        MsgpackSerializer().name,
        MsgspecMessagePackSerializer().name,
        ProtobufSerializer().name,
        AvroSerializer().name,
    }
    adapters = builtin_adapters()
    names = {a.name for a in adapters}
    assert "fastavro" not in names
    assert "avro" in names
    overlap = names & bench
    assert overlap, "expected shared JSON/YAML/… libraries in both lists"
    # Every adapter that is also a bench library must use the bench spelling.
    assert overlap <= bench


def test_python_runner_filters_to_serializer_standards_json():
    from compliance.adapters import builtin_adapters
    from compliance.mapping import allowed_pairs, filter_adapters

    mapped = allowed_pairs("python")
    filtered = filter_adapters("python", builtin_adapters())
    have = {(a.name, a.format) for a in filtered}
    assert have <= mapped
    # Every mapped public-spec pair the runner can import must be kept.
    raw = {(a.name, a.format) for a in builtin_adapters()}
    assert have == (raw & mapped)


def test_forbidden_split_names_are_gone_from_python_adapters():
    from compliance.adapters import builtin_adapters

    names = {a.name for a in builtin_adapters()}
    leaked = names & FORBIDDEN_ADAPTER_NAMES
    assert not leaked, f"adapter names that split All from Overview: {sorted(leaked)}"
