from std.collections import List

from bson_schema.model import SK_ARRAY, SK_BOOL, SK_F64, SK_I32, SK_I64, SK_REF, SK_STRING, Field, SchemaDoc, TypeDef


def _ty(kind: Int) -> String:
    if kind == SK_BOOL:
        return "Bool"
    if kind == SK_I32:
        return "Int32"
    if kind == SK_I64:
        return "Int64"
    if kind == SK_F64:
        return "Float64"
    if kind == SK_STRING:
        return "String"
    return "Int"


def _zero(kind: Int) -> String:
    if kind == SK_BOOL:
        return "False"
    if kind == SK_STRING:
        return "\"\""
    if kind == SK_F64:
        return "0.0"
    return "0"


def _wire(kind: Int) -> String:
    if kind == SK_BOOL:
        return "TY_BOOL"
    if kind == SK_I32:
        return "TY_INT32"
    if kind == SK_I64:
        return "TY_INT64"
    if kind == SK_F64:
        return "TY_DOUBLE"
    if kind == SK_STRING:
        return "TY_STRING"
    return "TY_DOCUMENT"


def _emit_type(td: TypeDef) -> String:
    var s = String()
    s += "from std.collections import List\n"
    var seen = List[String]()
    var r = 0
    while r < len(td.fields):
        var fr = td.fields[r].copy()
        var dep = String()
        if fr.kind == SK_REF:
            dep = fr.ref_name
        elif fr.kind == SK_ARRAY and fr.elem_kind == SK_REF:
            dep = fr.elem_ref
        if dep.byte_length() > 0:
            var known = False
            var sidx = 0
            while sidx < len(seen):
                if seen[sidx] == dep:
                    known = True
                sidx += 1
            if not known:
                seen.append(dep)
                s += "from " + dep + " import " + dep + "\n"
        r += 1
    s += "\n"
    s += "from bson_runtime.datum import BsonDatum\n"
    s += "from bson_runtime.error import DecodeError\n"
    s += "from bson_wire.reader import WireReader\n"
    s += "from bson_wire.types import TY_BOOL, TY_DOCUMENT, TY_DOUBLE, TY_INT32, TY_INT64, TY_STRING\n"
    s += "from bson_wire.writer import WireWriter, digit_count\n\n"
    s += "struct " + td.name + "(Copyable, Movable, Defaultable, BsonDatum):\n"
    var i = 0
    while i < len(td.fields):
        var f = td.fields[i].copy()
        if f.kind == SK_ARRAY:
            var et = _ty(f.elem_kind)
            if f.elem_kind == SK_REF:
                et = f.elem_ref
            s += "    var " + f.name + ": List[" + et + "]\n"
        elif f.kind == SK_REF:
            s += "    var " + f.name + ": " + f.ref_name + "\n"
        else:
            s += "    var " + f.name + ": " + _ty(f.kind) + "\n"
        i += 1
    s += "\n    def __init__(out self):\n"
    i = 0
    while i < len(td.fields):
        var f = td.fields[i].copy()
        if f.kind == SK_ARRAY:
            var et = _ty(f.elem_kind)
            if f.elem_kind == SK_REF:
                et = f.elem_ref
            s += "        self." + f.name + " = List[" + et + "]()\n"
        elif f.kind == SK_REF:
            s += "        self." + f.name + " = " + f.ref_name + "()\n"
        else:
            s += "        self." + f.name + " = " + _zero(f.kind) + "\n"
        i += 1
    s += "\n    def encoded_len(self) -> Int:\n        var n = 5\n"
    i = 0
    while i < len(td.fields):
        var f = td.fields[i].copy()
        s += "        n += " + String(1 + f.name.byte_length() + 1) + "\n"
        if f.kind == SK_BOOL:
            s += "        n += 1\n"
        elif f.kind == SK_I32:
            s += "        n += 4\n"
        elif f.kind == SK_I64 or f.kind == SK_F64:
            s += "        n += 8\n"
        elif f.kind == SK_STRING:
            s += "        n += 5 + self." + f.name + ".byte_length()\n"
        elif f.kind == SK_REF:
            s += "        n += self." + f.name + ".encoded_len()\n"
        elif f.kind == SK_ARRAY:
            s += "        var a_" + f.name + " = 5\n"
            s += "        var i_" + f.name + " = 0\n"
            s += "        while i_" + f.name + " < len(self." + f.name + "):\n"
            s += "            a_" + f.name + " += 2 + digit_count(i_" + f.name + ")\n"
            if f.elem_kind == SK_STRING:
                s += "            a_" + f.name + " += 5 + self." + f.name + "[i_" + f.name + "].byte_length()\n"
            elif f.elem_kind == SK_F64 or f.elem_kind == SK_I64:
                s += "            a_" + f.name + " += 8\n"
            elif f.elem_kind == SK_I32:
                s += "            a_" + f.name + " += 4\n"
            elif f.elem_kind == SK_BOOL:
                s += "            a_" + f.name + " += 1\n"
            elif f.elem_kind == SK_REF:
                s += "            a_" + f.name + " += self." + f.name + "[i_" + f.name + "].encoded_len()\n"
            s += "            i_" + f.name + " += 1\n"
            s += "        n += a_" + f.name + "\n"
        i += 1
    s += "        return n\n\n"
    s += "    def encode_to(self, mut w: WireWriter):\n"
    s += "        var at = w.begin_document()\n"
    i = 0
    while i < len(td.fields):
        var f = td.fields[i].copy()
        if f.kind == SK_BOOL:
            s += "        w.write_bool_field(\"" + f.name + "\", self." + f.name + ")\n"
        elif f.kind == SK_I32:
            s += "        w.write_i32_field(\"" + f.name + "\", self." + f.name + ")\n"
        elif f.kind == SK_I64:
            s += "        w.write_i64_field(\"" + f.name + "\", self." + f.name + ")\n"
        elif f.kind == SK_F64:
            s += "        w.write_f64_field(\"" + f.name + "\", self." + f.name + ")\n"
        elif f.kind == SK_STRING:
            s += "        w.write_string_field(\"" + f.name + "\", self." + f.name + ")\n"
        elif f.kind == SK_REF:
            s += "        w.write_type_key(TY_DOCUMENT, \"" + f.name + "\")\n"
            s += "        self." + f.name + ".encode_to(w)\n"
        elif f.kind == SK_ARRAY:
            s += "        var " + f.name + "_at = w.begin_array_field(\"" + f.name + "\")\n"
            s += "        var " + f.name + "_i = 0\n"
            s += "        while " + f.name + "_i < len(self." + f.name + "):\n"
            if f.elem_kind == SK_REF:
                s += "            w.write_type_index(TY_DOCUMENT, " + f.name + "_i)\n"
                s += "            self." + f.name + "[" + f.name + "_i].encode_to(w)\n"
            elif f.elem_kind == SK_STRING:
                s += "            w.write_string_index(" + f.name + "_i, self." + f.name + "[" + f.name + "_i])\n"
            elif f.elem_kind == SK_F64:
                s += "            w.write_f64_index(" + f.name + "_i, self." + f.name + "[" + f.name + "_i])\n"
            elif f.elem_kind == SK_I64:
                s += "            w.write_i64_index(" + f.name + "_i, self." + f.name + "[" + f.name + "_i])\n"
            elif f.elem_kind == SK_I32:
                s += "            w.write_i32_index(" + f.name + "_i, self." + f.name + "[" + f.name + "_i])\n"
            elif f.elem_kind == SK_BOOL:
                s += "            w.write_bool_index(" + f.name + "_i, self." + f.name + "[" + f.name + "_i])\n"
            s += "            " + f.name + "_i += 1\n"
            s += "        w.end_document(" + f.name + "_at)\n"
        i += 1
    s += "        w.end_document(at)\n\n"
    s += "    def decode_from[origin: ImmOrigin](mut self, mut r: WireReader[origin]) raises DecodeError:\n"
    s += "        var end = r.enter_document()\n"
    s += "        while r.pos < end - 1:\n"
    s += "            var typ = r.read_u8()\n"
    s += "            var key = r.read_cstring()\n"
    i = 0
    while i < len(td.fields):
        var f = td.fields[i].copy()
        if i == 0:
            s += "            if key == \"" + f.name + "\":\n"
        else:
            s += "            elif key == \"" + f.name + "\":\n"
        s += _decode_field(f)
        i += 1
    if len(td.fields) == 0:
        s += "            r.skip_value(typ)\n"
    else:
        s += "            else:\n                r.skip_value(typ)\n"
    s += "        r.finish_document(end)\n"
    return s


def _decode_field(f: Field) -> String:
    var s = String()
    if f.kind == SK_BOOL:
        s += "                _ = typ\n"
        s += "                self." + f.name + " = r.read_u8() != 0\n"
    elif f.kind == SK_I32:
        s += "                _ = typ\n"
        s += "                self." + f.name + " = r.read_i32()\n"
    elif f.kind == SK_I64:
        s += "                _ = typ\n"
        s += "                self." + f.name + " = r.read_i64()\n"
    elif f.kind == SK_F64:
        s += "                _ = typ\n"
        s += "                self." + f.name + " = r.read_f64()\n"
    elif f.kind == SK_STRING:
        s += "                _ = typ\n"
        s += "                self." + f.name + " = r.read_bson_string()\n"
    elif f.kind == SK_REF:
        s += "                _ = typ\n"
        s += "                self." + f.name + ".decode_from(r)\n"
    elif f.kind == SK_ARRAY:
        var et = _ty(f.elem_kind)
        if f.elem_kind == SK_REF:
            et = f.elem_ref
        s += "                var aend = r.enter_document()\n"
        s += "                self." + f.name + " = List[" + et + "]()\n"
        s += "                while r.pos < aend - 1:\n"
        s += "                    var atyp = r.read_u8()\n"
        s += "                    _ = r.read_cstring()\n"
        if f.elem_kind == SK_REF:
            s += "                    var item = " + et + "()\n"
            s += "                    item.decode_from(r)\n"
            s += "                    self." + f.name + ".append(item^)\n"
        elif f.elem_kind == SK_STRING:
            s += "                    self." + f.name + ".append(r.read_bson_string())\n"
        elif f.elem_kind == SK_F64:
            s += "                    self." + f.name + ".append(r.read_f64())\n"
        elif f.elem_kind == SK_I64:
            s += "                    self." + f.name + ".append(r.read_i64())\n"
        elif f.elem_kind == SK_I32:
            s += "                    self." + f.name + ".append(r.read_i32())\n"
        elif f.elem_kind == SK_BOOL:
            s += "                    self." + f.name + ".append(r.read_u8() != 0)\n"
        else:
            s += "                    r.skip_value(atyp)\n"
        s += "                r.finish_document(aend)\n"
        _ = _wire(0)
    return s


def emit_all(doc: SchemaDoc) -> List[String]:
    var out = List[String]()
    var i = 0
    while i < len(doc.types):
        out.append(doc.types[i].name)
        out.append(_emit_type(doc.types[i]))
        i += 1
    return out^
