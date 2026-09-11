"""mojo-yaml (gld-yaml) — YamlValue encode / decode on suite types."""

from std.collections import List
from yaml import DecodeError, EncodeOptions, WireReader, WireWriter
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


def _nl_key(mut w: WireWriter, key: String, first: Bool):
    if not first:
        w.write_ascii("\n")
    w.write_ascii(key)
    w.write_ascii(": ")


def message_to_writer(m: Message, mut w: WireWriter, options: EncodeOptions):
    _nl_key(w, "f_bool", True)
    w.write_bool(m.f_bool)
    _nl_key(w, "f_int32", False)
    w.write_int(Int64(m.f_int32))
    _nl_key(w, "f_int64", False)
    w.write_int(m.f_int64)
    _nl_key(w, "f_float64", False)
    w.write_float(m.f_float64)
    _nl_key(w, "f_string", False)
    w.write_string(m.f_string, options)
    _nl_key(w, "f_bool_2", False)
    w.write_bool(m.f_bool_2)
    _nl_key(w, "f_int32_2", False)
    w.write_int(Int64(m.f_int32_2))
    _nl_key(w, "f_string_2", False)
    w.write_string(m.f_string_2, options)


def message_from_reader[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Message:
    var m = Message()
    var st = r.begin_map()
    if r.next_key(st) and r.try_key("f_bool".as_bytes()):
        m.f_bool = r.read_bool()
    if r.next_key(st) and r.try_key("f_int32".as_bytes()):
        m.f_int32 = Int32(r.read_int())
    if r.next_key(st) and r.try_key("f_int64".as_bytes()):
        m.f_int64 = r.read_int()
    if r.next_key(st) and r.try_key("f_float64".as_bytes()):
        m.f_float64 = r.read_float()
    if r.next_key(st) and r.try_key("f_string".as_bytes()):
        m.f_string = r.read_string()
    if r.next_key(st) and r.try_key("f_bool_2".as_bytes()):
        m.f_bool_2 = r.read_bool()
    if r.next_key(st) and r.try_key("f_int32_2".as_bytes()):
        m.f_int32_2 = Int32(r.read_int())
    if r.next_key(st) and r.try_key("f_string_2".as_bytes()):
        m.f_string_2 = r.read_string()
    while r.next_key(st):
        r.skip_pair()
    r.end_map(st)
    return m^


def document_to_writer(d: Document, mut w: WireWriter, options: EncodeOptions):
    _nl_key(w, "id", True)
    w.write_string(d.id, options)
    _nl_key(w, "status", False)
    w.write_int(Int64(d.status))
    w.write_ascii("\nmeta:\n  region: ")
    w.write_string(d.meta.region, options)
    w.write_ascii("\n  version: ")
    w.write_int(Int64(d.meta.version))
    w.write_ascii("\nitems:")
    var i = 0
    while i < len(d.items):
        w.write_ascii("\n- sku: ")
        w.write_string(d.items[i].sku, options)
        w.write_ascii("\n  qty: ")
        w.write_int(Int64(d.items[i].qty))
        w.write_ascii("\n  price_minor: ")
        w.write_int(d.items[i].price_minor)
        i += 1
    if len(d.items) == 0:
        w.write_ascii(" []")


def document_from_reader[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Document:
    var d = Document()
    d.items = List[DocumentItem]()
    var st = r.begin_map()
    if r.next_key(st) and r.try_key("id".as_bytes()):
        d.id = r.read_string()
    if r.next_key(st) and r.try_key("status".as_bytes()):
        d.status = Int32(r.read_int())
    if r.next_key(st) and r.try_key("meta".as_bytes()):
        var mst = r.begin_map()
        if r.next_key(mst) and r.try_key("region".as_bytes()):
            d.meta.region = r.read_string()
        if r.next_key(mst) and r.try_key("version".as_bytes()):
            d.meta.version = Int32(r.read_int())
        while r.next_key(mst):
            r.skip_pair()
        r.end_map(mst)
    if r.next_key(st) and r.try_key("items".as_bytes()):
        var sst = r.begin_seq()
        while r.next_item(sst):
            var it = DocumentItem()
            var ist = r.begin_map()
            if r.next_key(ist) and r.try_key("sku".as_bytes()):
                it.sku = r.read_string()
            if r.next_key(ist) and r.try_key("qty".as_bytes()):
                it.qty = Int32(r.read_int())
            if r.next_key(ist) and r.try_key("price_minor".as_bytes()):
                it.price_minor = r.read_int()
            while r.next_key(ist):
                r.skip_pair()
            r.end_map(ist)
            d.items.append(it^)
        r.end_seq(sst)
    while r.next_key(st):
        r.skip_pair()
    r.end_map(st)
    return d^


def telemetry_to_writer(t: Telemetry, mut w: WireWriter, options: EncodeOptions):
    _nl_key(w, "source", True)
    w.write_string(t.source, options)
    _nl_key(w, "ts", False)
    w.write_int(t.ts)
    w.write_ascii("\ntags:")
    var i = 0
    while i < len(t.tags):
        w.write_ascii("\n- ")
        w.write_string(t.tags[i], options)
        i += 1
    if len(t.tags) == 0:
        w.write_ascii(" []")
    w.write_ascii("\nvalues:")
    i = 0
    while i < len(t.values):
        w.write_ascii("\n- ")
        w.write_float(t.values[i])
        i += 1
    if len(t.values) == 0:
        w.write_ascii(" []")


def telemetry_from_reader[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Telemetry:
    var t = Telemetry()
    var st = r.begin_map()
    if r.next_key(st) and r.try_key("source".as_bytes()):
        t.source = r.read_string()
    if r.next_key(st) and r.try_key("ts".as_bytes()):
        t.ts = r.read_int()
    if r.next_key(st) and r.try_key("tags".as_bytes()):
        var sst = r.begin_seq()
        while r.next_item(sst):
            t.tags.append(r.read_string())
        r.end_seq(sst)
    if r.next_key(st) and r.try_key("values".as_bytes()):
        var vst = r.begin_seq()
        while r.next_item(vst):
            t.values.append(r.read_float())
        r.end_seq(vst)
    while r.next_key(st):
        r.skip_pair()
    r.end_map(st)
    return t^


def strings_to_writer(s: Strings, mut w: WireWriter, options: EncodeOptions):
    w.write_ascii("items:")
    var i = 0
    while i < len(s.items):
        w.write_ascii("\n- ")
        w.write_string(s.items[i], options)
        i += 1
    if len(s.items) == 0:
        w.write_ascii(" []")


def strings_from_reader[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Strings:
    var s = Strings()
    var st = r.begin_map()
    if r.next_key(st) and r.try_key("items".as_bytes()):
        var sst = r.begin_seq()
        while r.next_item(sst):
            s.items.append(r.read_string())
        r.end_seq(sst)
    while r.next_key(st):
        r.skip_pair()
    r.end_map(st)
    return s^


def event_to_writer(e: Event, mut w: WireWriter, options: EncodeOptions):
    _nl_key(w, "event_id", True)
    w.write_string(e.event_id, options)
    _nl_key(w, "event_type", False)
    w.write_string(e.event_type, options)
    _nl_key(w, "occurred_at", False)
    w.write_int(e.occurred_at)
    _nl_key(w, "producer", False)
    w.write_string(e.producer, options)
    w.write_ascii("\nattrs:")
    var i = 0
    while i < len(e.attrs):
        w.write_ascii("\n- key: ")
        w.write_string(e.attrs[i].key, options)
        w.write_ascii("\n  value: ")
        w.write_string(e.attrs[i].value, options)
        i += 1
    if len(e.attrs) == 0:
        w.write_ascii(" []")


def event_from_reader[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Event:
    var e = Event()
    e.attrs = List[EventAttr]()
    var st = r.begin_map()
    if r.next_key(st) and r.try_key("event_id".as_bytes()):
        e.event_id = r.read_string()
    if r.next_key(st) and r.try_key("event_type".as_bytes()):
        e.event_type = r.read_string()
    if r.next_key(st) and r.try_key("occurred_at".as_bytes()):
        e.occurred_at = r.read_int()
    if r.next_key(st) and r.try_key("producer".as_bytes()):
        e.producer = r.read_string()
    if r.next_key(st) and r.try_key("attrs".as_bytes()):
        var ast = r.begin_seq()
        while r.next_item(ast):
            var a = EventAttr()
            var ist = r.begin_map()
            if r.next_key(ist) and r.try_key("key".as_bytes()):
                a.key = r.read_string()
            if r.next_key(ist) and r.try_key("value".as_bytes()):
                a.value = r.read_string()
            while r.next_key(ist):
                r.skip_pair()
            r.end_map(ist)
            e.attrs.append(a^)
        r.end_seq(ast)
    while r.next_key(st):
        r.skip_pair()
    r.end_map(st)
    return e^


def fixture_to_writer(fx: Fixture, mut w: WireWriter, options: EncodeOptions) raises DecodeError:
    if fx.n != 1:
        w.write_ascii("items:")
        var i = 0
        if fx.type_id == "message":
            while i < len(fx.messages):
                w.write_ascii("\n- ")
                message_to_writer(fx.messages[i], w, options)
                i += 1
        elif fx.type_id == "document":
            while i < len(fx.documents):
                w.write_ascii("\n- ")
                document_to_writer(fx.documents[i], w, options)
                i += 1
        elif fx.type_id == "telemetry":
            while i < len(fx.telemetries):
                w.write_ascii("\n- ")
                telemetry_to_writer(fx.telemetries[i], w, options)
                i += 1
        elif fx.type_id == "strings":
            while i < len(fx.strings):
                w.write_ascii("\n- ")
                strings_to_writer(fx.strings[i], w, options)
                i += 1
        else:
            while i < len(fx.events):
                w.write_ascii("\n- ")
                event_to_writer(fx.events[i], w, options)
                i += 1
        return
    if fx.type_id == "message":
        message_to_writer(fx.messages[0], w, options)
    elif fx.type_id == "document":
        document_to_writer(fx.documents[0], w, options)
    elif fx.type_id == "telemetry":
        telemetry_to_writer(fx.telemetries[0], w, options)
    elif fx.type_id == "strings":
        strings_to_writer(fx.strings[0], w, options)
    else:
        event_to_writer(fx.events[0], w, options)


def fixture_from_bytes(fx: Fixture, data: List[Byte]) raises DecodeError -> Fixture:
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
    var r = WireReader(data)
    r.skip_document_start()
    if fx.n != 1:
        var st = r.begin_map()
        if r.next_key(st) and r.try_key("items".as_bytes()):
            var sst = r.begin_seq()
            while r.next_item(sst):
                if fx.type_id == "message":
                    out.messages.append(message_from_reader(r))
                elif fx.type_id == "document":
                    out.documents.append(document_from_reader(r))
                elif fx.type_id == "telemetry":
                    out.telemetries.append(telemetry_from_reader(r))
                elif fx.type_id == "strings":
                    out.strings.append(strings_from_reader(r))
                else:
                    out.events.append(event_from_reader(r))
            r.end_seq(sst)
        while r.next_key(st):
            r.skip_pair()
        r.end_map(st)
        r.skip_document_end()
        return out^
    if fx.type_id == "message":
        out.messages.append(message_from_reader(r))
    elif fx.type_id == "document":
        out.documents.append(document_from_reader(r))
    elif fx.type_id == "telemetry":
        out.telemetries.append(telemetry_from_reader(r))
    elif fx.type_id == "strings":
        out.strings.append(strings_from_reader(r))
    else:
        out.events.append(event_from_reader(r))
    r.skip_document_end()
    return out^


struct YamlSer:
    var version: String

    def __init__(out self):
        self.version = "0.2.0"

    def name(self) -> String:
        return "mojo-yaml"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var w = WireWriter(capacity=1024 if fx.n == 1 else 65536)
        fixture_to_writer(fx, w, EncodeOptions.block)
        w.write_lf()
        return w^.finish()

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        return fixture_from_bytes(fx, data)

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
