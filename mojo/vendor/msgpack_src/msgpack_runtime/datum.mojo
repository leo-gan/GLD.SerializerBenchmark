from std.collections import List, Span

from msgpack_runtime.error import DecodeError
from msgpack_runtime.options import DecodeOptions, EncodeOptions
from msgpack_runtime.value import MsgpackValue, decode_value, encode_value
from msgpack_wire.reader import WireReader
from msgpack_wire.writer import WireWriter


trait MsgpackDatum(Copyable, Movable, Defaultable, Deinitable):
    def encoded_len(self, options: EncodeOptions) -> Int:
        ...

    def encode_to(self, mut w: WireWriter, options: EncodeOptions):
        ...

    def decode_from[
        origin: ImmOrigin
    ](mut self, mut r: WireReader[origin]) raises DecodeError:
        ...


def encode[
    T: MsgpackDatum
](value: T, options: EncodeOptions = EncodeOptions.default) -> List[Byte]:
    var cap = value.encoded_len(options)
    if cap < 16:
        cap = 16
    var w = WireWriter(capacity=cap, exact=True)
    value.encode_to(w, options)
    return w^.finish()


def encode_into[
    T: MsgpackDatum
](
    value: T, mut dest: List[Byte], options: EncodeOptions = EncodeOptions.default
) -> Int:
    """Write into `dest`, reusing its allocation. Returns the byte count.

    `dest` is grown to at least 512 bytes and is not shrunk. Callers must
    use the returned count as the live prefix.
    """
    var need = value.encoded_len(options) + 16
    if need < 512:
        need = 512
    if len(dest) < need:
        dest.resize(unsafe_uninit_length=need)
    var w = WireWriter(dest^, pos=0)
    value.encode_to(w, options)
    var n = w.pos
    dest = w^.finish_keep()
    return n


def decode[
    T: MsgpackDatum, origin: ImmOrigin
](
    buf: Span[Byte, origin], options: DecodeOptions = DecodeOptions.default
) raises DecodeError -> T:
    var msg = T()
    var r = WireReader[origin](buf, options)
    msg.decode_from(r)
    if r.remaining() > 0:
        raise DecodeError(DecodeError.KIND_TRAILING, r.position())
    return msg^
