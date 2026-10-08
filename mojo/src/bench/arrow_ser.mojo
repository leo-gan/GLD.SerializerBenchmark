"""gld-arrow IPC stream on the columnar types.

`encode_ipc_stream` / `decode_ipc_stream` are the library entry points.
The stream is the IPC stream, not the Arrow file. gld-arrow has no
included-fields reader, so `table_project` decodes the stream and then
materializes `f_float_0` only. Row-to-column conversion stays inside
serialize. Columns are non-null because the suite rows have no nulls.
"""

from std.collections import List, Span

from arrow_runtime.model import (
    TY_FLOAT,
    TY_INT,
    TY_LIST,
    TY_STRUCT,
    TY_UTF8,
    ArrayRec,
    Columnar,
    FieldRec,
    put_width,
    put_width_u,
    read_width,
)
from arrow_wire.ipc import decode_ipc_stream, encode_ipc_stream
from bench.data import (
    Document,
    Event,
    Fixture,
    Message,
    NestedItem,
    NestedMeta,
    NestedRow,
    SignalLeg,
    SignalRow,
    Strings,
    TableRow,
    Telemetry,
    fidelity,
)


def _bytes_of(text: String) -> List[Byte]:
    var raw = text.as_bytes()
    var out = List[Byte]()
    var i = 0
    while i < len(raw):
        out.append(raw[i])
        i += 1
    return out^


def _text_from(raw: List[Byte], start: Int, end: Int) -> String:
    var slice = List[Byte]()
    var i = start
    while i < end:
        slice.append(raw[i])
        i += 1
    return String(unsafe_from_utf8=Span(slice))


def _u64_at(raw: List[Byte], at: Int) -> UInt64:
    var x = UInt64(0)
    var k = 0
    while k < 8:
        x = x | (UInt64(Int(raw[at + k])) << UInt64(8 * k))
        k += 1
    return x


def _field(mut c: Columnar, name: String, kind: Int, width: Int, child0: Int, nchild: Int) -> Int:
    var f = FieldRec()
    f.name = c.intern(name)
    f.kind = kind
    f.nullable = 0
    f.bit_width = width
    f.is_signed = 1
    f.child0 = child0
    f.nchild = nchild
    return c.add_field(f)


def _remember(mut c: Columnar, ids: List[Int]) -> Int:
    var start = len(c.kids)
    var i = 0
    while i < len(ids):
        c.kids.append(ids[i])
        i += 1
    return start


def _push_fixed(mut c: Columnar, field: Int, raw: List[Byte], length: Int) -> Int:
    var a = ArrayRec()
    a.field = field
    a.length = length
    a.null_count = 0
    a.buf0 = len(c.abufs)
    a.nbuf = 2
    c.abufs.append(c.add_empty_buf())
    c.abufs.append(c.add_buf(Span(raw)))
    return c.push_array(a)


def _f64_col(mut c: Columnar, name: String, vals: List[Float64]) -> Int:
    var id = _field(c, name, TY_FLOAT, 64, 0, 0)
    c.add_top(id)
    var raw = List[Byte]()
    var i = 0
    while i < len(vals):
        put_width_u(raw, UInt64(vals[i].to_bits()), 8)
        i += 1
    return _push_fixed(c, id, raw^, len(vals))


def _i64_col(mut c: Columnar, name: String, vals: List[Int64], bit_width: Int) -> Int:
    var id = _field(c, name, TY_INT, bit_width, 0, 0)
    c.add_top(id)
    var raw = List[Byte]()
    var nbytes = bit_width // 8
    var i = 0
    while i < len(vals):
        put_width(raw, Int(vals[i]), nbytes)
        i += 1
    return _push_fixed(c, id, raw^, len(vals))


def _i32_values(mut c: Columnar, field: Int, vals: List[Int32]) -> Int:
    var raw = List[Byte]()
    var i = 0
    while i < len(vals):
        put_width(raw, Int(vals[i]), 4)
        i += 1
    return _push_fixed(c, field, raw^, len(vals))


def _utf8_values(mut c: Columnar, field: Int, vals: List[String]) -> Int:
    var off = List[Byte]()
    var data = List[Byte]()
    put_width(off, 0, 4)
    var pos = 0
    var i = 0
    while i < len(vals):
        var raw = _bytes_of(vals[i])
        var k = 0
        while k < len(raw):
            data.append(raw[k])
            k += 1
        pos += len(raw)
        put_width(off, pos, 4)
        i += 1
    var a = ArrayRec()
    a.field = field
    a.length = len(vals)
    a.null_count = 0
    a.buf0 = len(c.abufs)
    a.nbuf = 3
    c.abufs.append(c.add_empty_buf())
    c.abufs.append(c.add_buf(Span(off)))
    c.abufs.append(c.add_buf(Span(data)))
    return c.push_array(a)


def _utf8_col(mut c: Columnar, name: String, vals: List[String]) -> Int:
    var id = _field(c, name, TY_UTF8, 0, 0, 0)
    c.add_top(id)
    return _utf8_values(c, id, vals)


def _struct_array(mut c: Columnar, field: Int, length: Int, children: List[Int]) -> Int:
    var a = ArrayRec()
    a.field = field
    a.length = length
    a.null_count = 0
    a.buf0 = len(c.abufs)
    a.nbuf = 1
    c.abufs.append(c.add_empty_buf())
    a.child0 = len(c.achilds)
    a.nchild = len(children)
    var i = 0
    while i < len(children):
        c.achilds.append(children[i])
        i += 1
    return c.push_array(a)


def _list_array(mut c: Columnar, field: Int, nrows: Int, offsets: List[Int], child: Int) -> Int:
    var off = List[Byte]()
    var i = 0
    while i < len(offsets):
        put_width(off, offsets[i], 4)
        i += 1
    var a = ArrayRec()
    a.field = field
    a.length = nrows
    a.null_count = 0
    a.buf0 = len(c.abufs)
    a.nbuf = 2
    c.abufs.append(c.add_empty_buf())
    c.abufs.append(c.add_buf(Span(off)))
    a.child0 = len(c.achilds)
    a.nchild = 1
    c.achilds.append(child)
    return c.push_array(a)


def _read_f64(c: Columnar, col: Int) raises -> List[Float64]:
    var batch = c.batches[0]
    var a = c.arrays[c.batch_cols[batch.col0 + col]]
    var raw = c.buf_copy(c.abufs[a.buf0 + 1])
    var out = List[Float64]()
    var i = 0
    while i < a.length:
        out.append(Float64(from_bits=_u64_at(raw, i * 8)))
        i += 1
    return out^


def _read_i64(c: Columnar, col: Int, width: Int) raises -> List[Int64]:
    var batch = c.batches[0]
    var a = c.arrays[c.batch_cols[batch.col0 + col]]
    var raw = c.buf_copy(c.abufs[a.buf0 + 1])
    var out = List[Int64]()
    var i = 0
    while i < a.length:
        out.append(Int64(read_width(raw, i * width, width, True)))
        i += 1
    return out^


def _read_utf8(c: Columnar, col: Int) raises -> List[String]:
    var batch = c.batches[0]
    var a = c.arrays[c.batch_cols[batch.col0 + col]]
    var off = c.buf_copy(c.abufs[a.buf0 + 1])
    var data = c.buf_copy(c.abufs[a.buf0 + 2])
    var out = List[String]()
    var i = 0
    while i < a.length:
        var s0 = read_width(off, i * 4, 4, True)
        var s1 = read_width(off, (i + 1) * 4, 4, True)
        out.append(_text_from(data, s0, s1))
        i += 1
    return out^


def _table_batch(fx: Fixture) raises -> List[Byte]:
    var c = Columnar()
    var cols = List[Int]()
    var f = 0
    while f < 16:
        var vals = List[Float64]()
        var i = 0
        while i < len(fx.tables):
            vals.append(fx.tables[i].floats[f])
            i += 1
        cols.append(_f64_col(c, "f_float_" + String(f), vals^))
        f += 1
    var k = 0
    while k < 4:
        var vals = List[Int64]()
        var i = 0
        while i < len(fx.tables):
            vals.append(fx.tables[i].ints[k])
            i += 1
        cols.append(_i64_col(c, "f_int_" + String(k), vals^, 64))
        k += 1
    var s = 0
    while s < 2:
        var vals = List[String]()
        var i = 0
        while i < len(fx.tables):
            vals.append(fx.tables[i].strs[s])
            i += 1
        cols.append(_utf8_col(c, "f_str_" + String(s), vals^))
        s += 1
    c.add_batch(len(fx.tables), cols^)
    return encode_ipc_stream(c)


def _nested_batch(fx: Fixture) raises -> List[Byte]:
    var c = Columnar()
    var cols = List[Int]()
    var ids = List[String]()
    var statuses = List[Int32]()
    var regions = List[String]()
    var versions = List[Int32]()
    var skus = List[String]()
    var qtys = List[Int32]()
    var prices = List[Int64]()
    var offsets = List[Int]()
    offsets.append(0)
    var pos = 0
    var i = 0
    while i < len(fx.nested_rows):
        var row = fx.nested_rows[i].copy()
        ids.append(row.id)
        statuses.append(row.status)
        regions.append(row.meta.region)
        versions.append(row.meta.version)
        var j = 0
        while j < len(row.items):
            skus.append(row.items[j].sku)
            qtys.append(row.items[j].qty)
            prices.append(row.items[j].price_minor)
            j += 1
        pos += len(row.items)
        offsets.append(pos)
        i += 1
    var id_f = _field(c, "id", TY_UTF8, 0, 0, 0)
    c.add_top(id_f)
    cols.append(_utf8_values(c, id_f, ids^))
    var st_f = _field(c, "status", TY_INT, 32, 0, 0)
    c.add_top(st_f)
    cols.append(_i32_values(c, st_f, statuses^))
    var region_f = _field(c, "region", TY_UTF8, 0, 0, 0)
    var version_f = _field(c, "version", TY_INT, 32, 0, 0)
    var meta_kids = List[Int]()
    meta_kids.append(region_f)
    meta_kids.append(version_f)
    var meta_at = _remember(c, meta_kids^)
    var meta_f = _field(c, "meta", TY_STRUCT, 0, meta_at, 2)
    c.add_top(meta_f)
    var meta_children = List[Int]()
    meta_children.append(_utf8_values(c, region_f, regions^))
    meta_children.append(_i32_values(c, version_f, versions^))
    cols.append(_struct_array(c, meta_f, len(fx.nested_rows), meta_children^))
    var sku_f = _field(c, "sku", TY_UTF8, 0, 0, 0)
    var qty_f = _field(c, "qty", TY_INT, 32, 0, 0)
    var price_f = _field(c, "price_minor", TY_INT, 64, 0, 0)
    var item_kids = List[Int]()
    item_kids.append(sku_f)
    item_kids.append(qty_f)
    item_kids.append(price_f)
    var item_at = _remember(c, item_kids^)
    var item_f = _field(c, "item", TY_STRUCT, 0, item_at, 3)
    var item_children = List[Int]()
    item_children.append(_utf8_values(c, sku_f, skus^))
    item_children.append(_i32_values(c, qty_f, qtys^))
    var price_raw = List[Byte]()
    var p = 0
    while p < len(prices):
        put_width(price_raw, Int(prices[p]), 8)
        p += 1
    item_children.append(_push_fixed(c, price_f, price_raw^, len(prices)))
    var item_arr = _struct_array(c, item_f, len(prices), item_children^)
    var list_kids = List[Int]()
    list_kids.append(item_f)
    var list_at = _remember(c, list_kids^)
    var items_f = _field(c, "items", TY_LIST, 0, list_at, 1)
    c.add_top(items_f)
    cols.append(_list_array(c, items_f, len(fx.nested_rows), offsets^, item_arr))
    c.add_batch(len(fx.nested_rows), cols^)
    return encode_ipc_stream(c)


def _signal_batch(fx: Fixture) raises -> List[Byte]:
    var c = Columnar()
    var cols = List[Int]()
    var seqs = List[Int64]()
    var tss = List[Int64]()
    var prices = List[Int64]()
    var qtys = List[Int32]()
    var flags = List[Int32]()
    var symbols = List[String]()
    var venues = List[String]()
    var leg_ids = List[Int64]()
    var leg_qtys = List[Int32]()
    var leg_pads = List[Int32]()
    var offsets = List[Int]()
    offsets.append(0)
    var pos = 0
    var i = 0
    while i < len(fx.signals):
        var row = fx.signals[i].copy()
        seqs.append(row.seq)
        tss.append(row.ts)
        prices.append(row.price_mantissa)
        qtys.append(row.qty)
        flags.append(row.flags)
        symbols.append(row.symbol)
        venues.append(row.venue)
        var j = 0
        while j < len(row.legs):
            leg_ids.append(row.legs[j].leg_id)
            leg_qtys.append(row.legs[j].leg_qty)
            leg_pads.append(row.legs[j].leg_pad)
            j += 1
        pos += len(row.legs)
        offsets.append(pos)
        i += 1
    cols.append(_i64_col(c, "seq", seqs^, 64))
    cols.append(_i64_col(c, "ts", tss^, 64))
    cols.append(_i64_col(c, "price_mantissa", prices^, 64))
    var qty_f = _field(c, "qty", TY_INT, 32, 0, 0)
    c.add_top(qty_f)
    cols.append(_i32_values(c, qty_f, qtys^))
    var flags_f = _field(c, "flags", TY_INT, 32, 0, 0)
    c.add_top(flags_f)
    cols.append(_i32_values(c, flags_f, flags^))
    cols.append(_utf8_col(c, "symbol", symbols^))
    cols.append(_utf8_col(c, "venue", venues^))
    var id_f = _field(c, "leg_id", TY_INT, 64, 0, 0)
    var lq_f = _field(c, "leg_qty", TY_INT, 32, 0, 0)
    var lp_f = _field(c, "leg_pad", TY_INT, 32, 0, 0)
    var leg_kids = List[Int]()
    leg_kids.append(id_f)
    leg_kids.append(lq_f)
    leg_kids.append(lp_f)
    var leg_at = _remember(c, leg_kids^)
    var leg_f = _field(c, "leg", TY_STRUCT, 0, leg_at, 3)
    var leg_children = List[Int]()
    var id_raw = List[Byte]()
    var p = 0
    while p < len(leg_ids):
        put_width(id_raw, Int(leg_ids[p]), 8)
        p += 1
    leg_children.append(_push_fixed(c, id_f, id_raw^, len(leg_ids)))
    leg_children.append(_i32_values(c, lq_f, leg_qtys^))
    leg_children.append(_i32_values(c, lp_f, leg_pads^))
    var leg_arr = _struct_array(c, leg_f, len(leg_ids), leg_children^)
    var list_kids = List[Int]()
    list_kids.append(leg_f)
    var list_at = _remember(c, list_kids^)
    var legs_f = _field(c, "legs", TY_LIST, 0, list_at, 1)
    c.add_top(legs_f)
    cols.append(_list_array(c, legs_f, len(fx.signals), offsets^, leg_arr))
    c.add_batch(len(fx.signals), cols^)
    return encode_ipc_stream(c)


def _read_tables(c: Columnar) raises -> List[TableRow]:
    var floats = List[List[Float64]]()
    var f = 0
    while f < 16:
        floats.append(_read_f64(c, f))
        f += 1
    var ints = List[List[Int64]]()
    var k = 0
    while k < 4:
        ints.append(_read_i64(c, 16 + k, 8))
        k += 1
    var strs0 = _read_utf8(c, 20)
    var strs1 = _read_utf8(c, 21)
    var n = len(strs0)
    var out = List[TableRow]()
    var i = 0
    while i < n:
        var fv = List[Float64]()
        f = 0
        while f < 16:
            fv.append(floats[f][i])
            f += 1
        var iv = List[Int64]()
        k = 0
        while k < 4:
            iv.append(ints[k][i])
            k += 1
        var sv = List[String]()
        sv.append(strs0[i])
        sv.append(strs1[i])
        out.append(TableRow(fv^, iv^, sv^))
        i += 1
    return out^


def _top(c: Columnar, col: Int) -> ArrayRec:
    var batch = c.batches[0]
    return c.arrays[c.batch_cols[batch.col0 + col]]


def _child_arr(c: Columnar, parent: ArrayRec, i: Int) -> ArrayRec:
    return c.arrays[c.achilds[parent.child0 + i]]


def _i_at(raw: List[Byte], row: Int, width: Int) raises -> Int:
    return read_width(raw, row * width, width, True)


def _utf8_at(off: List[Byte], data: List[Byte], row: Int) raises -> String:
    var s0 = read_width(off, row * 4, 4, True)
    var s1 = read_width(off, (row + 1) * 4, 4, True)
    return _text_from(data, s0, s1)


def _load_utf8(c: Columnar, a: ArrayRec) -> Tuple[List[Byte], List[Byte]]:
    return (c.buf_copy(c.abufs[a.buf0 + 1]), c.buf_copy(c.abufs[a.buf0 + 2]))


def _load_fixed(c: Columnar, a: ArrayRec) -> List[Byte]:
    return c.buf_copy(c.abufs[a.buf0 + 1])


def _read_nested(c: Columnar) raises -> List[NestedRow]:
    var id_a = _top(c, 0)
    var id_bufs = _load_utf8(c, id_a)
    var status_raw = _load_fixed(c, _top(c, 1))
    var meta = _top(c, 2)
    var region_bufs = _load_utf8(c, _child_arr(c, meta, 0))
    var version_raw = _load_fixed(c, _child_arr(c, meta, 1))
    var items = _top(c, 3)
    var item_off = _load_fixed(c, items)
    var item = _child_arr(c, items, 0)
    var sku_bufs = _load_utf8(c, _child_arr(c, item, 0))
    var qty_raw = _load_fixed(c, _child_arr(c, item, 1))
    var price_raw = _load_fixed(c, _child_arr(c, item, 2))
    var out = List[NestedRow]()
    var i = 0
    while i < id_a.length:
        var s0 = _i_at(item_off, i, 4)
        var s1 = _i_at(item_off, i + 1, 4)
        var elems = List[NestedItem]()
        var j = s0
        while j < s1:
            elems.append(
                NestedItem(
                    _utf8_at(sku_bufs[0], sku_bufs[1], j),
                    Int32(_i_at(qty_raw, j, 4)),
                    Int64(_i_at(price_raw, j, 8)),
                )
            )
            j += 1
        out.append(
            NestedRow(
                _utf8_at(id_bufs[0], id_bufs[1], i),
                Int32(_i_at(status_raw, i, 4)),
                NestedMeta(
                    _utf8_at(region_bufs[0], region_bufs[1], i),
                    Int32(_i_at(version_raw, i, 4)),
                ),
                elems^,
            )
        )
        i += 1
    return out^


def _read_signals(c: Columnar) raises -> List[SignalRow]:
    var seq_raw = _load_fixed(c, _top(c, 0))
    var ts_raw = _load_fixed(c, _top(c, 1))
    var price_raw = _load_fixed(c, _top(c, 2))
    var qty_raw = _load_fixed(c, _top(c, 3))
    var flags_raw = _load_fixed(c, _top(c, 4))
    var symbol_bufs = _load_utf8(c, _top(c, 5))
    var venue_bufs = _load_utf8(c, _top(c, 6))
    var legs = _top(c, 7)
    var leg_off = _load_fixed(c, legs)
    var leg = _child_arr(c, legs, 0)
    var id_raw = _load_fixed(c, _child_arr(c, leg, 0))
    var lq_raw = _load_fixed(c, _child_arr(c, leg, 1))
    var lp_raw = _load_fixed(c, _child_arr(c, leg, 2))
    var n = c.batches[0].length
    var out = List[SignalRow]()
    var i = 0
    while i < n:
        var s0 = _i_at(leg_off, i, 4)
        var s1 = _i_at(leg_off, i + 1, 4)
        var elems = List[SignalLeg]()
        var j = s0
        while j < s1:
            elems.append(
                SignalLeg(
                    Int64(_i_at(id_raw, j, 8)),
                    Int32(_i_at(lq_raw, j, 4)),
                    Int32(_i_at(lp_raw, j, 4)),
                )
            )
            j += 1
        out.append(
            SignalRow(
                Int64(_i_at(seq_raw, i, 8)),
                Int64(_i_at(ts_raw, i, 8)),
                Int64(_i_at(price_raw, i, 8)),
                Int32(_i_at(qty_raw, i, 4)),
                Int32(_i_at(flags_raw, i, 4)),
                _utf8_at(symbol_bufs[0], symbol_bufs[1], i),
                _utf8_at(venue_bufs[0], venue_bufs[1], i),
                elems^,
            )
        )
        i += 1
    return out^


struct ArrowIpcSer:
    var version: String

    def __init__(out self):
        self.version = "0.2.0"

    def name(self) -> String:
        return "arrow-ipc"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        if fx.type_id == "table" or fx.type_id == "table_project":
            return _table_batch(fx)
        if fx.type_id == "nested_table":
            return _nested_batch(fx)
        if fx.type_id == "signal":
            return _signal_batch(fx)
        raise Error("arrow-ipc does not support " + fx.type_id)

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var c = decode_ipc_stream(Span(data))
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
        if fx.type_id == "table_project":
            out.projected = _read_f64(c, 0)
            out.n = len(out.projected)
            return out^
        if fx.type_id == "table":
            out.tables = _read_tables(c)
            out.n = len(out.tables)
            return out^
        if fx.type_id == "nested_table":
            out.nested_rows = _read_nested(c)
            out.n = len(out.nested_rows)
            return out^
        if fx.type_id == "signal":
            out.signals = _read_signals(c)
            out.n = len(out.signals)
            return out^
        raise Error("arrow-ipc does not support " + fx.type_id)

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
