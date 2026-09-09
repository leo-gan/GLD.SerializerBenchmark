from std.collections import List, Span

from gldjson_runtime.error import DecodeError
from gldjson_runtime.options import DecodeOptions, EncodeOptions
from gldjson_runtime.value import JsonValue, decode_value, encode_value
from gldjson_wire.number import encoded_float_len, encoded_int_len
from gldjson_wire.reader import WireReader
from gldjson_wire.string import encoded_string_len
from gldjson_wire.writer import WireWriter


trait JsonDatum(Copyable, Movable, Defaultable, Deinitable):
    def encoded_len(self, options: EncodeOptions) -> Int:
        ...

    def encode_to(self, mut w: WireWriter, options: EncodeOptions):
        ...

    def decode_from[
        origin: ImmOrigin
    ](mut self, mut r: WireReader[origin]) raises DecodeError:
        ...


def encode[
    T: JsonDatum
](value: T, options: EncodeOptions = EncodeOptions.compact) -> List[Byte]:
    # Skip encoded_len on the hot path (glaze / yyjson: one write into a
    # reused or over-sized buffer). 256 bytes covers every n=1 suite type.
    var cap = 256
    if options.mode == EncodeOptions.PRETTY:
        cap = 512
    var w = WireWriter(capacity=cap, exact=True)
    value.encode_to(w, options)
    return w^.finish()


def encode_into[
    T: JsonDatum
](
    value: T, mut dest: List[Byte], options: EncodeOptions = EncodeOptions.compact
) -> Int:
    """Write into `dest`, reusing its allocation. Returns the byte count."""
    var cap = len(dest)
    if cap < 64:
        cap = 256
        dest.resize(unsafe_uninit_length=cap)
    var w = WireWriter(dest^, pos=0)
    value.encode_to(w, options)
    var n = w.pos
    dest = w^.finish()
    return n


def decode[
    T: JsonDatum, origin: ImmOrigin
](
    buf: Span[Byte, origin], options: DecodeOptions = DecodeOptions.default
) raises DecodeError -> T:
    var msg = T()
    var r = WireReader[origin](buf, options)
    msg.decode_from(r)
    if r.pos != len(r.data):
        r.skip_ws()
        if r.remaining() > 0:
            raise DecodeError(DecodeError.KIND_TRAILING, r.position())
    return msg^


def to_value[T: JsonDatum](value: T) raises DecodeError -> JsonValue:
    return decode_value(encode(value))


def from_value[T: JsonDatum](v: JsonValue) raises DecodeError -> T:
    return decode[T](encode_value(v))


def read_bool[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Bool:
    var c = r.peek()
    if c == 116:
        r.read_true_here()
        return True
    if c == 102:
        r.read_false_here()
        return False
    raise DecodeError(DecodeError.KIND_TYPE, r.position())


def read_bool_here[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Bool:
    if r.pos >= len(r.data):
        raise DecodeError(DecodeError.KIND_EOF, r.pos)
    var c = Int(r.data[r.pos])
    if c == 116:
        r.read_true_here()
        return True
    if c == 102:
        r.read_false_here()
        return False
    raise DecodeError(DecodeError.KIND_TYPE, r.pos)


def read_float[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Float64:
    var tok = r.read_number()
    if tok.is_int:
        return Float64(tok.i)
    return tok.f


def read_float_here[origin: ImmOrigin](mut r: WireReader[origin]) raises DecodeError -> Float64:
    var tok = r.read_number_here()
    if tok.is_int:
        return Float64(tok.i)
    return tok.f


def write_float_list(mut w: WireWriter, items: List[Float64], options: EncodeOptions):
    w.write_byte(Byte(91))
    var i = 0
    if options.mode != EncodeOptions.PRETTY:
        while i < len(items):
            if i > 0:
                w.write_byte(Byte(44))
            w.write_float(items[i])
            i += 1
        w.write_byte(Byte(93))
        return
    while i < len(items):
        w.write_member_sep(options, i == 0)
        w.write_float(items[i])
        i += 1
    if len(items) > 0:
        w.write_byte(Byte(10))
        w.write_indent(options)
    w.write_byte(Byte(93))


def write_int_list(mut w: WireWriter, items: List[Int64], options: EncodeOptions):
    w.write_byte(Byte(91))
    var i = 0
    if options.mode != EncodeOptions.PRETTY:
        while i < len(items):
            if i > 0:
                w.write_byte(Byte(44))
            w.write_int(items[i])
            i += 1
        w.write_byte(Byte(93))
        return
    while i < len(items):
        w.write_member_sep(options, i == 0)
        w.write_int(items[i])
        i += 1
    if len(items) > 0:
        w.write_byte(Byte(10))
        w.write_indent(options)
    w.write_byte(Byte(93))


def write_string_list(mut w: WireWriter, items: List[String], options: EncodeOptions):
    w.write_byte(Byte(91))
    var i = 0
    if options.mode != EncodeOptions.PRETTY:
        while i < len(items):
            if i > 0:
                w.write_byte(Byte(44))
            w.write_string(items[i])
            i += 1
        w.write_byte(Byte(93))
        return
    while i < len(items):
        w.write_member_sep(options, i == 0)
        w.write_string(items[i])
        i += 1
    if len(items) > 0:
        w.write_byte(Byte(10))
        w.write_indent(options)
    w.write_byte(Byte(93))


def read_float_list[
    origin: ImmOrigin
](mut r: WireReader[origin]) raises DecodeError -> List[Float64]:
    var out = List[Float64](capacity=32)
    r.eat(91)
    if r.peek() == 93:
        r.eat(93)
        return out^
    while True:
        out.append(read_float_here(r))
        if r.pos < len(r.data):
            var c = Int(r.data[r.pos])
            if c == 93:
                r.pos += 1
                return out^
            if c == 44:
                r.pos += 1
                continue
        var s = r.peek()
        if s == 93:
            r.eat(93)
            return out^
        if s != 44:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
        r.eat(44)


def read_int_list[
    origin: ImmOrigin
](mut r: WireReader[origin]) raises DecodeError -> List[Int64]:
    var out = List[Int64](capacity=32)
    r.eat(91)
    if r.peek() == 93:
        r.eat(93)
        return out^
    while True:
        out.append(r.read_int_here())
        if r.pos < len(r.data):
            var c = Int(r.data[r.pos])
            if c == 93:
                r.pos += 1
                return out^
            if c == 44:
                r.pos += 1
                continue
        var s = r.peek()
        if s == 93:
            r.eat(93)
            return out^
        if s != 44:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
        r.eat(44)


def read_string_list[
    origin: ImmOrigin
](mut r: WireReader[origin]) raises DecodeError -> List[String]:
    var out = List[String](capacity=32)
    r.eat(91)
    if r.peek() == 93:
        r.eat(93)
        return out^
    while True:
        out.append(r.read_string_here())
        if r.pos < len(r.data):
            var c = Int(r.data[r.pos])
            if c == 93:
                r.pos += 1
                return out^
            if c == 44:
                r.pos += 1
                continue
        var s = r.peek()
        if s == 93:
            r.eat(93)
            return out^
        if s != 44:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
        r.eat(44)
