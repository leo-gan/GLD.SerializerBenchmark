"""mojo-smile (gld-smile) cursor on suite types."""

from std.collections import List

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
from smile_wire.direct import SmileBin, SmileCur


def _key[o: ImmOrigin](mut c: SmileCur[o], name: StaticString) raises:
    var id = c.next_id()
    if not c.name_is(id, name):
        raise Error("smile field")


def _end_obj[o: ImmOrigin](mut c: SmileCur[o]) raises:
    if c.next_id() != -1:
        raise Error("smile end")


def _write_message(mut bin: SmileBin, m: Message):
    bin.start_object()
    bin.key_lit("f_bool")
    bin.write_bool(m.f_bool)
    bin.key_lit("f_int32")
    bin.write_i64(Int64(m.f_int32))
    bin.key_lit("f_int64")
    bin.write_i64(m.f_int64)
    bin.key_lit("f_float64")
    bin.write_f64(m.f_float64)
    bin.key_lit("f_string")
    bin.write_str(m.f_string)
    bin.key_lit("f_bool_2")
    bin.write_bool(m.f_bool_2)
    bin.key_lit("f_int32_2")
    bin.write_i64(Int64(m.f_int32_2))
    bin.key_lit("f_string_2")
    bin.write_str(m.f_string_2)
    bin.end_object()


def _write_item(mut bin: SmileBin, item: DocumentItem):
    bin.start_object()
    bin.key_lit("sku")
    bin.write_str(item.sku)
    bin.key_lit("qty")
    bin.write_i64(Int64(item.qty))
    bin.key_lit("price_minor")
    bin.write_i64(item.price_minor)
    bin.end_object()


def _write_document(mut bin: SmileBin, d: Document):
    bin.start_object()
    bin.key_lit("id")
    bin.write_str(d.id)
    bin.key_lit("status")
    bin.write_i64(Int64(d.status))
    bin.key_lit("meta")
    bin.start_object()
    bin.key_lit("region")
    bin.write_str(d.meta.region)
    bin.key_lit("version")
    bin.write_i64(Int64(d.meta.version))
    bin.end_object()
    bin.key_lit("items")
    bin.start_array()
    var i = 0
    while i < len(d.items):
        _write_item(bin, d.items[i])
        i += 1
    bin.end_array()
    bin.end_object()


def _write_telemetry(mut bin: SmileBin, t: Telemetry):
    bin.start_object()
    bin.key_lit("source")
    bin.write_str(t.source)
    bin.key_lit("ts")
    bin.write_i64(t.ts)
    bin.key_lit("tags")
    bin.start_array()
    var i = 0
    while i < len(t.tags):
        bin.write_str(t.tags[i])
        i += 1
    bin.end_array()
    bin.key_lit("values")
    bin.start_array()
    i = 0
    while i < len(t.values):
        bin.write_f64(t.values[i])
        i += 1
    bin.end_array()
    bin.end_object()


def _write_strings(mut bin: SmileBin, s: Strings):
    bin.start_object()
    bin.key_lit("items")
    bin.start_array()
    var i = 0
    while i < len(s.items):
        bin.write_str(s.items[i])
        i += 1
    bin.end_array()
    bin.end_object()


def _write_attr(mut bin: SmileBin, a: EventAttr):
    bin.start_object()
    bin.key_lit("key")
    bin.write_str(a.key)
    bin.key_lit("value")
    bin.write_str(a.value)
    bin.end_object()


def _write_event(mut bin: SmileBin, ev: Event):
    bin.start_object()
    bin.key_lit("event_id")
    bin.write_str(ev.event_id)
    bin.key_lit("event_type")
    bin.write_str(ev.event_type)
    bin.key_lit("occurred_at")
    bin.write_i64(ev.occurred_at)
    bin.key_lit("producer")
    bin.write_str(ev.producer)
    bin.key_lit("attrs")
    bin.start_array()
    var i = 0
    while i < len(ev.attrs):
        _write_attr(bin, ev.attrs[i])
        i += 1
    bin.end_array()
    bin.end_object()


def _read_message[o: ImmOrigin](mut c: SmileCur[o]) raises -> Message:
    c.start_object()
    var m = Message()
    _key(c, "f_bool")
    m.f_bool = c.read_bool()
    _key(c, "f_int32")
    m.f_int32 = Int32(c.read_i64())
    _key(c, "f_int64")
    m.f_int64 = c.read_i64()
    _key(c, "f_float64")
    m.f_float64 = c.read_f64()
    _key(c, "f_string")
    m.f_string = c.read_string()
    _key(c, "f_bool_2")
    m.f_bool_2 = c.read_bool()
    _key(c, "f_int32_2")
    m.f_int32_2 = Int32(c.read_i64())
    _key(c, "f_string_2")
    m.f_string_2 = c.read_string()
    _end_obj(c)
    return m^


def _read_item[o: ImmOrigin](mut c: SmileCur[o]) raises -> DocumentItem:
    c.start_object()
    var item = DocumentItem()
    _key(c, "sku")
    item.sku = c.read_string()
    _key(c, "qty")
    item.qty = Int32(c.read_i64())
    _key(c, "price_minor")
    item.price_minor = c.read_i64()
    _end_obj(c)
    return item^


def _read_document[o: ImmOrigin](mut c: SmileCur[o]) raises -> Document:
    c.start_object()
    var d = Document()
    _key(c, "id")
    d.id = c.read_string()
    _key(c, "status")
    d.status = Int32(c.read_i64())
    _key(c, "meta")
    c.start_object()
    _key(c, "region")
    d.meta.region = c.read_string()
    _key(c, "version")
    d.meta.version = Int32(c.read_i64())
    _end_obj(c)
    _key(c, "items")
    c.start_array()
    while not c.at_array_end():
        var item = _read_item(c)
        d.items.append(item^)
    _end_obj(c)
    return d^


def _read_telemetry[o: ImmOrigin](mut c: SmileCur[o]) raises -> Telemetry:
    c.start_object()
    var t = Telemetry()
    _key(c, "source")
    t.source = c.read_string()
    _key(c, "ts")
    t.ts = c.read_i64()
    _key(c, "tags")
    c.start_array()
    while not c.at_array_end():
        t.tags.append(c.read_string())
    _key(c, "values")
    c.start_array()
    while not c.at_array_end():
        t.values.append(c.read_f64())
    _end_obj(c)
    return t^


def _read_strings[o: ImmOrigin](mut c: SmileCur[o]) raises -> Strings:
    c.start_object()
    var s = Strings()
    _key(c, "items")
    c.start_array()
    while not c.at_array_end():
        s.items.append(c.read_string())
    _end_obj(c)
    return s^


def _read_attr[o: ImmOrigin](mut c: SmileCur[o]) raises -> EventAttr:
    c.start_object()
    var a = EventAttr()
    _key(c, "key")
    a.key = c.read_string()
    _key(c, "value")
    a.value = c.read_string()
    _end_obj(c)
    return a^


def _read_event[o: ImmOrigin](mut c: SmileCur[o]) raises -> Event:
    c.start_object()
    var ev = Event()
    _key(c, "event_id")
    ev.event_id = c.read_string()
    _key(c, "event_type")
    ev.event_type = c.read_string()
    _key(c, "occurred_at")
    ev.occurred_at = c.read_i64()
    _key(c, "producer")
    ev.producer = c.read_string()
    _key(c, "attrs")
    c.start_array()
    while not c.at_array_end():
        var attr = _read_attr(c)
        ev.attrs.append(attr^)
    _end_obj(c)
    return ev^


struct SmileSer:
    var version: String

    def __init__(out self):
        self.version = "0.2.0"

    def name(self) -> String:
        return "mojo-smile"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var cap = 256
        if fx.n > 1:
            cap = 4096 + fx.n * 64
        var bin = SmileBin(capacity=cap)
        bin.begin()
        if fx.type_id == "message":
            if fx.n == 1:
                _write_message(bin, fx.messages[0])
            else:
                bin.start_object()
                bin.key_lit("items")
                bin.start_array()
                var i = 0
                while i < len(fx.messages):
                    _write_message(bin, fx.messages[i])
                    i += 1
                bin.end_array()
                bin.end_object()
        elif fx.type_id == "document":
            if fx.n == 1:
                _write_document(bin, fx.documents[0])
            else:
                bin.start_object()
                bin.key_lit("items")
                bin.start_array()
                var i = 0
                while i < len(fx.documents):
                    _write_document(bin, fx.documents[i])
                    i += 1
                bin.end_array()
                bin.end_object()
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                _write_telemetry(bin, fx.telemetries[0])
            else:
                bin.start_object()
                bin.key_lit("items")
                bin.start_array()
                var i = 0
                while i < len(fx.telemetries):
                    _write_telemetry(bin, fx.telemetries[i])
                    i += 1
                bin.end_array()
                bin.end_object()
        elif fx.type_id == "strings":
            if fx.n == 1:
                _write_strings(bin, fx.strings[0])
            else:
                bin.start_object()
                bin.key_lit("items")
                bin.start_array()
                var i = 0
                while i < len(fx.strings):
                    _write_strings(bin, fx.strings[i])
                    i += 1
                bin.end_array()
                bin.end_object()
        else:
            if fx.n == 1:
                _write_event(bin, fx.events[0])
            else:
                bin.start_object()
                bin.key_lit("items")
                bin.start_array()
                var i = 0
                while i < len(fx.events):
                    _write_event(bin, fx.events[i])
                    i += 1
                bin.end_array()
                bin.end_object()
        return bin^.take()

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var cur = SmileCur(Span(data))
        cur.open()
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
        if fx.n == 1:
            if fx.type_id == "message":
                var m = _read_message(cur)
                out.messages.append(m^)
            elif fx.type_id == "document":
                var d = _read_document(cur)
                out.documents.append(d^)
            elif fx.type_id == "telemetry":
                var t = _read_telemetry(cur)
                out.telemetries.append(t^)
            elif fx.type_id == "strings":
                var s = _read_strings(cur)
                out.strings.append(s^)
            else:
                var ev = _read_event(cur)
                out.events.append(ev^)
            return out^
        cur.start_object()
        _key(cur, "items")
        cur.start_array()
        while not cur.at_array_end():
            if fx.type_id == "message":
                var m = _read_message(cur)
                out.messages.append(m^)
            elif fx.type_id == "document":
                var d = _read_document(cur)
                out.documents.append(d^)
            elif fx.type_id == "telemetry":
                var t = _read_telemetry(cur)
                out.telemetries.append(t^)
            elif fx.type_id == "strings":
                var s = _read_strings(cur)
                out.strings.append(s^)
            else:
                var ev = _read_event(cur)
                out.events.append(ev^)
        _end_obj(cur)
        return out^

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
