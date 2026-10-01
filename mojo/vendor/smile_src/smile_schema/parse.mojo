from smile_schema.json import J_ARR, J_BOOL, J_INT, J_NULL, J_OBJ, J_STR, JDoc, parse_json
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
from smile_runtime.error import DecodeError


def parse_schema_file(path: String) raises DecodeError -> SchemaDoc:
    var text: String
    try:
        var f = open(path, "r")
        text = f.read()
        f.close()
    except _:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    return parse_schema(text, _stem(path))


def parse_schema(text: String, root_name: String) raises DecodeError -> SchemaDoc:
    var doc = parse_json(text)
    if doc.kind(doc.root) != J_OBJ:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var out = SchemaDoc()
    out.root_name = root_name
    var title = doc.get(doc.root, "title")
    if title >= 0 and doc.kind(title) == J_STR and doc.as_str(title).byte_length() > 0:
        out.root_name = doc.as_str(title)
    _collect_def_names(doc, doc.root, out)
    var i = 0
    while i < len(out.def_names):
        var body = _def_body(doc, doc.root, out.def_names[i])
        var def_name = out.def_names[i] + ""
        var tid = _parse_type(doc, body, out, def_name)
        out.def_types.append(tid)
        i += 1
    var root_copy = out.root_name + ""
    out.root = _parse_type(doc, doc.root, out, root_copy)
    _resolve_refs(out)
    return out^


def _stem(path: String) -> String:
    var raw = path.as_bytes()
    var start = 0
    var i = 0
    while i < len(raw):
        if Int(raw[i]) == 47:
            start = i + 1
        i += 1
    var end = len(raw)
    i = start
    while i < len(raw):
        if Int(raw[i]) == 46:
            end = i
        i += 1
    var name = String()
    i = start
    while i < end:
        name = name + chr(Int(raw[i]))
        i += 1
    if name.byte_length() == 0:
        return String("Root")
    var b = name.as_bytes()
    var first = Int(b[0])
    if first >= 97 and first <= 122:
        var capped = chr(first - 32)
        i = 1
        while i < len(b):
            capped = capped + chr(Int(b[i]))
            i += 1
        return capped
    return name


def _append_def_names(doc: JDoc, defs: Int, mut out: SchemaDoc):
    if defs < 0 or doc.kind(defs) != J_OBJ:
        return
    var i = 0
    while i < doc.count(defs):
        out.def_names.append(doc.key_at(defs, i))
        i += 1


def _collect_def_names(doc: JDoc, id: Int, mut out: SchemaDoc):
    if doc.get(id, "$defs") >= 0:
        _append_def_names(doc, doc.get(id, "$defs"), out)
        return
    if doc.get(id, "definitions") >= 0:
        _append_def_names(doc, doc.get(id, "definitions"), out)


def _def_body(doc: JDoc, id: Int, name: String) -> Int:
    var key = "$defs"
    if doc.get(id, "$defs") < 0:
        key = "definitions"
    var defs = doc.get(id, key)
    return doc.get(defs, name)


def _has(doc: JDoc, id: Int, key: String) -> Bool:
    return doc.get(id, key) >= 0


def _reject_unknown(doc: JDoc, id: Int) raises DecodeError:
    if doc.kind(id) != J_OBJ:
        return
    var allowed = List[String]()
    allowed.append("type")
    allowed.append("properties")
    allowed.append("required")
    allowed.append("items")
    allowed.append("$ref")
    allowed.append("$defs")
    allowed.append("definitions")
    allowed.append("enum")
    allowed.append("const")
    allowed.append("oneOf")
    allowed.append("anyOf")
    allowed.append("$id")
    allowed.append("title")
    allowed.append("description")
    allowed.append("$schema")
    var i = 0
    while i < doc.count(id):
        var key = doc.key_at(id, i)
        var ok = False
        var k = 0
        while k < len(allowed):
            if allowed[k] == key:
                ok = True
            k += 1
        if not ok:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        i += 1


def _parse_type(doc: JDoc, id: Int, mut out: SchemaDoc, name: String) raises DecodeError -> Int:
    _reject_unknown(doc, id)
    if doc.kind(id) != J_OBJ:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    if _has(doc, id, "$ref"):
        var ref_id = doc.get(id, "$ref")
        if doc.kind(ref_id) != J_STR:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var ty = SchemaType(ST_REF, name)
        ty.ref_name = _ref_name(doc.as_str(ref_id))
        return out.add(ty^)
    if _has(doc, id, "enum"):
        return _parse_enum(doc, id, out, name)
    if _has(doc, id, "const"):
        return _parse_const(doc, id, out, name)
    if _has(doc, id, "oneOf"):
        return _parse_union(doc, doc.get(id, "oneOf"), out, name)
    if _has(doc, id, "anyOf"):
        return _parse_union(doc, doc.get(id, "anyOf"), out, name)
    if _has(doc, id, "type"):
        return _parse_typed(doc, id, out, name)
    if _has(doc, id, "properties"):
        return _parse_object(doc, id, out, name)
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


def _ref_name(text: String) raises DecodeError -> String:
    var raw = text.as_bytes()
    var n = 8
    if _starts(text, "#/definitions/"):
        n = 14
    elif not _starts(text, "#/$defs/"):
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var out = String()
    var i = n
    while i < len(raw):
        out = out + chr(Int(raw[i]))
        i += 1
    if out.byte_length() == 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    return out


def _starts(text: String, prefix: String) -> Bool:
    var a = text.as_bytes()
    var b = prefix.as_bytes()
    if len(a) < len(b):
        return False
    var i = 0
    while i < len(b):
        if Int(a[i]) != Int(b[i]):
            return False
        i += 1
    return True


def _parse_typed(doc: JDoc, id: Int, mut out: SchemaDoc, name: String) raises DecodeError -> Int:
    var t = doc.get(id, "type")
    if doc.kind(t) == J_ARR:
        if doc.count(t) != 2:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var a = doc.as_str(doc.at(t, 0))
        var b = doc.as_str(doc.at(t, 1))
        var inner_name = b
        if b == "null":
            inner_name = a
        elif a != "null":
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var inner = _kind_from_name(doc, id, out, name, inner_name)
        var opt = SchemaType(ST_OPTIONAL, name)
        opt.inner = inner
        return out.add(opt^)
    if doc.kind(t) != J_STR:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var tn = doc.as_str(t)
    if tn == "object":
        return _parse_object(doc, id, out, name)
    if tn == "array":
        if not _has(doc, id, "items"):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var items = _parse_type(doc, doc.get(id, "items"), out, name + "Item")
        var ty = SchemaType(ST_ARRAY, name)
        ty.inner = items
        return out.add(ty^)
    return _kind_from_name(doc, id, out, name, tn)


def _kind_from_name(
    doc: JDoc, id: Int, mut out: SchemaDoc, name: String, tn: String
) raises DecodeError -> Int:
    if tn == "string":
        return out.add(SchemaType(ST_STRING, name))
    if tn == "integer":
        return out.add(SchemaType(ST_INT, name))
    if tn == "number":
        return out.add(SchemaType(ST_NUMBER, name))
    if tn == "boolean":
        return out.add(SchemaType(ST_BOOL, name))
    if tn == "null":
        return out.add(SchemaType(ST_NULL, name))
    if tn == "binary":
        return out.add(SchemaType(ST_BINARY, name))
    if tn == "biginteger":
        return out.add(SchemaType(ST_BIGINT, name))
    if tn == "bigdecimal":
        return out.add(SchemaType(ST_DECIMAL, name))
    if tn == "object":
        return _parse_object(doc, id, out, name)
    if tn == "array":
        if not _has(doc, id, "items"):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var items = _parse_type(doc, doc.get(id, "items"), out, name + "Item")
        var ty = SchemaType(ST_ARRAY, name)
        ty.inner = items
        return out.add(ty^)
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


def _parse_object(doc: JDoc, id: Int, mut out: SchemaDoc, name: String) raises DecodeError -> Int:
    var ty = SchemaType(ST_OBJECT, name)
    var req = List[String]()
    if _has(doc, id, "required"):
        var r = doc.get(id, "required")
        if doc.kind(r) != J_ARR:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var i = 0
        while i < doc.count(r):
            req.append(doc.as_str(doc.at(r, i)))
            i += 1
    if _has(doc, id, "properties"):
        var props = doc.get(id, "properties")
        if doc.kind(props) != J_OBJ:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var i = 0
        while i < doc.count(props):
            var pname = doc.key_at(props, i)
            var child = doc.at(props, i)
            var tid = _parse_type(doc, child, out, pname)
            var need = False
            var k = 0
            while k < len(req):
                if req[k] == pname:
                    need = True
                k += 1
            if not need:
                var opt = SchemaType(ST_OPTIONAL, pname)
                opt.inner = tid
                tid = out.add(opt^)
            ty.props.append(SchemaProp(pname, tid, need))
            i += 1
    return out.add(ty^)


def _is_null_schema(doc: JDoc, id: Int) -> Bool:
    if doc.kind(id) != J_OBJ:
        return False
    var t = doc.get(id, "type")
    if t < 0 or doc.kind(t) != J_STR:
        return False
    return doc.as_str(t) == "null"


def _parse_union(doc: JDoc, id: Int, mut out: SchemaDoc, name: String) raises DecodeError -> Int:
    if doc.kind(id) != J_ARR or doc.count(id) < 2:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    if doc.count(id) == 2:
        var a = doc.at(id, 0)
        var b = doc.at(id, 1)
        if _is_null_schema(doc, a):
            var inner = _parse_type(doc, b, out, name)
            var opt = SchemaType(ST_OPTIONAL, name)
            opt.inner = inner
            return out.add(opt^)
        if _is_null_schema(doc, b):
            var inner = _parse_type(doc, a, out, name)
            var opt = SchemaType(ST_OPTIONAL, name)
            opt.inner = inner
            return out.add(opt^)
    var ty = SchemaType(ST_UNION, name)
    var i = 0
    while i < doc.count(id):
        ty.branch_ids.append(_parse_type(doc, doc.at(id, i), out, name + String(i)))
        i += 1
    return out.add(ty^)


def _parse_enum(doc: JDoc, id: Int, mut out: SchemaDoc, name: String) raises DecodeError -> Int:
    var arr = doc.get(id, "enum")
    if doc.kind(arr) != J_ARR or doc.count(arr) == 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var ty = SchemaType(ST_ENUM, name)
    var first = doc.at(arr, 0)
    if doc.kind(first) == J_STR:
        var i = 0
        while i < doc.count(arr):
            ty.enum_strings.append(doc.as_str(doc.at(arr, i)))
            i += 1
        ty.inner = out.add(SchemaType(ST_STRING, name))
    elif doc.kind(first) == J_INT:
        var i = 0
        while i < doc.count(arr):
            ty.enum_ints.append(doc.as_int(doc.at(arr, i)))
            i += 1
        ty.inner = out.add(SchemaType(ST_INT, name))
    else:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    return out.add(ty^)


def _parse_const(doc: JDoc, id: Int, mut out: SchemaDoc, name: String) raises DecodeError -> Int:
    var c = doc.get(id, "const")
    var ty = SchemaType(ST_CONST, name)
    if doc.kind(c) == J_STR:
        ty.const_kind = ST_STRING
        ty.const_str = doc.as_str(c)
        ty.inner = out.add(SchemaType(ST_STRING, name))
    elif doc.kind(c) == J_INT:
        ty.const_kind = ST_INT
        ty.const_int = doc.as_int(c)
        ty.inner = out.add(SchemaType(ST_INT, name))
    elif doc.kind(c) == J_BOOL:
        ty.const_kind = ST_BOOL
        ty.const_bool = doc.as_bool(c)
        ty.inner = out.add(SchemaType(ST_BOOL, name))
    elif doc.kind(c) == J_NULL:
        ty.const_kind = ST_NULL
        ty.inner = out.add(SchemaType(ST_NULL, name))
    else:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    return out.add(ty^)


def _resolve_refs(mut out: SchemaDoc) raises DecodeError:
    var i = 0
    while i < len(out.types):
        var t = out.types[i].copy()
        if t.kind == ST_REF:
            var found = -1
            var k = 0
            while k < len(out.def_names):
                if out.def_names[k] == t.ref_name:
                    found = out.def_types[k]
                k += 1
            if found < 0:
                raise DecodeError(DecodeError.KIND_SCHEMA, 0)
            t.inner = found
            out.types[i] = t^
        i += 1
