"""mojo-msgpack (gld-messagepack) — WireWriter / WireReader on suite types."""

from std.collections import List
from msgpack import DecodeError, WireReader, WireWriter
from bench.data import (
    Document,
    DocumentItem,
    Event,
    EventAttr,
    Fixture,
    Message,
    Strings,
    Telemetry,
    fidelity,
)


def _enc_msg(m: Message, mut w: WireWriter):
    w.write_map_header(8)
    w.write_str("f_bool")
    w.write_bool(m.f_bool)
    w.write_str("f_int32")
    w.write_int(Int64(m.f_int32))
    w.write_str("f_int64")
    w.write_int(m.f_int64)
    w.write_str("f_float64")
    w.write_f64(m.f_float64)
    w.write_str("f_string")
    w.write_str(m.f_string)
    w.write_str("f_bool_2")
    w.write_bool(m.f_bool_2)
    w.write_str("f_int32_2")
    w.write_int(Int64(m.f_int32_2))
    w.write_str("f_string_2")
    w.write_str(m.f_string_2)


def _dec_msg[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Message:
    var m = Message()
    var n = r.read_map_header()
    var i = 0
    while i < n:
        var key = r.read_str()
        if key == "f_bool":
            m.f_bool = r.read_bool()
        elif key == "f_int32":
            m.f_int32 = Int32(r.read_i64())
        elif key == "f_int64":
            m.f_int64 = r.read_i64()
        elif key == "f_float64":
            m.f_float64 = r.read_as_f64()
        elif key == "f_string":
            m.f_string = r.read_str()
        elif key == "f_bool_2":
            m.f_bool_2 = r.read_bool()
        elif key == "f_int32_2":
            m.f_int32_2 = Int32(r.read_i64())
        elif key == "f_string_2":
            m.f_string_2 = r.read_str()
        else:
            r.skip_value()
        i += 1
    return m^


def _enc_doc(d: Document, mut w: WireWriter):
    w.write_map_header(4)
    w.write_str("id")
    w.write_str(d.id)
    w.write_str("status")
    w.write_int(Int64(d.status))
    w.write_str("meta")
    w.write_map_header(2)
    w.write_str("region")
    w.write_str(d.meta.region)
    w.write_str("version")
    w.write_int(Int64(d.meta.version))
    w.write_str("items")
    w.write_array_header(len(d.items))
    var i = 0
    while i < len(d.items):
        w.write_map_header(3)
        w.write_str("sku")
        w.write_str(d.items[i].sku)
        w.write_str("qty")
        w.write_int(Int64(d.items[i].qty))
        w.write_str("price_minor")
        w.write_int(d.items[i].price_minor)
        i += 1


def _dec_doc[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Document:
    var d = Document()
    d.items = List[DocumentItem]()
    var n = r.read_map_header()
    var i = 0
    while i < n:
        var key = r.read_str()
        if key == "id":
            d.id = r.read_str()
        elif key == "status":
            d.status = Int32(r.read_i64())
        elif key == "meta":
            var mn = r.read_map_header()
            var j = 0
            while j < mn:
                var mk = r.read_str()
                if mk == "region":
                    d.meta.region = r.read_str()
                elif mk == "version":
                    d.meta.version = Int32(r.read_i64())
                else:
                    r.skip_value()
                j += 1
        elif key == "items":
            var count = r.read_array_header()
            var k = 0
            while k < count:
                var it = DocumentItem()
                var in_ = r.read_map_header()
                var p = 0
                while p < in_:
                    var ik = r.read_str()
                    if ik == "sku":
                        it.sku = r.read_str()
                    elif ik == "qty":
                        it.qty = Int32(r.read_i64())
                    elif ik == "price_minor":
                        it.price_minor = r.read_i64()
                    else:
                        r.skip_value()
                    p += 1
                d.items.append(it^)
                k += 1
        else:
            r.skip_value()
        i += 1
    return d^


def _enc_tel(t: Telemetry, mut w: WireWriter):
    w.write_map_header(4)
    w.write_str("source")
    w.write_str(t.source)
    w.write_str("ts")
    w.write_int(t.ts)
    w.write_str("tags")
    w.write_array_header(len(t.tags))
    var i = 0
    while i < len(t.tags):
        w.write_str(t.tags[i])
        i += 1
    w.write_str("values")
    w.write_array_header(len(t.values))
    i = 0
    while i < len(t.values):
        w.write_f64(t.values[i])
        i += 1


def _dec_tel[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Telemetry:
    var t = Telemetry()
    var n = r.read_map_header()
    var i = 0
    while i < n:
        var key = r.read_str()
        if key == "source":
            t.source = r.read_str()
        elif key == "ts":
            t.ts = r.read_i64()
        elif key == "tags":
            var count = r.read_array_header()
            var j = 0
            while j < count:
                t.tags.append(r.read_str())
                j += 1
        elif key == "values":
            var count = r.read_array_header()
            var j = 0
            while j < count:
                t.values.append(r.read_as_f64())
                j += 1
        else:
            r.skip_value()
        i += 1
    return t^


def _enc_str(s: Strings, mut w: WireWriter):
    w.write_map_header(1)
    w.write_str("items")
    w.write_array_header(len(s.items))
    var i = 0
    while i < len(s.items):
        w.write_str(s.items[i])
        i += 1


def _dec_str[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Strings:
    var s = Strings()
    var n = r.read_map_header()
    var i = 0
    while i < n:
        var key = r.read_str()
        if key == "items":
            var count = r.read_array_header()
            var j = 0
            while j < count:
                s.items.append(r.read_str())
                j += 1
        else:
            r.skip_value()
        i += 1
    return s^


def _enc_ev(e: Event, mut w: WireWriter):
    w.write_map_header(5)
    w.write_str("event_id")
    w.write_str(e.event_id)
    w.write_str("event_type")
    w.write_str(e.event_type)
    w.write_str("occurred_at")
    w.write_int(e.occurred_at)
    w.write_str("producer")
    w.write_str(e.producer)
    w.write_str("attrs")
    w.write_array_header(len(e.attrs))
    var i = 0
    while i < len(e.attrs):
        w.write_map_header(2)
        w.write_str("key")
        w.write_str(e.attrs[i].key)
        w.write_str("value")
        w.write_str(e.attrs[i].value)
        i += 1


def _dec_ev[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Event:
    var e = Event()
    e.attrs = List[EventAttr]()
    var n = r.read_map_header()
    var i = 0
    while i < n:
        var key = r.read_str()
        if key == "event_id":
            e.event_id = r.read_str()
        elif key == "event_type":
            e.event_type = r.read_str()
        elif key == "occurred_at":
            e.occurred_at = r.read_i64()
        elif key == "producer":
            e.producer = r.read_str()
        elif key == "attrs":
            var count = r.read_array_header()
            var j = 0
            while j < count:
                var a = EventAttr()
                var an = r.read_map_header()
                var p = 0
                while p < an:
                    var ak = r.read_str()
                    if ak == "key":
                        a.key = r.read_str()
                    elif ak == "value":
                        a.value = r.read_str()
                    else:
                        r.skip_value()
                    p += 1
                e.attrs.append(a^)
                j += 1
        else:
            r.skip_value()
        i += 1
    return e^


def _wrap_items(mut w: WireWriter, n: Int):
    w.write_map_header(1)
    w.write_str("items")
    w.write_array_header(n)


struct MsgpackSer:
    var version: String

    def __init__(out self):
        self.version = "0.3.0"

    def name(self) -> String:
        return "mojo-msgpack"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var cap = 1024
        if fx.n > 1:
            cap = 65536
        var w = WireWriter(capacity=cap)
        if fx.type_id == "message":
            if fx.n == 1:
                _enc_msg(fx.messages[0], w)
            else:
                _wrap_items(w, fx.n)
                var i = 0
                while i < fx.n:
                    _enc_msg(fx.messages[i], w)
                    i += 1
        elif fx.type_id == "document":
            if fx.n == 1:
                _enc_doc(fx.documents[0], w)
            else:
                _wrap_items(w, fx.n)
                var i = 0
                while i < fx.n:
                    _enc_doc(fx.documents[i], w)
                    i += 1
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                _enc_tel(fx.telemetries[0], w)
            else:
                _wrap_items(w, fx.n)
                var i = 0
                while i < fx.n:
                    _enc_tel(fx.telemetries[i], w)
                    i += 1
        elif fx.type_id == "strings":
            if fx.n == 1:
                _enc_str(fx.strings[0], w)
            else:
                _wrap_items(w, fx.n)
                var i = 0
                while i < fx.n:
                    _enc_str(fx.strings[i], w)
                    i += 1
        else:
            if fx.n == 1:
                _enc_ev(fx.events[0], w)
            else:
                _wrap_items(w, fx.n)
                var i = 0
                while i < fx.n:
                    _enc_ev(fx.events[i], w)
                    i += 1
        return w^.finish()

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var out = Fixture(
            fx.type_id,
            fx.n,
            fx.hash,
            List[Message](),
            List[Document](),
            List[Telemetry](),
            List[Strings](),
            List[Event](),
        )
        var r = WireReader(data)
        if fx.n != 1:
            var n = r.read_map_header()
            var i = 0
            while i < n:
                var key = r.read_str()
                if key == "items":
                    items_n = r.read_array_header()
                    var j = 0
                    while j < items_n:
                        if fx.type_id == "message":
                            out.messages.append(_dec_msg(r))
                        elif fx.type_id == "document":
                            out.documents.append(_dec_doc(r))
                        elif fx.type_id == "telemetry":
                            out.telemetries.append(_dec_tel(r))
                        elif fx.type_id == "strings":
                            out.strings.append(_dec_str(r))
                        else:
                            out.events.append(_dec_ev(r))
                        j += 1
                else:
                    r.skip_value()
                i += 1
            return out^
        if fx.type_id == "message":
            out.messages.append(_dec_msg(r))
        elif fx.type_id == "document":
            out.documents.append(_dec_doc(r))
        elif fx.type_id == "telemetry":
            out.telemetries.append(_dec_tel(r))
        elif fx.type_id == "strings":
            out.strings.append(_dec_str(r))
        else:
            out.events.append(_dec_ev(r))
        return out^

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
