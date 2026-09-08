from std.collections import List, Span

from cbor_runtime.error import DecodeError
from cbor_runtime.options import EncodeOptions
from cbor_runtime.value import (
    CK_ARRAY,
    CK_BYTES,
    CK_FLOAT16,
    CK_FLOAT32,
    CK_FLOAT64,
    CK_INT,
    CK_TAG,
    CK_TEXT,
    CK_UINT,
    CborValue,
    decode_item,
    decode_value,
    encode_value,
)
from cbor_wire.half import f32_from_bits, f64_from_bits, half_to_f64
from cbor_wire.reader import WireReader
from cbor_wire.writer import WireWriter


struct EpochTime(Copyable, ImplicitlyCopyable, Movable):
    var sec: Float64

    def __init__(out self, sec: Float64 = 0.0):
        self.sec = sec


struct BigUint(Movable):
    var bytes: List[Byte]

    def __init__(out self):
        self.bytes = List[Byte]()

    def __init__(out self, var bytes: List[Byte]):
        self.bytes = bytes^


struct BigNint(Movable):
    var bytes: List[Byte]

    def __init__(out self):
        self.bytes = List[Byte]()

    def __init__(out self, var bytes: List[Byte]):
        self.bytes = bytes^


struct Uri(Copyable, ImplicitlyCopyable, Movable):
    var text: String

    def __init__(out self, text: String = ""):
        self.text = text


struct DecimalFraction(Movable):
    """RFC 8949 tag 4: value = mantissa × 10^exp."""

    var exp: Int64
    var mant: Int64
    var big: List[Byte]
    var big_neg: Bool

    def __init__(out self, exp: Int64 = 0, mant: Int64 = 0):
        self.exp = exp
        self.mant = mant
        self.big = List[Byte]()
        self.big_neg = False

    def __init__(out self, exp: Int64, var big: List[Byte], *, neg: Bool):
        self.exp = exp
        self.mant = Int64(0)
        self.big = big^
        self.big_neg = neg


struct BigFloat(Movable):
    """RFC 8949 tag 5: value = mantissa × 2^exp."""

    var exp: Int64
    var mant: Int64
    var big: List[Byte]
    var big_neg: Bool

    def __init__(out self, exp: Int64 = 0, mant: Int64 = 0):
        self.exp = exp
        self.mant = mant
        self.big = List[Byte]()
        self.big_neg = False

    def __init__(out self, exp: Int64, var big: List[Byte], *, neg: Bool):
        self.exp = exp
        self.mant = Int64(0)
        self.big = big^
        self.big_neg = neg


def _is_digit(b: Byte) -> Bool:
    var c = Int(b)
    return c >= 48 and c <= 57


def rfc3339_ok(text: String) -> Bool:
    var b = text.as_bytes()
    # YYYY-MM-DDThh:mm:ss ...
    if len(b) < 19:
        return False
    for i in range(4):
        if not _is_digit(b[i]):
            return False
    if Int(b[4]) != 45 or Int(b[7]) != 45:
        return False
    for i in range(5, 7):
        if not _is_digit(b[i]):
            return False
    for i in range(8, 10):
        if not _is_digit(b[i]):
            return False
    var t = Int(b[10])
    if t != 84 and t != 116:
        return False
    for i in range(11, 13):
        if not _is_digit(b[i]):
            return False
    if Int(b[13]) != 58 or Int(b[16]) != 58:
        return False
    for i in range(14, 16):
        if not _is_digit(b[i]):
            return False
    for i in range(17, 19):
        if not _is_digit(b[i]):
            return False
    return True


def _as_float(v: CborValue, idx: Int) raises DecodeError -> Float64:
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
    raise DecodeError(DecodeError.KIND_TAG, 0)


def decode_tag0(v: CborValue) raises DecodeError -> String:
    var n = v.nodes[v.root]
    if n.kind != CK_TAG or n.b != UInt64(0):
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var c = v.nodes[n.c]
    if c.kind != CK_TEXT:
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var s = v.texts[Int(c.a)]
    if not rfc3339_ok(s):
        raise DecodeError(DecodeError.KIND_TAG, 0)
    return s


def decode_tag1(v: CborValue) raises DecodeError -> EpochTime:
    var n = v.nodes[v.root]
    if n.kind != CK_TAG or n.b != UInt64(1):
        raise DecodeError(DecodeError.KIND_TAG, 0)
    return EpochTime(_as_float(v, n.c))


def _copy_bstr(v: CborValue, idx: Int) raises DecodeError -> List[Byte]:
    var n = v.nodes[idx]
    if n.kind != CK_BYTES:
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var out = List[Byte]()
    var start = Int(n.a)
    var ln = Int(n.b)
    for i in range(ln):
        out.append(v.bytes[start + i])
    return out^


def decode_tag2(v: CborValue) raises DecodeError -> BigUint:
    var n = v.nodes[v.root]
    if n.kind != CK_TAG or n.b != UInt64(2):
        raise DecodeError(DecodeError.KIND_TAG, 0)
    return BigUint(_copy_bstr(v, n.c))


def decode_tag3(v: CborValue) raises DecodeError -> BigNint:
    var n = v.nodes[v.root]
    if n.kind != CK_TAG or n.b != UInt64(3):
        raise DecodeError(DecodeError.KIND_TAG, 0)
    return BigNint(_copy_bstr(v, n.c))


def decode_tag24(v: CborValue) raises DecodeError -> CborValue:
    var n = v.nodes[v.root]
    if n.kind != CK_TAG or n.b != UInt64(24):
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var raw = _copy_bstr(v, n.c)
    return decode_value(raw)


def decode_tag32(v: CborValue) raises DecodeError -> Uri:
    var n = v.nodes[v.root]
    if n.kind != CK_TAG or n.b != UInt64(32):
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var c = v.nodes[n.c]
    if c.kind != CK_TEXT:
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var s = v.texts[Int(c.a)]
    if s.byte_length() == 0:
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var bb = s.as_bytes()
    for i in range(len(bb)):
        if Int(bb[i]) == 32:
            raise DecodeError(DecodeError.KIND_TAG, 0)
    return Uri(s)


def encode_tag0(text: String) raises DecodeError -> List[Byte]:
    if not rfc3339_ok(text):
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var w = WireWriter()
    w.write_tag(UInt64(0))
    w.write_tstr(text)
    return w^.finish()


def encode_tag1(t: EpochTime) -> List[Byte]:
    var w = WireWriter()
    w.write_tag(UInt64(1))
    var as_int = Int64(t.sec)
    if Float64(as_int) == t.sec:
        w.write_int(as_int)
    else:
        w.write_float_preferred(t.sec)
    return w^.finish()


def encode_tag2(b: BigUint) -> List[Byte]:
    var w = WireWriter()
    w.write_tag(UInt64(2))
    w.write_bstr(b.bytes)
    return w^.finish()


def encode_tag3(b: BigNint) -> List[Byte]:
    var w = WireWriter()
    w.write_tag(UInt64(3))
    w.write_bstr(b.bytes)
    return w^.finish()


def encode_tag24(inner: CborValue, options: EncodeOptions = EncodeOptions.preferred) raises DecodeError -> List[Byte]:
    var payload = encode_value(inner, options)
    var w = WireWriter()
    w.write_tag(UInt64(24))
    w.write_bstr(payload)
    return w^.finish()


def encode_tag32(u: Uri) raises DecodeError -> List[Byte]:
    if u.text.byte_length() == 0:
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var w = WireWriter()
    w.write_tag(UInt64(32))
    w.write_tstr(u.text)
    return w^.finish()


def _node_int64(v: CborValue, idx: Int) raises DecodeError -> Int64:
    var n = v.nodes[idx]
    if n.kind == CK_INT:
        return n.a
    if n.kind == CK_UINT:
        if n.b > UInt64(Int64.MAX):
            raise DecodeError(DecodeError.KIND_RANGE, 0)
        return Int64(n.b)
    raise DecodeError(DecodeError.KIND_TAG, 0)


def _decode_scaled(v: CborValue, want_tag: UInt64) raises DecodeError -> Tuple[Int64, Int64, List[Byte], Bool]:
    var n = v.nodes[v.root]
    if n.kind != CK_TAG or n.b != want_tag:
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var arr = v.nodes[n.c]
    if arr.kind != CK_ARRAY or Int(arr.b) != 2:
        raise DecodeError(DecodeError.KIND_TAG, 0)
    var a0 = Int(arr.a)
    var exp_idx = v.kids[a0]
    var mant_idx = v.kids[a0 + 1]
    var exp = _node_int64(v, exp_idx)
    var mn = v.nodes[mant_idx]
    if mn.kind == CK_INT or mn.kind == CK_UINT:
        return (exp, _node_int64(v, mant_idx), List[Byte](), False)
    if mn.kind == CK_TAG and (mn.b == UInt64(2) or mn.b == UInt64(3)):
        var raw = _copy_bstr(v, mn.c)
        return (exp, Int64(0), raw^, mn.b == UInt64(3))
    raise DecodeError(DecodeError.KIND_TAG, 0)


def decode_tag4(v: CborValue) raises DecodeError -> DecimalFraction:
    var t = _decode_scaled(v, UInt64(4))
    if len(t[2]) == 0:
        return DecimalFraction(t[0], t[1])
    var big4 = List[Byte]()
    for i in range(len(t[2])):
        big4.append(t[2][i])
    return DecimalFraction(t[0], big4^, neg=t[3])


def decode_tag5(v: CborValue) raises DecodeError -> BigFloat:
    var t = _decode_scaled(v, UInt64(5))
    if len(t[2]) == 0:
        return BigFloat(t[0], t[1])
    var big5 = List[Byte]()
    for i in range(len(t[2])):
        big5.append(t[2][i])
    return BigFloat(t[0], big5^, neg=t[3])


def _encode_scaled(tag: UInt64, exp: Int64, mant: Int64, big: List[Byte], big_neg: Bool) -> List[Byte]:
    var w = WireWriter()
    w.write_tag(tag)
    w.write_array_len(2)
    w.write_int(exp)
    if len(big) == 0:
        w.write_int(mant)
    else:
        if big_neg:
            w.write_tag(UInt64(3))
        else:
            w.write_tag(UInt64(2))
        w.write_bstr(big)
    return w^.finish()


def encode_tag4(d: DecimalFraction) -> List[Byte]:
    return _encode_scaled(UInt64(4), d.exp, d.mant, d.big, d.big_neg)


def encode_tag5(d: BigFloat) -> List[Byte]:
    return _encode_scaled(UInt64(5), d.exp, d.mant, d.big, d.big_neg)
