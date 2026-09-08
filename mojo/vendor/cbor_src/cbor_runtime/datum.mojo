from std.collections import List, Span

from cbor_runtime.error import DecodeError
from cbor_runtime.options import EncodeOptions
from cbor_wire.reader import WireReader
from cbor_wire.writer import WireWriter


trait CborDatum(Copyable, Movable, Defaultable, Deinitable):
    def encoded_len(self, options: EncodeOptions) -> Int:
        ...

    def encode_to(self, mut w: WireWriter, options: EncodeOptions):
        ...

    def decode_from[
        origin: ImmOrigin
    ](mut self, mut r: WireReader[origin]) raises DecodeError:
        ...


def encode[
    T: CborDatum
](value: T, options: EncodeOptions = EncodeOptions.preferred) -> List[Byte]:
    var cap = value.encoded_len(options)
    if cap < 1:
        cap = 1
    var w = WireWriter(capacity=cap, exact=True)
    value.encode_to(w, options)
    return w^.finish()


def encode_into[
    T: CborDatum
](
    value: T, mut dest: List[Byte], options: EncodeOptions = EncodeOptions.preferred
) -> Int:
    """Write into `dest`, reusing its allocation. Returns the byte count."""
    var cap = value.encoded_len(options)
    if cap < 1:
        cap = 1
    dest.resize(unsafe_uninit_length=cap)
    var w = WireWriter(dest^, pos=0)
    value.encode_to(w, options)
    var n = w.pos
    dest = w^.finish()
    return n


def decode[
    T: CborDatum, origin: ImmOrigin
](buf: Span[Byte, origin]) raises DecodeError -> T:
    var msg = T()
    var r = WireReader[origin](buf)
    msg.decode_from(r)
    if r.remaining() > 0:
        raise DecodeError(DecodeError.KIND_TRAILING, r.position())
    return msg^
