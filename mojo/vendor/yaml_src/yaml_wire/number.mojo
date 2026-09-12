from std.collections import List, Span

from yaml_runtime.error import DecodeError


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


def write_int_digits(mut dest: List[Byte], mut pos: Int, v: Int64):
    write_int_known(dest, pos, v, encoded_int_len(v))


def _is_int_valued(v: Float64) -> Bool:
    if v != v:
        return False
    if v > 9.223372036854776e18 or v < -9.223372036854776e18:
        return False
    var i = Int64(v)
    return Float64(i) == v


def encoded_float_len(v: Float64) -> Int:
    if v != v:
        return 4
    if v > 1.7976931348623157e308:
        return 4
    if v < -1.7976931348623157e308:
        return 5
    if _is_int_valued(v):
        return encoded_int_len(Int64(v)) + 2
    var s = String(v)
    return s.byte_length()


def write_float_digits(mut dest: List[Byte], mut pos: Int, v: Float64):
    if v != v:
        dest[pos] = Byte(46)
        dest[pos + 1] = Byte(110)
        dest[pos + 2] = Byte(97)
        dest[pos + 3] = Byte(110)
        pos += 4
        return
    if v > 1.7976931348623157e308:
        dest[pos] = Byte(46)
        dest[pos + 1] = Byte(105)
        dest[pos + 2] = Byte(110)
        dest[pos + 3] = Byte(102)
        pos += 4
        return
    if v < -1.7976931348623157e308:
        dest[pos] = Byte(45)
        dest[pos + 1] = Byte(46)
        dest[pos + 2] = Byte(105)
        dest[pos + 3] = Byte(110)
        dest[pos + 4] = Byte(102)
        pos += 5
        return
    if _is_int_valued(v):
        var n = encoded_int_len(Int64(v))
        write_int_known(dest, pos, Int64(v), n)
        dest[pos] = Byte(46)
        dest[pos + 1] = Byte(48)
        pos += 2
        return
    var s = String(v)
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        dest[pos] = b[i]
        pos += 1
        i += 1


def hex_val(c: Int) -> Int:
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 65 and c <= 70:
        return c - 55
    if c >= 97 and c <= 102:
        return c - 87
    return -1


def is_digit(c: Int) -> Bool:
    return c >= 48 and c <= 57
