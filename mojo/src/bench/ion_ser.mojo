"""mojo-ion (gld-ion) binary document encode/decode on suite types."""

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
from ion import decode, encode
from ion_runtime.doc import (
    IonDoc,
    K_BOOL,
    K_FLOAT,
    K_INT,
    K_LIST,
    K_STRING,
    K_STRUCT,
)
from ion_runtime.options import EncodeOptions
from ion_runtime.symtab import Catalog


def _need(doc: IonDoc, id: Int, kind: Int) raises:
    if id < 0 or doc.nodes[id].kind != kind:
        raise Error("ion type")


def _fname(doc: IonDoc, field: Int) -> String:
    if field < 0:
        return String()
    return doc.sym_text(field)


def _field(doc: IonDoc, obj: Int, name: String) raises -> Int:
    _need(doc, obj, K_STRUCT)
    var node = doc.nodes[obj]
    var edge = node.child
    var i = 0
    while i < node.nchild:
        if _fname(doc, doc.edges[edge].field) == name:
            return doc.edges[edge].child
        edge = doc.edges[edge].next
        i += 1
    raise Error("ion field " + name)


def _elems(doc: IonDoc, id: Int) raises -> List[Int]:
    _need(doc, id, K_LIST)
    var out = List[Int]()
    var node = doc.nodes[id]
    var edge = node.child
    var i = 0
    while i < node.nchild:
        out.append(doc.edges[edge].child)
        edge = doc.edges[edge].next
        i += 1
    return out^


def _istr(doc: IonDoc, id: Int) raises -> String:
    _need(doc, id, K_STRING)
    return doc.text_at(id)


def _ibool(doc: IonDoc, id: Int) raises -> Bool:
    _need(doc, id, K_BOOL)
    return doc.nodes[id].a != 0


def _ii64(doc: IonDoc, id: Int) raises -> Int64:
    _need(doc, id, K_INT)
    var n = doc.nodes[id]
    if n.b <= 0:
        return Int64(0)
    var mag = UInt64(doc.limbs[n.a])
    if n.b >= 2:
        mag = mag | (UInt64(doc.limbs[n.a + 1]) << UInt64(32))
    if n.c != 0:
        if mag == (UInt64(1) << UInt64(63)):
            return Int64(-9223372036854775807) - Int64(1)
        return Int64(0) - Int64(mag)
    return Int64(mag)


def _if64(doc: IonDoc, id: Int) raises -> Float64:
    _need(doc, id, K_FLOAT)
    return Float64(from_bits=doc.floats[doc.nodes[id].b])


def _sym(mut doc: IonDoc, name: String) -> Int:
    var node = doc.add_symbol_text(String(name))
    return doc.nodes[node].a


def _put(mut doc: IonDoc, parent: Int, name: String, child: Int):
    doc.add_child(parent, child, _sym(doc, name))


def _str(mut doc: IonDoc, text: String) -> Int:
    return doc.add_string(String(text))


def _f64(mut doc: IonDoc, value: Float64) -> Int:
    return doc.add_float(8, UInt64(value.to_bits()))


def _write_message(mut doc: IonDoc, m: Message) -> Int:
    var obj = doc.start_container(K_STRUCT)
    _put(doc, obj, "f_bool", doc.add_bool(m.f_bool))
    _put(doc, obj, "f_int32", doc.add_i64(Int64(m.f_int32)))
    _put(doc, obj, "f_int64", doc.add_i64(m.f_int64))
    _put(doc, obj, "f_float64", _f64(doc, m.f_float64))
    _put(doc, obj, "f_string", _str(doc, m.f_string))
    _put(doc, obj, "f_bool_2", doc.add_bool(m.f_bool_2))
    _put(doc, obj, "f_int32_2", doc.add_i64(Int64(m.f_int32_2)))
    _put(doc, obj, "f_string_2", _str(doc, m.f_string_2))
    return obj


def _write_item(mut doc: IonDoc, item: DocumentItem) -> Int:
    var obj = doc.start_container(K_STRUCT)
    _put(doc, obj, "sku", _str(doc, item.sku))
    _put(doc, obj, "qty", doc.add_i64(Int64(item.qty)))
    _put(doc, obj, "price_minor", doc.add_i64(item.price_minor))
    return obj


def _write_document(mut doc: IonDoc, d: Document) -> Int:
    var obj = doc.start_container(K_STRUCT)
    _put(doc, obj, "id", _str(doc, d.id))
    _put(doc, obj, "status", doc.add_i64(Int64(d.status)))
    var meta = doc.start_container(K_STRUCT)
    _put(doc, meta, "region", _str(doc, d.meta.region))
    _put(doc, meta, "version", doc.add_i64(Int64(d.meta.version)))
    _put(doc, obj, "meta", meta)
    var arr = doc.start_container(K_LIST)
    var i = 0
    while i < len(d.items):
        doc.add_child(arr, _write_item(doc, d.items[i]), -1)
        i += 1
    _put(doc, obj, "items", arr)
    return obj


def _write_telemetry(mut doc: IonDoc, t: Telemetry) -> Int:
    var obj = doc.start_container(K_STRUCT)
    _put(doc, obj, "source", _str(doc, t.source))
    _put(doc, obj, "ts", doc.add_i64(t.ts))
    var tags = doc.start_container(K_LIST)
    var i = 0
    while i < len(t.tags):
        doc.add_child(tags, _str(doc, t.tags[i]), -1)
        i += 1
    _put(doc, obj, "tags", tags)
    var values = doc.start_container(K_LIST)
    i = 0
    while i < len(t.values):
        doc.add_child(values, _f64(doc, t.values[i]), -1)
        i += 1
    _put(doc, obj, "values", values)
    return obj


def _write_strings(mut doc: IonDoc, s: Strings) -> Int:
    var obj = doc.start_container(K_STRUCT)
    var arr = doc.start_container(K_LIST)
    var i = 0
    while i < len(s.items):
        doc.add_child(arr, _str(doc, s.items[i]), -1)
        i += 1
    _put(doc, obj, "items", arr)
    return obj


def _write_attr(mut doc: IonDoc, a: EventAttr) -> Int:
    var obj = doc.start_container(K_STRUCT)
    _put(doc, obj, "key", _str(doc, a.key))
    _put(doc, obj, "value", _str(doc, a.value))
    return obj


def _write_event(mut doc: IonDoc, ev: Event) -> Int:
    var obj = doc.start_container(K_STRUCT)
    _put(doc, obj, "event_id", _str(doc, ev.event_id))
    _put(doc, obj, "event_type", _str(doc, ev.event_type))
    _put(doc, obj, "occurred_at", doc.add_i64(ev.occurred_at))
    _put(doc, obj, "producer", _str(doc, ev.producer))
    var arr = doc.start_container(K_LIST)
    var i = 0
    while i < len(ev.attrs):
        doc.add_child(arr, _write_attr(doc, ev.attrs[i]), -1)
        i += 1
    _put(doc, obj, "attrs", arr)
    return obj


def _read_message(doc: IonDoc, id: Int) raises -> Message:
    var m = Message()
    m.f_bool = _ibool(doc, _field(doc, id, "f_bool"))
    m.f_int32 = Int32(_ii64(doc, _field(doc, id, "f_int32")))
    m.f_int64 = _ii64(doc, _field(doc, id, "f_int64"))
    m.f_float64 = _if64(doc, _field(doc, id, "f_float64"))
    m.f_string = _istr(doc, _field(doc, id, "f_string"))
    m.f_bool_2 = _ibool(doc, _field(doc, id, "f_bool_2"))
    m.f_int32_2 = Int32(_ii64(doc, _field(doc, id, "f_int32_2")))
    m.f_string_2 = _istr(doc, _field(doc, id, "f_string_2"))
    return m^


def _read_item(doc: IonDoc, id: Int) raises -> DocumentItem:
    var item = DocumentItem()
    item.sku = _istr(doc, _field(doc, id, "sku"))
    item.qty = Int32(_ii64(doc, _field(doc, id, "qty")))
    item.price_minor = _ii64(doc, _field(doc, id, "price_minor"))
    return item^


def _read_document(doc: IonDoc, id: Int) raises -> Document:
    var d = Document()
    d.id = _istr(doc, _field(doc, id, "id"))
    d.status = Int32(_ii64(doc, _field(doc, id, "status")))
    var meta = _field(doc, id, "meta")
    d.meta.region = _istr(doc, _field(doc, meta, "region"))
    d.meta.version = Int32(_ii64(doc, _field(doc, meta, "version")))
    var elems = _elems(doc, _field(doc, id, "items"))
    var i = 0
    while i < len(elems):
        var item = _read_item(doc, elems[i])
        d.items.append(item^)
        i += 1
    return d^


def _read_telemetry(doc: IonDoc, id: Int) raises -> Telemetry:
    var t = Telemetry()
    t.source = _istr(doc, _field(doc, id, "source"))
    t.ts = _ii64(doc, _field(doc, id, "ts"))
    var tags = _elems(doc, _field(doc, id, "tags"))
    var i = 0
    while i < len(tags):
        var tag = _istr(doc, tags[i])
        t.tags.append(tag)
        i += 1
    var values = _elems(doc, _field(doc, id, "values"))
    i = 0
    while i < len(values):
        t.values.append(_if64(doc, values[i]))
        i += 1
    return t^


def _read_strings(doc: IonDoc, id: Int) raises -> Strings:
    var s = Strings()
    var elems = _elems(doc, _field(doc, id, "items"))
    var i = 0
    while i < len(elems):
        var item = _istr(doc, elems[i])
        s.items.append(item)
        i += 1
    return s^


def _read_attr(doc: IonDoc, id: Int) raises -> EventAttr:
    var a = EventAttr()
    a.key = _istr(doc, _field(doc, id, "key"))
    a.value = _istr(doc, _field(doc, id, "value"))
    return a^


def _read_event(doc: IonDoc, id: Int) raises -> Event:
    var ev = Event()
    ev.event_id = _istr(doc, _field(doc, id, "event_id"))
    ev.event_type = _istr(doc, _field(doc, id, "event_type"))
    ev.occurred_at = _ii64(doc, _field(doc, id, "occurred_at"))
    ev.producer = _istr(doc, _field(doc, id, "producer"))
    var elems = _elems(doc, _field(doc, id, "attrs"))
    var i = 0
    while i < len(elems):
        var attr = _read_attr(doc, elems[i])
        ev.attrs.append(attr^)
        i += 1
    return ev^


def _top(doc: IonDoc) raises -> Int:
    if len(doc.top) < 1:
        raise Error("ion top")
    return doc.top[0]


def _one_or_items(doc: IonDoc, n: Int) raises -> List[Int]:
    var root = _top(doc)
    if n == 1:
        var out = List[Int]()
        out.append(root)
        return out^
    return _elems(doc, _field(doc, root, "items"))


struct IonSer:
    var version: String

    def __init__(out self):
        self.version = "0.2.0"

    def name(self) -> String:
        return "mojo-ion"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var doc = IonDoc()
        var root: Int
        if fx.type_id == "message":
            if fx.n == 1:
                root = _write_message(doc, fx.messages[0])
            else:
                root = doc.start_container(K_STRUCT)
                var arr = doc.start_container(K_LIST)
                var i = 0
                while i < len(fx.messages):
                    doc.add_child(arr, _write_message(doc, fx.messages[i]), -1)
                    i += 1
                _put(doc, root, "items", arr)
        elif fx.type_id == "document":
            if fx.n == 1:
                root = _write_document(doc, fx.documents[0])
            else:
                root = doc.start_container(K_STRUCT)
                var arr = doc.start_container(K_LIST)
                var i = 0
                while i < len(fx.documents):
                    doc.add_child(arr, _write_document(doc, fx.documents[i]), -1)
                    i += 1
                _put(doc, root, "items", arr)
        elif fx.type_id == "telemetry":
            if fx.n == 1:
                root = _write_telemetry(doc, fx.telemetries[0])
            else:
                root = doc.start_container(K_STRUCT)
                var arr = doc.start_container(K_LIST)
                var i = 0
                while i < len(fx.telemetries):
                    doc.add_child(arr, _write_telemetry(doc, fx.telemetries[i]), -1)
                    i += 1
                _put(doc, root, "items", arr)
        elif fx.type_id == "strings":
            if fx.n == 1:
                root = _write_strings(doc, fx.strings[0])
            else:
                root = doc.start_container(K_STRUCT)
                var arr = doc.start_container(K_LIST)
                var i = 0
                while i < len(fx.strings):
                    doc.add_child(arr, _write_strings(doc, fx.strings[i]), -1)
                    i += 1
                _put(doc, root, "items", arr)
        else:
            if fx.n == 1:
                root = _write_event(doc, fx.events[0])
            else:
                root = doc.start_container(K_STRUCT)
                var arr = doc.start_container(K_LIST)
                var i = 0
                while i < len(fx.events):
                    doc.add_child(arr, _write_event(doc, fx.events[i]), -1)
                    i += 1
                _put(doc, root, "items", arr)
        doc.add_top(root)
        return encode(doc^, EncodeOptions(True), Catalog())

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var parsed = decode(Span(data), Catalog())
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
