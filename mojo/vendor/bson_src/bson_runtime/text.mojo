from std.collections import List

from bson_runtime.error import DecodeError

comptime _B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
comptime _HEX = "0123456789abcdef"


def _b64_val(c: Int) raises DecodeError -> Int:
    if c >= 65 and c <= 90:
        return c - 65
    if c >= 97 and c <= 122:
        return c - 97 + 26
    if c >= 48 and c <= 57:
        return c - 48 + 52
    if c == 43:
        return 62
    if c == 47:
        return 63
    raise DecodeError(DecodeError.KIND_SYNTAX, 0, c)


def base64_encode[origin: ImmOrigin](data: Span[Byte, origin]) -> String:
    var out = String()
    var i = 0
    var n = len(data)
    while i + 3 <= n:
        var v = (Int(data[i]) << 16) | (Int(data[i + 1]) << 8) | Int(data[i + 2])
        out += _B64[byte = (v >> 18) & 63]
        out += _B64[byte = (v >> 12) & 63]
        out += _B64[byte = (v >> 6) & 63]
        out += _B64[byte = v & 63]
        i += 3
    var left = n - i
    if left == 1:
        var v = Int(data[i]) << 16
        out += _B64[byte = (v >> 18) & 63]
        out += _B64[byte = (v >> 12) & 63]
        out += "=="
    elif left == 2:
        var v = (Int(data[i]) << 16) | (Int(data[i + 1]) << 8)
        out += _B64[byte = (v >> 18) & 63]
        out += _B64[byte = (v >> 12) & 63]
        out += _B64[byte = (v >> 6) & 63]
        out += "="
    return out


def base64_decode(text: String) raises DecodeError -> List[Byte]:
    var raw = text.as_bytes()
    var clean = List[Int]()
    var i = 0
    while i < len(raw):
        var c = Int(raw[i])
        if c != 61 and c != 10 and c != 13 and c != 32:
            clean.append(_b64_val(c))
        i += 1
    var out = List[Byte]()
    var k = 0
    while k + 4 <= len(clean):
        var v = (clean[k] << 18) | (clean[k + 1] << 12) | (clean[k + 2] << 6) | clean[k + 3]
        out.append(Byte((v >> 16) & 255))
        out.append(Byte((v >> 8) & 255))
        out.append(Byte(v & 255))
        k += 4
    var rem = len(clean) - k
    if rem == 2:
        var v = (clean[k] << 18) | (clean[k + 1] << 12)
        out.append(Byte((v >> 16) & 255))
    elif rem == 3:
        var v = (clean[k] << 18) | (clean[k + 1] << 12) | (clean[k + 2] << 6)
        out.append(Byte((v >> 16) & 255))
        out.append(Byte((v >> 8) & 255))
    elif rem == 1:
        raise DecodeError(DecodeError.KIND_SYNTAX, 0, rem)
    return out^


def hex_encode[origin: ImmOrigin](data: Span[Byte, origin]) -> String:
    var s = String()
    var i = 0
    while i < len(data):
        var b = Int(data[i])
        s += _HEX[byte = (b >> 4) & 15]
        s += _HEX[byte = b & 15]
        i += 1
    return s


def _hex_val(c: Int) raises DecodeError -> Int:
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 97 and c <= 102:
        return c - 87
    if c >= 65 and c <= 70:
        return c - 55
    raise DecodeError(DecodeError.KIND_SYNTAX, 0, c)


def hex_decode(text: String) raises DecodeError -> List[Byte]:
    var raw = text.as_bytes()
    if (len(raw) & 1) != 0:
        raise DecodeError(DecodeError.KIND_SIZE, 0, len(raw))
    var out = List[Byte]()
    var i = 0
    while i < len(raw):
        var v = (_hex_val(Int(raw[i])) << 4) | _hex_val(Int(raw[i + 1]))
        out.append(Byte(v))
        i += 2
    return out^


def _pad2(n: Int) -> String:
    if n < 10:
        return "0" + String(n)
    return String(n)


def _pad3(n: Int) -> String:
    if n < 10:
        return "00" + String(n)
    if n < 100:
        return "0" + String(n)
    return String(n)


def _pad4(n: Int) -> String:
    var s = String(n)
    while s.byte_length() < 4:
        s = "0" + s
    return s


def civil_from_days(z_in: Int) -> Tuple[Int, Int, Int]:
    var z = z_in + 719468
    var era = 0
    if z >= 0:
        era = z // 146097
    else:
        era = (z - 146096) // 146097
    var doe = z - era * 146097
    var yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    var y = yoe + era * 400
    var doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    var mp = (5 * doy + 2) // 153
    var d = doy - (153 * mp + 2) // 5 + 1
    var m = mp + 3
    if mp >= 10:
        m = mp - 9
    if m <= 2:
        y += 1
    return (y, m, d)


def days_from_civil(y_in: Int, m: Int, d: Int) -> Int:
    var y = y_in
    if m <= 2:
        y -= 1
    var era = 0
    if y >= 0:
        era = y // 400
    else:
        era = (y - 399) // 400
    var yoe = y - era * 400
    var mp = m + 9
    if m > 2:
        mp = m - 3
    var doy = (153 * mp + 2) // 5 + d - 1
    var doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468


def format_datetime(ms: Int64) -> String:
    var neg = ms < Int64(0)
    var v = ms
    if neg:
        v = -ms
    var day = Int(v // Int64(86400000))
    var tod = Int(v % Int64(86400000))
    if neg:
        if tod != 0:
            day = -(day + 1)
            tod = 86400000 - tod
        else:
            day = -day
    var ymd = civil_from_days(day)
    var hh = tod // 3600000
    var mm = (tod // 60000) % 60
    var ss = (tod // 1000) % 60
    var milli = tod % 1000
    var s = _pad4(ymd[0]) + "-" + _pad2(ymd[1]) + "-" + _pad2(ymd[2])
    s += "T" + _pad2(hh) + ":" + _pad2(mm) + ":" + _pad2(ss)
    if milli != 0:
        s += "." + _pad3(milli)
    s += "Z"
    return s


def _digits_at[origin: ImmOrigin](raw: Span[Byte, origin], at: Int, n: Int) raises DecodeError -> Int:
    var v = 0
    var i = 0
    while i < n:
        var c = Int(raw[at + i])
        if c < 48 or c > 57:
            raise DecodeError(DecodeError.KIND_SYNTAX, at, c)
        v = v * 10 + (c - 48)
        i += 1
    return v


def parse_datetime(text: String) raises DecodeError -> Int64:
    var raw = text.as_bytes()
    if len(raw) < 20:
        raise DecodeError(DecodeError.KIND_SYNTAX, 0, len(raw))
    var y = _digits_at(raw, 0, 4)
    var mo = _digits_at(raw, 5, 2)
    var d = _digits_at(raw, 8, 2)
    var hh = _digits_at(raw, 11, 2)
    var mm = _digits_at(raw, 14, 2)
    var ss = _digits_at(raw, 17, 2)
    var milli = 0
    var p = 19
    if p < len(raw) and raw[p] == Byte(ord(".")):
        p += 1
        var scale = 100
        var count = 0
        while p < len(raw) and raw[p] >= Byte(ord("0")) and raw[p] <= Byte(ord("9")) and count < 3:
            milli += (Int(raw[p]) - 48) * scale
            scale //= 10
            count += 1
            p += 1
        while p < len(raw) and raw[p] >= Byte(ord("0")) and raw[p] <= Byte(ord("9")):
            p += 1
    if p >= len(raw) or raw[p] != Byte(ord("Z")):
        raise DecodeError(DecodeError.KIND_SYNTAX, p, 0)
    var days = days_from_civil(y, mo, d)
    var ms = Int64(days) * Int64(86400000) + Int64(hh) * Int64(3600000) + Int64(mm) * Int64(60000) + Int64(ss) * Int64(1000) + Int64(milli)
    return ms
