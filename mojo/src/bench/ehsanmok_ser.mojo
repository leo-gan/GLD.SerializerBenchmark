"""ehsanmok/json (v0.3.1) — serialize_json encode, loads + Value DOM decode.

v0.3.1 reflects Int32 and List[struct] on the write path, so encode uses
the official typed serializer (same JSON shape as EmberJson). Telemetry
is the exception: serialize_json mis-matches List[Float64] as a float
(the type name contains SIMD[DType.float64), so that cell builds a
Value tree with object() / array() instead. List[struct] is still
unsupported on the read side, so decode walks the Value tree from loads().
"""

from std.collections import List
from ehsanmok_json import Value, dumps, loads, serialize_json
from bench.data import (
    BatchDocument,
    BatchEvent,
    BatchMessage,
    BatchStrings,
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
    var o = Value.object()
    o.set("source", Value(t.source))
    o.set("ts", Value(t.ts))
    var tags = Value.array()
    var i = 0
    while i < len(t.tags):
        tags.append(Value(t.tags[i]))
        i += 1
    o.set("tags", tags^)
    var values = Value.array()
    i = 0
    while i < len(t.values):
        values.append(Value(t.values[i]))
        i += 1
    o.set("values", values^)
    return o^


def telemetry_fixture_to_value(fx: Fixture) raises -> Value:
    if fx.n == 1:
        return telemetry_to_value(fx.telemetries[0])
    var items = Value.array()
    var i = 0
    while i < len(fx.telemetries):
        items.append(telemetry_to_value(fx.telemetries[i]))
        i += 1
    var wrap = Value.object()
    wrap.set("items", items^)
    return wrap^


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


def strings_from_value(v: Value) raises -> Strings:
    var items = List[String]()
    var arr = v["items"]
    var i = 0
    while i < arr.array_count():
        items.append(arr[i].string_value())
        i += 1
    return Strings(items^)


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
        self.version = "0.3.1"

    def name(self) -> String:
        return "ehsanmok-json"

    def serialize_bytes(self, fx: Fixture) raises -> String:
        if fx.type_id == "message":
            if fx.n == 1:
                return serialize_json(fx.messages[0])
            return serialize_json(BatchMessage(fx.messages.copy()))
        if fx.type_id == "document":
            if fx.n == 1:
                return serialize_json(fx.documents[0])
            return serialize_json(BatchDocument(fx.documents.copy()))
        if fx.type_id == "telemetry":
            return dumps(telemetry_fixture_to_value(fx))
        if fx.type_id == "strings":
            if fx.n == 1:
                return serialize_json(fx.strings[0])
            return serialize_json(BatchStrings(fx.strings.copy()))
        if fx.n == 1:
            return serialize_json(fx.events[0])
        return serialize_json(BatchEvent(fx.events.copy()))

    def deserialize_bytes(self, fx: Fixture, data: String) raises -> Fixture:
        return fixture_from_value(fx, loads(data))

    def check(self, fx: Fixture, data: String) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
