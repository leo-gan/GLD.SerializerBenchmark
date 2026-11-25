"""mojo-ion (gld-ion) binary cursor on suite types."""

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
from ion_wire.direct import IonBin, IonCur


def _sid(got: Int, want: Int) raises:
    if got != want:
        raise Error("ion field")


def _write_message(mut bin: IonBin, m: Message) raises:
    var st = bin.open_container()
    bin.field(10)
    bin.write_bool(m.f_bool)
    bin.field(11)
    bin.write_i64(Int64(m.f_int32))
    bin.field(12)
    bin.write_i64(m.f_int64)
    bin.field(13)
    bin.write_f64(m.f_float64)
    bin.field(14)
    bin.write_str(m.f_string)
    bin.field(15)
    bin.write_bool(m.f_bool_2)
    bin.field(16)
    bin.write_i64(Int64(m.f_int32_2))
    bin.field(17)
    bin.write_str(m.f_string_2)
    bin.close_container(st, 13)


def _write_item(mut bin: IonBin, item: DocumentItem) raises:
    var st = bin.open_container()
    bin.field(16)
    bin.write_str(item.sku)
    bin.field(17)
    bin.write_i64(Int64(item.qty))
    bin.field(18)
    bin.write_i64(item.price_minor)
    bin.close_container(st, 13)


def _write_document(mut bin: IonBin, d: Document) raises:
    var st = bin.open_container()
    bin.field(10)
    bin.write_str(d.id)
    bin.field(11)
    bin.write_i64(Int64(d.status))
    bin.field(12)
    var meta = bin.open_container()
    bin.field(13)
    bin.write_str(d.meta.region)
    bin.field(14)
    bin.write_i64(Int64(d.meta.version))
    bin.close_container(meta, 13)
    bin.field(15)
    var arr = bin.open_container()
    var i = 0
    while i < len(d.items):
        _write_item(bin, d.items[i])
        i += 1
    bin.close_container(arr, 11)
    bin.close_container(st, 13)


def _write_telemetry(mut bin: IonBin, t: Telemetry) raises:
    var st = bin.open_container()
    bin.field(10)
    bin.write_str(t.source)
    bin.field(11)
    bin.write_i64(t.ts)
    bin.field(12)
    var tags = bin.open_container()
    var i = 0
    while i < len(t.tags):
        bin.write_str(t.tags[i])
        i += 1
    bin.close_container(tags, 11)
    bin.field(13)
    var values = bin.open_container()
    i = 0
    while i < len(t.values):
        bin.write_f64(t.values[i])
        i += 1
    bin.close_container(values, 11)
    bin.close_container(st, 13)


def _write_strings(mut bin: IonBin, s: Strings) raises:
    var st = bin.open_container()
    bin.field(10)
    var arr = bin.open_container()
    var i = 0
    while i < len(s.items):
        bin.write_str(s.items[i])
        i += 1
    bin.close_container(arr, 11)
    bin.close_container(st, 13)


def _write_attr(mut bin: IonBin, a: EventAttr) raises:
    var st = bin.open_container()
    bin.field(15)
    bin.write_str(a.key)
    bin.field(16)
    bin.write_str(a.value)
    bin.close_container(st, 13)


def _write_event(mut bin: IonBin, ev: Event) raises:
    var st = bin.open_container()
    bin.field(10)
    bin.write_str(ev.event_id)
    bin.field(11)
    bin.write_str(ev.event_type)
    bin.field(12)
    bin.write_i64(ev.occurred_at)
    bin.field(13)
    bin.write_str(ev.producer)
    bin.field(14)
    var arr = bin.open_container()
    var i = 0
    while i < len(ev.attrs):
        _write_attr(bin, ev.attrs[i])
        i += 1
    bin.close_container(arr, 11)
    bin.close_container(st, 13)


def _names_message(mut bin: IonBin, batch: Bool):
    _ = bin.intern_lit("f_bool")
    _ = bin.intern_lit("f_int32")
    _ = bin.intern_lit("f_int64")
    _ = bin.intern_lit("f_float64")
    _ = bin.intern_lit("f_string")
    _ = bin.intern_lit("f_bool_2")
    _ = bin.intern_lit("f_int32_2")
    _ = bin.intern_lit("f_string_2")
    if batch:
        _ = bin.intern_lit("items")


def _names_document(mut bin: IonBin):
    _ = bin.intern_lit("id")
    _ = bin.intern_lit("status")
    _ = bin.intern_lit("meta")
    _ = bin.intern_lit("region")
    _ = bin.intern_lit("version")
    _ = bin.intern_lit("items")
    _ = bin.intern_lit("sku")
    _ = bin.intern_lit("qty")
    _ = bin.intern_lit("price_minor")


def _names_telemetry(mut bin: IonBin, batch: Bool):
    _ = bin.intern_lit("source")
    _ = bin.intern_lit("ts")
    _ = bin.intern_lit("tags")
    _ = bin.intern_lit("values")
    if batch:
        _ = bin.intern_lit("items")


def _names_strings(mut bin: IonBin, batch: Bool):
    _ = bin.intern_lit("items")
    _ = batch


def _names_event(mut bin: IonBin, batch: Bool):
    _ = bin.intern_lit("event_id")
    _ = bin.intern_lit("event_type")
    _ = bin.intern_lit("occurred_at")
    _ = bin.intern_lit("producer")
    _ = bin.intern_lit("attrs")
    _ = bin.intern_lit("key")
    _ = bin.intern_lit("value")
    if batch:
        _ = bin.intern_lit("items")


def _read_message[o: ImmOrigin](mut c: IonCur[o]) raises -> Message:
    var end = c.enter_struct()
    var m = Message()
    _sid(c.field_sid(), 10)
    m.f_bool = c.read_bool()
    _sid(c.field_sid(), 11)
    m.f_int32 = Int32(c.read_i64())
    _sid(c.field_sid(), 12)
    m.f_int64 = c.read_i64()
    _sid(c.field_sid(), 13)
    m.f_float64 = c.read_f64()
    _sid(c.field_sid(), 14)
    m.f_string = c.read_string()
    _sid(c.field_sid(), 15)
    m.f_bool_2 = c.read_bool()
    _sid(c.field_sid(), 16)
    m.f_int32_2 = Int32(c.read_i64())
    _sid(c.field_sid(), 17)
    m.f_string_2 = c.read_string()
    if c.i != end:
        raise Error("ion message")
    return m^


def _read_item[o: ImmOrigin](mut c: IonCur[o]) raises -> DocumentItem:
    var end = c.enter_struct()
    var item = DocumentItem()
    _sid(c.field_sid(), 16)
    item.sku = c.read_string()
    _sid(c.field_sid(), 17)
    item.qty = Int32(c.read_i64())
    _sid(c.field_sid(), 18)
    item.price_minor = c.read_i64()
    if c.i != end:
        raise Error("ion item")
    return item^


def _read_document[o: ImmOrigin](mut c: IonCur[o]) raises -> Document:
    var end = c.enter_struct()
    var d = Document()
    _sid(c.field_sid(), 10)
    d.id = c.read_string()
    _sid(c.field_sid(), 11)
    d.status = Int32(c.read_i64())
    _sid(c.field_sid(), 12)
    var mend = c.enter_struct()
    _sid(c.field_sid(), 13)
    d.meta.region = c.read_string()
    _sid(c.field_sid(), 14)
    d.meta.version = Int32(c.read_i64())
    if c.i != mend:
        raise Error("ion meta")
    _sid(c.field_sid(), 15)
    var lend = c.enter_list()
    while c.i < lend:
        var item = _read_item(c)
        d.items.append(item^)
    if c.i != end:
        raise Error("ion document")
    return d^


def _read_telemetry[o: ImmOrigin](mut c: IonCur[o]) raises -> Telemetry:
    var end = c.enter_struct()
    var t = Telemetry()
    _sid(c.field_sid(), 10)
    t.source = c.read_string()
    _sid(c.field_sid(), 11)
    t.ts = c.read_i64()
    _sid(c.field_sid(), 12)
    var tags = c.enter_list()
    while c.i < tags:
        t.tags.append(c.read_string())
    _sid(c.field_sid(), 13)
    var values = c.enter_list()
    while c.i < values:
        t.values.append(c.read_f64())
    if c.i != end:
        raise Error("ion telemetry")
    return t^


def _read_strings[o: ImmOrigin](mut c: IonCur[o]) raises -> Strings:
    var end = c.enter_struct()
    var s = Strings()
    _sid(c.field_sid(), 10)
    var lend = c.enter_list()
    while c.i < lend:
        s.items.append(c.read_string())
    if c.i != end:
        raise Error("ion strings")
    return s^


def _read_attr[o: ImmOrigin](mut c: IonCur[o]) raises -> EventAttr:
    var end = c.enter_struct()
    var a = EventAttr()
    _sid(c.field_sid(), 15)
    a.key = c.read_string()
    _sid(c.field_sid(), 16)
    a.value = c.read_string()
    if c.i != end:
        raise Error("ion attr")
    return a^


def _read_event[o: ImmOrigin](mut c: IonCur[o]) raises -> Event:
    var end = c.enter_struct()
    var ev = Event()
    _sid(c.field_sid(), 10)
    ev.event_id = c.read_string()
    _sid(c.field_sid(), 11)
    ev.event_type = c.read_string()
    _sid(c.field_sid(), 12)
    ev.occurred_at = c.read_i64()
    _sid(c.field_sid(), 13)
    ev.producer = c.read_string()
    _sid(c.field_sid(), 14)
    var lend = c.enter_list()
    while c.i < lend:
        var attr = _read_attr(c)
        ev.attrs.append(attr^)
    if c.i != end:
        raise Error("ion event")
    return ev^


def _read_list[o: ImmOrigin](mut c: IonCur[o], items_sid: Int) raises -> Int:
    var end = c.enter_struct()
    _sid(c.field_sid(), items_sid)
    _ = end
    return c.enter_list()


struct IonSer:
    var version: String

    def __init__(out self):
        self.version = "0.2.0"

    def name(self) -> String:
        return "mojo-ion"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var cap = 256
        if fx.n > 1:
            cap = 4096 + fx.n * 64
        var bin = IonBin(capacity=cap)
        var batch = fx.n != 1
        if fx.type_id == "message":
            _names_message(bin, batch)
            bin.begin()
            if not batch:
                _write_message(bin, fx.messages[0])
            else:
                var root = bin.open_container()
                bin.field(18)
                var arr = bin.open_container()
                var i = 0
                while i < len(fx.messages):
                    _write_message(bin, fx.messages[i])
                    i += 1
                bin.close_container(arr, 11)
                bin.close_container(root, 13)
        elif fx.type_id == "document":
            _names_document(bin)
            bin.begin()
            if not batch:
                _write_document(bin, fx.documents[0])
            else:
                var root = bin.open_container()
                bin.field(15)
                var arr = bin.open_container()
                var i = 0
                while i < len(fx.documents):
                    _write_document(bin, fx.documents[i])
                    i += 1
                bin.close_container(arr, 11)
                bin.close_container(root, 13)
        elif fx.type_id == "telemetry":
            _names_telemetry(bin, batch)
            bin.begin()
            if not batch:
                _write_telemetry(bin, fx.telemetries[0])
            else:
                var root = bin.open_container()
                bin.field(14)
                var arr = bin.open_container()
                var i = 0
                while i < len(fx.telemetries):
                    _write_telemetry(bin, fx.telemetries[i])
                    i += 1
                bin.close_container(arr, 11)
                bin.close_container(root, 13)
        elif fx.type_id == "strings":
            _names_strings(bin, batch)
            bin.begin()
            if not batch:
                _write_strings(bin, fx.strings[0])
            else:
                var root = bin.open_container()
                bin.field(10)
                var arr = bin.open_container()
                var i = 0
                while i < len(fx.strings):
                    _write_strings(bin, fx.strings[i])
                    i += 1
                bin.close_container(arr, 11)
                bin.close_container(root, 13)
        else:
            _names_event(bin, batch)
            bin.begin()
            if not batch:
                _write_event(bin, fx.events[0])
            else:
                var root = bin.open_container()
                bin.field(17)
                var arr = bin.open_container()
                var i = 0
                while i < len(fx.events):
                    _write_event(bin, fx.events[i])
                    i += 1
                bin.close_container(arr, 11)
                bin.close_container(root, 13)
        return bin^.take()

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var cur = IonCur(Span(data))
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
        if fx.type_id == "message":
            if fx.n == 1:
                var m = _read_message(cur)
                out.messages.append(m^)
            else:
                var lend = _read_list(cur, 18)
                while cur.i < lend:
                    var m = _read_message(cur)
                    out.messages.append(m^)
        elif fx.type_id == "document":
            if fx.n == 1:
                var d = _read_document(cur)
                out.documents.append(d^)
            else:
                var lend = _read_list(cur, 15)
                while cur.i < lend:
                    var d = _read_document(cur)
                    out.documents.append(d^)
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                var t = _read_telemetry(cur)
                out.telemetries.append(t^)
            else:
                var lend = _read_list(cur, 14)
                while cur.i < lend:
                    var t = _read_telemetry(cur)
                    out.telemetries.append(t^)
        elif fx.type_id == "strings":
            if fx.n == 1:
                var s = _read_strings(cur)
                out.strings.append(s^)
            else:
                var lend = _read_list(cur, 10)
                while cur.i < lend:
                    var s = _read_strings(cur)
                    out.strings.append(s^)
        else:
            if fx.n == 1:
                var ev = _read_event(cur)
                out.events.append(ev^)
            else:
                var lend = _read_list(cur, 17)
                while cur.i < lend:
                    var ev = _read_event(cur)
                    out.events.append(ev^)
        return out^

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
