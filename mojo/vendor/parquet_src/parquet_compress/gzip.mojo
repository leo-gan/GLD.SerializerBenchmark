from std.collections import List

from parquet_runtime.buf import crc32_bytes
from parquet_runtime.error import DecodeError


comptime GZIP_MAX = 67108864


def _word(raw: List[Byte], bi: Int) -> Int:
    var w = 0
    if bi < len(raw):
        w = Int(raw[bi])
    if bi + 1 < len(raw):
        w = w | (Int(raw[bi + 1]) << 8)
    if bi + 2 < len(raw):
        w = w | (Int(raw[bi + 2]) << 16)
    if bi + 3 < len(raw):
        w = w | (Int(raw[bi + 3]) << 24)
    return w


def _pull(raw: List[Byte], mut bit: Int, n: Int) raises DecodeError -> Int:
    if n < 0 or n > 24:
        raise DecodeError(DecodeError.KIND_COMPRESSION, bit >> 3)
    if n == 0:
        return 0
    var last = bit + n - 1
    if (last >> 3) >= len(raw):
        raise DecodeError(DecodeError.KIND_COMPRESSION, bit >> 3)
    var w = _word(raw, bit >> 3) >> (bit & 7)
    var mask = (1 << n) - 1
    bit += n
    return w & mask


def _rev16(x: Int) -> Int:
    var v = x & 65535
    v = ((v & 21845) << 1) | ((v >> 1) & 21845)
    v = ((v & 13107) << 2) | ((v >> 2) & 13107)
    v = ((v & 3855) << 4) | ((v >> 4) & 3855)
    v = ((v & 255) << 8) | ((v >> 8) & 255)
    return v


def _peek(raw: List[Byte], bit: Int, n: Int) -> Int:
    if n <= 0:
        return 0
    var w = _word(raw, bit >> 3) >> (bit & 7)
    var width = n
    if width > 16:
        width = 16
    var r = _rev16(w)
    return r >> (16 - width)


struct Huff:
    var sym: List[Int]
    var nbits: List[Int]
    var maxb: Int

    def __init__(out self):
        self.sym = List[Int]()
        self.nbits = List[Int]()
        self.maxb = 0


def _huff(lens: List[Int]) raises DecodeError -> Huff:
    var h = Huff()
    var n = len(lens)
    var count = List[Int]()
    count.resize(16, 0)
    var i = 0
    while i < n:
        var length = lens[i]
        if length < 0 or length > 15:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        if length > h.maxb:
            h.maxb = length
        if length > 0:
            count[length] += 1
        i += 1
    if h.maxb == 0:
        return h^
    var nextc = List[Int]()
    nextc.resize(16, 0)
    var code = 0
    var bits = 1
    while bits <= h.maxb:
        code = (code + count[bits - 1]) << 1
        nextc[bits] = code
        bits += 1
    var codes = List[Int]()
    codes.resize(n, 0)
    i = 0
    while i < n:
        var length = lens[i]
        if length > 0:
            codes[i] = nextc[length]
            nextc[length] += 1
        i += 1
    var size = 1 << h.maxb
    h.sym.resize(size, -1)
    h.nbits.resize(size, 0)
    i = 0
    while i < n:
        var length = lens[i]
        if length > 0:
            var base = codes[i] << (h.maxb - length)
            var fill = 1 << (h.maxb - length)
            var f = 0
            while f < fill:
                h.sym[base + f] = i
                h.nbits[base + f] = length
                f += 1
        i += 1
    return h^


def _dec(raw: List[Byte], mut bit: Int, h: Huff) raises DecodeError -> Int:
    if h.maxb == 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, bit >> 3)
    var peeked = _peek(raw, bit, h.maxb)
    var s = h.sym[peeked]
    var length = h.nbits[peeked]
    if s < 0 or length <= 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, bit >> 3)
    var bi = (bit + length - 1) >> 3
    if bi >= len(raw):
        raise DecodeError(DecodeError.KIND_COMPRESSION, bi)
    bit += length
    return s


def _fixed_lit() -> List[Int]:
    var lens = List[Int]()
    lens.resize(288, 8)
    var i = 144
    while i <= 255:
        lens[i] = 9
        i += 1
    i = 256
    while i <= 279:
        lens[i] = 7
        i += 1
    return lens^


def _fixed_dist() -> List[Int]:
    var lens = List[Int]()
    lens.resize(32, 5)
    return lens^


def _len_at(i: Int) -> Int:
    if i < 8:
        return 3 + i
    if i == 8:
        return 11
    if i == 9:
        return 13
    if i == 10:
        return 15
    if i == 11:
        return 17
    if i == 12:
        return 19
    if i == 13:
        return 23
    if i == 14:
        return 27
    if i == 15:
        return 31
    if i == 16:
        return 35
    if i == 17:
        return 43
    if i == 18:
        return 51
    if i == 19:
        return 59
    if i == 20:
        return 67
    if i == 21:
        return 83
    if i == 22:
        return 99
    if i == 23:
        return 115
    if i == 24:
        return 131
    if i == 25:
        return 163
    if i == 26:
        return 195
    if i == 27:
        return 227
    return 258


def _len_base(sym: Int) raises DecodeError -> Int:
    var i = sym - 257
    if i < 0 or i > 28:
        raise DecodeError(DecodeError.KIND_COMPRESSION, sym)
    return _len_at(i)


def _len_ex(sym: Int) -> Int:
    var i = sym - 257
    if i < 8 or i == 28:
        return 0
    if i < 12:
        return 1
    if i < 16:
        return 2
    if i < 20:
        return 3
    if i < 24:
        return 4
    return 5


def _dist_at(i: Int) -> Int:
    if i < 4:
        return 1 + i
    if i == 4:
        return 5
    if i == 5:
        return 7
    if i == 6:
        return 9
    if i == 7:
        return 13
    if i == 8:
        return 17
    if i == 9:
        return 25
    if i == 10:
        return 33
    if i == 11:
        return 49
    if i == 12:
        return 65
    if i == 13:
        return 97
    if i == 14:
        return 129
    if i == 15:
        return 193
    if i == 16:
        return 257
    if i == 17:
        return 385
    if i == 18:
        return 513
    if i == 19:
        return 769
    if i == 20:
        return 1025
    if i == 21:
        return 1537
    if i == 22:
        return 2049
    if i == 23:
        return 3073
    if i == 24:
        return 4097
    if i == 25:
        return 6145
    if i == 26:
        return 8193
    if i == 27:
        return 12289
    if i == 28:
        return 16385
    return 24577


def _dist_base(sym: Int) raises DecodeError -> Int:
    if sym < 0 or sym > 29:
        raise DecodeError(DecodeError.KIND_COMPRESSION, sym)
    return _dist_at(sym)


def _dist_ex(sym: Int) -> Int:
    if sym < 4:
        return 0
    return (sym >> 1) - 1


def _copy(mut out: List[Byte], dist: Int, length: Int) raises DecodeError:
    if dist <= 0 or dist > len(out) or len(out) + length > GZIP_MAX:
        raise DecodeError(DecodeError.KIND_COMPRESSION, len(out))
    var base = len(out)
    var start = base - dist
    out.resize(base + length, Byte(0))
    var k = 0
    while k < length:
        out[base + k] = out[start + k]
        k += 1


def _block_codes(raw: List[Byte], mut bit: Int, mut out: List[Byte], lit: Huff, dist: Huff) raises DecodeError:
    while True:
        var sym = _dec(raw, bit, lit)
        if sym < 256:
            out.append(Byte(sym))
            if len(out) > GZIP_MAX:
                raise DecodeError(DecodeError.KIND_COMPRESSION, bit >> 3)
        elif sym == 256:
            return
        else:
            var length = _len_base(sym) + _pull(raw, bit, _len_ex(sym))
            var ds = _dec(raw, bit, dist)
            var distance = _dist_base(ds) + _pull(raw, bit, _dist_ex(ds))
            _copy(out, distance, length)


def _dyn_trees(raw: List[Byte], mut bit: Int, mut lit_h: Huff, mut dist_h: Huff) raises DecodeError:
    var hlit = _pull(raw, bit, 5) + 257
    var hdist = _pull(raw, bit, 5) + 1
    var hclen = _pull(raw, bit, 4) + 4
    var order = List[Int]()
    order.append(16)
    order.append(17)
    order.append(18)
    order.append(0)
    order.append(8)
    order.append(7)
    order.append(9)
    order.append(6)
    order.append(10)
    order.append(5)
    order.append(11)
    order.append(4)
    order.append(12)
    order.append(3)
    order.append(13)
    order.append(2)
    order.append(14)
    order.append(1)
    order.append(15)
    var cl = List[Int]()
    cl.resize(19, 0)
    var i = 0
    while i < hclen:
        cl[order[i]] = _pull(raw, bit, 3)
        i += 1
    var clh = _huff(cl)
    var lens = List[Int]()
    var total = hlit + hdist
    while len(lens) < total:
        var sym = _dec(raw, bit, clh)
        if sym < 16:
            lens.append(sym)
        else:
            var rep = 0
            var value = 0
            if sym == 16:
                if len(lens) == 0:
                    raise DecodeError(DecodeError.KIND_COMPRESSION, bit >> 3)
                value = lens[len(lens) - 1]
                rep = 3 + _pull(raw, bit, 2)
            elif sym == 17:
                rep = 3 + _pull(raw, bit, 3)
            elif sym == 18:
                rep = 11 + _pull(raw, bit, 7)
            else:
                raise DecodeError(DecodeError.KIND_COMPRESSION, bit >> 3)
            var r = 0
            while r < rep:
                lens.append(value)
                r += 1
            if len(lens) > total:
                raise DecodeError(DecodeError.KIND_COMPRESSION, bit >> 3)
    var lit_l = List[Int]()
    var dist_l = List[Int]()
    i = 0
    while i < hlit:
        lit_l.append(lens[i])
        i += 1
    while i < total:
        dist_l.append(lens[i])
        i += 1
    lit_h = _huff(lit_l)
    dist_h = _huff(dist_l)


def _stored(raw: List[Byte], mut bit: Int, mut out: List[Byte]) raises DecodeError:
    if (bit & 7) != 0:
        bit = (bit + 7) & ~7
    var bi = bit >> 3
    if bi + 4 > len(raw):
        raise DecodeError(DecodeError.KIND_COMPRESSION, bi)
    var ln = Int(raw[bi]) | (Int(raw[bi + 1]) << 8)
    var nlen = Int(raw[bi + 2]) | (Int(raw[bi + 3]) << 8)
    if (ln ^ 0xFFFF) != nlen:
        raise DecodeError(DecodeError.KIND_COMPRESSION, bi)
    bi += 4
    if bi + ln > len(raw) or len(out) + ln > GZIP_MAX:
        raise DecodeError(DecodeError.KIND_COMPRESSION, bi)
    var base = len(out)
    out.resize(base + ln, Byte(0))
    var k = 0
    while k < ln:
        out[base + k] = raw[bi + k]
        k += 1
    bit = (bi + ln) * 8


def _member(raw: List[Byte], mut i: Int, mut out: List[Byte]) raises DecodeError:
    var start_len = len(out)
    if i + 10 > len(raw) or Int(raw[i]) != 0x1F or Int(raw[i + 1]) != 0x8B:
        raise DecodeError(DecodeError.KIND_COMPRESSION, i)
    if Int(raw[i + 2]) != 8:
        raise DecodeError(DecodeError.KIND_COMPRESSION, i)
    var flg = Int(raw[i + 3])
    if (flg & 0xE0) != 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, i)
    i += 10
    if (flg & 4) != 0:
        if i + 2 > len(raw):
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        var xlen = Int(raw[i]) | (Int(raw[i + 1]) << 8)
        i += 2 + xlen
    if (flg & 8) != 0:
        while i < len(raw) and Int(raw[i]) != 0:
            i += 1
        i += 1
    if (flg & 16) != 0:
        while i < len(raw) and Int(raw[i]) != 0:
            i += 1
        i += 1
    if (flg & 2) != 0:
        i += 2
    if i > len(raw):
        raise DecodeError(DecodeError.KIND_COMPRESSION, i)
    var bit = i * 8
    while True:
        var bfinal = _pull(raw, bit, 1)
        var btype = _pull(raw, bit, 2)
        if btype == 0:
            _stored(raw, bit, out)
        elif btype == 1:
            var lit = _huff(_fixed_lit())
            var dist = _huff(_fixed_dist())
            _block_codes(raw, bit, out, lit, dist)
        elif btype == 2:
            var dl = Huff()
            var dd = Huff()
            _dyn_trees(raw, bit, dl, dd)
            _block_codes(raw, bit, out, dl, dd)
        else:
            raise DecodeError(DecodeError.KIND_COMPRESSION, bit >> 3)
        if bfinal != 0:
            break
    if (bit & 7) != 0:
        bit = (bit + 7) & ~7
    var bi = bit >> 3
    if bi + 8 > len(raw):
        raise DecodeError(DecodeError.KIND_COMPRESSION, bi)
    var crc = Int(raw[bi]) | (Int(raw[bi + 1]) << 8) | (Int(raw[bi + 2]) << 16) | (Int(raw[bi + 3]) << 24)
    var isize = Int(raw[bi + 4]) | (Int(raw[bi + 5]) << 8) | (Int(raw[bi + 6]) << 16) | (Int(raw[bi + 7]) << 24)
    if crc < 0:
        crc = crc + 4294967296
    if isize < 0:
        isize = isize + 4294967296
    var got = crc32_bytes(out, start_len, len(out) - start_len)
    if got < 0:
        got = got + 4294967296
    var produced = len(out) - start_len
    if got != crc or (produced & 0xFFFFFFFF) != isize:
        raise DecodeError(DecodeError.KIND_COMPRESSION, bi)
    i = bi + 8


def gzip_decompress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    var out = List[Byte]()
    var i = 0
    if len(raw) == 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, 0)
    while i + 10 <= len(raw):
        var before = len(out)
        _member(raw, i, out)
        if len(out) < before:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        if i >= len(raw):
            break
        if i + 10 > len(raw):
            break
    if i != len(raw) and i + 10 <= len(raw):
        raise DecodeError(DecodeError.KIND_COMPRESSION, i)
    return out^


struct _BW:
    var b: List[Byte]
    var acc: Int
    var n: Int

    def __init__(out self):
        self.b = List[Byte]()
        self.acc = 0
        self.n = 0

    def bit(mut self, v: Int):
        if v != 0:
            self.acc = self.acc | (1 << self.n)
        self.n += 1
        if self.n == 8:
            self.b.append(Byte(self.acc))
            self.acc = 0
            self.n = 0

    def bits_low(mut self, v: Int, n: Int):
        var left = n
        var val = v
        while left > 0:
            var space = 8 - self.n
            var take = left
            if take > space:
                take = space
            var mask = (1 << take) - 1
            self.acc = self.acc | ((val & mask) << self.n)
            self.n += take
            val = val >> take
            left -= take
            if self.n == 8:
                self.b.append(Byte(self.acc))
                self.acc = 0
                self.n = 0

    def bits_high(mut self, v: Int, n: Int):
        var left = n
        while left > 0:
            var space = 8 - self.n
            var take = left
            if take > space:
                take = space
            var shift = left - take
            var piece = (v >> shift) & ((1 << take) - 1)
            var rev = 0
            var k = 0
            while k < take:
                rev = (rev << 1) | (piece & 1)
                piece = piece >> 1
                k += 1
            self.acc = self.acc | (rev << self.n)
            self.n += take
            left -= take
            if self.n == 8:
                self.b.append(Byte(self.acc))
                self.acc = 0
                self.n = 0

    def finish(mut self):
        if self.n > 0:
            self.b.append(Byte(self.acc))
            self.acc = 0
            self.n = 0


def _lit_code(sym: Int) -> Int:
    if sym <= 143:
        return sym + 48
    if sym <= 255:
        return sym - 144 + 400
    if sym <= 279:
        return sym - 256
    return sym - 280 + 192


def _lit_nbits(sym: Int) -> Int:
    if sym <= 143:
        return 8
    if sym <= 255:
        return 9
    if sym <= 279:
        return 7
    return 8


def _emit_lit(mut w: _BW, sym: Int):
    w.bits_high(_lit_code(sym), _lit_nbits(sym))


def _emit_len(mut w: _BW, length: Int):
    var idx = 0
    var best = 0
    while idx < 29:
        if _len_at(idx) <= length:
            best = idx
        idx += 1
    var sym = 257 + best
    _emit_lit(w, sym)
    var extra = length - _len_at(best)
    w.bits_low(extra, _len_ex(sym))


def _emit_dist(mut w: _BW, dist: Int):
    var idx = 0
    var best = 0
    while idx < 30:
        if _dist_at(idx) <= dist:
            best = idx
        idx += 1
    w.bits_high(best, 5)
    w.bits_low(dist - _dist_at(best), _dist_ex(best))


def gzip_compress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    if len(raw) > GZIP_MAX:
        raise DecodeError(DecodeError.KIND_COMPRESSION, len(raw))
    var w = _BW()
    w.bit(1)
    w.bits_low(1, 2)
    var n = len(raw)
    var i = 0
    var cap = 256
    while cap < 32768 and cap < n:
        cap = cap << 1
    var table = List[Int]()
    table.resize(cap, -1)
    var mask = cap - 1
    while i < n:
        var matched = 0
        if i + 3 <= n:
            var key = Int(raw[i]) | (Int(raw[i + 1]) << 8) | (Int(raw[i + 2]) << 16)
            var h = (key * 0x1E35A7BD) & mask
            var src = table[h]
            table[h] = i
            if src >= 0 and i - src > 0 and i - src <= 32768 and raw[src] == raw[i] and raw[src + 1] == raw[i + 1] and raw[src + 2] == raw[i + 2]:
                var m = 3
                var max_m = n - i
                if max_m > 258:
                    max_m = 258
                while m < max_m and raw[src + m] == raw[i + m]:
                    m += 1
                if m >= 3:
                    _emit_len(w, m)
                    _emit_dist(w, i - src)
                    var t = i + 1
                    var stop = i + m
                    while t + 2 < stop and t + 2 < n:
                        var kk = Int(raw[t]) | (Int(raw[t + 1]) << 8) | (Int(raw[t + 2]) << 16)
                        table[(kk * 0x1E35A7BD) & mask] = t
                        t += 1
                    i += m
                    matched = 1
        if matched == 0:
            _emit_lit(w, Int(raw[i]))
            i += 1
    _emit_lit(w, 256)
    w.finish()
    var out = List[Byte]()
    out.append(Byte(0x1F))
    out.append(Byte(0x8B))
    out.append(Byte(8))
    out.append(Byte(0))
    out.append(Byte(0))
    out.append(Byte(0))
    out.append(Byte(0))
    out.append(Byte(0))
    out.append(Byte(0))
    out.append(Byte(255))
    var k = 0
    while k < len(w.b):
        out.append(w.b[k])
        k += 1
    var crc = crc32_bytes(raw, 0, len(raw))
    if crc < 0:
        crc = crc + 4294967296
    var isize = len(raw) & 0xFFFFFFFF
    k = 0
    while k < 4:
        out.append(Byte((crc >> (8 * k)) & 255))
        k += 1
    k = 0
    while k < 4:
        out.append(Byte((isize >> (8 * k)) & 255))
        k += 1
    return out^
