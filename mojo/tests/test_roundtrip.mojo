from std.collections import List
from bench.data import (
    Book,
    Document,
    Event,
    Fixture,
    Message,
    Order,
    Person,
    Strings,
    Telemetry,
    TypeConfig,
    fidelity,
    make_cell,
    make_one,
)
from bench.emberjson_ser import EmberJsonSer
from bench.ehsanmok_ser import EhsanJsonSer
from bench.cbor_ser import CborSer
from bench.avro_ser import AvroSer
from bench.protobuf_ser import ProtobufSer
from bench.flatbuffers_ser import FlatBuffersSer
from bench.toml_ser import TomlSer
from bench.gldtoml_ser import GldTomlSer
from bench.gldjson_ser import GldJsonSer
from bench.yaml_ser import YamlSer
from bench.msgpack_ser import MsgpackSer
from bench.dagr_ser import DagrSer
from bench.dagr_regular_ser import DagrRegularSer
from bench.dagr_frozen_ser import DagrFrozenSer
from bench.dagr_frozen_packed_ser import DagrFrozenPackedSer
from bench.bson_ser import BsonSer
from bench.ion_ser import IonSer
from bench.smile_ser import SmileSer
from bench.arrow_ser import ArrowIpcSer
from bench.parquet_ser import ParquetSer
from parquet_runtime.model import CODEC_NONE, CODEC_SNAPPY


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
    var gldtoml = GldTomlSer()
    var gldj = GldJsonSer()
    var yaml = YamlSer()
    var msgp = MsgpackSer()
    var dagr = DagrSer()
    var bson = BsonSer()
    var ion = IonSer()
    var smile = SmileSer()
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
    if not gldtoml.check(fx, gldtoml.serialize_bytes(fx)):
        raise Error("gld-toml fidelity " + type_id)
    if not gldj.check(fx, gldj.serialize_bytes(fx)):
        raise Error("mojo-json fidelity " + type_id)
    if not yaml.check(fx, yaml.serialize_bytes(fx)):
        raise Error("gld-yaml fidelity " + type_id)
    if not msgp.check(fx, msgp.serialize_bytes(fx)):
        raise Error("mojo-msgpack fidelity " + type_id)
    if not dagr.check(fx, dagr.serialize_bytes(fx)):
        raise Error("dagr-packed fidelity " + type_id)
    var dagr_regular = DagrRegularSer()
    if not dagr_regular.check(fx, dagr_regular.serialize_bytes(fx)):
        raise Error("dagr-regular fidelity " + type_id)
    var dagr_frozen = DagrFrozenSer()
    if not dagr_frozen.check(fx, dagr_frozen.serialize_bytes(fx)):
        raise Error("dagr-frozen fidelity " + type_id)
    var dagr_fp = DagrFrozenPackedSer()
    if not dagr_fp.check(fx, dagr_fp.serialize_bytes(fx)):
        raise Error("dagr-frozen-packed fidelity " + type_id)
    if not bson.check(fx, bson.serialize_bytes(fx)):
        raise Error("mojo-bson fidelity " + type_id)
    if not ion.check(fx, ion.serialize_bytes(fx)):
        raise Error("mojo-ion fidelity " + type_id)
    if not smile.check(fx, smile.serialize_bytes(fx)):
        raise Error("mojo-smile fidelity " + type_id)


def _ehsan_batch(type_id: String) raises:
    var cfg = TypeConfig()
    var fx = make_cell(type_id, cfg, UInt64(42), 100, "")
    var ehsan = EhsanJsonSer()
    if not ehsan.check(fx, ehsan.serialize_bytes(fx)):
        raise Error("ehsanmok-json fidelity n=100 " + type_id)


def _yaml_batch(type_id: String) raises:
    var cfg = TypeConfig()
    var one = make_one(type_id, cfg, UInt64(42), 0)
    var fx = make_cell(type_id, cfg, UInt64(42), 100, "")
    var yaml = YamlSer()
    var small = yaml.serialize_bytes(one)
    var buf = yaml.serialize_bytes(fx)
    if not yaml.check(fx, buf):
        raise Error("gld-yaml fidelity n=100 " + type_id)
    if len(buf) < len(small) * 50:
        raise Error(
            "gld-yaml size n=100 "
            + type_id
            + " "
            + String(len(buf))
            + " vs n=1 "
            + String(len(small))
        )


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
        raise Error("dagr-packed fidelity n=100 " + type_id)
    if not dagr.check(fx, dagr.serialize_bytes(fx)):
        raise Error("dagr-packed fidelity n=100 (reuse) " + type_id)
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


def _graph_cfg() -> TypeConfig:
    var cfg = TypeConfig()
    cfg.string_min = 8
    cfg.string_max = 16
    return cfg^


def _graph_shape() raises:
    var fresh = TypeConfig()
    if fresh.order_count != 32 or fresh.region_count != 4 or fresh.ring_size != 8:
        raise Error("graph count defaults")
    var cfg = _graph_cfg()
    var fx = make_one("graph", cfg, UInt64(42), 0)
    if len(fx.books) != 1:
        raise Error("graph: expected one book")
    var book = fx.books[0].copy()
    if len(book.regions) != 4 or len(book.orders) != 32 or len(book.people) != 8:
        raise Error("graph shape")
    var i = 0
    while i < len(book.regions):
        var n = book.regions[i].note.byte_length()
        var c = book.regions[i].code.byte_length()
        if n != 64 or c < 8 or c > 16:
            raise Error("graph string lengths")
        var v = Int(book.regions[i].version)
        if v < 1 or v > 10:
            raise Error("graph region version")
        i += 1
    i = 0
    while i < 4:
        var hits = 0
        var j = 0
        while j < len(book.orders):
            if book.orders[j].region_index != j % 4:
                raise Error("graph region index")
            if book.orders[j].region_index == i:
                hits += 1
            var q = Int(book.orders[j].qty)
            if q < 1 or q > 100:
                raise Error("graph qty")
            j += 1
        if hits != 8:
            raise Error("graph region was copied")
        i += 1
    i = 0
    while i < len(book.people):
        if book.people[i].next_index != (i + 1) % 8:
            raise Error("graph ring")
        var n = book.people[i].name.byte_length()
        if n < 8 or n > 16:
            raise Error("graph person name")
        i += 1
    var again = make_one("graph", cfg, UInt64(42), 0)
    if not fidelity(fx, again):
        raise Error("graph generator is not stable")
    var other = make_one("graph", cfg, UInt64(42), 1)
    if fidelity(fx, other):
        raise Error("graph seed mix did not change the book")
    var bad_people = List[Person]()
    i = 0
    while i < len(book.people):
        var nxt = book.people[i].next_index
        if i == 0:
            nxt = 0
        bad_people.append(Person(book.people[i].name.copy(), nxt))
        i += 1
    var bad = Book(book.regions.copy(), book.orders.copy(), bad_people^)
    var badfx = Fixture(
        "graph",
        1,
        "",
        List[Message](),
        List[Document](),
        List[Telemetry](),
        List[Strings](),
        List[Event](),
    )
    badfx.books.append(bad^)
    if fidelity(fx, badfx):
        raise Error("graph fidelity ignored the ring")
    var dup_orders = List[Order]()
    i = 0
    while i < len(book.orders):
        var ri = book.orders[i].region_index
        if i == 4:
            ri = 1
        dup_orders.append(Order(book.orders[i].sku.copy(), book.orders[i].qty, ri))
        i += 1
    var dup = Book(book.regions.copy(), dup_orders^, book.people.copy())
    var dupfx = Fixture(
        "graph",
        1,
        "",
        List[Message](),
        List[Document](),
        List[Telemetry](),
        List[Strings](),
        List[Event](),
    )
    dupfx.books.append(dup^)
    if fidelity(fx, dupfx):
        raise Error("graph fidelity ignored the region index")


def _graph_dagr() raises:
    var cfg = _graph_cfg()
    var fx = make_one("graph", cfg, UInt64(42), 0)
    var packed = DagrSer()
    var fp = DagrFrozenPackedSer()
    if packed.supports("graph") or fp.supports("graph"):
        raise Error("packed layouts must not support graph")
    if not packed.supports("message") or not fp.supports("event"):
        raise Error("packed suite support changed")
    var reg = DagrRegularSer()
    var frz = DagrFrozenSer()
    if not reg.supports("graph") or not frz.supports("graph"):
        raise Error("regular and frozen must support graph")
    if not reg.supports("message") or not frz.supports("document"):
        raise Error("arena suite support changed")
    var reg_buf = reg.serialize_bytes(fx)
    var reg_back = reg.deserialize_bytes(fx, reg_buf)
    if not fidelity(fx, reg_back):
        raise Error("dagr-regular graph fidelity")
    if len(reg_back.books) != 1 or len(reg_back.books[0].regions) != 4:
        raise Error("dagr-regular duplicated regions")
    if reg_back.books[0].orders[0].region_index != reg_back.books[0].orders[4].region_index:
        raise Error("dagr-regular did not keep the shared region")
    if reg_back.books[0].people[7].next_index != 0:
        raise Error("dagr-regular ring did not wrap")
    var frz_buf = frz.serialize_bytes(fx)
    var frz_back = frz.deserialize_bytes(fx, frz_buf)
    if not fidelity(fx, frz_back):
        raise Error("dagr-frozen graph fidelity")
    if len(frz_back.books[0].regions) != 4:
        raise Error("dagr-frozen duplicated regions")
    if frz_back.books[0].orders[0].region_index != 0 or frz_back.books[0].orders[1].region_index != 1:
        raise Error("dagr-frozen region index")
    if frz_back.books[0].people[0].next_index != 1:
        raise Error("dagr-frozen ring")
    # Distinct bytes: the two layouts are not the same encoding.
    if len(reg_buf) == len(frz_buf):
        var same = True
        var i = 0
        while i < len(reg_buf):
            if reg_buf[i] != frz_buf[i]:
                same = False
                break
            i += 1
        if same:
            raise Error("regular and frozen graph encodings matched")
    var batch = make_cell("graph", cfg, UInt64(42), 3, "g")
    if not reg.check(batch, reg.serialize_bytes(batch)):
        raise Error("dagr-regular graph batch")
    if not reg.check(batch, reg.serialize_bytes(batch)):
        raise Error("dagr-regular graph reuse")
    if not frz.check(batch, frz.serialize_bytes(batch)):
        raise Error("dagr-frozen graph batch")
    if not frz.check(batch, frz.serialize_bytes(batch)):
        raise Error("dagr-frozen graph reuse")
    var tiny = TypeConfig()
    tiny.order_count = 4
    tiny.region_count = 2
    tiny.ring_size = 1
    tiny.string_min = 8
    tiny.string_max = 8
    var one = make_one("graph", tiny, UInt64(7), 0)
    if one.books[0].people[0].next_index != 0:
        raise Error("graph self ring")
    if not reg.check(one, reg.serialize_bytes(one)):
        raise Error("dagr-regular self ring")
    if not frz.check(one, frz.serialize_bytes(one)):
        raise Error("dagr-frozen self ring")


def _columnar(type_id: String, n: Int) raises -> Int:
    var cfg = TypeConfig()
    if type_id == "nested_table":
        cfg.children = 4
        cfg.string_max = 12
    if type_id == "signal":
        cfg.group_count = 4
        cfg.string_max = 12
    var fx = make_cell(type_id, cfg, UInt64(42), n, "h")
    var arrow = ArrowIpcSer()
    var parquet = ParquetSer("parquet", CODEC_SNAPPY)
    var raw = ParquetSer("parquet-uncompressed", CODEC_NONE)
    var ab = arrow.serialize_bytes(fx)
    var pb = parquet.serialize_bytes(fx)
    var ub = raw.serialize_bytes(fx)
    if not arrow.check(fx, ab):
        raise Error("arrow-ipc fidelity " + type_id + " n=" + String(n))
    if not parquet.check(fx, pb):
        raise Error("parquet fidelity " + type_id + " n=" + String(n))
    if not raw.check(fx, ub):
        raise Error("parquet-uncompressed fidelity " + type_id + " n=" + String(n))
    if len(ab) < 8 or len(pb) < 8 or len(ub) < 8:
        raise Error("columnar payload too small " + type_id)
    return len(ab)


def _columnar_scale() raises:
    var one = _columnar("table", 1)
    var hundred = _columnar("table", 100)
    # IPC schema and alignment dominate n=1. The added rows must still grow the file.
    if hundred - one < 99 * 80:
        raise Error("arrow-ipc table n=100 did not scale: " + String(hundred) + " vs " + String(one))
    _ = _columnar("table_project", 1)
    _ = _columnar("table_project", 100)
    _ = _columnar("nested_table", 1)
    _ = _columnar("nested_table", 3)
    _ = _columnar("signal", 1)
    _ = _columnar("signal", 3)
    var cfg = TypeConfig()
    cfg.group_count = 0
    cfg.children = 0
    var empty_sig = make_cell("signal", cfg, UInt64(7), 2, "e")
    var empty_nest = make_cell("nested_table", cfg, UInt64(7), 2, "e")
    var arrow = ArrowIpcSer()
    var parquet = ParquetSer("parquet", CODEC_NONE)
    if not arrow.check(empty_sig, arrow.serialize_bytes(empty_sig)):
        raise Error("arrow empty signal legs")
    if not parquet.check(empty_nest, parquet.serialize_bytes(empty_nest)):
        raise Error("parquet empty nested items")
    var neg = make_cell("table", TypeConfig(), UInt64(1), 1, "n")
    neg.tables[0].floats[0] = -1.5
    if not arrow.check(neg, arrow.serialize_bytes(neg)):
        raise Error("arrow negative float")
    if not parquet.check(neg, parquet.serialize_bytes(neg)):
        raise Error("parquet negative float")


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
    _yaml_batch("message")
    _yaml_batch("document")
    _yaml_batch("telemetry")
    _yaml_batch("strings")
    _yaml_batch("event")
    _graph_shape()
    _graph_dagr()
    _columnar_scale()
    print("ok")
