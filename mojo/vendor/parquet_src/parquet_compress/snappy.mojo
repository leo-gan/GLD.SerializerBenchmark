from std.collections import List

from parquet_runtime.error import DecodeError


comptime SNAPPY_MAX = 67108864


def _varint(mut out: List[Byte], v: Int):
    var x = v
    while x >= 128:
        out.append(Byte((x & 127) | 128))
        x = x >> 7
    out.append(Byte(x))


def _uvar(raw: List[Byte], mut i: Int) raises DecodeError -> Int:
    var shift = 0
    var out = 0
    while True:
        if i >= len(raw):
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        var b = Int(raw[i])
        i += 1
        out = out | ((b & 127) << shift)
        if b < 128:
            if out > SNAPPY_MAX:
                raise DecodeError(DecodeError.KIND_COMPRESSION, i)
            return out
        shift += 7
        if shift > 28:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)


def _emit_lit(mut out: List[Byte], raw: List[Byte], a: Int, b: Int):
    var n = b - a
    if n <= 0:
        return
    var left = n
    var at = a
    while left > 0:
        var take = left
        if take > 65536:
            take = 65536
        var len_m1 = take - 1
        if len_m1 < 60:
            out.append(Byte(len_m1 << 2))
        elif len_m1 < 256:
            out.append(Byte(60 << 2))
            out.append(Byte(len_m1))
        else:
            out.append(Byte(61 << 2))
            out.append(Byte(len_m1 & 255))
            out.append(Byte((len_m1 >> 8) & 255))
        var base = len(out)
        out.resize(base + take, Byte(0))
        var k = 0
        while k < take:
            out[base + k] = raw[at + k]
            k += 1
        at += take
        left -= take


def _emit_copy(mut out: List[Byte], offset: Int, length: Int):
    var left = length
    while left > 0:
        var m = left
        if offset < 2048 and m >= 4:
            if m > 11:
                m = 11
            var code = m - 4
            var tag = 1 | (code << 2) | ((offset >> 8) << 5)
            out.append(Byte(tag))
            out.append(Byte(offset & 255))
        else:
            if m > 64:
                m = 64
            var tag = 2 | ((m - 1) << 2)
            out.append(Byte(tag))
            out.append(Byte(offset & 255))
            out.append(Byte((offset >> 8) & 255))
        left -= m


def snappy_compress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    var n = len(raw)
    if n > SNAPPY_MAX:
        raise DecodeError(DecodeError.KIND_COMPRESSION, n)
    var out = List[Byte](capacity=n + 32)
    _varint(out, n)
    if n == 0:
        return out^
    if n < 8:
        _emit_lit(out, raw, 0, n)
        return out^
    var bits = 8
    var cap = 256
    while bits < 14 and cap < n:
        bits += 1
        cap = cap << 1
    var table = List[Int]()
    table.resize(cap, -1)
    var shift = UInt32(32 - bits)
    var mask = cap - 1
    var i = 0
    var anchor = 0
    while i + 4 <= n:
        var v = UInt32(Int(raw[i])) | (UInt32(Int(raw[i + 1])) << 8) | (UInt32(Int(raw[i + 2])) << 16) | (UInt32(Int(raw[i + 3])) << 24)
        var h = Int((v * UInt32(0x1E35A7BD)) >> shift) & mask
        var src = table[h]
        table[h] = i
        var matched = 0
        if src >= 0 and i - src > 0 and i - src <= 65535:
            if raw[src] == raw[i] and raw[src + 1] == raw[i + 1] and raw[src + 2] == raw[i + 2] and raw[src + 3] == raw[i + 3]:
                var m = 4
                var max_m = n - i
                if max_m > 65536:
                    max_m = 65536
                while m < max_m and raw[src + m] == raw[i + m]:
                    m += 1
                _emit_lit(out, raw, anchor, i)
                _emit_copy(out, i - src, m)
                i = i + m
                anchor = i
                matched = 1
        if matched == 0:
            i += 1
    _emit_lit(out, raw, anchor, n)
    return out^


def snappy_decompress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    var i = 0
    var expect = _uvar(raw, i)
    var out = List[Byte]()
    if expect == 0:
        return out^
    out.resize(expect, Byte(0))
    var o = 0
    while o < expect:
        if i >= len(raw):
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        var tag = Int(raw[i])
        i += 1
        var kind = tag & 3
        if kind == 0:
            var lit = tag >> 2
            if lit >= 60:
                var extra = lit - 59
                lit = 0
                var e = 0
                while e < extra:
                    if i >= len(raw):
                        raise DecodeError(DecodeError.KIND_COMPRESSION, i)
                    lit = lit | (Int(raw[i]) << (8 * e))
                    i += 1
                    e += 1
            lit += 1
            if lit < 0 or i + lit > len(raw) or o + lit > expect:
                raise DecodeError(DecodeError.KIND_COMPRESSION, i)
            var k = 0
            while k < lit:
                out[o + k] = raw[i + k]
                k += 1
            i += lit
            o += lit
        else:
            var length = 0
            var offset = 0
            if kind == 1:
                length = ((tag >> 2) & 7) + 4
                if i >= len(raw):
                    raise DecodeError(DecodeError.KIND_COMPRESSION, i)
                offset = ((tag >> 5) << 8) | Int(raw[i])
                i += 1
            elif kind == 2:
                length = (tag >> 2) + 1
                if i + 2 > len(raw):
                    raise DecodeError(DecodeError.KIND_COMPRESSION, i)
                offset = Int(raw[i]) | (Int(raw[i + 1]) << 8)
                i += 2
            else:
                length = (tag >> 2) + 1
                if i + 4 > len(raw):
                    raise DecodeError(DecodeError.KIND_COMPRESSION, i)
                offset = Int(raw[i]) | (Int(raw[i + 1]) << 8) | (Int(raw[i + 2]) << 16) | (Int(raw[i + 3]) << 24)
                i += 4
            if offset <= 0 or offset > o or o + length > expect:
                raise DecodeError(DecodeError.KIND_COMPRESSION, i)
            var k = 0
            var start = o - offset
            while k < length:
                out[o + k] = out[start + k]
                k += 1
            o += length
    if o != expect:
        raise DecodeError(DecodeError.KIND_COMPRESSION, i)
    return out^
