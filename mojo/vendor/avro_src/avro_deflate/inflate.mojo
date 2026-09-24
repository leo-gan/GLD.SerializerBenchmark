from std.collections import List

from avro_runtime.error import DecodeError


comptime MAX_INFLATE = 64194304


struct _Bits(Movable):
    var data: List[Byte]
    var pos: Int
    var acc: UInt32
    var nacc: Int

    def __init__(out self, var data: List[Byte]):
        self.data = data^
        self.pos = 0
        self.acc = 0
        self.nacc = 0

    def need(mut self, n: Int) raises DecodeError:
        while self.nacc < n:
            if self.pos >= len(self.data):
                raise DecodeError(DecodeError.KIND_DEFLATE, self.pos)
            self.acc |= UInt32(self.data[self.pos]) << UInt32(self.nacc)
            self.pos += 1
            self.nacc += 8

    def bits(mut self, n: Int) raises DecodeError -> Int:
        if n == 0:
            return 0
        self.need(n)
        var v = Int(self.acc & ((UInt32(1) << UInt32(n)) - 1))
        self.acc >>= UInt32(n)
        self.nacc -= n
        return v

    def align(mut self):
        self.acc = 0
        self.nacc = 0


def _copy_out(mut out: List[Byte], dist: Int, length: Int) raises DecodeError:
    if dist <= 0 or dist > len(out):
        raise DecodeError(DecodeError.KIND_DEFLATE, 0)
    if len(out) + length > MAX_INFLATE:
        raise DecodeError(DecodeError.KIND_DEFLATE, 0)
    var i = 0
    while i < length:
        out.append(out[len(out) - dist])
        i += 1


def _len_base(sym: Int) -> Int:
    if sym <= 264:
        return 3 + (sym - 257)
    if sym == 285:
        return 258
    var extra = (sym - 261) // 4
    var first = 265 + (extra - 1) * 4
    var start = 11
    var e = 1
    while e < extra:
        start += 4 * (1 << e)
        e += 1
    return start + (sym - first) * (1 << extra)


# Length extra bits for symbols 257-285
def _len_extra(sym: Int) -> Int:
    if sym < 265 or sym == 285:
        return 0
    return (sym - 261) // 4


def _dist_extra(sym: Int) -> Int:
    if sym < 4:
        return 0
    return (sym - 2) // 2


def _dist_base(sym: Int) -> Int:
    if sym <= 3:
        return 1 + sym
    var extra = (sym - 2) // 2
    var first = extra * 2 + 2
    var start = 1 << extra
    start += 1
    return start + (sym - first) * (1 << extra)


def _fixed_lit_lens() -> List[Int]:
    var L = List[Int]()
    var i = 0
    while i < 288:
        if i <= 143:
            L.append(8)
        elif i <= 255:
            L.append(9)
        elif i <= 279:
            L.append(7)
        else:
            L.append(8)
        i += 1
    return L^


def _fixed_dist_lens() -> List[Int]:
    var L = List[Int]()
    var i = 0
    while i < 32:
        L.append(5)
        i += 1
    return L^


def _inflate_codes(
    mut b: _Bits, mut out: List[Byte], lit_fn: Int
) raises DecodeError:
    var lit = _fixed_lit_lens()
    var dist = _fixed_dist_lens()
    while True:
        var sym = _decode_huff(b, lit)
        if sym < 256:
            if len(out) + 1 > MAX_INFLATE:
                raise DecodeError(DecodeError.KIND_DEFLATE, b.pos)
            out.append(Byte(sym))
        elif sym == 256:
            return
        else:
            var ln = _len_base(sym) + b.bits(_len_extra(sym))
            var ds = _decode_huff(b, dist)
            var distv = _dist_base(ds) + b.bits(_dist_extra(ds))
            _copy_out(out, distv, ln)


def inflate_raw(data: List[Byte]) raises DecodeError -> List[Byte]:
    """Inflate a raw DEFLATE stream (RFC 1951, no zlib header)."""
    var copied = data.copy()
    var b = _Bits(copied^)
    var out = List[Byte]()
    var bfinal = 0
    while bfinal == 0:
        bfinal = b.bits(1)
        var btype = b.bits(2)
        if btype == 0:
            b.align()
            var len16 = b.bits(8) | (b.bits(8) << 8)
            var nlen = b.bits(8) | (b.bits(8) << 8)
            if (len16 ^ 0xFFFF) != nlen:
                raise DecodeError(DecodeError.KIND_DEFLATE, b.pos)
            if len(out) + len16 > MAX_INFLATE:
                raise DecodeError(DecodeError.KIND_DEFLATE, b.pos)
            # stored uses byte-aligned stream: consume remaining acc then raw bytes
            # After align(), acc is empty and pos is at LEN. bits() already consumed LEN/NLEN
            # so next bytes are data — but bits() pulled them into acc. After 32 bits, pos is past NLEN.
            var i = 0
            while i < len16:
                out.append(Byte(b.bits(8)))
                i += 1
        elif btype == 1:
            _inflate_codes(b, out, 0)
        elif btype == 2:
            _inflate_dynamic(b, out)
        else:
            raise DecodeError(DecodeError.KIND_DEFLATE, b.pos)
    return out^


def _inflate_dynamic(mut b: _Bits, mut out: List[Byte]) raises DecodeError:
    var hlit = b.bits(5) + 257
    var hdist = b.bits(5) + 1
    var hclen = b.bits(4) + 4
    # 16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15
    var ordv = List[Int]()
    ordv.append(16)
    ordv.append(17)
    ordv.append(18)
    ordv.append(0)
    ordv.append(8)
    ordv.append(7)
    ordv.append(9)
    ordv.append(6)
    ordv.append(10)
    ordv.append(5)
    ordv.append(11)
    ordv.append(4)
    ordv.append(12)
    ordv.append(3)
    ordv.append(13)
    ordv.append(2)
    ordv.append(14)
    ordv.append(1)
    ordv.append(15)
    var clen = List[Int]()
    var i = 0
    while i < 19:
        clen.append(0)
        i += 1
    i = 0
    while i < hclen:
        clen[ordv[i]] = b.bits(3)
        i += 1
    var litlen = List[Int]()
    i = 0
    while i < hlit:
        litlen.append(0)
        i += 1
    var distlen = List[Int]()
    i = 0
    while i < hdist:
        distlen.append(0)
        i += 1
    _decode_code_lens(b, clen, litlen, distlen)
    while True:
        var sym = _decode_huff(b, litlen)
        if sym < 256:
            if len(out) + 1 > MAX_INFLATE:
                raise DecodeError(DecodeError.KIND_DEFLATE, b.pos)
            out.append(Byte(sym))
        elif sym == 256:
            return
        else:
            var ln = _len_base(sym) + b.bits(_len_extra(sym))
            var ds = _decode_huff(b, distlen)
            var dist = _dist_base(ds) + b.bits(_dist_extra(ds))
            _copy_out(out, dist, ln)


def _decode_code_lens(
    mut b: _Bits, clen: List[Int], mut litlen: List[Int], mut distlen: List[Int]
) raises DecodeError:
    var total = len(litlen) + len(distlen)
    var i = 0
    while i < total:
        var sym = _decode_huff(b, clen)
        var repeats = 1
        var code_len: Int
        if sym < 16:
            code_len = sym
        elif sym == 16:
            if i == 0:
                raise DecodeError(DecodeError.KIND_DEFLATE, b.pos)
            code_len = _prev_len(litlen, distlen, i)
            repeats = 3 + b.bits(2)
        elif sym == 17:
            code_len = 0
            repeats = 3 + b.bits(3)
        elif sym == 18:
            code_len = 0
            repeats = 11 + b.bits(7)
        else:
            raise DecodeError(DecodeError.KIND_DEFLATE, b.pos)
        var r = 0
        while r < repeats:
            if i >= total:
                raise DecodeError(DecodeError.KIND_DEFLATE, b.pos)
            if i < len(litlen):
                litlen[i] = code_len
            else:
                distlen[i - len(litlen)] = code_len
            i += 1
            r += 1


def _prev_len(litlen: List[Int], distlen: List[Int], i: Int) -> Int:
    if i == 0:
        return 0
    var p = i - 1
    if p < len(litlen):
        return litlen[p]
    return distlen[p - len(litlen)]


def _decode_huff(mut b: _Bits, lengths: List[Int]) raises DecodeError -> Int:
    """Decode one symbol from a canonical Huffman set given code lengths."""
    var maxl = 0
    var i = 0
    while i < len(lengths):
        if lengths[i] > maxl:
            maxl = lengths[i]
        i += 1
    if maxl == 0:
        raise DecodeError(DecodeError.KIND_DEFLATE, b.pos)
    var bl_count = List[Int]()
    i = 0
    while i <= maxl:
        bl_count.append(0)
        i += 1
    i = 0
    while i < len(lengths):
        if lengths[i] > 0:
            bl_count[lengths[i]] += 1
        i += 1
    var next_code = List[Int]()
    next_code.append(0)
    var code = 0
    i = 1
    while i <= maxl:
        code = (code + bl_count[i - 1]) << 1
        next_code.append(code)
        i += 1
    var codes = List[Int]()
    var clens = List[Int]()
    i = 0
    while i < len(lengths):
        codes.append(-1)
        clens.append(lengths[i])
        i += 1
    i = 0
    while i < len(lengths):
        var l = lengths[i]
        if l != 0:
            codes[i] = next_code[l]
            next_code[l] += 1
        i += 1
    var acc = 0
    var n = 0
    while n < maxl:
        acc = (acc << 1) | b.bits(1)
        n += 1
        i = 0
        while i < len(lengths):
            if lengths[i] == n and codes[i] == acc:
                return i
            i += 1
    raise DecodeError(DecodeError.KIND_DEFLATE, b.pos)
