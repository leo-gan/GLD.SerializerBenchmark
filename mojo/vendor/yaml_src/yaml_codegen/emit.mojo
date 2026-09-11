from std.collections import List

from yaml_codegen.names import mojo_ident
from yaml_runtime.error import DecodeError
from yaml_schema.model import (
    ST_ARRAY,
    ST_BOOL,
    ST_BYTES,
    ST_CONST,
    ST_ENUM,
    ST_INT,
    ST_NUMBER,
    ST_OBJECT,
    ST_OPTIONAL,
    ST_REF,
    ST_STRING,
    ST_UNION,
    SchemaDoc,
    SchemaType,
)
from yaml_schema.scc import scc_ids


def emit_all(doc: SchemaDoc) raises DecodeError -> List[String]:
    var files = List[String]()
    var seen = List[String]()
    _emit_named(doc, doc.root, files, seen)
    var i = 0
    while i < len(doc.def_types):
        _emit_named(doc, doc.def_types[i], files, seen)
        i += 1
    return files^


def _emit_named(
    doc: SchemaDoc, tid: Int, mut files: List[String], mut seen: List[String]
) raises DecodeError:
    var ty = _unwrap(doc, tid).copy()
    if ty.kind != ST_OBJECT and ty.kind != ST_UNION:
        return
    var name = ty.name
    if name.byte_length() == 0:
        name = String("Root")
    name = mojo_ident(name)
    var i = 0
    while i < len(seen):
        if seen[i] == name:
            return
        i += 1
    seen.append(name)
    if ty.kind == ST_OBJECT:
        var p = 0
        while p < len(ty.props):
            _emit_named(doc, ty.props[p].type_id, files, seen)
            p += 1
    if ty.kind == ST_UNION:
        var b = 0
        while b < len(ty.branch_ids):
            _emit_named(doc, ty.branch_ids[b], files, seen)
            b += 1
    files.append(name)
    files.append(_emit_struct(doc, tid, name))


def _unwrap(doc: SchemaDoc, tid: Int) -> SchemaType:
    var t = doc.types[tid].copy()
    while t.kind == ST_REF or t.kind == ST_OPTIONAL or t.kind == ST_ENUM or t.kind == ST_CONST:
        if t.inner < 0:
            break
        t = doc.types[t.inner].copy()
    return t^


def _type_name(doc: SchemaDoc, tid: Int, scc: List[Int], self_id: Int) -> String:
    var t = doc.types[tid].copy()
    if t.kind == ST_OPTIONAL:
        return "Optional[" + _type_name(doc, t.inner, scc, self_id) + "]"
    if t.kind == ST_ARRAY:
        return "List[" + _type_name(doc, t.inner, scc, self_id) + "]"
    if t.kind == ST_REF:
        return _type_name(doc, t.inner, scc, self_id)
    if t.kind == ST_ENUM or t.kind == ST_CONST:
        return _type_name(doc, t.inner, scc, self_id)
    if t.kind == ST_BOOL:
        return String("Bool")
    if t.kind == ST_INT:
        return String("Int64")
    if t.kind == ST_NUMBER:
        return String("Float64")
    if t.kind == ST_STRING:
        return String("String")
    if t.kind == ST_BYTES:
        return String("List[Byte]")
    if t.kind == ST_OBJECT or t.kind == ST_UNION:
        var n = mojo_ident(t.name)
        if self_id >= 0 and self_id < len(scc) and tid < len(scc):
            if scc[tid] == scc[self_id]:
                return "Box[" + n + "]"
        return n
    return String("Int64")


def _is_optional(doc: SchemaDoc, tid: Int) -> Bool:
    return doc.types[tid].kind == ST_OPTIONAL


def _named_refs(
    doc: SchemaDoc, ty: SchemaType, self_name: String, scc: List[Int], self_id: Int
) -> List[String]:
    var out = List[String]()
    var i = 0
    while i < len(ty.props):
        _collect_named(doc, ty.props[i].type_id, self_name, scc, self_id, out)
        i += 1
    i = 0
    while i < len(ty.branch_ids):
        _collect_named(doc, ty.branch_ids[i], self_name, scc, self_id, out)
        i += 1
    return out^


def _collect_named(
    doc: SchemaDoc,
    tid: Int,
    self_name: String,
    scc: List[Int],
    self_id: Int,
    mut out: List[String],
):
    var t = doc.types[tid].copy()
    if (
        t.kind == ST_OPTIONAL
        or t.kind == ST_ARRAY
        or t.kind == ST_REF
        or t.kind == ST_ENUM
        or t.kind == ST_CONST
    ):
        if t.inner >= 0:
            _collect_named(doc, t.inner, self_name, scc, self_id, out)
        return
    if t.kind != ST_OBJECT and t.kind != ST_UNION:
        return
    var n = mojo_ident(t.name)
    if n == self_name:
        return
    var j = 0
    while j < len(out):
        if out[j] == n:
            return
        j += 1
    out.append(n)


def _emit_struct(doc: SchemaDoc, tid: Int, name: String) raises DecodeError -> String:
    var ty = _unwrap(doc, tid).copy()
    var scc = scc_ids(doc)
    var out = String()
    out += "from std.collections import List, Optional, Span\n\n"
    out += "from yaml import (\n"
    out += "    Box,\n"
    out += "    DecodeError,\n"
    out += "    EncodeOptions,\n"
    out += "    YamlDatum,\n"
    out += "    WireReader,\n"
    out += "    WireWriter,\n"
    out += "    encoded_float_len,\n"
    out += "    encoded_int_len,\n"
    out += "    encoded_string_len,\n"
    out += "    read_bool,\n"
    out += "    read_float,\n"
    out += "    read_float_list,\n"
    out += "    read_int_list,\n"
    out += "    read_string_list,\n"
    out += "    write_float_list,\n"
    out += "    write_int_list,\n"
    out += "    write_string_list,\n"
    out += ")\n\n"
    var refs = _named_refs(doc, ty, name, scc_ids(doc), tid)
    var ri = 0
    while ri < len(refs):
        out += "from " + refs[ri] + " import " + refs[ri] + "\n"
        ri += 1
    if len(refs) > 0:
        out += "\n"
    if ty.kind == ST_UNION:
        return out + _emit_union(doc, ty, name, scc)
    out += (
        "struct "
        + name
        + "(Copyable, Movable, Defaultable, Deinitable, YamlDatum):\n"
    )
    var i = 0
    while i < len(ty.props):
        var p = ty.props[i].copy()
        var fname = mojo_ident(p.name)
        var fty = _type_name(doc, p.type_id, scc, tid)
        out += "    var " + fname + ": " + fty + "\n"
        i += 1
    out += "\n    def __init__(out self):\n"
    i = 0
    while i < len(ty.props):
        var p = ty.props[i].copy()
        var fname = mojo_ident(p.name)
        out += "        self." + fname + " = " + _zero(_type_name(doc, p.type_id, scc, tid)) + "\n"
        i += 1
    if len(ty.props) == 0:
        out += "        pass\n"
    if len(ty.props) > 0:
        out += "\n    def __init__(out self"
        i = 0
        while i < len(ty.props):
            var p = ty.props[i].copy()
            var fname = mojo_ident(p.name)
            var fty = _type_name(doc, p.type_id, scc, tid)
            out += ", var " + fname + ": " + fty
            i += 1
        out += "):\n"
        i = 0
        while i < len(ty.props):
            var p = ty.props[i].copy()
            var fname = mojo_ident(p.name)
            out += "        self." + fname + " = " + fname + "^\n"
            i += 1
    out += _emit_len(doc, ty, scc, tid)
    out += _emit_encode(doc, ty, scc, tid)
    out += _emit_decode(doc, ty, scc, tid)
    return out


def _zero(ty: String) -> String:
    if ty == "Bool":
        return String("False")
    if ty == "Int64":
        return String("Int64(0)")
    if ty == "Float64":
        return String("0.0")
    if _starts(ty, "Optional["):
        return "Optional[" + _cut(ty, 9, ty.byte_length() - 1) + "]()"
    if _starts(ty, "List["):
        return ty + "()"
    if _starts(ty, "Box["):
        return ty + "(" + _cut(ty, 4, ty.byte_length() - 1) + "())"
    return ty + "()"


def _emit_len(doc: SchemaDoc, ty: SchemaType, scc: List[Int], self_id: Int) -> String:
    var out = String()
    out += "\n    def encoded_len(self, options: EncodeOptions) -> Int:\n"
    out += "        return self.encoded_len_at(options, 0)\n\n"
    out += "    def encoded_len_at(self, options: EncodeOptions, depth: Int) -> Int:\n"
    out += "        var n = 0\n"
    out += "        var first = True\n"
    var i = 0
    while i < len(ty.props):
        var p = ty.props[i].copy()
        var fname = mojo_ident(p.name)
        var opt = _is_optional(doc, p.type_id)
        var indent = "        "
        if opt:
            out += indent + "if self." + fname + ":\n"
            indent = "            "
        out += indent + "if not first:\n"
        out += indent + "    n += 1\n"
        out += indent + "first = False\n"
        out += indent + "n += depth * options.indent\n"
        out += indent + "n += " + String(p.name.byte_length() + 2) + "\n"
        out += indent + _len_expr(doc, p.type_id, "self." + fname, scc, self_id) + "\n"
        i += 1
    out += "        return n\n"
    return out


def _len_expr(doc: SchemaDoc, tid: Int, acc: String, scc: List[Int], self_id: Int) -> String:
    var t = doc.types[tid].copy()
    if t.kind == ST_OPTIONAL:
        return _len_expr(doc, t.inner, acc + ".value()", scc, self_id)
    if t.kind == ST_REF:
        return _len_expr(doc, t.inner, acc, scc, self_id)
    if t.kind == ST_BOOL:
        return "if " + acc + ":\n" + "            n += 4\n        else:\n            n += 5"
    if t.kind == ST_INT:
        return "n += encoded_int_len(" + acc + ")"
    if t.kind == ST_NUMBER:
        return "n += encoded_float_len(" + acc + ")"
    if t.kind == ST_STRING:
        return "n += encoded_string_len(" + acc + ".as_bytes(), options)"
    if t.kind == ST_BYTES:
        return "n += 10 + ((len(" + acc + ") + 2) // 3) * 4"
    if t.kind == ST_ENUM or t.kind == ST_CONST:
        return _len_expr(doc, t.inner, acc, scc, self_id)
    if t.kind == ST_ARRAY:
        return "n += 1 + len(" + acc + ") * 8"
    var call = acc
    if _starts(_type_name(doc, tid, scc, self_id), "Box["):
        call = acc + "[]"
    return "n += " + call + ".encoded_len_at(options, depth + 1)"


def _emit_encode(doc: SchemaDoc, ty: SchemaType, scc: List[Int], self_id: Int) -> String:
    var out = String()
    out += "\n    def encode_to(self, mut w: WireWriter, options: EncodeOptions):\n"
    out += "        self.encode_to_at(w, options, 0, False)\n\n"
    out += "    def encode_to_at(self, mut w: WireWriter, options: EncodeOptions, depth: Int, inline_first: Bool = False):\n"
    out += "        var first = True\n"
    var i = 0
    while i < len(ty.props):
        var p = ty.props[i].copy()
        var fname = mojo_ident(p.name)
        var opt = _is_optional(doc, p.type_id)
        var indent = "        "
        if opt:
            out += "        if self." + fname + ":\n"
            indent = "            "
        out += indent + "if not first:\n"
        out += indent + "    if depth == 0:\n"
        out += indent + "        w.write_ascii(\"\\n" + p.name + ": \")\n"
        out += indent + "    else:\n"
        out += indent + "        w.write_lf()\n"
        out += indent + "        w.indent_depth = depth\n"
        out += indent + "        w.write_indent(options)\n"
        out += indent + "        w.write_ascii(\"" + p.name + ": \")\n"
        out += indent + "else:\n"
        out += indent + "    if not inline_first:\n"
        out += indent + "        w.indent_depth = depth\n"
        out += indent + "        w.write_indent(options)\n"
        out += indent + "    w.write_ascii(\"" + p.name + ": \")\n"
        out += indent + "first = False\n"
        out += indent + _encode_stmt(doc, p.type_id, "self." + fname, scc, self_id) + "\n"
        i += 1
    return out


def _encode_stmt(doc: SchemaDoc, tid: Int, acc: String, scc: List[Int], self_id: Int) -> String:
    var t = doc.types[tid].copy()
    if t.kind == ST_OPTIONAL:
        return _encode_stmt(doc, t.inner, acc + ".value()", scc, self_id)
    if t.kind == ST_REF:
        return _encode_stmt(doc, t.inner, acc, scc, self_id)
    if t.kind == ST_BOOL:
        return "w.write_bool(" + acc + ")"
    if t.kind == ST_INT:
        return "w.write_int(" + acc + ")"
    if t.kind == ST_NUMBER:
        return "w.write_float(" + acc + ")"
    if t.kind == ST_STRING:
        return "w.write_string(" + acc + ", options)"
    if t.kind == ST_BYTES:
        return "w.write_binary(Span(" + acc + "))"
    if t.kind == ST_ENUM or t.kind == ST_CONST:
        return _encode_stmt(doc, t.inner, acc, scc, self_id)
    if t.kind == ST_ARRAY:
        var elem = _unwrap(doc, t.inner)
        if elem.kind == ST_NUMBER:
            return "w.write_lf()\n        write_float_list(w, " + acc + ", options)"
        if elem.kind == ST_INT:
            return "w.write_lf()\n        write_int_list(w, " + acc + ", options)"
        if elem.kind == ST_STRING:
            return "w.write_lf()\n        write_string_list(w, " + acc + ", options)"
        var loop = "w.write_lf()\n"
        loop += "        var _i = 0\n"
        loop += "        while _i < len(" + acc + "):\n"
        loop += "            if _i > 0:\n"
        loop += "                w.write_lf()\n"
        loop += "            w.indent_depth = depth\n"
        loop += "            w.write_indent(options)\n"
        loop += "            w.write_ascii(\"- \")\n"
        loop += "            " + acc + "[_i].encode_to_at(w, options, depth + 1, True)\n"
        loop += "            _i += 1"
        return loop
    var call = acc
    if _starts(_type_name(doc, tid, scc, self_id), "Box["):
        call = acc + "[]"
    return "w.write_lf()\n        " + call + ".encode_to_at(w, options, depth + 1, False)"


def _emit_decode(doc: SchemaDoc, ty: SchemaType, scc: List[Int], self_id: Int) -> String:
    var out = String()
    out += "\n    def decode_from[origin: ImmOrigin](mut self, mut r: WireReader[origin]) raises DecodeError:\n"
    out += "        var saved = r.take_alias()\n"
    out += "        var st = r.begin_map()\n"
    var i = 0
    while i < len(ty.props):
        var p = ty.props[i].copy()
        var fname = mojo_ident(p.name)
        if _is_optional(doc, p.type_id):
            out += "        self." + fname + " = Optional[" + _type_name(doc, doc.types[p.type_id].inner, scc, self_id) + "]()\n"
        i += 1
    i = 0
    while i < len(ty.props):
        var p = ty.props[i].copy()
        var fname = mojo_ident(p.name)
        out += "        if r.next_key(st) and r.try_key(\"" + p.name + "\".as_bytes()):\n"
        out += _decode_block(doc, p.type_id, "self." + fname, scc, self_id, "            ")
        i += 1
    out += "        while r.next_key(st):\n"
    out += "            r.skip_pair()\n"
    out += "        r.end_map(st)\n"
    out += "        if saved:\n"
    out += "            r.end_alias(saved.value())\n"
    return out


def _decode_block(
    doc: SchemaDoc, tid: Int, acc: String, scc: List[Int], self_id: Int, indent: String
) -> String:
    var t = doc.types[tid].copy()
    if t.kind == ST_OPTIONAL:
        return _decode_optional(doc, t.inner, acc, scc, self_id, indent)
    if t.kind == ST_REF:
        return _decode_block(doc, t.inner, acc, scc, self_id, indent)
    if t.kind == ST_BOOL:
        return indent + acc + " = read_bool(r)\n"
    if t.kind == ST_INT:
        return indent + acc + " = r.read_int()\n"
    if t.kind == ST_NUMBER:
        return indent + acc + " = read_float(r)\n"
    if t.kind == ST_STRING:
        return indent + acc + " = r.read_string()\n"
    if t.kind == ST_BYTES:
        return indent + acc + " = r.read_binary()\n"
    if t.kind == ST_ENUM or t.kind == ST_CONST:
        return _decode_block(doc, t.inner, acc, scc, self_id, indent)
    if t.kind == ST_ARRAY:
        var elem = _unwrap(doc, t.inner)
        if elem.kind == ST_NUMBER:
            return indent + acc + " = read_float_list(r)\n"
        if elem.kind == ST_INT:
            return indent + acc + " = read_int_list(r)\n"
        if elem.kind == ST_STRING:
            return indent + acc + " = read_string_list(r)\n"
        var en = _type_name(doc, t.inner, scc, self_id)
        var out = indent + acc + " = List[" + en + "]()\n"
        out += indent + "var _st = r.begin_seq()\n"
        out += indent + "while r.next_item(_st):\n"
        out += indent + "    var _el = " + en + "()\n"
        out += indent + "    _el.decode_from(r)\n"
        out += indent + "    " + acc + ".append(_el^)\n"
        out += indent + "r.end_seq(_st)\n"
        return out
    var n = _type_name(doc, tid, scc, self_id)
    if _starts(n, "Box["):
        var inner = _cut(n, 4, n.byte_length() - 1)
        var out = indent + "var _b = " + inner + "()\n"
        out += indent + "_b.decode_from(r)\n"
        out += indent + acc + " = Box[" + inner + "](_b^)\n"
        return out
    var out = indent + "var _c = " + n + "()\n"
    out += indent + "_c.decode_from(r)\n"
    out += indent + acc + " = _c^\n"
    return out


def _decode_optional(
    doc: SchemaDoc, inner: Int, acc: String, scc: List[Int], self_id: Int, indent: String
) -> String:
    var inner_ty = _type_name(doc, inner, scc, self_id)
    var out = indent + "if r.peek_is_null():\n"
    out += indent + "    r.read_null()\n"
    out += indent + "    " + acc + " = Optional[" + inner_ty + "]()\n"
    out += indent + "else:\n"
    var inner_t = doc.types[inner].copy()
    if inner_t.kind == ST_STRING:
        out += indent + "    " + acc + " = Optional[" + inner_ty + "](r.read_string())\n"
        return out
    if inner_t.kind == ST_INT:
        out += indent + "    " + acc + " = Optional[" + inner_ty + "](r.read_int())\n"
        return out
    if inner_t.kind == ST_NUMBER:
        out += indent + "    " + acc + " = Optional[" + inner_ty + "](read_float(r))\n"
        return out
    if inner_t.kind == ST_BOOL:
        out += indent + "    " + acc + " = Optional[" + inner_ty + "](read_bool(r))\n"
        return out
    var n = _type_name(doc, inner, scc, -1)
    out += indent + "    var _o = " + n + "()\n"
    out += indent + "    _o.decode_from(r)\n"
    out += indent + "    " + acc + " = Optional[" + inner_ty + "](_o^)\n"
    return out


def _emit_union(doc: SchemaDoc, ty: SchemaType, name: String, scc: List[Int]) -> String:
    var out = String()
    out += "struct " + name + "(Copyable, Movable, Defaultable, Deinitable, YamlDatum):\n"
    out += "    var tag: Int\n"
    var i = 0
    while i < len(ty.branch_ids):
        out += "    var v" + String(i) + ": " + _type_name(doc, ty.branch_ids[i], scc, -1) + "\n"
        i += 1
    out += "\n    def __init__(out self):\n"
    out += "        self.tag = 0\n"
    i = 0
    while i < len(ty.branch_ids):
        out += "        self.v" + String(i) + " = " + _zero(_type_name(doc, ty.branch_ids[i], scc, -1)) + "\n"
        i += 1
    out += "\n    def encoded_len(self, options: EncodeOptions) -> Int:\n"
    out += "        if self.tag == 0:\n            return self.v0.encoded_len(options)\n"
    i = 1
    while i < len(ty.branch_ids):
        out += (
            "        if self.tag == "
            + String(i)
            + ":\n            return self.v"
            + String(i)
            + ".encoded_len(options)\n"
        )
        i += 1
    out += "        return 0\n"
    out += "\n    def encode_to(self, mut w: WireWriter, options: EncodeOptions):\n"
    i = 0
    while i < len(ty.branch_ids):
        out += (
            "        if self.tag == "
            + String(i)
            + ":\n            self.v"
            + String(i)
            + ".encode_to(w, options)\n            return\n"
        )
        i += 1
    out += "\n    def decode_from[origin: ImmOrigin](mut self, mut r: WireReader[origin]) raises DecodeError:\n"
    out += "        self.v0.decode_from(r)\n"
    out += "        self.tag = 0\n"
    return out


def _starts(s: String, prefix: String) -> Bool:
    if s.byte_length() < prefix.byte_length():
        return False
    var a = s.as_bytes()
    var b = prefix.as_bytes()
    var i = 0
    while i < len(b):
        if Int(a[i]) != Int(b[i]):
            return False
        i += 1
    return True


def _cut(s: String, start: Int, end: Int) -> String:
    var b = s.as_bytes()
    try:
        return String(from_utf8=b[start:end])
    except _:
        return String()
