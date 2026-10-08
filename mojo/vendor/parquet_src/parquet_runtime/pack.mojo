from std.collections import List, Span

from parquet_runtime.buf import i32_at, i64_at, put_i32, put_i64, put_u32, u32_at
from parquet_runtime.error import DecodeError


def _sl(v: UInt64, n: Int) -> UInt64:
    return v << UInt64(n)


def _sr(v: UInt64, n: Int) -> UInt64:
    return v >> UInt64(n)


def uleb_put(mut out: List[Byte], v: Int):
    var x = v
    if x < 0:
        x = 0
    while x >= 128:
        out.append(Byte((x & 127) | 128))
        x = x >> 7
    out.append(Byte(x))


def zz_put(mut out: List[Byte], v: Int):
    var u = UInt64(v)
    var sign = _sr(u, 63)
    var z = _sl(u, 1) ^ (UInt64(0) - sign)
    while z >= 128:
        out.append(Byte(Int((z & 127) | 128)))
        z = _sr(z, 7)
    out.append(Byte(Int(z)))


def uleb_get(raw: List[Byte], mut i: Int, end: Int) raises DecodeError -> Int:
    var shift = 0
    var out = 0
    while True:
        if i >= end or i >= len(raw):
            raise DecodeError(DecodeError.KIND_EOF, i)
        var b = Int(raw[i])
        i += 1
        out = out | ((b & 127) << shift)
        if b < 128:
            return out
        shift += 7
        if shift > 31 and (b & 127) > 1:
            raise DecodeError(DecodeError.KIND_RANGE, i)


def zz_get(raw: List[Byte], mut i: Int, end: Int) raises DecodeError -> Int:
    var shift = 0
    var u = UInt64(0)
    while True:
        if i >= end or i >= len(raw):
            raise DecodeError(DecodeError.KIND_EOF, i)
        var b = Int(raw[i])
        i += 1
        u = u | _sl(UInt64(b & 127), shift)
        if b < 128:
            break
        shift += 7
        if shift > 63:
            raise DecodeError(DecodeError.KIND_RANGE, i)
    var mag = _sr(u, 1)
    if (u & 1) == 0:
        return Int(mag)
    if mag == 0:
        return -1
    return Int(~mag)


def bits_of(v: UInt64) -> Int:
    var w = 0
    var x = v
    while x > 0:
        w += 1
        x = _sr(x, 1)
    return w


def put_low_bits(mut out: List[Byte], mut acc: UInt64, mut nbit: Int, value: UInt64, width: Int):
    var left = width
    var v = value
    while left > 0:
        var space = 64 - nbit
        var take = left
        if take > space:
            take = space
        var piece = v
        if take < 64:
            var mask = _sl(UInt64(1), take) - 1
            piece = v & mask
        acc = acc | _sl(piece, nbit)
        nbit += take
        if take == 64:
            v = 0
        else:
            v = _sr(v, take)
        left -= take
        while nbit >= 8:
            out.append(Byte(Int(acc & 255)))
            acc = _sr(acc, 8)
            nbit -= 8


def flush_bits(mut out: List[Byte], acc: UInt64, nbit: Int):
    if nbit > 0:
        out.append(Byte(Int(acc & 255)))


def take_bits(raw: List[Byte], mut bit: Int, width: Int, end: Int, msb: Int) raises DecodeError -> UInt64:
    if msb == 0 and width > 0 and width <= 56:
        var last = bit + width - 1
        if last < 0 or (last >> 3) >= end or (last >> 3) >= len(raw):
            raise DecodeError(DecodeError.KIND_EOF, bit >> 3)
        var bi = bit >> 3
        var w = UInt64(0)
        var t = 0
        while t < 8 and bi + t < len(raw):
            w = w | (UInt64(Int(raw[bi + t])) << UInt64(8 * t))
            t += 1
        var piece = w >> UInt64(bit & 7)
        piece = piece & (_sl(UInt64(1), width) - 1)
        bit += width
        return piece
    var out = UInt64(0)
    var k = 0
    while k < width:
        var bi = bit >> 3
        if bi >= end or bi >= len(raw):
            raise DecodeError(DecodeError.KIND_EOF, bi)
        var bit_i = bit & 7
        if msb != 0:
            bit_i = 7 - bit_i
        var bitv = (Int(raw[bi]) >> bit_i) & 1
        out = out | _sl(UInt64(bitv), k)
        bit += 1
        k += 1
    return out


def pack_bytes(vals: List[Int], n: Int, width: Int, msb: Int) -> List[Byte]:
    var out = List[Byte]()
    if width <= 0 or n <= 0:
        return out^
    if msb == 0:
        var acc = UInt64(0)
        var nbit = 0
        var i = 0
        while i < n:
            var mask = UInt64(0xFFFFFFFFFFFFFFFF)
            if width < 64:
                mask = _sl(UInt64(1), width) - 1
            put_low_bits(out, acc, nbit, UInt64(vals[i]) & mask, width)
            i += 1
        flush_bits(out, acc, nbit)
        return out^
    var bit = 0
    var i = 0
    while i < n:
        var v = UInt64(vals[i])
        var k = width - 1
        while k >= 0:
            var bi = bit >> 3
            while len(out) <= bi:
                out.append(Byte(0))
            var bit_i = 7 - (bit & 7)
            var bitv = Int((_sr(v, k)) & 1)
            out[bi] = Byte(Int(out[bi]) | (bitv << bit_i))
            bit += 1
            k -= 1
        i += 1
    return out^


def unpack_bytes(raw: List[Byte], off: Int, end: Int, width: Int, count: Int, msb: Int) raises DecodeError -> List[Int]:
    var out = List[Int]()
    if count <= 0:
        return out^
    var bit = off * 8
    var limit = end * 8
    var i = 0
    while i < count:
        if width <= 0:
            out.append(0)
        else:
            var u = take_bits(raw, bit, width, end, msb)
            _ = limit
            if width < 64 and u >= _sl(UInt64(1), width):
                raise DecodeError(DecodeError.KIND_ENCODING, off)
            out.append(Int(u))
        i += 1
    return out^


def rle_encode(vals: List[Int], n: Int, width: Int) -> List[Byte]:
    var out = List[Byte]()
    if n <= 0 or width < 0:
        return out^
    if width == 0:
        return out^
    var i = 0
    var nbytes = (width + 7) >> 3
    while i < n:
        var j = i + 1
        while j < n and vals[j] == vals[i] and (j - i) < 2147483647:
            j += 1
        var run = j - i
        if run >= 8 or n - i < 8:
            var header = run << 1
            uleb_put(out, header)
            var u = UInt64(vals[i])
            var b = 0
            while b < nbytes:
                out.append(Byte(Int((_sr(u, 8 * b)) & 255)))
                b += 1
            i = j
        else:
            var groups = 1
            var take = 8
            if i + take > n:
                take = n - i
            uleb_put(out, (groups << 1) | 1)
            var acc = UInt64(0)
            var nbit = 0
            var k = 0
            while k < 8:
                var v = UInt64(0)
                if k < take:
                    v = UInt64(vals[i + k])
                if width < 64:
                    v = v & (_sl(UInt64(1), width) - 1)
                put_low_bits(out, acc, nbit, v, width)
                k += 1
            flush_bits(out, acc, nbit)
            i += take
    return out^


def rle_decode(raw: List[Byte], mut i: Int, end: Int, width: Int, count: Int) raises DecodeError -> List[Int]:
    var out = List[Int]()
    if count <= 0:
        return out^
    if width == 0:
        var z = 0
        while z < count:
            out.append(0)
            z += 1
        return out^
    if width > 64:
        raise DecodeError(DecodeError.KIND_ENCODING, i)
    var nbytes = (width + 7) >> 3
    while len(out) < count:
        var header = uleb_get(raw, i, end)
        if (header & 1) == 0:
            var run = header >> 1
            if run <= 0:
                raise DecodeError(DecodeError.KIND_ENCODING, i)
            if i + nbytes > end:
                raise DecodeError(DecodeError.KIND_EOF, i)
            var u = UInt64(0)
            var b = 0
            while b < nbytes:
                u = u | _sl(UInt64(Int(raw[i + b])), 8 * b)
                b += 1
            i += nbytes
            var have = len(out)
            var add = run
            if have + add > count:
                add = count - have
            if add > 0:
                out.resize(have + add, Int(u))
        else:
            var groups = header >> 1
            if groups <= 0:
                raise DecodeError(DecodeError.KIND_ENCODING, i)
            var packed = groups * 8
            var bit = i * 8
            var need_bytes = (packed * width + 7) >> 3
            if i + need_bytes > end:
                raise DecodeError(DecodeError.KIND_EOF, i)
            var k = 0
            while k < packed:
                var u = take_bits(raw, bit, width, i + need_bytes, 0)
                if len(out) < count:
                    out.append(Int(u))
                k += 1
            i += need_bytes
    return out^


def level_width(max_level: Int) -> Int:
    var w = 0
    var m = max_level
    while m > 0:
        w += 1
        m = m >> 1
    return w


def levels_encode(vals: List[Int], n: Int, width: Int, with_len: Int) -> List[Byte]:
    var body = rle_encode(vals, n, width)
    if with_len == 0:
        return body^
    var out = List[Byte]()
    var nbody = len(body)
    out.resize(4 + nbody, Byte(0))
    var nlen = nbody
    out[0] = Byte(nlen & 255)
    out[1] = Byte((nlen >> 8) & 255)
    out[2] = Byte((nlen >> 16) & 255)
    out[3] = Byte((nlen >> 24) & 255)
    var i = 0
    while i < nbody:
        out[4 + i] = body[i]
        i += 1
    return out^


def levels_decode(raw: List[Byte], mut i: Int, end: Int, width: Int, count: Int, with_len: Int, bit_packed: Int) raises DecodeError -> List[Int]:
    if bit_packed != 0:
        var nbytes = 0
        if with_len != 0:
            if i + 4 > end:
                raise DecodeError(DecodeError.KIND_EOF, i)
            nbytes = u32_at(Span(raw), i)
            i += 4
        else:
            nbytes = (count * width + 7) >> 3
        if i + nbytes > end:
            raise DecodeError(DecodeError.KIND_EOF, i)
        var out = unpack_bytes(raw, i, i + nbytes, width, count, 1)
        i += nbytes
        return out^
    var stop = end
    if with_len != 0:
        if i + 4 > end:
            raise DecodeError(DecodeError.KIND_EOF, i)
        var nbytes = u32_at(Span(raw), i)
        i += 4
        stop = i + nbytes
        if stop > end:
            raise DecodeError(DecodeError.KIND_EOF, i)
    var out = rle_decode(raw, i, stop, width, count)
    if with_len != 0:
        i = stop
    return out^


def plain_bool_encode(vals: List[Int], n: Int) -> List[Byte]:
    return pack_bytes(vals, n, 1, 0)


def plain_bool_decode(raw: List[Byte], off: Int, end: Int, count: Int) raises DecodeError -> List[Int]:
    return unpack_bytes(raw, off, end, 1, count, 0)


def _wsub(a: Int, b: Int, bits: Int) -> UInt64:
    var ua = UInt64(a)
    var ub = UInt64(b)
    if bits == 32:
        ua = ua & 0xFFFFFFFF
        ub = ub & 0xFFFFFFFF
    return ua - ub


def _wadd(prev: Int, delta: UInt64, bits: Int) -> Int:
    var base = UInt64(prev)
    if bits == 32:
        base = base & 0xFFFFFFFF
        var sum = (base + (delta & 0xFFFFFFFF)) & 0xFFFFFFFF
        if sum >= 2147483648:
            return Int(sum) - 4294967296
        return Int(sum)
    return Int(base + delta)


def _signed_delta(a: Int, b: Int, bits: Int) -> Int:
    var d = _wsub(a, b, bits)
    if bits == 32:
        if d >= 2147483648:
            return Int(d) - 4294967296
        return Int(d)
    if d > 9223372036854775807:
        return Int(d - 9223372036854775808) - 9223372036854775807 - 1
    return Int(d)


def delta_int_encode(vals: List[Int], n: Int, bits: Int) -> List[Byte]:
    var out = List[Byte]()
    var block = 128
    var mbs = 4
    var mb_n = 32
    uleb_put(out, block)
    uleb_put(out, mbs)
    uleb_put(out, n)
    if n <= 0:
        return out^
    zz_put(out, vals[0])
    var prev = vals[0]
    var i = 1
    while i < n:
        var take = n - i
        if take > block:
            take = block
        var deltas = List[Int]()
        var min_s = 0
        var t = 0
        while t < take:
            var d = _signed_delta(vals[i + t], prev, bits)
            prev = vals[i + t]
            deltas.append(d)
            if t == 0 or d < min_s:
                min_s = d
            t += 1
        zz_put(out, min_s)
        var widths = List[Int]()
        var m = 0
        while m < mbs:
            var start = m * mb_n
            var w = 0
            if start < take:
                var endv = start + mb_n
                if endv > take:
                    endv = take
                var maxv = UInt64(0)
                var k = start
                while k < endv:
                    var rel = _wsub(deltas[k], min_s, bits)
                    if rel > maxv:
                        maxv = rel
                    k += 1
                w = bits_of(maxv)
                if bits == 32 and w > 32:
                    w = 32
                if w > 64:
                    w = 64
            widths.append(w)
            out.append(Byte(w))
            m += 1
        m = 0
        while m < mbs:
            var start = m * mb_n
            if start >= take:
                break
            var w = widths[m]
            if w > 0:
                var acc = UInt64(0)
                var nbit = 0
                var k = 0
                while k < mb_n:
                    var rel = UInt64(0)
                    if start + k < take:
                        rel = _wsub(deltas[start + k], min_s, bits)
                    put_low_bits(out, acc, nbit, rel, w)
                    k += 1
                flush_bits(out, acc, nbit)
            m += 1
        i += take
    return out^


struct DeltaInts:
    var vals: List[Int]
    var used: Int

    def __init__(out self):
        self.vals = List[Int]()
        self.used = 0


def delta_int_decode(raw: List[Byte], off: Int, end: Int, bits: Int) raises DecodeError -> DeltaInts:
    var out = DeltaInts()
    var i = off
    var block = uleb_get(raw, i, end)
    var mbs = uleb_get(raw, i, end)
    var count = uleb_get(raw, i, end)
    if block <= 0 or mbs <= 0 or block % mbs != 0:
        raise DecodeError(DecodeError.KIND_ENCODING, off)
    var mb_n = block // mbs
    if count == 0:
        out.used = i - off
        return out^
    var first = zz_get(raw, i, end)
    out.vals.append(first)
    var prev = first
    var left = count - 1
    while left > 0:
        var min_s = zz_get(raw, i, end)
        var min_d = UInt64(min_s)
        if bits == 32:
            min_d = min_d & 0xFFFFFFFF
        var widths = List[Int]()
        var m = 0
        while m < mbs:
            if i >= end:
                raise DecodeError(DecodeError.KIND_EOF, i)
            widths.append(Int(raw[i]))
            i += 1
            m += 1
        var in_block = left
        if in_block > block:
            in_block = block
        var produced = 0
        m = 0
        while m < mbs and produced < in_block:
            var w = widths[m]
            var bit = i * 8
            var nbytes = 0
            if w > 0:
                nbytes = (mb_n * w + 7) >> 3
                if i + nbytes > end:
                    raise DecodeError(DecodeError.KIND_EOF, i)
            var k = 0
            while k < mb_n:
                var rel = UInt64(0)
                if w > 0:
                    rel = take_bits(raw, bit, w, i + nbytes, 0)
                if produced < in_block:
                    var delta = min_d + rel
                    if bits == 32:
                        delta = delta & 0xFFFFFFFF
                    var value = _wadd(prev, delta, bits)
                    out.vals.append(value)
                    prev = value
                    produced += 1
                    left -= 1
                k += 1
            i += nbytes
            m += 1
        if produced != in_block:
            raise DecodeError(DecodeError.KIND_ENCODING, i)
    out.used = i - off
    return out^


struct ByteSeq:
    var raw: List[Byte]
    var ends: List[Int]
    var used: Int

    def __init__(out self):
        self.raw = List[Byte]()
        self.ends = List[Int]()
        self.used = 0


def delta_len_ba_decode(raw: List[Byte], off: Int, end: Int) raises DecodeError -> ByteSeq:
    var lens = delta_int_decode(raw, off, end, 32)
    var i = off + lens.used
    var out = ByteSeq()
    var k = 0
    while k < len(lens.vals):
        var n = lens.vals[k]
        if n < 0 or i + n > end:
            raise DecodeError(DecodeError.KIND_ENCODING, i)
        var t = 0
        while t < n:
            out.raw.append(raw[i + t])
            t += 1
        i += n
        out.ends.append(len(out.raw))
        k += 1
    out.used = i - off
    return out^


def delta_len_ba_encode(raw: List[Byte], ends: List[Int], n: Int) -> List[Byte]:
    var lens = List[Int]()
    var prev = 0
    var i = 0
    while i < n:
        var nlen = ends[i] - prev
        lens.append(nlen)
        prev = ends[i]
        i += 1
    var out = delta_int_encode(lens, n, 32)
    prev = 0
    i = 0
    while i < n:
        var a = prev
        if i > 0:
            a = ends[i - 1]
        var b = ends[i]
        while a < b:
            out.append(raw[a])
            a += 1
        prev = b
        i += 1
    return out^


def _prefix_len(raw: List[Byte], a0: Int, a1: Int, b0: Int, b1: Int) -> Int:
    var n = a1 - a0
    var m = b1 - b0
    if m < n:
        n = m
    var i = 0
    while i < n and raw[a0 + i] == raw[b0 + i]:
        i += 1
    return i


def delta_ba_encode(raw: List[Byte], ends: List[Int], n: Int) -> List[Byte]:
    var prefix = List[Int]()
    var suffix_raw = List[Byte]()
    var suffix_ends = List[Int]()
    var prev0 = 0
    var prev1 = 0
    var i = 0
    while i < n:
        var a = 0
        if i > 0:
            a = ends[i - 1]
        var b = ends[i]
        var p = 0
        if i > 0:
            p = _prefix_len(raw, prev0, prev1, a, b)
        prefix.append(p)
        var t = a + p
        while t < b:
            suffix_raw.append(raw[t])
            t += 1
        suffix_ends.append(len(suffix_raw))
        prev0 = a
        prev1 = b
        i += 1
    var out = delta_int_encode(prefix, n, 32)
    var suf = delta_len_ba_encode(suffix_raw, suffix_ends, n)
    i = 0
    while i < len(suf):
        out.append(suf[i])
        i += 1
    return out^


def delta_ba_decode(raw: List[Byte], off: Int, end: Int) raises DecodeError -> ByteSeq:
    var prefs = delta_int_decode(raw, off, end, 32)
    var suf = delta_len_ba_decode(raw, off + prefs.used, end)
    var out = ByteSeq()
    var prev = List[Byte]()
    var k = 0
    while k < len(prefs.vals):
        var p = prefs.vals[k]
        if p < 0 or p > len(prev):
            raise DecodeError(DecodeError.KIND_ENCODING, off)
        var s0 = 0
        if k > 0:
            s0 = suf.ends[k - 1]
        var s1 = suf.ends[k]
        var cur = List[Byte]()
        var t = 0
        while t < p:
            cur.append(prev[t])
            t += 1
        t = s0
        while t < s1:
            cur.append(suf.raw[t])
            t += 1
        t = 0
        while t < len(cur):
            out.raw.append(cur[t])
            t += 1
        out.ends.append(len(out.raw))
        prev = cur^
        k += 1
    out.used = prefs.used + suf.used
    return out^


def bss_encode(raw: List[Byte], n: Int, width: Int) -> List[Byte]:
    var out = List[Byte]()
    out.resize(n * width, Byte(0))
    var i = 0
    while i < n:
        var k = 0
        while k < width:
            out[k * n + i] = raw[i * width + k]
            k += 1
        i += 1
    return out^


def bss_decode(raw: List[Byte], off: Int, n: Int, width: Int) raises DecodeError -> List[Byte]:
    if n < 0 or width < 0 or off + n * width > len(raw):
        raise DecodeError(DecodeError.KIND_EOF, off)
    var out = List[Byte]()
    out.resize(n * width, Byte(0))
    var i = 0
    while i < n:
        var k = 0
        while k < width:
            out[i * width + k] = raw[off + k * n + i]
            k += 1
        i += 1
    return out^


def plain_i32_encode(vals: List[Int], n: Int) -> List[Byte]:
    var out = List[Byte]()
    out.resize(n * 4, Byte(0))
    var i = 0
    while i < n:
        var v = vals[i]
        if v < 0:
            v = v + 4294967296
        var o = i * 4
        out[o] = Byte(v & 255)
        out[o + 1] = Byte((v >> 8) & 255)
        out[o + 2] = Byte((v >> 16) & 255)
        out[o + 3] = Byte((v >> 24) & 255)
        i += 1
    return out^


def plain_i64_encode(vals: List[Int], n: Int) -> List[Byte]:
    var out = List[Byte]()
    out.resize(n * 8, Byte(0))
    var i = 0
    while i < n:
        var u = UInt64(vals[i])
        var o = i * 8
        var b = 0
        while b < 8:
            out[o + b] = Byte(Int((u >> UInt64(8 * b)) & 255))
            b += 1
        i += 1
    return out^


def plain_fixed_encode(raw: List[Byte], n: Int, width: Int) -> List[Byte]:
    var out = List[Byte]()
    var need = n * width
    out.resize(need, Byte(0))
    var i = 0
    while i < need and i < len(raw):
        out[i] = raw[i]
        i += 1
    return out^


def plain_ba_encode(raw: List[Byte], ends: List[Int], n: Int) -> List[Byte]:
    var out = List[Byte]()
    var prev = 0
    var i = 0
    while i < n:
        var a = prev
        var b = ends[i]
        put_u32(out, b - a)
        while a < b:
            out.append(raw[a])
            a += 1
        prev = b
        i += 1
    return out^


def plain_ba_decode(raw: List[Byte], off: Int, end: Int, count: Int) raises DecodeError -> ByteSeq:
    var out = ByteSeq()
    var i = off
    var k = 0
    while k < count:
        if i + 4 > end:
            raise DecodeError(DecodeError.KIND_EOF, i)
        var n = u32_at(Span(raw), i)
        i += 4
        if n < 0 or i + n > end:
            raise DecodeError(DecodeError.KIND_ENCODING, i)
        var base = len(out.raw)
        if n > 0:
            out.raw.resize(base + n, Byte(0))
            var t = 0
            while t < n:
                out.raw[base + t] = raw[i + t]
                t += 1
        i += n
        out.ends.append(base + n)
        k += 1
    out.used = i - off
    return out^


def plain_i32_decode(raw: List[Byte], off: Int, count: Int) raises DecodeError -> List[Int]:
    var out = List[Int]()
    var i = 0
    while i < count:
        out.append(i32_at(Span(raw), off + i * 4))
        i += 1
    return out^


def plain_i64_decode(raw: List[Byte], off: Int, count: Int) raises DecodeError -> List[Int]:
    var out = List[Int]()
    var i = 0
    while i < count:
        out.append(i64_at(Span(raw), off + i * 8))
        i += 1
    return out^
