"""gld-toml — TomlDoc encode / decode on suite types.

The serializer id is gld-toml. DataBooth/mojo-toml stays mojo-toml.
Vendored modules are renamed (gldtoml, gldtoml_wire, gldtoml_runtime) so both
libraries can be imported in one process.
"""

from std.collections import List
from std.memory import bitcast
from gldtoml import decode_toml, encode_toml
from gldtoml_wire.doc import TK_FALSE, TK_TRUE, TomlDoc
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


def _put(mut doc: TomlDoc, table: Int, key: String, child: Int):
    var ki = doc.add_text(key)
    doc.append_child(table, ki, child)


def _put_str(mut doc: TomlDoc, table: Int, key: String, value: String):
    _put(doc, table, key, doc.make_string(value, table))


def _put_bool(mut doc: TomlDoc, table: Int, key: String, value: Bool):
    _put(doc, table, key, doc.make_bool(value, table))


def _put_int(mut doc: TomlDoc, table: Int, key: String, value: Int64):
    _put(doc, table, key, doc.make_int(value, table))


def _put_float(mut doc: TomlDoc, table: Int, key: String, value: Float64):
    _put(doc, table, key, doc.make_float(bitcast[DType.uint64](value), table))


def _child(doc: TomlDoc, table: Int, key: String) raises -> Int:
    var node = doc.find_key(table, key)
    if node < 0:
        raise Error("missing toml key " + key)
    return node


def _as_bool(doc: TomlDoc, node: Int) raises -> Bool:
    var k = doc.kind(node)
    if k == TK_TRUE:
        return True
    if k == TK_FALSE:
        return False
    raise Error("toml bool")


def _kids(doc: TomlDoc, node: Int) -> List[Int]:
    var out = List[Int]()
    var e = doc.first_edge(node)
    while e >= 0:
        out.append(doc.edges[e].child)
        e = doc.edges[e].next
    return out^


def message_to_doc(mut doc: TomlDoc, table: Int, m: Message):
    _put_bool(doc, table, "f_bool", m.f_bool)
    _put_int(doc, table, "f_int32", Int64(m.f_int32))
    _put_int(doc, table, "f_int64", m.f_int64)
    _put_float(doc, table, "f_float64", m.f_float64)
    _put_str(doc, table, "f_string", m.f_string)
    _put_bool(doc, table, "f_bool_2", m.f_bool_2)
    _put_int(doc, table, "f_int32_2", Int64(m.f_int32_2))
    _put_str(doc, table, "f_string_2", m.f_string_2)


def message_from_doc(doc: TomlDoc, table: Int) raises -> Message:
    return Message(
        _as_bool(doc, _child(doc, table, "f_bool")),
        Int32(doc.int_at(_child(doc, table, "f_int32"))),
        doc.int_at(_child(doc, table, "f_int64")),
        doc.float_at(_child(doc, table, "f_float64")),
        doc.text_at(_child(doc, table, "f_string")),
        _as_bool(doc, _child(doc, table, "f_bool_2")),
        Int32(doc.int_at(_child(doc, table, "f_int32_2"))),
        doc.text_at(_child(doc, table, "f_string_2")),
    )


def document_to_doc(mut doc: TomlDoc, table: Int, src: Document):
    _put_str(doc, table, "id", src.id)
    _put_int(doc, table, "status", Int64(src.status))
    var meta = doc.make_table(table)
    _put_str(doc, meta, "region", src.meta.region)
    _put_int(doc, meta, "version", Int64(src.meta.version))
    _put(doc, table, "meta", meta)
    var items = doc.make_array(table)
    var i = 0
    while i < len(src.items):
        var row = doc.make_table(items)
        _put_str(doc, row, "sku", src.items[i].sku)
        _put_int(doc, row, "qty", Int64(src.items[i].qty))
        _put_int(doc, row, "price_minor", src.items[i].price_minor)
        doc.append_child(items, -1, row)
        i += 1
    _put(doc, table, "items", items)


def document_from_doc(doc: TomlDoc, table: Int) raises -> Document:
    var meta = _child(doc, table, "meta")
    var raw_items = _kids(doc, _child(doc, table, "items"))
    var items = List[DocumentItem]()
    var i = 0
    while i < len(raw_items):
        var row = raw_items[i]
        items.append(
            DocumentItem(
                doc.text_at(_child(doc, row, "sku")),
                Int32(doc.int_at(_child(doc, row, "qty"))),
                doc.int_at(_child(doc, row, "price_minor")),
            )
        )
        i += 1
    return Document(
        doc.text_at(_child(doc, table, "id")),
        Int32(doc.int_at(_child(doc, table, "status"))),
        DocumentMeta(
            doc.text_at(_child(doc, meta, "region")),
            Int32(doc.int_at(_child(doc, meta, "version"))),
        ),
        items^,
    )


def telemetry_to_doc(mut doc: TomlDoc, table: Int, t: Telemetry):
    _put_str(doc, table, "source", t.source)
    _put_int(doc, table, "ts", t.ts)
    var tags = doc.make_array(table)
    var i = 0
    while i < len(t.tags):
        doc.append_child(tags, -1, doc.make_string(t.tags[i], tags))
        i += 1
    _put(doc, table, "tags", tags)
    var values = doc.make_array(table)
    i = 0
    while i < len(t.values):
        doc.append_child(values, -1, doc.make_float(bitcast[DType.uint64](t.values[i]), values))
        i += 1
    _put(doc, table, "values", values)


def telemetry_from_doc(doc: TomlDoc, table: Int) raises -> Telemetry:
    var tags = List[String]()
    var raw_tags = _kids(doc, _child(doc, table, "tags"))
    var i = 0
    while i < len(raw_tags):
        tags.append(doc.text_at(raw_tags[i]))
        i += 1
    var values = List[Float64]()
    var raw_vals = _kids(doc, _child(doc, table, "values"))
    i = 0
    while i < len(raw_vals):
        values.append(doc.float_at(raw_vals[i]))
        i += 1
    return Telemetry(
        doc.text_at(_child(doc, table, "source")),
        doc.int_at(_child(doc, table, "ts")),
        tags^,
        values^,
    )


def strings_to_doc(mut doc: TomlDoc, table: Int, s: Strings):
    var items = doc.make_array(table)
    var i = 0
    while i < len(s.items):
        doc.append_child(items, -1, doc.make_string(s.items[i], items))
        i += 1
    _put(doc, table, "items", items)


def strings_from_doc(doc: TomlDoc, table: Int) raises -> Strings:
    var items = List[String]()
    var raw = _kids(doc, _child(doc, table, "items"))
    var i = 0
    while i < len(raw):
        items.append(doc.text_at(raw[i]))
        i += 1
    return Strings(items^)


def event_to_doc(mut doc: TomlDoc, table: Int, e: Event):
    _put_str(doc, table, "event_id", e.event_id)
    _put_str(doc, table, "event_type", e.event_type)
    _put_int(doc, table, "occurred_at", e.occurred_at)
    _put_str(doc, table, "producer", e.producer)
    var attrs = doc.make_array(table)
    var i = 0
    while i < len(e.attrs):
        var row = doc.make_table(attrs)
        _put_str(doc, row, "key", e.attrs[i].key)
        _put_str(doc, row, "value", e.attrs[i].value)
        doc.append_child(attrs, -1, row)
        i += 1
    _put(doc, table, "attrs", attrs)


def event_from_doc(doc: TomlDoc, table: Int) raises -> Event:
    var attrs = List[EventAttr]()
    var raw = _kids(doc, _child(doc, table, "attrs"))
    var i = 0
    while i < len(raw):
        var row = raw[i]
        attrs.append(
            EventAttr(
                doc.text_at(_child(doc, row, "key")),
                doc.text_at(_child(doc, row, "value")),
            )
        )
        i += 1
    return Event(
        doc.text_at(_child(doc, table, "event_id")),
        doc.text_at(_child(doc, table, "event_type")),
        doc.int_at(_child(doc, table, "occurred_at")),
        doc.text_at(_child(doc, table, "producer")),
        attrs^,
    )


def fill_doc(mut doc: TomlDoc, fx: Fixture):
    var root = doc.root
    if fx.n != 1:
        var items = doc.make_array(root)
        var i = 0
        if fx.type_id == "message":
            while i < len(fx.messages):
                var row = doc.make_table(items)
                message_to_doc(doc, row, fx.messages[i])
                doc.append_child(items, -1, row)
                i += 1
        elif fx.type_id == "document":
            while i < len(fx.documents):
                var row = doc.make_table(items)
                document_to_doc(doc, row, fx.documents[i])
                doc.append_child(items, -1, row)
                i += 1
        elif fx.type_id == "telemetry":
            while i < len(fx.telemetries):
                var row = doc.make_table(items)
                telemetry_to_doc(doc, row, fx.telemetries[i])
                doc.append_child(items, -1, row)
                i += 1
        elif fx.type_id == "strings":
            while i < len(fx.strings):
                var row = doc.make_table(items)
                strings_to_doc(doc, row, fx.strings[i])
                doc.append_child(items, -1, row)
                i += 1
        else:
            while i < len(fx.events):
                var row = doc.make_table(items)
                event_to_doc(doc, row, fx.events[i])
                doc.append_child(items, -1, row)
                i += 1
        _put(doc, root, "items", items)
        return
    if fx.type_id == "message":
        message_to_doc(doc, root, fx.messages[0])
    elif fx.type_id == "document":
        document_to_doc(doc, root, fx.documents[0])
    elif fx.type_id == "telemetry":
        telemetry_to_doc(doc, root, fx.telemetries[0])
    elif fx.type_id == "strings":
        strings_to_doc(doc, root, fx.strings[0])
    else:
        event_to_doc(doc, root, fx.events[0])


def read_doc(doc: TomlDoc, fx: Fixture) raises -> Fixture:
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
    if fx.n != 1:
        var items = _kids(doc, _child(doc, doc.root, "items"))
        var i = 0
        while i < len(items):
            var row = items[i]
            if fx.type_id == "message":
                out.messages.append(message_from_doc(doc, row))
            elif fx.type_id == "document":
                out.documents.append(document_from_doc(doc, row))
            elif fx.type_id == "telemetry":
                out.telemetries.append(telemetry_from_doc(doc, row))
            elif fx.type_id == "strings":
                out.strings.append(strings_from_doc(doc, row))
            else:
                out.events.append(event_from_doc(doc, row))
            i += 1
        return out^
    if fx.type_id == "message":
        out.messages.append(message_from_doc(doc, doc.root))
    elif fx.type_id == "document":
        out.documents.append(document_from_doc(doc, doc.root))
    elif fx.type_id == "telemetry":
        out.telemetries.append(telemetry_from_doc(doc, doc.root))
    elif fx.type_id == "strings":
        out.strings.append(strings_from_doc(doc, doc.root))
    else:
        out.events.append(event_from_doc(doc, doc.root))
    return out^


struct GldTomlSer:
    var version: String

    def __init__(out self):
        self.version = "0.1.0"

    def name(self) -> String:
        return "gld-toml"

    def serialize_bytes(self, fx: Fixture) raises -> String:
        var doc = TomlDoc()
        fill_doc(doc, fx)
        return encode_toml(doc)

    def deserialize_bytes(self, fx: Fixture, data: String) raises -> Fixture:
        var doc = decode_toml(data)
        return read_doc(doc, fx)

    def check(self, fx: Fixture, data: String) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
