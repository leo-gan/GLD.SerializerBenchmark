from std.collections import List

from parquet_runtime.error import DecodeError


comptime LZ4_MAX = 67108864
comptime LZ4_HASH = 12


def _extra(mut out: List[Byte], value: Int):
    var extra = value
    while extra >= 255:
        out.append(Byte(255))
        extra -= 255
    out.append(Byte(extra))


def _lit(mut out: List[Byte], raw: List[Byte], anchor: Int, end: Int):
    var lit = end - anchor
    var tok = len(out)
    out.append(Byte(0))
    if lit >= 15:
        out[tok] = Byte(15 << 4)
        _extra(out, lit - 15)
    else:
        out[tok] = Byte(lit << 4)
    var base = len(out)
    out.resize(base + lit, Byte(0))
    var i = 0
    while i < lit:
        out[base + i] = raw[anchor + i]
        i += 1


def _seq(mut out: List[Byte], raw: List[Byte], anchor: Int, at: Int, offset: Int, mlen: Int):
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
        _extra(out, lit - 15)
    var base = len(out)
    out.resize(base + lit, Byte(0))
    var i = 0
    while i < lit:
        out[base + i] = raw[anchor + i]
        i += 1
    out.append(Byte(offset & 255))
    out.append(Byte((offset >> 8) & 255))
    if ml >= 15:
        _extra(out, ml - 15)


def lz4_raw_compress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    var n = len(raw)
    if n > LZ4_MAX:
        raise DecodeError(DecodeError.KIND_COMPRESSION, n)
    var out = List[Byte]()
    if n == 0:
        out.append(Byte(0))
        return out^
    if n < 13:
        _lit(out, raw, 0, n)
        return out^
    var bits = 8
    var cap = 256
    while bits < LZ4_HASH and cap < n:
        bits += 1
        cap = cap << 1
    var table = List[Int]()
    table.resize(cap, -1)
    var shift = UInt32(32 - bits)
    var anchor = 0
    var i = 0
    while i <= n - 12:
        var v = UInt32(Int(raw[i])) | (UInt32(Int(raw[i + 1])) << 8) | (UInt32(Int(raw[i + 2])) << 16) | (UInt32(Int(raw[i + 3])) << 24)
        var h = Int((v * UInt32(2654435761)) >> shift)
        var src = table[h]
        table[h] = i
        if src < 0 or i - src > 65535 or i - src <= 0 or raw[src] != raw[i] or raw[src + 1] != raw[i + 1] or raw[src + 2] != raw[i + 2] or raw[src + 3] != raw[i + 3]:
            i += 1
        else:
            var m = 4
            var max_m = n - 5 - i
            if max_m < 4:
                max_m = 4
            while m < max_m and raw[src + m] == raw[i + m]:
                m += 1
            _seq(out, raw, anchor, i, i - src, m)
            i += m
            anchor = i
    _lit(out, raw, anchor, n)
    return out^


def lz4_raw_decompress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    var out = List[Byte]()
    var i = 0
    var n = len(raw)
    if n == 0:
        return out^
    while i < n:
        var token = Int(raw[i])
        i += 1
        var lit = token >> 4
        if lit == 15:
            while True:
                if i >= n:
                    raise DecodeError(DecodeError.KIND_COMPRESSION, i)
                var extra = Int(raw[i])
                i += 1
                lit += extra
                if extra != 255:
                    break
        if i + lit > n or len(out) + lit > LZ4_MAX:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        if lit > 0:
            var base = len(out)
            out.resize(base + lit, Byte(0))
            var k = 0
            while k < lit:
                out[base + k] = raw[i]
                i += 1
                k += 1
        if i >= n:
            break
        if i + 2 > n:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        var offset = Int(raw[i]) | (Int(raw[i + 1]) << 8)
        i += 2
        if offset <= 0 or offset > len(out):
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        var mlen = (token & 15) + 4
        if (token & 15) == 15:
            while True:
                if i >= n:
                    raise DecodeError(DecodeError.KIND_COMPRESSION, i)
                var extra = Int(raw[i])
                i += 1
                mlen += extra
                if extra != 255:
                    break
        if len(out) + mlen > LZ4_MAX:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        if mlen > 0:
            var base2 = len(out)
            var start = base2 - offset
            out.resize(base2 + mlen, Byte(0))
            var k2 = 0
            while k2 < mlen:
                out[base2 + k2] = out[start + k2]
                k2 += 1
    return out^


def _be32(raw: List[Byte], i: Int) -> Int:
    return (Int(raw[i]) << 24) | (Int(raw[i + 1]) << 16) | (Int(raw[i + 2]) << 8) | Int(raw[i + 3])


def lz4_hadoop_decompress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    """Deprecated Parquet LZ4: big-endian uncompressed size, compressed size, then one raw block."""
    var out = List[Byte]()
    var i = 0
    var n = len(raw)
    if n == 0:
        return out^
    while i + 8 <= n:
        var usize = _be32(raw, i)
        var csize = _be32(raw, i + 4)
        i += 8
        if usize < 0 or csize < 0 or i + csize > n or usize > LZ4_MAX:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        if csize == usize:
            var base = len(out)
            out.resize(base + csize, Byte(0))
            var k = 0
            while k < csize:
                out[base + k] = raw[i + k]
                k += 1
        else:
            var block = List[Byte]()
            var k = 0
            while k < csize:
                block.append(raw[i + k])
                k += 1
            var dec = lz4_raw_decompress(block)
            if len(dec) != usize:
                raise DecodeError(DecodeError.KIND_COMPRESSION, i)
            k = 0
            while k < len(dec):
                out.append(dec[k])
                k += 1
        i += csize
    if i != n:
        raise DecodeError(DecodeError.KIND_COMPRESSION, i)
    return out^
