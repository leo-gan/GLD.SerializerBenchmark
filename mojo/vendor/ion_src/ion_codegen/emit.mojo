from std.collections import List

from ion_codegen.names import sanitize
from ion_runtime.error import DecodeError
from ion_schema.parse import (
    TY_BOOL,
    TY_BYTES,
    TY_FLOAT,
    TY_INT,
    TY_ION,
    TY_LIST,
    TY_STRING,
    TY_STRUCT,
    Schema,
)


def emit_all(schema: Schema) raises DecodeError -> List[String]:
    var out = List[String]()
    var i = 0
    while i < len(schema.type_name):
        if schema.type_kind[i] == TY_STRUCT and schema.type_name[i].byte_length() != 0:
            var name = sanitize(schema.type_name[i])
            out.append(name)
            out.append(_emit_struct(schema, i, name))
        i += 1
    if len(out) == 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    return out^


def _emit_struct(schema: Schema, idx: Int, name: String) raises DecodeError -> String:
    var src = String()
    src = src + "from std.collections import List\n\n"
    src = src + "from ion_runtime.doc import IonDoc, K_BLOB, K_CLOB, K_LIST, K_STRUCT\n"
    src = src + "from ion_runtime.error import DecodeError\n"
    src = src + "from ion_runtime.options import EncodeOptions\n"
    src = src + "from ion_runtime.symtab import Catalog\n"
    src = src + "from ion_wire.bind import (\n"
    src = src + "    as_bool,\n    as_bytes,\n    as_f64,\n    as_i64,\n    as_string,\n"
    src = src + "    decode_any,\n    field_name,\n    ion_text,\n    parse_ion,\n)\n"
    src = src + "from ion_wire.writer import encode_binary, encode_text\n"
    var seen = List[String]()
    var f = 0
    while f < schema.field_n[idx]:
        var tid = schema.field_type[schema.field_at[idx] + f]
        _note_import(schema, tid, name, seen)
        f += 1
    var s = 0
    while s < len(seen):
        src = src + "from " + seen[s] + " import " + seen[s] + "\n"
        s += 1
    src = src + "\n\nstruct " + name + "(Movable):\n"
    f = 0
    while f < schema.field_n[idx]:
        var at = schema.field_at[idx] + f
        var ident = sanitize(schema.field_name[at])
        var tid = schema.field_type[at]
        if not schema.field_req[at]:
            src = src + "    var has_" + ident + ": Bool\n"
        src = src + "    var " + ident + ": " + _mtype(schema, tid) + "\n"
        f += 1
    src = src + "\n    def __init__(out self):\n"
    f = 0
    var any_field = False
    while f < schema.field_n[idx]:
        any_field = True
        var at = schema.field_at[idx] + f
        var ident = sanitize(schema.field_name[at])
        var tid = schema.field_type[at]
        if not schema.field_req[at]:
            src = src + "        self.has_" + ident + " = False\n"
        src = src + "        self." + ident + " = " + _default(schema, tid) + "\n"
        f += 1
    if not any_field:
        src = src + "        var _keep = 0\n"
    src = src + "\n    def encoded_len(self, options: EncodeOptions) raises -> Int:\n"
    src = src + "        var buf = List[Byte]()\n"
    src = src + "        self.encode_to(buf, options)\n"
    src = src + "        return len(buf)\n"
    src = src + "\n    def encode_to(self, mut buf: List[Byte], options: EncodeOptions) raises:\n"
    src = src + "        var doc = self.to_doc()\n"
    src = src + "        var cat = Catalog()\n"
    src = src + "        if options.binary:\n"
    src = src + "            var raw = encode_binary(doc, options, cat)\n"
    src = src + "            var i = 0\n"
    src = src + "            while i < len(raw):\n"
    src = src + "                buf.append(raw[i])\n"
    src = src + "                i += 1\n"
    src = src + "            return\n"
    src = src + "        var text = encode_text(doc, options)\n"
    src = src + "        var b = text.as_bytes()\n"
    src = src + "        var k = 0\n"
    src = src + "        while k < len(b):\n"
    src = src + "            buf.append(b[k])\n"
    src = src + "            k += 1\n"
    src = src + "\n    def to_doc(self) raises -> IonDoc:\n"
    src = src + "        var doc = IonDoc()\n"
    src = src + "        var st = self.write_into(doc)\n"
    src = src + "        doc.add_top(st)\n"
    src = src + "        return doc^\n"
    src = src + "\n    def write_into(self, mut doc: IonDoc) raises -> Int:\n"
    src = src + "        var st = doc.start_container(K_STRUCT)\n"
    f = 0
    while f < schema.field_n[idx]:
        var at = schema.field_at[idx] + f
        src = src + _write_field(schema, schema.field_name[at], schema.field_type[at], schema.field_req[at])
        f += 1
    src = src + "        return st\n"
    src = src + "\n    @staticmethod\n    def decode_from(raw: List[Byte]) raises -> " + name + ":\n"
    src = src + "        var doc = decode_any(Span(raw))\n"
    src = src + "        if len(doc.top) != 1:\n"
    src = src + "            raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
    src = src + "        return " + name + ".from_doc(doc, doc.top[0])\n"
    src = src + "\n    @staticmethod\n    def from_doc(doc: IonDoc, id: Int) raises -> " + name + ":\n"
    src = src + "        if doc.nodes[id].kind != K_STRUCT:\n"
    src = src + "            raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
    src = src + "        var out = " + name + "()\n"
    f = 0
    while f < schema.field_n[idx]:
        var at = schema.field_at[idx] + f
        if schema.field_req[at]:
            var ident = sanitize(schema.field_name[at])
            src = src + "        var got_" + ident + " = False\n"
        f += 1
    src = src + "        var i = 0\n"
    src = src + "        while i < doc.nodes[id].nchild:\n"
    src = src + "            var fname = field_name(doc, id, i)\n"
    src = src + "            var child = doc.child_at(id, i)\n"
    f = 0
    while f < schema.field_n[idx]:
        var at = schema.field_at[idx] + f
        var ion_name = schema.field_name[at]
        var ident = sanitize(schema.field_name[at])
        var kw = "if"
        if f > 0:
            kw = "elif"
        src = src + "            " + kw + " fname == \"" + ion_name + "\":\n"
        src = src + _read_field(schema, ident, schema.field_type[at], schema.field_req[at])
        f += 1
    if schema.field_n[idx] == 0:
        src = src + "            _ = fname\n            _ = child\n"
    else:
        src = src + "            else:\n"
        if schema.type_closed[idx] != 0:
            src = src + "                raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
        else:
            src = src + "                _ = child\n"
    src = src + "            i += 1\n"
    f = 0
    while f < schema.field_n[idx]:
        var at = schema.field_at[idx] + f
        if schema.field_req[at]:
            var ident = sanitize(schema.field_name[at])
            src = src + "        if not got_" + ident + ":\n"
            src = src + "            raise DecodeError(DecodeError.KIND_SCHEMA, 0)\n"
        f += 1
    src = src + "        return out^\n"
    return src


def _note_import(schema: Schema, tid: Int, self_name: String, mut seen: List[String]):
    var kind = schema.type_kind[tid]
    if kind == TY_STRUCT:
        var nm = sanitize(schema.type_name[tid])
        if nm != self_name and not _has(seen, nm):
            seen.append(nm)
        return
    if kind == TY_LIST:
        _note_import(schema, schema.type_inner[tid], self_name, seen)


def _slug(text: String) -> String:
    var raw = text.as_bytes()
    var out = String()
    var i = 0
    while i < len(raw):
        var c = Int(raw[i])
        if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57):
            out = out + chr(c)
        else:
            out = out + "_"
        i += 1
    return out


def _has(seen: List[String], name: String) -> Bool:
    var i = 0
    while i < len(seen):
        if seen[i] == name:
            return True
        i += 1
    return False


def _mtype(schema: Schema, tid: Int) raises DecodeError -> String:
    var kind = schema.type_kind[tid]
    if kind == TY_INT:
        return String("Int64")
    if kind == TY_BOOL:
        return String("Bool")
    if kind == TY_STRING or kind == TY_ION:
        return String("String")
    if kind == TY_FLOAT:
        return String("Float64")
    if kind == TY_BYTES:
        return String("List[Byte]")
    if kind == TY_STRUCT:
        return sanitize(schema.type_name[tid])
    if kind == TY_LIST:
        return "List[" + _mtype(schema, schema.type_inner[tid]) + "]"
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


def _default(schema: Schema, tid: Int) raises DecodeError -> String:
    var kind = schema.type_kind[tid]
    if kind == TY_INT:
        return String("Int64(0)")
    if kind == TY_BOOL:
        return String("False")
    if kind == TY_STRING or kind == TY_ION:
        return String("String()")
    if kind == TY_FLOAT:
        return String("Float64(0)")
    if kind == TY_BYTES or kind == TY_LIST:
        return _mtype(schema, tid) + "()"
    if kind == TY_STRUCT:
        return sanitize(schema.type_name[tid]) + "()"
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


def _write_field(schema: Schema, ion_name: String, tid: Int, required: Bool) raises DecodeError -> String:
    var ident = sanitize(ion_name)
    var body = String()
    var pad = "        "
    if not required:
        body = body + pad + "if self.has_" + ident + ":\n"
        pad = "            "
    body = body + pad + "var sym_" + ident + " = doc.add_symbol_text(\"" + ion_name + "\")\n"
    body = body + pad + "var slot_" + ident + " = doc.nodes[sym_" + ident + "].a\n"
    body = body + _write_value(schema, tid, "self." + ident, "val_" + ident, pad)
    body = body + pad + "doc.add_child(st, val_" + ident + ", slot_" + ident + ")\n"
    return body


def _write_value(schema: Schema, tid: Int, expr: String, dest: String, pad: String) raises DecodeError -> String:
    var kind = schema.type_kind[tid]
    if kind == TY_INT:
        return pad + "var " + dest + " = doc.add_i64(" + expr + ")\n"
    if kind == TY_BOOL:
        return pad + "var " + dest + " = doc.add_bool(" + expr + ")\n"
    if kind == TY_STRING:
        return pad + "var " + dest + " = doc.add_string(" + expr + ")\n"
    if kind == TY_FLOAT:
        var line = pad + "var bits_" + dest + " = " + expr + ".to_bits()\n"
        line = line + pad + "var " + dest + " = doc.add_float(8, UInt64(bits_" + dest + "))\n"
        return line
    if kind == TY_ION:
        return pad + "var " + dest + " = parse_ion(doc, " + expr + ", " + String(schema.type_expect[tid]) + ")\n"
    if kind == TY_BYTES:
        var line = pad + "var raw_" + dest + " = List[Byte]()\n"
        line = line + pad + "var j_" + dest + " = 0\n"
        line = line + pad + "while j_" + dest + " < len(" + expr + "):\n"
        line = line + pad + "    raw_" + dest + ".append(" + expr + "[j_" + dest + "])\n"
        line = line + pad + "    j_" + dest + " += 1\n"
        line = line + pad + "var " + dest + " = doc.add_bytes(" + String(schema.type_expect[tid]) + ", raw_" + dest + "^)\n"
        return line
    if kind == TY_STRUCT:
        return pad + "var " + dest + " = " + expr + ".write_into(doc)\n"
    if kind == TY_LIST:
        var inner = schema.type_inner[tid]
        var line = pad + "var " + dest + " = doc.start_container(K_LIST)\n"
        line = line + pad + "var j_" + dest + " = 0\n"
        line = line + pad + "while j_" + dest + " < len(" + expr + "):\n"
        line = line + _write_value(schema, inner, expr + "[j_" + dest + "]", "item_" + dest, pad + "    ")
        line = line + pad + "    doc.add_child(" + dest + ", item_" + dest + ", -1)\n"
        line = line + pad + "    j_" + dest + " += 1\n"
        return line
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


def _read_field(schema: Schema, ident: String, tid: Int, required: Bool) raises DecodeError -> String:
    var body = _read_value(schema, tid, "child", "out." + ident, "                ")
    if not required:
        body = body + "                out.has_" + ident + " = True\n"
    else:
        body = body + "                got_" + ident + " = True\n"
    return body


def _read_value(schema: Schema, tid: Int, expr: String, dest: String, pad: String) raises DecodeError -> String:
    var kind = schema.type_kind[tid]
    if kind == TY_INT:
        return pad + dest + " = as_i64(doc, " + expr + ")\n"
    if kind == TY_BOOL:
        return pad + dest + " = as_bool(doc, " + expr + ")\n"
    if kind == TY_STRING:
        return pad + dest + " = as_string(doc, " + expr + ")\n"
    if kind == TY_FLOAT:
        return pad + dest + " = as_f64(doc, " + expr + ")\n"
    if kind == TY_ION:
        return pad + dest + " = ion_text(doc, " + expr + ", " + String(schema.type_expect[tid]) + ")\n"
    if kind == TY_BYTES:
        return pad + dest + " = as_bytes(doc, " + expr + ", " + String(schema.type_expect[tid]) + ")\n"
    if kind == TY_STRUCT:
        var nm = sanitize(schema.type_name[tid])
        return pad + dest + " = " + nm + ".from_doc(doc, " + expr + ")\n"
    if kind == TY_LIST:
        var inner = schema.type_inner[tid]
        var item = "item_" + _slug(dest)
        var line = pad + "if doc.nodes[" + expr + "].kind != K_LIST:\n"
        line = line + pad + "    raise DecodeError(DecodeError.KIND_TYPE, 0)\n"
        line = line + pad + "var " + item + " = " + _default(schema, inner) + "\n"
        line = line + pad + "var j_" + item + " = 0\n"
        line = line + pad + "while j_" + item + " < doc.nodes[" + expr + "].nchild:\n"
        line = line + _read_value(schema, inner, "doc.child_at(" + expr + ", j_" + item + ")", item, pad + "    ")
        line = line + pad + "    " + dest + ".append(" + item + ")\n"
        line = line + pad + "    j_" + item + " += 1\n"
        return line
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)
