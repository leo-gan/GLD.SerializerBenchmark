from std.collections import List, Span

from parquet_runtime.buf import u32_at
from parquet_runtime.error import DecodeError
from parquet_runtime.model import Schema
from parquet_runtime.thrift import TRead, T_STRUCT


struct Footer:
    var version: Int
    var nrows: Int
    var created_by: String
    var schema: Schema
    var kv_k: List[String]
    var kv_v: List[String]
    var rg_rows: List[Int]
    var rg_bytes: List[Int]
    var rg_cbytes: List[Int]
    var rg_off: List[Int]
    var rg_col0: List[Int]
    var rg_ncols: List[Int]
    var col_type: List[Int]
    var col_codec: List[Int]
    var col_values: List[Int]
    var col_unc: List[Int]
    var col_comp: List[Int]
    var col_data: List[Int]
    var col_dict: List[Int]
    var col_nulls: List[Int]
    var col_bloom_off: List[Int]
    var col_bloom_len: List[Int]
    var col_oi_off: List[Int]
    var col_oi_len: List[Int]
    var col_ci_off: List[Int]
    var col_ci_len: List[Int]
    var col_path: List[String]
    var enc_b: List[Int]
    var enc_n: List[Int]
    var encodings: List[Int]
    var order: List[Int]
    var min_has: List[Int]
    var min_b: List[Int]
    var min_n: List[Int]
    var max_b: List[Int]
    var max_n: List[Int]
    var stat_raw: List[Byte]

    def __init__(out self):
        self.version = 1
        self.nrows = 0
        self.created_by = ""
        self.schema = Schema()
        self.kv_k = List[String]()
        self.kv_v = List[String]()
        self.rg_rows = List[Int]()
        self.rg_bytes = List[Int]()
        self.rg_cbytes = List[Int]()
        self.rg_off = List[Int]()
        self.rg_col0 = List[Int]()
        self.rg_ncols = List[Int]()
        self.col_type = List[Int]()
        self.col_codec = List[Int]()
        self.col_values = List[Int]()
        self.col_unc = List[Int]()
        self.col_comp = List[Int]()
        self.col_data = List[Int]()
        self.col_dict = List[Int]()
        self.col_nulls = List[Int]()
        self.col_bloom_off = List[Int]()
        self.col_bloom_len = List[Int]()
        self.col_oi_off = List[Int]()
        self.col_oi_len = List[Int]()
        self.col_ci_off = List[Int]()
        self.col_ci_len = List[Int]()
        self.col_path = List[String]()
        self.enc_b = List[Int]()
        self.enc_n = List[Int]()
        self.encodings = List[Int]()
        self.order = List[Int]()
        self.min_has = List[Int]()
        self.min_b = List[Int]()
        self.min_n = List[Int]()
        self.max_b = List[Int]()
        self.max_n = List[Int]()
        self.stat_raw = List[Byte]()


def _magic[origin: ImmOrigin](raw: Span[Byte, origin], i: Int, a: Int, b: Int, c: Int, d: Int) -> Bool:
    return Int(raw[i]) == a and Int(raw[i + 1]) == b and Int(raw[i + 2]) == c and Int(raw[i + 3]) == d


def _empty_struct[origin: ImmOrigin](mut rd: TRead[origin]) raises DecodeError:
    var prev = rd.enter()
    while rd.next() != 0:
        rd.skip()
    rd.leave(prev)


def _read_unit[origin: ImmOrigin](mut rd: TRead[origin]) raises DecodeError -> Int:
    var unit = 1
    var prev = rd.enter()
    while rd.next() != 0:
        unit = rd.fid
        if rd.typ == T_STRUCT:
            _empty_struct(rd)
        else:
            rd.skip()
    rd.leave(prev)
    return unit


def _read_logical[origin: ImmOrigin](mut rd: TRead[origin], mut sch: Schema) raises DecodeError:
    var i = len(sch.name) - 1
    var prev = rd.enter()
    while rd.next() != 0:
        var kind = rd.fid
        sch.logical[i] = kind
        if rd.typ != T_STRUCT:
            rd.skip()
        elif kind == 5:
            var p = rd.enter()
            while rd.next() != 0:
                if rd.fid == 1:
                    sch.scale[i] = rd.read_i32()
                elif rd.fid == 2:
                    sch.precision[i] = rd.read_i32()
                else:
                    rd.skip()
            rd.leave(p)
        elif kind == 7 or kind == 8:
            var p = rd.enter()
            while rd.next() != 0:
                if rd.fid == 1:
                    sch.adjusted[i] = rd.read_bool()
                elif rd.fid == 2:
                    sch.time_unit[i] = _read_unit(rd)
                else:
                    rd.skip()
            rd.leave(p)
        elif kind == 10:
            var p = rd.enter()
            while rd.next() != 0:
                if rd.fid == 1:
                    sch.bit_width[i] = rd.read_i32()
                elif rd.fid == 2:
                    sch.is_signed[i] = rd.read_bool()
                else:
                    rd.skip()
            rd.leave(p)
        elif kind == 16:
            var p = rd.enter()
            while rd.next() != 0:
                if rd.fid == 1:
                    sch.variant_spec[i] = rd.read_i32()
                else:
                    rd.skip()
            rd.leave(p)
        elif kind == 17 or kind == 18:
            var p = rd.enter()
            while rd.next() != 0:
                if rd.fid == 1:
                    sch.crs[i] = rd.read_text()
                elif rd.fid == 2:
                    sch.geo_algo[i] = rd.read_i32()
                else:
                    rd.skip()
            rd.leave(p)
        else:
            _empty_struct(rd)
    rd.leave(prev)


def _read_schema_elem[origin: ImmOrigin](mut rd: TRead[origin], mut sch: Schema) raises DecodeError:
    sch.add("", -1, -1, 0, 0, 0)
    var i = len(sch.name) - 1
    var prev = rd.enter()
    while rd.next() != 0:
        if rd.fid == 1:
            sch.physical[i] = rd.read_i32()
        elif rd.fid == 2:
            sch.type_len[i] = rd.read_i32()
        elif rd.fid == 3:
            sch.rep[i] = rd.read_i32()
        elif rd.fid == 4:
            sch.name[i] = rd.read_text()
        elif rd.fid == 5:
            sch.nchild[i] = rd.read_i32()
        elif rd.fid == 6:
            sch.converted[i] = rd.read_i32()
        elif rd.fid == 7:
            sch.scale[i] = rd.read_i32()
        elif rd.fid == 8:
            sch.precision[i] = rd.read_i32()
        elif rd.fid == 9:
            sch.field_id[i] = rd.read_i32()
        elif rd.fid == 10:
            _read_logical(rd, sch)
        else:
            rd.skip()
    rd.leave(prev)
    if sch.logical[i] == 0 and sch.converted[i] >= 0:
        _legacy(sch, i)


def _legacy(mut sch: Schema, i: Int):
    var c = sch.converted[i]
    if c == 0:
        sch.logical[i] = 1
    elif c == 1:
        sch.logical[i] = 2
    elif c == 3:
        sch.logical[i] = 3
    elif c == 4:
        sch.logical[i] = 4
    elif c == 5:
        sch.logical[i] = 5
    elif c == 6:
        sch.logical[i] = 6
    elif c == 7:
        sch.logical[i] = 7
        sch.time_unit[i] = 1
    elif c == 8:
        sch.logical[i] = 7
        sch.time_unit[i] = 2
    elif c == 9:
        sch.logical[i] = 8
        sch.time_unit[i] = 1
        sch.adjusted[i] = 1
    elif c == 10:
        sch.logical[i] = 8
        sch.time_unit[i] = 2
        sch.adjusted[i] = 1
    elif c >= 11 and c <= 18:
        sch.logical[i] = 10
        sch.is_signed[i] = 0
        if c >= 15:
            sch.is_signed[i] = 1
        var w = c
        if c >= 15:
            w = c - 4
        if w == 11:
            sch.bit_width[i] = 8
        elif w == 12:
            sch.bit_width[i] = 16
        elif w == 13:
            sch.bit_width[i] = 32
        else:
            sch.bit_width[i] = 64
    elif c == 19:
        sch.logical[i] = 12
    elif c == 20:
        sch.logical[i] = 13
    elif c == 21:
        sch.type_len[i] = 12


def _read_stats[origin: ImmOrigin](mut rd: TRead[origin], mut foot: Footer) raises DecodeError:
    var has_min = 0
    var has_max = 0
    var minb = List[Byte]()
    var maxb = List[Byte]()
    var nulls = -1
    var prev = rd.enter()
    while rd.next() != 0:
        if rd.fid == 2 or rd.fid == 6:
            minb = rd.read_bin()
            has_min = 1
        elif rd.fid == 1 or rd.fid == 5:
            maxb = rd.read_bin()
            has_max = 1
        elif rd.fid == 3:
            nulls = rd.read_i64()
        else:
            rd.skip()
    rd.leave(prev)
    foot.col_nulls.append(nulls)
    foot.min_has.append(has_min)
    foot.min_b.append(len(foot.stat_raw))
    var i = 0
    while i < len(minb):
        foot.stat_raw.append(minb[i])
        i += 1
    foot.min_n.append(len(minb))
    foot.max_b.append(len(foot.stat_raw))
    i = 0
    while i < len(maxb):
        foot.stat_raw.append(maxb[i])
        i += 1
    foot.max_n.append(len(maxb))
    if has_max == 0:
        _ = has_max


def _read_col_meta[origin: ImmOrigin](mut rd: TRead[origin], mut foot: Footer) raises DecodeError:
    foot.col_type.append(0)
    foot.col_codec.append(0)
    foot.col_values.append(0)
    foot.col_unc.append(0)
    foot.col_comp.append(0)
    foot.col_data.append(0)
    foot.col_dict.append(-1)
    foot.col_bloom_off.append(-1)
    foot.col_bloom_len.append(0)
    foot.col_oi_off.append(-1)
    foot.col_oi_len.append(0)
    foot.col_ci_off.append(-1)
    foot.col_ci_len.append(0)
    foot.col_path.append("")
    foot.enc_b.append(len(foot.encodings))
    foot.enc_n.append(0)
    var idx = len(foot.col_type) - 1
    var saw_stats = 0
    var prev = rd.enter()
    while rd.next() != 0:
        if rd.fid == 1:
            foot.col_type[idx] = rd.read_i32()
        elif rd.fid == 2:
            var n = rd.list_head()
            var k = 0
            while k < n:
                foot.encodings.append(rd.elem_i32())
                foot.enc_n[idx] += 1
                k += 1
        elif rd.fid == 3:
            var n = rd.list_head()
            var path = ""
            var k = 0
            while k < n:
                var part = rd.elem_text()
                if k > 0:
                    path = path + "\x1f"
                path = path + part
                k += 1
            foot.col_path[idx] = path
        elif rd.fid == 4:
            foot.col_codec[idx] = rd.read_i32()
        elif rd.fid == 5:
            foot.col_values[idx] = rd.read_i64()
        elif rd.fid == 6:
            foot.col_unc[idx] = rd.read_i64()
        elif rd.fid == 7:
            foot.col_comp[idx] = rd.read_i64()
        elif rd.fid == 9:
            foot.col_data[idx] = rd.read_i64()
        elif rd.fid == 11:
            foot.col_dict[idx] = rd.read_i64()
        elif rd.fid == 12:
            _read_stats(rd, foot)
            saw_stats = 1
        elif rd.fid == 14:
            foot.col_bloom_off[idx] = rd.read_i64()
        elif rd.fid == 15:
            foot.col_bloom_len[idx] = rd.read_i32()
        else:
            rd.skip()
    rd.leave(prev)
    if saw_stats == 0:
        foot.col_nulls.append(-1)
        foot.min_has.append(0)
        foot.min_b.append(0)
        foot.min_n.append(0)
        foot.max_b.append(0)
        foot.max_n.append(0)


def _read_column[origin: ImmOrigin](mut rd: TRead[origin], mut foot: Footer) raises DecodeError:
    var prev = rd.enter()
    var saw_meta = 0
    var oi = -1
    var oil = 0
    var ci = -1
    var cil = 0
    while rd.next() != 0:
        if rd.fid == 3:
            _read_col_meta(rd, foot)
            saw_meta = 1
        elif rd.fid == 4:
            oi = rd.read_i64()
        elif rd.fid == 5:
            oil = rd.read_i32()
        elif rd.fid == 6:
            ci = rd.read_i64()
        elif rd.fid == 7:
            cil = rd.read_i32()
        elif rd.fid == 8 or rd.fid == 9:
            raise DecodeError(DecodeError.KIND_VERSION, rd.i, rd.fid)
        else:
            rd.skip()
    rd.leave(prev)
    if saw_meta == 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, rd.i)
    var idx = len(foot.col_type) - 1
    foot.col_oi_off[idx] = oi
    foot.col_oi_len[idx] = oil
    foot.col_ci_off[idx] = ci
    foot.col_ci_len[idx] = cil


def _read_row_group[origin: ImmOrigin](mut rd: TRead[origin], mut foot: Footer) raises DecodeError:
    var rows = 0
    var nbytes = 0
    var cbytes = 0
    var off = 0
    var col0 = len(foot.col_type)
    var ncols = 0
    var prev = rd.enter()
    while rd.next() != 0:
        if rd.fid == 1:
            var n = rd.list_head()
            var k = 0
            while k < n:
                _read_column(rd, foot)
                k += 1
            ncols = n
        elif rd.fid == 2:
            nbytes = rd.read_i64()
        elif rd.fid == 3:
            rows = rd.read_i64()
        elif rd.fid == 5:
            off = rd.read_i64()
        elif rd.fid == 6:
            cbytes = rd.read_i64()
        else:
            rd.skip()
    rd.leave(prev)
    foot.rg_rows.append(rows)
    foot.rg_bytes.append(nbytes)
    foot.rg_cbytes.append(cbytes)
    foot.rg_off.append(off)
    foot.rg_col0.append(col0)
    foot.rg_ncols.append(ncols)


def _read_orders[origin: ImmOrigin](mut rd: TRead[origin], mut foot: Footer) raises DecodeError:
    var n = rd.list_head()
    var k = 0
    while k < n:
        var prev = rd.enter()
        var kind = 1
        while rd.next() != 0:
            kind = rd.fid
            if rd.typ == T_STRUCT:
                _empty_struct(rd)
            else:
                rd.skip()
        rd.leave(prev)
        foot.order.append(kind)
        k += 1


def read_footer[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> Footer:
    var n = len(raw)
    if n < 12:
        raise DecodeError(DecodeError.KIND_EOF, 0)
    if _magic(raw, 0, 80, 65, 82, 69) or _magic(raw, n - 4, 80, 65, 82, 69):
        raise DecodeError(DecodeError.KIND_VERSION, 0)
    if not _magic(raw, 0, 80, 65, 82, 49) or not _magic(raw, n - 4, 80, 65, 82, 49):
        raise DecodeError(DecodeError.KIND_SYNTAX, 0)
    var flen = u32_at(raw, n - 8)
    if flen < 0 or flen > n - 12:
        raise DecodeError(DecodeError.KIND_RANGE, n - 8)
    var rd = TRead(raw)
    rd.i = n - 8 - flen
    var foot = Footer()
    while rd.next() != 0:
        if rd.fid == 1:
            foot.version = rd.read_i32()
        elif rd.fid == 2:
            var count = rd.list_head()
            var k = 0
            while k < count:
                _read_schema_elem(rd, foot.schema)
                k += 1
        elif rd.fid == 3:
            foot.nrows = rd.read_i64()
        elif rd.fid == 4:
            var count = rd.list_head()
            var k = 0
            while k < count:
                _read_row_group(rd, foot)
                k += 1
        elif rd.fid == 5:
            var count = rd.list_head()
            var k = 0
            while k < count:
                var prev = rd.enter()
                var key = ""
                var val = ""
                while rd.next() != 0:
                    if rd.fid == 1:
                        key = rd.read_text()
                    elif rd.fid == 2:
                        val = rd.read_text()
                    else:
                        rd.skip()
                rd.leave(prev)
                foot.kv_k.append(key)
                foot.kv_v.append(val)
                k += 1
        elif rd.fid == 6:
            foot.created_by = rd.read_text()
        elif rd.fid == 7:
            _read_orders(rd, foot)
        elif rd.fid == 8 or rd.fid == 9:
            raise DecodeError(DecodeError.KIND_VERSION, rd.i, rd.fid)
        else:
            rd.skip()
    if foot.version != 1 and foot.version != 2:
        raise DecodeError(DecodeError.KIND_VERSION, 0)
    foot.schema.finish()
    return foot^
