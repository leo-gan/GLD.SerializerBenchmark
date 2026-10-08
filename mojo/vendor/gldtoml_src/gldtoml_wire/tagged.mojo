from std.collections import List

from gldtoml_runtime.error import DecodeError
from gldtoml_schema.json_read import ReadValue, decode_json
from gldtoml_wire.doc import (
    TK_ARRAY,
    TK_DATETIME,
    TK_FALSE,
    TK_FLOAT,
    TK_INT,
    TK_STRING,
    TK_TABLE,
    TK_TRUE,
    TomlDoc,
)
from gldtoml_wire.reader import decode_toml
from gldtoml_wire.utf8 import string_from_bytes


def tagged_json(doc: TomlDoc) raises DecodeError -> String:
    var out = List[Byte]()
    _write_node(doc, doc.root, out)
    out.append(Byte(10))
    return string_from_bytes(out^, 0)


def doc_from_tagged(text: String) raises DecodeError -> TomlDoc:
    var jv = decode_json(text.as_bytes())
    var doc = TomlDoc()
    if not jv.is_object() or _is_tagged(jv):
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    _fill_table(doc, doc.root, jv)
    return doc^


def _is_tagged(jv: ReadValue) raises DecodeError -> Bool:
    if not jv.is_object() or jv.count() != 2:
        return False
    var saw_t = False
    var saw_v = False
    var i = 0
    while i < jv.count():
        var p = jv.pair(i)
        if p[0] == "type":
            saw_t = True
        elif p[0] == "value":
            saw_v = True
        i += 1
    return saw_t and saw_v


def _field(jv: ReadValue, key: String) raises DecodeError -> String:
    var i = 0
    while i < jv.count():
        var p = jv.pair(i)
        if p[0] == key:
            return p[1].as_str()
        i += 1
    raise DecodeError(DecodeError.KIND_TYPE, 0)


def _fill_table(mut doc: TomlDoc, node: Int, jv: ReadValue) raises DecodeError:
    var i = 0
    while i < jv.count():
        var p = jv.pair(i)
        var child = _value_node(doc, p[1])
        var kt = doc.add_text(String(p[0]))
        doc.append_child(node, kt, child)
        i += 1


def _value_node(mut doc: TomlDoc, jv: ReadValue) raises DecodeError -> Int:
    if jv.is_array():
        var arr = doc.make_array(-1)
        var i = 0
        while i < jv.count():
            var child = _value_node(doc, jv.at(i))
            doc.append_child(arr, -1, child)
            i += 1
        return arr
    if jv.is_object() and _is_tagged(jv):
        var ty = _field(jv, "type")
        var val = _field(jv, "value")
        if ty == "string":
            return doc.make_string(val^, -1)
        if ty == "integer":
            var wrapped = String("v = ") + val + String("\n")
            var tmp = decode_toml(wrapped)
            return doc.make_int(tmp.int_at(tmp.find_key(tmp.root, "v")), -1)
        if ty == "float":
            var wrapped = String("v = ") + val + String("\n")
            var tmp = decode_toml(wrapped)
            var n = tmp.find_key(tmp.root, "v")
            return doc.make_float(tmp.nodes[n].b, -1)
        if ty == "bool":
            return doc.make_bool(val == "true", -1)
        if ty == "datetime" or ty == "datetime-local" or ty == "date-local" or ty == "time-local":
            var wrapped = String("v = ") + val + String("\n")
            var tmp = decode_toml(wrapped)
            return doc.make_datetime(tmp.date_at(tmp.find_key(tmp.root, "v")), -1)
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    if jv.is_object():
        var table = doc.make_table(-1)
        _fill_table(doc, table, jv)
        return table
    raise DecodeError(DecodeError.KIND_TYPE, 0)


def _write_node(doc: TomlDoc, node: Int, mut out: List[Byte]) raises DecodeError:
    var k = doc.kind(node)
    if k == TK_TABLE:
        out.append(Byte(123))
        var e = doc.first_edge(node)
        var first = True
        while e >= 0:
            if not first:
                out.append(Byte(44))
            _write_json_string(out, doc.texts[doc.edges[e].key])
            out.append(Byte(58))
            _write_node(doc, doc.edges[e].child, out)
            first = False
            e = doc.edges[e].next
        out.append(Byte(125))
        return
    if k == TK_ARRAY:
        out.append(Byte(91))
        var e = doc.first_edge(node)
        var first = True
        while e >= 0:
            if not first:
                out.append(Byte(44))
            _write_node(doc, doc.edges[e].child, out)
            first = False
            e = doc.edges[e].next
        out.append(Byte(93))
        return
    var ty: String
    var val: String
    if k == TK_STRING:
        ty = String("string")
        val = doc.text_at(node)
    elif k == TK_INT:
        ty = String("integer")
        val = _int_text(doc.int_at(node))
    elif k == TK_FLOAT:
        ty = String("float")
        val = String(doc.float_at(node))
    elif k == TK_TRUE:
        ty = String("bool")
        val = String("true")
    elif k == TK_FALSE:
        ty = String("bool")
        val = String("false")
    elif k == TK_DATETIME:
        var dt = doc.date_at(node)
        if dt.sub == 1:
            ty = String("datetime")
        elif dt.sub == 2:
            ty = String("datetime-local")
        elif dt.sub == 3:
            ty = String("date-local")
        else:
            ty = String("time-local")
        val = _date_text(doc, node)
    else:
        raise DecodeError(DecodeError.KIND_TYPE, 0)
    out.append(Byte(123))
    _write_json_string(out, String("type"))
    out.append(Byte(58))
    _write_json_string(out, ty)
    out.append(Byte(44))
    _write_json_string(out, String("value"))
    out.append(Byte(58))
    _write_json_string(out, val)
    out.append(Byte(125))


def _int_text(v: Int64) -> String:
    if v == Int64(0):
        return String("0")
    if v == Int64.MIN:
        return String("-9223372036854775808")
    var neg = v < Int64(0)
    var x = v
    if neg:
        x = Int64(0) - v
    var buf = List[Byte]()
    while x > Int64(0):
        buf.append(Byte(48 + Int(x % Int64(10))))
        x = x // Int64(10)
    var out = List[Byte]()
    if neg:
        out.append(Byte(45))
    var i = len(buf) - 1
    while i >= 0:
        out.append(buf[i])
        i -= 1
    try:
        return String(from_utf8=out)
    except _:
        return String("0")


def _date_text(doc: TomlDoc, node: Int) -> String:
    var dt = doc.date_at(node)
    var out = List[Byte]()
    if dt.sub == 1 or dt.sub == 2 or dt.sub == 3:
        _pad(out, dt.year, 4)
        out.append(Byte(45))
        _pad(out, dt.month, 2)
        out.append(Byte(45))
        _pad(out, dt.day, 2)
    if dt.sub == 1 or dt.sub == 2:
        out.append(Byte(84))
    if dt.sub == 1 or dt.sub == 2 or dt.sub == 4:
        _pad(out, dt.hour, 2)
        out.append(Byte(58))
        _pad(out, dt.minute, 2)
        out.append(Byte(58))
        _pad(out, dt.second, 2)
        if dt.nanos > 0:
            out.append(Byte(46))
            var digits = List[Byte]()
            var n = dt.nanos
            var k = 0
            while k < 9:
                digits.append(Byte(48 + (n % 10)))
                n = n // 10
                k += 1
            var end = 8
            while end > 0 and Int(digits[end]) == 48:
                end -= 1
            var j = end
            while j >= 0:
                out.append(digits[j])
                j -= 1
    if dt.sub == 1:
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
    try:
        return String(from_utf8=out)
    except _:
        return String()


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


def _write_json_string(mut out: List[Byte], text: String):
    out.append(Byte(34))
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 34 or c == 92:
            out.append(Byte(92))
            out.append(Byte(c))
        elif c == 10:
            out.append(Byte(92))
            out.append(Byte(110))
        elif c == 13:
            out.append(Byte(92))
            out.append(Byte(114))
        elif c == 9:
            out.append(Byte(92))
            out.append(Byte(116))
        elif c < 32:
            out.append(Byte(92))
            out.append(Byte(117))
            out.append(Byte(48))
            out.append(Byte(48))
            var hi = c >> 4
            var lo = c & 15
            if hi < 10:
                out.append(Byte(48 + hi))
            else:
                out.append(Byte(87 + hi))
            if lo < 10:
                out.append(Byte(48 + lo))
            else:
                out.append(Byte(87 + lo))
        else:
            out.append(Byte(c))
        i += 1
    out.append(Byte(34))
