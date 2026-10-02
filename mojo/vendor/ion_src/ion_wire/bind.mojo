from std.collections import List, Span

from ion_runtime.doc import (
    K_BLOB,
    K_BOOL,
    K_CLOB,
    K_FLOAT,
    K_INT,
    K_LIST,
    K_STRING,
    K_STRUCT,
    IonDoc,
)
from ion_runtime.error import DecodeError
from ion_runtime.symtab import Catalog
from ion_wire.binary import decode_binary
from ion_wire.text import adopt_text, decode_text
from ion_wire.writer import format_value


def decode_any[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> IonDoc:
    """Decode a binary datagram when the bytes start with an Ion version marker, otherwise text."""
    var cat = Catalog()
    if (
        len(raw) >= 4
        and Int(raw[0]) == 0xE0
        and Int(raw[1]) == 0x01
        and Int(raw[3]) == 0xEA
    ):
        return decode_binary(raw, cat)
    return decode_text(raw, cat)


def field_name(doc: IonDoc, id: Int, index: Int) -> String:
    var sym = doc.field_at(id, index)
    if sym < 0:
        return String()
    return doc.sym_text(sym)


def as_i64(doc: IonDoc, id: Int) raises DecodeError -> Int64:
    var n = doc.nodes[id]
    if n.kind != K_INT:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    if n.b > 2:
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    if n.b == 0:
        return Int64(0)
    var mag = UInt64(doc.limbs[n.a])
    if n.b == 2:
        mag = mag | (UInt64(doc.limbs[n.a + 1]) << UInt64(32))
    if n.c != 0:
        if mag > (UInt64(1) << UInt64(63)):
            raise DecodeError(DecodeError.KIND_RANGE, 0)
        if mag == (UInt64(1) << UInt64(63)):
            return Int64(0) - Int64(1) - Int64(9223372036854775807)
        return Int64(0) - Int64(mag)
    if mag > UInt64(9223372036854775807):
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    return Int64(mag)


def as_bool(doc: IonDoc, id: Int) raises DecodeError -> Bool:
    var n = doc.nodes[id]
    if n.kind != K_BOOL:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    return n.a != 0


def as_string(doc: IonDoc, id: Int) raises DecodeError -> String:
    if doc.nodes[id].kind != K_STRING:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    return doc.text_at(id)


def as_f64(doc: IonDoc, id: Int) raises DecodeError -> Float64:
    var n = doc.nodes[id]
    if n.kind != K_FLOAT:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    var bits = doc.floats[n.b]
    if n.a == 0:
        return Float64(0)
    if n.a == 4:
        return Float64(Float32(from_bits=UInt32(bits)))
    if n.a == 8:
        return Float64(from_bits=bits)
    if n.a == 2:
        return _f16(UInt16(bits))
    raise DecodeError(DecodeError.KIND_TYPE, 0)


def as_bytes(doc: IonDoc, id: Int, kind: Int) raises DecodeError -> List[Byte]:
    var n = doc.nodes[id]
    if n.kind != kind:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    var out = List[Byte]()
    var i = 0
    while i < doc.blob_len[n.a]:
        out.append(doc.blob_bytes[doc.blob_at[n.a] + i])
        i += 1
    return out^


def ion_text(doc: IonDoc, id: Int, expect: Int) raises DecodeError -> String:
    if expect != 0 and doc.nodes[id].kind != expect:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    return format_value(doc, id)


def parse_ion(mut doc: IonDoc, text: String, expect: Int) raises DecodeError -> Int:
    var id = adopt_text(doc, text)
    if expect != 0 and doc.nodes[id].kind != expect:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    return id


def _f16(h: UInt16) -> Float64:
    var sign = UInt64(h & UInt16(0x8000)) << UInt64(48)
    var exp = Int((h & UInt16(0x7C00)) >> UInt16(10))
    var frac = UInt64(h & UInt16(0x03FF))
    if exp == 0:
        if frac == UInt64(0):
            return Float64(from_bits=sign)
        exp = 1
        while (frac & UInt64(0x0400)) == UInt64(0):
            frac = frac << UInt64(1)
            exp -= 1
        frac = frac & UInt64(0x03FF)
    if exp == 31:
        var bits = sign | (UInt64(0x7FF) << UInt64(52)) | (frac << UInt64(42))
        return Float64(from_bits=bits)
    var e = UInt64(exp + (1023 - 15))
    var bits = sign | (e << UInt64(52)) | (frac << UInt64(42))
    return Float64(from_bits=bits)


def _blob_kind() -> Int:
    return K_BLOB


def _clob_kind() -> Int:
    return K_CLOB


def _struct_kind() -> Int:
    return K_STRUCT


def _list_kind() -> Int:
    return K_LIST
