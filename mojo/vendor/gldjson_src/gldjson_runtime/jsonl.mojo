from std.collections import List, Span

from gldjson_runtime.datum import JsonDatum, decode, encode
from gldjson_runtime.error import DecodeError
from gldjson_runtime.options import DecodeOptions
from gldjson_runtime.value import JsonValue, decode_item, encode_value
from gldjson_wire.classify import MAX_COUNT, is_ws
from gldjson_wire.reader import WireReader
from gldjson_wire.writer import WireWriter


def encode_jsonl[T: JsonDatum](items: List[T]) -> List[Byte]:
    var out = List[Byte]()
    var i = 0
    while i < len(items):
        var rec = encode(items[i])
        var j = 0
        while j < len(rec):
            out.append(rec[j])
            j += 1
        out.append(Byte(10))
        i += 1
    return out^


def encode_jsonl_values(items: List[JsonValue]) -> List[Byte]:
    var out = List[Byte]()
    var i = 0
    while i < len(items):
        var rec = encode_value(items[i])
        var j = 0
        while j < len(rec):
            out.append(rec[j])
            j += 1
        out.append(Byte(10))
        i += 1
    return out^


def decode_jsonl[
    T: JsonDatum, origin: ImmOrigin
](
    buf: Span[Byte, origin], options: DecodeOptions = DecodeOptions.default
) raises DecodeError -> List[T]:
    var out = List[T]()
    var r = WireReader[origin](buf, options)
    while True:
        _skip_blank_lines(r)
        if r.remaining() == 0:
            return out^
        if len(out) >= MAX_COUNT:
            raise DecodeError(DecodeError.KIND_RANGE, r.position())
        var item = T()
        item.decode_from(r)
        out.append(item^)


def decode_jsonl_values[
    origin: ImmOrigin
](
    buf: Span[Byte, origin], options: DecodeOptions = DecodeOptions.default
) raises DecodeError -> List[JsonValue]:
    var out = List[JsonValue]()
    var r = WireReader[origin](buf, options)
    while True:
        _skip_blank_lines(r)
        if r.remaining() == 0:
            return out^
        if len(out) >= MAX_COUNT:
            raise DecodeError(DecodeError.KIND_RANGE, r.position())
        var v = JsonValue()
        v.root = decode_item(r, v)
        out.append(v^)


def _skip_blank_lines[
    origin: ImmOrigin
](mut r: WireReader[origin]) raises DecodeError:
    while r.pos < len(r.data):
        var c = Int(r.data[r.pos])
        if c == 10 or c == 13 or is_ws(c):
            r.pos += 1
            continue
        return
