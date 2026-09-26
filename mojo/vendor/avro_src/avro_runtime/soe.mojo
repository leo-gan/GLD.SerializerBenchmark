from std.collections import List, Span

from avro_runtime.datum import AvroDatum, decode, decode_resolving, encode
from avro_runtime.error import DecodeError
from avro_schema.canonical import canonical_form
from avro_schema.fingerprint import crc64_avro
from avro_schema.parse_avsc import parse_avsc


def encode_single_object[T: AvroDatum](value: T) raises DecodeError -> List[Byte]:
    var payload = encode(value)
    var pcf: String
    try:
        pcf = canonical_form(parse_avsc(value.schema_json()))
    except _:
        raise DecodeError(DecodeError.KIND_SOE, 0)
    var fp = crc64_avro(pcf)
    var out = List[Byte]()
    out.append(Byte(0xC3))
    out.append(Byte(0x01))
    var i = 0
    while i < 8:
        out.append(Byte(Int((fp >> (UInt64(i) * 8)) & 0xFF)))
        i += 1
    var j = 0
    while j < len(payload):
        out.append(payload[j])
        j += 1
    return out^


def soe_fingerprint[
    origin: ImmOrigin
](buf: Span[Byte, origin]) raises DecodeError -> UInt64:
    if len(buf) < 10:
        raise DecodeError(DecodeError.KIND_SOE, 0)
    if Int(buf[0]) != 0xC3 or Int(buf[1]) != 0x01:
        raise DecodeError(DecodeError.KIND_SOE, 0)
    var fp: UInt64 = 0
    var i = 0
    while i < 8:
        fp |= UInt64(buf[2 + i]) << UInt64(i * 8)
        i += 1
    return fp


def decode_single_object[
    T: AvroDatum, origin: ImmOrigin
](buf: Span[Byte, origin]) raises DecodeError -> T:
    var fp = soe_fingerprint(buf)
    var want: UInt64
    try:
        want = crc64_avro(canonical_form(parse_avsc(T().schema_json())))
    except _:
        raise DecodeError(DecodeError.KIND_SOE, 0)
    if fp != want:
        raise DecodeError(DecodeError.KIND_SOE, 2)
    return decode[T, origin](buf[10:])


def decode_single_object[
    T: AvroDatum, origin: ImmOrigin
](buf: Span[Byte, origin], writer_schema_json: String) raises DecodeError -> T:
    var fp = soe_fingerprint(buf)
    var want: UInt64
    try:
        want = crc64_avro(canonical_form(parse_avsc(writer_schema_json)))
    except _:
        raise DecodeError(DecodeError.KIND_SOE, 0)
    if fp != want:
        raise DecodeError(DecodeError.KIND_SOE, 2)
    return decode_resolving[T, origin](buf[10:], writer_schema_json)
