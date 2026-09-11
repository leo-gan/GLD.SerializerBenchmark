from std.collections import List, Span

from msgpack_runtime.error import DecodeError
from msgpack_runtime.options import DecodeOptions, EncodeOptions, MAX_COUNT
from msgpack_runtime.value import MsgpackValue, decode_item, encode_item
from msgpack_wire.reader import WireReader
from msgpack_wire.writer import WireWriter


struct StreamDecoder[origin: ImmOrigin](Movable):
    var reader: WireReader[Self.origin]
    var count: Int

    def __init__(
        out self,
        data: Span[Byte, Self.origin],
        options: DecodeOptions = DecodeOptions.default,
    ):
        self.reader = WireReader[Self.origin](data, options)
        self.count = 0

    def next_value(mut self) raises DecodeError -> Optional[MsgpackValue]:
        if self.reader.remaining() == 0:
            return Optional[MsgpackValue](None)
        if self.count >= MAX_COUNT:
            raise DecodeError(DecodeError.KIND_RANGE, self.reader.position())
        var v = MsgpackValue()
        v.root = decode_item(self.reader, v)
        self.count += 1
        return Optional[MsgpackValue](v^)

    def skip(mut self) raises DecodeError -> Bool:
        if self.reader.remaining() == 0:
            return False
        if self.count >= MAX_COUNT:
            raise DecodeError(DecodeError.KIND_RANGE, self.reader.position())
        self.reader.skip_value()
        self.count += 1
        return True


def encode_stream(
    items: List[MsgpackValue], options: EncodeOptions = EncodeOptions.default
) raises DecodeError -> List[Byte]:
    var w = WireWriter(capacity=256, exact=True)
    var i = 0
    while i < len(items):
        encode_item(items[i], items[i].root, w)
        i += 1
    _ = options
    return w^.finish()
