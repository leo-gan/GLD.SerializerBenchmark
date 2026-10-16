from std.collections import Span

from kiln.error import KilnError


@always_inline
def utf8_ok[origin: ImmOrigin](span: Span[UInt8, origin]) -> Bool:
    """Return true when `span` is well-formed UTF-8.

    The check rejects overlong sequences, surrogates, and code points
    past U+10FFFF. It does not allocate.
    """
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
            return False
        if i + need >= n:
            return False
        var k = 0
        while k < need:
            i += 1
            var cc = Int(span[i])
            if (cc & 0xC0) != 0x80:
                return False
            cp = (cp << 6) | (cc & 0x3F)
            k += 1
        if cp < min_cp or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF):
            return False
        i += 1
    return True


@always_inline
def string_from_span[origin: ImmOrigin](
    span: Span[UInt8, origin], offset: Int, check: Bool
) raises KilnError -> String:
    if check and not utf8_ok(span):
        raise KilnError(KilnError.UTF8, offset)
    return String(unsafe_from_utf8=span)
