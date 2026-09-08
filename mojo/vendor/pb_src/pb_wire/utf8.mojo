from std.collections import Span

from pb_runtime.error import DecodeError


def string_from_utf8[
    origin: ImmOrigin
](span: Span[Byte, origin], offset: Int, field: UInt32 = 0) raises DecodeError -> String:
    """Wrap `String(from_utf8=)` and remap the default Error to DecodeError."""
    try:
        return String(from_utf8=span)
    except _:
        raise DecodeError(DecodeError.KIND_BAD_UTF8, offset, field)
