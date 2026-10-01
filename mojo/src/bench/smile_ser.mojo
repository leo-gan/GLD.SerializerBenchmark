"""mojo-smile (gld-smile) document encode/decode on suite types."""

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
from smile import decode_bytes, encode_doc
from smile_runtime.doc import (
    K_ARRAY,
    K_BOOL,
    K_F64,
    K_I32,
    K_I64,
    K_OBJECT,
    K_STRING,
    SmileDoc,
)
from smile_runtime.options import EncodeOptions


def _need(doc: SmileDoc, id: Int, kind: Int) raises:
    if id < 0 or doc.nodes[id].kind != kind:
        raise Error("smile type")


def _field(doc: SmileDoc, obj: Int, name: String) raises -> Int:
    _need(doc, obj, K_OBJECT)
    var n = doc.nodes[obj]
    var i = 0
    while i < n.nchild:
        var e = doc.edges[n.child + i]
        if doc.texts[e.key] == name:
            return e.val
        i += 1
    raise Error("smile field " + name)


def _sstr(doc: SmileDoc, id: Int) raises -> String:
    _need(doc, id, K_STRING)
    # `text_at` indexes the text table. The string node stores that index in `a`.
    return doc.texts[doc.nodes[id].a]


def _sbool(doc: SmileDoc, id: Int) raises -> Bool:
    _need(doc, id, K_BOOL)
    return doc.nodes[id].a != 0


def _si32(doc: SmileDoc, id: Int) raises -> Int32:
    _need(doc, id, K_I32)
    return Int32(doc.nodes[id].a)


def _si64(doc: SmileDoc, id: Int) raises -> Int64:
    _need(doc, id, K_I64)
    return Int64(doc.nodes[id].a)


def _sf64(doc: SmileDoc, id: Int) raises -> Float64:
    _need(doc, id, K_F64)
    return Float64(from_bits=doc.f64s[doc.nodes[id].a])


def _elems(doc: SmileDoc, id: Int) raises -> List[Int]:
    _need(doc, id, K_ARRAY)
    var out = List[Int]()
    var n = doc.nodes[id]
    var i = 0
    while i < n.nchild:
        out.append(doc.edges[n.child + i].val)
        i += 1
    return out^


def _key(mut doc: SmileDoc, name: String) -> Int:
    return doc._text(String(name))


def _put_str(mut doc: SmileDoc, text: String) -> Int:
    return doc.add_string(String(text))


def _ffield(mut doc: SmileDoc, obj: Int, name: String, val: Int):
    # Name and value must be built before this call. One expression that
    # mutates the document twice can store the key text as the value.
    var key = _key(doc, name)
    doc.add_field(obj, key, val)


def _write_message(mut doc: SmileDoc, m: Message) -> Int:
    var obj = doc.start_object()
    var b0 = doc.add_bool(m.f_bool)
    _ffield(doc, obj, "f_bool", b0)
    var i0 = doc.add_i32(Int(m.f_int32))
    _ffield(doc, obj, "f_int32", i0)
    var i1 = doc.add_i64(Int(m.f_int64))
    _ffield(doc, obj, "f_int64", i1)
    var f0 = doc.add_f64(m.f_float64)
    _ffield(doc, obj, "f_float64", f0)
    var s0 = _put_str(doc, m.f_string)
    _ffield(doc, obj, "f_string", s0)
    var b1 = doc.add_bool(m.f_bool_2)
    _ffield(doc, obj, "f_bool_2", b1)
    var i2 = doc.add_i32(Int(m.f_int32_2))
    _ffield(doc, obj, "f_int32_2", i2)
    var s1 = _put_str(doc, m.f_string_2)
    _ffield(doc, obj, "f_string_2", s1)
    return obj


def _write_item(mut doc: SmileDoc, item: DocumentItem) -> Int:
    var obj = doc.start_object()
    var sku = _put_str(doc, item.sku)
    _ffield(doc, obj, "sku", sku)
    var qty = doc.add_i32(Int(item.qty))
    _ffield(doc, obj, "qty", qty)
    var price = doc.add_i64(Int(item.price_minor))
    _ffield(doc, obj, "price_minor", price)
    return obj


def _write_document(mut doc: SmileDoc, d: Document) -> Int:
    var obj = doc.start_object()
    var id = _put_str(doc, d.id)
    _ffield(doc, obj, "id", id)
    var status = doc.add_i32(Int(d.status))
    _ffield(doc, obj, "status", status)
    var meta = doc.start_object()
    var region = _put_str(doc, d.meta.region)
    _ffield(doc, meta, "region", region)
    var version = doc.add_i32(Int(d.meta.version))
    _ffield(doc, meta, "version", version)
    _ffield(doc, obj, "meta", meta)
    var arr = doc.start_array()
    var i = 0
    while i < len(d.items):
        doc.add_elem(arr, _write_item(doc, d.items[i]))
        i += 1
    _ffield(doc, obj, "items", arr)
    return obj


def _write_telemetry(mut doc: SmileDoc, t: Telemetry) -> Int:
    var obj = doc.start_object()
    var source = _put_str(doc, t.source)
    _ffield(doc, obj, "source", source)
    var ts = doc.add_i64(Int(t.ts))
    _ffield(doc, obj, "ts", ts)
    var tags = doc.start_array()
    var i = 0
    while i < len(t.tags):
        doc.add_elem(tags, _put_str(doc, t.tags[i]))
        i += 1
    _ffield(doc, obj, "tags", tags)
    var values = doc.start_array()
    i = 0
    while i < len(t.values):
        doc.add_elem(values, doc.add_f64(t.values[i]))
        i += 1
    _ffield(doc, obj, "values", values)
    return obj


def _write_strings(mut doc: SmileDoc, s: Strings) -> Int:
    var obj = doc.start_object()
    var arr = doc.start_array()
    var i = 0
    while i < len(s.items):
        doc.add_elem(arr, _put_str(doc, s.items[i]))
        i += 1
    _ffield(doc, obj, "items", arr)
    return obj


def _write_attr(mut doc: SmileDoc, a: EventAttr) -> Int:
    var obj = doc.start_object()
    var key = _put_str(doc, a.key)
    _ffield(doc, obj, "key", key)
    var value = _put_str(doc, a.value)
    _ffield(doc, obj, "value", value)
    return obj


def _write_event(mut doc: SmileDoc, ev: Event) -> Int:
    var obj = doc.start_object()
    var event_id = _put_str(doc, ev.event_id)
    _ffield(doc, obj, "event_id", event_id)
    var event_type = _put_str(doc, ev.event_type)
    _ffield(doc, obj, "event_type", event_type)
    var occurred = doc.add_i64(Int(ev.occurred_at))
    _ffield(doc, obj, "occurred_at", occurred)
    var producer = _put_str(doc, ev.producer)
    _ffield(doc, obj, "producer", producer)
    var arr = doc.start_array()
    var i = 0
    while i < len(ev.attrs):
        doc.add_elem(arr, _write_attr(doc, ev.attrs[i]))
        i += 1
    _ffield(doc, obj, "attrs", arr)
    return obj


def _read_message(doc: SmileDoc, id: Int) raises -> Message:
    var m = Message()
    m.f_bool = _sbool(doc, _field(doc, id, "f_bool"))
    m.f_int32 = _si32(doc, _field(doc, id, "f_int32"))
    m.f_int64 = _si64(doc, _field(doc, id, "f_int64"))
    m.f_float64 = _sf64(doc, _field(doc, id, "f_float64"))
    m.f_string = _sstr(doc, _field(doc, id, "f_string"))
    m.f_bool_2 = _sbool(doc, _field(doc, id, "f_bool_2"))
    m.f_int32_2 = _si32(doc, _field(doc, id, "f_int32_2"))
    m.f_string_2 = _sstr(doc, _field(doc, id, "f_string_2"))
    return m^


def _read_item(doc: SmileDoc, id: Int) raises -> DocumentItem:
    var item = DocumentItem()
    item.sku = _sstr(doc, _field(doc, id, "sku"))
    item.qty = _si32(doc, _field(doc, id, "qty"))
    item.price_minor = _si64(doc, _field(doc, id, "price_minor"))
    return item^


def _read_document(doc: SmileDoc, id: Int) raises -> Document:
    var d = Document()
    d.id = _sstr(doc, _field(doc, id, "id"))
    d.status = _si32(doc, _field(doc, id, "status"))
    var meta = _field(doc, id, "meta")
    d.meta.region = _sstr(doc, _field(doc, meta, "region"))
    d.meta.version = _si32(doc, _field(doc, meta, "version"))
    var elems = _elems(doc, _field(doc, id, "items"))
    var i = 0
    while i < len(elems):
        var item = _read_item(doc, elems[i])
        d.items.append(item^)
        i += 1
    return d^


def _read_telemetry(doc: SmileDoc, id: Int) raises -> Telemetry:
    var t = Telemetry()
    t.source = _sstr(doc, _field(doc, id, "source"))
    t.ts = _si64(doc, _field(doc, id, "ts"))
    var tags = _elems(doc, _field(doc, id, "tags"))
    var i = 0
    while i < len(tags):
        var tag = _sstr(doc, tags[i])
        t.tags.append(tag)
        i += 1
    var values = _elems(doc, _field(doc, id, "values"))
    i = 0
    while i < len(values):
        t.values.append(_sf64(doc, values[i]))
        i += 1
    return t^


def _read_strings(doc: SmileDoc, id: Int) raises -> Strings:
    var s = Strings()
    var elems = _elems(doc, _field(doc, id, "items"))
    var i = 0
    while i < len(elems):
        var item = _sstr(doc, elems[i])
        s.items.append(item)
        i += 1
    return s^


def _read_attr(doc: SmileDoc, id: Int) raises -> EventAttr:
    var a = EventAttr()
    a.key = _sstr(doc, _field(doc, id, "key"))
    a.value = _sstr(doc, _field(doc, id, "value"))
    return a^


def _read_event(doc: SmileDoc, id: Int) raises -> Event:
    var ev = Event()
    ev.event_id = _sstr(doc, _field(doc, id, "event_id"))
    ev.event_type = _sstr(doc, _field(doc, id, "event_type"))
    ev.occurred_at = _si64(doc, _field(doc, id, "occurred_at"))
    ev.producer = _sstr(doc, _field(doc, id, "producer"))
    var elems = _elems(doc, _field(doc, id, "attrs"))
    var i = 0
    while i < len(elems):
        var attr = _read_attr(doc, elems[i])
        ev.attrs.append(attr^)
        i += 1
    return ev^


def _top(doc: SmileDoc) raises -> Int:
    if len(doc.top) != 1:
        raise Error("smile top")
    return doc.top[0]


def _one_or_items(doc: SmileDoc, n: Int) raises -> List[Int]:
    var root = _top(doc)
    if n == 1:
        var out = List[Int]()
        out.append(root)
        return out^
    return _elems(doc, _field(doc, root, "items"))


struct SmileSer:
    var version: String

    def __init__(out self):
        self.version = "0.2.0"

    def name(self) -> String:
        return "mojo-smile"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var doc = SmileDoc()
        if fx.type_id == "message":
            if fx.n == 1:
                doc.add_top(_write_message(doc, fx.messages[0]))
            else:
                var obj = doc.start_object()
                var arr = doc.start_array()
                var i = 0
                while i < len(fx.messages):
                    doc.add_elem(arr, _write_message(doc, fx.messages[i]))
                    i += 1
                doc.add_field(obj, _key(doc, "items"), arr)
                doc.add_top(obj)
        elif fx.type_id == "document":
            if fx.n == 1:
                doc.add_top(_write_document(doc, fx.documents[0]))
            else:
                var obj = doc.start_object()
                var arr = doc.start_array()
                var i = 0
                while i < len(fx.documents):
                    doc.add_elem(arr, _write_document(doc, fx.documents[i]))
                    i += 1
                doc.add_field(obj, _key(doc, "items"), arr)
                doc.add_top(obj)
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                doc.add_top(_write_telemetry(doc, fx.telemetries[0]))
            else:
                var obj = doc.start_object()
                var arr = doc.start_array()
                var i = 0
                while i < len(fx.telemetries):
                    doc.add_elem(arr, _write_telemetry(doc, fx.telemetries[i]))
                    i += 1
                doc.add_field(obj, _key(doc, "items"), arr)
                doc.add_top(obj)
        elif fx.type_id == "strings":
            if fx.n == 1:
                doc.add_top(_write_strings(doc, fx.strings[0]))
            else:
                var obj = doc.start_object()
                var arr = doc.start_array()
                var i = 0
                while i < len(fx.strings):
                    doc.add_elem(arr, _write_strings(doc, fx.strings[i]))
                    i += 1
                doc.add_field(obj, _key(doc, "items"), arr)
                doc.add_top(obj)
        else:
            if fx.n == 1:
                doc.add_top(_write_event(doc, fx.events[0]))
            else:
                var obj = doc.start_object()
                var arr = doc.start_array()
                var i = 0
                while i < len(fx.events):
                    doc.add_elem(arr, _write_event(doc, fx.events[i]))
                    i += 1
                doc.add_field(obj, _key(doc, "items"), arr)
                doc.add_top(obj)
        return encode_doc(doc^, EncodeOptions())

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var parsed = decode_bytes(Span(data))
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
        var ids = _one_or_items(parsed, fx.n)
        var i = 0
        if fx.type_id == "message":
            while i < len(ids):
                var m = _read_message(parsed, ids[i])
                out.messages.append(m^)
                i += 1
        elif fx.type_id == "document":
            while i < len(ids):
                var d = _read_document(parsed, ids[i])
                out.documents.append(d^)
                i += 1
        elif fx.type_id == "telemetry":
            while i < len(ids):
                var t = _read_telemetry(parsed, ids[i])
                out.telemetries.append(t^)
                i += 1
        elif fx.type_id == "strings":
            while i < len(ids):
                var s = _read_strings(parsed, ids[i])
                out.strings.append(s^)
                i += 1
        else:
            while i < len(ids):
                var ev = _read_event(parsed, ids[i])
                out.events.append(ev^)
                i += 1
        return out^

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
