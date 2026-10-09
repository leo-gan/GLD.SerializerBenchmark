"""Dagr (Data Graph), `regular` layout, on the suite types — row `dagr-regular`.

Schema: `schemas/v2/dagr/schema.py` -> `dagr build` -> `src/gen/dagr/` (the
`<Type>RegularGraph` graphs: every node `regular` — vtable-addressed, field presence in
the vtable, `deletable=False`). The generated modules share node/struct names across the
four layouts, so everything is imported under an alias.

Serialize (timed): a `regular` graph has no generated direct builder (the direct builder
is emitted for packed-rooted graphs only), so each instance is copied into a fresh
generated **arena** and written with `write_<root>_graph(b, arena)` into one builder
per graph that is kept for the process and `reset()` per instance. The arena build stays
inside the timer, matching the `dagr-packed` row (conversion inside the timer, like the
mojo-protobuf peer). Every field is set.

Deserialize (timed): the generated **lazy reader** (`read_<root>_root(bytes)`),
materialised into the owned suite value for the fidelity check.

N > 1 framing (same as `dagr-packed`): `u32 LE count`, then per instance `u32 LE length` + one
Dagr buffer.
"""

from std.collections import Dict, List
from dagr_writer import Builder
from message_regular_graph_arena import MessageRegularGraphArena
from message_regular_graph_serde import write_message_graph, _VT_MAX as _VT_MESSAGE
from strings_regular_graph_arena import StringsRegularGraphArena
from strings_regular_graph_serde import write_strings_graph, _VT_MAX as _VT_STRINGS
from document_regular_graph_arena import (
    DocumentRegularGraphArena,
    DocumentItem as ArenaDocumentItem,
)
from document_regular_graph_serde import write_document_graph, _VT_MAX as _VT_DOCUMENT
from telemetry_regular_graph_arena import TelemetryRegularGraphArena
from telemetry_regular_graph_serde import write_telemetry_graph, _VT_MAX as _VT_TELEMETRY
from event_regular_graph_arena import EventRegularGraphArena, EventAttr as ArenaEventAttr
from event_regular_graph_serde import write_event_graph, _VT_MAX as _VT_EVENT
from graph_regular_graph_arena import (
    GraphRegularGraphArena,
    Order as OrderNode,
    Person as PersonNode,
    Region as RegionNode,
)
from graph_regular_graph_serde import write_book_graph, _VT_MAX as _VT_GRAPH
from graph_regular_graph_reader import read_book_root
from message_regular_graph_reader import read_message_root
from strings_regular_graph_reader import read_strings_root
from document_regular_graph_reader import read_document_root
from telemetry_regular_graph_reader import read_telemetry_root
from event_regular_graph_reader import read_event_root
from bench.dagr_ser import _get_u32, _put_u32, _s
from bench.data import (
    Book,
    Document,
    DocumentItem,
    DocumentMeta,
    Event,
    EventAttr,
    Fixture,
    Message,
    Order,
    Person,
    Region,
    Strings,
    Telemetry,
    fidelity,
)


# ── encode ──────────────────────────────────────────────────────────────────


# Append the record the builder holds to `out` (with a `u32 LE` length when batch-framed).
# Generic over the builder's vtable width: each regular graph has its own `_VT_MAX`.
@always_inline
def _emit[vt: Int](mut b: Builder[vt], mut out: List[UInt8], framed: Bool):
    if framed:
        _put_u32(out, b.cursor)
    b.emit_reversed_into(out)


def _enc_messages(mut b: Builder[_VT_MESSAGE], ms: List[Message], mut out: List[UInt8], framed: Bool) raises:
    for i in range(len(ms)):
        ref m = ms[i]
        var a = MessageRegularGraphArena()
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
        var a = StringsRegularGraphArena()
        var r = a.new_strings()
        r.set_items(ss[i].items.copy())
        a.set_root(r)
        b.reset()
        _ = write_strings_graph(b, a)
        _emit(b, out, framed)


def _enc_documents(mut b: Builder[_VT_DOCUMENT], ds: List[Document], mut out: List[UInt8], framed: Bool) raises:
    for k in range(len(ds)):
        ref d = ds[k]
        var a = DocumentRegularGraphArena()
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
        var a = TelemetryRegularGraphArena()
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
        var a = EventRegularGraphArena()
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


def _enc_books(mut b: Builder[_VT_GRAPH], books: List[Book], mut out: List[UInt8], framed: Bool) raises:
    for k in range(len(books)):
        ref g = books[k]
        var a = GraphRegularGraphArena()
        # One region node per index; each order reuses that handle, not a copy.
        var regions = List[RegionNode[origin_of(a)]](capacity=len(g.regions))
        for i in range(len(g.regions)):
            ref r = g.regions[i]
            regions.append(a.new_region(r.code, r.note, r.version))
        var orders = List[OrderNode[origin_of(a)]](capacity=len(g.orders))
        for i in range(len(g.orders)):
            ref o = g.orders[i]
            if o.region_index < 0 or o.region_index >= len(regions):
                raise Error("dagr-regular: region index out of range")
            var h = a.new_order(o.sku, o.qty)
            h.set_region(regions[o.region_index])
            orders.append(h^)
        var people = List[PersonNode[origin_of(a)]](capacity=len(g.people))
        for i in range(len(g.people)):
            people.append(a.new_person(g.people[i].name))
        for i in range(len(people)):
            var nxt = g.people[i].next_index
            if nxt < 0 or nxt >= len(people):
                raise Error("dagr-regular: person next index out of range")
            people[i].set_next(people[nxt])
        var root = a.new_book()
        root.set_orders(orders^)
        root.set_people(people^)
        a.set_root(root)
        b.reset()
        _ = write_book_graph(b, a)
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
        values = ov.value().to_list()   # one block copy (Dagr spec/43)
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


def _dec_book[o: ImmOrigin](buf: Span[UInt8, o]) raises -> Book:
    var root = read_book_root(buf)
    var regions = List[Region]()
    var orders = List[Order]()
    var region_at = Dict[Int, Int]()
    var oo = root.orders()
    if not oo:
        raise Error("dagr-regular: book missing orders")
    var oarr = oo.value()
    for i in range(len(oarr)):
        var od = oarr.get(i)
        var reg = od.region()
        if not reg:
            raise Error("dagr-regular: order missing region")
        var acc = reg.value()
        var rp = acc.pos
        var ri = len(regions)
        if rp in region_at:
            ri = region_at[rp]
        else:
            region_at[rp] = ri
            regions.append(Region(_s(acc.code()), _s(acc.note()), acc.version().or_else(0)))
        orders.append(Order(_s(od.sku()), od.qty().or_else(0), ri))
    var names = List[String]()
    var nexts = List[Int]()
    var person_at = Dict[Int, Int]()
    var op = root.people()
    if not op:
        raise Error("dagr-regular: book missing people")
    var parr = op.value()
    for i in range(len(parr)):
        var p = parr.get(i)
        person_at[p.pos] = i
        names.append(_s(p.name()))
    for i in range(len(parr)):
        var p = parr.get(i)
        var nxt = p.next()
        if not nxt:
            raise Error("dagr-regular: person missing next")
        var np = nxt.value().pos
        if np not in person_at:
            raise Error("dagr-regular: person next is outside the ring")
        nexts.append(person_at[np])
    var people = List[Person]()
    for i in range(len(names)):
        people.append(Person(names[i].copy(), nexts[i]))
    return Book(regions^, orders^, people^)


struct DagrRegularSer(Movable):
    var version: String
    var _bm: Builder[_VT_MESSAGE]
    var _bs: Builder[_VT_STRINGS]
    var _bd: Builder[_VT_DOCUMENT]
    var _bt: Builder[_VT_TELEMETRY]
    var _be: Builder[_VT_EVENT]
    var _bg: Builder[_VT_GRAPH]
    var _hint: Int   # last output size: pre-reserves the batch output buffer

    def __init__(out self):
        # Generator version from schemas/v2/dagr/dagr.lock.json ("tool_version": "dagr 2026.10.1").
        self.version = "2026.10.1"
        self._bm = Builder[_VT_MESSAGE](hint=64)
        self._bs = Builder[_VT_STRINGS](hint=64)
        self._bd = Builder[_VT_DOCUMENT](hint=64)
        self._bt = Builder[_VT_TELEMETRY](hint=64)
        self._be = Builder[_VT_EVENT](hint=64)
        self._bg = Builder[_VT_GRAPH](hint=256)
        self._hint = 0

    def name(self) -> String:
        return "dagr-regular"

    def supports(self, type_id: String) -> Bool:
        return (
            type_id == "message"
            or type_id == "document"
            or type_id == "telemetry"
            or type_id == "strings"
            or type_id == "event"
            or type_id == "graph"
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
        elif fx.type_id == "graph":
            _enc_books(self._bg, fx.books, out, framed)
        else:
            raise Error("dagr-regular: unsupported type " + fx.type_id)
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
        elif fx.type_id == "graph":
            out.books.append(_dec_book(buf))
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
            raise Error("dagr-regular: batch count " + String(n) + " != " + String(fx.n))
        var o = 4
        for _ in range(n):
            var ln = _get_u32(buf, o)
            o += 4
            if o + ln > len(buf):
                raise Error("dagr-regular: truncated batch payload")
            self._decode_one(fx, buf[o : o + ln], out)
            o += ln
        return out^

    def check(mut self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
