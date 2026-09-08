from std.collections import List, Span

from pb_runtime.error import DecodeError
from pb_wire.reader import WireReader
from pb_wire.writer import WireWriter


trait ProtoMessage(Copyable, Movable, Defaultable, Deinitable):
    def encoded_len(self) -> Int:
        ...

    def encode_to(self, mut enc: WireWriter):
        ...

    def merge_from[
        origin: ImmOrigin
    ](mut self, mut dec: WireReader[origin]) raises DecodeError:
        ...


def encode[T: ProtoMessage](msg: T) -> List[Byte]:
    var cap = msg.encoded_len()
    if cap < 1:
        cap = 1
    var enc = WireWriter(capacity=cap)
    msg.encode_to(enc)
    return enc^.finish()


def decode[
    T: ProtoMessage, origin: ImmOrigin
](buf: Span[Byte, origin]) raises DecodeError -> T:
    var msg = T()
    var dec = WireReader[origin](buf)
    msg.merge_from(dec)
    return msg^
