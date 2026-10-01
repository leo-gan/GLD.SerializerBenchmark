from std.collections import List

from smile_runtime.doc import (
    K_ARRAY,
    K_BIGINT,
    K_BINARY,
    K_BOOL,
    K_DECIMAL,
    K_F32,
    K_F64,
    K_I32,
    K_I64,
    K_NULL,
    K_OBJECT,
    K_STRING,
    SmileDoc,
)
from smile_runtime.error import DecodeError
from smile_runtime.numtext import dec_to_tc, format_decimal, parse_decimal, parse_decimal_scale, tc_to_dec


def find_field(doc: SmileDoc, obj: Int, key: String) -> Int:
    """First field named `key`, or -1. Later duplicates stay in the document and are ignored here."""
    var n = doc.nodes[obj]
    if n.kind != K_OBJECT:
        return -1
    var i = 0
    while i < n.nchild:
        var e = doc.edges[n.child + i]
        if doc.texts[e.key] == key:
            return e.val
        i += 1
    return -1


def array_len(doc: SmileDoc, id: Int) -> Int:
    return doc.nodes[id].nchild


def array_at(doc: SmileDoc, id: Int, index: Int) -> Int:
    return doc.edges[doc.nodes[id].child + index].val


def put_i64(mut doc: SmileDoc, obj: Int, key: String, v: Int):
    doc.add_field(obj, doc._text(key), doc.add_i64(v))


def put_f64(mut doc: SmileDoc, obj: Int, key: String, v: Float64):
    doc.add_field(obj, doc._text(key), doc.add_f64(v))


def put_bool(mut doc: SmileDoc, obj: Int, key: String, v: Bool):
    doc.add_field(obj, doc._text(key), doc.add_bool(v))


def put_str(mut doc: SmileDoc, obj: Int, key: String, v: String):
    doc.add_field(obj, doc._text(key), doc.add_string(v))


def put_bytes(mut doc: SmileDoc, obj: Int, key: String, v: List[Byte]):
    var copy = List[Byte]()
    var i = 0
    while i < len(v):
        copy.append(v[i])
        i += 1
    doc.add_field(obj, doc._text(key), doc.add_binary(copy^))


def put_bigint(mut doc: SmileDoc, obj: Int, key: String, text: String) raises DecodeError:
    doc.add_field(obj, doc._text(key), doc.add_bigint(dec_to_tc(text)))


def put_decimal(mut doc: SmileDoc, obj: Int, key: String, text: String) raises DecodeError:
    var scale = parse_decimal_scale(text)
    var mag = parse_decimal(text)
    doc.add_field(obj, doc._text(key), doc.add_decimal(scale, mag^))


def read_i64(doc: SmileDoc, id: Int) raises DecodeError -> Int:
    var n = doc.nodes[id]
    if n.kind == K_I32 or n.kind == K_I64:
        return n.a
    if n.kind == K_BIGINT:
        return _dec_to_int(tc_to_dec(doc.slice_copy(n.a)))
    raise DecodeError(DecodeError.KIND_TYPE, 0)


def _dec_to_int(text: String) raises DecodeError -> Int:
    if text == "-9223372036854775808":
        return Int(UInt64(1) << 63)
    var raw = text.as_bytes()
    var i = 0
    var neg = False
    if len(raw) > 0 and Int(raw[0]) == 45:
        neg = True
        i = 1
    if i >= len(raw):
        raise DecodeError(DecodeError.KIND_SYNTAX, 0)
    var v = 0
    while i < len(raw):
        var c = Int(raw[i])
        if c < 48 or c > 57:
            raise DecodeError(DecodeError.KIND_SYNTAX, i)
        var d = c - 48
        if v > 922337203685477580 or (v == 922337203685477580 and d > 7):
            raise DecodeError(DecodeError.KIND_RANGE, i)
        v = v * 10 + d
        i += 1
    if neg:
        return -v
    return v


def read_f64(doc: SmileDoc, id: Int) raises DecodeError -> Float64:
    var n = doc.nodes[id]
    if n.kind == K_F64:
        return Float64(from_bits=doc.f64s[n.a])
    if n.kind == K_F32:
        return Float64(Float32(from_bits=UInt32(n.a)))
    if n.kind == K_I32 or n.kind == K_I64:
        return Float64(n.a)
    raise DecodeError(DecodeError.KIND_TYPE, 0)


def read_bool(doc: SmileDoc, id: Int) raises DecodeError -> Bool:
    if doc.nodes[id].kind != K_BOOL:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    return doc.nodes[id].a != 0


def read_str(doc: SmileDoc, id: Int) raises DecodeError -> String:
    if doc.nodes[id].kind != K_STRING:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    return doc.texts[doc.nodes[id].a]


def read_bytes(doc: SmileDoc, id: Int) raises DecodeError -> List[Byte]:
    if doc.nodes[id].kind != K_BINARY:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    return doc.slice_copy(doc.nodes[id].a)


def read_bigint(doc: SmileDoc, id: Int) raises DecodeError -> String:
    var n = doc.nodes[id]
    if n.kind == K_BIGINT:
        return tc_to_dec(doc.slice_copy(n.a))
    if n.kind == K_I32 or n.kind == K_I64:
        return String(n.a)
    raise DecodeError(DecodeError.KIND_TYPE, 0)


def read_decimal(doc: SmileDoc, id: Int) raises DecodeError -> String:
    var n = doc.nodes[id]
    if n.kind == K_DECIMAL:
        return format_decimal(n.a, doc.slice_copy(n.b))
    if n.kind == K_I32 or n.kind == K_I64:
        return String(n.a)
    raise DecodeError(DecodeError.KIND_TYPE, 0)


def is_null(doc: SmileDoc, id: Int) -> Bool:
    return id < 0 or doc.nodes[id].kind == K_NULL


def is_array(doc: SmileDoc, id: Int) -> Bool:
    return doc.nodes[id].kind == K_ARRAY


def is_object(doc: SmileDoc, id: Int) -> Bool:
    return doc.nodes[id].kind == K_OBJECT
