from std.collections import Span

from msgpack_runtime.error import DecodeError


@always_inline
def _is_ascii[origin: ImmOrigin](span: Span[Byte, origin]) -> Bool:
    """ASCII bytes are valid UTF-8. Does not read past `span`."""
    var n = len(span)
    var i = 0
    var p = span.unsafe_ptr()
    var mask = UInt64(0x8080808080808080)
    while i + 8 <= n:
        var w = p.unsafe_offset(i).unsafe_bitcast[UInt64]()[]
        if (w & mask) != UInt64(0):
            return False
        i += 8
    while i < n:
        if Int(p.unsafe_offset(i)[]) >= 128:
            return False
        i += 1
    return True


@always_inline
def string_from_utf8[
    origin: ImmOrigin
](span: Span[Byte, origin], offset: Int, field: Int = 0) raises DecodeError -> String:
    """Copy `span` into a `String`. ASCII skips the stdlib scanner; other bytes use `String(from_utf8=)`.

    Invalid UTF-8 still raises `DecodeError(KIND_UTF8)`. Not lossy.
    """
    if _is_ascii(span):
        return String(unsafe_from_utf8=span)
    try:
        return String(from_utf8=span)
    except _:
        raise DecodeError(DecodeError.KIND_UTF8, offset, field)
