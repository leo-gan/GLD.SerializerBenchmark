from std.collections import List, Span

from cbor_runtime.error import DecodeError
from cbor_wire.reader import WireReader


def decode_tstr_span[
    origin: ImmOrigin
](buf: Span[Byte, origin]) raises DecodeError -> StringSpan[origin]:
    """Decode one definite text string as a view into `buf`. Trailing bytes are an error."""
    var r = WireReader(buf)
    var sl = r.read_text_span()
    if r.remaining() > 0:
        raise DecodeError(DecodeError.KIND_TRAILING, r.position())
    return sl


def decode_tstr_chunks[
    origin: ImmOrigin
](buf: Span[Byte, origin]) raises DecodeError -> List[StringSpan[origin]]:
    """Zero-copy views of each definite tstr chunk. Works for indefinite text."""
    var r = WireReader(buf)
    var chunks = r.read_text_chunks()
    if r.remaining() > 0:
        raise DecodeError(DecodeError.KIND_TRAILING, r.position())
    return chunks^
