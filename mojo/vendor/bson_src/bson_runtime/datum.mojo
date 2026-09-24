from std.collections import List, Span

from bson_runtime.error import DecodeError
from bson_wire.reader import WireReader
from bson_wire.writer import WireWriter


trait BsonDatum(Movable, Defaultable, Deinitable):
    def encoded_len(self) -> Int:
        ...

    def encode_to(self, mut w: WireWriter):
        ...

    def decode_from[origin: ImmOrigin](mut self, mut r: WireReader[origin]) raises DecodeError:
        ...


def encode[T: BsonDatum](value: T) -> List[Byte]:
    var cap = value.encoded_len()
    if cap < 5:
        cap = 5
    var w = WireWriter(capacity=cap)
    value.encode_to(w)
    return w^.finish()


def decode[T: BsonDatum, origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> T:
    var msg = T()
    var r = WireReader[origin](buf)
    msg.decode_from(r)
    var left = r.remaining()
    if left != 0:
        var _drop = msg^
        raise DecodeError(DecodeError.KIND_TRAILING, r.pos, left)
    return msg^
