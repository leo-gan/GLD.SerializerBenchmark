from std.collections import List, Span

from arrow_compress.xxh import xxh32_list
from arrow_runtime.error import DecodeError


comptime LZ4_MAGIC = 0x184D2204
comptime LZ4_BLOCK_MAX = 65536
comptime LZ4_HASH_LOG = 12


def lz4_frame_compress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    var out = List[Byte]()
    out.append(Byte(0x04))
    out.append(Byte(0x22))
    out.append(Byte(0x4D))
    out.append(Byte(0x18))
    var flg = 0x60
    var bd = 0x40
    var hdr = List[Byte]()
    hdr.append(Byte(flg))
    hdr.append(Byte(bd))
    var sum = xxh32_list(hdr)
    out.append(Byte(flg))
    out.append(Byte(bd))
    out.append(Byte(Int((sum >> 8) & 0xFF)))
    if len(raw) == 0:
        _write_stored(out, raw, 0, 0)
    else:
        var off = 0
        while off < len(raw):
            var take = len(raw) - off
            if take > LZ4_BLOCK_MAX:
                take = LZ4_BLOCK_MAX
            _write_block(out, raw, off, take)
            off += take
    out.append(Byte(0))
    out.append(Byte(0))
    out.append(Byte(0))
    out.append(Byte(0))
    return out^


def lz4_frame_decompress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    if len(raw) < 7:
        raise DecodeError(DecodeError.KIND_COMPRESSION, 0)
    var magic = _u32(raw, 0)
    if magic != LZ4_MAGIC:
        raise DecodeError(DecodeError.KIND_COMPRESSION, 0)
    var flg = Int(raw[4])
    var bd = Int(raw[5])
    if (flg >> 6) != 1 or (flg & 0x02) != 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, 4)
    if (bd & 0x8F) != 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, 5)
    var max_code = (bd >> 4) & 7
    var block_max = _lz4_block_max(max_code)
    var independent = (flg >> 5) & 1
    var block_check = (flg >> 4) & 1
    var size_flag = (flg >> 3) & 1
    var content_check = (flg >> 2) & 1
    var dict_flag = flg & 1
    var hdr = List[Byte]()
    hdr.append(raw[4])
    hdr.append(raw[5])
    var pos = 6
    var content_size = -1
    if size_flag != 0:
        if pos + 8 > len(raw):
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var declared = _u64(raw, pos)
        if declared > UInt64(67108864):
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        content_size = Int(declared)
        var k = 0
        while k < 8:
            hdr.append(raw[pos + k])
            k += 1
        pos += 8
    if dict_flag != 0:
        if pos + 4 > len(raw):
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var k = 0
        while k < 4:
            hdr.append(raw[pos + k])
            k += 1
        pos += 4
    if pos >= len(raw):
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var expect = Int((xxh32_list(hdr) >> 8) & 0xFF)
    if Int(raw[pos]) != expect:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    pos += 1
    if dict_flag != 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, 4)
    var out = List[Byte]()
    while True:
        if pos + 4 > len(raw):
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var size_word = _u32(raw, pos)
        pos += 4
        if size_word == 0:
            break
        var stored = (size_word & 0x80000000) != 0
        var size = size_word & 0x7FFFFFFF
        if size > block_max or pos + size > len(raw):
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var block = List[Byte]()
        var k = 0
        while k < size:
            block.append(raw[pos + k])
            k += 1
        pos += size
        if block_check != 0:
            if pos + 4 > len(raw):
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            var got = _u32(raw, pos)
            pos += 4
            if got != Int(xxh32_list(block)):
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var block_at = len(out)
        if stored:
            k = 0
            while k < len(block):
                out.append(block[k])
                k += 1
        else:
            _lz4_block(block, out, block_at, independent)
        if len(out) > 67108864:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    if content_check != 0:
        if pos + 4 > len(raw):
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var got = _u32(raw, pos)
        pos += 4
        if got != Int(xxh32_list(out)):
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    if content_size >= 0 and content_size != len(out):
        raise DecodeError(DecodeError.KIND_COMPRESSION, 0)
    if pos != len(raw):
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    return out^


def _write_block(mut out: List[Byte], raw: List[Byte], off: Int, n: Int):
    var slice = List[Byte]()
    var i = 0
    while i < n:
        slice.append(raw[off + i])
        i += 1
    var comp = _lz4_compress_block(slice)
    if len(comp) >= n:
        _write_stored(out, raw, off, n)
    else:
        _put_u32(out, len(comp))
        i = 0
        while i < len(comp):
            out.append(comp[i])
            i += 1


def _write_stored(mut out: List[Byte], raw: List[Byte], off: Int, n: Int):
    var size = n | 0x80000000
    _put_u32(out, size)
    var i = 0
    while i < n:
        out.append(raw[off + i])
        i += 1


def _lz4_compress_block(raw: List[Byte]) -> List[Byte]:
    var out = List[Byte]()
    var n = len(raw)
    if n < 13:
        _emit_literals(out, raw, 0, n)
        return out^
    var table = List[Int]()
    table.resize(1 << LZ4_HASH_LOG, -1)
    var anchor = 0
    var i = 0
    while i <= n - 12:
        var h = _hash4(raw, i)
        var src_at = table[h]
        table[h] = i
        if src_at < 0 or i - src_at > 65535 or not _match4(raw, src_at, i):
            i += 1
        else:
            var m = 4
            var max_m = n - 5 - i
            while m < max_m and raw[src_at + m] == raw[i + m]:
                m += 1
            _emit_sequence(out, raw, anchor, i, i - src_at, m)
            i += m
            anchor = i
    _emit_literals(out, raw, anchor, n)
    return out^


def _match4(raw: List[Byte], a: Int, b: Int) -> Bool:
    return raw[a] == raw[b] and raw[a + 1] == raw[b + 1] and raw[a + 2] == raw[b + 2] and raw[a + 3] == raw[b + 3]


def _hash4(raw: List[Byte], i: Int) -> Int:
    var v = UInt32(Int(raw[i]))
    v = v | (UInt32(Int(raw[i + 1])) << 8)
    v = v | (UInt32(Int(raw[i + 2])) << 16)
    v = v | (UInt32(Int(raw[i + 3])) << 24)
    var shift = UInt32(32 - LZ4_HASH_LOG)
    return Int((v * UInt32(2654435761)) >> shift)


def _emit_literals(mut out: List[Byte], raw: List[Byte], anchor: Int, end: Int):
    var lit = end - anchor
    var tok = len(out)
    out.append(Byte(0))
    if lit >= 15:
        out[tok] = Byte(15 << 4)
        _emit_extra(out, lit - 15)
    else:
        out[tok] = Byte(lit << 4)
    var i = anchor
    while i < end:
        out.append(raw[i])
        i += 1


def _emit_sequence(mut out: List[Byte], raw: List[Byte], anchor: Int, at: Int, offset: Int, mlen: Int):
    var lit = at - anchor
    var tok = len(out)
    out.append(Byte(0))
    var ll = lit
    if ll > 15:
        ll = 15
    var ml = mlen - 4
    var mm = ml
    if mm > 15:
        mm = 15
    out[tok] = Byte((ll << 4) | mm)
    if lit >= 15:
        _emit_extra(out, lit - 15)
    var i = anchor
    while i < at:
        out.append(raw[i])
        i += 1
    out.append(Byte(offset & 255))
    out.append(Byte((offset >> 8) & 255))
    if ml >= 15:
        _emit_extra(out, ml - 15)


def _emit_extra(mut out: List[Byte], value: Int):
    var extra = value
    while extra >= 255:
        out.append(Byte(255))
        extra -= 255
    out.append(Byte(extra))


def _lz4_block(src: List[Byte], mut out: List[Byte], block_at: Int, independent: Int) raises DecodeError:
    var i = 0
    var n = len(src)
    while i < n:
        var token = Int(src[i])
        i += 1
        var lit = token >> 4
        if lit == 15:
            while True:
                if i >= n:
                    raise DecodeError(DecodeError.KIND_COMPRESSION, i)
                var extra = Int(src[i])
                i += 1
                lit += extra
                if extra != 255:
                    break
        if lit < 0 or i + lit > n:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        var k = 0
        while k < lit:
            out.append(src[i])
            i += 1
            k += 1
        if i >= n:
            break
        if i + 2 > n:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        var offset = Int(src[i]) | (Int(src[i + 1]) << 8)
        i += 2
        if offset <= 0 or offset > len(out):
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        if independent != 0 and offset > len(out) - block_at:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        var mlen = (token & 15) + 4
        if (token & 15) == 15:
            while True:
                if i >= n:
                    raise DecodeError(DecodeError.KIND_COMPRESSION, i)
                var extra = Int(src[i])
                i += 1
                mlen += extra
                if extra != 255:
                    break
        var mpos = len(out) - offset
        k = 0
        while k < mlen:
            out.append(out[mpos + k])
            k += 1
    if len(out) > 67108864:
        raise DecodeError(DecodeError.KIND_COMPRESSION, i)


def _lz4_block_max(code: Int) raises DecodeError -> Int:
    if code == 4:
        return 65536
    if code == 5:
        return 262144
    if code == 6:
        return 1048576
    if code == 7:
        return 4194304
    raise DecodeError(DecodeError.KIND_COMPRESSION, 5)


def _put_u32(mut out: List[Byte], v: Int):
    out.append(Byte(v & 255))
    out.append(Byte((v >> 8) & 255))
    out.append(Byte((v >> 16) & 255))
    out.append(Byte((v >> 24) & 255))


def _u32(raw: List[Byte], i: Int) -> Int:
    return Int(raw[i]) | (Int(raw[i + 1]) << 8) | (Int(raw[i + 2]) << 16) | (Int(raw[i + 3]) << 24)


def _u64(raw: List[Byte], i: Int) -> UInt64:
    var x = UInt64(0)
    var k = 7
    while k >= 0:
        x = (x << 8) | UInt64(Int(raw[i + k]))
        k -= 1
    return x
