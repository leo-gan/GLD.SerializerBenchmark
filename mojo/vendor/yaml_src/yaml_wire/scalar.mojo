from std.collections import List, Span
from std.memory import unsafe_memcpy

from yaml_runtime.error import DecodeError
from yaml_runtime.options import EncodeOptions
from yaml_wire.number import hex_val, is_digit
from yaml_wire.simdscan import scan_dquote
from yaml_wire.utf8 import string_from_utf8

# Writer lives in wire.writer; string emit is implemented there to avoid a cycle.


def is_plain_safe[origin: ImmOrigin](data: Span[Byte, origin], flow: Bool) -> Bool:
    """YAML 1.2 Core-plain-safe in block or flow context."""
    var n = len(data)
    if n == 0:
        return False
    var c0 = Int(data[0])
    if c0 == 45 or c0 == 63 or c0 == 58:
        if n == 1:
            return False
        if _is_space(Int(data[1])):
            return False
    if (
        c0 == 35
        or c0 == 38
        or c0 == 42
        or c0 == 33
        or c0 == 124
        or c0 == 62
        or c0 == 39
        or c0 == 34
        or c0 == 37
        or c0 == 64
        or c0 == 96
    ):
        return False
    if flow and (c0 == 91 or c0 == 93 or c0 == 123 or c0 == 125 or c0 == 44):
        return False
    var i = 0
    while i < n:
        var c = Int(data[i])
        if c == 10 or c == 13:
            return False
        if c == 58 and i + 1 < n and _is_space(Int(data[i + 1])):
            return False
        if c == 32 and i + 1 < n and Int(data[i + 1]) == 35:
            return False
        if flow and (c == 91 or c == 93 or c == 123 or c == 125 or c == 44):
            return False
        i += 1
    if _looks_core_special(data):
        return False
    return True


def _is_space(c: Int) -> Bool:
    return c == 32 or c == 9


def _looks_core_special[origin: ImmOrigin](data: Span[Byte, origin]) -> Bool:
    """True if a plain would be read back as null/bool/int/float."""
    var n = len(data)
    if n == 1 and Int(data[0]) == 126:
        return True
    if _eq(data, "null") or _eq(data, "Null") or _eq(data, "NULL"):
        return True
    if (
        _eq(data, "true")
        or _eq(data, "True")
        or _eq(data, "TRUE")
        or _eq(data, "false")
        or _eq(data, "False")
        or _eq(data, "FALSE")
    ):
        return True
    if (
        _eq(data, ".inf")
        or _eq(data, ".Inf")
        or _eq(data, ".INF")
        or _eq(data, "-.inf")
        or _eq(data, "-.Inf")
        or _eq(data, "-.INF")
        or _eq(data, ".nan")
        or _eq(data, ".NaN")
        or _eq(data, ".NAN")
        or _eq(data, "+.inf")
        or _eq(data, "+.Inf")
        or _eq(data, "+.INF")
    ):
        return True
    if n == 0:
        return False
    var i = 0
    var c = Int(data[0])
    if c == 43 or c == 45:
        i = 1
        if i >= n:
            return False
        c = Int(data[i])
    if i + 1 < n and c == 48 and (Int(data[i + 1]) == 120 or Int(data[i + 1]) == 111):
        return True
    var saw_digit = False
    var saw_dot = False
    var saw_exp = False
    while i < n:
        c = Int(data[i])
        if is_digit(c):
            saw_digit = True
        elif c == 46 and not saw_dot and not saw_exp:
            saw_dot = True
        elif (c == 101 or c == 69) and saw_digit and not saw_exp:
            saw_exp = True
            if i + 1 < n and (Int(data[i + 1]) == 43 or Int(data[i + 1]) == 45):
                i += 1
        else:
            return False
        i += 1
    return saw_digit


def _eq[origin: ImmOrigin](data: Span[Byte, origin], lit: String) -> Bool:
    var b = lit.as_bytes()
    if len(data) != len(b):
        return False
    var i = 0
    while i < len(b):
        if Int(data[i]) != Int(b[i]):
            return False
        i += 1
    return True


def encoded_string_len[origin: ImmOrigin](data: Span[Byte, origin], options: EncodeOptions) -> Int:
    if is_plain_safe(data, options.is_flow()):
        return len(data)
    return 2 + _escaped_len(data)


def _escaped_len[origin: ImmOrigin](data: Span[Byte, origin]) -> Int:
    var n = 0
    var i = 0
    while i < len(data):
        var c = Int(data[i])
        if c == 10 or c == 13 or c == 9 or c == 34 or c == 92:
            n += 2
        elif c < 32:
            n += 6
        else:
            n += 1
        i += 1
    return n


def hex_digit_ascii(v: Int) -> Int:
    if v < 10:
        return 48 + v
    return 97 + (v - 10)


def parse_double_quoted[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int) raises DecodeError -> String:
    if pos >= len(data) or Int(data[pos]) != 34:
        raise DecodeError(DecodeError.KIND_SYNTAX, pos)
    pos += 1
    var start = pos
    var hit = scan_dquote(data, pos)
    if hit < len(data) and Int(data[hit]) == 34:
        var span = data[start:hit]
        pos = hit + 1
        return string_from_utf8(span, start)
    var out = List[Byte]()
    while pos < len(data):
        var c = Int(data[pos])
        if c == 34:
            pos += 1
            return string_from_utf8(Span(out), start)
        if c == 92:
            pos += 1
            if pos >= len(data):
                raise DecodeError(DecodeError.KIND_ESCAPE, pos)
            _append_escape(data, pos, out)
            continue
        if c == 10 or c == 13:
            _fold_break(data, pos, out)
            continue
        out.append(data[pos])
        pos += 1
    raise DecodeError(DecodeError.KIND_EOF, pos)


def _append_escape[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int, mut out: List[Byte]) raises DecodeError:
    var c = Int(data[pos])
    pos += 1
    if c == 48:
        out.append(Byte(0))
    elif c == 97:
        out.append(Byte(7))
    elif c == 98:
        out.append(Byte(8))
    elif c == 116:
        out.append(Byte(9))
    elif c == 110:
        out.append(Byte(10))
    elif c == 118:
        out.append(Byte(11))
    elif c == 102:
        out.append(Byte(12))
    elif c == 114:
        out.append(Byte(13))
    elif c == 101:
        out.append(Byte(27))
    elif c == 32:
        out.append(Byte(32))
    elif c == 34:
        out.append(Byte(34))
    elif c == 47:
        out.append(Byte(47))
    elif c == 92:
        out.append(Byte(92))
    elif c == 78:
        out.append(Byte(0xC2))
        out.append(Byte(0x85))
    elif c == 95:
        out.append(Byte(0xC2))
        out.append(Byte(0xA0))
    elif c == 76:
        out.append(Byte(0xE2))
        out.append(Byte(0x80))
        out.append(Byte(0xA8))
    elif c == 80:
        out.append(Byte(0xE2))
        out.append(Byte(0x80))
        out.append(Byte(0xA9))
    elif c == 120:
        _hex_bytes(data, pos, 2, out)
    elif c == 117:
        _hex_bytes(data, pos, 4, out)
    elif c == 85:
        _hex_bytes(data, pos, 8, out)
    elif c == 10 or c == 13:
        pos -= 1
        _skip_break(data, pos)
    else:
        raise DecodeError(DecodeError.KIND_ESCAPE, pos - 1)


def _hex_bytes[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int, n: Int, mut out: List[Byte]) raises DecodeError:
    var cp = 0
    var i = 0
    while i < n:
        if pos >= len(data):
            raise DecodeError(DecodeError.KIND_ESCAPE, pos)
        var h = hex_val(Int(data[pos]))
        if h < 0:
            raise DecodeError(DecodeError.KIND_ESCAPE, pos)
        cp = (cp << 4) + h
        pos += 1
        i += 1
    _utf8_append(out, cp)


def _utf8_append(mut out: List[Byte], cp: Int) raises DecodeError:
    if cp < 0x80:
        out.append(Byte(cp))
    elif cp < 0x800:
        out.append(Byte(0xC0 | (cp >> 6)))
        out.append(Byte(0x80 | (cp & 0x3F)))
    elif cp < 0x10000:
        if cp >= 0xD800 and cp <= 0xDFFF:
            raise DecodeError(DecodeError.KIND_UTF8, 0)
        out.append(Byte(0xE0 | (cp >> 12)))
        out.append(Byte(0x80 | ((cp >> 6) & 0x3F)))
        out.append(Byte(0x80 | (cp & 0x3F)))
    elif cp < 0x110000:
        out.append(Byte(0xF0 | (cp >> 18)))
        out.append(Byte(0x80 | ((cp >> 12) & 0x3F)))
        out.append(Byte(0x80 | ((cp >> 6) & 0x3F)))
        out.append(Byte(0x80 | (cp & 0x3F)))
    else:
        raise DecodeError(DecodeError.KIND_UTF8, 0)


def parse_single_quoted[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int) raises DecodeError -> String:
    if pos >= len(data) or Int(data[pos]) != 39:
        raise DecodeError(DecodeError.KIND_SYNTAX, pos)
    pos += 1
    var start = pos
    var out = List[Byte]()
    while pos < len(data):
        var c = Int(data[pos])
        if c == 39:
            if pos + 1 < len(data) and Int(data[pos + 1]) == 39:
                out.append(Byte(39))
                pos += 2
                continue
            pos += 1
            return string_from_utf8(Span(out), start)
        if c == 10 or c == 13:
            _fold_break(data, pos, out)
            continue
        out.append(data[pos])
        pos += 1
    raise DecodeError(DecodeError.KIND_EOF, pos)


def _fold_break[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int, mut out: List[Byte]):
    _skip_break(data, pos)
    var blanks = 0
    while pos < len(data):
        var c = Int(data[pos])
        if c == 32 or c == 9:
            pos += 1
            continue
        if c == 10 or c == 13:
            blanks += 1
            _skip_break(data, pos)
            continue
        break
    if blanks == 0:
        out.append(Byte(32))
    else:
        var i = 0
        while i < blanks:
            out.append(Byte(10))
            i += 1


def _skip_break[origin: ImmOrigin](data: Span[Byte, origin], mut pos: Int):
    if pos >= len(data):
        return
    if Int(data[pos]) == 13:
        pos += 1
        if pos < len(data) and Int(data[pos]) == 10:
            pos += 1
        return
    if Int(data[pos]) == 10:
        pos += 1
