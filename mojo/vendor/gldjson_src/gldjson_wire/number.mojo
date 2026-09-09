from std.collections import List, Span

from gldjson_runtime.error import DecodeError
from gldjson_wire.classify import is_digit


struct NumberTok(Copyable, ImplicitlyCopyable):
    var is_int: Bool
    var is_neg: Bool
    var i: Int64
    var f: Float64
    var start: Int
    var end: Int

    def __init__(
        out self,
        is_int: Bool,
        is_neg: Bool,
        i: Int64,
        f: Float64,
        start: Int,
        end: Int,
    ):
        self.is_int = is_int
        self.is_neg = is_neg
        self.i = i
        self.f = f
        self.start = start
        self.end = end


def encoded_int_len(v: Int64) -> Int:
    if v == Int64.MIN:
        return 20
    var n = 0
    var x = v
    if x < Int64(0):
        n = 1
        x = -x
    if x == Int64(0):
        return n + 1
    while x > Int64(0):
        n += 1
        x = x // Int64(10)
    return n


def write_int_digits(mut dest: List[Byte], mut pos: Int, v: Int64):
    if v == Int64(0):
        dest[pos] = Byte(48)
        pos += 1
        return
    if v == Int64.MIN:
        # -9223372036854775808
        var s = String("-9223372036854775808")
        var b = s.as_bytes()
        var i = 0
        while i < len(b):
            dest[pos] = b[i]
            pos += 1
            i += 1
        return
    var mag = v
    if v < Int64(0):
        dest[pos] = Byte(45)
        pos += 1
        mag = -v
    var end = pos
    var x = mag
    while True:
        end += 1
        x = x // Int64(10)
        if x == Int64(0):
            break
    var write = end
    x = mag
    while True:
        write -= 1
        dest[write] = Byte(48 + Int(x % Int64(10)))
        x = x // Int64(10)
        if x == Int64(0):
            break
    pos = end


def encoded_float_len(v: Float64) -> Int:
    if v != v:
        return 0
    var s = _float_text(v)
    return s.byte_length()


def _f64_bits(v: Float64) -> UInt64:
    return UInt64(v.to_bits())


def _is_neg_zero(v: Float64) -> Bool:
    if v != 0.0:
        return False
    return (_f64_bits(v) >> UInt64(63)) == UInt64(1)


def _float_text(v: Float64) -> String:
    if _is_neg_zero(v):
        return String("-0.0")
    var s = String(v)
    # Mojo String(float) is already a decimal. Ensure it is a JSON number.
    if s.byte_length() == 0:
        return String("0")
    return s


def write_float_digits(mut dest: List[Byte], mut pos: Int, v: Float64) raises DecodeError:
    if v != v:
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    var bits = _f64_bits(v)
    var exp = Int((bits >> UInt64(52)) & UInt64(0x7FF))
    if exp == 0x7FF:
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    var s = _float_text(v)
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        dest[pos] = b[i]
        pos += 1
        i += 1


def parse_number[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int) raises DecodeError -> NumberTok:
    var start = pos
    if pos >= len(data):
        raise DecodeError(DecodeError.KIND_EOF, pos)
    var neg = False
    if Int(data[pos]) == 45:
        neg = True
        pos += 1
        if pos >= len(data):
            raise DecodeError(DecodeError.KIND_EOF, pos)
    var c = Int(data[pos])
    if c == 43:
        raise DecodeError(DecodeError.KIND_NUMBER, start)
    if not is_digit(c):
        raise DecodeError(DecodeError.KIND_NUMBER, start)
    if c == 48:
        pos += 1
        if pos < len(data):
            var n = Int(data[pos])
            if is_digit(n):
                raise DecodeError(DecodeError.KIND_NUMBER, start)
    else:
        while pos < len(data) and is_digit(Int(data[pos])):
            pos += 1
    var is_int = True
    if pos < len(data) and Int(data[pos]) == 46:
        is_int = False
        pos += 1
        if pos >= len(data) or not is_digit(Int(data[pos])):
            raise DecodeError(DecodeError.KIND_NUMBER, start)
        while pos < len(data) and is_digit(Int(data[pos])):
            pos += 1
    if pos < len(data) and (Int(data[pos]) == 101 or Int(data[pos]) == 69):
        is_int = False
        pos += 1
        if pos < len(data) and (Int(data[pos]) == 43 or Int(data[pos]) == 45):
            pos += 1
        if pos >= len(data) or not is_digit(Int(data[pos])):
            raise DecodeError(DecodeError.KIND_NUMBER, start)
        while pos < len(data) and is_digit(Int(data[pos])):
            pos += 1
    var tok = NumberTok(
        is_int=is_int,
        is_neg=neg,
        i=Int64(0),
        f=0.0,
        start=start,
        end=pos,
    )
    if is_int:
        var ok = _try_int64(data, start, pos, tok)
        if ok:
            return tok
    tok.is_int = False
    tok.f = _parse_float(data, start, pos, start)
    return tok


def _try_int64[
    origin: ImmOrigin
](data: Span[Byte, origin], start: Int, end: Int, mut tok: NumberTok) -> Bool:
    var i = start
    var neg = False
    if i < end and Int(data[i]) == 45:
        neg = True
        i += 1
    if i >= end:
        return False
    var acc = Int64(0)
    while i < end:
        var d = Int(data[i]) - 48
        if d < 0 or d > 9:
            return False
        if acc > (Int64.MAX - Int64(d)) // Int64(10):
            if neg and acc == (Int64.MAX // Int64(10)) and d == 8:
                # Int64.MIN
                var j = i + 1
                if j == end:
                    tok.i = Int64.MIN
                    tok.is_neg = True
                    return True
            return False
        acc = acc * Int64(10) + Int64(d)
        i += 1
    if neg:
        tok.i = -acc
    else:
        tok.i = acc
    tok.is_neg = neg
    return True


def _parse_float[
    origin: ImmOrigin
](data: Span[Byte, origin], start: Int, end: Int, err_off: Int) raises DecodeError -> Float64:
    var s: String
    try:
        s = String(from_utf8=data[start:end])
    except _:
        raise DecodeError(DecodeError.KIND_UTF8, err_off)
    var v: Float64
    try:
        v = atof(s)
    except _:
        raise DecodeError(DecodeError.KIND_RANGE, err_off)
    if v != v:
        raise DecodeError(DecodeError.KIND_RANGE, err_off)
    var bits = UInt64(v.to_bits())
    var exp = Int((bits >> UInt64(52)) & UInt64(0x7FF))
    if exp == 0x7FF:
        raise DecodeError(DecodeError.KIND_RANGE, err_off)
    return v
