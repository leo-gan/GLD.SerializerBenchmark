"""mojo-json (gld-json) generated-path style encode/decode on suite types."""

from std.collections import List
from gldjson import (
    DecodeError,
    EncodeOptions,
    WireReader,
    WireWriter,
    read_bool,
    read_float,
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


def _dec_msg[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Message:
    var m = Message()
    r.eat(123)
    if r.try_eat_bytes("\"f_bool\":".as_bytes()):
        m.f_bool = read_bool(r)
        if r.try_eat_bytes(",\"f_int32\":".as_bytes()):
            m.f_int32 = Int32(r.read_number().i)
            if r.try_eat_bytes(",\"f_int64\":".as_bytes()):
                m.f_int64 = r.read_number().i
                if r.try_eat_bytes(",\"f_float64\":".as_bytes()):
                    m.f_float64 = read_float(r)
                    if r.try_eat_bytes(",\"f_string\":".as_bytes()):
                        m.f_string = r.read_string()
                        if r.try_eat_bytes(",\"f_bool_2\":".as_bytes()):
                            m.f_bool_2 = read_bool(r)
                            if r.try_eat_bytes(",\"f_int32_2\":".as_bytes()):
                                m.f_int32_2 = Int32(r.read_number().i)
                                if r.try_eat_bytes(",\"f_string_2\":".as_bytes()):
                                    m.f_string_2 = r.read_string()
                                    if r.try_eat_bytes("}".as_bytes()):
                                        return m^
    raise DecodeError(DecodeError.KIND_SYNTAX, r.position())


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
    if not r.try_eat_bytes("\"id\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    d.id = r.read_string()
    if not r.try_eat_bytes(",\"status\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    d.status = Int32(r.read_number().i)
    if not r.try_eat_bytes(",\"meta\":{\"region\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    d.meta.region = r.read_string()
    if not r.try_eat_bytes(",\"version\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    d.meta.version = Int32(r.read_number().i)
    if not r.try_eat_bytes("},\"items\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    r.eat(91)
    if r.peek() != 93:
        while True:
            var it = DocumentItem()
            r.eat(123)
            if not r.try_eat_bytes("\"sku\":".as_bytes()):
                raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
            it.sku = r.read_string()
            if not r.try_eat_bytes(",\"qty\":".as_bytes()):
                raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
            it.qty = Int32(r.read_number().i)
            if not r.try_eat_bytes(",\"price_minor\":".as_bytes()):
                raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
            it.price_minor = r.read_number().i
            r.eat(125)
            d.items.append(it^)
            var s = r.peek()
            if s == 93:
                break
            r.eat(44)
    r.eat(93)
    r.eat(125)
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
    if not r.try_eat_bytes("\"source\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    t.source = r.read_string()
    if not r.try_eat_bytes(",\"ts\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    t.ts = r.read_number().i
    if not r.try_eat_bytes(",\"tags\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    t.tags = read_string_list(r)
    if not r.try_eat_bytes(",\"values\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    t.values = read_float_list(r)
    r.eat(125)
    return t^


def _enc_str(s: Strings, mut w: WireWriter):
    w.write_byte(Byte(123))
    w.write_bytes("\"items\":".as_bytes())
    write_string_list(w, s.items, EncodeOptions.compact)
    w.write_byte(Byte(125))


def _dec_str[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Strings:
    var s = Strings()
    r.eat(123)
    if not r.try_eat_bytes("\"items\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    s.items = read_string_list(r)
    r.eat(125)
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
    if not r.try_eat_bytes("\"event_id\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    e.event_id = r.read_string()
    if not r.try_eat_bytes(",\"event_type\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    e.event_type = r.read_string()
    if not r.try_eat_bytes(",\"occurred_at\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    e.occurred_at = r.read_number().i
    if not r.try_eat_bytes(",\"producer\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    e.producer = r.read_string()
    if not r.try_eat_bytes(",\"attrs\":".as_bytes()):
        raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
    r.eat(91)
    if r.peek() != 93:
        while True:
            var a = EventAttr()
            r.eat(123)
            if not r.try_eat_bytes("\"key\":".as_bytes()):
                raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
            a.key = r.read_string()
            if not r.try_eat_bytes(",\"value\":".as_bytes()):
                raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
            a.value = r.read_string()
            r.eat(125)
            e.attrs.append(a^)
            var s = r.peek()
            if s == 93:
                break
            r.eat(44)
    r.eat(93)
    r.eat(125)
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
        var w = WireWriter(capacity=cap, exact=False)
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
            fx.messages.copy(),
            fx.documents.copy(),
            fx.telemetries.copy(),
            fx.strings.copy(),
            fx.events.copy(),
        )
        var r = WireReader(data)
        if fx.type_id == "message":
            if fx.n == 1:
                out.messages = List[Message]()
                out.messages.append(_dec_msg(r))
            else:
                r.eat(123)
                if not r.try_eat_bytes("\"items\":".as_bytes()):
                    raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
                r.eat(91)
                out.messages = List[Message]()
                if r.peek() != 93:
                    while True:
                        out.messages.append(_dec_msg(r))
                        var s = r.peek()
                        if s == 93:
                            break
                        r.eat(44)
                r.eat(93)
                r.eat(125)
        elif fx.type_id == "document":
            if fx.n == 1:
                out.documents = List[Document]()
                out.documents.append(_dec_doc(r))
            else:
                r.eat(123)
                if not r.try_eat_bytes("\"items\":".as_bytes()):
                    raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
                r.eat(91)
                out.documents = List[Document]()
                if r.peek() != 93:
                    while True:
                        out.documents.append(_dec_doc(r))
                        var s = r.peek()
                        if s == 93:
                            break
                        r.eat(44)
                r.eat(93)
                r.eat(125)
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                out.telemetries = List[Telemetry]()
                out.telemetries.append(_dec_tel(r))
            else:
                r.eat(123)
                if not r.try_eat_bytes("\"items\":".as_bytes()):
                    raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
                r.eat(91)
                out.telemetries = List[Telemetry]()
                if r.peek() != 93:
                    while True:
                        out.telemetries.append(_dec_tel(r))
                        var s = r.peek()
                        if s == 93:
                            break
                        r.eat(44)
                r.eat(93)
                r.eat(125)
        elif fx.type_id == "strings":
            if fx.n == 1:
                out.strings = List[Strings]()
                out.strings.append(_dec_str(r))
            else:
                r.eat(123)
                if not r.try_eat_bytes("\"items\":".as_bytes()):
                    raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
                r.eat(91)
                out.strings = List[Strings]()
                if r.peek() != 93:
                    while True:
                        out.strings.append(_dec_str(r))
                        var s = r.peek()
                        if s == 93:
                            break
                        r.eat(44)
                r.eat(93)
                r.eat(125)
        else:
            if fx.n == 1:
                out.events = List[Event]()
                out.events.append(_dec_ev(r))
            else:
                r.eat(123)
                if not r.try_eat_bytes("\"items\":".as_bytes()):
                    raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
                r.eat(91)
                out.events = List[Event]()
                if r.peek() != 93:
                    while True:
                        out.events.append(_dec_ev(r))
                        var s = r.peek()
                        if s == 93:
                            break
                        r.eat(44)
                r.eat(93)
                r.eat(125)
        return out^

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
