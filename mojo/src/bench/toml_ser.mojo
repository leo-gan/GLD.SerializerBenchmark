from std.collections import Dict, List
from toml import TomlValue, parse, to_toml
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


def _tv_str(s: String) -> TomlValue:
    return TomlValue(s)


def _tv_bool(v: Bool) -> TomlValue:
    return TomlValue(v)


def _tv_int(v: Int) -> TomlValue:
    return TomlValue(v)


def _tv_float(v: Float64) -> TomlValue:
    return TomlValue(v)


def message_to_toml(m: Message) -> Dict[String, TomlValue]:
    var d = Dict[String, TomlValue]()
    d["f_bool"] = _tv_bool(m.f_bool)
    d["f_int32"] = _tv_int(Int(m.f_int32))
    d["f_int64"] = _tv_int(Int(m.f_int64))
    d["f_float64"] = _tv_float(m.f_float64)
    d["f_string"] = _tv_str(m.f_string)
    d["f_bool_2"] = _tv_bool(m.f_bool_2)
    d["f_int32_2"] = _tv_int(Int(m.f_int32_2))
    d["f_string_2"] = _tv_str(m.f_string_2)
    return d^


def message_from_toml(d: Dict[String, TomlValue]) raises -> Message:
    return Message(
        d["f_bool"].as_bool(),
        Int32(d["f_int32"].as_int()),
        Int64(d["f_int64"].as_int()),
        d["f_float64"].as_float(),
        d["f_string"].as_string(),
        d["f_bool_2"].as_bool(),
        Int32(d["f_int32_2"].as_int()),
        d["f_string_2"].as_string(),
    )


def document_to_toml(doc: Document) -> Dict[String, TomlValue]:
    var d = Dict[String, TomlValue]()
    d["id"] = _tv_str(doc.id)
    d["status"] = _tv_int(Int(doc.status))
    var meta = Dict[String, TomlValue]()
    meta["region"] = _tv_str(doc.meta.region)
    meta["version"] = _tv_int(Int(doc.meta.version))
    d["meta"] = TomlValue(meta^)
    var items = List[TomlValue]()
    var i = 0
    while i < len(doc.items):
        var it = Dict[String, TomlValue]()
        it["sku"] = _tv_str(doc.items[i].sku)
        it["qty"] = _tv_int(Int(doc.items[i].qty))
        it["price_minor"] = _tv_int(Int(doc.items[i].price_minor))
        items.append(TomlValue(it^))
        i += 1
    d["items"] = TomlValue(items^)
    return d^


def document_from_toml(d: Dict[String, TomlValue]) raises -> Document:
    var meta = d["meta"].as_table()
    var raw_items = d["items"].as_array()
    var items = List[DocumentItem]()
    var i = 0
    while i < len(raw_items):
        var it = raw_items[i].as_table()
        items.append(
            DocumentItem(
                it["sku"].as_string(),
                Int32(it["qty"].as_int()),
                Int64(it["price_minor"].as_int()),
            )
        )
        i += 1
    return Document(
        d["id"].as_string(),
        Int32(d["status"].as_int()),
        DocumentMeta(meta["region"].as_string(), Int32(meta["version"].as_int())),
        items^,
    )


def telemetry_to_toml(t: Telemetry) -> Dict[String, TomlValue]:
    var d = Dict[String, TomlValue]()
    d["source"] = _tv_str(t.source)
    d["ts"] = _tv_int(Int(t.ts))
    var tags = List[TomlValue]()
    var i = 0
    while i < len(t.tags):
        tags.append(_tv_str(t.tags[i]))
        i += 1
    d["tags"] = TomlValue(tags^)
    var values = List[TomlValue]()
    i = 0
    while i < len(t.values):
        values.append(_tv_float(t.values[i]))
        i += 1
    d["values"] = TomlValue(values^)
    return d^


def telemetry_from_toml(d: Dict[String, TomlValue]) raises -> Telemetry:
    var tags = List[String]()
    var raw_tags = d["tags"].as_array()
    var i = 0
    while i < len(raw_tags):
        tags.append(raw_tags[i].as_string())
        i += 1
    var values = List[Float64]()
    var raw_vals = d["values"].as_array()
    i = 0
    while i < len(raw_vals):
        values.append(raw_vals[i].as_float())
        i += 1
    return Telemetry(d["source"].as_string(), Int64(d["ts"].as_int()), tags^, values^)


def strings_to_toml(s: Strings) -> Dict[String, TomlValue]:
    var d = Dict[String, TomlValue]()
    var items = List[TomlValue]()
    var i = 0
    while i < len(s.items):
        items.append(_tv_str(s.items[i]))
        i += 1
    d["items"] = TomlValue(items^)
    return d^


def strings_from_toml(d: Dict[String, TomlValue]) raises -> Strings:
    var items = List[String]()
    var raw = d["items"].as_array()
    var i = 0
    while i < len(raw):
        items.append(raw[i].as_string())
        i += 1
    return Strings(items^)


def event_to_toml(e: Event) -> Dict[String, TomlValue]:
    var d = Dict[String, TomlValue]()
    d["event_id"] = _tv_str(e.event_id)
    d["event_type"] = _tv_str(e.event_type)
    d["occurred_at"] = _tv_int(Int(e.occurred_at))
    d["producer"] = _tv_str(e.producer)
    var attrs = List[TomlValue]()
    var i = 0
    while i < len(e.attrs):
        var a = Dict[String, TomlValue]()
        a["key"] = _tv_str(e.attrs[i].key)
        a["value"] = _tv_str(e.attrs[i].value)
        attrs.append(TomlValue(a^))
        i += 1
    d["attrs"] = TomlValue(attrs^)
    return d^


def event_from_toml(d: Dict[String, TomlValue]) raises -> Event:
    var attrs = List[EventAttr]()
    var raw = d["attrs"].as_array()
    var i = 0
    while i < len(raw):
        var a = raw[i].as_table()
        attrs.append(EventAttr(a["key"].as_string(), a["value"].as_string()))
        i += 1
    return Event(
        d["event_id"].as_string(),
        d["event_type"].as_string(),
        Int64(d["occurred_at"].as_int()),
        d["producer"].as_string(),
        attrs^,
    )


def fixture_to_toml(fx: Fixture) raises -> Dict[String, TomlValue]:
    if fx.n != 1:
        var items = List[TomlValue]()
        var i = 0
        if fx.type_id == "message":
            while i < len(fx.messages):
                items.append(TomlValue(message_to_toml(fx.messages[i])))
                i += 1
        elif fx.type_id == "document":
            while i < len(fx.documents):
                items.append(TomlValue(document_to_toml(fx.documents[i])))
                i += 1
        elif fx.type_id == "telemetry":
            while i < len(fx.telemetries):
                items.append(TomlValue(telemetry_to_toml(fx.telemetries[i])))
                i += 1
        elif fx.type_id == "strings":
            while i < len(fx.strings):
                items.append(TomlValue(strings_to_toml(fx.strings[i])))
                i += 1
        else:
            while i < len(fx.events):
                items.append(TomlValue(event_to_toml(fx.events[i])))
                i += 1
        var wrap = Dict[String, TomlValue]()
        wrap["items"] = TomlValue(items^)
        return wrap^
    if fx.type_id == "message":
        return message_to_toml(fx.messages[0])
    if fx.type_id == "document":
        return document_to_toml(fx.documents[0])
    if fx.type_id == "telemetry":
        return telemetry_to_toml(fx.telemetries[0])
    if fx.type_id == "strings":
        return strings_to_toml(fx.strings[0])
    return event_to_toml(fx.events[0])


def fixture_from_toml(fx: Fixture, d: Dict[String, TomlValue]) raises -> Fixture:
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
        var items = d["items"].as_array()
        var i = 0
        while i < len(items):
            var table = items[i].as_table()
            if fx.type_id == "message":
                out.messages.append(message_from_toml(table))
            elif fx.type_id == "document":
                out.documents.append(document_from_toml(table))
            elif fx.type_id == "telemetry":
                out.telemetries.append(telemetry_from_toml(table))
            elif fx.type_id == "strings":
                out.strings.append(strings_from_toml(table))
            else:
                out.events.append(event_from_toml(table))
            i += 1
        return out^
    if fx.type_id == "message":
        out.messages.append(message_from_toml(d))
    elif fx.type_id == "document":
        out.documents.append(document_from_toml(d))
    elif fx.type_id == "telemetry":
        out.telemetries.append(telemetry_from_toml(d))
    elif fx.type_id == "strings":
        out.strings.append(strings_from_toml(d))
    else:
        out.events.append(event_from_toml(d))
    return out^


struct TomlSer:
    var version: String

    def __init__(out self):
        self.version = "0.9.1"

    def name(self) -> String:
        return "mojo-toml"

    def serialize_bytes(self, fx: Fixture) raises -> String:
        return to_toml(fixture_to_toml(fx))

    def deserialize_bytes(self, fx: Fixture, data: String) raises -> Fixture:
        return fixture_from_toml(fx, parse(data))

    def check(self, fx: Fixture, data: String) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
