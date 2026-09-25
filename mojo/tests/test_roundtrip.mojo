from bench.data import TypeConfig, make_cell, make_one
from bench.emberjson_ser import EmberJsonSer
from bench.ehsanmok_ser import EhsanJsonSer
from bench.cbor_ser import CborSer
from bench.avro_ser import AvroSer
from bench.protobuf_ser import ProtobufSer
from bench.flatbuffers_ser import FlatBuffersSer
from bench.toml_ser import TomlSer
from bench.gldjson_ser import GldJsonSer
from bench.yaml_ser import YamlSer
from bench.msgpack_ser import MsgpackSer
from bench.dagr_ser import DagrSer
from bench.dagr_regular_ser import DagrRegularSer
from bench.dagr_frozen_ser import DagrFrozenSer
from bench.dagr_frozen_packed_ser import DagrFrozenPackedSer


def _roundtrip_all(type_id: String) raises:
    var cfg = TypeConfig()
    var fx = make_one(type_id, cfg, UInt64(42), 0)
    var ember = EmberJsonSer()
    var ehsan = EhsanJsonSer()
    var cbor = CborSer()
    var avro = AvroSer()
    var proto = ProtobufSer()
    var fb = FlatBuffersSer()
    var toml = TomlSer()
    var gldj = GldJsonSer()
    var yaml = YamlSer()
    var msgp = MsgpackSer()
    var dagr = DagrSer()
    if not ember.check(fx, ember.serialize_bytes(fx)):
        raise Error("emberjson fidelity " + type_id)
    if not ehsan.check(fx, ehsan.serialize_bytes(fx)):
        raise Error("ehsanmok-json fidelity " + type_id)
    if not cbor.check(fx, cbor.serialize_bytes(fx)):
        raise Error("cbor fidelity " + type_id)
    if not avro.check(fx, avro.serialize_bytes(fx)):
        raise Error("avro fidelity " + type_id)
    if not proto.check(fx, proto.serialize_bytes(fx)):
        raise Error("protobuf fidelity " + type_id)
    if not fb.check(fx, fb.serialize_bytes(fx)):
        raise Error("flatbuffers fidelity " + type_id)
    if not toml.check(fx, toml.serialize_bytes(fx)):
        raise Error("toml fidelity " + type_id)
    if not gldj.check(fx, gldj.serialize_bytes(fx)):
        raise Error("mojo-json fidelity " + type_id)
    if not yaml.check(fx, yaml.serialize_bytes(fx)):
        raise Error("gld-yaml fidelity " + type_id)
    if not msgp.check(fx, msgp.serialize_bytes(fx)):
        raise Error("mojo-msgpack fidelity " + type_id)
    if not dagr.check(fx, dagr.serialize_bytes(fx)):
        raise Error("dagr fidelity " + type_id)
    var dagr_regular = DagrRegularSer()
    if not dagr_regular.check(fx, dagr_regular.serialize_bytes(fx)):
        raise Error("dagr-regular fidelity " + type_id)
    var dagr_frozen = DagrFrozenSer()
    if not dagr_frozen.check(fx, dagr_frozen.serialize_bytes(fx)):
        raise Error("dagr-frozen fidelity " + type_id)
    var dagr_fp = DagrFrozenPackedSer()
    if not dagr_fp.check(fx, dagr_fp.serialize_bytes(fx)):
        raise Error("dagr-frozen-packed fidelity " + type_id)


def _ehsan_batch(type_id: String) raises:
    var cfg = TypeConfig()
    var fx = make_cell(type_id, cfg, UInt64(42), 100, "")
    var ehsan = EhsanJsonSer()
    if not ehsan.check(fx, ehsan.serialize_bytes(fx)):
        raise Error("ehsanmok-json fidelity n=100 " + type_id)


def _flatbuffers_batch(type_id: String) raises:
    var cfg = TypeConfig()
    var fx = make_cell(type_id, cfg, UInt64(42), 100, "")
    var fb = FlatBuffersSer()
    if not fb.check(fx, fb.serialize_bytes(fx)):
        raise Error("flatbuffers fidelity n=100 " + type_id)


def _dagr_batch(type_id: String) raises:
    var cfg = TypeConfig()
    var fx = make_cell(type_id, cfg, UInt64(42), 100, "")
    var dagr = DagrSer()
    # Twice: the second call reuses the builder and the size hint.
    if not dagr.check(fx, dagr.serialize_bytes(fx)):
        raise Error("dagr fidelity n=100 " + type_id)
    if not dagr.check(fx, dagr.serialize_bytes(fx)):
        raise Error("dagr fidelity n=100 (reuse) " + type_id)
    var dagr_regular = DagrRegularSer()
    var dagr_frozen = DagrFrozenSer()
    var dagr_fp = DagrFrozenPackedSer()
    for _ in range(2):
        if not dagr_regular.check(fx, dagr_regular.serialize_bytes(fx)):
            raise Error("dagr-regular fidelity n=100 " + type_id)
        if not dagr_frozen.check(fx, dagr_frozen.serialize_bytes(fx)):
            raise Error("dagr-frozen fidelity n=100 " + type_id)
        if not dagr_fp.check(fx, dagr_fp.serialize_bytes(fx)):
            raise Error("dagr-frozen-packed fidelity n=100 " + type_id)


def main() raises:
    _roundtrip_all("message")
    _roundtrip_all("document")
    _roundtrip_all("telemetry")
    _roundtrip_all("strings")
    _roundtrip_all("event")
    _ehsan_batch("document")
    _ehsan_batch("telemetry")
    _flatbuffers_batch("document")
    _flatbuffers_batch("telemetry")
    _flatbuffers_batch("strings")
    _flatbuffers_batch("event")
    _flatbuffers_batch("message")
    _dagr_batch("message")
    _dagr_batch("document")
    _dagr_batch("telemetry")
    _dagr_batch("strings")
    _dagr_batch("event")
    print("ok")
