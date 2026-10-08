from std.collections import List

from arrow_runtime.model import TY_BOOL, TY_FLOAT, TY_INT, TY_LIST, TY_STRUCT, TY_UTF8, Columnar, FieldRec
from arrow_schema.json import JsonDoc
from arrow_schema.load import schema_title


def emit_schema(doc: JsonDoc, c: Columnar) -> String:
    var name = _ident(schema_title(doc))
    var ids = _emit_ids(c)
    var out = String("from std.collections import List, Span\n\n")
    out = out + "from arrow_runtime.model import TY_BOOL, TY_FLOAT, TY_INT, TY_LIST, TY_STRUCT, TY_UTF8, ArrayRec, Columnar, FieldRec, put_width\n"
    out = out + "from arrow_runtime.rows import rows_from_batch, text_at, child_at\n"
    out = out + "from arrow_wire.ipc import decode_ipc_stream, encode_ipc_stream\n\n\n"
    out = out + "struct " + name + ":\n"
    var i = 0
    while i < len(ids):
        var ch = c.fields[ids[i]]
        out = out + "    var " + _field_name(c, ch) + ": " + _mojo_type(ch) + "\n"
        if ch.nullable != 0:
            out = out + "    var " + _field_name(c, ch) + "_set: Bool\n"
        i += 1
    out = out + "\n    def __init__(out self):\n"
    i = 0
    while i < len(ids):
        var ch = c.fields[ids[i]]
        out = out + "        self." + _field_name(c, ch) + " = " + _zero(ch) + "\n"
        if ch.nullable != 0:
            out = out + "        self." + _field_name(c, ch) + "_set = False\n"
        i += 1
    out = out + "\n    def encoded_len(self) raises -> Int:\n"
    out = out + "        return len(self.encode_bytes())\n\n"
    out = out + "    def encode_to(self, mut buf: List[Byte]) raises:\n"
    out = out + "        var raw = self.encode_bytes()\n"
    out = out + "        var i = 0\n"
    out = out + "        while i < len(raw):\n"
    out = out + "            buf.append(raw[i])\n"
    out = out + "            i += 1\n\n"
    out = out + "    def encode_bytes(self) raises -> List[Byte]:\n"
    out = out + "        var c = Columnar()\n"
    out = out + "        var cols = List[Int]()\n"
    i = 0
    while i < len(ids):
        var ch = c.fields[ids[i]]
        var nm = _field_name(c, ch)
        out = out + "        var f" + String(i) + " = FieldRec()\n"
        out = out + "        f" + String(i) + ".name = c.intern(\"" + _raw_name(c, ch) + "\")\n"
        out = out + "        f" + String(i) + ".kind = " + _kind_const(ch) + "\n"
        out = out + "        f" + String(i) + ".nullable = " + String(ch.nullable) + "\n"
        out = out + "        f" + String(i) + ".bit_width = " + String(ch.bit_width) + "\n"
        out = out + "        f" + String(i) + ".is_signed = " + String(ch.is_signed) + "\n"
        out = out + "        f" + String(i) + ".unit = " + String(ch.unit) + "\n"
        out = out + "        var id" + String(i) + " = c.add_field(f" + String(i) + ")\n"
        out = out + "        c.add_top(id" + String(i) + ")\n"
        out = out + "        cols.append(_emit_" + _kind_const(ch) + "(c, id" + String(i) + ", self." + nm + "))\n"
        i += 1
    out = out + "        c.add_batch(1, cols)\n"
    out = out + "        return encode_ipc_stream(c)\n\n"
    out = out + "    @staticmethod\n"
    out = out + "    def decode_from[origin: ImmOrigin](raw: Span[Byte, origin]) raises -> " + name + ":\n"
    out = out + "        var c = decode_ipc_stream(raw)\n"
    out = out + "        var doc = rows_from_batch(c, 0)\n"
    out = out + "        var out = " + name + "()\n"
    i = 0
    while i < len(ids):
        var ch = c.fields[ids[i]]
        var nm = _field_name(c, ch)
        out = out + "        var n" + String(i) + " = child_at(doc, doc.rows[0], " + String(i) + ")\n"
        if ch.kind == TY_INT:
            out = out + "        out." + nm + " = doc.nodes[n" + String(i) + "].a\n"
        elif ch.kind == TY_BOOL:
            out = out + "        out." + nm + " = doc.nodes[n" + String(i) + "].a != 0\n"
        elif ch.kind == TY_UTF8:
            out = out + "        out." + nm + " = text_at(doc, n" + String(i) + ")\n"
        elif ch.kind == TY_FLOAT:
            out = out + "        out." + nm + " = Float64(from_bits=UInt64(doc.nodes[n" + String(i) + "].a))\n"
        if ch.nullable != 0:
            out = out + "        out." + nm + "_set = doc.nodes[n" + String(i) + "].is_null == 0\n"
        i += 1
    out = out + "        return out^\n"
    out = out + _helpers()
    return out


def _emit_ids(c: Columnar) -> List[Int]:
    var ids = List[Int]()
    if len(c.top) == 1 and c.fields[c.top[0]].kind == TY_STRUCT:
        var f = c.fields[c.top[0]]
        var i = 0
        while i < f.nchild:
            ids.append(c.kids[f.child0 + i])
            i += 1
        return ids^
    var i = 0
    while i < len(c.top):
        ids.append(c.top[i])
        i += 1
    return ids^


def _helpers() -> String:
    var s = String("\n\ndef _emit_TY_INT(mut c: Columnar, field: Int, value: Int) -> Int:\n")
    s = s + "    var vals = List[Byte]()\n    put_width(vals, value, 8)\n"
    s = s + "    var a = ArrayRec()\n    a.field = field\n    a.length = 1\n    a.buf0 = len(c.abufs)\n    a.nbuf = 2\n"
    s = s + "    c.abufs.append(c.add_empty_buf())\n    c.abufs.append(c.add_buf(Span(vals)))\n    return c.push_array(a)\n"
    s = s + "\n\ndef _emit_TY_BOOL(mut c: Columnar, field: Int, value: Bool) -> Int:\n"
    s = s + "    var bits = List[Byte]()\n    var b = 0\n    if value:\n        b = 1\n    bits.append(Byte(b))\n"
    s = s + "    var a = ArrayRec()\n    a.field = field\n    a.length = 1\n    a.buf0 = len(c.abufs)\n    a.nbuf = 2\n"
    s = s + "    c.abufs.append(c.add_empty_buf())\n    c.abufs.append(c.add_buf(Span(bits)))\n    return c.push_array(a)\n"
    s = s + "\n\ndef _emit_TY_UTF8(mut c: Columnar, field: Int, value: String) -> Int:\n"
    s = s + "    var raw = value.as_bytes()\n    var off = List[Byte]()\n    put_width(off, 0, 4)\n    put_width(off, len(raw), 4)\n"
    s = s + "    var data = List[Byte]()\n    var i = 0\n    while i < len(raw):\n        data.append(raw[i])\n        i += 1\n"
    s = s + "    var a = ArrayRec()\n    a.field = field\n    a.length = 1\n    a.buf0 = len(c.abufs)\n    a.nbuf = 3\n"
    s = s + "    c.abufs.append(c.add_empty_buf())\n    c.abufs.append(c.add_buf(Span(off)))\n    c.abufs.append(c.add_buf(Span(data)))\n    return c.push_array(a)\n"
    s = s + "\n\ndef _emit_TY_FLOAT(mut c: Columnar, field: Int, value: Float64) -> Int:\n"
    s = s + "    var vals = List[Byte]()\n    put_width(vals, Int(UInt64(value.to_bits())), 8)\n"
    s = s + "    var a = ArrayRec()\n    a.field = field\n    a.length = 1\n    a.buf0 = len(c.abufs)\n    a.nbuf = 2\n"
    s = s + "    c.abufs.append(c.add_empty_buf())\n    c.abufs.append(c.add_buf(Span(vals)))\n    return c.push_array(a)\n"
    s = s + "\n\ndef _emit_TY_LIST(mut c: Columnar, field: Int, value: Int) -> Int:\n    return _emit_TY_INT(c, field, value)\n"
    s = s + "\n\ndef _emit_TY_STRUCT(mut c: Columnar, field: Int, value: Int) -> Int:\n    return _emit_TY_INT(c, field, value)\n"
    return s


def _field_name(c: Columnar, f: FieldRec) -> String:
    if f.name < 0:
        return "field"
    return _ident(c.strings[f.name])


def _raw_name(c: Columnar, f: FieldRec) -> String:
    if f.name < 0:
        return "field"
    return c.strings[f.name]


def _mojo_type(f: FieldRec) -> String:
    if f.kind == TY_BOOL:
        return "Bool"
    if f.kind == TY_UTF8:
        return "String"
    if f.kind == TY_FLOAT:
        return "Float64"
    return "Int"


def _zero(f: FieldRec) -> String:
    if f.kind == TY_BOOL:
        return "False"
    if f.kind == TY_UTF8:
        return "String()"
    if f.kind == TY_FLOAT:
        return "Float64(0)"
    return "0"


def _kind_const(f: FieldRec) -> String:
    if f.kind == TY_BOOL:
        return "TY_BOOL"
    if f.kind == TY_UTF8:
        return "TY_UTF8"
    if f.kind == TY_FLOAT:
        return "TY_FLOAT"
    if f.kind == TY_LIST:
        return "TY_LIST"
    if f.kind == TY_STRUCT:
        return "TY_STRUCT"
    return "TY_INT"


def _ident(name: String) -> String:
    var raw = name.as_bytes()
    var out = String("")
    var i = 0
    while i < len(raw):
        var c = Int(raw[i])
        var ok = (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95
        if i == 0 and c >= 48 and c <= 57:
            ok = False
        if ok:
            out = out + String(unsafe_from_utf8=raw[i : i + 1])
        else:
            out = out + "_"
        i += 1
    if out == "struct" or out == "type" or out == "self":
        out = out + "_"
    if out.byte_length() == 0:
        return "Root"
    return out
