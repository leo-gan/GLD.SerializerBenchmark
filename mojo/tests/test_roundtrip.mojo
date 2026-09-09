from bench.data import TypeConfig, fidelity, make_one
from bench.emberjson_ser import EmberJsonSer
from bench.ehsanmok_ser import EhsanJsonSer
from bench.cbor_ser import CborSer
from bench.avro_ser import AvroSer
from bench.protobuf_ser import ProtobufSer
from bench.toml_ser import TomlSer
from bench.gldjson_ser import GldJsonSer


def _roundtrip_all(type_id: String) raises:
    var cfg = TypeConfig()
    var fx = make_one(type_id, cfg, UInt64(42), 0)
    var ember = EmberJsonSer()
    var ehsan = EhsanJsonSer()
    var cbor = CborSer()
    var avro = AvroSer()
    var proto = ProtobufSer()
    var toml = TomlSer()
    var gldj = GldJsonSer()
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
    if not toml.check(fx, toml.serialize_bytes(fx)):
        raise Error("toml fidelity " + type_id)
    if not gldj.check(fx, gldj.serialize_bytes(fx)):
        raise Error("mojo-json fidelity " + type_id)


def main() raises:
    _roundtrip_all("message")
    _roundtrip_all("document")
    _roundtrip_all("telemetry")
    _roundtrip_all("strings")
    _roundtrip_all("event")
    print("ok")
