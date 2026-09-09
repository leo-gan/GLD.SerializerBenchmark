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
    """yyjson two-digit write. `encoded_int_len` already counted digits."""
    var n = encoded_int_len(v)
    write_int_known(dest, pos, v, n)


comptime _DIGIT_PAIRS = "00010203040506070809101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899"


def write_int_known(mut dest: List[Byte], mut pos: Int, v: Int64, n: Int):
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
    var start = pos
    var mag = v
    if v < Int64(0):
        dest[pos] = Byte(45)
        mag = -v
    var write = start + n
    var x = mag
    var pairs = _DIGIT_PAIRS.as_bytes()
    while x >= Int64(100):
        var r = Int(x % Int64(100))
        write -= 2
        dest[write] = pairs[r * 2]
        dest[write + 1] = pairs[r * 2 + 1]
        x = x // Int64(100)
    write -= 1
    dest[write] = Byte(48 + Int(x % Int64(10)))
    if x >= Int64(10):
        write -= 1
        dest[write] = Byte(48 + Int(x // Int64(10)))
    pos = start + n


def _is_eight_digits(w: UInt64) -> Bool:
    """EmberJson / simdjson: all 8 bytes are ASCII digits. Needs 8 readable bytes."""
    return (
        (w & UInt64(0xF0F0F0F0F0F0F0F0))
        | (((w + UInt64(0x0606060606060606)) & UInt64(0xF0F0F0F0F0F0F0F0)) >> UInt64(4))
    ) == UInt64(0x3333333333333333)


def _parse_eight_digits(w: UInt64) -> UInt64:
    """sonic-cpp / EmberJson SWAR 8-digit accumulate."""
    var val = w
    val = (val & UInt64(0x0F0F0F0F0F0F0F0F)) * UInt64(2561) >> UInt64(8)
    val = (val & UInt64(0x00FF00FF00FF00FF)) * UInt64(6553601) >> UInt64(16)
    val = (val & UInt64(0x0000FFFF0000FFFF)) * UInt64(42949672960001) >> UInt64(32)
    return val


def _load_u64_at[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) -> UInt64:
    return data.unsafe_ptr().unsafe_offset(pos).unsafe_bitcast[UInt64]()[]


def _load_u32_at[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) -> UInt32:
    return data.unsafe_ptr().unsafe_offset(pos).unsafe_bitcast[UInt32]()[]


def _is_four_digits(w: UInt32) -> Bool:
    """Same 8-digit SWAR test, 4-byte lane. Needs 4 readable bytes."""
    return (
        (w & UInt32(0xF0F0F0F0))
        | (((w + UInt32(0x06060606)) & UInt32(0xF0F0F0F0)) >> UInt32(4))
    ) == UInt32(0x33333333)


def _parse_four_digits(w: UInt32) -> UInt64:
    """4-digit SWAR. Multiplies stay in UInt64; UInt32 overflows on 9999."""
    var v = UInt64(w & UInt32(0x0F0F0F0F))
    v = (v * UInt64(2561)) >> UInt64(8)
    v = (v & UInt64(0x00FF00FF)) * UInt64(6553601) >> UInt64(16)
    return v & UInt64(0xFFFF)


def encoded_float_len(v: Float64) -> Int:
    if v != v:
        return 0
    if _int_valued_float(v):
        return encoded_int_len(Int64(v)) + 2
    # Over-estimate. String(v) used to allocate on every size pass.
    return 24


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
    # Skip _write_short_decimal: 7 exact-scale probes never hit random suite floats.
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
    # yyjson/ember digit-pair write of the 9-digit fraction, then strip zeros.
    var start_f = pos
    var write = start_f + 9
    var fx = frac
    var pairs = _DIGIT_PAIRS.as_bytes()
    while write > start_f + 1:
        var r = Int(fx % Int64(100))
        write -= 2
        dest[write] = pairs[r * 2]
        dest[write + 1] = pairs[r * 2 + 1]
        fx = fx // Int64(100)
    dest[start_f] = Byte(48 + Int(fx))
    var end = start_f + 9
    while end > start_f + 1 and Int(dest[end - 1]) == 48:
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
    var nd = 0
    if c == 48:
        pos += 1
        nd = 1
        if pos < len(data):
            var n = Int(data[pos])
            if is_digit(n):
                raise DecodeError(DecodeError.KIND_NUMBER, start)
    else:
        while pos + 8 <= len(data):
            var w = _load_u64_at(data, pos)
            if not _is_eight_digits(w):
                break
            nd += 8
            if nd <= 18:
                acc = acc * Int64(100000000) + Int64(_parse_eight_digits(w))
            else:
                overflow = True
            pos += 8
        while pos + 4 <= len(data):
            var w4 = _load_u32_at(data, pos)
            if not _is_four_digits(w4):
                break
            nd += 4
            if nd <= 18:
                acc = acc * Int64(10000) + Int64(_parse_four_digits(w4))
            else:
                overflow = True
            pos += 4
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
    var frac = 0
    var exp = 0
    if pos < len(data) and Int(data[pos]) == 46:
        is_int = False
        pos += 1
        if pos >= len(data) or not is_digit(Int(data[pos])):
            raise DecodeError(DecodeError.KIND_NUMBER, start)
        var fs = pos
        while pos + 8 <= len(data):
            var w = _load_u64_at(data, pos)
            if not _is_eight_digits(w):
                break
            nd += 8
            if nd <= 18:
                acc = acc * Int64(100000000) + Int64(_parse_eight_digits(w))
            else:
                overflow = True
            pos += 8
        while pos + 4 <= len(data):
            var w4 = _load_u32_at(data, pos)
            if not _is_four_digits(w4):
                break
            nd += 4
            if nd <= 18:
                acc = acc * Int64(10000) + Int64(_parse_four_digits(w4))
            else:
                overflow = True
            pos += 4
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
        frac = pos - fs
    if pos < len(data) and (Int(data[pos]) == 101 or Int(data[pos]) == 69):
        is_int = False
        pos += 1
        var eneg = False
        if pos < len(data) and (Int(data[pos]) == 43 or Int(data[pos]) == 45):
            eneg = Int(data[pos]) == 45
            pos += 1
        if pos >= len(data) or not is_digit(Int(data[pos])):
            raise DecodeError(DecodeError.KIND_NUMBER, start)
        var ev = 0
        var ed = 0
        while pos < len(data):
            var d = Int(data[pos]) - 48
            if d < 0 or d > 9:
                break
            ev = ev * 10 + d
            ed += 1
            pos += 1
        if ed == 0:
            raise DecodeError(DecodeError.KIND_NUMBER, start)
        if eneg:
            exp = -ev
        else:
            exp = ev
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
    if not overflow and nd > 0:
        var p = exp - frac
        if p >= -22 and p <= 22:
            var f = Float64(acc)
            if p > 0:
                f = f * _pow10f(p)
            elif p < 0:
                f = f / _pow10f(-p)
            if neg:
                f = -f
            tok.f = f
            return tok
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
        while pos + 8 <= len(data):
            var w = _load_u64_at(data, pos)
            if not _is_eight_digits(w):
                break
            nd += 8
            if nd <= 18:
                acc = acc * Int64(100000000) + Int64(_parse_eight_digits(w))
            else:
                pos = start
                return parse_number(data, pos).i
            pos += 8
        while pos + 4 <= len(data):
            var w4 = _load_u32_at(data, pos)
            if not _is_four_digits(w4):
                break
            nd += 4
            if nd <= 18:
                acc = acc * Int64(10000) + Int64(_parse_four_digits(w4))
            else:
                pos = start
                return parse_number(data, pos).i
            pos += 4
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
    """EmberJson POWER_OF_TEN values. If-chain: InlineArray needs materialize."""
    if k == 0:
        return 1.0
    if k == 1:
        return 10.0
    if k == 2:
        return 100.0
    if k == 3:
        return 1000.0
    if k == 4:
        return 10000.0
    if k == 5:
        return 100000.0
    if k == 6:
        return 1000000.0
    if k == 7:
        return 10000000.0
    if k == 8:
        return 100000000.0
    if k == 9:
        return 1000000000.0
    if k == 10:
        return 1.0e10
    if k == 11:
        return 1.0e11
    if k == 12:
        return 1.0e12
    if k == 13:
        return 1.0e13
    if k == 14:
        return 1.0e14
    if k == 15:
        return 1.0e15
    if k == 16:
        return 1.0e16
    if k == 17:
        return 1.0e17
    if k == 18:
        return 1.0e18
    if k == 19:
        return 1.0e19
    if k == 20:
        return 1.0e20
    if k == 21:
        return 1.0e21
    if k == 22:
        return 1.0e22
    return 1.0


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
        while i + 8 <= end:
            var w = _load_u64_at(data, i)
            if not _is_eight_digits(w):
                break
            nd += 8
            if nd > 18:
                return False
            acc = acc * Int64(100000000) + Int64(_parse_eight_digits(w))
            i += 8
        while i + 4 <= end:
            var w4 = _load_u32_at(data, i)
            if not _is_four_digits(w4):
                break
            nd += 4
            if nd > 18:
                return False
            acc = acc * Int64(10000) + Int64(_parse_four_digits(w4))
            i += 4
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
        while i + 8 <= end:
            var w = _load_u64_at(data, i)
            if not _is_eight_digits(w):
                break
            nd += 8
            if nd > 18:
                return False
            acc = acc * Int64(100000000) + Int64(_parse_eight_digits(w))
            i += 8
        while i + 4 <= end:
            var w4 = _load_u32_at(data, i)
            if not _is_four_digits(w4):
                break
            nd += 4
            if nd > 18:
                return False
            acc = acc * Int64(10000) + Int64(_parse_four_digits(w4))
            i += 4
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
