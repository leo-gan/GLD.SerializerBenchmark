from std.collections import List, Span

from yaml_runtime.error import DecodeError
from yaml_runtime.options import DecodeOptions, EncodeOptions
from yaml_runtime.value import YamlValue, decode_value, encode_value
from yaml_wire.number import encoded_float_len, encoded_int_len
from yaml_wire.reader import WireReader
from yaml_wire.scalar import encoded_string_len
from yaml_wire.writer import WireWriter


trait YamlDatum(Copyable, Movable, Defaultable, Deinitable):
    def encoded_len(self, options: EncodeOptions) -> Int:
        ...

    def encode_to(self, mut w: WireWriter, options: EncodeOptions):
        ...

    def decode_from[
        origin: ImmOrigin
    ](mut self, mut r: WireReader[origin]) raises DecodeError:
        ...


def encode[
    T: YamlDatum
](value: T, options: EncodeOptions = EncodeOptions.block) -> List[Byte]:
    # One write into a reused/over-sized buffer (glaze / yyjson / ryml).
    # 256 bytes covers the n=1 suite Message.
    var w = WireWriter(capacity=256, exact=True)
    value.encode_to(w, options)
    if w.pos == 0 or Int(w.buf[w.pos - 1]) != 10:
        w.write_lf()
    return w^.finish()


def encode_into[
    T: YamlDatum
](
    value: T, mut dest: List[Byte], options: EncodeOptions = EncodeOptions.block
) -> Int:
    var cap = len(dest)
    if cap < 256:
        cap = 256
        dest.resize(unsafe_uninit_length=cap)
    var w = WireWriter(dest^, pos=0)
    value.encode_to(w, options)
    if w.pos == 0 or Int(w.buf[w.pos - 1]) != 10:
        w.write_lf()
    var n = w.pos
    dest = w^.finish()
    return n


def decode[
    T: YamlDatum, origin: ImmOrigin
](
    buf: Span[Byte, origin], options: DecodeOptions = DecodeOptions.default
) raises DecodeError -> T:
    var msg = T()
    var r = WireReader[origin](buf, options=options)
    r.skip_document_start()
    msg.decode_from(r)
    r.skip_document_end()
    r.skip_separation()
    if r.remaining() > 0 and not r.at_document_end():
        raise DecodeError(DecodeError.KIND_TRAILING, r.position())
    return msg^


def to_value[T: YamlDatum](value: T) raises DecodeError -> YamlValue:
    return decode_value(encode(value))


def from_value[T: YamlDatum](v: YamlValue) raises DecodeError -> T:
    return decode[T](encode_value(v))


def read_bool[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Bool:
    return r.read_bool()


def read_float[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Float64:
    return r.read_as_f64()


def write_float_list(mut w: WireWriter, items: List[Float64], options: EncodeOptions):
    if options.is_flow() or True:
        var i = 0
        while i < len(items):
            if i > 0:
                w.write_lf()
            w.write_indent(options)
            w.write_ascii("- ")
            w.write_float(items[i])
            i += 1


def write_int_list(mut w: WireWriter, items: List[Int64], options: EncodeOptions):
    var i = 0
    while i < len(items):
        if i > 0:
            w.write_lf()
        w.write_indent(options)
        w.write_ascii("- ")
        w.write_int(items[i])
        i += 1


def write_string_list(mut w: WireWriter, items: List[String], options: EncodeOptions):
    var i = 0
    while i < len(items):
        if i > 0:
            w.write_lf()
        w.write_indent(options)
        w.write_ascii("- ")
        w.write_string(items[i], options)
        i += 1


def read_float_list[
    origin: ImmOrigin
](mut r: WireReader[origin]) raises DecodeError -> List[Float64]:
    var out = List[Float64]()
    var st = r.begin_seq()
    while r.next_item(st):
        out.append(r.read_as_f64())
    r.end_seq(st)
    return out^


def read_int_list[
    origin: ImmOrigin
](mut r: WireReader[origin]) raises DecodeError -> List[Int64]:
    var out = List[Int64]()
    var st = r.begin_seq()
    while r.next_item(st):
        out.append(r.read_int())
    r.end_seq(st)
    return out^


def read_string_list[
    origin: ImmOrigin
](mut r: WireReader[origin]) raises DecodeError -> List[String]:
    var out = List[String]()
    var st = r.begin_seq()
    while r.next_item(st):
        out.append(r.read_string())
    r.end_seq(st)
    return out^
