from std.collections import List, Span

from gldtoml_runtime.error import DecodeError


def validate_utf8[
    origin: ImmOrigin
](span: Span[Byte, origin]) raises DecodeError:
    """Reject ill-formed UTF-8 without allocating a String."""
    var i = 0
    var n = len(span)
    while i < n:
        var c = Int(span[i])
        if c < 0x80:
            i += 1
            continue
        var need: Int
        var cp: Int
        var min_cp: Int
        if c >= 0xC2 and c <= 0xDF:
            need = 1
            cp = c & 0x1F
            min_cp = 0x80
        elif c >= 0xE0 and c <= 0xEF:
            need = 2
            cp = c & 0x0F
            min_cp = 0x800
        elif c >= 0xF0 and c <= 0xF4:
            need = 3
            cp = c & 0x07
            min_cp = 0x10000
        else:
            raise DecodeError(DecodeError.KIND_UTF8, i)
        if i + need >= n:
            raise DecodeError(DecodeError.KIND_UTF8, i)
        var k = 0
        while k < need:
            i += 1
            var cc = Int(span[i])
            if (cc & 0xC0) != 0x80:
                raise DecodeError(DecodeError.KIND_UTF8, i)
            cp = (cp << 6) | (cc & 0x3F)
            k += 1
        if cp < min_cp or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF):
            raise DecodeError(DecodeError.KIND_UTF8, i)
        i += 1


def string_from_utf8[
    origin: ImmOrigin
](span: Span[Byte, origin], offset: Int, field: Int = 0) raises DecodeError -> String:
    try:
        return String(from_utf8=span)
    except _:
        raise DecodeError(DecodeError.KIND_UTF8, offset, field)


def trusted_utf8[
    origin: ImmOrigin
](span: Span[Byte, origin]) -> String:
    """Copy bytes that `validate_utf8` already accepted, or that this encoder just wrote."""
    return String(unsafe_from_utf8=span)


def string_from_bytes(buf: List[Byte], offset: Int) -> String:
    _ = offset
    return String(unsafe_from_utf8=buf)


def append_scalar(mut buf: List[Byte], cp: Int, offset: Int) raises DecodeError:
    if cp < 0 or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF):
        raise DecodeError(DecodeError.KIND_ESCAPE, offset)
    if cp < 0x80:
        buf.append(Byte(cp))
        return
    if cp < 0x800:
        buf.append(Byte(0xC0 | (cp >> 6)))
        buf.append(Byte(0x80 | (cp & 0x3F)))
        return
    if cp < 0x10000:
        buf.append(Byte(0xE0 | (cp >> 12)))
        buf.append(Byte(0x80 | ((cp >> 6) & 0x3F)))
        buf.append(Byte(0x80 | (cp & 0x3F)))
        return
    buf.append(Byte(0xF0 | (cp >> 18)))
    buf.append(Byte(0x80 | ((cp >> 12) & 0x3F)))
    buf.append(Byte(0x80 | ((cp >> 6) & 0x3F)))
    buf.append(Byte(0x80 | (cp & 0x3F)))
