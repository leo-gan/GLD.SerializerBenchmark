from std.collections import Span

from yaml_runtime.error import DecodeError


def string_from_utf8[
    origin: ImmOrigin
](span: Span[Byte, origin], offset: Int, field: Int = 0) raises DecodeError -> String:
    """Wrap `String(from_utf8=)` and remap the default Error to DecodeError.

    ASCII inputs skip the validator. Bytes at or above 128 still go through it
    so illegal sequences stay `DecodeError`.
    """
    var n = len(span)
    if n <= 64:
        var i = 0
        var ascii = True
        while i < n:
            if Int(span[i]) >= 128:
                ascii = False
                break
            i += 1
        if ascii:
            return String(unsafe_from_utf8=span)
    try:
        return String(from_utf8=span)
    except _:
        raise DecodeError(DecodeError.KIND_UTF8, offset, field)
