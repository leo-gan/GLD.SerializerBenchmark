from std.collections import List

from cbor_cddl.model import (
    CK_INT_KEY,
    CK_POS_KEY,
    CK_TEXT_KEY,
    CT_ANY,
    CT_ARRAY,
    CT_BOOL,
    CT_BSTR,
    CT_CHOICE,
    CT_FLOAT,
    CT_INT,
    CT_NAMED,
    CT_NULL,
    CT_STRUCT,
    CT_TAG,
    CT_TSTR,
    CT_UINT,
    CT_UNWRAP,
    CddlDoc,
)
from cbor_runtime.error import DecodeError


def _starts(s: String, prefix: String) -> Bool:
    if s.byte_length() < prefix.byte_length():
        return False
    var a = s.as_bytes()
    var b = prefix.as_bytes()
    for i in range(len(b)):
        if Int(a[i]) != Int(b[i]):
            return False
    return True


def _cut(s: String, start: Int, end: Int) -> String:
    var b = s.as_bytes()
    try:
        return String(from_utf8=b[start:end])
    except _:
        return String()


def _hex2(n: Int) -> String:
    var digits = String("0123456789abcdef")
    var db = digits.as_bytes()
    var out = List[Byte]()
    out.append(db[(n >> 4) & 15])
    out.append(db[n & 15])
    try:
        return String(from_utf8=out)
    except _:
        return String("00")


def _int_encoded_bytes(n: Int64) -> List[Byte]:
    var out = List[Byte]()
    if n >= Int64(0):
        var u = UInt64(n)
        if u < UInt64(24):
            out.append(Byte(Int(u)))
            return out^
        if u < UInt64(256):
            out.append(Byte(0x18))
            out.append(Byte(Int(u)))
            return out^
        if u < UInt64(65536):
            out.append(Byte(0x19))
            out.append(Byte(Int((u >> UInt64(8)) & UInt64(255))))
            out.append(Byte(Int(u & UInt64(255))))
            return out^
        out.append(Byte(0x1A))
        var i = 4
        while i > 0:
            i -= 1
            var shift = UInt64(i) * UInt64(8)
            out.append(Byte(Int((u >> shift) & UInt64(255))))
        return out^
    var mag = UInt64(-(n + Int64(1)))
    if mag < UInt64(24):
        out.append(Byte(0x20 + Int(mag)))
        return out^
    if mag < UInt64(256):
        out.append(Byte(0x38))
        out.append(Byte(Int(mag)))
        return out^
    out.append(Byte(0x39))
    out.append(Byte(Int((mag >> UInt64(8)) & UInt64(255))))
    out.append(Byte(Int(mag & UInt64(255))))
    return out^


def _tstr_encoded_bytes(name: String) -> List[Byte]:
    var payload = name.as_bytes()
    var n = len(payload)
    var out = List[Byte]()
    if n < 24:
        out.append(Byte(0x60 + n))
    elif n < 256:
        out.append(Byte(0x78))
        out.append(Byte(n))
    elif n < 65536:
        out.append(Byte(0x79))
        out.append(Byte((n >> 8) & 255))
        out.append(Byte(n & 255))
    else:
        out.append(Byte(0x7A))
        out.append(Byte((n >> 24) & 255))
        out.append(Byte((n >> 16) & 255))
        out.append(Byte((n >> 8) & 255))
        out.append(Byte(n & 255))
    for i in range(n):
        out.append(payload[i])
    return out^


def _encoded_bytes_lt(a: List[Byte], b: List[Byte]) -> Bool:
    var n = len(a)
    if len(b) < n:
        n = len(b)
    for i in range(n):
        if Int(a[i]) < Int(b[i]):
            return True
        if Int(a[i]) > Int(b[i]):
            return False
    return len(a) < len(b)


def _cde_order_enc(enc: List[List[Byte]]) -> List[Int]:
    var order = List[Int]()
    for i in range(len(enc)):
        order.append(i)
    for i in range(len(enc)):
        var j = i
        while j > 0:
            if _encoded_bytes_lt(enc[order[j]], enc[order[j - 1]]):
                var tmp = order[j]
                order[j] = order[j - 1]
                order[j - 1] = tmp
                j -= 1
            else:
                break
    return order^


def _cde_key_order(keys: List[String]) -> List[Int]:
    var enc = List[List[Byte]]()
    for i in range(len(keys)):
        enc.append(_tstr_encoded_bytes(keys[i]))
    return _cde_order_enc(enc)


def _same_order(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def _xbytes_lit(data: List[Byte]) -> String:
    var s = String("String(\"")
    for i in range(len(data)):
        s += "\\x" + _hex2(Int(data[i]))
    s += "\").as_bytes()"
    return s


def _mojo_ident(name: String) -> String:
    if (
        name == "struct"
        or name == "fn"
        or name == "var"
        or name == "def"
        or name == "trait"
    ):
        return name + "_"
    return name


def _lookup_named(doc: CddlDoc, name: String) -> Int:
    for i in range(len(doc.def_names)):
        if doc.def_names[i] == name:
            return doc.def_types[i]
    return -1


def _def_index(doc: CddlDoc, name: String) -> Int:
    for i in range(len(doc.def_names)):
        if doc.def_names[i] == name:
            return i
    return -1


def _resolve(doc: CddlDoc, idx: Int) -> Int:
    var t = doc.types[idx]
    if t.kind == CT_NAMED:
        var found = _lookup_named(doc, t.name)
        if found >= 0:
            return found
    if t.kind == CT_UNWRAP and t.inner >= 0:
        return _resolve(doc, t.inner)
    return idx


def _flatten_choice(doc: CddlDoc, idx: Int, mut out: List[Int]):
    var r = _resolve(doc, idx)
    var t = doc.types[r]
    if t.kind == CT_CHOICE:
        _flatten_choice(doc, t.inner, out)
        _flatten_choice(doc, t.inner2, out)
    else:
        out.append(r)


def _is_null_choice(doc: CddlDoc, idx: Int) -> Bool:
    var br = List[Int]()
    _flatten_choice(doc, idx, br)
    var nulls = 0
    var others = 0
    for i in range(len(br)):
        if doc.types[br[i]].kind == CT_NULL:
            nulls += 1
        else:
            others += 1
    return nulls == 1 and others == 1


def _nonnull_branch(doc: CddlDoc, idx: Int) -> Int:
    var br = List[Int]()
    _flatten_choice(doc, idx, br)
    for i in range(len(br)):
        if doc.types[br[i]].kind != CT_NULL:
            return br[i]
    return _resolve(doc, idx)


def _is_multi_choice(doc: CddlDoc, idx: Int) -> Bool:
    var r = _resolve(doc, idx)
    if doc.types[r].kind != CT_CHOICE:
        return False
    return not _is_null_choice(doc, idx)


def _unwrap_optional(doc: CddlDoc, type_idx: Int) -> Int:
    if _is_null_choice(doc, type_idx):
        return _nonnull_branch(doc, type_idx)
    return type_idx


def _is_optional_member(doc: CddlDoc, member_optional: Bool, type_idx: Int) -> Bool:
    if member_optional:
        return True
    return _is_null_choice(doc, type_idx)


def _collect_named_defs(doc: CddlDoc, type_idx: Int, mut out: List[Int]):
    var t0 = doc.types[type_idx]
    if t0.kind == CT_NAMED:
        var d = _def_index(doc, t0.name)
        if d >= 0:
            out.append(d)
        return
    var r = _resolve(doc, type_idx)
    var t = doc.types[r]
    if t.kind == CT_STRUCT:
        for m in range(t.members_count):
            _collect_named_defs(doc, doc.members[t.members_start + m].type_idx, out)
    elif t.kind == CT_ARRAY or t.kind == CT_UNWRAP or t.kind == CT_TAG:
        if t.inner >= 0:
            _collect_named_defs(doc, t.inner, out)
    elif t.kind == CT_CHOICE:
        _collect_named_defs(doc, t.inner, out)
        _collect_named_defs(doc, t.inner2, out)


def _def_reaches(doc: CddlDoc, src: Int, dst: Int, mut seen: List[Int]) -> Bool:
    if src == dst:
        return True
    for i in range(len(seen)):
        if seen[i] == src:
            return False
    seen.append(src)
    var refs = List[Int]()
    _collect_named_defs(doc, doc.def_types[src], refs)
    for i in range(len(refs)):
        if _def_reaches(doc, refs[i], dst, seen):
            return True
    return False


def _same_scc(doc: CddlDoc, a: Int, b: Int) -> Bool:
    var s1 = List[Int]()
    var s2 = List[Int]()
    return _def_reaches(doc, a, b, s1) and _def_reaches(doc, b, a, s2)


def _named_def_of(doc: CddlDoc, type_idx: Int) -> Int:
    var t = doc.types[type_idx]
    if t.kind == CT_NAMED:
        return _def_index(doc, t.name)
    var r = _resolve(doc, type_idx)
    var tr = doc.types[r]
    if tr.kind == CT_NAMED:
        return _def_index(doc, tr.name)
    return -1


def _needs_box(doc: CddlDoc, owner_def: Int, type_idx: Int) -> Bool:
    if owner_def < 0:
        return False
    var d = _named_def_of(doc, type_idx)
    if d < 0:
        return False
    var rt = doc.types[_resolve(doc, doc.def_types[d])]
    if rt.kind != CT_STRUCT and rt.kind != CT_CHOICE:
        return False
    return _same_scc(doc, owner_def, d)


def _prelude_name(doc: CddlDoc, idx: Int) raises DecodeError -> String:
    var r = _resolve(doc, idx)
    var t = doc.types[r]
    if t.kind == CT_BOOL:
        return String("Bool")
    if t.kind == CT_INT:
        return String("Int64")
    if t.kind == CT_UINT:
        return String("UInt64")
    if t.kind == CT_TSTR:
        return String("String")
    if t.kind == CT_BSTR:
        return String("List[Byte]")
    if t.kind == CT_FLOAT:
        return String("Float64")
    if t.kind == CT_ANY:
        return String("CborValue")
    if t.kind == CT_TAG:
        if t.tag == UInt64(0):
            return String("String")
        if t.tag == UInt64(1):
            return String("EpochTime")
        if t.tag == UInt64(2):
            return String("BigUint")
        if t.tag == UInt64(3):
            return String("BigNint")
        if t.tag == UInt64(4):
            return String("DecimalFraction")
        if t.tag == UInt64(5):
            return String("BigFloat")
        if t.tag == UInt64(32):
            return String("Uri")
        return String("CborValue")
    if t.kind == CT_NAMED:
        return _mojo_ident(t.name)
    if t.kind == CT_ARRAY:
        return String("List[") + _prelude_name(doc, t.inner) + "]"
    raise DecodeError(DecodeError.KIND_CDDL, 0)


def _elem_type_name(
    doc: CddlDoc, owner_def: Int, elem_idx: Int
) raises DecodeError -> String:
    var inner = _unwrap_optional(doc, elem_idx)
    var n: String
    if doc.types[inner].kind == CT_NAMED:
        n = _mojo_ident(doc.types[inner].name)
    else:
        n = _prelude_name(doc, inner)
    if _needs_box(doc, owner_def, inner):
        return String("Box[") + n + "]"
    return n


def _field_type_name(
    doc: CddlDoc,
    owner_def: Int,
    type_idx: Int,
    optional: Bool,
    owner_name: String,
    field_name: String,
) raises DecodeError -> String:
    var inner = _unwrap_optional(doc, type_idx)
    var t = doc.types[inner]
    var base: String
    if t.kind == CT_NAMED:
        base = _mojo_ident(t.name)
    elif _is_multi_choice(doc, inner):
        base = _mojo_ident(owner_name) + "_" + _mojo_ident(field_name)
    else:
        var r = _resolve(doc, inner)
        var tr = doc.types[r]
        if tr.kind == CT_ARRAY:
            base = String("List[") + _elem_type_name(doc, owner_def, tr.inner) + "]"
        else:
            base = _prelude_name(doc, inner)
    if _needs_box(doc, owner_def, inner):
        var rr = _resolve(doc, inner)
        if doc.types[rr].kind != CT_ARRAY:
            base = String("Box[") + base + "]"
    if optional:
        return String("Optional[") + base + "]"
    return base


def _zero_expr(tn: String) -> String:
    if tn == "Bool":
        return String("False")
    if tn == "Int64":
        return String("Int64(0)")
    if tn == "UInt64":
        return String("UInt64(0)")
    if tn == "Float64":
        return String("0.0")
    if tn == "String":
        return String("String()")
    if tn == "List[Byte]":
        return String("List[Byte]()")
    if tn.byte_length() >= 9:
        # Optional[...] or List[...]
        return tn + "()"
    return tn + "()"


def _header() -> String:
    var out = String()
    out += "from std.collections import List, Optional, Span\n\n"
    out += "from cbor import (\n"
    out += "    Box,\n"
    out += "    CborDatum,\n"
    out += "    DecodeError,\n"
    out += "    EncodeOptions,\n"
    out += "    WireReader,\n"
    out += "    WireWriter,\n"
    out += "    encoded_bstr_len,\n"
    out += "    encoded_float_preferred_len,\n"
    out += "    encoded_head_len,\n"
    out += "    encoded_int_len,\n"
    out += "    encoded_tstr_len,\n"
    out += "    encoded_uint_len,\n"
    out += ")\n\n\n"
    return out


def _emit_write_value(indent: String, access: String, tn: String) -> String:
    var out = String()
    if tn == "Bool":
        out += indent + "w.write_bool(" + access + ")\n"
    elif tn == "Int64":
        out += indent + "w.write_int(" + access + ")\n"
    elif tn == "UInt64":
        out += indent + "w.write_uint(" + access + ")\n"
    elif tn == "Float64":
        out += indent + "w.write_float_preferred(" + access + ")\n"
    elif tn == "String":
        out += indent + "w.write_tstr(" + access + ")\n"
    elif tn == "List[Byte]":
        out += indent + "w.write_bstr(" + access + ")\n"
    elif tn == "List[Float64]":
        out += indent + "w.write_array_len(len(" + access + "))\n"
        out += indent + "for _i in range(len(" + access + ")):\n"
        out += indent + "    w.write_float_preferred(" + access + "[_i])\n"
    elif tn == "List[String]":
        out += indent + "w.write_array_len(len(" + access + "))\n"
        out += indent + "for _i in range(len(" + access + ")):\n"
        out += indent + "    w.write_tstr(" + access + "[_i])\n"
    elif tn == "List[Int64]":
        out += indent + "w.write_array_len(len(" + access + "))\n"
        out += indent + "for _i in range(len(" + access + ")):\n"
        out += indent + "    w.write_int(" + access + "[_i])\n"
    elif _starts(tn, "List["):
        out += indent + "w.write_array_len(len(" + access + "))\n"
        out += indent + "for _i in range(len(" + access + ")):\n"
        var inner = _cut(tn, 5, tn.byte_length() - 1)
        if _starts(inner, "Box["):
            out += indent + "    " + access + "[_i][].encode_to(w, options)\n"
        else:
            out += indent + "    " + access + "[_i].encode_to(w, options)\n"
    elif _starts(tn, "Box["):
        out += indent + access + "[].encode_to(w, options)\n"
    else:
        out += indent + access + ".encode_to(w, options)\n"
    return out


def _emit_len_value(indent: String, access: String, tn: String) -> String:
    var out = String()
    if tn == "Bool":
        out += indent + "n += 1\n"
    elif tn == "Int64":
        out += indent + "n += encoded_int_len(" + access + ")\n"
    elif tn == "UInt64":
        out += indent + "n += encoded_uint_len(" + access + ")\n"
    elif tn == "Float64":
        out += indent + "n += encoded_float_preferred_len(" + access + ")\n"
    elif tn == "String":
        out += indent + "n += encoded_tstr_len(" + access + ".byte_length())\n"
    elif tn == "List[Byte]":
        out += indent + "n += encoded_bstr_len(len(" + access + "))\n"
    elif tn == "List[Float64]":
        out += indent + "n += encoded_head_len(UInt64(len(" + access + ")))\n"
        out += indent + "for _i in range(len(" + access + ")):\n"
        out += indent + "    n += encoded_float_preferred_len(" + access + "[_i])\n"
    elif tn == "List[String]":
        out += indent + "n += encoded_head_len(UInt64(len(" + access + ")))\n"
        out += indent + "for _i in range(len(" + access + ")):\n"
        out += indent + "    n += encoded_tstr_len(" + access + "[_i].byte_length())\n"
    elif tn == "List[Int64]":
        out += indent + "n += encoded_head_len(UInt64(len(" + access + ")))\n"
        out += indent + "for _i in range(len(" + access + ")):\n"
        out += indent + "    n += encoded_int_len(" + access + "[_i])\n"
    elif _starts(tn, "List["):
        var inner = _cut(tn, 5, tn.byte_length() - 1)
        out += indent + "n += encoded_head_len(UInt64(len(" + access + ")))\n"
        out += indent + "for _i in range(len(" + access + ")):\n"
        if _starts(inner, "Box["):
            out += indent + "    n += " + access + "[_i][].encoded_len(options)\n"
        else:
            out += indent + "    n += " + access + "[_i].encoded_len(options)\n"
    elif _starts(tn, "Box["):
        out += indent + "n += " + access + "[].encoded_len(options)\n"
    else:
        out += indent + "n += " + access + ".encoded_len(options)\n"
    return out


def _opt_assign(indent: String, dest: String, tn: String, expr: String, opt: Bool) -> String:
    if opt:
        return indent + dest + " = Optional[" + tn + "](" + expr + ")\n"
    return indent + dest + " = " + expr + "\n"


def _emit_decode_value(
    indent: String, dest: String, tn: String, opt: Bool
) raises DecodeError -> String:
    var out = String()
    if tn == "Bool":
        return _opt_assign(indent, dest, tn, "r.read_bool()", opt)
    if tn == "Int64":
        return _opt_assign(indent, dest, tn, "r.read_int64()", opt)
    if tn == "UInt64":
        return _opt_assign(indent, dest, tn, "r.read_uint64()", opt)
    if tn == "Float64":
        return _opt_assign(indent, dest, tn, "r.read_float64()", opt)
    if tn == "String":
        return _opt_assign(indent, dest, tn, "r.read_tstr()", opt)
    if tn == "List[Byte]":
        return _opt_assign(indent, dest, tn, "r.read_bstr()", opt)
    if tn == "List[Float64]" or tn == "List[String]" or tn == "List[Int64]" or _starts(
        tn, "List["
    ):
        var inner = _cut(tn, 5, tn.byte_length() - 1)
        out += indent + "var _lst = " + tn + "()\n"
        out += indent + "var _alen = r.read_array_len()\n"
        out += indent + "for _j in range(_alen):\n"
        if tn == "List[Float64]":
            out += indent + "    _lst.append(r.read_float64())\n"
        elif tn == "List[String]":
            out += indent + "    _lst.append(r.read_tstr())\n"
        elif tn == "List[Int64]":
            out += indent + "    _lst.append(r.read_int64())\n"
        elif _starts(inner, "Box["):
            var rec = _cut(inner, 4, inner.byte_length() - 1)
            out += indent + "    var _c = " + rec + "()\n"
            out += indent + "    _c.decode_from(r)\n"
            out += indent + "    _lst.append(Box(_c^))\n"
        else:
            out += indent + "    var _c = " + inner + "()\n"
            out += indent + "    _c.decode_from(r)\n"
            out += indent + "    _lst.append(_c^)\n"
        if opt:
            out += indent + dest + " = Optional[" + tn + "](_lst^)\n"
        else:
            out += indent + dest + " = _lst^\n"
        return out
    if _starts(tn, "Box["):
        var rec2 = _cut(tn, 4, tn.byte_length() - 1)
        out += indent + "var _c = " + rec2 + "()\n"
        out += indent + "_c.decode_from(r)\n"
        if opt:
            out += indent + dest + " = Optional[" + tn + "](Box(_c^))\n"
        else:
            out += indent + dest + " = Box(_c^)\n"
        return out
    out += indent + "var _c = " + tn + "()\n"
    out += indent + "_c.decode_from(r)\n"
    if opt:
        out += indent + dest + " = Optional[" + tn + "](_c^)\n"
    else:
        out += indent + dest + " = _c^\n"
    return out


def _emit_struct_pairs(
    indent: String,
    fields: List[String],
    types: List[String],
    opts: List[Bool],
    key_lits: List[String],
    order: List[Int],
) -> String:
    var out = String()
    for j in range(len(order)):
        var i = order[j]
        var inner_indent = indent
        var access = "self." + fields[i]
        var write_tn = types[i]
        if opts[i]:
            out += indent + "if self." + fields[i] + ":\n"
            inner_indent = indent + "    "
            access = "self." + fields[i] + ".value()"
            write_tn = _cut(types[i], 9, types[i].byte_length() - 1)
        out += inner_indent + key_lits[i]
        out += _emit_write_value(inner_indent, access, write_tn)
    return out


def _emit_decode_expect_then_len(
    fields: List[String],
    types: List[String],
    opts: List[Bool],
    keys: List[String],
) raises DecodeError -> String:
    var out = String()
    if len(fields) == 0:
        out += "            r.skip_item()\n"
        return out
    for i in range(len(fields)):
        var read_tn = types[i]
        var dest = "self." + fields[i]
        if opts[i]:
            read_tn = _cut(types[i], 9, types[i].byte_length() - 1)
        if i == 0:
            out += (
                "            if _expect == 0 and r.bytes_eq(_ks, _kn, \""
                + keys[i]
                + "\"):\n"
            )
        else:
            out += (
                "            elif _expect == "
                + String(i)
                + " and r.bytes_eq(_ks, _kn, \""
                + keys[i]
                + "\"):\n"
            )
        out += _emit_decode_value(String("                "), dest, read_tn, opts[i])
        out += "                _expect = " + String(i + 1) + "\n"
    out += "            else:\n"
    out += _emit_decode_by_key_len(fields, types, opts, keys, String("                "))
    return out


def _emit_decode_by_key_len(
    fields: List[String],
    types: List[String],
    opts: List[Bool],
    keys: List[String],
    indent: String,
) raises DecodeError -> String:
    var out = String()
    if len(fields) == 0:
        out += indent + "r.skip_item()\n"
        return out
    var inner = indent + "    "
    var body = inner + "    "
    var lens = List[Int]()
    for i in range(len(fields)):
        var ln = keys[i].byte_length()
        var seen = False
        for j in range(len(lens)):
            if lens[j] == ln:
                seen = True
                break
        if not seen:
            lens.append(ln)
    for li in range(len(lens)):
        var ln = lens[li]
        if li == 0:
            out += indent + "if _kn == " + String(ln) + ":\n"
        else:
            out += indent + "elif _kn == " + String(ln) + ":\n"
        var first = True
        for i in range(len(fields)):
            if keys[i].byte_length() != ln:
                continue
            var read_tn = types[i]
            var dest = "self." + fields[i]
            if opts[i]:
                read_tn = _cut(types[i], 9, types[i].byte_length() - 1)
            if first:
                out += inner + "if r.bytes_eq(_ks, _kn, \"" + keys[i] + "\"):\n"
                first = False
            else:
                out += inner + "elif r.bytes_eq(_ks, _kn, \"" + keys[i] + "\"):\n"
            out += _emit_decode_value(body, dest, read_tn, opts[i])
        out += inner + "else:\n"
        out += body + "r.skip_item()\n"
    out += indent + "else:\n"
    out += inner + "r.skip_item()\n"
    return out


def _emit_tuple_encode_decode(
    fields: List[String],
    types: List[String],
    opts: List[Bool],
    req: Int,
    has_opt: Bool,
) raises DecodeError -> String:
    var out = String()
    out += "    def encode_to(self, mut w: WireWriter, options: EncodeOptions):\n"
    if has_opt:
        out += "        var n = " + String(req) + "\n"
        for i in range(len(fields)):
            if opts[i]:
                out += "        if self." + fields[i] + ":\n"
                out += "            n += 1\n"
        out += "        w.write_array_len(n)\n"
    else:
        out += "        w.write_array_len(" + String(req) + ")\n"
    for i in range(len(fields)):
        var indent = String("        ")
        var access = "self." + fields[i]
        var write_tn = types[i]
        if opts[i]:
            out += "        if self." + fields[i] + ":\n"
            indent = String("            ")
            access = "self." + fields[i] + ".value()"
            write_tn = _cut(types[i], 9, types[i].byte_length() - 1)
        out += _emit_write_value(indent, access, write_tn)
    out += "\n    def decode_from[origin: ImmOrigin](mut self, mut r: WireReader[origin]) raises DecodeError:\n"
    out += "        var _n = r.read_array_len()\n"
    out += "        var _i = 0\n"
    for i in range(len(fields)):
        var read_tn = types[i]
        var dest = "self." + fields[i]
        if opts[i]:
            read_tn = _cut(types[i], 9, types[i].byte_length() - 1)
            out += "        if _i < _n:\n"
            out += _emit_decode_value(String("            "), dest, read_tn, True)
            out += "            _i += 1\n"
        else:
            out += "        if _i >= _n:\n"
            out += "            raise DecodeError(DecodeError.KIND_EOF, r.position())\n"
            out += _emit_decode_value(String("        "), dest, read_tn, False)
            out += "        _i += 1\n"
    out += "        while _i < _n:\n"
    out += "            r.skip_item()\n"
    out += "            _i += 1\n"
    return out


def _emit_decode_int_keys(
    fields: List[String],
    types: List[String],
    opts: List[Bool],
    key_ints: List[Int64],
) raises DecodeError -> String:
    var out = String()
    out += "\n    def decode_from[origin: ImmOrigin](mut self, mut r: WireReader[origin]) raises DecodeError:\n"
    out += "        var _pairs = r.read_map_len()\n"
    if len(fields) > 0:
        out += "        var _expect = 0\n"
    out += "        for _i in range(_pairs):\n"
    out += "            var _ik = Int64(0)\n"
    out += "            if not r.take_int_key(_ik):\n"
    out += "                r.skip_item()\n"
    out += "                continue\n"
    for i in range(len(fields)):
        var read_tn = types[i]
        var dest = "self." + fields[i]
        if opts[i]:
            read_tn = _cut(types[i], 9, types[i].byte_length() - 1)
        var iks = String(key_ints[i])
        if i == 0:
            out += "            if _expect == 0 and _ik == Int64(" + iks + "):\n"
        else:
            out += (
                "            elif _expect == "
                + String(i)
                + " and _ik == Int64("
                + iks
                + "):\n"
            )
        out += _emit_decode_value(String("                "), dest, read_tn, opts[i])
        out += "                _expect = " + String(i + 1) + "\n"
    if len(fields) == 0:
        out += "            r.skip_item()\n"
    else:
        out += "            else:\n"
        for i in range(len(fields)):
            var read_tn2 = types[i]
            var dest2 = "self." + fields[i]
            if opts[i]:
                read_tn2 = _cut(types[i], 9, types[i].byte_length() - 1)
            if i == 0:
                out += "                if _ik == Int64(" + String(key_ints[i]) + "):\n"
            else:
                out += "                elif _ik == Int64(" + String(key_ints[i]) + "):\n"
            out += _emit_decode_value(String("                    "), dest2, read_tn2, opts[i])
        out += "                else:\n"
        out += "                    r.skip_item()\n"
    return out


def emit_union(
    doc: CddlDoc, name: String, type_idx: Int, owner_def: Int
) raises DecodeError -> String:
    var br = List[Int]()
    _flatten_choice(doc, type_idx, br)
    var rec = 0
    var first_plain = -1
    for i in range(len(br)):
        if doc.types[br[i]].kind == CT_NULL:
            continue
        if _needs_box(doc, owner_def, br[i]):
            rec += 1
        elif first_plain < 0:
            first_plain = i
    if rec == len(br) and rec > 0:
        raise DecodeError(DecodeError.KIND_CDDL, 0)
    if first_plain < 0:
        first_plain = 0
    var uname = _mojo_ident(name)
    var out = _header()
    out += "struct " + uname + "(Copyable, Movable, Defaultable, Deinitable, CborDatum):\n"
    out += "    var tag: Int\n"
    var tns = List[String]()
    for i in range(len(br)):
        var tn = _prelude_name(doc, br[i])
        if _needs_box(doc, owner_def, br[i]):
            tn = String("Box[") + tn + "]"
        tns.append(tn)
        out += "    var v" + String(i) + ": " + tn + "\n"
    out += "\n    def __init__(out self):\n"
    out += "        self.tag = " + String(first_plain) + "\n"
    for i in range(len(br)):
        out += "        self.v" + String(i) + " = " + _zero_expr(tns[i]) + "\n"
    out += "\n    def encoded_len(self, options: EncodeOptions) -> Int:\n"
    for i in range(len(br)):
        if i == 0:
            out += "        if self.tag == 0:\n"
        else:
            out += "        elif self.tag == " + String(i) + ":\n"
        out += "            var n = 0\n"
        out += _emit_len_value(String("            "), "self.v" + String(i), tns[i])
        out += "            return n\n"
    out += "        return 0\n\n"
    out += "    def encode_to(self, mut w: WireWriter, options: EncodeOptions):\n"
    for i in range(len(br)):
        if i == 0:
            out += "        if self.tag == 0:\n"
        else:
            out += "        elif self.tag == " + String(i) + ":\n"
        out += _emit_write_value(String("            "), "self.v" + String(i), tns[i])
    out += "\n    def decode_from[origin: ImmOrigin](mut self, mut r: WireReader[origin]) raises DecodeError:\n"
    out += "        var _hb = r.peek_head_byte()\n"
    out += "        var _maj = _hb >> 5\n"
    out += "        var _ai = _hb & 0x1F\n"
    for i in range(len(br)):
        var k = doc.types[br[i]].kind
        var cond = String("True")
        if k == CT_INT or k == CT_UINT:
            cond = String("_maj == 0 or _maj == 1")
        elif k == CT_TSTR:
            cond = String("_maj == 3")
        elif k == CT_BSTR:
            cond = String("_maj == 2")
        elif k == CT_BOOL:
            cond = String("_maj == 7 and (_ai == 20 or _ai == 21)")
        elif k == CT_FLOAT:
            cond = String("_maj == 7 and (_ai == 25 or _ai == 26 or _ai == 27)")
        elif k == CT_STRUCT:
            if doc.types[br[i]].name == "[]":
                cond = String("_maj == 4")
            else:
                cond = String("_maj == 5")
        elif k == CT_ARRAY:
            cond = String("_maj == 4")
        if i == 0:
            out += "        if " + cond + ":\n"
        else:
            out += "        elif " + cond + ":\n"
        out += "            self.tag = " + String(i) + "\n"
        out += _emit_decode_value(String("            "), "self.v" + String(i), tns[i], False)
        out += "            return\n"
    out += "        raise DecodeError(DecodeError.KIND_TYPE, r.position())\n"
    return out


def emit_struct(doc: CddlDoc, def_i: Int) raises DecodeError -> String:
    var name = _mojo_ident(doc.def_names[def_i])
    var ty = _resolve(doc, doc.def_types[def_i])
    var t = doc.types[ty]
    if t.kind != CT_STRUCT:
        raise DecodeError(DecodeError.KIND_CDDL, 0)
    var fields = List[String]()
    var types = List[String]()
    var opts = List[Bool]()
    var keys = List[String]()
    var key_kinds = List[Int]()
    var key_ints = List[Int64]()
    var inners = List[Int]()
    for m in range(t.members_count):
        var mem = doc.members[t.members_start + m]
        var opt = _is_optional_member(doc, mem.optional, mem.type_idx)
        var inner = _unwrap_optional(doc, mem.type_idx)
        if _needs_box(doc, def_i, inner) and not opt:
            var rr = _resolve(doc, inner)
            if doc.types[rr].kind != CT_ARRAY:
                raise DecodeError(DecodeError.KIND_CDDL, 0)
        var fname = mem.name
        if fname.byte_length() == 0:
            fname = String("e") + String(m)
        var tn = _field_type_name(doc, def_i, mem.type_idx, opt, name, fname)
        fields.append(_mojo_ident(fname))
        types.append(tn)
        opts.append(opt)
        keys.append(mem.name)
        key_kinds.append(mem.key_kind)
        key_ints.append(mem.key_int)
        inners.append(inner)
    var is_tuple = t.name == "[]"
    var out = _header()
    out += "struct " + name + "(Copyable, Movable, Defaultable, Deinitable, CborDatum):\n"
    for i in range(len(fields)):
        out += "    var " + fields[i] + ": " + types[i] + "\n"
    out += "\n    def __init__(out self):\n"
    for i in range(len(fields)):
        out += "        self." + fields[i] + " = " + _zero_expr(types[i]) + "\n"
    out += "\n    def __init__(out self"
    for i in range(len(fields)):
        out += ", var " + fields[i] + ": " + types[i]
    out += "):\n"
    for i in range(len(fields)):
        out += "        self." + fields[i] + " = " + fields[i] + "^\n"
    var req = 0
    var has_opt = False
    for i in range(len(fields)):
        if opts[i]:
            has_opt = True
        else:
            req += 1
    out += "\n    def encoded_len(self, options: EncodeOptions) -> Int:\n"
    out += "        var n = 0\n"
    if has_opt:
        out += "        var _pairs = " + String(req) + "\n"
        for i in range(len(fields)):
            if opts[i]:
                out += "        if self." + fields[i] + ":\n"
                out += "            _pairs += 1\n"
        out += "        n += encoded_head_len(UInt64(_pairs))\n"
    else:
        out += "        n += encoded_head_len(UInt64(" + String(req) + "))\n"
    for i in range(len(fields)):
        var indent = String("        ")
        var access = "self." + fields[i]
        var write_tn = types[i]
        if opts[i]:
            out += "        if self." + fields[i] + ":\n"
            indent = String("            ")
            access = "self." + fields[i] + ".value()"
            write_tn = _cut(types[i], 9, types[i].byte_length() - 1)
        if (not is_tuple) and key_kinds[i] == CK_INT_KEY:
            out += indent + "n += encoded_int_len(Int64(" + String(key_ints[i]) + "))\n"
        elif not is_tuple:
            out += indent + "n += encoded_tstr_len(" + String(keys[i].byte_length()) + ")\n"
        out += _emit_len_value(indent, access, write_tn)
    out += "        return n\n\n"
    if is_tuple:
        out += _emit_tuple_encode_decode(fields, types, opts, req, has_opt)
        return out
    var cddl_order = List[Int]()
    var encs = List[List[Byte]]()
    for i in range(len(fields)):
        cddl_order.append(i)
        if key_kinds[i] == CK_INT_KEY:
            encs.append(_int_encoded_bytes(key_ints[i]))
        else:
            encs.append(_tstr_encoded_bytes(keys[i]))
    var cde_order = _cde_order_enc(encs)
    var key_lits = List[String]()
    for i in range(len(fields)):
        if key_kinds[i] == CK_INT_KEY:
            key_lits.append("w.write_int(Int64(" + String(key_ints[i]) + "))\n")
        else:
            key_lits.append("w.write_bytes(" + _xbytes_lit(encs[i]) + ")\n")
    out += "    def encode_to(self, mut w: WireWriter, options: EncodeOptions):\n"
    if has_opt:
        out += "        var n = " + String(req) + "\n"
        for i in range(len(fields)):
            if opts[i]:
                out += "        if self." + fields[i] + ":\n"
                out += "            n += 1\n"
        out += "        w.write_map_len(n)\n"
    else:
        out += "        w.write_map_len(" + String(req) + ")\n"
    if len(fields) > 0 and not _same_order(cddl_order, cde_order):
        out += "        if options.is_cde():\n"
        out += _emit_struct_pairs(
            String("            "), fields, types, opts, key_lits, cde_order
        )
        out += "        else:\n"
        out += _emit_struct_pairs(
            String("            "), fields, types, opts, key_lits, cddl_order
        )
    else:
        out += _emit_struct_pairs(
            String("        "), fields, types, opts, key_lits, cddl_order
        )
    var all_int = len(fields) > 0
    for i in range(len(fields)):
        if key_kinds[i] != CK_INT_KEY:
            all_int = False
    if all_int:
        out += _emit_decode_int_keys(fields, types, opts, key_ints)
    else:
        out += "\n    def decode_from[origin: ImmOrigin](mut self, mut r: WireReader[origin]) raises DecodeError:\n"
        out += "        var _pairs = r.read_map_len()\n"
        if len(fields) > 0:
            out += "        var _expect = 0\n"
        out += "        for _i in range(_pairs):\n"
        out += "            var _ks = 0\n"
        out += "            var _kn = 0\n"
        out += "            if not r.take_definite_tstr(_ks, _kn):\n"
        out += "                r.skip_item()\n"
        out += "                continue\n"
        out += _emit_decode_expect_then_len(fields, types, opts, keys)
    return out


def emit_all(doc: CddlDoc) raises DecodeError -> List[String]:
    var out = List[String]()
    for i in range(len(doc.def_names)):
        var ty = _resolve(doc, doc.def_types[i])
        if doc.types[ty].kind == CT_CHOICE and not _is_null_choice(doc, ty):
            out.append(_mojo_ident(doc.def_names[i]))
            out.append(emit_union(doc, doc.def_names[i], ty, i))
    for i in range(len(doc.def_names)):
        var ty2 = _resolve(doc, doc.def_types[i])
        if doc.types[ty2].kind != CT_STRUCT:
            continue
        var t = doc.types[ty2]
        var owner = _mojo_ident(doc.def_names[i])
        for m in range(t.members_count):
            var mem = doc.members[t.members_start + m]
            var inner = _unwrap_optional(doc, mem.type_idx)
            if doc.types[inner].kind != CT_NAMED and _is_multi_choice(doc, inner):
                var un = owner + "_" + _mojo_ident(mem.name)
                out.append(un)
                out.append(emit_union(doc, un, inner, i))
        out.append(owner)
        out.append(emit_struct(doc, i))
    return out^
