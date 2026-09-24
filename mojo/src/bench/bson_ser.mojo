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
from bson_wire.reader import WireReader
from bson_wire.types import TY_ARRAY, TY_DOCUMENT, TY_DOUBLE, TY_INT32, TY_INT64, TY_STRING
from bson_wire.writer import WireWriter


def _write_message(mut w: WireWriter, m: Message):
    var at = w.begin_document()
    w.write_bool_field("f_bool", m.f_bool)
    w.write_i32_field("f_int32", m.f_int32)
    w.write_i64_field("f_int64", m.f_int64)
    w.write_f64_field("f_float64", m.f_float64)
    w.write_string_field("f_string", m.f_string)
    w.write_bool_field("f_bool_2", m.f_bool_2)
    w.write_i32_field("f_int32_2", m.f_int32_2)
    w.write_string_field("f_string_2", m.f_string_2)
    w.end_document(at)


def _write_item(mut w: WireWriter, item: DocumentItem):
    var at = w.begin_document()
    w.write_string_field("sku", item.sku)
    w.write_i32_field("qty", item.qty)
    w.write_i64_field("price_minor", item.price_minor)
    w.end_document(at)


def _write_document(mut w: WireWriter, doc: Document):
    var at = w.begin_document()
    w.write_string_field("id", doc.id)
    w.write_i32_field("status", doc.status)
    w.write_type_key(TY_DOCUMENT, "meta")
    var meta = w.begin_document()
    w.write_string_field("region", doc.meta.region)
    w.write_i32_field("version", doc.meta.version)
    w.end_document(meta)
    var arr = w.begin_array_field("items")
    var i = 0
    while i < len(doc.items):
        w.write_type_index(TY_DOCUMENT, i)
        _write_item(w, doc.items[i])
        i += 1
    w.end_document(arr)
    w.end_document(at)


def _write_telemetry(mut w: WireWriter, t: Telemetry):
    var at = w.begin_document()
    w.write_string_field("source", t.source)
    w.write_i64_field("ts", t.ts)
    var tags = w.begin_array_field("tags")
    var i = 0
    while i < len(t.tags):
        w.write_string_index(i, t.tags[i])
        i += 1
    w.end_document(tags)
    var values = w.begin_array_field("values")
    i = 0
    while i < len(t.values):
        w.write_f64_index(i, t.values[i])
        i += 1
    w.end_document(values)
    w.end_document(at)


def _write_strings(mut w: WireWriter, s: Strings):
    var at = w.begin_document()
    var arr = w.begin_array_field("items")
    var i = 0
    while i < len(s.items):
        w.write_string_index(i, s.items[i])
        i += 1
    w.end_document(arr)
    w.end_document(at)


def _write_attr(mut w: WireWriter, a: EventAttr):
    var at = w.begin_document()
    w.write_string_field("key", a.key)
    w.write_string_field("value", a.value)
    w.end_document(at)


def _write_event(mut w: WireWriter, ev: Event):
    var at = w.begin_document()
    w.write_string_field("event_id", ev.event_id)
    w.write_string_field("event_type", ev.event_type)
    w.write_i64_field("occurred_at", ev.occurred_at)
    w.write_string_field("producer", ev.producer)
    var arr = w.begin_array_field("attrs")
    var i = 0
    while i < len(ev.attrs):
        w.write_type_index(TY_DOCUMENT, i)
        _write_attr(w, ev.attrs[i])
        i += 1
    w.end_document(arr)
    w.end_document(at)


def _read_message[origin: ImmOrigin](mut r: WireReader[origin]) raises -> Message:
    var end = r.enter_document()
    var m = Message()
    while r.pos < end - 1:
        var typ = r.read_u8()
        var key = r.read_cstring()
        if key == "f_bool" and typ == 0x08:
            m.f_bool = r.read_u8() != 0
        elif key == "f_int32" and typ == TY_INT32:
            m.f_int32 = r.read_i32()
        elif key == "f_int64" and typ == TY_INT64:
            m.f_int64 = r.read_i64()
        elif key == "f_float64" and typ == TY_DOUBLE:
            m.f_float64 = r.read_f64()
        elif key == "f_string" and typ == TY_STRING:
            m.f_string = r.read_bson_string()
        elif key == "f_bool_2" and typ == 0x08:
            m.f_bool_2 = r.read_u8() != 0
        elif key == "f_int32_2" and typ == TY_INT32:
            m.f_int32_2 = r.read_i32()
        elif key == "f_string_2" and typ == TY_STRING:
            m.f_string_2 = r.read_bson_string()
        else:
            r.skip_value(typ)
    r.finish_document(end)
    return m^


def _read_item[origin: ImmOrigin](mut r: WireReader[origin]) raises -> DocumentItem:
    var end = r.enter_document()
    var item = DocumentItem()
    while r.pos < end - 1:
        var typ = r.read_u8()
        var key = r.read_cstring()
        if key == "sku" and typ == TY_STRING:
            item.sku = r.read_bson_string()
        elif key == "qty" and typ == TY_INT32:
            item.qty = r.read_i32()
        elif key == "price_minor" and typ == TY_INT64:
            item.price_minor = r.read_i64()
        else:
            r.skip_value(typ)
    r.finish_document(end)
    return item^


def _read_document[origin: ImmOrigin](mut r: WireReader[origin]) raises -> Document:
    var end = r.enter_document()
    var doc = Document()
    while r.pos < end - 1:
        var typ = r.read_u8()
        var key = r.read_cstring()
        if key == "id" and typ == TY_STRING:
            doc.id = r.read_bson_string()
        elif key == "status" and typ == TY_INT32:
            doc.status = r.read_i32()
        elif key == "meta" and typ == TY_DOCUMENT:
            var mend = r.enter_document()
            while r.pos < mend - 1:
                var mt = r.read_u8()
                var mk = r.read_cstring()
                if mk == "region" and mt == TY_STRING:
                    doc.meta.region = r.read_bson_string()
                elif mk == "version" and mt == TY_INT32:
                    doc.meta.version = r.read_i32()
                else:
                    r.skip_value(mt)
            r.finish_document(mend)
        elif key == "items" and typ == TY_ARRAY:
            var aend = r.enter_document()
            doc.items = List[DocumentItem]()
            while r.pos < aend - 1:
                var at = r.read_u8()
                _ = r.read_cstring()
                if at == TY_DOCUMENT:
                    var item = _read_item(r)
                    doc.items.append(item^)
                else:
                    r.skip_value(at)
            r.finish_document(aend)
        else:
            r.skip_value(typ)
    r.finish_document(end)
    return doc^


def _read_telemetry[origin: ImmOrigin](mut r: WireReader[origin]) raises -> Telemetry:
    var end = r.enter_document()
    var t = Telemetry()
    while r.pos < end - 1:
        var typ = r.read_u8()
        var key = r.read_cstring()
        if key == "source" and typ == TY_STRING:
            t.source = r.read_bson_string()
        elif key == "ts" and typ == TY_INT64:
            t.ts = r.read_i64()
        elif key == "tags" and typ == TY_ARRAY:
            var aend = r.enter_document()
            t.tags = List[String]()
            while r.pos < aend - 1:
                var at = r.read_u8()
                _ = r.read_cstring()
                if at == TY_STRING:
                    t.tags.append(r.read_bson_string())
                else:
                    r.skip_value(at)
            r.finish_document(aend)
        elif key == "values" and typ == TY_ARRAY:
            var aend = r.enter_document()
            t.values = List[Float64]()
            while r.pos < aend - 1:
                var at = r.read_u8()
                _ = r.read_cstring()
                if at == TY_DOUBLE:
                    t.values.append(r.read_f64())
                else:
                    r.skip_value(at)
            r.finish_document(aend)
        else:
            r.skip_value(typ)
    r.finish_document(end)
    return t^


def _read_strings[origin: ImmOrigin](mut r: WireReader[origin]) raises -> Strings:
    var end = r.enter_document()
    var s = Strings()
    while r.pos < end - 1:
        var typ = r.read_u8()
        var key = r.read_cstring()
        if key == "items" and typ == TY_ARRAY:
            var aend = r.enter_document()
            s.items = List[String]()
            while r.pos < aend - 1:
                var at = r.read_u8()
                _ = r.read_cstring()
                if at == TY_STRING:
                    s.items.append(r.read_bson_string())
                else:
                    r.skip_value(at)
            r.finish_document(aend)
        else:
            r.skip_value(typ)
    r.finish_document(end)
    return s^


def _read_attr[origin: ImmOrigin](mut r: WireReader[origin]) raises -> EventAttr:
    var end = r.enter_document()
    var a = EventAttr()
    while r.pos < end - 1:
        var typ = r.read_u8()
        var key = r.read_cstring()
        if key == "key" and typ == TY_STRING:
            a.key = r.read_bson_string()
        elif key == "value" and typ == TY_STRING:
            a.value = r.read_bson_string()
        else:
            r.skip_value(typ)
    r.finish_document(end)
    return a^


def _read_event[origin: ImmOrigin](mut r: WireReader[origin]) raises -> Event:
    var end = r.enter_document()
    var ev = Event()
    while r.pos < end - 1:
        var typ = r.read_u8()
        var key = r.read_cstring()
        if key == "event_id" and typ == TY_STRING:
            ev.event_id = r.read_bson_string()
        elif key == "event_type" and typ == TY_STRING:
            ev.event_type = r.read_bson_string()
        elif key == "occurred_at" and typ == TY_INT64:
            ev.occurred_at = r.read_i64()
        elif key == "producer" and typ == TY_STRING:
            ev.producer = r.read_bson_string()
        elif key == "attrs" and typ == TY_ARRAY:
            var aend = r.enter_document()
            ev.attrs = List[EventAttr]()
            while r.pos < aend - 1:
                var at = r.read_u8()
                _ = r.read_cstring()
                if at == TY_DOCUMENT:
                    var attr = _read_attr(r)
                    ev.attrs.append(attr^)
                else:
                    r.skip_value(at)
            r.finish_document(aend)
        else:
            r.skip_value(typ)
    r.finish_document(end)
    return ev^


struct BsonSer:
    var version: String

    def __init__(out self):
        self.version = "0.1.0"

    def name(self) -> String:
        return "mojo-bson"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var w = WireWriter(capacity=4096)
        if fx.type_id == "message":
            if fx.n == 1:
                _write_message(w, fx.messages[0])
            else:
                var at = w.begin_document()
                var arr = w.begin_array_field("items")
                var i = 0
                while i < len(fx.messages):
                    w.write_type_index(TY_DOCUMENT, i)
                    _write_message(w, fx.messages[i])
                    i += 1
                w.end_document(arr)
                w.end_document(at)
        elif fx.type_id == "document":
            if fx.n == 1:
                _write_document(w, fx.documents[0])
            else:
                var at = w.begin_document()
                var arr = w.begin_array_field("items")
                var i = 0
                while i < len(fx.documents):
                    w.write_type_index(TY_DOCUMENT, i)
                    _write_document(w, fx.documents[i])
                    i += 1
                w.end_document(arr)
                w.end_document(at)
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                _write_telemetry(w, fx.telemetries[0])
            else:
                var at = w.begin_document()
                var arr = w.begin_array_field("items")
                var i = 0
                while i < len(fx.telemetries):
                    w.write_type_index(TY_DOCUMENT, i)
                    _write_telemetry(w, fx.telemetries[i])
                    i += 1
                w.end_document(arr)
                w.end_document(at)
        elif fx.type_id == "strings":
            if fx.n == 1:
                _write_strings(w, fx.strings[0])
            else:
                var at = w.begin_document()
                var arr = w.begin_array_field("items")
                var i = 0
                while i < len(fx.strings):
                    w.write_type_index(TY_DOCUMENT, i)
                    _write_strings(w, fx.strings[i])
                    i += 1
                w.end_document(arr)
                w.end_document(at)
        else:
            if fx.n == 1:
                _write_event(w, fx.events[0])
            else:
                var at = w.begin_document()
                var arr = w.begin_array_field("items")
                var i = 0
                while i < len(fx.events):
                    w.write_type_index(TY_DOCUMENT, i)
                    _write_event(w, fx.events[i])
                    i += 1
                w.end_document(arr)
                w.end_document(at)
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
        var r = WireReader(Span(data))
        if fx.type_id == "message":
            out.messages = List[Message]()
            if fx.n == 1:
                var m = _read_message(r)
                out.messages.append(m^)
            else:
                _ = r.enter_document()
                _ = r.read_u8()
                _ = r.read_cstring()
                var aend = r.enter_document()
                while r.pos < aend - 1:
                    _ = r.read_u8()
                    _ = r.read_cstring()
                    var m = _read_message(r)
                    out.messages.append(m^)
                r.finish_document(aend)
        elif fx.type_id == "document":
            out.documents = List[Document]()
            if fx.n == 1:
                var d = _read_document(r)
                out.documents.append(d^)
            else:
                _ = r.enter_document()
                _ = r.read_u8()
                _ = r.read_cstring()
                var aend = r.enter_document()
                while r.pos < aend - 1:
                    _ = r.read_u8()
                    _ = r.read_cstring()
                    var d = _read_document(r)
                    out.documents.append(d^)
                r.finish_document(aend)
        elif fx.type_id == "telemetry":
            out.telemetries = List[Telemetry]()
            if fx.n == 1:
                var t = _read_telemetry(r)
                out.telemetries.append(t^)
            else:
                _ = r.enter_document()
                _ = r.read_u8()
                _ = r.read_cstring()
                var aend = r.enter_document()
                while r.pos < aend - 1:
                    _ = r.read_u8()
                    _ = r.read_cstring()
                    var t = _read_telemetry(r)
                    out.telemetries.append(t^)
                r.finish_document(aend)
        elif fx.type_id == "strings":
            out.strings = List[Strings]()
            if fx.n == 1:
                var s = _read_strings(r)
                out.strings.append(s^)
            else:
                _ = r.enter_document()
                _ = r.read_u8()
                _ = r.read_cstring()
                var aend = r.enter_document()
                while r.pos < aend - 1:
                    _ = r.read_u8()
                    _ = r.read_cstring()
                    var s = _read_strings(r)
                    out.strings.append(s^)
                r.finish_document(aend)
        else:
            out.events = List[Event]()
            if fx.n == 1:
                var ev = _read_event(r)
                out.events.append(ev^)
            else:
                _ = r.enter_document()
                _ = r.read_u8()
                _ = r.read_cstring()
                var aend = r.enter_document()
                while r.pos < aend - 1:
                    _ = r.read_u8()
                    _ = r.read_cstring()
                    var ev = _read_event(r)
                    out.events.append(ev^)
                r.finish_document(aend)
        return out^

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
