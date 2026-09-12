from std.collections import Span

from yaml_runtime.error import DecodeError


def string_from_utf8[
    origin: ImmOrigin
](span: Span[Byte, origin], offset: Int, field: Int = 0) raises DecodeError -> String:
    """Wrap `String(from_utf8=)` and remap the default Error to DecodeError."""
    try:
        return String(from_utf8=span)
    except _:
        raise DecodeError(DecodeError.KIND_UTF8, offset, field)
