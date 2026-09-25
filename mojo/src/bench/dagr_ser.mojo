"""Dagr (Data Graph) on the suite types.

Schema: `schemas/v2/dagr/schema.py` -> `dagr build` -> `src/gen/dagr/` (one DataGraph
per suite type, all nodes `packed`, Telemetry `values` marked `raw`). The generated
modules import each other by bare name (`from dagr_writer import ...`), so the build
adds `-I src/gen/dagr`.

Serialize (timed): one `Builder` (`DirectBuilder`) is kept for the process and
`reset()` per instance; each graph's generated **direct builder** (`Direct{Node}` value
structs -> `write_{root}_graph_direct`, no arena) stores the record, which is appended
straight into the output buffer. Every field is set.

Deserialize (timed): the generated **lazy reader** (`read_{root}_root(bytes)`),
materialised into the owned suite value for the fidelity check.

N > 1 framing (same as the Rust harness): `u32 LE count`, then per instance
`u32 LE length` + one Dagr buffer.
"""

from std.collections import List
from dagr_writer import Builder
from message_graph_direct import DirectMessage, write_message_graph_direct
from strings_graph_direct import DirectStrings, write_strings_graph_direct
from document_graph_direct import (
    DirectDocument,
    DirectDocumentItem,
    DirectDocumentMeta,
    write_document_graph_direct,
)
from telemetry_graph_direct import DirectTelemetry, write_telemetry_graph_direct
from event_graph_direct import DirectEvent, DirectEventAttr, write_event_graph_direct
from message_graph_reader import read_message_root
from strings_graph_reader import read_strings_root
from document_graph_reader import read_document_root
from telemetry_graph_reader import read_telemetry_root
from event_graph_reader import read_event_root
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

# Every generated module in this suite uses `_VT_MAX = 1` (packed nodes, no vtables),
# so one `Builder[1]` serves all five graphs.
comptime _VT = 1


def _s(v: Optional[String]) -> String:
    if v:
        return v.value()
    return String("")


# ── encode ──────────────────────────────────────────────────────────────────


# Append the record the builder holds to `out` (with a `u32 LE` length when batch-framed).
@always_inline
def _emit(mut b: Builder[_VT], mut out: List[UInt8], framed: Bool):
    if framed:
        _put_u32(out, b.cursor)
    b.emit_reversed_into(out)


def _enc_messages(mut b: Builder[_VT], ms: List[Message], mut out: List[UInt8], framed: Bool) raises:
    for i in range(len(ms)):
        ref m = ms[i]
        var v = DirectMessage(
            Optional(m.f_bool),
            Optional(m.f_int32),
            Optional(m.f_int64),
            Optional(m.f_float64),
            Optional(m.f_string),
            Optional(m.f_bool_2),
            Optional(m.f_int32_2),
            Optional(m.f_string_2),
        )
        b.reset()
        _ = write_message_graph_direct(b, v)
        _emit(b, out, framed)


def _enc_strings(mut b: Builder[_VT], ss: List[Strings], mut out: List[UInt8], framed: Bool) raises:
    for i in range(len(ss)):
        var v = DirectStrings(ss[i].items.copy())
        b.reset()
        _ = write_strings_graph_direct(b, v)
        _emit(b, out, framed)


def _enc_documents(mut b: Builder[_VT], ds: List[Document], mut out: List[UInt8], framed: Bool) raises:
    for k in range(len(ds)):
        ref d = ds[k]
        var items = List[DirectDocumentItem](capacity=len(d.items))
        for i in range(len(d.items)):
            ref it = d.items[i]
            items.append(DirectDocumentItem(Optional(it.sku), Optional(it.qty), Optional(it.price_minor)))
        var v = DirectDocument(
            Optional(d.id),
            Optional(d.status),
            Optional(DirectDocumentMeta(Optional(d.meta.region), Optional(d.meta.version))),
            items^,
        )
        b.reset()
        _ = write_document_graph_direct(b, v)
        _emit(b, out, framed)


def _enc_telemetries(mut b: Builder[_VT], ts: List[Telemetry], mut out: List[UInt8], framed: Bool) raises:
    for k in range(len(ts)):
        ref t = ts[k]
        var v = DirectTelemetry(Optional(t.source), Optional(t.ts), t.tags.copy(), t.values.copy())
        b.reset()
        _ = write_telemetry_graph_direct(b, v)
        _emit(b, out, framed)


def _enc_events(mut b: Builder[_VT], es: List[Event], mut out: List[UInt8], framed: Bool) raises:
    for k in range(len(es)):
        ref e = es[k]
        var attrs = List[DirectEventAttr](capacity=len(e.attrs))
        for i in range(len(e.attrs)):
            ref at = e.attrs[i]
            attrs.append(DirectEventAttr(Optional(at.key), Optional(at.value)))
        var v = DirectEvent(
            Optional(e.event_id),
            Optional(e.event_type),
            Optional(e.occurred_at),
            Optional(e.producer),
            attrs^,
        )
        b.reset()
        _ = write_event_graph_direct(b, v)
        _emit(b, out, framed)


# ── decode (lazy reader -> owned suite value) ──────────────────────────────


def _dec_message[o: ImmOrigin](buf: Span[UInt8, o]) raises -> Message:
    var m = read_message_root(buf)
    return Message(
        m.f_bool().or_else(False),
        m.f_int32().or_else(0),
        m.f_int64().or_else(0),
        m.f_float64().or_else(0.0),
        _s(m.f_string()),
        m.f_bool_2().or_else(False),
        m.f_int32_2().or_else(0),
        _s(m.f_string_2()),
    )


def _dec_strings[o: ImmOrigin](buf: Span[UInt8, o]) raises -> Strings:
    var s = read_strings_root(buf)
    var items = s.items()
    if items:
        return Strings(items.take().into_list())
    return Strings(List[String]())


def _dec_document[o: ImmOrigin](buf: Span[UInt8, o]) raises -> Document:
    var d = read_document_root(buf)
    var meta = DocumentMeta(String(""), 0)
    var om = d.meta()
    if om:
        var m = om.value()
        meta = DocumentMeta(_s(m.region()), m.version().or_else(0))
    var items = List[DocumentItem]()
    var oi = d.items()
    if oi:
        var arr = oi.value()
        items.reserve(len(arr))
        var it = arr.iter()
        for _ in range(len(arr)):
            var x = it.next()
            items.append(DocumentItem(_s(x.sku()), x.qty().or_else(0), x.price_minor().or_else(0)))
    return Document(_s(d.id()), d.status().or_else(0), meta^, items^)


def _dec_telemetry[o: ImmOrigin](buf: Span[UInt8, o]) raises -> Telemetry:
    var t = read_telemetry_root(buf)
    var tags = List[String]()
    var ot = t.tags()
    if ot:
        tags = ot.take().into_list()
    var values = List[Float64]()
    var ov = t.values()
    if ov:
        values = ov.value().into_list()
    return Telemetry(_s(t.source()), t.ts().or_else(0), tags^, values^)


def _dec_event[o: ImmOrigin](buf: Span[UInt8, o]) raises -> Event:
    var e = read_event_root(buf)
    var attrs = List[EventAttr]()
    var oa = e.attrs()
    if oa:
        var arr = oa.value()
        attrs.reserve(len(arr))
        var it = arr.iter()
        for _ in range(len(arr)):
            var x = it.next()
            attrs.append(EventAttr(_s(x.key()), _s(x.value())))
    return Event(_s(e.event_id()), _s(e.event_type()), e.occurred_at().or_else(0), _s(e.producer()), attrs^)


# ── framing helpers ─────────────────────────────────────────────────────────


@always_inline
def _put_u32(mut out: List[UInt8], v: Int):
    out.append(UInt8(v & 0xFF))
    out.append(UInt8((v >> 8) & 0xFF))
    out.append(UInt8((v >> 16) & 0xFF))
    out.append(UInt8((v >> 24) & 0xFF))


@always_inline
def _get_u32(buf: Span[UInt8, _], at: Int) raises -> Int:
    if at + 4 > len(buf):
        raise Error("dagr: truncated batch frame")
    return Int(buf[at]) | (Int(buf[at + 1]) << 8) | (Int(buf[at + 2]) << 16) | (Int(buf[at + 3]) << 24)


struct DagrSer(Movable):
    var version: String
    var _b: Builder[_VT]
    var _hint: Int   # last output size: pre-reserves the batch output buffer

    def __init__(out self):
        # Generator version from schemas/v2/dagr/dagr.lock.json ("tool_version": "dagr 2026.9.0").
        self.version = "2026.9.0"
        self._b = Builder[_VT](hint=64)
        self._hint = 0

    def name(self) -> String:
        return "dagr"

    def supports(self, type_id: String) -> Bool:
        return (
            type_id == "message"
            or type_id == "document"
            or type_id == "telemetry"
            or type_id == "strings"
            or type_id == "event"
        )

    def serialize_bytes(mut self, fx: Fixture) raises -> List[Byte]:
        var out = List[UInt8](capacity=self._hint)
        var framed = fx.n != 1
        if framed:
            _put_u32(out, fx.n)
        if fx.type_id == "message":
            _enc_messages(self._b, fx.messages, out, framed)
        elif fx.type_id == "document":
            _enc_documents(self._b, fx.documents, out, framed)
        elif fx.type_id == "telemetry":
            _enc_telemetries(self._b, fx.telemetries, out, framed)
        elif fx.type_id == "strings":
            _enc_strings(self._b, fx.strings, out, framed)
        elif fx.type_id == "event":
            _enc_events(self._b, fx.events, out, framed)
        else:
            raise Error("dagr: unsupported type " + fx.type_id)
        self._hint = len(out)
        return out^

    def _decode_one(self, fx: Fixture, buf: Span[UInt8, _], mut out: Fixture) raises:
        if fx.type_id == "message":
            out.messages.append(_dec_message(buf))
        elif fx.type_id == "document":
            out.documents.append(_dec_document(buf))
        elif fx.type_id == "telemetry":
            out.telemetries.append(_dec_telemetry(buf))
        elif fx.type_id == "strings":
            out.strings.append(_dec_strings(buf))
        else:
            out.events.append(_dec_event(buf))

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
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
        var buf = Span(data)
        if fx.n == 1:
            self._decode_one(fx, buf, out)
            return out^
        var n = _get_u32(buf, 0)
        if n != fx.n:
            raise Error("dagr: batch count " + String(n) + " != " + String(fx.n))
        var o = 4
        for _ in range(n):
            var ln = _get_u32(buf, o)
            o += 4
            if o + ln > len(buf):
                raise Error("dagr: truncated batch payload")
            self._decode_one(fx, buf[o : o + ln], out)
            o += ln
        return out^

    def check(mut self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
