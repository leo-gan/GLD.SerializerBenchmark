"""Ensure Python serializer registry stays intact (imports that do not need protos)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "generated" / "flatbuffers_gen"))
sys.path.insert(0, str(ROOT))


def test_core_serializers_constructible_without_optional_schema_deps():
    from benchmark.serializers.json_orjson import OrjsonSerializer
    from benchmark.serializers.json_msgspec import MsgspecSerializer, MsgspecMessagePackSerializer
    from benchmark.serializers.json_rapidjson import RapidjsonSerializer
    from benchmark.serializers.json_stdlib import StdlibJsonSerializer
    from benchmark.serializers.binary_msgpack import MsgpackSerializer
    from benchmark.serializers.binary_cbor2 import Cbor2Serializer
    from benchmark.serializers.native_pickle import PickleSerializer
    from benchmark.serializers.native_cloudpickle import CloudpickleSerializer
    from benchmark.serializers.native_dill import DillSerializer
    from benchmark.serializers.base import Serializer

    instances = [
        StdlibJsonSerializer(),
        OrjsonSerializer(),
        MsgspecSerializer(),
        RapidjsonSerializer(),
        MsgspecMessagePackSerializer(),
        MsgpackSerializer(),
        Cbor2Serializer(),
        PickleSerializer(),
        CloudpickleSerializer(),
        DillSerializer(),
    ]
    assert len(instances) >= 10
    for s in instances:
        assert isinstance(s, Serializer)
        assert s.name


def test_object_graph_supported_by_all_capable_serializers():
    """Flat ObjectGraph (index edges) is portable — every registered codec supports it."""
    from benchmark.runner import ALL_SERIALIZERS

    for ser in ALL_SERIALIZERS:
        assert ser.supports("ObjectGraph") is True, f"{ser.name} should support flat ObjectGraph"


def test_full_runner_registry_size():
    from benchmark.runner import ALL_SERIALIZERS

    assert len(ALL_SERIALIZERS) >= 16
    names = {s.name for s in ALL_SERIALIZERS}
    for required in (
        "json", "orjson", "msgspec", "pydantic", "mashumaro", "serpyco-rs",
        "msgpack", "cbor2", "protobuf", "avro", "flatbuffers",
        "pickle", "cloudpickle", "dill",
    ):
        assert required in names


if __name__ == "__main__":
    test_core_serializers_constructible_without_optional_schema_deps()
    test_object_graph_supported_by_all_capable_serializers()
    test_full_runner_registry_size()
    print("ok")
