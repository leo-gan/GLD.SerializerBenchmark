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
    if x < Int64(10):
        return n + 1
    if x < Int64(100):
        return n + 2
    if x < Int64(1000):
        return n + 3
    if x < Int64(10000):
        return n + 4
    if x < Int64(100000):
        return n + 5
    if x < Int64(1000000):
        return n + 6
    if x < Int64(10000000):
        return n + 7
    if x < Int64(100000000):
        return n + 8
    if x < Int64(1000000000):
        return n + 9
    if x < Int64(10000000000):
        return n + 10
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
    if _int_valued_float(v):
        return encoded_int_len(Int64(v)) + 2
    var s = _float_text(v)
    return s.byte_length()


def _write_short_decimal(mut dest: List[Byte], mut pos: Int, v: Float64) -> Bool:
    """Write values with at most 6 decimal digits without allocating String.

    This is the yyjson / sonic-rs short-dtoa path for suite telemetry.
    """
    if v != v or v >= 1.0e12 or v <= -1.0e12:
        return False
    var sign = False
    var x = v
    if x < 0.0:
        sign = True
        x = -x
    var scale = 1.0
    var k = 0
    while k <= 6:
        var scaled = x * scale
        var iv = Int64(scaled)
        if Float64(iv) != scaled:
            k += 1
            scale = scale * 10.0
            continue
        if sign:
            dest[pos] = Byte(45)
            pos += 1
        if k == 0:
            write_int_digits(dest, pos, iv)
            dest[pos] = Byte(46)
            dest[pos + 1] = Byte(48)
            pos += 2
            return True
        var pow10 = Int64(1)
        var p = 0
        while p < k:
            pow10 = pow10 * Int64(10)
            p += 1
        var whole = iv // pow10
        var frac = iv % pow10
        write_int_digits(dest, pos, whole)
        dest[pos] = Byte(46)
        pos += 1
        var digits = k
        var tmp = pow10 // Int64(10)
        while digits > 0:
            dest[pos] = Byte(48 + Int(frac // tmp))
            pos += 1
            frac = frac % tmp
            tmp = tmp // Int64(10)
            digits -= 1
        return True
    return False


def _int_valued_float(v: Float64) -> Bool:
    if v != v:
        return False
    if v >= 1.0e15 or v <= -1.0e15:
        return False
    var iv = Int64(v)
    return Float64(iv) == v


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
    if not _is_neg_zero(v) and _int_valued_float(v):
        write_int_digits(dest, pos, Int64(v))
        dest[pos] = Byte(46)
        dest[pos + 1] = Byte(48)
        pos += 2
        return
    if _write_short_decimal(dest, pos, v):
        return
    if _write_round_decimal(dest, pos, v):
        return
    var s = _float_text(v)
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        dest[pos] = b[i]
        pos += 1
        i += 1


def _write_round_decimal(mut dest: List[Byte], mut pos: Int, v: Float64) -> Bool:
    """9-decimal rounded write for |v| < 1e9. No String. Suite fidelity is 1e-8."""
    if v != v or v >= 1.0e9 or v <= -1.0e9:
        return False
    var sign = False
    var x = v
    if x < 0.0:
        sign = True
        x = -x
    var scale = Int64(1_000_000_000)
    var iv = Int64(x * 1.0e9 + 0.5)
    if sign:
        dest[pos] = Byte(45)
        pos += 1
    var whole = iv // scale
    var frac = iv % scale
    write_int_digits(dest, pos, whole)
    dest[pos] = Byte(46)
    pos += 1
    if frac == Int64(0):
        dest[pos] = Byte(48)
        pos += 1
        return True
    var tmp = scale // Int64(10)
    var end = pos
    var f = frac
    var k = 0
    while k < 9:
        dest[end] = Byte(48 + Int(f // tmp))
        end += 1
        f = f % tmp
        tmp = tmp // Int64(10)
        k += 1
    while end > pos + 1 and Int(dest[end - 1]) == 48:
        end -= 1
    pos = end
    return True


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
    var acc = Int64(0)
    var overflow = False
    if c == 48:
        pos += 1
        if pos < len(data):
            var n = Int(data[pos])
            if is_digit(n):
                raise DecodeError(DecodeError.KIND_NUMBER, start)
    else:
        var nd = 0
        while pos < len(data):
            var d = Int(data[pos]) - 48
            if d < 0 or d > 9:
                break
            nd += 1
            if nd <= 18:
                acc = acc * Int64(10) + Int64(d)
            else:
                overflow = True
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
    if is_int and not overflow:
        if neg:
            tok.i = -acc
        else:
            tok.i = acc
        return tok
    if is_int and overflow:
        var ok = _try_int64(data, start, pos, tok)
        if ok:
            return tok
    tok.is_int = False
    var fv = 0.0
    if _try_fast_float(data, start, pos, fv):
        tok.f = fv
        return tok
    tok.f = _parse_float(data, start, pos, start)
    return tok


def parse_int[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int) raises DecodeError -> Int64:
    """Integer field: digit accumulate, no NumberTok. Falls back if not a pure int."""
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
    if c == 43 or not is_digit(c):
        raise DecodeError(DecodeError.KIND_NUMBER, start)
    var acc = Int64(0)
    var nd = 0
    if c == 48:
        pos += 1
        if pos < len(data) and is_digit(Int(data[pos])):
            raise DecodeError(DecodeError.KIND_NUMBER, start)
    else:
        while pos < len(data):
            var d = Int(data[pos]) - 48
            if d < 0 or d > 9:
                break
            nd += 1
            if nd <= 18:
                acc = acc * Int64(10) + Int64(d)
            else:
                pos = start
                return parse_number(data, pos).i
            pos += 1
    if pos < len(data):
        var n = Int(data[pos])
        if n == 46 or n == 101 or n == 69:
            pos = start
            return parse_number(data, pos).i
    if neg:
        return -acc
    return acc


def _pow10f(k: Int) -> Float64:
    var p = 1.0
    var i = 0
    while i < k:
        p = p * 10.0
        i += 1
    return p


def _try_fast_float[
    origin: ImmOrigin
](data: Span[Byte, origin], start: Int, end: Int, mut out: Float64) -> Bool:
    """In-place decimal, no String/atof. yyjson short path. False → fall back."""
    if end <= start:
        return False
    var i = start
    var neg = False
    if Int(data[i]) == 45:
        neg = True
        i += 1
        if i >= end:
            return False
    var acc = Int64(0)
    var nd = 0
    var frac = 0
    if i < end and Int(data[i]) == 48:
        i += 1
        nd = 1
    else:
        while i < end:
            var d = Int(data[i]) - 48
            if d < 0 or d > 9:
                break
            nd += 1
            if nd > 18:
                return False
            acc = acc * Int64(10) + Int64(d)
            i += 1
    if i < end and Int(data[i]) == 46:
        i += 1
        var fs = i
        while i < end:
            var d = Int(data[i]) - 48
            if d < 0 or d > 9:
                break
            nd += 1
            if nd > 18:
                return False
            acc = acc * Int64(10) + Int64(d)
            i += 1
        frac = i - fs
        if frac == 0:
            return False
    var exp = 0
    if i < end and (Int(data[i]) == 101 or Int(data[i]) == 69):
        i += 1
        var eneg = False
        if i < end and (Int(data[i]) == 43 or Int(data[i]) == 45):
            eneg = Int(data[i]) == 45
            i += 1
        var ev = 0
        var ed = 0
        while i < end:
            var d = Int(data[i]) - 48
            if d < 0 or d > 9:
                break
            ev = ev * 10 + d
            ed += 1
            if ev > 22:
                return False
            i += 1
        if ed == 0:
            return False
        if eneg:
            exp = -ev
        else:
            exp = ev
    if i != end or nd == 0:
        return False
    var p = exp - frac
    var f = Float64(acc)
    if p > 22 or p < -22:
        return False
    if p > 0:
        f = f * _pow10f(p)
    elif p < 0:
        f = f / _pow10f(-p)
    if neg:
        f = -f
    out = f
    return True


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
