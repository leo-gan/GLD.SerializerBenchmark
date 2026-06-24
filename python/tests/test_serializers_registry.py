"""Ensure Python serializer registry stays intact (imports that do not need protos)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
# generated protos live under python/generated
sys.path.insert(0, str(ROOT))


def test_core_serializers_constructible_without_optional_schema_deps():
    from benchmark.serializers.json_orjson import OrjsonSerializer
    from benchmark.serializers.json_msgspec import MsgspecSerializer, MsgspecMessagePackSerializer
    from benchmark.serializers.json_rapidjson import RapidjsonSerializer
    from benchmark.serializers.binary_msgpack import MsgpackSerializer
    from benchmark.serializers.binary_cbor2 import Cbor2Serializer
    from benchmark.serializers.native_pickle import PickleSerializer
    from benchmark.serializers.native_cloudpickle import CloudpickleSerializer
    from benchmark.serializers.base import Serializer

    instances = [
        OrjsonSerializer(),
        MsgspecSerializer(),
        RapidjsonSerializer(),
        MsgspecMessagePackSerializer(),
        MsgpackSerializer(),
        Cbor2Serializer(),
        PickleSerializer(),
        CloudpickleSerializer(),
    ]
    assert len(instances) >= 8
    for s in instances:
        assert isinstance(s, Serializer)
        assert s.name


def test_object_graph_unsupported_by_json_serializers():
    from benchmark.serializers.json_orjson import OrjsonSerializer
    from benchmark.serializers.json_msgspec import MsgspecSerializer

    assert OrjsonSerializer().supports("ObjectGraph") is False
    assert MsgspecSerializer().supports("ObjectGraph") is False


if __name__ == "__main__":
    test_core_serializers_constructible_without_optional_schema_deps()
    test_object_graph_unsupported_by_json_serializers()
    print("ok")
