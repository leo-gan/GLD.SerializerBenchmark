"""gld-parquet on the columnar types.

`encode_table` / `decode_table` read and write a whole PAR1 file.
`parquet` sets Snappy, which is the suite page codec. The library default
is uncompressed, so `parquet-uncompressed` leaves the codec off.
gld-parquet has no column projection, so `table_project` decodes the file
and then materializes `f_float_0` only. Non-null suite fields are required
leaves. Lists use the three-level optional group, repeated group, element.
"""

from std.collections import List, Span

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
from parquet_runtime.model import (
    CODEC_NONE,
    CODEC_SNAPPY,
    L_LIST,
    L_NONE,
    L_STRING,
    PHY_BA,
    PHY_F64,
    PHY_I32,
    PHY_I64,
    REP_OPT,
    REP_REPEATED,
    REP_REQ,
    Cols,
    Schema,
    WriteOpts,
)
from parquet_wire.decode import Table, decode_table
from parquet_wire.encode import encode_table


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
    while i < end and i < len(raw):
        slice.append(raw[i])
        i += 1
    return String(unsafe_from_utf8=Span(slice))


def _add_group(mut schema: Schema, name: String, rep: Int, nchild: Int, logical: Int):
    schema.add(name, -1, rep, 0, nchild, logical)


def _leaf_str(mut cols: Cols, node: Int, vals: List[String]):
    cols.begin(node, PHY_BA)
    var i = 0
    while i < len(vals):
        cols.add_bytes(_bytes_of(vals[i]))
        i += 1


def _leaf_i64(mut cols: Cols, node: Int, physical: Int, vals: List[Int]):
    cols.begin(node, physical)
    var i = 0
    while i < len(vals):
        cols.add_i64(vals[i])
        i += 1


def _leaf_f64(mut cols: Cols, node: Int, vals: List[Float64]):
    cols.begin(node, PHY_F64)
    var i = 0
    while i < len(vals):
        cols.add_bits(UInt64(vals[i].to_bits()))
        i += 1


def _list_strs(mut cols: Cols, node: Int, max_def: Int, counts: List[Int], vals: List[String]):
    cols.begin(node, PHY_BA)
    var v = 0
    var row = 0
    while row < len(counts):
        var n = counts[row]
        if n == 0:
            cols.add_level(max_def - 1, 0)
        else:
            var k = 0
            while k < n:
                var rep = 0
                if k > 0:
                    rep = 1
                cols.add_level(max_def, rep)
                cols.add_bytes(_bytes_of(vals[v]))
                v += 1
                k += 1
        row += 1


def _list_ints(mut cols: Cols, node: Int, physical: Int, max_def: Int, counts: List[Int], vals: List[Int]):
    cols.begin(node, physical)
    var v = 0
    var row = 0
    while row < len(counts):
        var n = counts[row]
        if n == 0:
            cols.add_level(max_def - 1, 0)
        else:
            var k = 0
            while k < n:
                var rep = 0
                if k > 0:
                    rep = 1
                cols.add_level(max_def, rep)
                cols.add_i64(vals[v])
                v += 1
                k += 1
        row += 1


def _str_at(cols: Cols, leaf: Int, idx: Int) -> String:
    var end = cols.ends[cols.val_b[leaf] + idx]
    var start = cols.byte_b[leaf]
    if idx > 0:
        start = cols.ends[cols.val_b[leaf] + idx - 1]
    return _text_from(cols.raw, start, end)


def _i_at(cols: Cols, leaf: Int, idx: Int) -> Int:
    return cols.i64s[cols.val_b[leaf] + idx]


def _f_at(cols: Cols, leaf: Int, idx: Int) -> Float64:
    return Float64(from_bits=cols.bits[cols.val_b[leaf] + idx])


def _row_counts(cols: Cols, leaf: Int, max_def: Int) -> List[Int]:
    var out = List[Int]()
    var b = cols.level_b[leaf]
    var n = cols.level_n[leaf]
    var count = 0
    var started = False
    var i = 0
    while i < n:
        var rep = cols.reps[b + i]
        if rep == 0 and started:
            out.append(count)
            count = 0
        started = True
        if cols.defs[b + i] == max_def:
            count += 1
        i += 1
    if started:
        out.append(count)
    return out^


def _table_schema() raises -> Schema:
    var schema = Schema()
    _add_group(schema, "schema", -1, 22, L_NONE)
    var i = 0
    while i < 16:
        schema.add("f_float_" + String(i), PHY_F64, REP_REQ, 0, 0, L_NONE)
        i += 1
    i = 0
    while i < 4:
        schema.add("f_int_" + String(i), PHY_I64, REP_REQ, 0, 0, L_NONE)
        i += 1
    schema.add("f_str_0", PHY_BA, REP_REQ, 0, 0, L_STRING)
    schema.add("f_str_1", PHY_BA, REP_REQ, 0, 0, L_STRING)
    schema.finish()
    return schema^


def _nested_schema() raises -> Schema:
    var schema = Schema()
    _add_group(schema, "schema", -1, 4, L_NONE)
    schema.add("id", PHY_BA, REP_REQ, 0, 0, L_STRING)
    schema.add("status", PHY_I32, REP_REQ, 0, 0, L_NONE)
    _add_group(schema, "meta", REP_REQ, 2, L_NONE)
    schema.add("region", PHY_BA, REP_REQ, 0, 0, L_STRING)
    schema.add("version", PHY_I32, REP_REQ, 0, 0, L_NONE)
    _add_group(schema, "items", REP_OPT, 1, L_LIST)
    _add_group(schema, "list", REP_REPEATED, 1, L_NONE)
    _add_group(schema, "element", REP_REQ, 3, L_NONE)
    schema.add("sku", PHY_BA, REP_REQ, 0, 0, L_STRING)
    schema.add("qty", PHY_I32, REP_REQ, 0, 0, L_NONE)
    schema.add("price_minor", PHY_I64, REP_REQ, 0, 0, L_NONE)
    schema.finish()
    return schema^


def _signal_schema() raises -> Schema:
    var schema = Schema()
    _add_group(schema, "schema", -1, 8, L_NONE)
    schema.add("seq", PHY_I64, REP_REQ, 0, 0, L_NONE)
    schema.add("ts", PHY_I64, REP_REQ, 0, 0, L_NONE)
    schema.add("price_mantissa", PHY_I64, REP_REQ, 0, 0, L_NONE)
    schema.add("qty", PHY_I32, REP_REQ, 0, 0, L_NONE)
    schema.add("flags", PHY_I32, REP_REQ, 0, 0, L_NONE)
    schema.add("symbol", PHY_BA, REP_REQ, 0, 0, L_STRING)
    schema.add("venue", PHY_BA, REP_REQ, 0, 0, L_STRING)
    _add_group(schema, "legs", REP_OPT, 1, L_LIST)
    _add_group(schema, "list", REP_REPEATED, 1, L_NONE)
    _add_group(schema, "element", REP_REQ, 3, L_NONE)
    schema.add("leg_id", PHY_I64, REP_REQ, 0, 0, L_NONE)
    schema.add("leg_qty", PHY_I32, REP_REQ, 0, 0, L_NONE)
    schema.add("leg_pad", PHY_I32, REP_REQ, 0, 0, L_NONE)
    schema.finish()
    return schema^


def _finish(var schema: Schema, var cols: Cols, nrows: Int, codec: Int) raises -> List[Byte]:
    var table = Table()
    table.nrows = nrows
    table.cols = cols^
    table.foot.schema = schema^
    var opts = WriteOpts()
    opts.codec = codec
    return encode_table(table, opts)


def _write_table(fx: Fixture, codec: Int) raises -> List[Byte]:
    var schema = _table_schema()
    var cols = Cols()
    var f = 0
    while f < 16:
        var vals = List[Float64]()
        var i = 0
        while i < len(fx.tables):
            vals.append(fx.tables[i].floats[f])
            i += 1
        _leaf_f64(cols, 1 + f, vals^)
        f += 1
    var k = 0
    while k < 4:
        var vals = List[Int]()
        var i = 0
        while i < len(fx.tables):
            vals.append(Int(fx.tables[i].ints[k]))
            i += 1
        _leaf_i64(cols, 17 + k, PHY_I64, vals^)
        k += 1
    var s0 = List[String]()
    var s1 = List[String]()
    var i = 0
    while i < len(fx.tables):
        s0.append(fx.tables[i].strs[0])
        s1.append(fx.tables[i].strs[1])
        i += 1
    _leaf_str(cols, 21, s0^)
    _leaf_str(cols, 22, s1^)
    return _finish(schema^, cols^, len(fx.tables), codec)


def _write_nested(fx: Fixture, codec: Int) raises -> List[Byte]:
    var schema = _nested_schema()
    var cols = Cols()
    var ids = List[String]()
    var statuses = List[Int]()
    var regions = List[String]()
    var versions = List[Int]()
    var counts = List[Int]()
    var skus = List[String]()
    var qtys = List[Int]()
    var prices = List[Int]()
    var i = 0
    while i < len(fx.nested_rows):
        var row = fx.nested_rows[i].copy()
        ids.append(row.id)
        statuses.append(Int(row.status))
        regions.append(row.meta.region)
        versions.append(Int(row.meta.version))
        counts.append(len(row.items))
        var j = 0
        while j < len(row.items):
            skus.append(row.items[j].sku)
            qtys.append(Int(row.items[j].qty))
            prices.append(Int(row.items[j].price_minor))
            j += 1
        i += 1
    _leaf_str(cols, 1, ids^)
    _leaf_i64(cols, 2, PHY_I32, statuses^)
    _leaf_str(cols, 4, regions^)
    _leaf_i64(cols, 5, PHY_I32, versions^)
    var max_def = schema.max_def[9]
    _list_strs(cols, 9, max_def, counts, skus^)
    _list_ints(cols, 10, PHY_I32, max_def, counts, qtys^)
    _list_ints(cols, 11, PHY_I64, max_def, counts, prices^)
    return _finish(schema^, cols^, len(fx.nested_rows), codec)


def _write_signal(fx: Fixture, codec: Int) raises -> List[Byte]:
    var schema = _signal_schema()
    var cols = Cols()
    var seqs = List[Int]()
    var tss = List[Int]()
    var prices = List[Int]()
    var qtys = List[Int]()
    var flags = List[Int]()
    var symbols = List[String]()
    var venues = List[String]()
    var counts = List[Int]()
    var leg_ids = List[Int]()
    var leg_qtys = List[Int]()
    var leg_pads = List[Int]()
    var i = 0
    while i < len(fx.signals):
        var row = fx.signals[i].copy()
        seqs.append(Int(row.seq))
        tss.append(Int(row.ts))
        prices.append(Int(row.price_mantissa))
        qtys.append(Int(row.qty))
        flags.append(Int(row.flags))
        symbols.append(row.symbol)
        venues.append(row.venue)
        counts.append(len(row.legs))
        var j = 0
        while j < len(row.legs):
            leg_ids.append(Int(row.legs[j].leg_id))
            leg_qtys.append(Int(row.legs[j].leg_qty))
            leg_pads.append(Int(row.legs[j].leg_pad))
            j += 1
        i += 1
    _leaf_i64(cols, 1, PHY_I64, seqs^)
    _leaf_i64(cols, 2, PHY_I64, tss^)
    _leaf_i64(cols, 3, PHY_I64, prices^)
    _leaf_i64(cols, 4, PHY_I32, qtys^)
    _leaf_i64(cols, 5, PHY_I32, flags^)
    _leaf_str(cols, 6, symbols^)
    _leaf_str(cols, 7, venues^)
    var max_def = schema.max_def[11]
    _list_ints(cols, 11, PHY_I64, max_def, counts, leg_ids^)
    _list_ints(cols, 12, PHY_I32, max_def, counts, leg_qtys^)
    _list_ints(cols, 13, PHY_I32, max_def, counts, leg_pads^)
    return _finish(schema^, cols^, len(fx.signals), codec)


def _read_tables(table: Table) -> List[TableRow]:
    var n = table.nrows
    var out = List[TableRow]()
    var i = 0
    while i < n:
        var floats = List[Float64]()
        var f = 0
        while f < 16:
            floats.append(_f_at(table.cols, f, i))
            f += 1
        var ints = List[Int64]()
        var k = 0
        while k < 4:
            ints.append(Int64(_i_at(table.cols, 16 + k, i)))
            k += 1
        var strs = List[String]()
        strs.append(_str_at(table.cols, 20, i))
        strs.append(_str_at(table.cols, 21, i))
        out.append(TableRow(floats^, ints^, strs^))
        i += 1
    return out^


def _read_nested(table: Table) -> List[NestedRow]:
    var max_def = table.foot.schema.max_def[table.cols.schema_i[4]]
    var counts = _row_counts(table.cols, 4, max_def)
    var out = List[NestedRow]()
    var v = 0
    var i = 0
    while i < table.nrows:
        var items = List[NestedItem]()
        var j = 0
        while j < counts[i]:
            items.append(
                NestedItem(
                    _str_at(table.cols, 4, v),
                    Int32(_i_at(table.cols, 5, v)),
                    Int64(_i_at(table.cols, 6, v)),
                )
            )
            v += 1
            j += 1
        out.append(
            NestedRow(
                _str_at(table.cols, 0, i),
                Int32(_i_at(table.cols, 1, i)),
                NestedMeta(_str_at(table.cols, 2, i), Int32(_i_at(table.cols, 3, i))),
                items^,
            )
        )
        i += 1
    return out^


def _read_signals(table: Table) -> List[SignalRow]:
    var max_def = table.foot.schema.max_def[table.cols.schema_i[7]]
    var counts = _row_counts(table.cols, 7, max_def)
    var out = List[SignalRow]()
    var v = 0
    var i = 0
    while i < table.nrows:
        var legs = List[SignalLeg]()
        var j = 0
        while j < counts[i]:
            legs.append(
                SignalLeg(
                    Int64(_i_at(table.cols, 7, v)),
                    Int32(_i_at(table.cols, 8, v)),
                    Int32(_i_at(table.cols, 9, v)),
                )
            )
            v += 1
            j += 1
        out.append(
            SignalRow(
                Int64(_i_at(table.cols, 0, i)),
                Int64(_i_at(table.cols, 1, i)),
                Int64(_i_at(table.cols, 2, i)),
                Int32(_i_at(table.cols, 3, i)),
                Int32(_i_at(table.cols, 4, i)),
                _str_at(table.cols, 5, i),
                _str_at(table.cols, 6, i),
                legs^,
            )
        )
        i += 1
    return out^


struct ParquetSer:
    var version: String
    var ser_name: String
    var codec: Int

    def __init__(out self, ser_name: String, codec: Int):
        self.version = "0.2.0"
        self.ser_name = ser_name
        self.codec = codec

    def name(self) -> String:
        return self.ser_name

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        if fx.type_id == "table" or fx.type_id == "table_project":
            return _write_table(fx, self.codec)
        if fx.type_id == "nested_table":
            return _write_nested(fx, self.codec)
        if fx.type_id == "signal":
            return _write_signal(fx, self.codec)
        raise Error(self.ser_name + " does not support " + fx.type_id)

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var table = decode_table(Span(data))
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
            var vals = List[Float64]()
            var i = 0
            while i < table.nrows:
                vals.append(_f_at(table.cols, 0, i))
                i += 1
            out.projected = vals^
            out.n = len(out.projected)
            return out^
        if fx.type_id == "table":
            out.tables = _read_tables(table)
            out.n = len(out.tables)
            return out^
        if fx.type_id == "nested_table":
            out.nested_rows = _read_nested(table)
            out.n = len(out.nested_rows)
            return out^
        if fx.type_id == "signal":
            out.signals = _read_signals(table)
            out.n = len(out.signals)
            return out^
        raise Error(self.ser_name + " does not support " + fx.type_id)

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))


def parquet_ser() -> ParquetSer:
    return ParquetSer("parquet", CODEC_SNAPPY)


def parquet_uncompressed_ser() -> ParquetSer:
    return ParquetSer("parquet-uncompressed", CODEC_NONE)
