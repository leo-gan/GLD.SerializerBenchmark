"""
Sanity tests that re-check the suite from a different angle than the
primary contract/roundtrip tests.

Goals:
- Inventory consistency (docs/registry/modules)
- Roundtrip matrix for *all* registered serializers on a fixed fixture
- Invariants: serialize of same native input is deterministic for pure codecs
- Negative: ObjectGraph only on native family
- prepare must be called before schema deserializers work
"""
from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "generated" / "flatbuffers_gen"))
sys.path.insert(0, str(ROOT))

from benchmark.comparer import compare
from benchmark.data.generator import generate_test_data
from benchmark.data.models import GraphNode, Person
from benchmark.runner import ALL_SERIALIZERS, ALL_TEST_DATA


def test_registry_names_are_unique():
    names = [s.name for s in ALL_SERIALIZERS]
    dupes = [n for n, c in Counter(names).items() if c > 1]
    assert not dupes, f"duplicate serializer names: {dupes}"
    assert len(names) >= 16


def test_every_serializer_declares_metadata():
    for s in ALL_SERIALIZERS:
        assert s.native_kind in {"dataclass", "dict", "struct", "message", "model"}
        assert s.stream_mode in {"native", "adapted"}


@pytest.mark.parametrize("ser", ALL_SERIALIZERS, ids=lambda s: s.name)
def test_all_serializers_person_or_skip(ser):
    """Different angle: drive entirely from runner registry, not hand-picked lists."""
    if not ser.supports("Person"):
        pytest.skip("unsupported")
    original = generate_test_data("Person")
    ser.prepare("Person", Person)
    native = ser.prepare_data(original, "Person", Person)
    a = ser.serialize_bytes(native)
    b = ser.serialize_bytes(native)
    # Pure codecs should be deterministic on identical input
    assert a == b, f"{ser.name}: non-deterministic serialize"
    out = ser.deserialize_bytes(a)
    ok, err = compare(original, out)
    assert ok, f"{ser.name}: {err}"


def test_object_graph_only_native_family_succeeds():
    original = generate_test_data("ObjectGraph")
    successes = []
    failures = []
    for ser in ALL_SERIALIZERS:
        if not ser.supports("ObjectGraph"):
            failures.append(ser.name)
            continue
        try:
            ser.prepare("ObjectGraph", GraphNode)
            native = ser.prepare_data(original, "ObjectGraph", GraphNode)
            data = ser.serialize_bytes(native)
            out = ser.deserialize_bytes(data)
            ok, _ = compare(original, out)
            if ok:
                successes.append(ser.name)
            else:
                failures.append(ser.name)
        except Exception:
            failures.append(ser.name)
    # Only language-native serializers are expected to pass cycles
    for name in successes:
        assert name in {"pickle", "cloudpickle", "dill"}, f"unexpected ObjectGraph success: {name}"
    assert set(successes) >= {"pickle", "cloudpickle", "dill"}


def test_schema_deserialize_requires_prepare():
    from benchmark.serializers.schema_protobuf import ProtobufSerializer
    from benchmark.serializers.schema_avro import AvroSerializer

    for ser in (ProtobufSerializer(), AvroSerializer()):
        with pytest.raises((RuntimeError, TypeError, AttributeError, KeyError, Exception)):
            # No prepare → should not silently work with wrong type
            ser.deserialize_bytes(b"\x00\x01\x02\x03")


def test_dict_native_kind_serializers_output_json_or_binary_not_empty():
    original = generate_test_data("Person")
    for ser in ALL_SERIALIZERS:
        if ser.native_kind != "dict" or not ser.supports("Person"):
            continue
        ser.prepare("Person", Person)
        native = ser.prepare_data(original, "Person", Person)
        assert isinstance(native, dict)
        data = ser.serialize_bytes(native)
        assert len(data) > 20


def test_test_data_registry_names_match_generator():
    for name, _cls in ALL_TEST_DATA:
        obj = generate_test_data(name)
        assert obj is not None


def test_comparer_accepts_dict_projection_of_person():
    """Sanity on comparer: dict projection equal to dataclass (dict-codec path)."""
    from benchmark.converters import to_dict

    person = generate_test_data("Person")
    ok, err = compare(person, to_dict(person))
    assert ok, err


def test_comparer_rejects_clear_mismatch():
    person = generate_test_data("Person")
    bad = generate_test_data("Person")
    bad.Age = person.Age + 999
    ok, err = compare(person, bad)
    assert ok is False
    assert "Age" in err or "mismatch" in err
