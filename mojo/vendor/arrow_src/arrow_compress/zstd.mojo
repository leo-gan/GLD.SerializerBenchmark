from std.collections import List

from arrow_compress.xxh import xxh64_list
from arrow_compress.zstd_tables import ll_base, ll_bits, ll_norm, ml_base, ml_bits, ml_norm, of_base, of_bits, of_norm
from arrow_runtime.error import DecodeError


comptime ZSTD_MAX_OUT = 67108864
comptime ZSTD_BLOCK_LIMIT = 131072


struct FseTab:
    var log: Int
    var size: Int
    var nbits: List[Int]
    var nxt: List[Int]
    var base: List[Int]
    var add: List[Int]
    var sym: List[Int]

    def __init__(out self):
        self.log = 0
        self.size = 0
        self.nbits = List[Int]()
        self.nxt = List[Int]()
        self.base = List[Int]()
        self.add = List[Int]()
        self.sym = List[Int]()


struct HuffTab:
    var log: Int
    var size: Int
    var sym: List[Int]
    var nbits: List[Int]

    def __init__(out self):
        self.log = 0
        self.size = 0
        self.sym = List[Int]()
        self.nbits = List[Int]()


struct RevBits:
    var base: Int
    var bitpos: Int

    def __init__(out self, base: Int, bitpos: Int):
        self.base = base
        self.bitpos = bitpos

    def read(mut self, data: List[Byte], n: Int) -> Int:
        var v = 0
        var k = 0
        while k < n:
            v = v << 1
            if self.bitpos >= 0:
                var idx = self.base + (self.bitpos // 8)
                var bit = self.bitpos & 7
                v = v | ((Int(data[idx]) >> bit) & 1)
            self.bitpos -= 1
            k += 1
        return v

    def peek(mut self, data: List[Byte], n: Int) -> Int:
        var saved = self.bitpos
        var v = self.read(data, n)
        self.bitpos = saved
        return v


struct FwdBits:
    var origin: Int
    var i: Int
    var limit: Int
    var bit: Int

    def __init__(out self, origin: Int, limit: Int):
        self.origin = origin
        self.i = origin
        self.limit = limit
        self.bit = 0

    def read(mut self, data: List[Byte], n: Int) -> Int:
        var v = 0
        var k = 0
        while k < n:
            var bitv = 0
            if self.i >= 0 and self.i < self.limit and self.i < len(data):
                bitv = (Int(data[self.i]) >> self.bit) & 1
            v = v | (bitv << k)
            self.bit += 1
            if self.bit == 8:
                self.bit = 0
                self.i += 1
            k += 1
        return v

    def peek(mut self, data: List[Byte], n: Int) -> Int:
        var si = self.i
        var sb = self.bit
        var v = self.read(data, n)
        self.i = si
        self.bit = sb
        return v

    def bytes_used(self) -> Int:
        if self.bit == 0:
            return self.i - self.origin
        return self.i - self.origin + 1


struct ZCtx:
    var huff: HuffTab
    var huff_on: Int
    var ll: FseTab
    var oft: FseTab
    var ml: FseTab
    var ll_def: FseTab
    var of_def: FseTab
    var ml_def: FseTab
    var seq_on: Int
    var o1: Int
    var o2: Int
    var o3: Int
    var bases_ll: List[Int]
    var bits_ll: List[Int]
    var bases_ml: List[Int]
    var bits_ml: List[Int]
    var bases_of: List[Int]
    var bits_of: List[Int]

    def __init__(out self):
        self.huff = HuffTab()
        self.huff_on = 0
        self.ll = FseTab()
        self.oft = FseTab()
        self.ml = FseTab()
        self.ll_def = FseTab()
        self.of_def = FseTab()
        self.ml_def = FseTab()
        self.seq_on = 0
        self.o1 = 1
        self.o2 = 4
        self.o3 = 8
        self.bases_ll = List[Int]()
        self.bits_ll = List[Int]()
        self.bases_ml = List[Int]()
        self.bits_ml = List[Int]()
        self.bases_of = List[Int]()
        self.bits_of = List[Int]()

    def prepare(mut self) raises DecodeError:
        self.bases_ll = ll_base()
        self.bits_ll = ll_bits()
        self.bases_ml = ml_base()
        self.bits_ml = ml_bits()
        self.bases_of = of_base()
        self.bits_of = of_bits()
        var nll = ll_norm()
        var nml = ml_norm()
        var nof = of_norm()
        self.ll_def = _build_fse(nll, len(nll) - 1, 6, self.bases_ll, self.bits_ll, 1)
        self.ml_def = _build_fse(nml, len(nml) - 1, 6, self.bases_ml, self.bits_ml, 1)
        self.of_def = _build_fse(nof, len(nof) - 1, 5, self.bases_of, self.bits_of, 1)

    def reset_frame(mut self):
        self.huff_on = 0
        self.seq_on = 0
        self.o1 = 1
        self.o2 = 4
        self.o3 = 8


def zstd_compress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    if len(raw) > ZSTD_MAX_OUT:
        raise DecodeError(DecodeError.KIND_COMPRESSION, len(raw))
    var out = List[Byte]()
    out.append(Byte(0x28))
    out.append(Byte(0xB5))
    out.append(Byte(0x2F))
    out.append(Byte(0xFD))
    var n = len(raw)
    if n <= 255:
        out.append(Byte(0x20))
        out.append(Byte(n))
    elif n <= 65791:
        out.append(Byte(0x60))
        var adj = n - 256
        out.append(Byte(adj & 255))
        out.append(Byte((adj >> 8) & 255))
    else:
        out.append(Byte(0xA0))
        var k = 0
        while k < 4:
            out.append(Byte((n >> (8 * k)) & 255))
            k += 1
    if n == 0:
        out.append(Byte(1))
        out.append(Byte(0))
        out.append(Byte(0))
        return out^
    var uniform = 0
    if n > 1:
        uniform = 1
        var v0 = raw[0]
        var t = 1
        while t < n:
            if raw[t] != v0:
                uniform = 0
                break
            t += 1
    var block_max = n
    if block_max > ZSTD_BLOCK_LIMIT:
        block_max = ZSTD_BLOCK_LIMIT
    var off = 0
    while off < n:
        var take = n - off
        if take > block_max:
            take = block_max
        var last = 0
        if off + take == n:
            last = 1
        if uniform != 0:
            var hdr = (take << 3) | 2 | last
            out.append(Byte(hdr & 255))
            out.append(Byte((hdr >> 8) & 255))
            out.append(Byte((hdr >> 16) & 255))
            out.append(raw[off])
        else:
            var hdr = (take << 3) | last
            out.append(Byte(hdr & 255))
            out.append(Byte((hdr >> 8) & 255))
            out.append(Byte((hdr >> 16) & 255))
            var i = 0
            while i < take:
                out.append(raw[off + i])
                i += 1
        off += take
    return out^


def zstd_decompress(raw: List[Byte]) raises DecodeError -> List[Byte]:
    var ctx = ZCtx()
    ctx.prepare()
    var out = List[Byte]()
    var pos = 0
    var n = len(raw)
    while pos < n:
        if pos + 4 > n:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var magic = _u32(raw, pos)
        if magic >= 0x184D2A50 and magic <= 0x184D2A5F:
            pos += 4
            if pos + 4 > n:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            var skip = _u32(raw, pos)
            pos += 4
            if skip < 0 or pos + skip > n:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            pos += skip
        elif magic == 0xFD2FB528:
            pos += 4
            pos = _decode_frame(ctx, raw, pos, out)
            if len(out) > ZSTD_MAX_OUT:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        else:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    return out^


def _decode_frame(mut ctx: ZCtx, raw: List[Byte], pos0: Int, mut out: List[Byte]) raises DecodeError -> Int:
    ctx.reset_frame()
    var pos = pos0
    var n = len(raw)
    if pos >= n:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var desc = Int(raw[pos])
    pos += 1
    if (desc & 0x08) != 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var fcs_flag = (desc >> 6) & 3
    var single = (desc >> 5) & 1
    var checksum = (desc >> 2) & 1
    var did_flag = desc & 3
    var window = 0
    if single == 0:
        if pos >= n:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var wd = Int(raw[pos])
        pos += 1
        var exp = wd >> 3
        var mant = wd & 7
        var wlog = 10 + exp
        if wlog > 31:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var base = 1 << wlog
        window = base + (base // 8) * mant
        if window <= 0 or window > ZSTD_MAX_OUT:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var did_size = 0
    if did_flag == 1:
        did_size = 1
    elif did_flag == 2:
        did_size = 2
    elif did_flag == 3:
        did_size = 4
    var fcs_size = 0
    if single != 0:
        if fcs_flag == 0:
            fcs_size = 1
        elif fcs_flag == 1:
            fcs_size = 2
        elif fcs_flag == 2:
            fcs_size = 4
        else:
            fcs_size = 8
    else:
        if fcs_flag == 1:
            fcs_size = 2
        elif fcs_flag == 2:
            fcs_size = 4
        elif fcs_flag == 3:
            fcs_size = 8
    if pos + did_size + fcs_size > n:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var did = 0
    var k = 0
    while k < did_size:
        did = did | (Int(raw[pos]) << (8 * k))
        pos += 1
        k += 1
    if did != 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var content = -1
    if fcs_size != 0:
        var declared = UInt64(0)
        k = fcs_size - 1
        var p0 = pos
        while k >= 0:
            declared = (declared << UInt64(8)) | UInt64(Int(raw[p0 + k]))
            k -= 1
        pos += fcs_size
        if fcs_size == 2:
            declared = declared + UInt64(256)
        if declared > UInt64(ZSTD_MAX_OUT):
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        content = Int(declared)
    if single != 0:
        if content < 0:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        window = content
    var block_max = window
    if block_max > ZSTD_BLOCK_LIMIT:
        block_max = ZSTD_BLOCK_LIMIT
    var frame_at = len(out)
    while True:
        if pos + 3 > n:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var hdr = Int(raw[pos]) | (Int(raw[pos + 1]) << 8) | (Int(raw[pos + 2]) << 16)
        pos += 3
        var last = hdr & 1
        var btype = (hdr >> 1) & 3
        var bsize = hdr >> 3
        if btype == 3:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        if btype == 1:
            if pos >= n:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            if bsize > block_max or len(out) + bsize > ZSTD_MAX_OUT:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            var value = raw[pos]
            pos += 1
            if bsize > 0:
                var start = len(out)
                out.resize(start + bsize, value)
        elif btype == 0:
            if bsize > block_max or pos + bsize > n or len(out) + bsize > ZSTD_MAX_OUT:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            var i = 0
            while i < bsize:
                out.append(raw[pos + i])
                i += 1
            pos += bsize
        else:
            if bsize > block_max or pos + bsize > n:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            var before = len(out)
            _block(ctx, raw, pos, bsize, out, window, block_max)
            pos += bsize
            if len(out) - before > block_max:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        if last != 0:
            break
    if content >= 0 and len(out) - frame_at != content:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    if checksum != 0:
        if pos + 4 > n:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var want = _u32(raw, pos)
        pos += 4
        var chunk = List[Byte]()
        var i = frame_at
        while i < len(out):
            chunk.append(out[i])
            i += 1
        var have = Int(xxh64_list(chunk) & UInt64(0xFFFFFFFF))
        if have != want:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    return pos


def _block(mut ctx: ZCtx, data: List[Byte], pos: Int, bsize: Int, mut out: List[Byte], window: Int, block_max: Int) raises DecodeError:
    var end = pos + bsize
    var cursor = pos
    var lits = List[Byte]()
    _literals(ctx, data, cursor, end, lits, block_max)
    _sequences(ctx, data, cursor, end, lits, out, window, block_max)


def _literals(mut self: ZCtx, data: List[Byte], mut pos: Int, end: Int, mut lits: List[Byte], block_max: Int) raises DecodeError:
    if pos >= end:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var b0 = Int(data[pos])
    var ltype = b0 & 3
    var fmt = (b0 >> 2) & 3
    if ltype == 0 or ltype == 1:
        var lh = 1
        var regen = b0 >> 3
        if fmt == 1:
            if pos + 2 > end:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            lh = 2
            regen = (Int(data[pos]) >> 4) + (Int(data[pos + 1]) << 4)
        elif fmt == 3:
            if pos + 3 > end:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            lh = 3
            regen = (Int(data[pos]) >> 4) + (Int(data[pos + 1]) << 4) + (Int(data[pos + 2]) << 12)
        if regen > block_max or pos + lh > end:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        if ltype == 0:
            if pos + lh + regen > end:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            var i = 0
            while i < regen:
                lits.append(data[pos + lh + i])
                i += 1
            pos += lh + regen
            return
        if regen == 0:
            pos += lh
            return
        if pos + lh >= end:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var value = data[pos + lh]
        lits.resize(regen, value)
        pos += lh + 1
        return
    if end - pos < 5:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var word = _u32(data, pos)
    var lh = 3
    var regen = (word >> 4) & 0x3FF
    var csize = (word >> 14) & 0x3FF
    var single = 0
    if fmt == 0:
        single = 1
    elif fmt == 2:
        lh = 4
        regen = (word >> 4) & 0x3FFF
        csize = word >> 18
    elif fmt == 3:
        lh = 5
        regen = (word >> 4) & 0x3FFFF
        csize = (word >> 22) + (Int(data[pos + 4]) << 10)
    if csize <= 0 or regen > block_max or pos + lh + csize > end:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    if single == 0 and regen < 6:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var body = pos + lh
    if ltype == 2:
        _read_huff(self, data, body, pos + lh + csize)
        self.huff_on = 1
    elif ltype == 3:
        if self.huff_on == 0:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    else:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var total = pos + lh + csize - body
    if single != 0:
        var part = _huf_decode(data, body, total, self.huff, regen)
        var i = 0
        while i < len(part):
            lits.append(part[i])
            i += 1
        pos += lh + csize
        return
    if total < 10:
        raise DecodeError(DecodeError.KIND_COMPRESSION, body)
    var s1 = Int(data[body]) | (Int(data[body + 1]) << 8)
    var s2 = Int(data[body + 2]) | (Int(data[body + 3]) << 8)
    var s3 = Int(data[body + 4]) | (Int(data[body + 5]) << 8)
    var s4 = total - 6 - s1 - s2 - s3
    if s1 < 1 or s2 < 1 or s3 < 1 or s4 < 1:
        raise DecodeError(DecodeError.KIND_COMPRESSION, body)
    var chunk = (regen + 3) // 4
    var counts = List[Int]()
    counts.append(chunk)
    counts.append(chunk)
    counts.append(chunk)
    counts.append(regen - 3 * chunk)
    var sizes = List[Int]()
    sizes.append(s1)
    sizes.append(s2)
    sizes.append(s3)
    sizes.append(s4)
    var off = body + 6
    var stream = 0
    while stream < 4:
        var part = _huf_decode(data, off, sizes[stream], self.huff, counts[stream])
        var i = 0
        while i < len(part):
            lits.append(part[i])
            i += 1
        off += sizes[stream]
        stream += 1
    pos += lh + csize


def _sequences(mut self: ZCtx, data: List[Byte], mut pos: Int, end: Int, lits: List[Byte], mut out: List[Byte], window: Int, block_max: Int) raises DecodeError:
    if pos >= end:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var b0 = Int(data[pos])
    pos += 1
    var nb = b0
    if b0 >= 128 and b0 < 255:
        if pos >= end:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        nb = ((b0 - 128) << 8) + Int(data[pos])
        pos += 1
    elif b0 == 255:
        if pos + 2 > end:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        nb = Int(data[pos]) + (Int(data[pos + 1]) << 8) + 0x7F00
        pos += 2
    if nb == 0:
        if pos != end:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var i = 0
        while i < len(lits):
            out.append(lits[i])
            i += 1
        return
    if pos >= end:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var modes = Int(data[pos])
    pos += 1
    if (modes & 3) != 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var ll_mode = (modes >> 6) & 3
    var of_mode = (modes >> 4) & 3
    var ml_mode = (modes >> 2) & 3
    _install_table(self, data, pos, end, 0, ll_mode)
    _install_table(self, data, pos, end, 1, of_mode)
    _install_table(self, data, pos, end, 2, ml_mode)
    if pos >= end:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var br = _rev(data, pos, end - pos)
    var st_ll = br.read(data, self.ll.log)
    var st_of = br.read(data, self.oft.log)
    var st_ml = br.read(data, self.ml.log)
    if st_ll >= self.ll.size or st_of >= self.oft.size or st_ml >= self.ml.size:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var lit_i = 0
    var nseq = 0
    while nseq < nb:
        var is_last = 0
        if nseq + 1 == nb:
            is_last = 1
        var ll_base_v = self.ll.base[st_ll]
        var ml_base_v = self.ml.base[st_ml]
        var of_base_v = self.oft.base[st_of]
        var ll_add = self.ll.add[st_ll]
        var ml_add = self.ml.add[st_ml]
        var of_add = self.oft.add[st_of]
        var ll_nb = self.ll.nbits[st_ll]
        var ml_nb = self.ml.nbits[st_ml]
        var of_nb = self.oft.nbits[st_of]
        var ll_next = self.ll.nxt[st_ll]
        var ml_next = self.ml.nxt[st_ml]
        var of_next = self.oft.nxt[st_of]
        var offset = self.o1
        if of_add > 1:
            offset = of_base_v + br.read(data, of_add)
            self.o3 = self.o2
            self.o2 = self.o1
            self.o1 = offset
        elif of_add == 0 and ll_base_v == 0:
            offset = self.o2
            self.o2 = self.o1
            self.o1 = offset
        elif of_add != 0:
            var ll0 = 0
            if ll_base_v == 0:
                ll0 = 1
            var code = of_base_v + ll0 + br.read(data, 1)
            var temp = self.o1
            if code == 3:
                temp = self.o1 - 1
            elif code == 2:
                temp = self.o3
            elif code == 1:
                temp = self.o2
            if temp <= 0:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
            if code != 1:
                self.o3 = self.o2
            self.o2 = self.o1
            self.o1 = temp
            offset = temp
        var match_len = ml_base_v
        if ml_add != 0:
            match_len += br.read(data, ml_add)
        var lit_len = ll_base_v
        if ll_add != 0:
            lit_len += br.read(data, ll_add)
        if offset <= 0 or lit_len < 0 or match_len < 0:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        if lit_len > block_max or match_len > block_max:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        if lit_i + lit_len > len(lits):
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var t = 0
        while t < lit_len:
            out.append(lits[lit_i])
            lit_i += 1
            t += 1
        if offset > len(out) or offset > window:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var mpos = len(out) - offset
        t = 0
        while t < match_len:
            out.append(out[mpos + t])
            t += 1
        if is_last == 0:
            st_ll = ll_next + br.read(data, ll_nb)
            st_ml = ml_next + br.read(data, ml_nb)
            st_of = of_next + br.read(data, of_nb)
            if st_ll >= self.ll.size or st_ml >= self.ml.size or st_of >= self.oft.size or st_ll < 0 or st_ml < 0 or st_of < 0:
                raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        nseq += 1
    if br.bitpos != -1:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    while lit_i < len(lits):
        out.append(lits[lit_i])
        lit_i += 1
    self.seq_on = 1


def _install_table(mut ctx: ZCtx, data: List[Byte], mut pos: Int, end: Int, which: Int, mode: Int) raises DecodeError:
    if mode == 3:
        if ctx.seq_on == 0:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        return
    if mode == 0:
        if which == 0:
            var copied = _copy_fse(ctx.ll_def)
            ctx.ll = copied^
        elif which == 1:
            var copied = _copy_fse(ctx.of_def)
            ctx.oft = copied^
        else:
            var copied = _copy_fse(ctx.ml_def)
            ctx.ml = copied^
        return
    var max_sym = 35
    var max_log = 9
    if which == 1:
        max_sym = 31
        max_log = 8
    elif which == 2:
        max_sym = 52
    if mode == 1:
        if pos >= end:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var symbol = Int(data[pos])
        pos += 1
        if which == 0:
            var made = _make_rle(symbol, ctx.bases_ll, ctx.bits_ll)
            ctx.ll = made^
        elif which == 1:
            var made = _make_rle(symbol, ctx.bases_of, ctx.bits_of)
            ctx.oft = made^
        else:
            var made = _make_rle(symbol, ctx.bases_ml, ctx.bits_ml)
            ctx.ml = made^
        return
    if mode != 2:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var norm = List[Int]()
    var table_log = 0
    var npos = pos
    _read_ncount(data, pos, end, max_sym, max_log, norm, table_log, npos)
    pos = npos
    if which == 0:
        var built = _build_fse(norm, max_sym, table_log, ctx.bases_ll, ctx.bits_ll, 1)
        ctx.ll = built^
    elif which == 1:
        var built = _build_fse(norm, max_sym, table_log, ctx.bases_of, ctx.bits_of, 1)
        ctx.oft = built^
    else:
        var built = _build_fse(norm, max_sym, table_log, ctx.bases_ml, ctx.bits_ml, 1)
        ctx.ml = built^


def _read_huff(mut self: ZCtx, data: List[Byte], mut pos: Int, end: Int) raises DecodeError:
    if pos >= end:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var header = Int(data[pos])
    if header >= 128:
        var osize = header - 127
        var nbytes = (osize + 1) // 2
        if pos + 1 + nbytes > end:
            raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
        var weights = List[Int]()
        var n = 0
        while n < osize:
            var b = Int(data[pos + 1 + (n // 2)])
            weights.append(b >> 4)
            if n + 1 < osize:
                weights.append(b & 15)
            n += 2
        self.huff = _build_huff(weights)
        pos += 1 + nbytes
        return
    if header == 0 or pos + 1 + header > end:
        raise DecodeError(DecodeError.KIND_COMPRESSION, pos)
    var weights = _fse_weights(data, pos + 1, header, 255)
    self.huff = _build_huff(weights)
    pos += 1 + header


def _fse_weights(data: List[Byte], start: Int, size: Int, max_out: Int) raises DecodeError -> List[Int]:
    var norm = List[Int]()
    var table_log = 0
    var npos = start
    _read_ncount(data, start, start + size, 255, 6, norm, table_log, npos)
    var empty_b = List[Int]()
    var tab = _build_fse(norm, 255, table_log, empty_b, empty_b, 0)
    if npos >= start + size:
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    var br = _rev(data, npos, start + size - npos)
    var s1 = br.read(data, table_log)
    var s2 = br.read(data, table_log)
    var out = List[Int]()
    var guard = 0
    while guard <= max_out:
        if len(out) > max_out - 2:
            raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        if s1 < 0 or s1 >= tab.size:
            raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        var sym = tab.sym[s1]
        var low = br.read(data, tab.nbits[s1])
        s1 = tab.nxt[s1] + low
        out.append(sym)
        if br.bitpos < -1:
            if s2 < 0 or s2 >= tab.size:
                raise DecodeError(DecodeError.KIND_COMPRESSION, start)
            out.append(tab.sym[s2])
            break
        if len(out) > max_out - 2:
            raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        if s2 < 0 or s2 >= tab.size:
            raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        sym = tab.sym[s2]
        low = br.read(data, tab.nbits[s2])
        s2 = tab.nxt[s2] + low
        out.append(sym)
        if br.bitpos < -1:
            if s1 < 0 or s1 >= tab.size:
                raise DecodeError(DecodeError.KIND_COMPRESSION, start)
            out.append(tab.sym[s1])
            break
        guard += 1
    if len(out) > max_out or guard > max_out:
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    return out^


def _huf_decode(data: List[Byte], start: Int, size: Int, tab: HuffTab, count: Int) raises DecodeError -> List[Byte]:
    if size < 1:
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    var br = _rev(data, start, size)
    var out = List[Byte]()
    if count == 0:
        if br.bitpos != -1:
            raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        return out^
    var k = 0
    while k < count:
        var val = br.peek(data, tab.log)
        if val < 0 or val >= tab.size:
            raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        var nb = tab.nbits[val]
        if nb <= 0 or nb > tab.log:
            raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        var skip = br.read(data, nb)
        if skip < 0:
            raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        out.append(Byte(tab.sym[val]))
        k += 1
    if br.bitpos != -1:
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    return out^


def _build_huff(weights: List[Int]) raises DecodeError -> HuffTab:
    var rank = List[Int]()
    rank.resize(16, 0)
    var total = 0
    var i = 0
    while i < len(weights):
        var w = weights[i]
        if w < 0 or w > 12:
            raise DecodeError(DecodeError.KIND_COMPRESSION, i)
        rank[w] += 1
        if w > 0:
            total += 1 << (w - 1)
        i += 1
    if total <= 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, 0)
    var table_log = _bit_length(total) - 1 + 1
    if table_log > 11 or table_log <= 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, 0)
    var full = 1 << table_log
    var rest = full - total
    if rest <= 0 or (rest & (rest - 1)) != 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, 0)
    var last = _bit_length(rest)
    var ws = weights.copy()
    ws.append(last)
    rank[last] += 1
    if rank[1] < 2 or (rank[1] & 1) != 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, 0)
    var nb = len(ws)
    var rank_start = List[Int]()
    rank_start.resize(table_log + 1, 0)
    var acc = 0
    var w = 0
    while w <= table_log:
        rank_start[w] = acc
        acc += rank[w]
        w += 1
    var ordered = List[Int]()
    ordered.resize(nb, 0)
    var rs = rank_start.copy()
    i = 0
    while i < nb:
        var ww = ws[i]
        var at = rs[ww]
        ordered[at] = i
        rs[ww] = at + 1
        i += 1
    var table_size = 1 << table_log
    var tab = HuffTab()
    tab.log = table_log
    tab.size = table_size
    tab.sym.resize(table_size, 0)
    tab.nbits.resize(table_size, 0)
    var idx = rank[0]
    var slot = 0
    w = 1
    while w <= table_log:
        var count = rank[w]
        var length = 1 << (w - 1)
        var bits = table_log + 1 - w
        var s = 0
        while s < count:
            var symbol = ordered[idx + s]
            var u = 0
            while u < length:
                if slot >= table_size:
                    raise DecodeError(DecodeError.KIND_COMPRESSION, slot)
                tab.sym[slot] = symbol
                tab.nbits[slot] = bits
                slot += 1
                u += 1
            s += 1
        idx += count
        w += 1
    if slot != table_size:
        raise DecodeError(DecodeError.KIND_COMPRESSION, slot)
    return tab^


def _read_ncount(data: List[Byte], start: Int, limit: Int, max_symbol: Int, max_log: Int, mut norm: List[Int], mut table_log: Int, mut npos: Int) raises DecodeError:
    if start >= limit or start < 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    var br = FwdBits(start, limit)
    var acc = br.read(data, 4) + 5
    if acc > max_log or acc > 15 or acc < 5:
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    table_log = acc
    var remaining = (1 << table_log) + 1
    var threshold = 1 << table_log
    var nb_bits = table_log + 1
    norm.clear()
    norm.resize(max_symbol + 1, 0)
    var charnum = 0
    var prev0 = 0
    var guard = 0
    while guard < max_symbol + 8:
        guard += 1
        if prev0 != 0:
            while True:
                var rep = br.read(data, 2)
                charnum += rep
                if rep != 3:
                    break
            if charnum > max_symbol + 1:
                raise DecodeError(DecodeError.KIND_COMPRESSION, start)
            if charnum >= max_symbol + 1:
                break
        var maxv = (2 * threshold - 1) - remaining
        if maxv < 0 or nb_bits <= 1:
            raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        var low = br.peek(data, nb_bits - 1)
        var val = low
        if low < maxv:
            var consumed = br.read(data, nb_bits - 1)
            if consumed < 0:
                raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        else:
            val = br.read(data, nb_bits)
            if val >= threshold:
                val -= maxv
        val -= 1
        if charnum > max_symbol:
            raise DecodeError(DecodeError.KIND_COMPRESSION, start)
        norm[charnum] = val
        charnum += 1
        if val >= 0:
            remaining -= val
        else:
            if val != -1:
                raise DecodeError(DecodeError.KIND_COMPRESSION, start)
            remaining -= 1
        if val == 0:
            prev0 = 1
        else:
            prev0 = 0
        if remaining < threshold:
            if remaining <= 1:
                break
            nb_bits = _bit_length(remaining)
            threshold = 1 << (nb_bits - 1)
        if charnum >= max_symbol + 1:
            break
    if remaining != 1 or charnum > max_symbol + 1:
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    var used = br.bytes_used()
    if start + used > limit:
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    var nonzero = 0
    var i = 0
    while i < len(norm):
        if norm[i] != 0:
            nonzero += 1
        i += 1
    if nonzero < 2:
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    npos = start + used


def _build_fse(norm: List[Int], max_symbol: Int, table_log: Int, bases: List[Int], adds: List[Int], use_base: Int) raises DecodeError -> FseTab:
    if table_log < 5 or table_log > 12 or max_symbol < 0 or max_symbol >= len(norm):
        raise DecodeError(DecodeError.KIND_COMPRESSION, table_log)
    var table_size = 1 << table_log
    var symbol_at = List[Int]()
    symbol_at.resize(table_size, 0)
    var symbol_next = List[Int]()
    symbol_next.resize(max_symbol + 1, 0)
    var high = table_size - 1
    var s = 0
    while s <= max_symbol:
        if norm[s] == -1:
            if high < 0:
                raise DecodeError(DecodeError.KIND_COMPRESSION, s)
            symbol_at[high] = s
            high -= 1
            symbol_next[s] = 1
        elif norm[s] < 0:
            raise DecodeError(DecodeError.KIND_COMPRESSION, s)
        else:
            symbol_next[s] = norm[s]
        s += 1
    var step = (table_size >> 1) + (table_size >> 3) + 3
    var mask = table_size - 1
    var position = 0
    s = 0
    while s <= max_symbol:
        var count = norm[s]
        if count > 0:
            var j = 0
            while j < count:
                symbol_at[position] = s
                position = (position + step) & mask
                var spins = 0
                while position > high:
                    position = (position + step) & mask
                    spins += 1
                    if spins > table_size:
                        raise DecodeError(DecodeError.KIND_COMPRESSION, s)
                j += 1
        s += 1
    if position != 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, position)
    var tab = FseTab()
    tab.log = table_log
    tab.size = table_size
    tab.nbits.resize(table_size, 0)
    tab.nxt.resize(table_size, 0)
    tab.base.resize(table_size, 0)
    tab.add.resize(table_size, 0)
    tab.sym.resize(table_size, 0)
    var u = 0
    while u < table_size:
        var symbol = symbol_at[u]
        var ns = symbol_next[symbol]
        symbol_next[symbol] = ns + 1
        if ns <= 0:
            raise DecodeError(DecodeError.KIND_COMPRESSION, u)
        var nb = table_log - (_bit_length(ns) - 1)
        tab.nbits[u] = nb
        tab.nxt[u] = (ns << nb) - table_size
        tab.sym[u] = symbol
        if use_base != 0:
            if symbol < 0 or symbol >= len(bases) or symbol >= len(adds):
                raise DecodeError(DecodeError.KIND_COMPRESSION, symbol)
            tab.base[u] = bases[symbol]
            tab.add[u] = adds[symbol]
        u += 1
    return tab^


def _make_rle(symbol: Int, bases: List[Int], adds: List[Int]) raises DecodeError -> FseTab:
    if symbol < 0 or symbol >= len(bases) or symbol >= len(adds):
        raise DecodeError(DecodeError.KIND_COMPRESSION, symbol)
    var tab = FseTab()
    tab.log = 0
    tab.size = 1
    tab.nbits.append(0)
    tab.nxt.append(0)
    tab.base.append(bases[symbol])
    tab.add.append(adds[symbol])
    tab.sym.append(symbol)
    return tab^


def _copy_fse(src: FseTab) -> FseTab:
    var dst = FseTab()
    dst.log = src.log
    dst.size = src.size
    dst.nbits = src.nbits.copy()
    dst.nxt = src.nxt.copy()
    dst.base = src.base.copy()
    dst.add = src.add.copy()
    dst.sym = src.sym.copy()
    return dst^


def _rev(data: List[Byte], start: Int, size: Int) raises DecodeError -> RevBits:
    if size < 1 or start < 0 or start + size > len(data):
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    var last = Int(data[start + size - 1])
    if last == 0:
        raise DecodeError(DecodeError.KIND_COMPRESSION, start)
    var hibit = _bit_length(last) - 1
    var bitpos = (size - 1) * 8 + hibit - 1
    return RevBits(start, bitpos)


def _bit_length(v: Int) -> Int:
    var n = 0
    var x = v
    while x > 0:
        x = x >> 1
        n += 1
    return n


def _u32(raw: List[Byte], i: Int) -> Int:
    return Int(raw[i]) | (Int(raw[i + 1]) << 8) | (Int(raw[i + 2]) << 16) | (Int(raw[i + 3]) << 24)
