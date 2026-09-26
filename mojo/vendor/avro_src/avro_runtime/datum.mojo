from std.collections import List, Span

from avro_runtime.error import DecodeError
from avro_runtime.generic import GenericDatum
from avro_runtime.resolve import decode_resolving_generic
from avro_schema.canonical import canonical_form
from avro_schema.model import SchemaPool
from avro_schema.parse_avsc import parse_avsc
from avro_wire.reader import WireReader
from avro_wire.writer import WireWriter


trait AvroDatum(Copyable, Movable, Defaultable, Deinitable):
    def encoded_len(self) -> Int:
        ...

    def encode_to(self, mut enc: WireWriter):
        ...

    def decode_from[
        origin: ImmOrigin
    ](mut self, mut dec: WireReader[origin]) raises DecodeError:
        ...

    def schema_json(self) -> String:
        ...


def encode[T: AvroDatum](value: T) -> List[Byte]:
    var cap = value.encoded_len()
    if cap < 1:
        cap = 1
    var enc = WireWriter(capacity=cap)
    value.encode_to(enc)
    return enc^.finish()


def decode[
    T: AvroDatum, origin: ImmOrigin
](buf: Span[Byte, origin]) raises DecodeError -> T:
    var msg = T()
    var dec = WireReader[origin](buf)
    msg.decode_from(dec)
    return msg^


def convert_to[T: AvroDatum](datum: GenericDatum) raises DecodeError -> T:
    var want: String
    try:
        want = canonical_form(parse_avsc(T().schema_json()))
    except _:
        raise DecodeError(DecodeError.KIND_RESOLVE, 0)
    var got: String
    try:
        got = canonical_form(datum.pool)
    except _:
        raise DecodeError(DecodeError.KIND_RESOLVE, 0)
    if want != got:
        raise DecodeError(DecodeError.KIND_RESOLVE, 0)
    return decode[T](datum.encode())


def decode_resolving[
    T: AvroDatum, origin: ImmOrigin
](buf: Span[Byte, origin], writer_schema_json: String) raises DecodeError -> T:
    var writer: SchemaPool
    var reader: SchemaPool
    try:
        writer = parse_avsc(writer_schema_json)
        reader = parse_avsc(T().schema_json())
    except _:
        raise DecodeError(DecodeError.KIND_RESOLVE, 0)
    var g = decode_resolving_generic(buf, writer^, reader^)
    return convert_to[T](g)
