"""Dagr (Data Graph), `frozen` layout, on the suite types — row `dagr-frozen`.

Schema: `schemas/v2/dagr/schema.py` -> `dagr build` -> `src/gen/dagr/` (the
`<Type>FrozenGraph` graphs: every node `frozen` — fixed struct layout, no vtable, no
schema evolution, `deletable=False`). The generated modules share node/struct names across the
four layouts, so everything is imported under an alias.

Serialize (timed): a `frozen` graph has no generated direct builder (the direct builder
is emitted for packed-rooted graphs only), so each instance is copied into a fresh
generated **arena** and written with `write_<root>_graph(b, arena)` into one builder
per graph that is kept for the process and `reset()` per instance. The arena build stays
inside the timer, matching the `dagr` row (conversion inside the timer, like the
mojo-protobuf peer). Every field is set.

Deserialize (timed): the generated **lazy reader** (`read_<root>_root(bytes)`),
materialised into the owned suite value for the fidelity check.

N > 1 framing (same as `dagr`): `u32 LE count`, then per instance `u32 LE length` + one
Dagr buffer.
"""

from std.collections import List
from dagr_writer import Builder
from message_frozen_graph_arena import MessageFrozenGraphArena
from message_frozen_graph_serde import write_message_graph, _VT_MAX as _VT_MESSAGE
from strings_frozen_graph_arena import StringsFrozenGraphArena
from strings_frozen_graph_serde import write_strings_graph, _VT_MAX as _VT_STRINGS
from document_frozen_graph_arena import (
    DocumentFrozenGraphArena,
    DocumentItem as ArenaDocumentItem,
)
from document_frozen_graph_serde import write_document_graph, _VT_MAX as _VT_DOCUMENT
from telemetry_frozen_graph_arena import TelemetryFrozenGraphArena
from telemetry_frozen_graph_serde import write_telemetry_graph, _VT_MAX as _VT_TELEMETRY
from event_frozen_graph_arena import EventFrozenGraphArena, EventAttr as ArenaEventAttr
from event_frozen_graph_serde import write_event_graph, _VT_MAX as _VT_EVENT
from message_frozen_graph_reader import read_message_root
from strings_frozen_graph_reader import read_strings_root
from document_frozen_graph_reader import read_document_root
from telemetry_frozen_graph_reader import read_telemetry_root
from event_frozen_graph_reader import read_event_root
from bench.dagr_ser import _get_u32, _put_u32, _s
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


# ── encode ──────────────────────────────────────────────────────────────────


# Append the record the builder holds to `out` (with a `u32 LE` length when batch-framed).
# Generic over the builder's vtable width: each graph declares its own `_VT_MAX`.
@always_inline
def _emit[vt: Int](mut b: Builder[vt], mut out: List[UInt8], framed: Bool):
    if framed:
        _put_u32(out, b.cursor)
    b.emit_reversed_into(out)


def _enc_messages(mut b: Builder[_VT_MESSAGE], ms: List[Message], mut out: List[UInt8], framed: Bool) raises:
    for i in range(len(ms)):
        ref m = ms[i]
        var a = MessageFrozenGraphArena()
        var r = a.new_message(
            m.f_bool,
            m.f_int32,
            m.f_int64,
            m.f_float64,
            m.f_string,
            m.f_bool_2,
            m.f_int32_2,
            m.f_string_2,
        )
        a.set_root(r)
        b.reset()
        _ = write_message_graph(b, a)
        _emit(b, out, framed)


def _enc_strings(mut b: Builder[_VT_STRINGS], ss: List[Strings], mut out: List[UInt8], framed: Bool) raises:
    for i in range(len(ss)):
        var a = StringsFrozenGraphArena()
        var r = a.new_strings()
        r.set_items(ss[i].items.copy())
        a.set_root(r)
        b.reset()
        _ = write_strings_graph(b, a)
        _emit(b, out, framed)


def _enc_documents(mut b: Builder[_VT_DOCUMENT], ds: List[Document], mut out: List[UInt8], framed: Bool) raises:
    for k in range(len(ds)):
        ref d = ds[k]
        var a = DocumentFrozenGraphArena()
        var r = a.new_document(d.id, d.status)
        r.set_meta(a.new_document_meta(d.meta.region, d.meta.version))
        var items = List[ArenaDocumentItem[origin_of(a)]](capacity=len(d.items))
        for i in range(len(d.items)):
            ref it = d.items[i]
            items.append(a.new_document_item(it.sku, it.qty, it.price_minor))
        r.set_items(items)
        a.set_root(r)
        b.reset()
        _ = write_document_graph(b, a)
        _emit(b, out, framed)


def _enc_telemetries(mut b: Builder[_VT_TELEMETRY], ts: List[Telemetry], mut out: List[UInt8], framed: Bool) raises:
    for k in range(len(ts)):
        ref t = ts[k]
        var a = TelemetryFrozenGraphArena()
        var r = a.new_telemetry(t.source, t.ts)
        r.set_tags(t.tags.copy())
        r.set_values(t.values.copy())
        a.set_root(r)
        b.reset()
        _ = write_telemetry_graph(b, a)
        _emit(b, out, framed)


def _enc_events(mut b: Builder[_VT_EVENT], es: List[Event], mut out: List[UInt8], framed: Bool) raises:
    for k in range(len(es)):
        ref e = es[k]
        var a = EventFrozenGraphArena()
        var r = a.new_event(e.event_id, e.event_type, e.occurred_at, e.producer)
        var attrs = List[ArenaEventAttr[origin_of(a)]](capacity=len(e.attrs))
        for i in range(len(e.attrs)):
            ref at = e.attrs[i]
            attrs.append(a.new_event_attr(at.key, at.value))
        r.set_attrs(attrs)
        a.set_root(r)
        b.reset()
        _ = write_event_graph(b, a)
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
    var items = List[String]()
    var oi = s.items()
    if oi:
        # Regular/frozen utf8 arrays are pointer tables: `get(i)` is O(1).
        var arr = oi.value()
        items.reserve(len(arr))
        for i in range(len(arr)):
            items.append(arr.get(i))
    return Strings(items^)


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
        var arr = ot.value()
        tags.reserve(len(arr))
        for i in range(len(arr)):
            tags.append(arr.get(i))
    var values = List[Float64]()
    var ov = t.values()
    if ov:
        var arr = ov.value()
        values.reserve(len(arr))
        for i in range(len(arr)):
            values.append(arr.get(i))
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


struct DagrFrozenSer(Movable):
    var version: String
    var _bm: Builder[_VT_MESSAGE]
    var _bs: Builder[_VT_STRINGS]
    var _bd: Builder[_VT_DOCUMENT]
    var _bt: Builder[_VT_TELEMETRY]
    var _be: Builder[_VT_EVENT]
    var _hint: Int   # last output size: pre-reserves the batch output buffer

    def __init__(out self):
        # Generator version from schemas/v2/dagr/dagr.lock.json ("tool_version": "dagr 2026.9.0").
        self.version = "2026.9.0"
        self._bm = Builder[_VT_MESSAGE](hint=64)
        self._bs = Builder[_VT_STRINGS](hint=64)
        self._bd = Builder[_VT_DOCUMENT](hint=64)
        self._bt = Builder[_VT_TELEMETRY](hint=64)
        self._be = Builder[_VT_EVENT](hint=64)
        self._hint = 0

    def name(self) -> String:
        return "dagr-frozen"

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
            _enc_messages(self._bm, fx.messages, out, framed)
        elif fx.type_id == "document":
            _enc_documents(self._bd, fx.documents, out, framed)
        elif fx.type_id == "telemetry":
            _enc_telemetries(self._bt, fx.telemetries, out, framed)
        elif fx.type_id == "strings":
            _enc_strings(self._bs, fx.strings, out, framed)
        elif fx.type_id == "event":
            _enc_events(self._be, fx.events, out, framed)
        else:
            raise Error("dagr-frozen: unsupported type " + fx.type_id)
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
            raise Error("dagr-frozen: batch count " + String(n) + " != " + String(fx.n))
        var o = 4
        for _ in range(n):
            var ln = _get_u32(buf, o)
            o += 4
            if o + ln > len(buf):
                raise Error("dagr-frozen: truncated batch payload")
            self._decode_one(fx, buf[o : o + ln], out)
            o += ln
        return out^

    def check(mut self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
