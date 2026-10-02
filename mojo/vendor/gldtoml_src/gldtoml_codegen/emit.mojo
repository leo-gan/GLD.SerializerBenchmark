from std.collections import List

from gldtoml_codegen.names import mojo_ident
from gldtoml_runtime.error import DecodeError
from gldtoml_schema.model import (
    ST_ARRAY,
    ST_BOOL,
    ST_CONST,
    ST_ENUM,
    ST_INT,
    ST_NUMBER,
    ST_OBJECT,
    ST_OPTIONAL,
    ST_REF,
    ST_STRING,
    ST_TIMESTAMP,
    ST_UNION,
    SchemaDoc,
    SchemaType,
)
from gldtoml_schema.scc import scc_ids


def emit_all(doc: SchemaDoc) raises DecodeError -> List[String]:
    var files = List[String]()
    var seen = List[String]()
    _emit_named(doc, doc.root, files, seen)
    var i = 0
    while i < len(doc.def_types):
        _emit_named(doc, doc.def_types[i], files, seen)
        i += 1
    return files^


def _unwrap(doc: SchemaDoc, tid: Int) -> SchemaType:
    var t = doc.types[tid].copy()
    while t.kind == ST_REF or t.kind == ST_OPTIONAL or t.kind == ST_ENUM or t.kind == ST_CONST:
        if t.inner < 0:
            break
        t = doc.types[t.inner].copy()
    return t^


def _emit_named(
    doc: SchemaDoc, tid: Int, mut files: List[String], mut seen: List[String]
) raises DecodeError:
    var ty = _unwrap(doc, tid).copy()
    if ty.kind != ST_OBJECT and ty.kind != ST_UNION:
        return
    var name = mojo_ident(ty.name)
    if name.byte_length() == 0:
        name = String("Root")
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
    else:
        var b = 0
        while b < len(ty.branch_ids):
            _emit_named(doc, ty.branch_ids[b], files, seen)
            b += 1
    files.append(name)
    files.append(_emit_struct(doc, ty, name, tid))


def _type_name(doc: SchemaDoc, tid: Int, scc: List[Int], self_id: Int) raises DecodeError -> String:
    var t = doc.types[tid].copy()
    if t.kind == ST_OPTIONAL:
        return "Optional[" + _type_name(doc, t.inner, scc, self_id) + "]"
    if t.kind == ST_ARRAY:
        return "List[" + _type_name(doc, t.inner, scc, self_id) + "]"
    if t.kind == ST_REF or t.kind == ST_ENUM or t.kind == ST_CONST:
        return _type_name(doc, t.inner, scc, self_id)
    if t.kind == ST_BOOL:
        return String("Bool")
    if t.kind == ST_INT:
        return String("Int64")
    if t.kind == ST_NUMBER:
        return String("Float64")
    if t.kind == ST_STRING:
        return String("String")
    if t.kind == ST_TIMESTAMP:
        return String("TomlDateTime")
    if t.kind == ST_OBJECT or t.kind == ST_UNION:
        var n = mojo_ident(t.name)
        if self_id >= 0 and tid < len(scc) and self_id < len(scc) and scc[tid] == scc[self_id]:
            return "Box[" + n + "]"
        return n
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


def _in_scc(doc: SchemaDoc, tid: Int, scc: List[Int], self_id: Int) -> Bool:
    var t = _unwrap(doc, tid).copy()
    if t.kind != ST_OBJECT and t.kind != ST_UNION:
        return False
    var id = tid
    var cur = doc.types[tid].copy()
    while cur.kind == ST_REF or cur.kind == ST_OPTIONAL:
        if cur.inner < 0:
            break
        id = cur.inner
        cur = doc.types[id].copy()
    if id >= len(scc) or self_id >= len(scc):
        return False
    return scc[id] == scc[self_id]


def _emit_struct(doc: SchemaDoc, ty: SchemaType, name: String, self_id: Int) raises DecodeError -> String:
    var scc = scc_ids(doc)
    var refs = List[String]()
    _collect_refs(doc, ty, name, refs)
    var out = String("from std.collections import List, Optional\n\n")
    out += "from gldtoml_runtime.box import Box\n"
    out += "from gldtoml_runtime.datum import TomlDatum\n"
    out += "from gldtoml_runtime.error import DecodeError\n"
    out += "from gldtoml_runtime.options import EncodeOptions\n"
    out += "from gldtoml_wire.doc import (\n"
    out += "    TK_ARRAY,\n    TK_DATETIME,\n    TK_FALSE,\n    TK_FLOAT,\n    TK_INT,\n"
    out += "    TK_STRING,\n    TK_TABLE,\n    TK_TRUE,\n    TomlDateTime,\n    TomlDoc,\n)\n"
    out += "from gldtoml_wire.flat import parse_f64, parse_i64, parse_toml_str, skip_tail, span_is, take_prefix, value_end\n"
    out += "from gldtoml_wire.reader import decode_toml\n"
    out += "from gldtoml_wire.writer import append_ascii, append_bool, append_datetime, append_float, append_int, append_toml_str\n"
    var i = 0
    while i < len(refs):
        out += "from " + refs[i] + " import " + refs[i] + "\n"
        i += 1
    out += "\nstruct " + name + "(Copyable, Movable, Defaultable, Deinitable, TomlDatum):\n"
    if ty.kind == ST_UNION:
        out += "    var tag: Int\n"
        i = 0
        while i < len(ty.branch_ids):
            var bn = mojo_ident(_unwrap(doc, ty.branch_ids[i]).name)
            var field = mojo_ident(bn)
            out += "    var " + field + ": Optional[" + bn + "]\n"
            i += 1
    else:
        i = 0
        while i < len(ty.props):
            var p = ty.props[i].copy()
            if p.required and _in_scc(doc, p.type_id, scc, self_id):
                raise DecodeError(DecodeError.KIND_SCHEMA, 0)
            var fty = _type_name(doc, p.type_id, scc, self_id)
            out += "    var " + mojo_ident(p.name) + ": " + fty + "\n"
            i += 1
    out += "\n    def __init__(out self):\n"
    if ty.kind == ST_UNION:
        out += "        self.tag = 0\n"
        i = 0
        while i < len(ty.branch_ids):
            var bn = mojo_ident(_unwrap(doc, ty.branch_ids[i]).name)
            out += "        self." + mojo_ident(bn) + " = Optional[" + bn + "]()\n"
            i += 1
    else:
        i = 0
        while i < len(ty.props):
            var p = ty.props[i].copy()
            var fname = mojo_ident(p.name)
            var fty = _type_name(doc, p.type_id, scc, self_id)
            out += "        self." + fname + " = " + _zero(fty) + "\n"
            i += 1
    out += "\n    def encoded_len(self, options: EncodeOptions) raises -> Int:\n"
    out += "        var buf = List[Byte]()\n"
    out += "        self.encode_to(buf, options)\n"
    out += "        return len(buf)\n\n"
    out += "    def encode_to(self, mut buf: List[Byte], options: EncodeOptions) raises:\n"
    out += "        var start = len(buf)\n"
    out += "        self._write(buf, options, True, String(), False)\n"
    out += "        if len(buf) == start or Int(buf[len(buf) - 1]) != 10:\n"
    out += "            buf.append(Byte(10))\n\n"
    out += "    def _write(self, mut buf: List[Byte], options: EncodeOptions, root: Bool, prefix: String, inline: Bool) raises:\n"
    out += "        if inline or ((not root) and options.inline_tables):\n"
    out += "            self._write_inline(buf, options)\n"
    out += "            return\n"
    if ty.kind == ST_UNION:
        out += _emit_union_write(doc, ty, False)
    else:
        out += _emit_object_write(doc, ty, scc, self_id, False)
    out += "\n    def _write_inline(self, mut buf: List[Byte], options: EncodeOptions) raises:\n"
    if ty.kind == ST_UNION:
        out += _emit_union_write(doc, ty, True)
    else:
        out += _emit_object_write(doc, ty, scc, self_id, True)
    out += "\n    def read_text(mut self, text: String) raises DecodeError:\n"
    if ty.kind == ST_OBJECT and _is_flat(doc, ty):
        out += _emit_flat_read(doc, ty)
    else:
        out += "        var doc = decode_toml(text)\n"
        out += "        self.read_from(doc, doc.root)\n"
    out += "\n    def read_from(mut self, doc: TomlDoc, node: Int) raises DecodeError:\n"
    if ty.kind == ST_UNION:
        out += _emit_union_read(doc, ty)
    else:
        out += _emit_read(doc, ty, scc, self_id)
    return out


def _zero(fty: String) -> String:
    if fty == "Bool":
        return String("False")
    if fty == "Int64":
        return String("Int64(0)")
    if fty == "Float64":
        return String("Float64(0)")
    if fty == "String":
        return String("String()")
    if fty == "TomlDateTime":
        return String("TomlDateTime()")
    if fty.startswith("Optional["):
        return fty + "()"
    if fty.startswith("List["):
        return fty + "()"
    return fty + "()"


def _collect_refs(doc: SchemaDoc, ty: SchemaType, self_name: String, mut out: List[String]):
    if ty.kind == ST_OBJECT:
        var i = 0
        while i < len(ty.props):
            _collect_tid(doc, ty.props[i].type_id, self_name, out)
            i += 1
    else:
        var i = 0
        while i < len(ty.branch_ids):
            _collect_tid(doc, ty.branch_ids[i], self_name, out)
            i += 1


def _collect_tid(doc: SchemaDoc, tid: Int, self_name: String, mut out: List[String]):
    var t = doc.types[tid].copy()
    if t.kind == ST_OPTIONAL or t.kind == ST_ARRAY or t.kind == ST_REF or t.kind == ST_ENUM or t.kind == ST_CONST:
        if t.inner >= 0:
            _collect_tid(doc, t.inner, self_name, out)
        return
    if t.kind != ST_OBJECT and t.kind != ST_UNION:
        return
    var n = mojo_ident(t.name)
    if n == self_name or n.byte_length() == 0:
        return
    var j = 0
    while j < len(out):
        if out[j] == n:
            return
        j += 1
    out.append(n)


def _emit_fill(doc: SchemaDoc, ty: SchemaType, scc: List[Int], self_id: Int) raises DecodeError -> String:
    var out = String("")
    var i = 0
    while i < len(ty.props):
        var p = ty.props[i].copy()
        var fname = mojo_ident(p.name)
        var key = p.name
        out += "        var _k" + String(i) + " = doc.add_text(String(\"" + key + "\"))\n"
        out += _fill_expr(doc, "self." + fname, p.type_id, "_k" + String(i), scc, self_id, 8)
        i += 1
    if len(ty.props) == 0:
        out += "        _ = node\n"
    return out


def _fill_expr(
    doc: SchemaDoc,
    expr: String,
    tid: Int,
    keyvar: String,
    scc: List[Int],
    self_id: Int,
    pad: Int,
) raises DecodeError -> String:
    _ = scc
    _ = self_id
    var ind = String("        ")
    var t = doc.types[tid].copy()
    if t.kind == ST_OPTIONAL:
        var inner = _unwrap(doc, t.inner).copy()
        var body = String("")
        body += ind + "if " + expr + ":\n"
        body += ind + "    var _inner = " + expr + ".value().copy()\n"
        if inner.kind == ST_OBJECT or inner.kind == ST_UNION:
            var use = "_inner"
            if _in_scc(doc, t.inner, scc, self_id):
                use = "_inner[]"
            body += ind + "    var _child = doc.make_table(node)\n"
            body += ind + "    " + use + "._fill(doc, _child)\n"
            body += ind + "    doc.append_child(node, " + keyvar + ", _child)\n"
        else:
            body += _store_scalar(doc, "_inner", t.inner, keyvar, "    ")
        return body
    var u = _unwrap(doc, tid).copy()
    if u.kind == ST_OBJECT or u.kind == ST_UNION:
        var use = expr
        if _in_scc(doc, tid, scc, self_id):
            use = expr + "[]"
        var body = String("")
        body += ind + "var _child = doc.make_table(node)\n"
        body += ind + use + "._fill(doc, _child)\n"
        body += ind + "doc.append_child(node, " + keyvar + ", _child)\n"
        return body
    if u.kind == ST_ARRAY:
        return _fill_array(doc, expr, u, keyvar, scc, self_id)
    return _store_scalar(doc, expr, tid, keyvar, "")


def _store_scalar(doc: SchemaDoc, expr: String, tid: Int, keyvar: String, extra: String) -> String:
    var u = _unwrap(doc, tid).copy()
    var ind = String("        ") + extra
    if u.kind == ST_BOOL:
        return ind + "doc.append_child(node, " + keyvar + ", doc.make_bool(" + expr + ", node))\n"
    if u.kind == ST_INT:
        return ind + "doc.append_child(node, " + keyvar + ", doc.make_int(" + expr + ", node))\n"
    if u.kind == ST_NUMBER:
        return ind + "doc.append_child(node, " + keyvar + ", doc.make_float(UInt64((" + expr + ").to_bits()), node))\n"
    if u.kind == ST_STRING:
        return ind + "doc.append_child(node, " + keyvar + ", doc.make_string(String(" + expr + "), node))\n"
    if u.kind == ST_TIMESTAMP:
        return ind + "doc.append_child(node, " + keyvar + ", doc.make_datetime(" + expr + ", node))\n"
    return ind + "_ = " + expr + "\n"


def _fill_array(
    doc: SchemaDoc, expr: String, arr: SchemaType, keyvar: String, scc: List[Int], self_id: Int
) raises DecodeError -> String:
    _ = scc
    _ = self_id
    var inner = _unwrap(doc, arr.inner).copy()
    var out = String("        var _arr = doc.make_array(node)\n")
    out += "        var _i = 0\n"
    out += "        while _i < len(" + expr + "):\n"
    if inner.kind == ST_OBJECT or inner.kind == ST_UNION:
        out += "            var _el = doc.make_table(_arr)\n"
        out += "            " + expr + "[_i]._fill(doc, _el)\n"
        out += "            doc.append_child(_arr, -1, _el)\n"
    elif inner.kind == ST_INT:
        out += "            doc.append_child(_arr, -1, doc.make_int(" + expr + "[_i], _arr))\n"
    elif inner.kind == ST_NUMBER:
        out += "            doc.append_child(_arr, -1, doc.make_float(UInt64((" + expr + "[_i]).to_bits()), _arr))\n"
    elif inner.kind == ST_STRING:
        out += "            doc.append_child(_arr, -1, doc.make_string(String(" + expr + "[_i]), _arr))\n"
    elif inner.kind == ST_BOOL:
        out += "            doc.append_child(_arr, -1, doc.make_bool(" + expr + "[_i], _arr))\n"
    else:
        out += "            _ = _i\n"
    out += "            _i += 1\n"
    out += "        doc.append_child(node, " + keyvar + ", _arr)\n"
    return out


def _emit_read(doc: SchemaDoc, ty: SchemaType, scc: List[Int], self_id: Int) raises DecodeError -> String:
    var out = String("        if doc.kind(node) != TK_TABLE:\n")
    out += "            raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
    var i = 0
    while i < len(ty.props):
        var p = ty.props[i].copy()
        var fname = mojo_ident(p.name)
        out += "        var _n" + String(i) + " = doc.find_key(node, \"" + p.name + "\")\n"
        if p.required:
            out += "        if _n" + String(i) + " < 0:\n"
            out += "            raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
            out += _read_into(doc, "self." + fname, p.type_id, "_n" + String(i), scc, self_id, False)
        else:
            out += "        if _n" + String(i) + " < 0:\n"
            out += "            self." + fname + " = " + _zero(_type_name(doc, p.type_id, scc, self_id)) + "\n"
            out += "        else:\n"
            out += _read_into(doc, "self." + fname, p.type_id, "_n" + String(i), scc, self_id, True)
        i += 1
    if len(ty.props) == 0:
        out += "        _ = doc\n"
    return out


def _read_into(
    doc: SchemaDoc,
    dest: String,
    tid: Int,
    nvar: String,
    scc: List[Int],
    self_id: Int,
    optional: Bool,
) raises DecodeError -> String:
    var u = _unwrap(doc, tid).copy()
    var ind = String("        ")
    if optional:
        ind += "    "
    if u.kind == ST_BOOL:
        return ind + dest + " = doc.kind(" + nvar + ") == TK_TRUE\n"
    if u.kind == ST_INT:
        return ind + dest + " = doc.int_at(" + nvar + ")\n"
    if u.kind == ST_NUMBER:
        return ind + dest + " = doc.float_at(" + nvar + ")\n"
    if u.kind == ST_STRING:
        return ind + dest + " = doc.text_at(" + nvar + ")\n"
    if u.kind == ST_TIMESTAMP:
        return ind + dest + " = doc.date_at(" + nvar + ")\n"
    if u.kind == ST_ARRAY:
        return _read_array(doc, dest, u, nvar, optional)
    if u.kind == ST_OBJECT or u.kind == ST_UNION:
        var n = mojo_ident(u.name)
        var boxed = _in_scc(doc, tid, scc, self_id)
        var body = String("")
        body += ind + "var _obj = " + n + "()\n"
        body += ind + "_obj.read_from(doc, " + nvar + ")\n"
        if optional and boxed:
            body += ind + dest + " = Optional[Box[" + n + "]](Box( _obj^))\n"
        elif optional:
            body += ind + dest + " = Optional[" + n + "](_obj^)\n"
        elif boxed:
            body += ind + dest + " = Box(_obj^)\n"
        else:
            body += ind + dest + " = _obj^\n"
        return body
    return ind + "_ = " + nvar + "\n"


def _read_array(doc: SchemaDoc, dest: String, arr: SchemaType, nvar: String, optional: Bool) -> String:
    var inner = _unwrap(doc, arr.inner).copy()
    var ind = String("        ")
    if optional:
        ind += "    "
    var elem = String("Int64")
    if inner.kind == ST_BOOL:
        elem = String("Bool")
    elif inner.kind == ST_NUMBER:
        elem = String("Float64")
    elif inner.kind == ST_STRING:
        elem = String("String")
    elif inner.kind == ST_OBJECT or inner.kind == ST_UNION:
        elem = mojo_ident(inner.name)
    var out = ind + dest + " = List[" + elem + "]()\n"
    out += ind + "var _e = doc.first_edge(" + nvar + ")\n"
    out += ind + "while _e >= 0:\n"
    out += ind + "    var _c = doc.edges[_e].child\n"
    if inner.kind == ST_OBJECT or inner.kind == ST_UNION:
        out += ind + "    var _item = " + elem + "()\n"
        out += ind + "    _item.read_from(doc, _c)\n"
        out += ind + "    " + dest + ".append(_item^)\n"
    elif inner.kind == ST_INT:
        out += ind + "    " + dest + ".append(doc.int_at(_c))\n"
    elif inner.kind == ST_NUMBER:
        out += ind + "    " + dest + ".append(doc.float_at(_c))\n"
    elif inner.kind == ST_STRING:
        out += ind + "    " + dest + ".append(doc.text_at(_c))\n"
    elif inner.kind == ST_BOOL:
        out += ind + "    " + dest + ".append(doc.kind(_c) == TK_TRUE)\n"
    out += ind + "    _e = doc.edges[_e].next\n"
    return out


def _bare_key(name: String) -> Bool:
    var b = name.as_bytes()
    if len(b) == 0:
        return False
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        var ok = (
            (c >= 65 and c <= 90)
            or (c >= 97 and c <= 122)
            or (c >= 48 and c <= 57)
            or c == 95
            or c == 45
        )
        if not ok:
            return False
        i += 1
    return True


def _byte_appends(text: String, pad: String) -> String:
    var out = String("")
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        out += pad + "buf.append(Byte(" + String(Int(b[i])) + "))\n"
        i += 1
    return out


def _key_lit(name: String) -> String:
    if _bare_key(name):
        return "append_ascii(buf, \"" + name + "\")\n"
    return "append_toml_str(buf, String(\"" + name + "\"))\n"


def _key_eq(name: String, pad: String) -> String:
    if _bare_key(name):
        return _byte_appends(name + " = ", pad)
    return pad + "append_toml_str(buf, String(\"" + name + "\"))\n" + pad + "append_ascii(buf, \" = \")\n"


def _emit_object_write(
    doc: SchemaDoc, ty: SchemaType, scc: List[Int], self_id: Int, inline: Bool
) raises DecodeError -> String:
    _ = scc
    _ = self_id
    var out = String("")
    if inline:
        out += "        buf.append(Byte(123))\n"
        out += "        var _first = True\n"
    else:
        out += "        _ = prefix\n"
    var i = 0
    while i < len(ty.props):
        var p = ty.props[i].copy()
        var fname = mojo_ident(p.name)
        var expr = String("self.") + fname
        var optional = doc.types[p.type_id].kind == ST_OPTIONAL
        var inner_id = p.type_id
        if optional:
            inner_id = doc.types[p.type_id].inner
        var u = _unwrap(doc, inner_id).copy()
        if optional:
            var slot = String("_in") + String(i)
            out += "        if " + expr + ":\n"
            out += "            var " + slot + " = " + expr + ".value().copy()\n"
            expr = slot
            if _in_scc(doc, inner_id, scc, self_id):
                expr = slot + "[]"
        var pad = String("        ")
        if optional:
            pad += "    "
        if inline:
            out += pad + "if not _first:\n"
            out += pad + "    append_ascii(buf, \", \")\n"
            out += pad + "_first = False\n"
            out += pad + _key_lit(p.name)
            out += pad + "append_ascii(buf, \" = \")\n"
            out += _emit_value_write(doc, u, expr, pad, True, p.name)
        else:
            out += _emit_std_field(doc, u, expr, p.name, pad, i)
        i += 1
    if inline:
        out += "        buf.append(Byte(125))\n"
        if len(ty.props) == 0:
            out += "        _ = options\n"
    elif len(ty.props) == 0:
        out += "        _ = options\n        _ = buf\n"
    return out


def _emit_std_field(
    doc: SchemaDoc, u: SchemaType, expr: String, key: String, pad: String, slot: Int
) -> String:
    var out = String("")
    if u.kind == ST_OBJECT or u.kind == ST_UNION:
        var next = "prefix + \"." + key + "\""
        var np = String("_np") + String(slot)
        out += pad + "var " + np + " = String(\"" + key + "\")\n"
        out += pad + "if prefix.byte_length() > 0:\n"
        out += pad + "    " + np + " = prefix + \"." + key + "\"\n"
        out += pad + "if options.inline_tables:\n"
        out += pad + "    " + _key_lit(key)
        out += pad + "    append_ascii(buf, \" = \")\n"
        out += pad + "    " + expr + "._write(buf, options, False, " + np + ", True)\n"
        out += pad + "    buf.append(Byte(10))\n"
        out += pad + "else:\n"
        out += pad + "    buf.append(Byte(10))\n"
        out += pad + "    append_ascii(buf, \"[\")\n"
        out += pad + "    append_ascii(buf, " + np + ")\n"
        out += pad + "    append_ascii(buf, \"]\\n\")\n"
        out += pad + "    " + expr + "._write(buf, options, False, " + np + ", False)\n"
        _ = next
        return out
    if u.kind == ST_ARRAY:
        var inner = _unwrap(doc, u.inner).copy()
        if inner.kind == ST_OBJECT or inner.kind == ST_UNION:
            var next = "prefix + \"." + key + "\""
            var np = String("_np") + String(slot)
            var ix = String("_i") + String(slot)
            out += pad + "var " + np + " = String(\"" + key + "\")\n"
            out += pad + "if prefix.byte_length() > 0:\n"
            out += pad + "    " + np + " = prefix + \"." + key + "\"\n"
            out += pad + "var " + ix + " = 0\n"
            out += pad + "if options.compact_arrays or options.inline_tables:\n"
            out += pad + "    " + _key_lit(key)
            out += pad + "    append_ascii(buf, \" = [\")\n"
            out += pad + "    while " + ix + " < len(" + expr + "):\n"
            out += pad + "        if " + ix + " > 0:\n"
            out += pad + "            append_ascii(buf, \", \")\n"
            out += pad + "        " + expr + "[" + ix + "]._write(buf, options, False, " + np + ", True)\n"
            out += pad + "        " + ix + " += 1\n"
            out += pad + "    append_ascii(buf, \"]\\n\")\n"
            out += pad + "else:\n"
            out += pad + "    while " + ix + " < len(" + expr + "):\n"
            out += pad + "        buf.append(Byte(10))\n"
            out += pad + "        append_ascii(buf, \"[[\")\n"
            out += pad + "        append_ascii(buf, " + np + ")\n"
            out += pad + "        append_ascii(buf, \"]]\\n\")\n"
            out += pad + "        " + expr + "[" + ix + "]._write(buf, options, False, " + np + ", False)\n"
            out += pad + "        " + ix + " += 1\n"
            _ = next
            return out
        var ix = String("_i") + String(slot)
        out += pad + _key_lit(key)
        out += pad + "append_ascii(buf, \" = [\")\n"
        out += pad + "var " + ix + " = 0\n"
        out += pad + "while " + ix + " < len(" + expr + "):\n"
        out += pad + "    if " + ix + " > 0:\n"
        out += pad + "        append_ascii(buf, \", \")\n"
        out += pad + "    " + _scalar_write(inner, expr + "[" + ix + "]")
        out += pad + "    " + ix + " += 1\n"
        out += pad + "append_ascii(buf, \"]\\n\")\n"
        return out
    out += _key_eq(key, pad)
    out += pad + _scalar_write(u, expr)
    out += pad + "buf.append(Byte(10))\n"
    return out


def _emit_value_write(
    doc: SchemaDoc, u: SchemaType, expr: String, pad: String, inline: Bool, key: String
) -> String:
    _ = doc
    _ = inline
    _ = key
    if u.kind == ST_OBJECT or u.kind == ST_UNION:
        return pad + expr + "._write(buf, options, False, String(), True)\n"
    if u.kind == ST_ARRAY:
        var inner = _unwrap(doc, u.inner).copy()
        var out = pad + "buf.append(Byte(91))\n"
        out += pad + "var _i = 0\n"
        out += pad + "while _i < len(" + expr + "):\n"
        out += pad + "    if _i > 0:\n"
        out += pad + "        append_ascii(buf, \", \")\n"
        if inner.kind == ST_OBJECT or inner.kind == ST_UNION:
            out += pad + "    " + expr + "[_i]._write(buf, options, False, String(), True)\n"
        else:
            out += pad + "    " + _scalar_write(inner, expr + "[_i]")
        out += pad + "    _i += 1\n"
        out += pad + "buf.append(Byte(93))\n"
        return out
    return pad + _scalar_write(u, expr)


def _scalar_write(u: SchemaType, expr: String) -> String:
    if u.kind == ST_BOOL:
        return "append_bool(buf, " + expr + ")\n"
    if u.kind == ST_INT:
        return "append_int(buf, " + expr + ")\n"
    if u.kind == ST_NUMBER:
        return "append_float(buf, " + expr + ")\n"
    if u.kind == ST_STRING:
        return "append_toml_str(buf, " + expr + ")\n"
    if u.kind == ST_TIMESTAMP:
        return "append_datetime(buf, " + expr + ")\n"
    return "_ = " + expr + "\n"


def _is_flat(doc: SchemaDoc, ty: SchemaType) -> Bool:
    var i = 0
    while i < len(ty.props):
        var tid = ty.props[i].type_id
        var u = _unwrap(doc, tid).copy()
        if u.kind != ST_BOOL and u.kind != ST_INT and u.kind != ST_NUMBER and u.kind != ST_STRING:
            return False
        i += 1
    return True


def _all_required(ty: SchemaType) -> Bool:
    var i = 0
    while i < len(ty.props):
        if not ty.props[i].required:
            return False
        i += 1
    return True


def _emit_ordered(doc: SchemaDoc, ty: SchemaType) -> String:
    var out = String("        var _ord = 0\n")
    var i = 0
    while i < len(ty.props):
        var prop = ty.props[i].copy()
        var fname = mojo_ident(prop.name)
        var u = _unwrap(doc, prop.type_id).copy()
        out += "        if _ord >= 0:\n"
        out += "            var _nx = take_prefix(raw, _ord, \"" + prop.name + " = \")\n"
        out += "            if _nx < 0:\n"
        out += "                _ord = -1\n"
        out += "            else:\n"
        out += "                var _ve = value_end(raw, _nx)\n"
        if u.kind == ST_BOOL:
            out += "                self." + fname + " = span_is(raw, _nx, _ve, \"true\")\n"
            out += "                if not self." + fname + " and not span_is(raw, _nx, _ve, \"false\"):\n"
            out += "                    _ord = -1\n"
            out += "                else:\n"
            out += "                    _ord = skip_tail(raw, _ve)\n"
        elif u.kind == ST_INT:
            out += "                self." + fname + " = parse_i64(raw, _nx, _ve)\n"
            out += "                _ord = skip_tail(raw, _ve)\n"
        elif u.kind == ST_NUMBER:
            out += "                self." + fname + " = parse_f64(raw, _nx, _ve)\n"
            out += "                _ord = skip_tail(raw, _ve)\n"
        elif u.kind == ST_STRING:
            out += "                var _esc = _nx\n"
            out += "                while _esc < _ve and Int(raw[_esc]) != 92:\n"
            out += "                    _esc += 1\n"
            out += "                if _esc < _ve:\n"
            out += "                    _ord = -1\n"
            out += "                else:\n"
            out += "                    self." + fname + " = parse_toml_str(raw, _nx, _ve)\n"
            out += "                    _ord = skip_tail(raw, _ve)\n"
        else:
            out += "                _ord = -1\n"
        i += 1
    out += "        if _ord >= 0:\n"
    out += "            while _ord < n and (Int(raw[_ord]) == 32 or Int(raw[_ord]) == 9 or Int(raw[_ord]) == 10 or Int(raw[_ord]) == 13):\n"
    out += "                _ord += 1\n"
    out += "            if _ord == n:\n"
    out += "                return\n"
    return out


def _emit_flat_read(doc: SchemaDoc, ty: SchemaType) -> String:
    var out = String("        var raw = text.as_bytes()\n")
    out += "        var n = len(raw)\n"
    if _all_required(ty):
        out += _emit_ordered(doc, ty)
    out += "        var i = 0\n"
    out += "        while i < n:\n"
    out += "            var c = Int(raw[i])\n"
    out += "            if c == 91 or c == 92 or c == 123:\n"
    out += "                var doc = decode_toml(text)\n"
    out += "                self.read_from(doc, doc.root)\n"
    out += "                return\n"
    out += "            i += 1\n"
    out += "        i = 0\n"
    var p = 0
    while p < len(ty.props):
        if ty.props[p].required:
            out += "        var _saw" + String(p) + " = False\n"
        p += 1
    out += "        while i < n:\n"
    out += "            var c = Int(raw[i])\n"
    out += "            if c == 32 or c == 9 or c == 10 or c == 13:\n"
    out += "                i += 1\n"
    out += "                continue\n"
    out += "            if c == 35:\n"
    out += "                while i < n and Int(raw[i]) != 10:\n"
    out += "                    i += 1\n"
    out += "                continue\n"
    out += "            var ks = i\n"
    out += "            while i < n:\n"
    out += "                c = Int(raw[i])\n"
    out += "                if c == 32 or c == 9 or c == 61:\n"
    out += "                    break\n"
    out += "                i += 1\n"
    out += "            var ke = i\n"
    out += "            while i < n and (Int(raw[i]) == 32 or Int(raw[i]) == 9):\n"
    out += "                i += 1\n"
    out += "            if i >= n or Int(raw[i]) != 61:\n"
    out += "                raise DecodeError(DecodeError.KIND_SYNTAX, i)\n"
    out += "            i += 1\n"
    out += "            while i < n and (Int(raw[i]) == 32 or Int(raw[i]) == 9):\n"
    out += "                i += 1\n"
    out += "            var vs = i\n"
    out += "            if i < n and (Int(raw[i]) == 34 or Int(raw[i]) == 39):\n"
    out += "                var q = Int(raw[i])\n"
    out += "                i += 1\n"
    out += "                while i < n and Int(raw[i]) != q:\n"
    out += "                    if Int(raw[i]) == 92:\n"
    out += "                        i += 1\n"
    out += "                    if i < n:\n"
    out += "                        i += 1\n"
    out += "                if i < n:\n"
    out += "                    i += 1\n"
    out += "            else:\n"
    out += "                while i < n and Int(raw[i]) != 10 and Int(raw[i]) != 35:\n"
    out += "                    i += 1\n"
    out += "            var ve = i\n"
    out += "            while ve > vs and (Int(raw[ve - 1]) == 32 or Int(raw[ve - 1]) == 9):\n"
    out += "                ve -= 1\n"
    p = 0
    while p < len(ty.props):
        var prop = ty.props[p].copy()
        var fname = mojo_ident(prop.name)
        var u = _unwrap(doc, prop.type_id).copy()
        var kw = "if"
        if p > 0:
            kw = "elif"
        out += "            " + kw + " span_is(raw, ks, ke, \"" + prop.name + "\"):\n"
        if prop.required:
            out += "                _saw" + String(p) + " = True\n"
        if u.kind == ST_BOOL:
            out += "                self." + fname + " = span_is(raw, vs, ve, \"true\")\n"
            out += "                if not self." + fname + " and not span_is(raw, vs, ve, \"false\"):\n"
            out += "                    raise DecodeError(DecodeError.KIND_SYNTAX, vs)\n"
        elif u.kind == ST_INT:
            out += "                self." + fname + " = parse_i64(raw, vs, ve)\n"
        elif u.kind == ST_NUMBER:
            out += "                self." + fname + " = parse_f64(raw, vs, ve)\n"
        elif u.kind == ST_STRING:
            out += "                self." + fname + " = parse_toml_str(raw, vs, ve)\n"
        else:
            out += "                _ = vs\n"
        p += 1
    p = 0
    while p < len(ty.props):
        if ty.props[p].required:
            out += "        if not _saw" + String(p) + ":\n"
            out += "            raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
        p += 1
    return out


def _emit_union_write(doc: SchemaDoc, ty: SchemaType, inline: Bool) -> String:
    var out = String("")
    if inline:
        out += "        _ = options\n"
    else:
        out += "        _ = prefix\n        _ = root\n        _ = inline\n"
    var i = 0
    while i < len(ty.branch_ids):
        var bn = mojo_ident(_unwrap(doc, ty.branch_ids[i]).name)
        var field = mojo_ident(bn)
        out += "        if self.tag == " + String(i) + " and self." + field + ":\n"
        if inline:
            out += "            self." + field + ".value()._write_inline(buf, options)\n"
        else:
            out += "            self." + field + ".value()._write(buf, options, True, prefix, False)\n"
        out += "            return\n"
        i += 1
    if inline:
        out += "        buf.append(Byte(123))\n        buf.append(Byte(125))\n"
    return out


def _emit_union_read(doc: SchemaDoc, ty: SchemaType) -> String:
    var out = String("        if doc.kind(node) != TK_TABLE:\n")
    out += "            raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
    var i = 0
    while i < len(ty.branch_ids):
        var branch = _unwrap(doc, ty.branch_ids[i]).copy()
        var bn = mojo_ident(branch.name)
        var field = mojo_ident(bn)
        out += "        var _ok" + String(i) + " = True\n"
        var p = 0
        while p < len(branch.props):
            var prop = branch.props[p].copy()
            if prop.required:
                out += "        if doc.find_key(node, \"" + prop.name + "\") < 0:\n"
                out += "            _ok" + String(i) + " = False\n"
            p += 1
        out += "        if _ok" + String(i) + ":\n"
        out += "            var _b = " + bn + "()\n"
        out += "            _b.read_from(doc, node)\n"
        out += "            self.tag = " + String(i) + "\n"
        out += "            self." + field + " = Optional[" + bn + "](_b^)\n"
        out += "            return\n"
        i += 1
    out += "        raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
    return out
