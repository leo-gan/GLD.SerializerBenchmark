from std.collections import List

from smile_codegen.names import field_name, struct_name
from smile_runtime.error import DecodeError
from smile_schema.model import (
    ST_ARRAY,
    ST_BIGINT,
    ST_BINARY,
    ST_BOOL,
    ST_CONST,
    ST_DECIMAL,
    ST_ENUM,
    ST_INT,
    ST_NULL,
    ST_NUMBER,
    ST_OBJECT,
    ST_OPTIONAL,
    ST_REF,
    ST_STRING,
    ST_UNION,
    SchemaDoc,
    SchemaProp,
    SchemaType,
)


def emit_all(doc: SchemaDoc) raises DecodeError -> List[String]:
    _reject_cycles(doc)
    var names = _assign_names(doc)
    var files = List[String]()
    var seen = List[String]()
    var i = 0
    while i < len(doc.types):
        var t = doc.types[i].copy()
        if t.kind == ST_OBJECT or t.kind == ST_UNION:
            var sname = names[i]
            var dup = False
            var k = 0
            while k < len(seen):
                if seen[k] == sname:
                    dup = True
                k += 1
            if not dup and sname.byte_length() > 0:
                seen.append(sname)
                files.append(sname)
                if t.kind == ST_OBJECT:
                    files.append(_emit_object(doc, names, i, sname))
                else:
                    files.append(_emit_union(doc, names, i, sname))
        i += 1
    return files^


def _assign_names(doc: SchemaDoc) -> List[String]:
    var names = List[String]()
    var used = List[String]()
    var i = 0
    while i < len(doc.types):
        var t = doc.types[i].copy()
        var base = String()
        if t.kind == ST_OBJECT or t.kind == ST_UNION:
            base = struct_name(t.name)
            var k = 0
            var clash = False
            while k < len(used):
                if used[k] == base:
                    clash = True
                k += 1
            if clash:
                base = base + "_" + String(i)
            used.append(base)
        names.append(base)
        i += 1
    return names^


def _reject_cycles(doc: SchemaDoc) raises DecodeError:
    var color = List[Int]()
    var i = 0
    while i < len(doc.types):
        color.append(0)
        i += 1
    i = 0
    while i < len(doc.types):
        _visit(doc, i, color)
        i += 1


def _visit(doc: SchemaDoc, tid: Int, mut color: List[Int]) raises DecodeError:
    if tid < 0:
        return
    if color[tid] == 1:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    if color[tid] == 2:
        return
    color[tid] = 1
    var t = doc.types[tid].copy()
    if t.inner >= 0:
        _visit(doc, t.inner, color)
    var p = 0
    while p < len(t.props):
        _visit(doc, t.props[p].type_id, color)
        p += 1
    var b = 0
    while b < len(t.branch_ids):
        _visit(doc, t.branch_ids[b], color)
        b += 1
    color[tid] = 2


def _type_expr(doc: SchemaDoc, names: List[String], tid: Int) -> String:
    var t = doc.types[tid].copy()
    if t.kind == ST_OPTIONAL:
        return "Optional[" + _type_expr(doc, names, t.inner) + "]"
    if t.kind == ST_ARRAY:
        return "List[" + _type_expr(doc, names, t.inner) + "]"
    if t.kind == ST_REF or t.kind == ST_ENUM or t.kind == ST_CONST:
        return _type_expr(doc, names, t.inner)
    if t.kind == ST_BOOL:
        return String("Bool")
    if t.kind == ST_INT:
        return String("Int64")
    if t.kind == ST_NUMBER:
        return String("Float64")
    if t.kind == ST_STRING or t.kind == ST_BIGINT or t.kind == ST_DECIMAL:
        return String("String")
    if t.kind == ST_BINARY:
        return String("List[Byte]")
    if t.kind == ST_NULL:
        return String("Bool")
    if t.kind == ST_OBJECT or t.kind == ST_UNION:
        return names[tid]
    return String("Int64")


def _default_expr(doc: SchemaDoc, names: List[String], tid: Int) -> String:
    var t = doc.types[tid].copy()
    if t.kind == ST_OPTIONAL:
        return "Optional[" + _type_expr(doc, names, t.inner) + "]()"
    if t.kind == ST_ARRAY:
        return "List[" + _type_expr(doc, names, t.inner) + "]()"
    if t.kind == ST_REF or t.kind == ST_ENUM or t.kind == ST_CONST:
        return _default_expr(doc, names, t.inner)
    if t.kind == ST_BOOL or t.kind == ST_NULL:
        return String("False")
    if t.kind == ST_INT:
        return String("0")
    if t.kind == ST_NUMBER:
        return String("0.0")
    if t.kind == ST_STRING or t.kind == ST_BIGINT or t.kind == ST_DECIMAL:
        return String("String()")
    if t.kind == ST_BINARY:
        return String("List[Byte]()")
    if t.kind == ST_OBJECT or t.kind == ST_UNION:
        return names[tid] + "()"
    return String("0")


def _lit(text: String) -> String:
    var raw = text.as_bytes()
    var out = String("\"")
    var i = 0
    while i < len(raw):
        var c = Int(raw[i])
        if c == 34 or c == 92:
            out = out + "\\" + chr(c)
        elif c == 10:
            out = out + "\\n"
        else:
            out = out + chr(c)
        i += 1
    return out + "\""


def _core_kind(doc: SchemaDoc, tid: Int) -> Int:
    var t = doc.types[tid].copy()
    var guard = 0
    while guard < 32 and (
        t.kind == ST_REF or t.kind == ST_OPTIONAL or t.kind == ST_ENUM or t.kind == ST_CONST
    ):
        if t.inner < 0:
            break
        t = doc.types[t.inner].copy()
        guard += 1
    return t.kind


def _add_dep(mut deps: List[String], name: String):
    if name.byte_length() == 0:
        return
    var i = 0
    while i < len(deps):
        if deps[i] == name:
            return
        i += 1
    deps.append(name)


def _deps(doc: SchemaDoc, names: List[String], tid: Int, mut deps: List[String], self_name: String):
    if tid < 0:
        return
    var t = doc.types[tid].copy()
    if t.kind == ST_OBJECT or t.kind == ST_UNION:
        if names[tid] != self_name:
            _add_dep(deps, names[tid])
        return
    if t.inner >= 0:
        _deps(doc, names, t.inner, deps, self_name)
    var b = 0
    while b < len(t.branch_ids):
        _deps(doc, names, t.branch_ids[b], deps, self_name)
        b += 1


def _file_deps(doc: SchemaDoc, names: List[String], tid: Int, self_name: String) -> List[String]:
    var deps = List[String]()
    var t = doc.types[tid].copy()
    var p = 0
    while p < len(t.props):
        _deps(doc, names, t.props[p].type_id, deps, self_name)
        p += 1
    var b = 0
    while b < len(t.branch_ids):
        _deps(doc, names, t.branch_ids[b], deps, self_name)
        b += 1
    return deps^


def _header(deps: List[String]) -> String:
    var out = String("from std.collections import List, Optional, Span\n\n")
    var i = 0
    while i < len(deps):
        out += "from " + deps[i] + " import " + deps[i] + "\n"
        i += 1
    if len(deps) > 0:
        out += "\n"
    return out + (
        "from smile_runtime.bind import (\n"
        + "    array_at,\n"
        + "    array_len,\n"
        + "    find_field,\n"
        + "    is_null,\n"
        + "    put_bigint,\n"
        + "    put_bool,\n"
        + "    put_bytes,\n"
        + "    put_decimal,\n"
        + "    put_f64,\n"
        + "    put_i64,\n"
        + "    put_str,\n"
        + "    read_bigint,\n"
        + "    read_bool,\n"
        + "    read_bytes,\n"
        + "    read_decimal,\n"
        + "    read_f64,\n"
        + "    read_i64,\n"
        + "    read_str,\n"
        + ")\n"
        + "from smile_runtime.doc import K_ARRAY, K_BIGINT, K_BINARY, K_BOOL, K_DECIMAL, K_F32, K_F64, K_I32, K_I64, K_OBJECT, K_STRING, SmileDoc\n"
        + "from smile_runtime.error import DecodeError\n"
        + "from smile_runtime.options import EncodeOptions\n"
        + "from smile_wire.codec import decode, encode\n\n"
    )


def _emit_object(doc: SchemaDoc, names: List[String], tid: Int, sname: String) -> String:
    var t = doc.types[tid].copy()
    var out = _header(_file_deps(doc, names, tid, sname))
    out += "struct " + sname + "(Copyable, Movable):\n"
    var p = 0
    while p < len(t.props):
        var prop = t.props[p].copy()
        out += "    var " + field_name(prop.name) + ": " + _type_expr(doc, names, prop.type_id) + "\n"
        p += 1
    if len(t.props) == 0:
        out += "    var _unused: Int\n"
    out += "\n    def __init__(out self):\n"
    if len(t.props) == 0:
        out += "        self._unused = 0\n"
    p = 0
    while p < len(t.props):
        var prop = t.props[p].copy()
        out += "        self." + field_name(prop.name) + " = " + _default_expr(doc, names, prop.type_id) + "\n"
        p += 1
    out += "\n    def encoded_len(self, options: EncodeOptions) raises DecodeError -> Int:\n"
    out += "        return len(self.to_bytes(options))\n"
    out += "\n    def encode_to(self, mut buf: List[Byte], options: EncodeOptions) raises DecodeError:\n"
    out += "        var raw = self.to_bytes(options)\n"
    out += "        var i = 0\n"
    out += "        while i < len(raw):\n"
    out += "            buf.append(raw[i])\n"
    out += "            i += 1\n"
    out += "\n    def to_bytes(self, options: EncodeOptions) raises DecodeError -> List[Byte]:\n"
    out += "        var doc = SmileDoc()\n"
    out += "        doc.add_top(self.to_node(doc))\n"
    out += "        return encode(doc, options)\n"
    out += "\n    def to_node(self, mut doc: SmileDoc) raises DecodeError -> Int:\n"
    out += "        var obj = doc.start_object()\n"
    p = 0
    while p < len(t.props):
        out += _encode_prop(doc, names, t.props[p].copy())
        p += 1
    out += "        return obj\n"
    out += "\n    def decode_from[origin: ImmOrigin](mut self, raw: Span[Byte, origin]) raises DecodeError:\n"
    out += "        var doc = decode(raw, False)\n"
    out += "        if len(doc.top) != 1:\n"
    out += "            raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
    out += "        self.read_value(doc, doc.top[0])\n"
    out += "\n    def read_value(mut self, doc: SmileDoc, id: Int) raises DecodeError:\n"
    out += "        if doc.nodes[id].kind != K_OBJECT:\n"
    out += "            raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
    p = 0
    while p < len(t.props):
        out += _decode_prop(doc, names, t.props[p].copy())
        p += 1
    return out


def _encode_prop(doc: SchemaDoc, names: List[String], prop: SchemaProp) -> String:
    var fname = field_name(prop.name)
    var key = _lit(prop.name)
    var inner = prop.type_id
    var opt = False
    if doc.types[inner].kind == ST_OPTIONAL:
        opt = True
        inner = doc.types[inner].inner
    var pad = "        "
    var out = String()
    if opt:
        out += pad + "if self." + fname + ":\n"
        pad = "            "
    out += _encode_value(doc, names, "self." + fname, inner, key, pad, opt)
    return out


def _encode_value(
    doc: SchemaDoc,
    names: List[String],
    expr: String,
    tid: Int,
    key: String,
    pad: String,
    opt: Bool,
) -> String:
    var t = doc.types[tid].copy()
    var value = expr
    if opt:
        value = expr + ".value()"
    if t.kind == ST_REF or t.kind == ST_ENUM or t.kind == ST_CONST:
        var out = _encode_value(doc, names, expr, t.inner, key, pad, opt)
        if t.kind == ST_CONST:
            out += pad + _const_check(t, value)
        return out
    if t.kind == ST_INT:
        return pad + "put_i64(doc, obj, " + key + ", Int(" + value + "))\n"
    if t.kind == ST_NUMBER:
        return pad + "put_f64(doc, obj, " + key + ", Float64(" + value + "))\n"
    if t.kind == ST_BOOL:
        return pad + "put_bool(doc, obj, " + key + ", " + value + ")\n"
    if t.kind == ST_STRING:
        return pad + "put_str(doc, obj, " + key + ", " + value + ")\n"
    if t.kind == ST_BINARY:
        return pad + "put_bytes(doc, obj, " + key + ", " + value + ")\n"
    if t.kind == ST_BIGINT:
        return pad + "put_bigint(doc, obj, " + key + ", " + value + ")\n"
    if t.kind == ST_DECIMAL:
        return pad + "put_decimal(doc, obj, " + key + ", " + value + ")\n"
    if t.kind == ST_OBJECT or t.kind == ST_UNION:
        var out = pad + "var _child = " + value + ".to_node(doc)\n"
        out += pad + "doc.add_field(obj, doc._text(String(" + key + ")), _child)\n"
        return out
    if t.kind == ST_ARRAY:
        var out = pad + "var _arr = doc.start_array()\n"
        out += pad + "var _i = 0\n"
        out += pad + "while _i < len(" + value + "):\n"
        out += _encode_elem(doc, names, value + "[_i]", t.inner, pad + "    ")
        out += pad + "    _i += 1\n"
        out += pad + "doc.add_field(obj, doc._text(String(" + key + ")), _arr)\n"
        return out
    return pad + "put_i64(doc, obj, " + key + ", 0)\n"


def _encode_elem(doc: SchemaDoc, names: List[String], expr: String, tid: Int, pad: String) -> String:
    var t = doc.types[tid].copy()
    if t.kind == ST_REF or t.kind == ST_ENUM or t.kind == ST_CONST:
        return _encode_elem(doc, names, expr, t.inner, pad)
    if t.kind == ST_INT:
        return pad + "doc.add_elem(_arr, doc.add_i64(Int(" + expr + ")))\n"
    if t.kind == ST_NUMBER:
        return pad + "doc.add_elem(_arr, doc.add_f64(Float64(" + expr + ")))\n"
    if t.kind == ST_BOOL:
        return pad + "doc.add_elem(_arr, doc.add_bool(" + expr + "))\n"
    if t.kind == ST_STRING:
        return pad + "doc.add_elem(_arr, doc.add_string(" + expr + "))\n"
    if t.kind == ST_OBJECT or t.kind == ST_UNION:
        return pad + "doc.add_elem(_arr, " + expr + ".to_node(doc))\n"
    return pad + "doc.add_elem(_arr, doc.add_i64(0))\n"


def _decode_prop(doc: SchemaDoc, names: List[String], prop: SchemaProp) -> String:
    var fname = field_name(prop.name)
    var key = _lit(prop.name)
    var tid = prop.type_id
    var opt = False
    if doc.types[tid].kind == ST_OPTIONAL:
        opt = True
        tid = doc.types[tid].inner
    var slot = "_f_" + fname
    var out = "        var " + slot + " = find_field(doc, id, " + key + ")\n"
    if opt:
        out += "        if " + slot + " < 0 or is_null(doc, " + slot + "):\n"
        out += "            self." + fname + " = " + _default_expr(doc, names, prop.type_id) + "\n"
        out += "        else:\n"
        out += _decode_into(doc, names, "self." + fname, tid, slot, "            ", True)
    else:
        out += "        if " + slot + " < 0 or is_null(doc, " + slot + "):\n"
        out += "            raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
        out += _decode_into(doc, names, "self." + fname, tid, slot, "        ", False)
    return out


def _decode_into(
    doc: SchemaDoc,
    names: List[String],
    dest: String,
    tid: Int,
    slot: String,
    pad: String,
    opt: Bool,
) -> String:
    var tmp = "_g" + slot
    var t = doc.types[tid].copy()
    if t.kind == ST_REF:
        return _decode_into(doc, names, dest, t.inner, slot, pad, opt)
    if t.kind == ST_INT or (t.kind == ST_ENUM and _core_kind(doc, tid) == ST_INT):
        var out = pad + "var " + tmp + " = Int64(read_i64(doc, " + slot + "))\n"
        if t.kind == ST_ENUM:
            out += _enum_int_check(t, tmp, pad)
        if t.kind == ST_CONST:
            out += pad + "if " + tmp + " != Int64(" + String(t.const_int) + "):\n"
            out += pad + "    raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
        if opt:
            out += pad + dest + " = Optional[Int64](" + tmp + ")\n"
        else:
            out += pad + dest + " = " + tmp + "\n"
        return out
    if t.kind == ST_ENUM:
        var out = _decode_into(doc, names, dest, t.inner, slot, pad, opt)
        if _core_kind(doc, t.inner) == ST_STRING or doc.types[t.inner].kind == ST_STRING:
            out += _enum_str_check(t, dest, pad, opt)
        return out
    if t.kind == ST_CONST:
        var out = _decode_into(doc, names, dest, t.inner, slot, pad, opt)
        out += pad + _const_check(t, dest)
        return out
    if t.kind == ST_NUMBER:
        var out = pad + "var " + tmp + " = read_f64(doc, " + slot + ")\n"
        if opt:
            out += pad + dest + " = Optional[Float64](" + tmp + ")\n"
        else:
            out += pad + dest + " = " + tmp + "\n"
        return out
    if t.kind == ST_BOOL:
        var out = pad + "var " + tmp + " = read_bool(doc, " + slot + ")\n"
        if opt:
            out += pad + dest + " = Optional[Bool](" + tmp + ")\n"
        else:
            out += pad + dest + " = " + tmp + "\n"
        return out
    if t.kind == ST_STRING or t.kind == ST_BIGINT or t.kind == ST_DECIMAL:
        var call = "read_str"
        if t.kind == ST_BIGINT:
            call = "read_bigint"
        if t.kind == ST_DECIMAL:
            call = "read_decimal"
        var out = pad + "var " + tmp + " = " + call + "(doc, " + slot + ")\n"
        if opt:
            out += pad + dest + " = Optional[String](" + tmp + "^)\n"
        else:
            out += pad + dest + " = " + tmp + "^\n"
        return out
    if t.kind == ST_BINARY:
        var out = pad + "var " + tmp + " = read_bytes(doc, " + slot + ")\n"
        if opt:
            out += pad + dest + " = Optional[List[Byte]](" + tmp + "^)\n"
        else:
            out += pad + dest + " = " + tmp + "^\n"
        return out
    if t.kind == ST_OBJECT or t.kind == ST_UNION:
        var ty = names[tid]
        var child = "_c" + slot
        var out = pad + "var " + child + " = " + ty + "()\n"
        out += pad + child + ".read_value(doc, " + slot + ")\n"
        if opt:
            out += pad + dest + " = Optional[" + ty + "](" + child + "^)\n"
        else:
            out += pad + dest + " = " + child + "^\n"
        return out
    if t.kind == ST_ARRAY:
        return _array_decode(
            doc, names, dest, t.inner, slot, pad, opt, _type_expr(doc, names, t.inner)
        )
    return pad + dest + " = " + _default_expr(doc, names, tid) + "\n"


def _array_decode(
    doc: SchemaDoc,
    names: List[String],
    dest: String,
    elem_tid: Int,
    slot: String,
    pad: String,
    opt: Bool,
    elem: String,
) -> String:
    var out = pad + "if doc.nodes[" + slot + "].kind != K_ARRAY:\n"
    out += pad + "    raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
    out += pad + "var _items = List[" + elem + "]()\n"
    out += pad + "var _i = 0\n"
    out += pad + "while _i < array_len(doc, " + slot + "):\n"
    out += pad + "    var _el = array_at(doc, " + slot + ", _i)\n"
    var kind = _core_kind(doc, elem_tid)
    if kind == ST_INT:
        out += pad + "    _items.append(Int64(read_i64(doc, _el)))\n"
    elif kind == ST_NUMBER:
        out += pad + "    _items.append(read_f64(doc, _el))\n"
    elif kind == ST_BOOL:
        out += pad + "    _items.append(read_bool(doc, _el))\n"
    elif kind == ST_STRING:
        out += pad + "    var _s = read_str(doc, _el)\n"
        out += pad + "    _items.append(_s^)\n"
    elif kind == ST_OBJECT or kind == ST_UNION:
        var real = elem_tid
        var u = doc.types[elem_tid].copy()
        while u.kind == ST_REF or u.kind == ST_ENUM or u.kind == ST_CONST:
            real = u.inner
            u = doc.types[real].copy()
        out += pad + "    var _child = " + names[real] + "()\n"
        out += pad + "    _child.read_value(doc, _el)\n"
        out += pad + "    _items.append(_child^)\n"
    else:
        out += pad + "    var _s = read_str(doc, _el)\n"
        out += pad + "    _items.append(_s^)\n"
    out += pad + "    _i += 1\n"
    if opt:
        out += pad + dest + " = Optional[List[" + elem + "]](_items^)\n"
    else:
        out += pad + dest + " = _items^\n"
    return out


def _enum_str_check(t: SchemaType, dest: String, pad: String, opt: Bool) -> String:
    var src = dest
    if opt:
        src = dest + ".value()"
    var out = pad + "var _ok = False\n"
    var i = 0
    while i < len(t.enum_strings):
        out += pad + "if " + src + " == " + _lit(t.enum_strings[i]) + ":\n"
        out += pad + "    _ok = True\n"
        i += 1
    out += pad + "if not _ok:\n"
    out += pad + "    raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
    return out


def _enum_int_check(t: SchemaType, expr: String, pad: String) -> String:
    var out = pad + "var _ok = False\n"
    var i = 0
    while i < len(t.enum_ints):
        out += pad + "if " + expr + " == Int64(" + String(t.enum_ints[i]) + "):\n"
        out += pad + "    _ok = True\n"
        i += 1
    out += pad + "if not _ok:\n"
    out += pad + "    raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
    return out


def _const_check(t: SchemaType, expr: String) -> String:
    if t.const_kind == ST_STRING:
        return "if " + expr + " != " + _lit(t.const_str) + ":\n            raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
    if t.const_kind == ST_INT:
        return "if Int(" + expr + ") != " + String(t.const_int) + ":\n            raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
    if t.const_kind == ST_BOOL:
        var flag = "False"
        if t.const_bool:
            flag = "True"
        return "if " + expr + " != " + flag + ":\n            raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
    return ""


def _emit_union(doc: SchemaDoc, names: List[String], tid: Int, sname: String) -> String:
    var t = doc.types[tid].copy()
    var out = _header(_file_deps(doc, names, tid, sname))
    out += "struct " + sname + "(Copyable, Movable):\n"
    out += "    var tag: Int\n"
    var b = 0
    while b < len(t.branch_ids):
        var bid = t.branch_ids[b]
        out += "    var arm" + String(b) + ": " + _type_expr(doc, names, bid) + "\n"
        b += 1
    out += "\n    def __init__(out self):\n"
    out += "        self.tag = 0\n"
    b = 0
    while b < len(t.branch_ids):
        out += "        self.arm" + String(b) + " = " + _default_expr(doc, names, t.branch_ids[b]) + "\n"
        b += 1
    out += "\n    def encoded_len(self, options: EncodeOptions) raises DecodeError -> Int:\n"
    out += "        return len(self.to_bytes(options))\n"
    out += "\n    def encode_to(self, mut buf: List[Byte], options: EncodeOptions) raises DecodeError:\n"
    out += "        var raw = self.to_bytes(options)\n"
    out += "        var i = 0\n"
    out += "        while i < len(raw):\n"
    out += "            buf.append(raw[i])\n"
    out += "            i += 1\n"
    out += "\n    def to_bytes(self, options: EncodeOptions) raises DecodeError -> List[Byte]:\n"
    out += "        var doc = SmileDoc()\n"
    out += "        doc.add_top(self.to_node(doc))\n"
    out += "        return encode(doc, options)\n"
    out += "\n    def to_node(self, mut doc: SmileDoc) raises DecodeError -> Int:\n"
    b = 0
    while b < len(t.branch_ids):
        out += "        if self.tag == " + String(b) + ":\n"
        out += _union_encode_arm(doc, names, t.branch_ids[b], b)
        b += 1
    out += "        raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
    out += "\n    def decode_from[origin: ImmOrigin](mut self, raw: Span[Byte, origin]) raises DecodeError:\n"
    out += "        var doc = decode(raw, False)\n"
    out += "        if len(doc.top) != 1:\n"
    out += "            raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
    out += "        self.read_value(doc, doc.top[0])\n"
    out += "\n    def read_value(mut self, doc: SmileDoc, id: Int) raises DecodeError:\n"
    out += "        var kind = doc.nodes[id].kind\n"
    b = 0
    while b < len(t.branch_ids):
        out += _union_decode_arm(doc, names, t.branch_ids[b], b)
        b += 1
    out += "        raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
    return out


def _union_encode_arm(doc: SchemaDoc, names: List[String], tid: Int, index: Int) -> String:
    var kind = _core_kind(doc, tid)
    var expr = "self.arm" + String(index)
    if kind == ST_INT:
        return "            return doc.add_i64(Int(" + expr + "))\n"
    if kind == ST_NUMBER:
        return "            return doc.add_f64(Float64(" + expr + "))\n"
    if kind == ST_BOOL:
        return "            return doc.add_bool(" + expr + ")\n"
    if kind == ST_STRING:
        return "            return doc.add_string(" + expr + ")\n"
    if kind == ST_OBJECT or kind == ST_UNION:
        return "            return " + expr + ".to_node(doc)\n"
    return "            return doc.add_null()\n"


def _union_decode_arm(doc: SchemaDoc, names: List[String], tid: Int, index: Int) -> String:
    var kind = _core_kind(doc, tid)
    var expr = "self.arm" + String(index)
    var tag = "            self.tag = " + String(index) + "\n"
    if kind == ST_INT:
        var out = "        if kind == K_I32 or kind == K_I64 or kind == K_BIGINT:\n"
        out += tag
        out += "            " + expr + " = Int64(read_i64(doc, id))\n"
        out += "            return\n"
        return out
    if kind == ST_NUMBER:
        var out = "        if kind == K_F32 or kind == K_F64:\n"
        out += tag
        out += "            " + expr + " = read_f64(doc, id)\n"
        out += "            return\n"
        return out
    if kind == ST_BOOL:
        var out = "        if kind == K_BOOL:\n"
        out += tag
        out += "            " + expr + " = read_bool(doc, id)\n"
        out += "            return\n"
        return out
    if kind == ST_STRING:
        var out = "        if kind == K_STRING:\n"
        out += tag
        out += "            " + expr + " = read_str(doc, id)\n"
        out += "            return\n"
        return out
    if kind == ST_OBJECT:
        var hint = _first_field(doc, tid)
        var out = "        if kind == K_OBJECT"
        if hint.byte_length() > 0:
            out += " and find_field(doc, id, " + _lit(hint) + ") >= 0"
        out += ":\n"
        out += tag
        out += "            " + expr + ".read_value(doc, id)\n"
        out += "            return\n"
        return out
    return ""


def _first_field(doc: SchemaDoc, tid: Int) -> String:
    var t = doc.types[tid].copy()
    var guard = 0
    while guard < 16 and (t.kind == ST_REF or t.kind == ST_OPTIONAL):
        t = doc.types[t.inner].copy()
        guard += 1
    if t.kind == ST_OBJECT and len(t.props) > 0:
        return t.props[0].name
    return String()
