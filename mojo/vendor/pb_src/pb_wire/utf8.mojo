from std.collections import Span

from pb_runtime.error import DecodeError


@always_inline
def string_from_utf8[
    origin: ImmOrigin
](span: Span[Byte, origin], offset: Int, field: UInt32 = 0) raises DecodeError -> String:
    """Copy UTF-8 bytes into a String. ASCII skips the full validator."""
    var n = len(span)
    if n == 0:
        return String()
    var i = 0
    while i < n:
        if span.unsafe_get(i) >= 0x80:
            try:
                return String(from_utf8=span)
            except _:
                raise DecodeError(DecodeError.KIND_BAD_UTF8, offset, field)
        i += 1
    return String(unsafe_from_utf8=span)
