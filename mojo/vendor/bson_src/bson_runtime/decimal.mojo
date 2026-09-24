from std.collections import List

from bson_runtime.error import DecodeError

comptime DEC_BIAS = 6176
comptime DEC_SIGN = UInt64(0x8000000000000000)
comptime DEC_INF = UInt64(0x7800000000000000)
comptime DEC_NAN = UInt64(0x7C00000000000000)
comptime DEC_SNAN = UInt64(0x7E00000000000000)
comptime DEC_EXP_MASK = UInt64(3) << UInt64(61)


struct U128(Copyable, Movable):
    var hi: UInt64
    var lo: UInt64

    def __init__(out self, hi: UInt64 = 0, lo: UInt64 = 0):
        self.hi = hi
        self.lo = lo

    def is_zero(self) -> Bool:
        return self.hi == UInt64(0) and self.lo == UInt64(0)


def _mul10_add(mut x: U128, digit: Int):
    var d = UInt64(digit)
    var lo_lo = (x.lo & UInt64(0xFFFFFFFF)) * UInt64(10)
    var lo_hi = (x.lo >> UInt64(32)) * UInt64(10)
    lo_hi = lo_hi + (lo_lo >> UInt64(32))
    var new_lo = (lo_hi << UInt64(32)) | (lo_lo & UInt64(0xFFFFFFFF))
    var carry = lo_hi >> UInt64(32)
    var hi_lo = (x.hi & UInt64(0xFFFFFFFF)) * UInt64(10) + carry
    var hi_hi = (x.hi >> UInt64(32)) * UInt64(10)
    hi_hi = hi_hi + (hi_lo >> UInt64(32))
    var new_hi = (hi_hi << UInt64(32)) | (hi_lo & UInt64(0xFFFFFFFF))
    var sum = new_lo + d
    if sum < d:
        new_hi = new_hi + UInt64(1)
    x.lo = sum
    x.hi = new_hi


def _divmod10(x: U128) -> Tuple[U128, Int]:
    var rem = UInt64(0)
    var parts = List[UInt64]()
    parts.append(x.hi >> UInt64(32))
    parts.append(x.hi & UInt64(0xFFFFFFFF))
    parts.append(x.lo >> UInt64(32))
    parts.append(x.lo & UInt64(0xFFFFFFFF))
    var outs = List[UInt64]()
    var i = 0
    while i < 4:
        var cur = (rem << UInt64(32)) | parts[i]
        var q = cur // UInt64(10)
        rem = cur % UInt64(10)
        outs.append(q)
        i += 1
    var out = U128((outs[0] << UInt64(32)) | outs[1], (outs[2] << UInt64(32)) | outs[3])
    return (out^, Int(rem))


def _digits(coeff: U128) -> String:
    if coeff.is_zero():
        return "0"
    var tmp = List[Int]()
    var x = coeff.copy()
    while not x.is_zero():
        var step = _divmod10(x)
        x = step[0].copy()
        tmp.append(step[1])
    var s = String()
    var i = len(tmp)
    while i > 0:
        i -= 1
        s += String(chr(48 + tmp[i]))
    return s


def _exp_text(exp: Int) -> String:
    if exp < 0:
        return String(exp)
    return "+" + String(exp)


struct Decimal128(Copyable, Movable):
    """IEEE 754-2008 decimal128 in BID form, stored as BSON's 16 little-endian bytes.

    The bit layout matches pymongo's `_decimal_to_128`: a 14-bit biased exponent
    at bit 49 of the high word, and a coefficient that fits in 113 bits.
    """

    var hi: UInt64
    var lo: UInt64

    def __init__(out self):
        self.hi = UInt64(0)
        self.lo = UInt64(0)

    def __init__(out self, hi: UInt64, lo: UInt64):
        self.hi = hi
        self.lo = lo

    def to_bytes(self) -> List[Byte]:
        var out = List[Byte](unsafe_uninit_length=16)
        var lo = self.lo
        var hi = self.hi
        var i = 0
        while i < 8:
            out[i] = Byte(lo & UInt64(0xFF))
            lo = lo >> UInt64(8)
            i += 1
        while i < 16:
            out[i] = Byte(hi & UInt64(0xFF))
            hi = hi >> UInt64(8)
            i += 1
        return out^

    def is_snan(self) -> Bool:
        return (self.hi & DEC_SNAN) == DEC_SNAN

    def is_nan(self) -> Bool:
        return (self.hi & DEC_NAN) == DEC_NAN

    def is_inf(self) -> Bool:
        return (self.hi & DEC_INF) == DEC_INF


def decimal_from_list(raw: List[Byte]) raises DecodeError -> Decimal128:
    if len(raw) != 16:
        raise DecodeError(DecodeError.KIND_SIZE, 0, len(raw))
    var lo = UInt64(0)
    var hi = UInt64(0)
    var i = 0
    while i < 8:
        lo = lo | (UInt64(raw[i]) << UInt64(8 * i))
        i += 1
    while i < 16:
        hi = hi | (UInt64(raw[i]) << UInt64(8 * (i - 8)))
        i += 1
    return Decimal128(hi, lo)


def _coeff(d: Decimal128) -> U128:
    var mask = (UInt64(1) << UInt64(49)) - UInt64(1)
    return U128(d.hi & mask, d.lo)


def _biased_exp(d: Decimal128) -> Int:
    if (d.hi & DEC_EXP_MASK) == DEC_EXP_MASK:
        return Int((d.hi & UInt64(0x1FFFE00000000000)) >> UInt64(47))
    return Int((d.hi & UInt64(0x7FFF800000000000)) >> UInt64(49))


def decimal_to_string(d: Decimal128) -> String:
    var sign = (d.hi & DEC_SIGN) != UInt64(0)
    var prefix = String()
    if sign:
        prefix = "-"
    if d.is_snan():
        return prefix + "sNaN"
    if d.is_nan():
        return prefix + "NaN"
    if d.is_inf():
        return prefix + "Infinity"
    var exp = _biased_exp(d) - DEC_BIAS
    var digits = _digits(_coeff(d))
    var n = digits.byte_length()
    var left = n + exp
    var body = String()
    if exp <= 0 and left > -6:
        if exp == 0:
            body = digits
        else:
            var point = n + exp
            if point <= 0:
                body = "0."
                var z = -point
                while z > 0:
                    body += "0"
                    z -= 1
                body += digits
            else:
                var raw = digits.as_bytes()
                var i = 0
                while i < point:
                    body += String(chr(Int(raw[i])))
                    i += 1
                body += "."
                while i < n:
                    body += String(chr(Int(raw[i])))
                    i += 1
    else:
        var raw = digits.as_bytes()
        body += String(chr(Int(raw[0])))
        if n > 1:
            body += "."
            var i = 1
            while i < n:
                body += String(chr(Int(raw[i])))
                i += 1
        var adj = exp + n - 1
        body += "E" + _exp_text(adj)
    return prefix + body


def decimal_parse(text: String) raises DecodeError -> Decimal128:
    var s = text
    if s == "NaN" or s == "+NaN":
        return Decimal128(DEC_NAN, 0)
    if s == "-NaN":
        return Decimal128(DEC_NAN | DEC_SIGN, 0)
    if s == "sNaN" or s == "+sNaN":
        return Decimal128(DEC_SNAN, 0)
    if s == "-sNaN":
        return Decimal128(DEC_SNAN | DEC_SIGN, 0)
    if s == "Infinity" or s == "+Infinity" or s == "Inf" or s == "+Inf":
        return Decimal128(DEC_INF, 0)
    if s == "-Infinity" or s == "-Inf":
        return Decimal128(DEC_INF | DEC_SIGN, 0)
    var raw = s.as_bytes()
    var i = 0
    var n = len(raw)
    var neg = False
    if n > 0 and (raw[0] == Byte(ord("+")) or raw[0] == Byte(ord("-"))):
        neg = raw[0] == Byte(ord("-"))
        i = 1
    var coeff = U128()
    var digits = 0
    var places = 0
    var seen_dot = False
    var seen_digit = False
    while i < n:
        var c = raw[i]
        if c == Byte(ord(".")) and not seen_dot:
            seen_dot = True
            i += 1
            continue
        if c == Byte(ord("e")) or c == Byte(ord("E")):
            break
        if c < Byte(ord("0")) or c > Byte(ord("9")):
            raise DecodeError(DecodeError.KIND_SYNTAX, i, Int(c))
        seen_digit = True
        if digits < 34:
            _mul10_add(coeff, Int(c) - 48)
            digits += 1
            if seen_dot:
                places += 1
        else:
            raise DecodeError(DecodeError.KIND_RANGE, i, digits)
        if seen_dot:
            # places counted above only when digits < 34. Keep both in lockstep.
            pass
        i += 1
    if not seen_digit:
        raise DecodeError(DecodeError.KIND_SYNTAX, 0, 0)
    var exp = -places
    if i < n and (raw[i] == Byte(ord("e")) or raw[i] == Byte(ord("E"))):
        i += 1
        var exp_neg = False
        if i < n and (raw[i] == Byte(ord("+")) or raw[i] == Byte(ord("-"))):
            exp_neg = raw[i] == Byte(ord("-"))
            i += 1
        if i >= n:
            raise DecodeError(DecodeError.KIND_SYNTAX, i, 0)
        var ev = 0
        while i < n:
            var c = raw[i]
            if c < Byte(ord("0")) or c > Byte(ord("9")):
                raise DecodeError(DecodeError.KIND_SYNTAX, i, Int(c))
            ev = ev * 10 + (Int(c) - 48)
            i += 1
        if exp_neg:
            ev = -ev
        exp += ev
    if exp < -6176 or exp > 6111:
        raise DecodeError(DecodeError.KIND_RANGE, 0, exp)
    if (coeff.hi >> UInt64(49)) != UInt64(0):
        raise DecodeError(DecodeError.KIND_RANGE, 0, 34)
    var biased = exp + DEC_BIAS
    var hi = (UInt64(biased) << UInt64(49)) | coeff.hi
    if neg:
        hi = hi | DEC_SIGN
    return Decimal128(hi, coeff.lo)
