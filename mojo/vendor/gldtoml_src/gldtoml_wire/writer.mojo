from std.collections import List

from gldtoml_runtime.error import DecodeError
from gldtoml_runtime.options import EncodeOptions
from gldtoml_wire.doc import (
    DT_DATE,
    DT_LOCAL,
    DT_OFFSET,
    DT_TIME,
    TK_ARRAY,
    TK_DATETIME,
    TK_FALSE,
    TK_FLOAT,
    TK_INT,
    TK_STRING,
    TK_TABLE,
    TK_TRUE,
    TomlDateTime,
    TomlDoc,
)
from gldtoml_wire.utf8 import string_from_bytes


def encode_toml(
    doc: TomlDoc, options: EncodeOptions = EncodeOptions.standard
) raises DecodeError -> String:
    if doc.kind(doc.root) != TK_TABLE:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    var out = List[Byte](capacity=128)
    var prefix = List[String]()
    _write_body(doc, doc.root, prefix, options, out, False)
    if len(out) == 0 or Int(out[len(out) - 1]) != 10:
        out.append(Byte(10))
    return string_from_bytes(out^, 0)


def _write_body(
    doc: TomlDoc,
    node: Int,
    prefix: List[String],
    options: EncodeOptions,
    mut out: List[Byte],
    as_inline: Bool,
) raises DecodeError:
    if as_inline or (options.inline_tables and node != doc.root):
        _write_inline_table(doc, node, options, out)
        return
    var e = doc.first_edge(node)
    while e >= 0:
        var edge = doc.edges[e]
        var child = edge.child
        var k = doc.kind(child)
        var write_here: Bool
        if k == TK_TABLE:
            write_here = options.inline_tables
        elif k == TK_ARRAY and _is_aot(doc, child, options):
            write_here = False
        else:
            write_here = True
        if write_here:
            if len(out) > 0 and Int(out[len(out) - 1]) != 10:
                out.append(Byte(10))
            _write_key(out, doc.texts[edge.key])
            _write_ascii(out, " = ")
            if k == TK_TABLE:
                _write_inline_table(doc, child, options, out)
            else:
                _write_value(doc, child, options, out)
            out.append(Byte(10))
        e = edge.next
    if options.inline_tables:
        return
    e = doc.first_edge(node)
    while e >= 0:
        var edge = doc.edges[e]
        var child = edge.child
        if doc.kind(child) == TK_TABLE:
            var sub = _extend(prefix, doc.texts[edge.key])
            if len(out) > 0 and Int(out[len(out) - 1]) != 10:
                out.append(Byte(10))
            out.append(Byte(10))
            out.append(Byte(91))
            _write_dotted(out, sub)
            out.append(Byte(93))
            out.append(Byte(10))
            _write_body(doc, child, sub, options, out, False)
        elif _is_aot(doc, child, options):
            var sub = _extend(prefix, doc.texts[edge.key])
            var ae = doc.first_edge(child)
            while ae >= 0:
                if len(out) > 0 and Int(out[len(out) - 1]) != 10:
                    out.append(Byte(10))
                out.append(Byte(10))
                _write_ascii(out, "[[")
                _write_dotted(out, sub)
                _write_ascii(out, "]]\n")
                _write_body(doc, doc.edges[ae].child, sub, options, out, False)
                ae = doc.edges[ae].next
        e = edge.next


def _is_aot(doc: TomlDoc, node: Int, options: EncodeOptions) -> Bool:
    if options.inline_tables or options.compact_arrays:
        return False
    if doc.kind(node) != TK_ARRAY or doc.child_count(node) == 0:
        return False
    var e = doc.first_edge(node)
    while e >= 0:
        if doc.kind(doc.edges[e].child) != TK_TABLE:
            return False
        e = doc.edges[e].next
    return True


def _write_inline_table(
    doc: TomlDoc, node: Int, options: EncodeOptions, mut out: List[Byte]
) raises DecodeError:
    var nested = False
    var e = doc.first_edge(node)
    while e >= 0:
        var k = doc.kind(doc.edges[e].child)
        if k == TK_TABLE or k == TK_ARRAY:
            nested = True
        e = edge_next(doc, e)
    out.append(Byte(123))
    if nested:
        out.append(Byte(10))
    var first = True
    e = doc.first_edge(node)
    while e >= 0:
        if not first:
            out.append(Byte(44))
            if nested:
                out.append(Byte(10))
            else:
                out.append(Byte(32))
        if nested:
            _write_ascii(out, "  ")
        _write_key(out, doc.texts[doc.edges[e].key])
        _write_ascii(out, " = ")
        _write_value(doc, doc.edges[e].child, options, out)
        first = False
        e = doc.edges[e].next
    if nested:
        out.append(Byte(44))
        out.append(Byte(10))
    out.append(Byte(125))


def edge_next(doc: TomlDoc, e: Int) -> Int:
    return doc.edges[e].next


def _write_value(
    doc: TomlDoc, node: Int, options: EncodeOptions, mut out: List[Byte]
) raises DecodeError:
    var k = doc.kind(node)
    if k == TK_STRING:
        _write_string(out, doc.text_at(node))
    elif k == TK_INT:
        append_int(out, doc.int_at(node))
    elif k == TK_FLOAT:
        append_float(out, doc.float_at(node))
    elif k == TK_TRUE:
        _write_ascii(out, "true")
    elif k == TK_FALSE:
        _write_ascii(out, "false")
    elif k == TK_DATETIME:
        _write_datetime(out, doc, node)
    elif k == TK_ARRAY:
        _write_array(doc, node, options, out)
    elif k == TK_TABLE:
        _write_inline_table(doc, node, options, out)
    else:
        raise DecodeError(DecodeError.KIND_TYPE, 0)


def _write_array(
    doc: TomlDoc, node: Int, options: EncodeOptions, mut out: List[Byte]
) raises DecodeError:
    out.append(Byte(91))
    var e = doc.first_edge(node)
    var first = True
    while e >= 0:
        if not first:
            _write_ascii(out, ", ")
        _write_value(doc, doc.edges[e].child, options, out)
        first = False
        e = doc.edges[e].next
    out.append(Byte(93))


def _write_datetime(mut out: List[Byte], doc: TomlDoc, node: Int):
    append_datetime(out, doc.date_at(node))


def _pad(mut out: List[Byte], v: Int, width: Int):
    var buf = List[Byte]()
    var n = v
    if n < 0:
        n = 0
    var k = 0
    while k < width:
        buf.append(Byte(48 + (n % 10)))
        n = n // 10
        k += 1
    var j = width - 1
    while j >= 0:
        out.append(buf[j])
        j -= 1


@always_inline
def append_ascii(mut out: List[Byte], text: String):
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        out.append(b[i])
        i += 1


@always_inline
def append_bool(mut out: List[Byte], v: Bool):
    if v:
        out.append(Byte(116))
        out.append(Byte(114))
        out.append(Byte(117))
        out.append(Byte(101))
    else:
        out.append(Byte(102))
        out.append(Byte(97))
        out.append(Byte(108))
        out.append(Byte(115))
        out.append(Byte(101))


@always_inline
def append_int(mut out: List[Byte], v: Int64):
    if v == Int64(0):
        out.append(Byte(48))
        return
    if v == Int64.MIN:
        append_ascii(out, "-9223372036854775808")
        return
    var neg = v < Int64(0)
    var x = v
    if neg:
        x = Int64(0) - v
        out.append(Byte(45))
    var digits = 1
    var div = Int64(1)
    var probe = x
    while probe >= Int64(10):
        probe = probe // Int64(10)
        div = div * Int64(10)
        digits += 1
    while digits > 0:
        var d = x // div
        out.append(Byte(48 + Int(d)))
        x = x - d * div
        div = div // Int64(10)
        digits -= 1


def _append_fixed(mut out: List[Byte], iv: Int64, scale: Int):
    var z = 0
    if iv == Int64(0):
        out.append(Byte(48))
        out.append(Byte(46))
        if scale == 0:
            out.append(Byte(48))
            return
        while z < scale:
            out.append(Byte(48))
            z += 1
        return
    if scale == 0:
        append_int(out, iv)
        out.append(Byte(46))
        out.append(Byte(48))
        return
    var nd = 0
    var t = iv
    while t > Int64(0):
        nd += 1
        t = t // Int64(10)
    if nd <= scale:
        out.append(Byte(48))
        out.append(Byte(46))
        while z < scale - nd:
            out.append(Byte(48))
            z += 1
        append_int(out, iv)
        return
    var div = Int64(1)
    var k = 1
    while k < nd:
        div = div * Int64(10)
        k += 1
    var x = iv
    var placed = 0
    var left = nd
    var int_digits = nd - scale
    while left > 0:
        if placed == int_digits:
            out.append(Byte(46))
        var d = x // div
        out.append(Byte(48 + Int(d)))
        x = x - d * div
        if div > Int64(1):
            div = div // Int64(10)
        left -= 1
        placed += 1


def append_float(mut out: List[Byte], v: Float64):
    var bits = UInt64(v.to_bits())
    var exp = (bits >> UInt64(52)) & UInt64(2047)
    if exp == UInt64(2047):
        if (bits & UInt64(4503599627370495)) != UInt64(0):
            append_ascii(out, "nan")
        elif (bits >> UInt64(63)) != UInt64(0):
            append_ascii(out, "-inf")
        else:
            append_ascii(out, "inf")
        return
    if bits == UInt64(9223372036854775808):
        append_ascii(out, "-0.0")
        return
    if bits == UInt64(0):
        append_ascii(out, "0.0")
        return
    var neg = (bits >> UInt64(63)) != UInt64(0)
    var x = v
    if neg:
        x = Float64(0) - v
    var scale = 0
    var scaled = x
    var limit = Float64(1000000000000000)
    while scale <= 12 and scaled == scaled and scaled < limit:
        var as_int = Int64(scaled)
        if Float64(as_int) == scaled:
            var back = Float64(as_int)
            var s = scale
            while s > 0:
                back = back / Float64(10)
                s -= 1
            if back == x:
                if neg:
                    out.append(Byte(45))
                _append_fixed(out, as_int, scale)
                return
        scaled = scaled * Float64(10)
        scale += 1
    append_ascii(out, String(v))


def append_toml_str(mut out: List[Byte], text: String):
    _write_string(out, text)


def append_datetime(mut out: List[Byte], dt: TomlDateTime):
    if dt.sub == DT_DATE or dt.sub == DT_OFFSET or dt.sub == DT_LOCAL:
        _pad(out, dt.year, 4)
        out.append(Byte(45))
        _pad(out, dt.month, 2)
        out.append(Byte(45))
        _pad(out, dt.day, 2)
    if dt.sub == DT_OFFSET or dt.sub == DT_LOCAL:
        out.append(Byte(84))
    if dt.sub == DT_OFFSET or dt.sub == DT_LOCAL or dt.sub == DT_TIME:
        _pad(out, dt.hour, 2)
        out.append(Byte(58))
        _pad(out, dt.minute, 2)
        out.append(Byte(58))
        _pad(out, dt.second, 2)
        if dt.nanos > 0:
            out.append(Byte(46))
            var scale = 100000000
            var n = dt.nanos
            var rest = n
            var k = 0
            while k < 9:
                var d = rest // scale
                out.append(Byte(48 + d))
                rest = rest - d * scale
                scale = scale // 10
                k += 1
                if rest == 0:
                    break
            _ = n
    if dt.sub == DT_OFFSET:
        if dt.offset_z:
            out.append(Byte(90))
        else:
            var m = dt.offset_minutes
            if m < 0:
                out.append(Byte(45))
                m = 0 - m
            else:
                out.append(Byte(43))
            _pad(out, m // 60, 2)
            out.append(Byte(58))
            _pad(out, m % 60, 2)


def _bare(key: String) -> Bool:
    var b = key.as_bytes()
    if len(b) == 0:
        return False
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        var ok = (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 45
        if not ok:
            return False
        i += 1
    return True


def _write_key(mut out: List[Byte], key: String):
    if _bare(key):
        _write_ascii(out, key)
    else:
        _write_string(out, key)


def _write_dotted(mut out: List[Byte], parts: List[String]):
    var i = 0
    while i < len(parts):
        if i > 0:
            out.append(Byte(46))
        _write_key(out, parts[i])
        i += 1


def _extend(prefix: List[String], key: String) -> List[String]:
    var out = List[String]()
    var i = 0
    while i < len(prefix):
        out.append(String(prefix[i]))
        i += 1
    out.append(String(key))
    return out^


@always_inline
def _write_ascii(mut out: List[Byte], text: String):
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        out.append(b[i])
        i += 1


def _write_string(mut out: List[Byte], text: String):
    out.append(Byte(34))
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 34 or c == 92:
            out.append(Byte(92))
            out.append(Byte(c))
        elif c == 8:
            out.append(Byte(92))
            out.append(Byte(98))
        elif c == 9:
            out.append(Byte(92))
            out.append(Byte(116))
        elif c == 10:
            out.append(Byte(92))
            out.append(Byte(110))
        elif c == 12:
            out.append(Byte(92))
            out.append(Byte(102))
        elif c == 13:
            out.append(Byte(92))
            out.append(Byte(114))
        elif c < 32 or c == 127:
            out.append(Byte(92))
            out.append(Byte(117))
            out.append(Byte(48))
            out.append(Byte(48))
            var hi = c >> 4
            var lo = c & 15
            out.append(_hex(hi))
            out.append(_hex(lo))
        else:
            out.append(Byte(c))
        i += 1
    out.append(Byte(34))


def _hex(n: Int) -> Byte:
    if n < 10:
        return Byte(48 + n)
    return Byte(87 + n)
