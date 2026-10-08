from std.collections import List, Span

from parquet_compress.gzip import gzip_decompress
from parquet_compress.lz4raw import lz4_hadoop_decompress, lz4_raw_decompress
from parquet_compress.snappy import snappy_decompress
from parquet_compress.zstd import zstd_decompress
from parquet_runtime.buf import crc32_bytes, i32_at, i64_at, i64_of, slice_list, u32_at
from parquet_runtime.error import DecodeError
from parquet_runtime.model import (
    CODEC_GZIP,
    CODEC_LZ4,
    CODEC_LZ4_RAW,
    CODEC_NONE,
    CODEC_SNAPPY,
    CODEC_ZSTD,
    ENC_ALP,
    ENC_BITPACK,
    ENC_BSS,
    ENC_DELTA,
    ENC_DELTA_BA,
    ENC_DELTA_LEN,
    ENC_DICT,
    ENC_PLAIN,
    ENC_RLE,
    ENC_RLE_DICT,
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
)
from parquet_runtime.pack import (
    bss_decode,
    delta_ba_decode,
    delta_int_decode,
    delta_len_ba_decode,
    level_width,
    levels_decode,
    plain_ba_decode,
    plain_bool_decode,
    plain_i32_decode,
    plain_i64_decode,
    rle_decode,
)
from parquet_runtime.thrift import TRead, T_I32, T_STRUCT
from parquet_wire.footer import Footer, read_footer


struct Page:
    var kind: Int
    var uncomp: Int
    var comp: Int
    var crc: Int
    var has_crc: Int
    var num_values: Int
    var encoding: Int
    var def_enc: Int
    var rep_enc: Int
    var num_nulls: Int
    var num_rows: Int
    var def_bytes: Int
    var rep_bytes: Int
    var compressed: Int
    var dict_n: Int
    var hdr: Int

    def __init__(out self):
        self.kind = 0
        self.uncomp = 0
        self.comp = 0
        self.crc = 0
        self.has_crc = 0
        self.num_values = 0
        self.encoding = 0
        self.def_enc = 3
        self.rep_enc = 3
        self.num_nulls = 0
        self.num_rows = 0
        self.def_bytes = 0
        self.rep_bytes = 0
        self.compressed = 1
        self.dict_n = 0
        self.hdr = 0


def _span_copy[origin: ImmOrigin](raw: Span[Byte, origin], off: Int, n: Int) raises DecodeError -> List[Byte]:
    if n < 0 or off < 0 or off + n > len(raw):
        raise DecodeError(DecodeError.KIND_EOF, off)
    var out = List[Byte]()
    if n == 0:
        return out^
    out.resize(n, Byte(0))
    var i = 0
    while i < n:
        out[i] = raw[off + i]
        i += 1
    return out^


def _decompress(codec: Int, raw: List[Byte]) raises DecodeError -> List[Byte]:
    if codec == CODEC_NONE:
        return slice_list(raw, 0, len(raw))
    if codec == CODEC_SNAPPY:
        return snappy_decompress(raw)
    if codec == CODEC_GZIP:
        return gzip_decompress(raw)
    if codec == CODEC_ZSTD:
        return zstd_decompress(raw)
    if codec == CODEC_LZ4_RAW:
        return lz4_raw_decompress(raw)
    if codec == CODEC_LZ4:
        return lz4_hadoop_decompress(raw)
    raise DecodeError(DecodeError.KIND_COMPRESSION, codec)


def _read_page[origin: ImmOrigin](raw: Span[Byte, origin], pos: Int) raises DecodeError -> Page:
    var rd = TRead(raw)
    rd.i = pos
    var page = Page()
    while rd.next() != 0:
        if rd.fid == 1:
            page.kind = rd.read_i32()
        elif rd.fid == 2:
            page.uncomp = rd.read_i32()
        elif rd.fid == 3:
            page.comp = rd.read_i32()
        elif rd.fid == 4:
            page.crc = rd.read_i32()
            page.has_crc = 1
        elif rd.fid == 5:
            var prev = rd.enter()
            while rd.next() != 0:
                if rd.fid == 1:
                    page.num_values = rd.read_i32()
                elif rd.fid == 2:
                    page.encoding = rd.read_i32()
                elif rd.fid == 3:
                    page.def_enc = rd.read_i32()
                elif rd.fid == 4:
                    page.rep_enc = rd.read_i32()
                else:
                    rd.skip()
            rd.leave(prev)
        elif rd.fid == 7:
            var prev = rd.enter()
            while rd.next() != 0:
                if rd.fid == 1:
                    page.dict_n = rd.read_i32()
                elif rd.fid == 2:
                    page.encoding = rd.read_i32()
                else:
                    rd.skip()
            rd.leave(prev)
        elif rd.fid == 8:
            var prev = rd.enter()
            while rd.next() != 0:
                if rd.fid == 1:
                    page.num_values = rd.read_i32()
                elif rd.fid == 2:
                    page.num_nulls = rd.read_i32()
                elif rd.fid == 3:
                    page.num_rows = rd.read_i32()
                elif rd.fid == 4:
                    page.encoding = rd.read_i32()
                elif rd.fid == 5:
                    page.def_bytes = rd.read_i32()
                elif rd.fid == 6:
                    page.rep_bytes = rd.read_i32()
                elif rd.fid == 7:
                    page.compressed = rd.read_bool()
                else:
                    rd.skip()
            rd.leave(prev)
        else:
            rd.skip()
    page.hdr = rd.i - pos
    _ = T_I32
    _ = T_STRUCT
    return page^


def _pow10(i: Int, neg: Int) -> UInt64:
    if neg == 0:
        if i == 0:
            return UInt64(0x3FF0000000000000)
        if i == 1:
            return UInt64(0x4024000000000000)
        if i == 2:
            return UInt64(0x4059000000000000)
        if i == 3:
            return UInt64(0x408F400000000000)
        if i == 4:
            return UInt64(0x40C3880000000000)
        if i == 5:
            return UInt64(0x40F86A0000000000)
        if i == 6:
            return UInt64(0x412E848000000000)
        if i == 7:
            return UInt64(0x416312D000000000)
        if i == 8:
            return UInt64(0x4197D78400000000)
        if i == 9:
            return UInt64(0x41CDCD6500000000)
        if i == 10:
            return UInt64(0x4202A05F20000000)
        if i == 11:
            return UInt64(0x42374876E8000000)
        if i == 12:
            return UInt64(0x426D1A94A2000000)
        if i == 13:
            return UInt64(0x42A2309CE5400000)
        if i == 14:
            return UInt64(0x42D6BCC41E900000)
        if i == 15:
            return UInt64(0x430C6BF526340000)
        if i == 16:
            return UInt64(0x4341C37937E08000)
        if i == 17:
            return UInt64(0x4376345785D8A000)
        return UInt64(0x43ABC16D674EC800)
    if i == 0:
        return UInt64(0x3FF0000000000000)
    if i == 1:
        return UInt64(0x3FB999999999999A)
    if i == 2:
        return UInt64(0x3F847AE147AE147B)
    if i == 3:
        return UInt64(0x3F50624DD2F1A9FC)
    if i == 4:
        return UInt64(0x3F1A36E2EB1C432D)
    if i == 5:
        return UInt64(0x3EE4F8B588E368F1)
    if i == 6:
        return UInt64(0x3EB0C6F7A0B5ED8D)
    if i == 7:
        return UInt64(0x3E7AD7F29ABCAF48)
    if i == 8:
        return UInt64(0x3E45798EE2308C3A)
    if i == 9:
        return UInt64(0x3E112E0BE826D695)
    if i == 10:
        return UInt64(0x3DDB7CDFD9D7BDBB)
    if i == 11:
        return UInt64(0x3DA5FD7FE1796495)
    if i == 12:
        return UInt64(0x3D719799812DEA11)
    if i == 13:
        return UInt64(0x3D3C25C268497682)
    if i == 14:
        return UInt64(0x3D06849B86A12B9B)
    if i == 15:
        return UInt64(0x3CD203AF9EE75616)
    if i == 16:
        return UInt64(0x3C9CD2B297D889BC)
    if i == 17:
        return UInt64(0x3C670EF54646D497)
    return UInt64(0x3C32725DD1D243AC)


def _pow10_f32(i: Int, neg: Int) -> UInt32:
    if neg == 0:
        if i == 0:
            return UInt32(0x3F800000)
        if i == 1:
            return UInt32(0x41200000)
        if i == 2:
            return UInt32(0x42C80000)
        if i == 3:
            return UInt32(0x447A0000)
        if i == 4:
            return UInt32(0x461C4000)
        if i == 5:
            return UInt32(0x47C35000)
        if i == 6:
            return UInt32(0x49742400)
        if i == 7:
            return UInt32(0x4B189680)
        if i == 8:
            return UInt32(0x4CBEBC20)
        if i == 9:
            return UInt32(0x4E6E6B28)
        return UInt32(0x501502F9)
    if i == 0:
        return UInt32(0x3F800000)
    if i == 1:
        return UInt32(0x3DCCCCCD)
    if i == 2:
        return UInt32(0x3C23D70A)
    if i == 3:
        return UInt32(0x3A83126F)
    if i == 4:
        return UInt32(0x38D1B717)
    if i == 5:
        return UInt32(0x3727C5AC)
    if i == 6:
        return UInt32(0x358637BD)
    if i == 7:
        return UInt32(0x33D6BF95)
    if i == 8:
        return UInt32(0x322BCC77)
    if i == 9:
        return UInt32(0x3089705F)
    return UInt32(0x2EDBE6FF)


def _u16(raw: List[Byte], i: Int) -> Int:
    return Int(raw[i]) | (Int(raw[i + 1]) << 8)


def decode_alp(raw: List[Byte], off: Int, wide: Int) raises DecodeError -> List[UInt64]:
    if off + 7 > len(raw):
        raise DecodeError(DecodeError.KIND_ENCODING, off)
    if Int(raw[off]) != 0 or Int(raw[off + 1]) != 0:
        raise DecodeError(DecodeError.KIND_ENCODING, off)
    var logv = Int(raw[off + 2])
    if logv < 3 or logv > 15:
        raise DecodeError(DecodeError.KIND_ENCODING, off)
    var count = i32_at(Span(raw), off + 3)
    var vsize = 1 << logv
    var nvec = 0
    if count > 0:
        nvec = (count + vsize - 1) // vsize
    var base = off + 7
    if base + nvec * 4 > len(raw):
        raise DecodeError(DecodeError.KIND_EOF, base)
    var out = List[UInt64]()
    var produced = 0
    var v = 0
    while v < nvec:
        var rel = u32_at(Span(raw), base + v * 4)
        var at = base + rel
        var remain = count - produced
        var n = vsize
        if remain < n:
            n = remain
        if at + 4 > len(raw):
            raise DecodeError(DecodeError.KIND_EOF, at)
        var exp = Int(raw[at])
        var fac = Int(raw[at + 1])
        var nexc = _u16(raw, at + 2)
        at += 4
        var frame = 0
        var bw = 0
        if wide == 0:
            frame = i32_at(Span(raw), at)
            bw = Int(raw[at + 4])
            at += 5
        else:
            frame = i64_at(Span(raw), at)
            bw = Int(raw[at + 8])
            at += 9
        var packed_n = 0
        if bw > 0:
            packed_n = (n * bw + 7) >> 3
        if at + packed_n + nexc * 2 > len(raw):
            raise DecodeError(DecodeError.KIND_EOF, at)
        var bit = at * 8
        var deltas = List[Int]()
        var k = 0
        while k < n:
            var relv = 0
            if bw > 0:
                var got = UInt64(0)
                var b = 0
                while b < bw:
                    var bi = bit >> 3
                    var bitv = (Int(raw[bi]) >> (bit & 7)) & 1
                    got = got | (UInt64(bitv) << UInt64(b))
                    bit += 1
                    b += 1
                relv = Int(got)
            deltas.append(frame + relv)
            k += 1
        at += packed_n
        var exc_at = List[Int]()
        exc_at.resize(n, 0)
        var ex_pos = List[Int]()
        var ex_bits = List[UInt64]()
        k = 0
        while k < nexc:
            var p = _u16(raw, at)
            at += 2
            if p < 0 or p >= n:
                raise DecodeError(DecodeError.KIND_ENCODING, at)
            exc_at[p] = 1
            ex_pos.append(p)
            k += 1
        var width = 4
        if wide != 0:
            width = 8
        k = 0
        while k < nexc:
            var bits = UInt64(0)
            var b = 0
            while b < width:
                bits = bits | (UInt64(Int(raw[at + b])) << UInt64(8 * b))
                b += 1
            ex_bits.append(bits)
            at += width
            k += 1
        var ei = 0
        k = 0
        while k < n:
            if exc_at[k] != 0:
                out.append(ex_bits[ei])
                ei += 1
            else:
                var encoded = deltas[k]
                if wide == 0:
                    var f = Float32(encoded)
                    f = f * Float32(from_bits=_pow10_f32(fac, 0))
                    f = f * Float32(from_bits=_pow10_f32(exp, 1))
                    out.append(UInt64(f.to_bits()))
                else:
                    var d = Float64(encoded)
                    d = d * Float64(from_bits=_pow10(fac, 0))
                    d = d * Float64(from_bits=_pow10(exp, 1))
                    out.append(UInt64(d.to_bits()))
            k += 1
        produced += n
        v += 1
    if produced != count:
        raise DecodeError(DecodeError.KIND_ENCODING, off)
    return out^


def _find(imm schema: Schema, path: String) raises DecodeError -> Int:
    var node = 0
    var raw = path.as_bytes()
    var i = 0
    var n = len(raw)
    if n == 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    while i < n:
        var j = i
        while j < n and Int(raw[j]) != 31:
            j += 1
        var hit = -1
        var c = 0
        while c < schema.nchild[node]:
            var ch = schema.child(node, c)
            var name = schema.name[ch].as_bytes()
            if len(name) == j - i:
                var ok = 1
                var k = 0
                while k < len(name):
                    if name[k] != raw[i + k]:
                        ok = 0
                    k += 1
                if ok != 0:
                    hit = ch
            c += 1
        if hit < 0:
            raise DecodeError(DecodeError.KIND_SCHEMA, i)
        node = hit
        i = j
        if i < n:
            i += 1
    return node


def _append_plain(mut cols: Cols, physical: Int, type_len: Int, buf: List[Byte], mut i: Int, count: Int) raises DecodeError:
    if count <= 0:
        return
    if physical == PHY_BOOL:
        var vals = plain_bool_decode(buf, i, len(buf), count)
        var k = 0
        while k < count:
            cols.add_i64(vals[k])
            k += 1
        i += (count + 7) >> 3
    elif physical == PHY_I32:
        if count < 0 or i + count * 4 > len(buf):
            raise DecodeError(DecodeError.KIND_EOF, i)
        var base = len(cols.i64s)
        cols.i64s.resize(base + count, 0)
        var k = 0
        while k < count:
            var o = i + k * 4
            var u = Int(buf[o]) | (Int(buf[o + 1]) << 8) | (Int(buf[o + 2]) << 16) | (Int(buf[o + 3]) << 24)
            if u >= 2147483648:
                u = u - 4294967296
            cols.i64s[base + k] = u
            k += 1
        cols.val_n[cols.cur] += count
        i += count * 4
    elif physical == PHY_I64:
        if count < 0 or i + count * 8 > len(buf):
            raise DecodeError(DecodeError.KIND_EOF, i)
        var base = len(cols.i64s)
        cols.i64s.resize(base + count, 0)
        var k = 0
        while k < count:
            var o = i + k * 8
            var u = UInt64(0)
            var b = 0
            while b < 8:
                u = u | (UInt64(Int(buf[o + b])) << UInt64(8 * b))
                b += 1
            cols.i64s[base + k] = i64_of(u)
            k += 1
        cols.val_n[cols.cur] += count
        i += count * 8
    elif physical == PHY_F32:
        var k = 0
        while k < count:
            var u = u32_at(Span(buf), i)
            cols.add_bits(UInt64(u))
            i += 4
            k += 1
    elif physical == PHY_F64:
        var k = 0
        while k < count:
            var b = 0
            var u = UInt64(0)
            while b < 8:
                u = u | (UInt64(Int(buf[i + b])) << UInt64(8 * b))
                b += 1
            cols.add_bits(u)
            i += 8
            k += 1
    elif physical == PHY_BA:
        var seq = plain_ba_decode(buf, i, len(buf), count)
        var base = len(cols.raw)
        var nr = len(seq.raw)
        if nr > 0:
            cols.raw.resize(base + nr, Byte(0))
            var t = 0
            while t < nr:
                cols.raw[base + t] = seq.raw[t]
                t += 1
        var k = 0
        while k < count:
            cols.ends.append(base + seq.ends[k])
            k += 1
        cols.val_n[cols.cur] += count
        i += seq.used
    elif physical == PHY_FIXED or physical == PHY_I96:
        var width = type_len
        if physical == PHY_I96:
            width = 12
        var k = 0
        while k < count:
            var piece = slice_list(buf, i, width)
            cols.add_bytes(piece)
            i += width
            k += 1
    else:
        raise DecodeError(DecodeError.KIND_TYPE, i)


def _read_chunk[origin: ImmOrigin](file: Span[Byte, origin], mut cols: Cols, imm schema: Schema, imm foot: Footer, col: Int) raises DecodeError:
    var node = _find(schema, foot.col_path[col])
    var physical = schema.physical[node]
    var type_len = schema.type_len[node]
    var max_def = schema.max_def[node]
    var max_rep = schema.max_rep[node]
    var start = foot.col_data[col]
    if foot.col_dict[col] >= 0:
        start = foot.col_dict[col]
    var end = start + foot.col_comp[col]
    if end > len(file) or start < 0:
        raise DecodeError(DecodeError.KIND_EOF, start)
    var dict_i = List[Int]()
    var dict_b = List[UInt64]()
    var dict_raw = List[Byte]()
    var dict_ends = List[Int]()
    var pos = start
    while pos < end:
        var page = _read_page(file, pos)
        var body_at = pos + page.hdr
        if body_at + page.comp > len(file):
            raise DecodeError(DecodeError.KIND_EOF, body_at)
        var stored = _span_copy(file, body_at, page.comp)
        if page.has_crc != 0:
            var got = crc32_bytes(stored, 0, len(stored))
            var want = page.crc
            if got < 0:
                got = got + 4294967296
            if want < 0:
                want = want + 4294967296
            if got != want:
                raise DecodeError(DecodeError.KIND_ENCODING, body_at)
        var payload = List[Byte]()
        if page.kind == 3:
            var levels_n = page.def_bytes + page.rep_bytes
            if levels_n > len(stored):
                raise DecodeError(DecodeError.KIND_ENCODING, body_at)
            var data = slice_list(stored, levels_n, len(stored) - levels_n)
            if page.compressed != 0:
                data = _decompress(foot.col_codec[col], data)
            payload = slice_list(stored, 0, levels_n)
            var t = 0
            while t < len(data):
                payload.append(data[t])
                t += 1
        elif foot.col_codec[col] != CODEC_NONE:
            payload = _decompress(foot.col_codec[col], stored)
        else:
            payload = stored^
        if page.kind == 1:
            pos = body_at + page.comp
            continue
        if page.kind == 2:
            var tmp = Cols()
            tmp.begin(node, physical)
            var cursor = 0
            _append_plain(tmp, physical, type_len, payload, cursor, page.dict_n)
            dict_i = List[Int]()
            dict_b = List[UInt64]()
            dict_raw = List[Byte]()
            dict_ends = List[Int]()
            var k = 0
            while k < tmp.val_n[0]:
                if physical == PHY_F32 or physical == PHY_F64:
                    dict_b.append(tmp.bits[k])
                elif physical == PHY_BA or physical == PHY_FIXED or physical == PHY_I96:
                    var a = 0
                    if k > 0:
                        a = tmp.ends[k - 1]
                    var b = tmp.ends[k]
                    while a < b:
                        dict_raw.append(tmp.raw[a])
                        a += 1
                    dict_ends.append(len(dict_raw))
                else:
                    dict_i.append(tmp.i64s[k])
                k += 1
        else:
            var defs = List[Int]()
            var reps = List[Int]()
            var cursor = 0
            var bitpack_def = 0
            var bitpack_rep = 0
            if page.def_enc == ENC_BITPACK:
                bitpack_def = 1
            if page.rep_enc == ENC_BITPACK:
                bitpack_rep = 1
            var with_len = 1
            if page.kind == 3:
                with_len = 0
                if max_rep > 0:
                    var stop = cursor + page.rep_bytes
                    reps = levels_decode(payload, cursor, stop, level_width(max_rep), page.num_values, 0, bitpack_rep)
                    cursor = stop
                if max_def > 0:
                    var stop2 = cursor + page.def_bytes
                    defs = levels_decode(payload, cursor, stop2, level_width(max_def), page.num_values, 0, bitpack_def)
                    cursor = stop2
            else:
                if max_rep > 0:
                    reps = levels_decode(payload, cursor, len(payload), level_width(max_rep), page.num_values, with_len, bitpack_rep)
                if max_def > 0:
                    defs = levels_decode(payload, cursor, len(payload), level_width(max_def), page.num_values, with_len, bitpack_def)
            var nonnull = page.num_values
            if max_def > 0:
                nonnull = 0
                var k = 0
                while k < page.num_values:
                    if defs[k] == max_def:
                        nonnull += 1
                    k += 1
            var values_i = List[Int]()
            var values_b = List[UInt64]()
            var values_raw = List[Byte]()
            var values_ends = List[Int]()
            if page.encoding == ENC_RLE_DICT or page.encoding == ENC_DICT:
                var width = 0
                if cursor < len(payload):
                    width = Int(payload[cursor])
                    cursor += 1
                var idx = rle_decode(payload, cursor, len(payload), width, nonnull)
                var k = 0
                while k < nonnull:
                    var id = idx[k]
                    if physical == PHY_F32 or physical == PHY_F64:
                        values_b.append(dict_b[id])
                    elif physical == PHY_BA or physical == PHY_FIXED or physical == PHY_I96:
                        var a = 0
                        if id > 0:
                            a = dict_ends[id - 1]
                        var b = dict_ends[id]
                        while a < b:
                            values_raw.append(dict_raw[a])
                            a += 1
                        values_ends.append(len(values_raw))
                    else:
                        values_i.append(dict_i[id])
                    k += 1
            elif page.encoding == ENC_PLAIN or page.encoding == ENC_RLE:
                var tmp = Cols()
                tmp.begin(node, physical)
                if page.encoding == ENC_RLE and physical == PHY_BOOL:
                    var vals = levels_decode(payload, cursor, len(payload), 1, nonnull, 1, 0)
                    var k = 0
                    while k < nonnull:
                        tmp.add_i64(vals[k])
                        k += 1
                else:
                    _append_plain(tmp, physical, type_len, payload, cursor, nonnull)
                _copy_i(tmp.i64s, values_i)
                _copy_u(tmp.bits, values_b)
                _copy_b(tmp.raw, values_raw)
                _copy_i(tmp.ends, values_ends)
            elif page.encoding == ENC_DELTA:
                var bits = 64
                if physical == PHY_I32:
                    bits = 32
                var got = delta_int_decode(payload, cursor, len(payload), bits)
                _copy_i(got.vals, values_i)
            elif page.encoding == ENC_DELTA_LEN:
                var seq = delta_len_ba_decode(payload, cursor, len(payload))
                _copy_b(seq.raw, values_raw)
                _copy_i(seq.ends, values_ends)
            elif page.encoding == ENC_DELTA_BA:
                var seq = delta_ba_decode(payload, cursor, len(payload))
                _copy_b(seq.raw, values_raw)
                _copy_i(seq.ends, values_ends)
            elif page.encoding == ENC_BSS:
                var width = type_len
                if physical == PHY_I32 or physical == PHY_F32:
                    width = 4
                elif physical == PHY_I64 or physical == PHY_F64:
                    width = 8
                var plain = bss_decode(payload, cursor, nonnull, width)
                var tmp = Cols()
                tmp.begin(node, physical)
                var c2 = 0
                _append_plain(tmp, physical, type_len, plain, c2, nonnull)
                _copy_i(tmp.i64s, values_i)
                _copy_u(tmp.bits, values_b)
                _copy_b(tmp.raw, values_raw)
                _copy_i(tmp.ends, values_ends)
            elif page.encoding == ENC_ALP:
                var wide = 0
                if physical == PHY_F64:
                    wide = 1
                values_b = decode_alp(payload, cursor, wide)
            else:
                raise DecodeError(DecodeError.KIND_ENCODING, body_at, page.encoding)
            var vi = 0
            var k = 0
            while k < page.num_values:
                var d = max_def
                var r = 0
                if max_def > 0:
                    d = defs[k]
                if max_rep > 0:
                    r = reps[k]
                if max_def > 0 or max_rep > 0:
                    cols.add_level(d, r)
                if d == max_def:
                    if physical == PHY_F32 or physical == PHY_F64 or page.encoding == ENC_ALP:
                        cols.add_bits(values_b[vi])
                    elif physical == PHY_BA or physical == PHY_FIXED or physical == PHY_I96:
                        var a = 0
                        if vi > 0:
                            a = values_ends[vi - 1]
                        var piece = slice_list(values_raw, a, values_ends[vi] - a)
                        cols.add_bytes(piece)
                    else:
                        cols.add_i64(values_i[vi])
                    vi += 1
                k += 1
        pos = body_at + page.comp


def _copy_i(imm src: List[Int], mut dst: List[Int]):
    var i = 0
    while i < len(src):
        dst.append(src[i])
        i += 1


def _copy_b(imm src: List[Byte], mut dst: List[Byte]):
    var i = 0
    while i < len(src):
        dst.append(src[i])
        i += 1


def _copy_u(imm src: List[UInt64], mut dst: List[UInt64]):
    var i = 0
    while i < len(src):
        dst.append(src[i])
        i += 1


struct Table:
    var foot: Footer
    var cols: Cols
    var nrows: Int

    def __init__(out self):
        self.foot = Footer()
        self.cols = Cols()
        self.nrows = 0


def decode_table[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> Table:
    var foot = read_footer(raw)
    var table = Table()
    table.nrows = foot.nrows
    var slots = List[Int]()
    var s = 0
    while s < foot.schema.nleaves:
        slots.append(-1)
        s += 1
    var leaf = 0
    while leaf < foot.schema.nleaves:
        var rg = 0
        while rg < len(foot.rg_rows):
            var col = foot.rg_col0[rg] + leaf
            var node = _find(foot.schema, foot.col_path[col])
            if slots[leaf] < 0:
                table.cols.begin(node, foot.schema.physical[node])
                slots[leaf] = table.cols.cur
            else:
                table.cols.use(slots[leaf])
            _read_chunk(raw, table.cols, foot.schema, foot, col)
            rg += 1
        leaf += 1
    table.nrows = foot.nrows
    table.foot = foot^
    return table^
