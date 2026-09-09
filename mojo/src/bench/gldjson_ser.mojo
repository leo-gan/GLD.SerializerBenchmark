"""mojo-json (gld-json) generated-path style encode/decode on suite types."""

from std.collections import List
from gldjson import (
    DecodeError,
    EncodeOptions,
    WireReader,
    WireWriter,
    read_bool_here,
    read_float_here,
    read_float_list,
    read_string_list,
    write_float_list,
    write_string_list,
)
from bench.data import (
    Document,
    DocumentItem,
    DocumentMeta,
    Event,
    EventAttr,
    Fixture,
    Message,
    Strings,
    Telemetry,
    fidelity,
)


def _enc_msg(m: Message, mut w: WireWriter):
    w.write_byte(Byte(123))
    w.write_bytes("\"f_bool\":".as_bytes())
    w.write_bool(m.f_bool)
    w.write_bytes(",\"f_int32\":".as_bytes())
    w.write_int(Int64(m.f_int32))
    w.write_bytes(",\"f_int64\":".as_bytes())
    w.write_int(m.f_int64)
    w.write_bytes(",\"f_float64\":".as_bytes())
    w.write_float(m.f_float64)
    w.write_bytes(",\"f_string\":".as_bytes())
    w.write_string(m.f_string)
    w.write_bytes(",\"f_bool_2\":".as_bytes())
    w.write_bool(m.f_bool_2)
    w.write_bytes(",\"f_int32_2\":".as_bytes())
    w.write_int(Int64(m.f_int32_2))
    w.write_bytes(",\"f_string_2\":".as_bytes())
    w.write_string(m.f_string_2)
    w.write_byte(Byte(125))


def _syn[origin: ImmOrigin](r: WireReader[origin]) raises DecodeError:
    raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)


def _need64[origin: ImmOrigin](mut r: WireReader[origin], n: Int, w: UInt64) raises DecodeError:
    if r.pos + n > len(r.data) or r.load_u64() != w:
        _syn(r)


def _need32[origin: ImmOrigin](mut r: WireReader[origin], n: Int, w: UInt32) raises DecodeError:
    if r.pos + n > len(r.data) or r.load_u32_at(0) != w:
        _syn(r)


def _byte[origin: ImmOrigin](r: WireReader[origin], off: Int, b: Int) raises DecodeError:
    if Int(r.data[r.pos + off]) != b:
        _syn(r)


def _close[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError:
    if r.pos >= len(r.data) or Int(r.data[r.pos]) != 125:
        _syn(r)
    r.pos += 1


def _dec_msg[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Message:
    var m = Message()
    r.eat(123)
    _need64(r, 9, UInt64(2480480018956772898))
    _byte(r, 8, 58)
    r.pos += 9
    m.f_bool = read_bool_here(r)
    _need64(r, 11, UInt64(3707709792083911212))
    _byte(r, 8, 50)
    _byte(r, 9, 34)
    _byte(r, 10, 58)
    r.pos += 11
    m.f_int32 = Int32(r.read_int_here())
    _need64(r, 11, UInt64(3923882574197695020))
    _byte(r, 8, 52)
    _byte(r, 9, 34)
    _byte(r, 10, 58)
    r.pos += 11
    m.f_int64 = r.read_int_here()
    _need64(r, 13, UInt64(7020949531036885548))
    if r.load_u32_at(8) != UInt32(573847156):
        _syn(r)
    _byte(r, 12, 58)
    r.pos += 13
    m.f_float64 = read_float_here(r)
    _need64(r, 12, UInt64(7598263560198038060))
    if r.load_u32_at(8) != UInt32(975333230):
        _syn(r)
    r.pos += 12
    m.f_string = r.read_string_here()
    _need64(r, 12, UInt64(7813586346809106988))
    if r.load_u32_at(8) != UInt32(975319647):
        _syn(r)
    r.pos += 12
    m.f_bool_2 = read_bool_here(r)
    _need64(r, 13, UInt64(3707709792083911212))
    if r.load_u32_at(8) != UInt32(573726514):
        _syn(r)
    _byte(r, 12, 58)
    r.pos += 13
    m.f_int32_2 = Int32(r.read_int_here())
    _need64(r, 14, UInt64(7598263560198038060))
    if r.load_u32_at(8) != UInt32(845113198):
        _syn(r)
    _byte(r, 12, 34)
    _byte(r, 13, 58)
    r.pos += 14
    m.f_string_2 = r.read_string_here()
    _close(r)
    return m^


def _enc_doc(d: Document, mut w: WireWriter):
    w.write_byte(Byte(123))
    w.write_bytes("\"id\":".as_bytes())
    w.write_string(d.id)
    w.write_bytes(",\"status\":".as_bytes())
    w.write_int(Int64(d.status))
    w.write_bytes(",\"meta\":{\"region\":".as_bytes())
    w.write_string(d.meta.region)
    w.write_bytes(",\"version\":".as_bytes())
    w.write_int(Int64(d.meta.version))
    w.write_bytes("},\"items\":".as_bytes())
    w.write_byte(Byte(91))
    var i = 0
    while i < len(d.items):
        if i > 0:
            w.write_byte(Byte(44))
        w.write_bytes("{\"sku\":".as_bytes())
        w.write_string(d.items[i].sku)
        w.write_bytes(",\"qty\":".as_bytes())
        w.write_int(Int64(d.items[i].qty))
        w.write_bytes(",\"price_minor\":".as_bytes())
        w.write_int(d.items[i].price_minor)
        w.write_byte(Byte(125))
        i += 1
    w.write_byte(Byte(93))
    w.write_byte(Byte(125))


def _dec_doc[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Document:
    var d = Document()
    r.eat(123)
    _need32(r, 5, UInt32(577005858))
    _byte(r, 4, 58)
    r.pos += 5
    d.id = r.read_string_here()
    _need64(r, 10, UInt64(8319683848551211564))
    _byte(r, 8, 34)
    _byte(r, 9, 58)
    r.pos += 10
    d.status = Int32(r.read_int_here())
    _need64(r, 18, UInt64(4189017755953734188))
    if r.load_u32_at(8) != UInt32(1701978747):
        _syn(r)
    _byte(r, 12, 103)
    _byte(r, 13, 105)
    _byte(r, 14, 111)
    _byte(r, 15, 110)
    _byte(r, 16, 34)
    _byte(r, 17, 58)
    r.pos += 18
    d.meta.region = r.read_string_here()
    _need64(r, 11, UInt64(8028074745930326572))
    _byte(r, 8, 110)
    _byte(r, 9, 34)
    _byte(r, 10, 58)
    r.pos += 11
    d.meta.version = Int32(r.read_int_here())
    _need64(r, 10, UInt64(8317415637477633149))
    _byte(r, 8, 34)
    _byte(r, 9, 58)
    r.pos += 10
    r.eat_here(91)
    if r.pos < len(r.data) and Int(r.data[r.pos]) != 93:
        while True:
            var it = DocumentItem()
            _need32(r, 7, UInt32(1802707579))
            _byte(r, 4, 117)
            _byte(r, 5, 34)
            _byte(r, 6, 58)
            r.pos += 7
            it.sku = r.read_string_here()
            _need32(r, 7, UInt32(1953571372))
            _byte(r, 4, 121)
            _byte(r, 5, 34)
            _byte(r, 6, 58)
            r.pos += 7
            it.qty = Int32(r.read_int_here())
            _need64(r, 15, UInt64(6874009710793597484))
            if r.load_u32_at(8) != UInt32(1869506925):
                _syn(r)
            _byte(r, 12, 114)
            _byte(r, 13, 34)
            _byte(r, 14, 58)
            r.pos += 15
            it.price_minor = r.read_int_here()
            _close(r)
            d.items.append(it^)
            if r.pos < len(r.data) and Int(r.data[r.pos]) == 93:
                break
            r.eat_here(44)
    r.eat_here(93)
    _close(r)
    return d^


def _enc_tel(t: Telemetry, mut w: WireWriter):
    w.write_byte(Byte(123))
    w.write_bytes("\"source\":".as_bytes())
    w.write_string(t.source)
    w.write_bytes(",\"ts\":".as_bytes())
    w.write_int(t.ts)
    w.write_bytes(",\"tags\":".as_bytes())
    write_string_list(w, t.tags, EncodeOptions.compact)
    w.write_bytes(",\"values\":".as_bytes())
    write_float_list(w, t.values, EncodeOptions.compact)
    w.write_byte(Byte(125))


def _dec_tel[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Telemetry:
    var t = Telemetry()
    r.eat(123)
    _need64(r, 9, UInt64(2478496513184985890))
    _byte(r, 8, 58)
    r.pos += 9
    t.source = r.read_string_here()
    _need32(r, 6, UInt32(1936990764))
    _byte(r, 4, 34)
    _byte(r, 5, 58)
    r.pos += 6
    t.ts = r.read_int_here()
    _need64(r, 8, UInt64(4189037491261809196))
    r.pos += 8
    t.tags = read_string_list(r)
    _need64(r, 10, UInt64(8315181395361538604))
    _byte(r, 8, 34)
    _byte(r, 9, 58)
    r.pos += 10
    t.values = read_float_list(r)
    _close(r)
    return t^


def _enc_str(s: Strings, mut w: WireWriter):
    w.write_byte(Byte(123))
    w.write_bytes("\"items\":".as_bytes())
    write_string_list(w, s.items, EncodeOptions.compact)
    w.write_byte(Byte(125))


def _dec_str[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Strings:
    var s = Strings()
    r.eat(123)
    _need64(r, 8, UInt64(4189037517098740002))
    r.pos += 8
    s.items = read_string_list(r)
    _close(r)
    return s^


def _enc_ev(e: Event, mut w: WireWriter):
    w.write_byte(Byte(123))
    w.write_bytes("\"event_id\":".as_bytes())
    w.write_string(e.event_id)
    w.write_bytes(",\"event_type\":".as_bytes())
    w.write_string(e.event_type)
    w.write_bytes(",\"occurred_at\":".as_bytes())
    w.write_int(e.occurred_at)
    w.write_bytes(",\"producer\":".as_bytes())
    w.write_string(e.producer)
    w.write_bytes(",\"attrs\":".as_bytes())
    w.write_byte(Byte(91))
    var i = 0
    while i < len(e.attrs):
        if i > 0:
            w.write_byte(Byte(44))
        w.write_bytes("{\"key\":".as_bytes())
        w.write_string(e.attrs[i].key)
        w.write_bytes(",\"value\":".as_bytes())
        w.write_string(e.attrs[i].value)
        w.write_byte(Byte(125))
        i += 1
    w.write_byte(Byte(93))
    w.write_byte(Byte(125))


def _dec_ev[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Event:
    var e = Event()
    r.eat(123)
    _need64(r, 11, UInt64(7592915514267428130))
    _byte(r, 8, 100)
    _byte(r, 9, 34)
    _byte(r, 10, 58)
    r.pos += 11
    e.event_id = r.read_string_here()
    _need64(r, 14, UInt64(6878243912958681644))
    if r.load_u32_at(8) != UInt32(1701869940):
        _syn(r)
    _byte(r, 12, 34)
    _byte(r, 13, 58)
    r.pos += 14
    e.event_type = r.read_string_here()
    _need64(r, 15, UInt64(8246782937399239212))
    if r.load_u32_at(8) != UInt32(1633641573):
        _syn(r)
    _byte(r, 12, 116)
    _byte(r, 13, 34)
    _byte(r, 14, 58)
    r.pos += 15
    e.occurred_at = r.read_int_here()
    _need64(r, 12, UInt64(7166744811854111276))
    if r.load_u32_at(8) != UInt32(975336037):
        _syn(r)
    r.pos += 12
    e.producer = r.read_string_here()
    _need64(r, 9, UInt64(2482453664105570860))
    _byte(r, 8, 58)
    r.pos += 9
    r.eat_here(91)
    if r.pos < len(r.data) and Int(r.data[r.pos]) != 93:
        while True:
            var a = EventAttr()
            _need32(r, 7, UInt32(1701519995))
            _byte(r, 4, 121)
            _byte(r, 5, 34)
            _byte(r, 6, 58)
            r.pos += 7
            a.key = r.read_string_here()
            _need64(r, 9, UInt64(2478516278289375788))
            _byte(r, 8, 58)
            r.pos += 9
            a.value = r.read_string_here()
            _close(r)
            e.attrs.append(a^)
            if r.pos < len(r.data) and Int(r.data[r.pos]) == 93:
                break
            r.eat_here(44)
    r.eat_here(93)
    _close(r)
    return e^


struct GldJsonSer:
    var version: String

    def __init__(out self):
        self.version = "0.2.0"

    def name(self) -> String:
        return "mojo-json"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var cap = 256
        if fx.n > 1:
            cap = 65536
        var w = WireWriter(capacity=cap)
        if fx.type_id == "message":
            if fx.n == 1:
                _enc_msg(fx.messages[0], w)
            else:
                w.write_bytes("{\"items\":[".as_bytes())
                var i = 0
                while i < fx.n:
                    if i > 0:
                        w.write_byte(Byte(44))
                    _enc_msg(fx.messages[i], w)
                    i += 1
                w.write_bytes("]}".as_bytes())
        elif fx.type_id == "document":
            if fx.n == 1:
                _enc_doc(fx.documents[0], w)
            else:
                w.write_bytes("{\"items\":[".as_bytes())
                var i = 0
                while i < fx.n:
                    if i > 0:
                        w.write_byte(Byte(44))
                    _enc_doc(fx.documents[i], w)
                    i += 1
                w.write_bytes("]}".as_bytes())
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                _enc_tel(fx.telemetries[0], w)
            else:
                w.write_bytes("{\"items\":[".as_bytes())
                var i = 0
                while i < fx.n:
                    if i > 0:
                        w.write_byte(Byte(44))
                    _enc_tel(fx.telemetries[i], w)
                    i += 1
                w.write_bytes("]}".as_bytes())
        elif fx.type_id == "strings":
            if fx.n == 1:
                _enc_str(fx.strings[0], w)
            else:
                w.write_bytes("{\"items\":[".as_bytes())
                var i = 0
                while i < fx.n:
                    if i > 0:
                        w.write_byte(Byte(44))
                    _enc_str(fx.strings[i], w)
                    i += 1
                w.write_bytes("]}".as_bytes())
        else:
            if fx.n == 1:
                _enc_ev(fx.events[0], w)
            else:
                w.write_bytes("{\"items\":[".as_bytes())
                var i = 0
                while i < fx.n:
                    if i > 0:
                        w.write_byte(Byte(44))
                    _enc_ev(fx.events[i], w)
                    i += 1
                w.write_bytes("]}".as_bytes())
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
        if fx.type_id == "message":
            if fx.n == 1:
                out.messages.append(_dec_msg(r))
            else:
                r.eat(123)
                _need64(r, 8, UInt64(4189037517098740002))
                r.pos += 8
                r.eat_here(91)
                if r.pos < len(r.data) and Int(r.data[r.pos]) != 93:
                    while True:
                        out.messages.append(_dec_msg(r))
                        if r.pos < len(r.data) and Int(r.data[r.pos]) == 93:
                            break
                        r.eat_here(44)
                r.eat_here(93)
                _close(r)
        elif fx.type_id == "document":
            if fx.n == 1:
                out.documents.append(_dec_doc(r))
            else:
                r.eat(123)
                _need64(r, 8, UInt64(4189037517098740002))
                r.pos += 8
                r.eat_here(91)
                if r.pos < len(r.data) and Int(r.data[r.pos]) != 93:
                    while True:
                        out.documents.append(_dec_doc(r))
                        if r.pos < len(r.data) and Int(r.data[r.pos]) == 93:
                            break
                        r.eat_here(44)
                r.eat_here(93)
                _close(r)
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                out.telemetries.append(_dec_tel(r))
            else:
                r.eat(123)
                _need64(r, 8, UInt64(4189037517098740002))
                r.pos += 8
                r.eat_here(91)
                if r.pos < len(r.data) and Int(r.data[r.pos]) != 93:
                    while True:
                        out.telemetries.append(_dec_tel(r))
                        if r.pos < len(r.data) and Int(r.data[r.pos]) == 93:
                            break
                        r.eat_here(44)
                r.eat_here(93)
                _close(r)
        elif fx.type_id == "strings":
            if fx.n == 1:
                out.strings.append(_dec_str(r))
            else:
                r.eat(123)
                _need64(r, 8, UInt64(4189037517098740002))
                r.pos += 8
                r.eat_here(91)
                if r.pos < len(r.data) and Int(r.data[r.pos]) != 93:
                    while True:
                        out.strings.append(_dec_str(r))
                        if r.pos < len(r.data) and Int(r.data[r.pos]) == 93:
                            break
                        r.eat_here(44)
                r.eat_here(93)
                _close(r)
        else:
            if fx.n == 1:
                out.events.append(_dec_ev(r))
            else:
                r.eat(123)
                _need64(r, 8, UInt64(4189037517098740002))
                r.pos += 8
                r.eat_here(91)
                if r.pos < len(r.data) and Int(r.data[r.pos]) != 93:
                    while True:
                        out.events.append(_dec_ev(r))
                        if r.pos < len(r.data) and Int(r.data[r.pos]) == 93:
                            break
                        r.eat_here(44)
                r.eat_here(93)
                _close(r)
        return out^

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
