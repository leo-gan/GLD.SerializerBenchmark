from std.collections import List, Span

from cbor_runtime.error import DecodeError
from cbor_runtime.options import EncodeOptions
from cbor_runtime.value import CborValue, decode_item, encode_value
from cbor_wire.head import MAX_COUNT
from cbor_wire.reader import WireReader
from cbor_wire.writer import WireWriter


struct SeqDecoder[origin: ImmOrigin](Movable):
    """Pull one RFC 8742 item at a time. Dropping the returned value frees it."""

    var reader: WireReader[Self.origin]
    var seen: Int

    def __init__(out self, buf: Span[Byte, Self.origin]):
        self.reader = WireReader(buf)
        self.seen = 0

    def has_more(self) -> Bool:
        return self.reader.remaining() > 0

    def position(self) -> Int:
        return self.reader.position()

    def next_value(mut self) raises DecodeError -> CborValue:
        if not self.has_more():
            raise DecodeError(DecodeError.KIND_EOF, self.reader.position())
        if self.seen >= MAX_COUNT:
            raise DecodeError(DecodeError.KIND_RANGE, self.reader.position())
        var v = CborValue()
        v.root = decode_item(self.reader, v)
        self.seen += 1
        return v^

    def skip(mut self) raises DecodeError:
        """Advance past the next item without building a `CborValue`."""
        if not self.has_more():
            raise DecodeError(DecodeError.KIND_EOF, self.reader.position())
        if self.seen >= MAX_COUNT:
            raise DecodeError(DecodeError.KIND_RANGE, self.reader.position())
        self.reader.skip_item()
        self.seen += 1


def decode_seq_values[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> List[CborValue]:
    var dec = SeqDecoder(buf)
    var out = List[CborValue]()
    while dec.has_more():
        out.append(dec.next_value())
    return out^


def encode_seq_values(
    items: List[CborValue], options: EncodeOptions = EncodeOptions.preferred
) raises DecodeError -> List[Byte]:
    var w = WireWriter()
    for i in range(len(items)):
        var one = encode_value(items[i], options)
        for j in range(len(one)):
            w.write_byte(one[j])
    return w^.finish()
