"""ehsanmok/json (v0.3.0) — official loads / dumps + Value DOM.

Reflection `serialize_json` / `deserialize_json` is the typed path, but
v0.3.0 cannot reflect `Int32` or `List[struct]`. Those are the suite
field types, so the timed path is the documented Python-like API:
build a `Value` tree with `set` / `append`, then `dumps` / `loads`.
"""

from std.collections import List
from ehsanmok_json import Value, dumps, loads
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


def _obj() raises -> Value:
    return loads("{}")


def _arr() raises -> Value:
    return loads("[]")


def message_to_value(m: Message) raises -> Value:
    var o = _obj()
    o.set("f_bool", Value(m.f_bool))
    o.set("f_int32", Value(Int(m.f_int32)))
    o.set("f_int64", Value(m.f_int64))
    o.set("f_float64", Value(m.f_float64))
    o.set("f_string", Value(m.f_string))
    o.set("f_bool_2", Value(m.f_bool_2))
    o.set("f_int32_2", Value(Int(m.f_int32_2)))
    o.set("f_string_2", Value(m.f_string_2))
    return o^


def message_from_value(v: Value) raises -> Message:
    return Message(
        v["f_bool"].bool_value(),
        Int32(v["f_int32"].int_value()),
        v["f_int64"].int_value(),
        v["f_float64"].float_value(),
        v["f_string"].string_value(),
        v["f_bool_2"].bool_value(),
        Int32(v["f_int32_2"].int_value()),
        v["f_string_2"].string_value(),
    )


def document_to_value(d: Document) raises -> Value:
    var o = _obj()
    o.set("id", Value(d.id))
    o.set("status", Value(Int(d.status)))
    var meta = _obj()
    meta.set("region", Value(d.meta.region))
    meta.set("version", Value(Int(d.meta.version)))
    o.set("meta", meta)
    var items = _arr()
    var i = 0
    while i < len(d.items):
        var it = _obj()
        it.set("sku", Value(d.items[i].sku))
        it.set("qty", Value(Int(d.items[i].qty)))
        it.set("price_minor", Value(d.items[i].price_minor))
        items.append(it)
        i += 1
    o.set("items", items)
    return o^


def document_from_value(v: Value) raises -> Document:
    var items = List[DocumentItem]()
    var arr = v["items"]
    var i = 0
    while i < arr.array_count():
        var it = arr[i]
        items.append(
            DocumentItem(
                it["sku"].string_value(),
                Int32(it["qty"].int_value()),
                it["price_minor"].int_value(),
            )
        )
        i += 1
    return Document(
        v["id"].string_value(),
        Int32(v["status"].int_value()),
        DocumentMeta(v["meta"]["region"].string_value(), Int32(v["meta"]["version"].int_value())),
        items^,
    )


def telemetry_to_value(t: Telemetry) raises -> Value:
    var o = _obj()
    o.set("source", Value(t.source))
    o.set("ts", Value(t.ts))
    var tags = _arr()
    var i = 0
    while i < len(t.tags):
        tags.append(Value(t.tags[i]))
        i += 1
    o.set("tags", tags)
    var values = _arr()
    i = 0
    while i < len(t.values):
        values.append(Value(t.values[i]))
        i += 1
    o.set("values", values)
    return o^


def telemetry_from_value(v: Value) raises -> Telemetry:
    var tags = List[String]()
    var tarr = v["tags"]
    var i = 0
    while i < tarr.array_count():
        tags.append(tarr[i].string_value())
        i += 1
    var values = List[Float64]()
    var varr = v["values"]
    i = 0
    while i < varr.array_count():
        values.append(varr[i].float_value())
        i += 1
    return Telemetry(v["source"].string_value(), v["ts"].int_value(), tags^, values^)


def strings_to_value(s: Strings) raises -> Value:
    var o = _obj()
    var items = _arr()
    var i = 0
    while i < len(s.items):
        items.append(Value(s.items[i]))
        i += 1
    o.set("items", items)
    return o^


def strings_from_value(v: Value) raises -> Strings:
    var items = List[String]()
    var arr = v["items"]
    var i = 0
    while i < arr.array_count():
        items.append(arr[i].string_value())
        i += 1
    return Strings(items^)


def event_to_value(e: Event) raises -> Value:
    var o = _obj()
    o.set("event_id", Value(e.event_id))
    o.set("event_type", Value(e.event_type))
    o.set("occurred_at", Value(e.occurred_at))
    o.set("producer", Value(e.producer))
    var attrs = _arr()
    var i = 0
    while i < len(e.attrs):
        var a = _obj()
        a.set("key", Value(e.attrs[i].key))
        a.set("value", Value(e.attrs[i].value))
        attrs.append(a)
        i += 1
    o.set("attrs", attrs)
    return o^


def event_from_value(v: Value) raises -> Event:
    var attrs = List[EventAttr]()
    var arr = v["attrs"]
    var i = 0
    while i < arr.array_count():
        var a = arr[i]
        attrs.append(EventAttr(a["key"].string_value(), a["value"].string_value()))
        i += 1
    return Event(
        v["event_id"].string_value(),
        v["event_type"].string_value(),
        v["occurred_at"].int_value(),
        v["producer"].string_value(),
        attrs^,
    )


def fixture_to_value(fx: Fixture) raises -> Value:
    if fx.n != 1:
        var items = _arr()
        var i = 0
        if fx.type_id == "message":
            while i < len(fx.messages):
                items.append(message_to_value(fx.messages[i]))
                i += 1
        elif fx.type_id == "document":
            while i < len(fx.documents):
                items.append(document_to_value(fx.documents[i]))
                i += 1
        elif fx.type_id == "telemetry":
            while i < len(fx.telemetries):
                items.append(telemetry_to_value(fx.telemetries[i]))
                i += 1
        elif fx.type_id == "strings":
            while i < len(fx.strings):
                items.append(strings_to_value(fx.strings[i]))
                i += 1
        else:
            while i < len(fx.events):
                items.append(event_to_value(fx.events[i]))
                i += 1
        var wrap = _obj()
        wrap.set("items", items)
        return wrap^
    if fx.type_id == "message":
        return message_to_value(fx.messages[0])
    if fx.type_id == "document":
        return document_to_value(fx.documents[0])
    if fx.type_id == "telemetry":
        return telemetry_to_value(fx.telemetries[0])
    if fx.type_id == "strings":
        return strings_to_value(fx.strings[0])
    return event_to_value(fx.events[0])


def fixture_from_value(fx: Fixture, v: Value) raises -> Fixture:
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
        var items = v["items"]
        var i = 0
        while i < items.array_count():
            var one = items[i]
            if fx.type_id == "message":
                out.messages.append(message_from_value(one))
            elif fx.type_id == "document":
                out.documents.append(document_from_value(one))
            elif fx.type_id == "telemetry":
                out.telemetries.append(telemetry_from_value(one))
            elif fx.type_id == "strings":
                out.strings.append(strings_from_value(one))
            else:
                out.events.append(event_from_value(one))
            i += 1
        return out^
    if fx.type_id == "message":
        out.messages.append(message_from_value(v))
    elif fx.type_id == "document":
        out.documents.append(document_from_value(v))
    elif fx.type_id == "telemetry":
        out.telemetries.append(telemetry_from_value(v))
    elif fx.type_id == "strings":
        out.strings.append(strings_from_value(v))
    else:
        out.events.append(event_from_value(v))
    return out^


struct EhsanJsonSer:
    var version: String

    def __init__(out self):
        self.version = "0.3.0"

    def name(self) -> String:
        return "ehsanmok-json"

    def serialize_bytes(self, fx: Fixture) raises -> String:
        return dumps(fixture_to_value(fx))

    def deserialize_bytes(self, fx: Fixture, data: String) raises -> Fixture:
        return fixture_from_value(fx, loads(data))

    def check(self, fx: Fixture, data: String) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
