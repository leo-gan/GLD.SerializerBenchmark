from std.collections import List

from smile_runtime.error import DecodeError


def _mul_add(mut limbs: List[Int], digit: Int):
    var carry = digit
    var i = 0
    while i < len(limbs):
        var v = limbs[i] * 10 + carry
        limbs[i] = v & 0xFF
        carry = v >> 8
        i += 1
    while carry > 0:
        limbs.append(carry & 0xFF)
        carry = carry >> 8


def _trim(mut be: List[Int]):
    while len(be) > 1 and be[0] == 0:
        var next = List[Int]()
        var i = 1
        while i < len(be):
            next.append(be[i])
            i += 1
        be = next^


def dec_to_tc(text: String) raises DecodeError -> List[Byte]:
    """Two's-complement big-endian bytes, the same shape Java `BigInteger.toByteArray` uses."""
    var raw = text.as_bytes()
    var i = 0
    var neg = False
    if len(raw) > 0 and Int(raw[0]) == 45:
        neg = True
        i = 1
    if i >= len(raw):
        raise DecodeError(DecodeError.KIND_SYNTAX, 0)
    var limbs = List[Int]()
    while i < len(raw):
        var c = Int(raw[i])
        if c < 48 or c > 57:
            raise DecodeError(DecodeError.KIND_SYNTAX, i)
        _mul_add(limbs, c - 48)
        i += 1
    if len(limbs) == 0:
        limbs.append(0)
    var nonzero = False
    var k = 0
    while k < len(limbs):
        if limbs[k] != 0:
            nonzero = True
        k += 1
    if not nonzero:
        var z = List[Byte]()
        z.append(Byte(0))
        return z^
    if neg:
        var carry = 1
        k = 0
        while k < len(limbs):
            var v = (limbs[k] ^ 0xFF) + carry
            limbs[k] = v & 0xFF
            carry = v >> 8
            k += 1
        if carry != 0:
            limbs.append(0xFF)
    var be = List[Int]()
    k = len(limbs) - 1
    while k >= 0:
        be.append(limbs[k])
        k -= 1
    if (not neg) and (be[0] & 0x80) != 0:
        var padded = List[Int]()
        padded.append(0)
        k = 0
        while k < len(be):
            padded.append(be[k])
            k += 1
        be = padded^
    if neg and (be[0] & 0x80) == 0:
        var padded = List[Int]()
        padded.append(0xFF)
        k = 0
        while k < len(be):
            padded.append(be[k])
            k += 1
        be = padded^
    var out = List[Byte]()
    k = 0
    while k < len(be):
        out.append(Byte(be[k]))
        k += 1
    return out^


def tc_to_dec(raw: List[Byte]) raises DecodeError -> String:
    if len(raw) == 0:
        return String("0")
    var neg = Int(raw[0]) >= 128
    var limbs = List[Int]()
    var i = len(raw) - 1
    while i >= 0:
        limbs.append(Int(raw[i]))
        i -= 1
    if neg:
        var carry = 1
        i = 0
        while i < len(limbs):
            var v = (limbs[i] ^ 0xFF) + carry
            limbs[i] = v & 0xFF
            carry = v >> 8
            i += 1
    var digits = List[Int]()
    var guard = 0
    while True:
        var all_zero = True
        i = 0
        while i < len(limbs):
            if limbs[i] != 0:
                all_zero = False
            i += 1
        if all_zero:
            break
        var rem = 0
        i = len(limbs) - 1
        while i >= 0:
            var cur = (rem << 8) | limbs[i]
            limbs[i] = cur // 10
            rem = cur % 10
            i -= 1
        digits.append(rem)
        guard += 1
        if guard > len(raw) * 4 + 8:
            raise DecodeError(DecodeError.KIND_RANGE, 0)
    if len(digits) == 0:
        return String("0")
    var out = String()
    if neg:
        out = "-"
    i = len(digits) - 1
    while i >= 0:
        out = out + chr(48 + digits[i])
        i -= 1
    return out


def format_decimal(scale: Int, raw: List[Byte]) raises DecodeError -> String:
    """Java `BigDecimal.toString` for the scale and unscaled integer Smile stores."""
    var digits = tc_to_dec(raw)
    var neg = False
    var body = digits
    var db = digits.as_bytes()
    if len(db) > 0 and Int(db[0]) == 45:
        neg = True
        body = String()
        var i = 1
        while i < len(db):
            body = body + chr(Int(db[i]))
            i += 1
    if body == "0" and scale == 0:
        return String("0")
    var sign = String()
    if neg:
        sign = "-"
    if scale == 0:
        return sign + body
    if scale < 0:
        var exp = String(-scale)
        return sign + body + "E+" + exp
    var bb = body.as_bytes()
    var n = len(bb)
    if scale >= n:
        var zeros = String()
        var z = 0
        while z < scale - n:
            zeros = zeros + "0"
            z += 1
        var frac = String()
        var i = 0
        while i < n:
            frac = frac + chr(Int(bb[i]))
            i += 1
        return sign + "0." + zeros + frac
    var ip = String()
    var i = 0
    while i < n - scale:
        ip = ip + chr(Int(bb[i]))
        i += 1
    var fp = String()
    while i < n:
        fp = fp + chr(Int(bb[i]))
        i += 1
    return sign + ip + "." + fp


def parse_decimal(text: String) raises DecodeError -> List[Byte]:
    """Return `scale` in the first caller-visible way: this returns only the unscaled bytes.

    Use `parse_decimal_scale` for the scale. Both share `parse_decimal_parts`.
    """
    var parts = _split_decimal(text)
    return dec_to_tc(parts[0])


def parse_decimal_scale(text: String) raises DecodeError -> Int:
    var parts = _split_decimal(text)
    var raw = parts[1].as_bytes()
    var n = 0
    var neg = False
    var i = 0
    if len(raw) > 0 and Int(raw[0]) == 45:
        neg = True
        i = 1
    while i < len(raw):
        var c = Int(raw[i])
        if c < 48 or c > 57:
            raise DecodeError(DecodeError.KIND_SYNTAX, i)
        n = n * 10 + (c - 48)
        i += 1
    if neg:
        return -n
    return n


def _split_decimal(text: String) raises DecodeError -> List[String]:
    """Return unscaled decimal text and a decimal scale, as two strings."""
    var raw = text.as_bytes()
    var i = 0
    var neg = False
    if len(raw) > 0 and Int(raw[0]) == 45:
        neg = True
        i = 1
    var int_part = String()
    var frac = String()
    var exp = 0
    var exp_neg = False
    var saw_dot = False
    var saw_exp = False
    while i < len(raw):
        var c = Int(raw[i])
        if c == 46 and not saw_dot and not saw_exp:
            saw_dot = True
            i += 1
            continue
        if (c == 69 or c == 101) and not saw_exp:
            saw_exp = True
            i += 1
            if i < len(raw) and (Int(raw[i]) == 43 or Int(raw[i]) == 45):
                exp_neg = Int(raw[i]) == 45
                i += 1
            continue
        if c < 48 or c > 57:
            raise DecodeError(DecodeError.KIND_SYNTAX, i)
        if saw_exp:
            exp = exp * 10 + (c - 48)
        elif saw_dot:
            frac = frac + chr(c)
        else:
            int_part = int_part + chr(c)
        i += 1
    if exp_neg:
        exp = -exp
    var fb = frac.as_bytes()
    var scale = len(fb) - exp
    var digits = int_part + frac
    if digits.byte_length() == 0:
        digits = String("0")
    if neg:
        digits = "-" + digits
    var scale_txt = String(scale)
    var out = List[String]()
    out.append(digits)
    out.append(scale_txt)
    return out^
