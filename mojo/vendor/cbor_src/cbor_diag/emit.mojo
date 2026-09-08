from std.collections import List

from cbor_runtime.value import (
    CK_ARRAY,
    CK_BYTES,
    CK_FALSE,
    CK_FLOAT16,
    CK_FLOAT32,
    CK_FLOAT64,
    CK_INT,
    CK_MAP,
    CK_NULL,
    CK_SIMPLE,
    CK_TAG,
    CK_TEXT,
    CK_TRUE,
    CK_UINT,
    CK_UNDEFINED,
    CborValue,
)
from cbor_wire.half import f32_from_bits, f64_from_bits, half_to_f64


def _hex_byte(b: Int) -> String:
    var digits = String("0123456789abcdef")
    var s = String()
    s += digits[byte = (b >> 4) & 15]
    s += digits[byte = b & 15]
    return s


def _escape_text(text: String) raises -> String:
    var b = text.as_bytes()
    var out = String("\"")
    for i in range(len(b)):
        var c = Int(b[i])
        if c == 34:
            out += "\\\""
        elif c == 92:
            out += "\\\\"
        elif c == 10:
            out += "\\n"
        elif c == 9:
            out += "\\t"
        else:
            out += String(from_utf8=b[i : i + 1])
    out += "\""
    return out


def _emit_node(v: CborValue, idx: Int) raises -> String:
    var n = v.nodes[idx]
    if n.kind == CK_INT:
        return String(n.a)
    if n.kind == CK_UINT:
        return String(n.b)
    if n.kind == CK_FALSE:
        return String("false")
    if n.kind == CK_TRUE:
        return String("true")
    if n.kind == CK_NULL:
        return String("null")
    if n.kind == CK_UNDEFINED:
        return String("undefined")
    if n.kind == CK_SIMPLE:
        return String("simple(") + String(n.a) + ")"
    if n.kind == CK_TEXT:
        return _escape_text(v.texts[Int(n.a)])
    if n.kind == CK_BYTES:
        var s = String("h'")
        var start = Int(n.a)
        var ln = Int(n.b)
        for i in range(ln):
            s += _hex_byte(Int(v.bytes[start + i]))
        s += "'"
        if (n.flags & 1) != 0:
            return String("(_ ") + s + ")"
        return s
    if n.kind == CK_FLOAT16:
        return String(half_to_f64(UInt16(n.b)))
    if n.kind == CK_FLOAT32:
        return String(Float64(f32_from_bits(UInt32(n.b))))
    if n.kind == CK_FLOAT64:
        return String(f64_from_bits(n.b))
    if n.kind == CK_TAG:
        return String(n.b) + "(" + _emit_node(v, n.c) + ")"
    if n.kind == CK_ARRAY:
        var out = String("[")
        if (n.flags & 1) != 0:
            out += "_ "
        var k0 = Int(n.a)
        var count = Int(n.b)
        for i in range(count):
            if i > 0:
                out += ", "
            out += _emit_node(v, v.kids[k0 + i])
        out += "]"
        return out
    if n.kind == CK_MAP:
        var outm = String("{")
        if (n.flags & 1) != 0:
            outm += "_ "
        var m0 = Int(n.a)
        var pairs = Int(n.b)
        for i in range(pairs):
            if i > 0:
                outm += ", "
            outm += _emit_node(v, v.kids[m0 + i * 2])
            outm += ": "
            outm += _emit_node(v, v.kids[m0 + i * 2 + 1])
        outm += "}"
        return outm
    return String("undefined")


def encode_diag(value: CborValue) raises -> String:
    return _emit_node(value, value.root)


def _spaces(n: Int) -> String:
    var s = String()
    for _i in range(n):
        s += " "
    return s


def _emit_pretty(v: CborValue, idx: Int, indent: Int, step: Int) raises -> String:
    var n = v.nodes[idx]
    if n.kind == CK_ARRAY:
        var count = Int(n.b)
        if count == 0:
            return String("[]")
        var out = String("[\n")
        var k0 = Int(n.a)
        var next = indent + step
        for i in range(count):
            out += _spaces(next)
            out += _emit_pretty(v, v.kids[k0 + i], next, step)
            if i + 1 < count:
                out += ","
            out += "\n"
        out += _spaces(indent)
        out += "]"
        return out
    if n.kind == CK_MAP:
        var pairs = Int(n.b)
        if pairs == 0:
            return String("{}")
        var outm = String("{\n")
        var m0 = Int(n.a)
        var nextm = indent + step
        for i in range(pairs):
            outm += _spaces(nextm)
            outm += _emit_pretty(v, v.kids[m0 + i * 2], nextm, step)
            outm += ": "
            outm += _emit_pretty(v, v.kids[m0 + i * 2 + 1], nextm, step)
            if i + 1 < pairs:
                outm += ","
            outm += "\n"
        outm += _spaces(indent)
        outm += "}"
        return outm
    if n.kind == CK_TAG:
        return String(n.b) + "(" + _emit_pretty(v, n.c, indent, step) + ")"
    return _emit_node(v, idx)


def encode_diag_pretty(value: CborValue, indent: Int = 2) raises -> String:
    """Diagnostic notation with one item per line inside arrays and maps."""
    var step = indent
    if step < 1:
        step = 2
    return _emit_pretty(value, value.root, 0, step)
