from std.collections import List, Span
from std.memory import unsafe_memcpy

from cbor_runtime.cde import assert_cde_roundtrip, encoded_eq
from cbor_runtime.error import DecodeError
from cbor_runtime.options import EncodeOptions
from cbor_wire.half import f32_from_bits, f64_from_bits, f64_to_bits, half_to_f64
from cbor_wire.head import AI_INDEF, MAX_ITEM_BYTES
from cbor_wire.reader import WireReader
from cbor_wire.utf8 import string_from_utf8
from cbor_wire.writer import WireWriter


comptime CK_INT = 1
comptime CK_UINT = 2
comptime CK_BYTES = 3
comptime CK_TEXT = 4
comptime CK_ARRAY = 5
comptime CK_MAP = 6
comptime CK_TAG = 7
comptime CK_FALSE = 8
comptime CK_TRUE = 9
comptime CK_NULL = 10
comptime CK_UNDEFINED = 11
comptime CK_SIMPLE = 12
comptime CK_FLOAT16 = 13
comptime CK_FLOAT32 = 14
comptime CK_FLOAT64 = 15

comptime FLAG_INDEF = 1


struct CborNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int64
    var b: UInt64
    var c: Int
    var flags: Int

    def __init__(out self, kind: Int, a: Int64 = 0, b: UInt64 = 0, c: Int = 0, flags: Int = 0):
        self.kind = kind
        self.a = a
        self.b = b
        self.c = c
        self.flags = flags


struct CborValue(Movable):
    """Arena of CBOR items. Nested containers use `kids` as a child-index table."""

    var nodes: List[CborNode]
    var kids: List[Int]
    var bytes: List[Byte]
    var texts: List[String]
    var root: Int

    def __init__(out self):
        self.nodes = List[CborNode]()
        self.kids = List[Int]()
        self.bytes = List[Byte]()
        self.texts = List[String]()
        self.root = 0

    def add(mut self, node: CborNode) -> Int:
        var idx = len(self.nodes)
        self.nodes.append(node)
        return idx

    def is_indef(self, idx: Int) -> Bool:
        return (self.nodes[idx].flags & FLAG_INDEF) != 0


def _append_bytes(mut v: CborValue, src: List[Byte]) -> Int:
    var start = len(v.bytes)
    var n = len(src)
    if n == 0:
        return start
    v.bytes.resize(unsafe_uninit_length=start + n)
    unsafe_memcpy(
        dest=v.bytes.unsafe_ptr().unsafe_offset(start),
        src=src.unsafe_ptr(),
        count=n,
    )
    return start


struct _TextCache:
    """Short-text intern table. `dense` is a linear scan until 8 entries, then `slots`."""

    var slots: List[Int]
    var dense: List[Int]
    var count: Int

    def __init__(out self):
        self.slots = List[Int](unsafe_uninit_length=64)
        for i in range(64):
            self.slots[i] = -1
        self.dense = List[Int](capacity=8)
        self.count = 0


def _hash_bytes[origin: ImmOrigin](sp: Span[Byte, origin]) -> UInt64:
    var h = UInt64(0xCBF29CE484222325)
    var n = len(sp)
    for i in range(n):
        h = (h ^ UInt64(sp[i])) * UInt64(0x100000001B3)
    return h


def _text_has_bytes[origin: ImmOrigin](v: CborValue, idx: Int, sp: Span[Byte, origin]) -> Bool:
    var tb = v.texts[idx].as_bytes()
    var n = len(sp)
    if len(tb) != n:
        return False
    for i in range(n):
        if tb[i] != sp[i]:
            return False
    return True


def _cache_grow(mut c: _TextCache, v: CborValue):
    var n = len(c.slots) * 2
    if n < 64:
        n = 64
    var old_n = len(c.slots)
    var old = c.slots^
    c.slots = List[Int](unsafe_uninit_length=n)
    for i in range(n):
        c.slots[i] = -1
    var mask = n - 1
    for i in range(old_n):
        var idx = old[i]
        if idx >= 0:
            var h = _hash_bytes(v.texts[idx].as_bytes())
            var slot = Int(h & UInt64(mask))
            while c.slots[slot] >= 0:
                slot = (slot + 1) & mask
            c.slots[slot] = idx


def _intern_insert[
    origin: ImmOrigin
](mut c: _TextCache, v: CborValue, sp: Span[Byte, origin], idx: Int):
    if (c.count + 1) * 2 > len(c.slots):
        _cache_grow(c, v)
    var mask = len(c.slots) - 1
    var h = _hash_bytes(sp)
    var slot = Int(h & UInt64(mask))
    while c.slots[slot] >= 0:
        slot = (slot + 1) & mask
    c.slots[slot] = idx
    if c.count < 8:
        c.dense.append(idx)
    c.count += 1


def _intern_text[
    origin: ImmOrigin
](mut c: _TextCache, mut v: CborValue, sp: Span[Byte, origin], at: Int) raises DecodeError -> Int:
    """Reuse a previous text node when the UTF-8 bytes match. Long strings are not cached."""
    var n = len(sp)
    if n > 128:
        var big = string_from_utf8(sp, at)
        var big_idx = len(v.texts)
        v.texts.append(big^)
        return big_idx
    # Repeated map keys hit a handful of recent strings. Skip hashing those.
    if c.count <= 8:
        for i in range(c.count):
            var cur = c.dense[i]
            if _text_has_bytes(v, cur, sp):
                return cur
    else:
        if (c.count + 1) * 2 > len(c.slots):
            _cache_grow(c, v)
        var mask = len(c.slots) - 1
        var h = _hash_bytes(sp)
        var slot = Int(h & UInt64(mask))
        while True:
            var cur = c.slots[slot]
            if cur < 0:
                break
            if _text_has_bytes(v, cur, sp):
                return cur
            slot = (slot + 1) & mask
    var s = string_from_utf8(sp, at)
    var idx = len(v.texts)
    v.texts.append(s^)
    _intern_insert(c, v, sp, idx)
    return idx


def _reserve_decode(mut v: CborValue, n: Int):
    if n <= 0:
        return
    var nodes = n
    if nodes > 4096:
        nodes = 4096
    v.nodes.reserve(nodes)
    v.kids.reserve(nodes)
    var texts = n
    if texts > 1024:
        texts = 1024
    v.texts.reserve(texts)
    var nbytes = n
    if nbytes > 65536:
        nbytes = 65536
    v.bytes.reserve(nbytes)


def _text_from_stored(data: List[Byte], start: Int, n: Int, at: Int) raises DecodeError -> String:
    if n <= 0:
        return String()
    var whole = Span(data)
    return string_from_utf8(whole[start : start + n], at)


def _decode_indef_bytes[
    origin: ImmOrigin
](mut r: WireReader[origin], mut v: CborValue, want_major: Int) raises DecodeError -> Tuple[Int, Int]:
    var start = len(v.bytes)
    var total = 0
    while True:
        if r.read_break_or_item():
            break
        var h = r.read_head()
        if h[0] != want_major or h[2] == AI_INDEF:
            raise DecodeError(DecodeError.KIND_TYPE, r.position())
        var n = Int(h[1])
        if n < 0 or total + n > MAX_ITEM_BYTES:
            raise DecodeError(DecodeError.KIND_RANGE, r.position())
        r.append_exact(v.bytes, n)
        total += n
    return (start, total)


def decode_item[
    origin: ImmOrigin
](mut r: WireReader[origin], mut v: CborValue, mut cache: _TextCache) raises DecodeError -> Int:
    r.enter()
    var at = r.position()
    var h = r.read_head()
    var major = h[0]
    var arg = h[1]
    var ai = h[2]
    var idx: Int
    if major == 0:
        if arg <= UInt64(Int64.MAX):
            idx = v.add(CborNode(CK_INT, a=Int64(arg)))
        else:
            idx = v.add(CborNode(CK_UINT, b=arg))
    elif major == 1:
        if arg > UInt64(Int64.MAX):
            raise DecodeError(DecodeError.KIND_RANGE, at)
        var nval = -(Int64(arg) + Int64(1))
        idx = v.add(CborNode(CK_INT, a=nval))
    elif major == 2:
        if ai == AI_INDEF:
            var pair = _decode_indef_bytes(r, v, 2)
            idx = v.add(
                CborNode(CK_BYTES, a=Int64(pair[0]), b=UInt64(pair[1]), flags=FLAG_INDEF)
            )
        else:
            var n = Int(arg)
            var start = len(v.bytes)
            r.append_exact(v.bytes, n)
            idx = v.add(CborNode(CK_BYTES, a=Int64(start), b=UInt64(n)))
    elif major == 3:
        if ai == AI_INDEF:
            var pair2 = _decode_indef_bytes(r, v, 3)
            var span_start = pair2[0]
            var span_n = pair2[1]
            var s = _text_from_stored(v.bytes, span_start, span_n, at)
            var tidx = len(v.texts)
            v.texts.append(s^)
            idx = v.add(
                CborNode(CK_TEXT, a=Int64(tidx), b=UInt64(span_n), flags=FLAG_INDEF)
            )
        else:
            var n2 = Int(arg)
            var sp = r.read_payload_span(n2)
            var tidx2 = _intern_text(cache, v, sp, r.position() - n2)
            idx = v.add(CborNode(CK_TEXT, a=Int64(tidx2), b=UInt64(n2)))
    elif major == 4:
        # Reserve direct-child slots before recursing. Nested containers append
        # their own kids after this range, so the slots stay contiguous.
        var count = 0
        var flags = 0
        var kstart = len(v.kids)
        if ai == AI_INDEF:
            flags = FLAG_INDEF
            var direct = List[Int]()
            while True:
                if r.read_break_or_item():
                    break
                direct.append(_decode_one(r, v, cache))
                count += 1
            kstart = len(v.kids)
            for i in range(count):
                v.kids.append(direct[i])
        else:
            r.check_count(arg)
            count = Int(arg)
            for _s in range(count):
                v.kids.append(-1)
            for i in range(count):
                v.kids[kstart + i] = _decode_one(r, v, cache)
        idx = v.add(CborNode(CK_ARRAY, a=Int64(kstart), b=UInt64(count), flags=flags))
    elif major == 5:
        var pairs = 0
        var mflags = 0
        var mstart = len(v.kids)
        if ai == AI_INDEF:
            mflags = FLAG_INDEF
            var directm = List[Int]()
            while True:
                if r.read_break_or_item():
                    break
                var key = _decode_one(r, v, cache)
                if r.read_break_or_item():
                    raise DecodeError(DecodeError.KIND_MAP_PAIR, r.position())
                var val = _decode_one(r, v, cache)
                directm.append(key)
                directm.append(val)
                pairs += 1
            mstart = len(v.kids)
            for i in range(len(directm)):
                v.kids.append(directm[i])
        else:
            r.check_count(arg)
            pairs = Int(arg)
            var slots = pairs * 2
            for _s2 in range(slots):
                v.kids.append(-1)
            for j in range(pairs):
                v.kids[mstart + j * 2] = _decode_one(r, v, cache)
                v.kids[mstart + j * 2 + 1] = _decode_one(r, v, cache)
        idx = v.add(CborNode(CK_MAP, a=Int64(mstart), b=UInt64(pairs), flags=mflags))
    elif major == 6:
        var child3 = _decode_one(r, v, cache)
        var cn = v.nodes[child3]
        # RFC 8949 §3.4.1: tag 0 is a date-time text string; tag 1 is a numeric
        # epoch offset. The official vectors reject a map in either position.
        if arg == UInt64(0):
            if cn.kind != CK_TEXT:
                raise DecodeError(DecodeError.KIND_TAG, at)
        elif arg == UInt64(1):
            if (
                cn.kind != CK_INT
                and cn.kind != CK_UINT
                and cn.kind != CK_FLOAT16
                and cn.kind != CK_FLOAT32
                and cn.kind != CK_FLOAT64
            ):
                raise DecodeError(DecodeError.KIND_TAG, at)
        idx = v.add(CborNode(CK_TAG, b=arg, c=child3))
    elif major == 7:
        if ai == AI_INDEF:
            raise DecodeError(DecodeError.KIND_BREAK, at)
        if ai == 25:
            idx = v.add(CborNode(CK_FLOAT16, b=arg))
        elif ai == 26:
            idx = v.add(CborNode(CK_FLOAT32, b=arg))
        elif ai == 27:
            idx = v.add(CborNode(CK_FLOAT64, b=arg))
        else:
            var simple = Int(arg)
            if simple == 20:
                idx = v.add(CborNode(CK_FALSE))
            elif simple == 21:
                idx = v.add(CborNode(CK_TRUE))
            elif simple == 22:
                idx = v.add(CborNode(CK_NULL))
            elif simple == 23:
                idx = v.add(CborNode(CK_UNDEFINED))
            else:
                idx = v.add(CborNode(CK_SIMPLE, a=Int64(simple)))
    else:
        raise DecodeError(DecodeError.KIND_TYPE, at)
    r.leave()
    return idx


def _decode_fast_leaf[
    origin: ImmOrigin
](mut r: WireReader[origin], mut v: CborValue, mut cache: _TextCache) raises DecodeError -> Int:
    """Decode a small int, short text, or simple literal. Returns -1 if the head is not one of those."""
    var limit = len(r.data)
    if r.pos >= limit:
        return -1
    var b = Int(r.data[r.pos])
    var major = b >> 5
    var ai = b & 0x1F
    if major == 0 and ai < 24:
        if r.depth >= r.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, r.pos)
        r.pos += 1
        return v.add(CborNode(CK_INT, a=Int64(ai)))
    if major == 1 and ai < 24:
        if r.depth >= r.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, r.pos)
        r.pos += 1
        return v.add(CborNode(CK_INT, a=-(Int64(ai) + Int64(1))))
    if major == 0 and ai == 24:
        if r.depth >= r.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, r.pos)
        if r.pos + 1 >= limit:
            raise DecodeError(DecodeError.KIND_EOF, r.pos + 1)
        var arg = Int(r.data[r.pos + 1])
        r.pos += 2
        return v.add(CborNode(CK_INT, a=Int64(arg)))
    if major == 1 and ai == 24:
        if r.depth >= r.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, r.pos)
        if r.pos + 1 >= limit:
            raise DecodeError(DecodeError.KIND_EOF, r.pos + 1)
        var narg = Int(r.data[r.pos + 1])
        r.pos += 2
        return v.add(CborNode(CK_INT, a=-(Int64(narg) + Int64(1))))
    if major == 3 and ai < 24:
        if r.depth >= r.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, r.pos)
        var n = ai
        if r.pos + 1 + n > limit:
            raise DecodeError(DecodeError.KIND_EOF, r.pos + 1)
        var payload = r.pos + 1
        r.pos = payload + n
        var tidx = _intern_text(cache, v, r.data[payload : payload + n], payload)
        return v.add(CborNode(CK_TEXT, a=Int64(tidx), b=UInt64(n)))
    if major == 7 and ai >= 20 and ai <= 23:
        if r.depth >= r.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, r.pos)
        r.pos += 1
        if ai == 20:
            return v.add(CborNode(CK_FALSE))
        if ai == 21:
            return v.add(CborNode(CK_TRUE))
        if ai == 22:
            return v.add(CborNode(CK_NULL))
        return v.add(CborNode(CK_UNDEFINED))
    return -1


def _decode_one[
    origin: ImmOrigin
](mut r: WireReader[origin], mut v: CborValue, mut cache: _TextCache) raises DecodeError -> Int:
    """Decode one item. Small containers recurse here so depth stays one frame per level."""
    var leaf = _decode_fast_leaf(r, v, cache)
    if leaf >= 0:
        return leaf
    if r.pos >= len(r.data):
        return decode_item(r, v, cache)
    var b = Int(r.data[r.pos])
    var ai = b & 0x1F
    var major = b >> 5
    if ai < 24 and (major == 4 or major == 5):
        if r.depth >= r.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, r.pos)
        r.depth += 1
        r.pos += 1
        var count = ai
        var kstart = len(v.kids)
        if major == 4:
            for _s in range(count):
                v.kids.append(-1)
            for i in range(count):
                v.kids[kstart + i] = _decode_one(r, v, cache)
            r.depth -= 1
            return v.add(CborNode(CK_ARRAY, a=Int64(kstart), b=UInt64(count)))
        var slots = count * 2
        for _s2 in range(slots):
            v.kids.append(-1)
        for j in range(count):
            v.kids[kstart + j * 2] = _decode_one(r, v, cache)
            v.kids[kstart + j * 2 + 1] = _decode_one(r, v, cache)
        r.depth -= 1
        return v.add(CborNode(CK_MAP, a=Int64(kstart), b=UInt64(count)))
    return decode_item(r, v, cache)


def decode_value[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> CborValue:
    var r = WireReader(buf)
    var v = CborValue()
    _reserve_decode(v, len(buf))
    var cache = _TextCache()
    v.root = _decode_one(r, v, cache)
    if r.remaining() > 0:
        raise DecodeError(DecodeError.KIND_TRAILING, r.position())
    return v^


def _is_nan_or_inf(bits: UInt64) -> Bool:
    var exp = Int((bits >> UInt64(52)) & UInt64(0x7FF))
    return exp == 0x7FF


def _encode_float_dcbor(mut w: WireWriter, fv: Float64) raises DecodeError:
    var bits = f64_to_bits(fv)
    if _is_nan_or_inf(bits):
        raise DecodeError(DecodeError.KIND_CDE, 0)
    var as_int = Int64(fv)
    if Float64(as_int) == fv:
        w.write_int(as_int)
        return
    w.write_float_preferred(fv)


def _emit(v: CborValue, idx: Int, mut w: WireWriter, options: EncodeOptions) raises DecodeError:
    """Inline leaf writes. Containers go through `_encode_node`."""
    var n = v.nodes[idx]
    var k = n.kind
    if k == CK_INT:
        w.write_int(n.a)
        return
    if k == CK_UINT:
        w.write_uint(n.b)
        return
    if k == CK_TEXT and (options.mode != EncodeOptions.IDENTITY or (n.flags & FLAG_INDEF) == 0):
        w.write_tstr(v.texts[Int(n.a)])
        return
    if k == CK_FALSE:
        w.write_false()
        return
    if k == CK_TRUE:
        w.write_true()
        return
    if k == CK_NULL:
        w.write_null()
        return
    _encode_node(v, idx, w, options)


def _encode_node(v: CborValue, idx: Int, mut w: WireWriter, options: EncodeOptions) raises DecodeError:
    var n = v.nodes[idx]
    var ident = options.mode == EncodeOptions.IDENTITY
    var dcbor = options.mode == EncodeOptions.DCBOR
    if n.kind == CK_INT:
        w.write_int(n.a)
    elif n.kind == CK_UINT:
        w.write_uint(n.b)
    elif n.kind == CK_BYTES:
        var start = Int(n.a)
        var ln = Int(n.b)
        if ident and (n.flags & FLAG_INDEF) != 0:
            w.write_head_raw(2, AI_INDEF, UInt64(0))
            w.write_head(2, n.b)
            w.write_bytes_range(v.bytes, start, ln)
            w.write_break()
        else:
            w.write_head(2, UInt64(ln))
            w.write_bytes_range(v.bytes, start, ln)
    elif n.kind == CK_TEXT:
        var ti = Int(n.a)
        if ident and (n.flags & FLAG_INDEF) != 0:
            var nb = v.texts[ti].byte_length()
            w.write_head_raw(3, AI_INDEF, UInt64(0))
            w.write_head(3, UInt64(nb))
            w.write_bytes(v.texts[ti].as_bytes())
            w.write_break()
        else:
            w.write_tstr(v.texts[ti])
    elif n.kind == CK_ARRAY:
        var count = Int(n.b)
        var k0 = Int(n.a)
        if ident and (n.flags & FLAG_INDEF) != 0:
            w.write_head_raw(4, AI_INDEF, UInt64(0))
            for i in range(count):
                _emit(v, v.kids[k0 + i], w, options)
            w.write_break()
        else:
            w.write_array_len(count)
            for i in range(count):
                _emit(v, v.kids[k0 + i], w, options)
    elif n.kind == CK_MAP:
        _encode_map(v, idx, w, options)
    elif n.kind == CK_TAG:
        w.write_tag(n.b)
        _emit(v, n.c, w, options)
    elif n.kind == CK_FALSE:
        w.write_false()
    elif n.kind == CK_TRUE:
        w.write_true()
    elif n.kind == CK_NULL:
        w.write_null()
    elif n.kind == CK_UNDEFINED:
        if dcbor:
            raise DecodeError(DecodeError.KIND_CDE, 0)
        w.write_undefined()
    elif n.kind == CK_SIMPLE:
        if dcbor:
            raise DecodeError(DecodeError.KIND_CDE, 0)
        w.write_simple(Int(n.a))
    elif n.kind == CK_FLOAT16:
        if ident:
            w.write_float16_bits(UInt16(n.b))
        elif dcbor:
            _encode_float_dcbor(w, half_to_f64(UInt16(n.b)))
        else:
            w.write_float_preferred(half_to_f64(UInt16(n.b)))
    elif n.kind == CK_FLOAT32:
        if ident:
            w.write_float32_bits(UInt32(n.b))
        elif dcbor:
            _encode_float_dcbor(w, Float64(f32_from_bits(UInt32(n.b))))
        else:
            w.write_float_preferred(Float64(f32_from_bits(UInt32(n.b))))
    elif n.kind == CK_FLOAT64:
        if ident:
            w.write_float64_bits(n.b)
        elif dcbor:
            _encode_float_dcbor(w, f64_from_bits(n.b))
        else:
            w.write_float_preferred(f64_from_bits(n.b))
    else:
        raise DecodeError(DecodeError.KIND_TYPE, 0)


def _text_eq(v: CborValue, ia: Int, ib: Int) -> Bool:
    if ia == ib:
        return True
    var ab = v.texts[ia].as_bytes()
    var bb = v.texts[ib].as_bytes()
    var n = len(ab)
    if n != len(bb):
        return False
    for i in range(n):
        if ab[i] != bb[i]:
            return False
    return True


def _raw_eq(v: CborValue, a0: Int, an: Int, b0: Int, bn: Int) -> Bool:
    if an != bn:
        return False
    for i in range(an):
        if v.bytes[a0 + i] != v.bytes[b0 + i]:
            return False
    return True


def _encoded_key_eq(v: CborValue, ai: Int, bi: Int) raises DecodeError -> Bool:
    var wa = WireWriter(capacity=48)
    _encode_node(v, ai, wa, EncodeOptions.preferred)
    var wb = WireWriter(capacity=48)
    _encode_node(v, bi, wb, EncodeOptions.preferred)
    var ba = wa^.finish()
    var bb = wb^.finish()
    return encoded_eq(ba, bb)


def _preferred_key_eq(v: CborValue, ai: Int, bi: Int) raises DecodeError -> Bool:
    """Adjacent-key duplicate check. Same bytes as preferred encoding, without a temp list for leaves."""
    var a = v.nodes[ai]
    var b = v.nodes[bi]
    var k = a.kind
    if k != b.kind:
        return _encoded_key_eq(v, ai, bi)
    if k == CK_TEXT:
        if a.b != UInt64(0) and b.b != UInt64(0) and a.b != b.b:
            return False
        return _text_eq(v, Int(a.a), Int(b.a))
    if k == CK_INT:
        return a.a == b.a
    if k == CK_UINT:
        return a.b == b.b
    if k == CK_BYTES:
        return _raw_eq(v, Int(a.a), Int(a.b), Int(b.a), Int(b.b))
    if k == CK_FALSE or k == CK_TRUE or k == CK_NULL or k == CK_UNDEFINED:
        return True
    if k == CK_SIMPLE:
        return a.a == b.a
    return _encoded_key_eq(v, ai, bi)


def _range_lt(buf: List[Byte], a0: Int, a1: Int, b0: Int, b1: Int) -> Bool:
    var an = a1 - a0
    var bn = b1 - b0
    var n = an
    if bn < n:
        n = bn
    for i in range(n):
        var av = Int(buf[a0 + i])
        var bv = Int(buf[b0 + i])
        if av < bv:
            return True
        if av > bv:
            return False
    return an < bn


def _range_eq(buf: List[Byte], a0: Int, a1: Int, b0: Int, b1: Int) -> Bool:
    var an = a1 - a0
    if an != b1 - b0:
        return False
    for i in range(an):
        if buf[a0 + i] != buf[b0 + i]:
            return False
    return True


def _sort_key_ranges(buf: List[Byte], starts: List[Int], pairs: Int) -> List[Int]:
    var order = List[Int](capacity=pairs)
    for i in range(pairs):
        order.append(i)
    for i in range(pairs):
        var j = i
        while j > 0:
            var aj = order[j]
            var ak = order[j - 1]
            if _range_lt(buf, starts[aj], starts[aj + 1], starts[ak], starts[ak + 1]):
                order[j] = ak
                order[j - 1] = aj
                j -= 1
            else:
                break
    return order^


def _key_copy_ok(kind: Int) -> Bool:
    """Preferred bytes of this key match CDE/dCBOR bytes (no nested map sort, not a float-to-int)."""
    if kind == CK_ARRAY or kind == CK_MAP or kind == CK_TAG:
        return False
    if kind == CK_FLOAT16 or kind == CK_FLOAT32 or kind == CK_FLOAT64:
        return False
    return True


def _encode_map(
    v: CborValue, idx: Int, mut w: WireWriter, options: EncodeOptions
) raises DecodeError:
    var n = v.nodes[idx]
    var pairs = Int(n.b)
    var k0 = Int(n.a)
    var ident = options.mode == EncodeOptions.IDENTITY
    var dcbor = options.mode == EncodeOptions.DCBOR
    if ident and (n.flags & FLAG_INDEF) != 0:
        w.write_head_raw(5, AI_INDEF, UInt64(0))
        for i in range(pairs):
            _emit(v, v.kids[k0 + i * 2], w, options)
            _emit(v, v.kids[k0 + i * 2 + 1], w, options)
        w.write_break()
        return
    if options.mode != EncodeOptions.CDE and not dcbor:
        w.write_map_len(pairs)
        var prev = -1
        for i in range(pairs):
            var key = v.kids[k0 + i * 2]
            if i > 0 and _preferred_key_eq(v, prev, key):
                raise DecodeError(DecodeError.KIND_DUP_KEY, 0)
            prev = key
            _emit(v, key, w, options)
            _emit(v, v.kids[k0 + i * 2 + 1], w, options)
        return
    if dcbor:
        for i in range(pairs):
            if v.nodes[v.kids[k0 + i * 2]].kind != CK_TEXT:
                raise DecodeError(DecodeError.KIND_CDE, 0)
    var scratch = WireWriter(capacity=pairs * 16 + 16)
    var starts = List[Int](capacity=pairs + 1)
    starts.append(0)
    for i in range(pairs):
        _encode_node(v, v.kids[k0 + i * 2], scratch, EncodeOptions.preferred)
        starts.append(scratch.pos)
    var order = _sort_key_ranges(scratch.buf, starts, pairs)
    if pairs > 1:
        for i in range(1, pairs):
            var left = order[i - 1]
            var right = order[i]
            if _range_eq(scratch.buf, starts[left], starts[left + 1], starts[right], starts[right + 1]):
                raise DecodeError(DecodeError.KIND_DUP_KEY, 0)
    w.write_map_len(pairs)
    for i in range(pairs):
        var p = order[i]
        var key_idx = v.kids[k0 + p * 2]
        if _key_copy_ok(v.nodes[key_idx].kind):
            var a0 = starts[p]
            w.write_bytes_range(scratch.buf, a0, starts[p + 1] - a0)
        else:
            _encode_node(v, key_idx, w, options)
        _emit(v, v.kids[k0 + p * 2 + 1], w, options)


def _size_hint(v: CborValue) -> Int:
    var n = len(v.nodes) * 12 + len(v.bytes) + 8
    var tn = len(v.texts)
    for i in range(tn):
        n += v.texts[i].byte_length()
    if n < 64:
        return 64
    return n


def encode_value_into(
    value: CborValue,
    mut w: WireWriter,
    options: EncodeOptions = EncodeOptions.preferred,
) raises DecodeError:
    """Encode `value` onto an existing writer without an intermediate buffer."""
    _emit(value, value.root, w, options)


def encode_value(
    value: CborValue, options: EncodeOptions = EncodeOptions.preferred
) raises DecodeError -> List[Byte]:
    var w = WireWriter(capacity=_size_hint(value), exact=True)
    _emit(value, value.root, w, options)
    return w^.finish()


def node_as_float(v: CborValue, idx: Int) raises DecodeError -> Float64:
    var n = v.nodes[idx]
    if n.kind == CK_INT:
        return Float64(n.a)
    if n.kind == CK_UINT:
        return Float64(n.b)
    if n.kind == CK_FLOAT16:
        return half_to_f64(UInt16(n.b))
    if n.kind == CK_FLOAT32:
        return Float64(f32_from_bits(UInt32(n.b)))
    if n.kind == CK_FLOAT64:
        return f64_from_bits(n.b)
    raise DecodeError(DecodeError.KIND_TYPE, 0)


def decode_strict[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> CborValue:
    var v = decode_value(buf)
    var again = encode_value(v, EncodeOptions.cde)
    assert_cde_roundtrip(buf, again)
    return v^
