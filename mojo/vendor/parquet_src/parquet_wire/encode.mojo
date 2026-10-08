from std.collections import List

from parquet_compress.gzip import gzip_compress
from parquet_compress.lz4raw import lz4_raw_compress
from parquet_compress.snappy import snappy_compress
from parquet_compress.xxh import xxh64_list
from parquet_compress.zstd import zstd_compress
from parquet_runtime.buf import crc32_bytes, extend_list, put_i32, put_u32
from parquet_runtime.error import DecodeError
from parquet_runtime.model import (
    CODEC_GZIP,
    CODEC_LZ4_RAW,
    CODEC_NONE,
    CODEC_SNAPPY,
    CODEC_ZSTD,
    ENC_PLAIN,
    ENC_RLE,
    ENC_RLE_DICT,
    L_BSON,
    L_DATE,
    L_DECIMAL,
    L_ENUM,
    L_INTEGER,
    L_JSON,
    L_LIST,
    L_MAP,
    L_STRING,
    L_TIME,
    L_TIMESTAMP,
    PHY_BA,
    PHY_BOOL,
    PHY_F32,
    PHY_F64,
    PHY_FIXED,
    PHY_I32,
    PHY_I64,
    PHY_I96,
    Cols,
    Schema,
    WriteOpts,
)
from parquet_runtime.pack import level_width, levels_encode, plain_ba_encode, plain_bool_encode, plain_i32_encode, plain_i64_encode, rle_encode
from parquet_runtime.thrift import TOut, T_BINARY, T_BOOL_TRUE, T_I32, T_I64, T_STRUCT, zz_to
from parquet_wire.decode import Table
from parquet_wire.footer import Footer


comptime CREATED = "gld-parquet version 0.2.0"


struct RgSlice(Copyable, ImplicitlyCopyable):
    var lb: Int
    var le: Int
    var vb: Int
    var ve: Int

    def __init__(out self, lb: Int, le: Int, vb: Int, ve: Int):
        self.lb = lb
        self.le = le
        self.vb = vb
        self.ve = ve


def _compress(codec: Int, raw: List[Byte]) raises DecodeError -> List[Byte]:
    if codec == CODEC_NONE:
        var out = List[Byte]()
        extend_list(out, raw)
        return out^
    if codec == CODEC_SNAPPY:
        return snappy_compress(raw)
    if codec == CODEC_GZIP:
        return gzip_compress(raw)
    if codec == CODEC_ZSTD:
        return zstd_compress(raw)
    if codec == CODEC_LZ4_RAW:
        return lz4_raw_compress(raw)
    raise DecodeError(DecodeError.KIND_COMPRESSION, codec)


def _rows(imm schema: Schema, imm cols: Cols, leaf: Int) -> Int:
    var node = cols.schema_i[leaf]
    var ln = cols.level_n[leaf]
    if schema.max_rep[node] == 0 and schema.max_def[node] == 0:
        return cols.val_n[leaf]
    var n = 0
    var i = 0
    var b = cols.level_b[leaf]
    while i < ln:
        if cols.reps[b + i] == 0:
            n += 1
        i += 1
    if n == 0:
        return cols.val_n[leaf]
    return n


def _slices(imm schema: Schema, imm cols: Cols, leaf: Int, rg_rows: Int) -> List[RgSlice]:
    var out = List[RgSlice]()
    var node = cols.schema_i[leaf]
    var ln = cols.level_n[leaf]
    var vn = cols.val_n[leaf]
    if schema.max_def[node] == 0 and schema.max_rep[node] == 0:
        var i = 0
        while i < vn:
            var take = rg_rows
            if i + take > vn:
                take = vn - i
            out.append(RgSlice(0, 0, i, i + take))
            i += take
        if vn == 0:
            out.append(RgSlice(0, 0, 0, 0))
        return out^
    var b = cols.level_b[leaf]
    var vb0 = cols.val_b[leaf]
    var i = 0
    var vb = 0
    while i < ln:
        var rows = 0
        var j = i
        var v = vb
        while j < ln:
            if cols.reps[b + j] == 0:
                if rows >= rg_rows and j > i:
                    break
                rows += 1
            if cols.defs[b + j] == schema.max_def[node]:
                v += 1
            j += 1
        out.append(RgSlice(i, j, vb, v))
        i = j
        vb = v
    if len(out) == 0:
        out.append(RgSlice(0, 0, 0, 0))
    _ = vb0
    return out^


def _plain_fixed(imm cols: Cols, leaf: Int, vb: Int, ve: Int, width: Int) -> List[Byte]:
    var out = List[Byte]()
    var base = cols.byte_b[leaf]
    var i = vb
    while i < ve:
        var end = cols.ends[cols.val_b[leaf] + i]
        var start = base
        if i > 0:
            start = cols.ends[cols.val_b[leaf] + i - 1]
        var k = start
        while k < end:
            out.append(cols.raw[k])
            k += 1
        i += 1
    _ = width
    return out^


def _values_plain(imm cols: Cols, leaf: Int, physical: Int, type_len: Int, vb: Int, ve: Int) -> List[Byte]:
    var n = ve - vb
    if physical == PHY_BOOL:
        var vals = List[Int]()
        var i = 0
        while i < n:
            vals.append(cols.i64s[cols.val_b[leaf] + vb + i])
            i += 1
        return plain_bool_encode(vals, n)
    if physical == PHY_I32:
        var out = List[Byte]()
        out.resize(n * 4, Byte(0))
        var base = cols.val_b[leaf] + vb
        var i = 0
        while i < n:
            var v = cols.i64s[base + i]
            if v < 0:
                v = v + 4294967296
            var o = i * 4
            out[o] = Byte(v & 255)
            out[o + 1] = Byte((v >> 8) & 255)
            out[o + 2] = Byte((v >> 16) & 255)
            out[o + 3] = Byte((v >> 24) & 255)
            i += 1
        return out^
    if physical == PHY_I64:
        var out = List[Byte]()
        out.resize(n * 8, Byte(0))
        var base = cols.val_b[leaf] + vb
        var i = 0
        while i < n:
            var u = UInt64(cols.i64s[base + i])
            var o = i * 8
            var b = 0
            while b < 8:
                out[o + b] = Byte(Int((u >> UInt64(8 * b)) & 255))
                b += 1
            i += 1
        return out^
    if physical == PHY_F32:
        var out = List[Byte]()
        var i = 0
        while i < n:
            var u = cols.bits[cols.val_b[leaf] + vb + i]
            put_u32(out, Int(u & 0xFFFFFFFF))
            i += 1
        return out^
    if physical == PHY_F64:
        var out = List[Byte]()
        var i = 0
        while i < n:
            var u = cols.bits[cols.val_b[leaf] + vb + i]
            var b = 0
            while b < 8:
                out.append(Byte(Int((u >> UInt64(8 * b)) & 255)))
                b += 1
            i += 1
        return out^
    if physical == PHY_BA:
        var raw = List[Byte]()
        var ends = List[Int]()
        var i = vb
        while i < ve:
            var end = cols.ends[cols.val_b[leaf] + i]
            var start = cols.byte_b[leaf]
            if i > 0:
                start = cols.ends[cols.val_b[leaf] + i - 1]
            var k = start
            while k < end:
                raw.append(cols.raw[k])
                k += 1
            ends.append(len(raw))
            i += 1
        return plain_ba_encode(raw, ends, n)
    return _plain_fixed(cols, leaf, vb, ve, type_len)


def _stat_bytes(imm cols: Cols, leaf: Int, physical: Int, idx: Int) -> List[Byte]:
    var one = List[Byte]()
    if physical == PHY_BOOL or physical == PHY_I32:
        put_i32(one, cols.i64s[cols.val_b[leaf] + idx])
        if physical == PHY_BOOL:
            one = List[Byte]()
            one.append(Byte(cols.i64s[cols.val_b[leaf] + idx] & 255))
    elif physical == PHY_I64:
        var u = UInt64(cols.i64s[cols.val_b[leaf] + idx])
        var b = 0
        while b < 8:
            one.append(Byte(Int((u >> UInt64(8 * b)) & 255)))
            b += 1
    elif physical == PHY_F32:
        put_u32(one, Int(cols.bits[cols.val_b[leaf] + idx] & 0xFFFFFFFF))
    elif physical == PHY_F64:
        var u = cols.bits[cols.val_b[leaf] + idx]
        var b = 0
        while b < 8:
            one.append(Byte(Int((u >> UInt64(8 * b)) & 255)))
            b += 1
    else:
        var end = cols.ends[cols.val_b[leaf] + idx]
        var start = cols.byte_b[leaf]
        if idx > 0:
            start = cols.ends[cols.val_b[leaf] + idx - 1]
        var k = start
        while k < end:
            one.append(cols.raw[k])
            k += 1
    return one^


def _less(imm a: List[Byte], imm b: List[Byte]) -> Bool:
    var n = len(a)
    if len(b) < n:
        n = len(b)
    var i = 0
    while i < n:
        if Int(a[i]) < Int(b[i]):
            return True
        if Int(a[i]) > Int(b[i]):
            return False
        i += 1
    return len(a) < len(b)


def _write_bin(mut w: TOut, id: Int, raw: List[Byte]):
    w.binary(id, raw)


def _page_v1(mut file: List[Byte], codec: Int, num_values: Int, encoding: Int, crc_on: Int, body: List[Byte]) raises DecodeError -> Int:
    var comp = _compress(codec, body)
    var hdr = TOut()
    hdr.i32(1, 0)
    hdr.i32(2, len(body))
    hdr.i32(3, len(comp))
    if crc_on != 0:
        hdr.i32(4, crc32_bytes(comp, 0, len(comp)))
    var p = hdr.begin(5)
    hdr.i32(1, num_values)
    hdr.i32(2, encoding)
    hdr.i32(3, ENC_RLE)
    hdr.i32(4, ENC_RLE)
    hdr.end(p)
    hdr.stop()
    var start = len(file)
    extend_list(file, hdr.b)
    extend_list(file, comp)
    return len(file) - start


def _uleb(mut out: List[Byte], v: Int):
    var x = v
    while x >= 128:
        out.append(Byte((x & 127) | 128))
        x = x >> 7
    out.append(Byte(x))


def _const_defs(imm cols: Cols, leaf: Int, lb: Int, n: Int, max_def: Int) -> List[Byte]:
    var out = List[Byte]()
    if n <= 0 or max_def <= 0:
        return out^
    var b = cols.level_b[leaf] + lb
    var v0 = cols.defs[b]
    var i = 1
    while i < n:
        if cols.defs[b + i] != v0:
            return out^
        i += 1
    var width = level_width(max_def)
    var body = List[Byte]()
    _uleb(body, n << 1)
    var nbytes = (width + 7) >> 3
    var u = UInt64(v0)
    var k = 0
    while k < nbytes:
        body.append(Byte(Int((u >> UInt64(8 * k)) & 255)))
        k += 1
    var nlen = len(body)
    out.append(Byte(nlen & 255))
    out.append(Byte((nlen >> 8) & 255))
    out.append(Byte((nlen >> 16) & 255))
    out.append(Byte((nlen >> 24) & 255))
    extend_list(out, body)
    return out^


def _levels(imm cols: Cols, leaf: Int, lb: Int, le: Int, max_def: Int, max_rep: Int) -> List[Byte]:
    var out = List[Byte]()
    var n = le - lb
    if max_rep == 0 and max_def > 0:
        var fast = _const_defs(cols, leaf, lb, n, max_def)
        if len(fast) > 0:
            return fast^
    if max_rep > 0:
        var reps = List[Int]()
        var i = 0
        while i < n:
            reps.append(cols.reps[cols.level_b[leaf] + lb + i])
            i += 1
        var enc = levels_encode(reps, n, level_width(max_rep), 1)
        extend_list(out, enc)
    if max_def > 0:
        var defs = List[Int]()
        var i = 0
        while i < n:
            defs.append(cols.defs[cols.level_b[leaf] + lb + i])
            i += 1
        var enc = levels_encode(defs, n, level_width(max_def), 1)
        extend_list(out, enc)
    return out^


def _write_schema_elem(mut w: TOut, imm schema: Schema, i: Int):
    w.last = 0
    if schema.physical[i] >= 0:
        w.i32(1, schema.physical[i])
    if schema.type_len[i] > 0 or schema.physical[i] == PHY_FIXED:
        w.i32(2, schema.type_len[i])
    if schema.rep[i] >= 0:
        w.i32(3, schema.rep[i])
    w.text(4, schema.name[i])
    if schema.nchild[i] > 0:
        w.i32(5, schema.nchild[i])
    var conv = schema.converted[i]
    if conv < 0:
        conv = _converted(schema, i)
    if conv >= 0:
        w.i32(6, conv)
    if schema.logical[i] == L_DECIMAL or conv == 5:
        w.i32(7, schema.scale[i])
        w.i32(8, schema.precision[i])
    if schema.field_id[i] >= 0:
        w.i32(9, schema.field_id[i])
    if schema.logical[i] > 0:
        _write_logical(w, schema, i)
    w.stop()


def _converted(imm schema: Schema, i: Int) -> Int:
    var k = schema.logical[i]
    if k == L_STRING:
        return 0
    if k == L_MAP:
        return 1
    if k == L_LIST:
        return 3
    if k == L_ENUM:
        return 4
    if k == L_DECIMAL:
        return 5
    if k == L_DATE:
        return 6
    if k == L_TIME and schema.time_unit[i] == 1:
        return 7
    if k == L_TIME and schema.time_unit[i] == 2:
        return 8
    if k == L_TIMESTAMP and schema.time_unit[i] == 1:
        return 9
    if k == L_TIMESTAMP and schema.time_unit[i] == 2:
        return 10
    if k == L_INTEGER:
        var bit = schema.bit_width[i]
        var base = 11
        if schema.is_signed[i] != 0:
            base = 15
        if bit == 8:
            return base
        if bit == 16:
            return base + 1
        if bit == 32:
            return base + 2
        return base + 3
    if k == L_JSON:
        return 19
    if k == L_BSON:
        return 20
    return -1


def _write_logical(mut w: TOut, imm schema: Schema, i: Int):
    var p = w.begin(10)
    var k = schema.logical[i]
    if k == L_DECIMAL:
        var ip = w.begin(5)
        w.i32(1, schema.scale[i])
        w.i32(2, schema.precision[i])
        w.end(ip)
    elif k == L_TIME or k == L_TIMESTAMP:
        var field = 7
        if k == L_TIMESTAMP:
            field = 8
        var ip = w.begin(field)
        w.bool(1, schema.adjusted[i])
        var up = w.begin(2)
        var ep = w.begin(schema.time_unit[i])
        w.end(ep)
        w.end(up)
        w.end(ip)
    elif k == L_INTEGER:
        var ip = w.begin(10)
        w.i32(1, schema.bit_width[i])
        w.bool(2, schema.is_signed[i])
        w.end(ip)
    elif k == 16:
        var ip = w.begin(16)
        if schema.variant_spec[i] >= 0:
            w.i32(1, schema.variant_spec[i])
        w.end(ip)
    elif k == 17 or k == 18:
        var ip = w.begin(k)
        if schema.crs[i].byte_length() > 0:
            w.text(1, schema.crs[i])
        if k == 18 and schema.geo_algo[i] >= 0:
            w.i32(2, schema.geo_algo[i])
        w.end(ip)
    else:
        var ip = w.begin(k)
        w.end(ip)
    w.end(p)


def _path_list(mut w: TOut, path: String):
    var raw = path.as_bytes()
    var n = 1
    var i = 0
    while i < len(raw):
        if Int(raw[i]) == 31:
            n += 1
        i += 1
    var prev = w.list_begin(3, T_BINARY, n)
    i = 0
    var start = 0
    while i <= len(raw):
        if i == len(raw) or Int(raw[i]) == 31:
            w.uvar(UInt64(i - start))
            var k = start
            while k < i:
                w.b.append(raw[k])
                k += 1
            start = i + 1
        i += 1
    w.finish_list(prev)


def _empty_order(mut w: TOut, kind: Int):
    w.last = 0
    var p = w.begin(kind)
    w.end(p)
    w.stop()


def _page_body(imm table: Table, imm opts: WriteOpts, leaf: Int, physical: Int, lb: Int, le: Int, vb: Int, ve: Int) raises DecodeError -> List[Byte]:
    var node = table.cols.schema_i[leaf]
    var body = _levels(table.cols, leaf, lb, le, table.foot.schema.max_def[node], table.foot.schema.max_rep[node])
    if physical == PHY_BOOL and opts.encoding < 0:
        var vals = List[Int]()
        var i = vb
        while i < ve:
            vals.append(table.cols.i64s[table.cols.val_b[leaf] + i])
            i += 1
        var packed = levels_encode(vals, ve - vb, 1, 1)
        extend_list(body, packed)
    else:
        var plain = _values_plain(table.cols, leaf, physical, table.foot.schema.type_len[node], vb, ve)
        extend_list(body, plain)
    return body^


def _emit_chunk(mut file: List[Byte], mut foot: TOut, imm table: Table, imm opts: WriteOpts, leaf: Int, sl: RgSlice) raises DecodeError -> Int:
    var node = table.cols.schema_i[leaf]
    var physical = table.foot.schema.physical[node]
    var num_values = sl.le - sl.lb
    if table.foot.schema.max_def[node] == 0 and table.foot.schema.max_rep[node] == 0:
        num_values = sl.ve - sl.vb
    var body = _page_body(table, opts, leaf, physical, sl.lb, sl.le, sl.vb, sl.ve)
    var data_off = len(file)
    var enc = ENC_PLAIN
    if physical == PHY_BOOL and opts.encoding < 0:
        enc = ENC_RLE
    var page_sz = _page_v1(file, opts.codec, num_values, enc, opts.crc, body)
    var nulls = num_values - (sl.ve - sl.vb)
    foot.last = 0
    foot.i64(2, 0)
    var meta = foot.begin(3)
    foot.i32(1, physical)
    var encs = 1
    if table.foot.schema.max_def[node] > 0 or table.foot.schema.max_rep[node] > 0 or enc == ENC_RLE:
        encs = 2
    var ep = foot.list_begin(2, T_I32, encs)
    if encs == 2:
        foot.uvar(zz_to(ENC_RLE))
    foot.uvar(zz_to(enc))
    foot.finish_list(ep)
    _path_list(foot, _leaf_path(table.foot.schema, node))
    foot.i32(4, opts.codec)
    foot.i64(5, num_values)
    foot.i64(6, page_sz)
    foot.i64(7, page_sz)
    foot.i64(9, data_off)
    if opts.stats != 0 and sl.ve > sl.vb:
        _write_stats(foot, table.cols, leaf, physical, sl.vb, sl.ve, nulls)
    foot.end(meta)
    foot.stop()
    return page_sz


def _gather(imm table: Table, rg_rows: Int) -> List[RgSlice]:
    var flat = List[RgSlice]()
    var leaf = 0
    var nleaf = table.foot.schema.nleaves
    while leaf < nleaf:
        var part = _slices(table.foot.schema, table.cols, leaf, rg_rows)
        var p = 0
        while p < len(part):
            flat.append(part[p])
            p += 1
        leaf += 1
    return flat^


def encode_table(imm table: Table, imm opts: WriteOpts) raises DecodeError -> List[Byte]:
    var file = List[Byte](capacity=1024)
    file.append(Byte(80))
    file.append(Byte(65))
    file.append(Byte(82))
    file.append(Byte(49))
    var nleaf = table.foot.schema.nleaves
    var rg_rows = opts.rg_rows
    if rg_rows <= 0:
        rg_rows = 1048576
    var flat = _gather(table, rg_rows)
    var nrg = 1
    if nleaf > 0 and len(flat) > 0:
        nrg = len(flat) // nleaf
    var foot = TOut()
    foot.i32(1, 1)
    var sp = foot.list_begin(2, T_STRUCT, len(table.foot.schema.name))
    var s = 0
    while s < len(table.foot.schema.name):
        _write_schema_elem(foot, table.foot.schema, s)
        s += 1
    foot.finish_list(sp)
    foot.i64(3, table.nrows)
    var rg_saved = foot.list_begin(4, T_STRUCT, nrg)
    var rg = 0
    while rg < nrg:
        foot.last = 0
        var col_saved = foot.list_begin(1, T_STRUCT, nleaf)
        var total = 0
        var rg_file_off = len(file)
        var leaf = 0
        while leaf < nleaf:
            var sl = flat[leaf * nrg + rg]
            total += _emit_chunk(file, foot, table, opts, leaf, sl)
            leaf += 1
        foot.finish_list(col_saved)
        foot.i64(2, total)
        foot.i64(3, _rows_in(flat, nrg, rg, table.foot.schema, table.cols))
        foot.i64(5, rg_file_off)
        foot.i64(6, total)
        foot.stop()
        rg += 1
    foot.finish_list(rg_saved)
    foot.text(6, CREATED)
    if nleaf > 0:
        var op = foot.list_begin(7, T_STRUCT, nleaf)
        var leaf = 0
        while leaf < nleaf:
            var kind = 1
            var physical = table.foot.schema.physical[table.cols.schema_i[leaf]]
            if physical == PHY_F32 or physical == PHY_F64:
                kind = 2
            if physical == PHY_I96:
                kind = 3
            _empty_order(foot, kind)
            leaf += 1
        foot.finish_list(op)
    foot.stop()
    extend_list(file, foot.b)
    put_u32(file, len(foot.b))
    file.append(Byte(80))
    file.append(Byte(65))
    file.append(Byte(82))
    file.append(Byte(49))
    return file^


def _rows_in(imm slices: List[RgSlice], nrg: Int, rg: Int, imm schema: Schema, imm cols: Cols) -> Int:
    if len(slices) == 0:
        return 0
    var sl = slices[rg]
    var node = cols.schema_i[0]
    _ = nrg
    if schema.max_def[node] == 0 and schema.max_rep[node] == 0:
        return sl.ve - sl.vb
    var n = 0
    var i = sl.lb
    while i < sl.le:
        if cols.reps[cols.level_b[0] + i] == 0:
            n += 1
        i += 1
    return n


def _leaf_path(imm schema: Schema, node: Int) -> String:
    var names = List[String]()
    var cur = node
    while cur > 0:
        names.append(schema.name[cur])
        var parent = -1
        var i = 0
        while i < cur:
            if schema.nchild[i] > 0 and schema.span_end[i] > cur:
                parent = i
            i += 1
        if parent <= 0:
            break
        cur = parent
    var path = ""
    var i = len(names) - 1
    while i >= 0:
        if path.byte_length() > 0:
            path = path + "\x1f"
        path = path + names[i]
        i -= 1
    return path


def _nan_bits(bits: UInt64, wide: Int) -> Bool:
    if wide == 0:
        var exp = (bits >> UInt64(23)) & 0xFF
        var frac = bits & 0x7FFFFF
        return exp == 0xFF and frac != 0
    var exp = (bits >> UInt64(52)) & 0x7FF
    var frac = bits & 0xFFFFFFFFFFFFF
    return exp == 0x7FF and frac != 0


def _stat_before(imm cols: Cols, leaf: Int, physical: Int, i: Int, j: Int) -> Bool:
    if physical == PHY_BOOL or physical == PHY_I32 or physical == PHY_I64:
        return cols.i64s[cols.val_b[leaf] + i] < cols.i64s[cols.val_b[leaf] + j]
    if physical == PHY_F32 or physical == PHY_F64:
        var wide = 0
        if physical == PHY_F64:
            wide = 1
        var a = cols.bits[cols.val_b[leaf] + i]
        var b = cols.bits[cols.val_b[leaf] + j]
        if wide == 0:
            return Float32(from_bits=UInt32(a)) < Float32(from_bits=UInt32(b))
        return Float64(from_bits=a) < Float64(from_bits=b)
    var ai = _stat_bytes(cols, leaf, physical, i)
    var bi = _stat_bytes(cols, leaf, physical, j)
    return _less(ai, bi)


def _write_stats(mut w: TOut, imm cols: Cols, leaf: Int, physical: Int, vb: Int, ve: Int, nulls: Int):
    var p = w.begin(12)
    var have = 0
    var min_i = -1
    var max_i = -1
    var nans = 0
    var i = vb
    while i < ve:
        var skip = 0
        if physical == PHY_F32 or physical == PHY_F64:
            var wide = 0
            if physical == PHY_F64:
                wide = 1
            if _nan_bits(cols.bits[cols.val_b[leaf] + i], wide):
                nans += 1
                skip = 1
        if skip == 0:
            if min_i < 0 or _stat_before(cols, leaf, physical, i, min_i):
                min_i = i
            if max_i < 0 or _stat_before(cols, leaf, physical, max_i, i):
                max_i = i
            have = 1
        i += 1
    if have != 0 and physical != PHY_F32 and physical != PHY_F64:
        var mx = _stat_bytes(cols, leaf, physical, max_i)
        var mn = _stat_bytes(cols, leaf, physical, min_i)
        _write_bin(w, 1, mx)
        _write_bin(w, 2, mn)
    w.i64(3, nulls)
    if have != 0:
        var mx = _stat_bytes(cols, leaf, physical, max_i)
        var mn = _stat_bytes(cols, leaf, physical, min_i)
        _write_bin(w, 5, mx)
        _write_bin(w, 6, mn)
        w.bool(7, 1)
        w.bool(8, 1)
    if physical == PHY_F32 or physical == PHY_F64:
        w.i64(9, nans)
    w.end(p)
