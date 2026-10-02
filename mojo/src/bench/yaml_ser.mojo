"""gld-yaml — YamlValue encode / decode on suite types."""

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


def _key(
    mut w: WireWriter,
    key: StaticString,
    options: EncodeOptions,
    depth: Int,
    first: Bool,
    inline_first: Bool,
    nested: Bool,
):
    """Block-map key at `depth`, matching gld-yaml `encode_to_at`.

    A scalar keeps `: `. A nested value keeps `:` so the break stays tight.
    Continuation lines inside a `- ` item use `depth` so they share the first
    key's column. Column 0 would end the map and drop the rest of the record.
    """
    if not first:
        if depth == 0:
            w.write_ascii("\n")
        else:
            w.write_lf()
            w.indent_depth = depth
            w.write_indent(options)
    elif not inline_first:
        w.indent_depth = depth
        w.write_indent(options)
    w.write_ascii(key)
    if nested:
        w.write_ascii(":")
    else:
        w.write_ascii(": ")


def _seq_dash(mut w: WireWriter, options: EncodeOptions, depth: Int):
    w.write_lf()
    w.indent_depth = depth
    w.write_indent(options)
    w.write_ascii("- ")


def message_to_writer(
    m: Message,
    mut w: WireWriter,
    options: EncodeOptions,
    depth: Int,
    inline_first: Bool,
):
    _key(w, "f_bool", options, depth, True, inline_first, False)
    w.write_bool(m.f_bool)
    _key(w, "f_int32", options, depth, False, inline_first, False)
    w.write_int(Int64(m.f_int32))
    _key(w, "f_int64", options, depth, False, inline_first, False)
    w.write_int(m.f_int64)
    _key(w, "f_float64", options, depth, False, inline_first, False)
    w.write_float(m.f_float64)
    _key(w, "f_string", options, depth, False, inline_first, False)
    w.write_string(m.f_string, options)
    _key(w, "f_bool_2", options, depth, False, inline_first, False)
    w.write_bool(m.f_bool_2)
    _key(w, "f_int32_2", options, depth, False, inline_first, False)
    w.write_int(Int64(m.f_int32_2))
    _key(w, "f_string_2", options, depth, False, inline_first, False)
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


def document_to_writer(
    d: Document,
    mut w: WireWriter,
    options: EncodeOptions,
    depth: Int,
    inline_first: Bool,
):
    _key(w, "id", options, depth, True, inline_first, False)
    w.write_string(d.id, options)
    _key(w, "status", options, depth, False, inline_first, False)
    w.write_int(Int64(d.status))
    _key(w, "meta", options, depth, False, inline_first, True)
    w.write_lf()
    _key(w, "region", options, depth + 1, True, False, False)
    w.write_string(d.meta.region, options)
    _key(w, "version", options, depth + 1, False, False, False)
    w.write_int(Int64(d.meta.version))
    _key(w, "items", options, depth, False, inline_first, True)
    var i = 0
    while i < len(d.items):
        _seq_dash(w, options, depth)
        _key(w, "sku", options, depth + 1, True, True, False)
        w.write_string(d.items[i].sku, options)
        _key(w, "qty", options, depth + 1, False, True, False)
        w.write_int(Int64(d.items[i].qty))
        _key(w, "price_minor", options, depth + 1, False, True, False)
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


def telemetry_to_writer(
    t: Telemetry,
    mut w: WireWriter,
    options: EncodeOptions,
    depth: Int,
    inline_first: Bool,
):
    _key(w, "source", options, depth, True, inline_first, False)
    w.write_string(t.source, options)
    _key(w, "ts", options, depth, False, inline_first, False)
    w.write_int(t.ts)
    _key(w, "tags", options, depth, False, inline_first, True)
    var i = 0
    while i < len(t.tags):
        _seq_dash(w, options, depth)
        w.write_string(t.tags[i], options)
        i += 1
    if len(t.tags) == 0:
        w.write_ascii(" []")
    _key(w, "values", options, depth, False, inline_first, True)
    i = 0
    while i < len(t.values):
        _seq_dash(w, options, depth)
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


def strings_to_writer(
    s: Strings,
    mut w: WireWriter,
    options: EncodeOptions,
    depth: Int,
    inline_first: Bool,
):
    _key(w, "items", options, depth, True, inline_first, True)
    var i = 0
    while i < len(s.items):
        _seq_dash(w, options, depth)
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


def event_to_writer(
    e: Event,
    mut w: WireWriter,
    options: EncodeOptions,
    depth: Int,
    inline_first: Bool,
):
    _key(w, "event_id", options, depth, True, inline_first, False)
    w.write_string(e.event_id, options)
    _key(w, "event_type", options, depth, False, inline_first, False)
    w.write_string(e.event_type, options)
    _key(w, "occurred_at", options, depth, False, inline_first, False)
    w.write_int(e.occurred_at)
    _key(w, "producer", options, depth, False, inline_first, False)
    w.write_string(e.producer, options)
    _key(w, "attrs", options, depth, False, inline_first, True)
    var i = 0
    while i < len(e.attrs):
        _seq_dash(w, options, depth)
        _key(w, "key", options, depth + 1, True, True, False)
        w.write_string(e.attrs[i].key, options)
        _key(w, "value", options, depth + 1, False, True, False)
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
        var wrote = False
        if fx.type_id == "message":
            while i < len(fx.messages):
                _seq_dash(w, options, 0)
                message_to_writer(fx.messages[i], w, options, 1, True)
                i += 1
                wrote = True
        elif fx.type_id == "document":
            while i < len(fx.documents):
                _seq_dash(w, options, 0)
                document_to_writer(fx.documents[i], w, options, 1, True)
                i += 1
                wrote = True
        elif fx.type_id == "telemetry":
            while i < len(fx.telemetries):
                _seq_dash(w, options, 0)
                telemetry_to_writer(fx.telemetries[i], w, options, 1, True)
                i += 1
                wrote = True
        elif fx.type_id == "strings":
            while i < len(fx.strings):
                _seq_dash(w, options, 0)
                strings_to_writer(fx.strings[i], w, options, 1, True)
                i += 1
                wrote = True
        else:
            while i < len(fx.events):
                _seq_dash(w, options, 0)
                event_to_writer(fx.events[i], w, options, 1, True)
                i += 1
                wrote = True
        if not wrote:
            w.write_ascii(" []")
        return
    if fx.type_id == "message":
        message_to_writer(fx.messages[0], w, options, 0, False)
    elif fx.type_id == "document":
        document_to_writer(fx.documents[0], w, options, 0, False)
    elif fx.type_id == "telemetry":
        telemetry_to_writer(fx.telemetries[0], w, options, 0, False)
    elif fx.type_id == "strings":
        strings_to_writer(fx.strings[0], w, options, 0, False)
    else:
        event_to_writer(fx.events[0], w, options, 0, False)


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
        self.version = "0.6.0"

    def name(self) -> String:
        return "gld-yaml"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var w = WireWriter(capacity=1024 if fx.n == 1 else 65536)
        fixture_to_writer(fx, w, EncodeOptions.block)
        w.write_lf()
        return w^.finish()

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        return fixture_from_bytes(fx, data)

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
