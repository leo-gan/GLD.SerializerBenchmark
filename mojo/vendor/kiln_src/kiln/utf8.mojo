from std.collections import Span
from std.memory import unsafe_memcpy
from std.sys import is_little_endian

from kiln.error import KilnError


@always_inline
def _ascii_bits[o: ImmOrigin](p: Pointer[UInt8, o], n: Int) -> UInt8:
    """OR of every byte. A result below 0x80 means the buffer is ASCII.

    Eight-byte loads are the pointer manual's unaligned `unsafe_load`.
    A set high bit in the word returns 0x80 so the multi-byte checker runs.
    """
    var i = 0
    comptime if is_little_endian():
        while i + 8 <= n:
            var q = p.unsafe_offset(i).unsafe_bitcast[Scalar[DType.uint64]]()
            var w = q.unsafe_load[alignment=1](0)
            if (w & UInt64(0x8080808080808080)) != UInt64(0):
                return UInt8(0x80)
            i += 8
    var bits = UInt8(0)
    while i < n:
        bits = bits | p[unsafe_offset=i]
        i += 1
    return bits


@always_inline
def _utf8_ptr[o: ImmOrigin](p: Pointer[UInt8, o], n: Int) -> Bool:
    """Well-formed UTF-8 over `n` bytes at `p`.

    ASCII bytes have the high bit clear, so one OR of the bytes accepts
    that common case. The multi-byte checker runs only when a byte is
    past 0x7F. Pointer loads skip the per-byte bounds check of `span[i]`.
    """
    if n == 0:
        return True
    if _ascii_bits(p, n) < UInt8(0x80):
        return True
    var i = 0
    while i < n:
        var c = Int(p[unsafe_offset=i])
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
            var cc = Int(p[unsafe_offset=i])
            if (cc & 0xC0) != 0x80:
                return False
            cp = (cp << 6) | (cc & 0x3F)
            k += 1
        if cp < min_cp or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF):
            return False
        i += 1
    return True


@always_inline
def utf8_ok[origin: ImmOrigin](span: Span[UInt8, origin]) -> Bool:
    """Return true when `span` is well-formed UTF-8.

    The check rejects overlong sequences, surrogates, and code points
    past U+10FFFF. It does not allocate.
    """
    return _utf8_ptr(span.unsafe_ptr(), len(span))


@always_inline
def string_from_ptr[o: ImmOrigin](
    p: Pointer[UInt8, o], n: Int, offset: Int, check: Bool
) raises KilnError -> String:
    """Copy `n` bytes into a `String`.

    `String(unsafe_uninit_length=)` plus `memcpy` is the stdlib's
    uninitialized SSO fill. On a 5-byte runtime length it was several
    times faster than `String(unsafe_from_utf8=)` of a sliced span,
    which is what `read_string` used to build.
    """
    if check and not _utf8_ptr(p, n):
        raise KilnError(KilnError.UTF8, offset)
    var out = String(unsafe_uninit_length=n)
    if n > 0:
        unsafe_memcpy(dest=out.unsafe_ptr_mut(), src=p, count=n)
    return out^


@always_inline
def string_from_span[origin: ImmOrigin](
    span: Span[UInt8, origin], offset: Int, check: Bool
) raises KilnError -> String:
    return string_from_ptr(span.unsafe_ptr(), len(span), offset, check)
