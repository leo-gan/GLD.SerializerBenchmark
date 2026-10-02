from std.collections import List, Span

from gldtoml_runtime.error import DecodeError
from gldtoml_wire.utf8 import string_from_bytes, trusted_utf8


@always_inline
def take_prefix[
    origin: ImmOrigin
](raw: Span[Byte, origin], i: Int, lit: String) -> Int:
    var b = lit.as_bytes()
    var n = len(b)
    if i + n > len(raw):
        return -1
    var k = 0
    while k < n:
        if raw[i + k] != b[k]:
            return -1
        k += 1
    return i + n


@always_inline
def value_end[
    origin: ImmOrigin
](raw: Span[Byte, origin], i: Int) -> Int:
    """End index of a single-line value starting at i. The returned index is the value end."""
    var n = len(raw)
    var p = i
    if p < n and (Int(raw[p]) == 34 or Int(raw[p]) == 39):
        var q = Int(raw[p])
        p += 1
        while p < n and Int(raw[p]) != q:
            if Int(raw[p]) == 92 and p + 1 < n:
                p += 2
                continue
            p += 1
        if p < n:
            p += 1
        return p
    while p < n and Int(raw[p]) != 10 and Int(raw[p]) != 35 and Int(raw[p]) != 13:
        p += 1
    while p > i and (Int(raw[p - 1]) == 32 or Int(raw[p - 1]) == 9):
        p -= 1
    return p


@always_inline
def skip_tail[
    origin: ImmOrigin
](raw: Span[Byte, origin], i: Int) -> Int:
    var p = i
    var n = len(raw)
    if p < n and Int(raw[p]) == 35:
        while p < n and Int(raw[p]) != 10:
            p += 1
    if p < n and Int(raw[p]) == 13:
        p += 1
    if p < n and Int(raw[p]) == 10:
        p += 1
    return p


@always_inline
def span_is[
    origin: ImmOrigin
](raw: Span[Byte, origin], start: Int, end: Int, lit: String) -> Bool:
    var b = lit.as_bytes()
    if end - start != len(b):
        return False
    var i = 0
    while i < len(b):
        if raw[start + i] != b[i]:
            return False
        i += 1
    return True


def parse_i64[
    origin: ImmOrigin
](raw: Span[Byte, origin], start: Int, end: Int) raises DecodeError -> Int64:
    if start >= end:
        raise DecodeError(DecodeError.KIND_SYNTAX, start)
    var i = start
    var neg = False
    if Int(raw[i]) == 45:
        neg = True
        i += 1
    elif Int(raw[i]) == 43:
        i += 1
    if i >= end:
        raise DecodeError(DecodeError.KIND_SYNTAX, start)
    var acc = UInt64(0)
    var limit = UInt64(9223372036854775807)
    if neg:
        limit = limit + UInt64(1)
    while i < end:
        var c = Int(raw[i])
        if c == 95:
            i += 1
            continue
        if c < 48 or c > 57:
            raise DecodeError(DecodeError.KIND_SYNTAX, i)
        var d = UInt64(c - 48)
        if acc > (limit - d) // UInt64(10):
            raise DecodeError(DecodeError.KIND_RANGE, i)
        acc = acc * UInt64(10) + d
        i += 1
    if neg:
        if acc == UInt64(9223372036854775808):
            return Int64.MIN
        return Int64(0) - Int64(acc)
    return Int64(acc)


def parse_f64[
    origin: ImmOrigin
](raw: Span[Byte, origin], start: Int, end: Int) raises DecodeError -> Float64:
    try:
        return Float64(trusted_utf8(raw[start:end]))
    except _:
        raise DecodeError(DecodeError.KIND_SYNTAX, start)


def parse_toml_str[
    origin: ImmOrigin
](raw: Span[Byte, origin], start: Int, end: Int) raises DecodeError -> String:
    if start >= end:
        raise DecodeError(DecodeError.KIND_SYNTAX, start)
    var q = Int(raw[start])
    if q != 34 and q != 39:
        raise DecodeError(DecodeError.KIND_SYNTAX, start)
    var i = start + 1
    while i < end and Int(raw[i]) != q and Int(raw[i]) != 92:
        i += 1
    if i < end and Int(raw[i]) == q and i + 1 == end:
        return trusted_utf8(raw[start + 1 : i])
    var buf = List[Byte]()
    i = start + 1
    while i < end and Int(raw[i]) != q:
        var c = Int(raw[i])
        if c == 92 and q == 34:
            i += 1
            if i >= end:
                raise DecodeError(DecodeError.KIND_ESCAPE, i)
            var e = Int(raw[i])
            if e == 110:
                buf.append(Byte(10))
            elif e == 116:
                buf.append(Byte(9))
            elif e == 114:
                buf.append(Byte(13))
            elif e == 92 or e == 34:
                buf.append(Byte(e))
            else:
                buf.append(Byte(e))
        else:
            buf.append(Byte(c))
        i += 1
    return string_from_bytes(buf^, start)
