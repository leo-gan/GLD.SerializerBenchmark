from std.collections import List, Span

from gldjson_runtime.error import DecodeError
from gldjson_runtime.options import DecodeOptions


def ensure_index[
    origin: ImmOrigin
](data: Span[Byte, origin], mut positions: List[UInt32]) raises DecodeError:
    """Structural index. Empty until the speed pass fills it."""
    _ = data
    _ = positions
    _ = DecodeOptions.default
