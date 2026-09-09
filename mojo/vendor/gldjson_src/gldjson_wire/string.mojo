from std.collections import List, Span
from std.memory import unsafe_memcpy

from gldjson_runtime.error import DecodeError
from gldjson_wire.classify import MAX_ITEM_BYTES, hex_digit
from gldjson_wire.simdscan import first_escape_or_quote, needs_escape_bytes
from gldjson_wire.utf8 import string_from_utf8


def needs_escape[origin: ImmOrigin](data: Span[Byte, origin]) -> Bool:
    return needs_escape_bytes(data)


def encoded_string_len(s: String) -> Int:
    var b = s.as_bytes()
    var n = 2
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 34 or c == 92 or c == 8 or c == 12 or c == 10 or c == 13 or c == 9:
            n += 2
        elif c < 32:
            n += 6
        else:
            n += 1
        i += 1
    return n


def write_string_escaped(mut dest: List[Byte], mut pos: Int, s: String):
    dest[pos] = Byte(34)
    pos += 1
    var b = s.as_bytes()
    if not needs_escape(b):
        var n = len(b)
        if n > 0:
            unsafe_memcpy(
                dest=dest.unsafe_ptr().unsafe_offset(pos),
                src=b.unsafe_ptr(),
                count=n,
            )
            pos += n
        dest[pos] = Byte(34)
        pos += 1
        return
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 34:
            dest[pos] = Byte(92)
            dest[pos + 1] = Byte(34)
            pos += 2
        elif c == 92:
            dest[pos] = Byte(92)
            dest[pos + 1] = Byte(92)
            pos += 2
        elif c == 8:
            dest[pos] = Byte(92)
            dest[pos + 1] = Byte(98)
            pos += 2
        elif c == 12:
            dest[pos] = Byte(92)
            dest[pos + 1] = Byte(102)
            pos += 2
        elif c == 10:
            dest[pos] = Byte(92)
            dest[pos + 1] = Byte(110)
            pos += 2
        elif c == 13:
            dest[pos] = Byte(92)
            dest[pos + 1] = Byte(114)
            pos += 2
        elif c == 9:
            dest[pos] = Byte(92)
            dest[pos + 1] = Byte(116)
            pos += 2
        elif c < 32:
            dest[pos] = Byte(92)
            dest[pos + 1] = Byte(117)
            dest[pos + 2] = Byte(48)
            dest[pos + 3] = Byte(48)
            dest[pos + 4] = _hex(c >> 4)
            dest[pos + 5] = _hex(c & 15)
            pos += 6
        else:
            dest[pos] = b[i]
            pos += 1
        i += 1
    dest[pos] = Byte(34)
    pos += 1


def _hex(n: Int) -> Byte:
    if n < 10:
        return Byte(48 + n)
    return Byte(87 + n)


def parse_string[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int) raises DecodeError -> String:
    if pos >= len(data) or Int(data[pos]) != 34:
        raise DecodeError(DecodeError.KIND_SYNTAX, pos)
    var start = pos
    pos += 1
    # Fast path: SIMD scan to the first quote, backslash, or control byte.
    var scan = first_escape_or_quote(data, pos)
    var escaped = scan < len(data) and Int(data[scan]) == 92
    if scan < len(data) and Int(data[scan]) < 32:
        raise DecodeError(DecodeError.KIND_ESCAPE, scan)
    if not escaped and scan < len(data) and Int(data[scan]) == 34:
        var n = scan - pos
        if n > MAX_ITEM_BYTES:
            raise DecodeError(DecodeError.KIND_RANGE, start)
        var ascii = True
        var i = pos
        while i < scan:
            if Int(data[i]) >= 128:
                ascii = False
                break
            i += 1
        var s: String
        if ascii:
            s = String(unsafe_from_utf8=data[pos:scan])
        else:
            s = string_from_utf8(data[pos:scan], start)
        pos = scan + 1
        return s^
    var out = List[Byte]()
    while pos < len(data):
        var c = Int(data[pos])
        if c == 34:
            pos += 1
            if len(out) > MAX_ITEM_BYTES:
                raise DecodeError(DecodeError.KIND_RANGE, start)
            try:
                return String(from_utf8=out)
            except _:
                raise DecodeError(DecodeError.KIND_UTF8, start)
        if c < 32:
            raise DecodeError(DecodeError.KIND_ESCAPE, pos)
        pos += 1
        if c != 92:
            out.append(Byte(c))
            continue
        if pos >= len(data):
            raise DecodeError(DecodeError.KIND_EOF, pos)
        var e = Int(data[pos])
        pos += 1
        if e == 34 or e == 92 or e == 47:
            out.append(Byte(e))
        elif e == 98:
            out.append(Byte(8))
        elif e == 102:
            out.append(Byte(12))
        elif e == 110:
            out.append(Byte(10))
        elif e == 114:
            out.append(Byte(13))
        elif e == 116:
            out.append(Byte(9))
        elif e == 117:
            var cp = _hex4(data, pos)
            pos += 4
            if cp >= 0xD800 and cp <= 0xDBFF:
                if pos + 5 < len(data) and Int(data[pos]) == 92 and Int(data[pos + 1]) == 117:
                    pos += 2
                    var low = _hex4(data, pos)
                    pos += 4
                    if low < 0xDC00 or low > 0xDFFF:
                        raise DecodeError(DecodeError.KIND_ESCAPE, pos - 4)
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                else:
                    raise DecodeError(DecodeError.KIND_ESCAPE, pos)
            elif cp >= 0xDC00 and cp <= 0xDFFF:
                raise DecodeError(DecodeError.KIND_ESCAPE, pos - 4)
            _append_utf8(out, cp)
        else:
            raise DecodeError(DecodeError.KIND_ESCAPE, pos - 1)
    raise DecodeError(DecodeError.KIND_EOF, start)


def _hex4[
    origin: ImmOrigin
](data: Span[Byte, origin], pos: Int) raises DecodeError -> Int:
    if pos + 4 > len(data):
        raise DecodeError(DecodeError.KIND_EOF, pos)
    var v = 0
    var i = 0
    while i < 4:
        var d = hex_digit(Int(data[pos + i]))
        if d < 0:
            raise DecodeError(DecodeError.KIND_ESCAPE, pos + i)
        v = (v << 4) + d
        i += 1
    return v


def _append_utf8(mut out: List[Byte], cp: Int):
    if cp < 0x80:
        out.append(Byte(cp))
    elif cp < 0x800:
        out.append(Byte(0xC0 | (cp >> 6)))
        out.append(Byte(0x80 | (cp & 0x3F)))
    elif cp < 0x10000:
        out.append(Byte(0xE0 | (cp >> 12)))
        out.append(Byte(0x80 | ((cp >> 6) & 0x3F)))
        out.append(Byte(0x80 | (cp & 0x3F)))
    else:
        out.append(Byte(0xF0 | (cp >> 18)))
        out.append(Byte(0x80 | ((cp >> 12) & 0x3F)))
        out.append(Byte(0x80 | ((cp >> 6) & 0x3F)))
        out.append(Byte(0x80 | (cp & 0x3F)))
