from std.collections import List, Span
from std.memory import unsafe_memcpy

from cbor_runtime.cde import assert_cde_roundtrip, encoded_eq, sort_by_encoded_keys
from cbor_runtime.error import DecodeError
from cbor_runtime.options import EncodeOptions
from cbor_wire.half import f32_from_bits, f64_from_bits, f64_to_bits, half_to_f64
from cbor_wire.head import AI_INDEF, MAX_ITEM_BYTES
from cbor_wire.reader import WireReader
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
](mut r: WireReader[origin], mut v: CborValue) raises DecodeError -> Int:
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
            # validate concatenated UTF-8
            var tmp = List[Byte](capacity=span_n)
            for i in range(span_n):
                tmp.append(v.bytes[span_start + i])
            # reuse reader helper via a throwaway WireReader on tmp
            var tr = WireReader(tmp)
            var s = tr.read_text_exact(span_n)
            var tidx = len(v.texts)
            v.texts.append(s^)
            idx = v.add(
                CborNode(CK_TEXT, a=Int64(tidx), b=UInt64(span_n), flags=FLAG_INDEF)
            )
        else:
            var n2 = Int(arg)
            var s2 = r.read_text_exact(n2)
            var tidx2 = len(v.texts)
            v.texts.append(s2^)
            idx = v.add(CborNode(CK_TEXT, a=Int64(tidx2), b=UInt64(n2)))
    elif major == 4:
        var kstart = len(v.kids)
        var count = 0
        var flags = 0
        if ai == AI_INDEF:
            flags = FLAG_INDEF
            while True:
                if r.read_break_or_item():
                    break
                var child = decode_item(r, v)
                v.kids.append(child)
                count += 1
        else:
            r.check_count(arg)
            count = Int(arg)
            for _i in range(count):
                var child2 = decode_item(r, v)
                v.kids.append(child2)
        idx = v.add(CborNode(CK_ARRAY, a=Int64(kstart), b=UInt64(count), flags=flags))
    elif major == 5:
        var mstart = len(v.kids)
        var pairs = 0
        var mflags = 0
        if ai == AI_INDEF:
            mflags = FLAG_INDEF
            while True:
                if r.read_break_or_item():
                    break
                var key = decode_item(r, v)
                if r.read_break_or_item():
                    raise DecodeError(DecodeError.KIND_MAP_PAIR, r.position())
                var val = decode_item(r, v)
                v.kids.append(key)
                v.kids.append(val)
                pairs += 1
        else:
            r.check_count(arg)
            pairs = Int(arg)
            for _j in range(pairs):
                var key2 = decode_item(r, v)
                var val2 = decode_item(r, v)
                v.kids.append(key2)
                v.kids.append(val2)
        idx = v.add(CborNode(CK_MAP, a=Int64(mstart), b=UInt64(pairs), flags=mflags))
    elif major == 6:
        var child3 = decode_item(r, v)
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


def decode_value[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> CborValue:
    var r = WireReader(buf)
    var v = CborValue()
    v.root = decode_item(r, v)
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


def _encode_node(v: CborValue, idx: Int, mut w: WireWriter, options: EncodeOptions) raises DecodeError:
    var n = v.nodes[idx]
    var ident = options.is_identity()
    var dcbor = options.is_dcbor()
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
        var t = v.texts[Int(n.a)]
        if ident and (n.flags & FLAG_INDEF) != 0:
            var b = t.as_bytes()
            w.write_head_raw(3, AI_INDEF, UInt64(0))
            w.write_head(3, UInt64(len(b)))
            w.write_bytes(b)
            w.write_break()
        else:
            w.write_tstr(t)
    elif n.kind == CK_ARRAY:
        var count = Int(n.b)
        var k0 = Int(n.a)
        if ident and (n.flags & FLAG_INDEF) != 0:
            w.write_head_raw(4, AI_INDEF, UInt64(0))
            for i in range(count):
                _encode_node(v, v.kids[k0 + i], w, options)
            w.write_break()
        else:
            w.write_array_len(count)
            for i in range(count):
                _encode_node(v, v.kids[k0 + i], w, options)
    elif n.kind == CK_MAP:
        _encode_map(v, idx, w, options)
    elif n.kind == CK_TAG:
        w.write_tag(n.b)
        _encode_node(v, n.c, w, options)
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


def _key_bytes(v: CborValue, key_idx: Int) raises DecodeError -> List[Byte]:
    var w = WireWriter()
    _encode_node(v, key_idx, w, EncodeOptions.preferred)
    return w^.finish()


def _encode_map(
    v: CborValue, idx: Int, mut w: WireWriter, options: EncodeOptions
) raises DecodeError:
    var n = v.nodes[idx]
    var pairs = Int(n.b)
    var k0 = Int(n.a)
    var ident = options.is_identity()
    var dcbor = options.is_dcbor()
    if ident and (n.flags & FLAG_INDEF) != 0:
        w.write_head_raw(5, AI_INDEF, UInt64(0))
        for i in range(pairs):
            _encode_node(v, v.kids[k0 + i * 2], w, options)
            _encode_node(v, v.kids[k0 + i * 2 + 1], w, options)
        w.write_break()
        return
    var keys = List[List[Byte]]()
    for i in range(pairs):
        if dcbor:
            if v.nodes[v.kids[k0 + i * 2]].kind != CK_TEXT:
                raise DecodeError(DecodeError.KIND_CDE, 0)
        keys.append(_key_bytes(v, v.kids[k0 + i * 2]))
    var order = List[Int]()
    if options.is_cde() or dcbor:
        order = sort_by_encoded_keys(keys)
    else:
        for i in range(pairs):
            order.append(i)
    if pairs > 1:
        for i in range(1, pairs):
            if encoded_eq(keys[order[i - 1]], keys[order[i]]):
                raise DecodeError(DecodeError.KIND_DUP_KEY, 0)
    w.write_map_len(pairs)
    for i in range(pairs):
        var p = order[i]
        _encode_node(v, v.kids[k0 + p * 2], w, options)
        _encode_node(v, v.kids[k0 + p * 2 + 1], w, options)


def encode_value(
    value: CborValue, options: EncodeOptions = EncodeOptions.preferred
) raises DecodeError -> List[Byte]:
    var w = WireWriter()
    _encode_node(value, value.root, w, options)
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
