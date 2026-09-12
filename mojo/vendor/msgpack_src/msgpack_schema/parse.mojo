from std.collections import List

from msgpack_runtime.error import DecodeError
from msgpack_schema.json_read import ReadValue, decode_json
from msgpack_schema.model import (
    ENC_ARRAY,
    ENC_INTKEYS,
    ENC_MAP,
    ST_ARRAY,
    ST_BOOL,
    ST_BYTES,
    ST_CONST,
    ST_ENUM,
    ST_EXT,
    ST_INT,
    ST_NULL,
    ST_NUMBER,
    ST_OBJECT,
    ST_OPTIONAL,
    ST_REF,
    ST_STRING,
    ST_TIMESTAMP,
    ST_UNION,
    SchemaDoc,
    SchemaProp,
    SchemaType,
)


def parse_schema_file(path: String) raises DecodeError -> SchemaDoc:
    var text: String
    try:
        var f = open(path, "r")
        text = f.read()
        f.close()
    except _:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var v = decode_json(text.as_bytes())
    var stem = _stem(path)
    return parse_schema(v, stem)


def parse_schema(v: ReadValue, root_name: String = "Root") raises DecodeError -> SchemaDoc:
    if not v.is_object():
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    _reject_unknown(v)
    var doc = SchemaDoc()
    doc.root_name = _name_hint(v, root_name)
    _collect_defs(v, doc)
    var root_nm = doc.root_name
    doc.root = _parse_type(v, doc, root_nm)
    return doc^


def _stem(path: String) -> String:
    var b = path.as_bytes()
    var start = 0
    var end = len(b)
    var i = 0
    while i < len(b):
        if Int(b[i]) == 47:
            start = i + 1
        i += 1
    i = start
    while i < len(b):
        if Int(b[i]) == 46:
            end = i
        i += 1
    try:
        return String(from_utf8=b[start:end])
    except _:
        return String("Root")


def _name_hint(v: ReadValue, fallback: String) -> String:
    try:
        return v.get("title").as_str()
    except _:
        pass
    return fallback


def _has(v: ReadValue, key: String) -> Bool:
    try:
        _ = v.get(key)
        return True
    except _:
        return False


def _reject_unknown(v: ReadValue) raises DecodeError:
    if not v.is_object():
        return
    var i = 0
    while i < v.count():
        var p = v.pair(i)
        if not _allowed(p[0]):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        i += 1


def _allowed(k: String) -> Bool:
    return (
        k == "type"
        or k == "properties"
        or k == "required"
        or k == "items"
        or k == "$ref"
        or k == "$defs"
        or k == "definitions"
        or k == "enum"
        or k == "const"
        or k == "oneOf"
        or k == "anyOf"
        or k == "$id"
        or k == "title"
        or k == "description"
        or k == "$schema"
        or k == "x-msgpack-timestamp"
        or k == "x-msgpack-encoding"
        or k == "x-msgpack-key"
    )


def _collect_defs(v: ReadValue, mut doc: SchemaDoc) raises DecodeError:
    if _has(v, "$defs"):
        var defs = v.get("$defs")
        _collect_defs_obj(defs, doc)
        return
    if _has(v, "definitions"):
        var defs2 = v.get("definitions")
        _collect_defs_obj(defs2, doc)


def _collect_defs_obj(defs: ReadValue, mut doc: SchemaDoc) raises DecodeError:
    if not defs.is_object():
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var i = 0
    while i < defs.count():
        var p = defs.pair(i)
        _reject_unknown(p[1])
        var tid = _parse_type(p[1], doc, p[0])
        doc.def_names.append(p[0])
        doc.def_types.append(tid)
        i += 1


def _parse_type(v: ReadValue, mut doc: SchemaDoc, name: String) raises DecodeError -> Int:
    _reject_unknown(v)
    if _has(v, "x-msgpack-timestamp"):
        var flag = v.get("x-msgpack-timestamp")
        if not flag.is_bool() or not flag.as_bool():
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return doc.add(SchemaType(ST_TIMESTAMP, name))
    if _has(v, "$ref"):
        var ty = SchemaType(ST_REF, name)
        ty.inner = _resolve_ref(v.get("$ref").as_str(), doc)
        return doc.add(ty^)
    if _has(v, "enum"):
        return _parse_enum(v, doc, name)
    if _has(v, "const"):
        return _parse_const(v, doc, name)
    if _has(v, "oneOf"):
        return _parse_union(v.get("oneOf"), doc, name)
    if _has(v, "anyOf"):
        return _parse_union(v.get("anyOf"), doc, name)
    if _has(v, "type"):
        return _parse_typed(v, doc, name)
    if _has(v, "properties"):
        return _parse_object(v, doc, name)
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


def _parse_typed(v: ReadValue, mut doc: SchemaDoc, name: String) raises DecodeError -> Int:
    var t = v.get("type")
    if t.is_array():
        if t.count() != 2:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var an = t.at(0).as_str()
        var bn = t.at(1).as_str()
        var inner_name: String
        if an == "null":
            inner_name = bn
        elif bn == "null":
            inner_name = an
        else:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var inner = _kind_from_name(inner_name, v, doc, name)
        var opt = SchemaType(ST_OPTIONAL, name)
        opt.inner = inner
        return doc.add(opt^)
    var tn = t.as_str()
    if tn == "object":
        return _parse_object(v, doc, name)
    if tn == "array":
        if not _has(v, "items"):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var items = _parse_type(v.get("items"), doc, name + "Item")
        var ty = SchemaType(ST_ARRAY, name)
        ty.inner = items
        return doc.add(ty^)
    if tn == "string":
        return doc.add(SchemaType(ST_STRING, name))
    if tn == "integer":
        return doc.add(SchemaType(ST_INT, name))
    if tn == "number":
        return doc.add(SchemaType(ST_NUMBER, name))
    if tn == "boolean":
        return doc.add(SchemaType(ST_BOOL, name))
    if tn == "null":
        return doc.add(SchemaType(ST_NULL, name))
    if tn == "bytes":
        return doc.add(SchemaType(ST_BYTES, name))
    if tn == "extension":
        return doc.add(SchemaType(ST_EXT, name))
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


def _kind_from_name(
    tn: String, v: ReadValue, mut doc: SchemaDoc, name: String
) raises DecodeError -> Int:
    if tn == "string":
        return doc.add(SchemaType(ST_STRING, name))
    if tn == "integer":
        return doc.add(SchemaType(ST_INT, name))
    if tn == "number":
        return doc.add(SchemaType(ST_NUMBER, name))
    if tn == "boolean":
        return doc.add(SchemaType(ST_BOOL, name))
    if tn == "bytes":
        return doc.add(SchemaType(ST_BYTES, name))
    if tn == "extension":
        return doc.add(SchemaType(ST_EXT, name))
    if tn == "object":
        return _parse_object(v, doc, name)
    if tn == "array":
        if not _has(v, "items"):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var items = _parse_type(v.get("items"), doc, name + "Item")
        var ty = SchemaType(ST_ARRAY, name)
        ty.inner = items
        return doc.add(ty^)
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


def _parse_object(v: ReadValue, mut doc: SchemaDoc, name: String) raises DecodeError -> Int:
    var ty = SchemaType(ST_OBJECT, name)
    if _has(v, "x-msgpack-encoding"):
        var enc = v.get("x-msgpack-encoding").as_str()
        if enc == "array":
            ty.encoding = ENC_ARRAY
        elif enc == "intkeys":
            ty.encoding = ENC_INTKEYS
        elif enc == "map":
            ty.encoding = ENC_MAP
        else:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var req = List[String]()
    if _has(v, "required"):
        var r = v.get("required")
        if not r.is_array():
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var i = 0
        while i < r.count():
            req.append(r.at(i).as_str())
            i += 1
    if _has(v, "properties"):
        var props = v.get("properties")
        if not props.is_object():
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var i = 0
        while i < props.count():
            var p = props.pair(i)
            var tid = _parse_type(p[1], doc, p[0])
            var need = False
            var k = 0
            while k < len(req):
                if req[k] == p[0]:
                    need = True
                k += 1
            if not need:
                var opt = SchemaType(ST_OPTIONAL, p[0])
                opt.inner = tid
                tid = doc.add(opt^)
            var ik = Int64(i)
            var has_ik = False
            if _has(p[1], "x-msgpack-key"):
                ik = p[1].get("x-msgpack-key").as_int()
                has_ik = True
            ty.props.append(SchemaProp(p[0], tid, need, ik, has_ik))
            i += 1
    if ty.encoding == ENC_INTKEYS:
        var j = 0
        while j < len(ty.props):
            if not ty.props[j].has_int_key:
                raise DecodeError(DecodeError.KIND_SCHEMA, 0)
            j += 1
    return doc.add(ty^)


def _parse_union(arr: ReadValue, mut doc: SchemaDoc, name: String) raises DecodeError -> Int:
    if not arr.is_array() or arr.count() < 2:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    if arr.count() == 2:
        var a = arr.at(0)
        var b = arr.at(1)
        if _is_null_schema(a):
            var inner = _parse_type(b, doc, name)
            var opt = SchemaType(ST_OPTIONAL, name)
            opt.inner = inner
            return doc.add(opt^)
        if _is_null_schema(b):
            var inner = _parse_type(a, doc, name)
            var opt = SchemaType(ST_OPTIONAL, name)
            opt.inner = inner
            return doc.add(opt^)
    var ty = SchemaType(ST_UNION, name)
    var i = 0
    while i < arr.count():
        var br = arr.at(i)
        ty.branch_ids.append(_parse_type(br, doc, name + String(i)))
        i += 1
    return doc.add(ty^)


def _is_null_schema(v: ReadValue) -> Bool:
    try:
        if v.is_object() and _has(v, "type") and v.get("type").as_str() == "null":
            return True
    except _:
        pass
    return False


def _parse_enum(v: ReadValue, mut doc: SchemaDoc, name: String) raises DecodeError -> Int:
    var arr = v.get("enum")
    if not arr.is_array() or arr.count() == 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var ty = SchemaType(ST_ENUM, name)
    var first = arr.at(0)
    if first.is_string():
        var i = 0
        while i < arr.count():
            ty.enum_strings.append(arr.at(i).as_str())
            i += 1
        ty.inner = doc.add(SchemaType(ST_STRING, name))
    elif first.is_int():
        var i = 0
        while i < arr.count():
            ty.enum_ints.append(arr.at(i).as_int())
            i += 1
        ty.inner = doc.add(SchemaType(ST_INT, name))
    else:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    return doc.add(ty^)


def _parse_const(v: ReadValue, mut doc: SchemaDoc, name: String) raises DecodeError -> Int:
    var c = v.get("const")
    var ty = SchemaType(ST_CONST, name)
    if c.is_string():
        ty.const_kind = ST_STRING
        ty.const_str = c.as_str()
        ty.inner = doc.add(SchemaType(ST_STRING, name))
    elif c.is_int():
        ty.const_kind = ST_INT
        ty.const_int = c.as_int()
        ty.inner = doc.add(SchemaType(ST_INT, name))
    elif c.is_bool():
        ty.const_kind = ST_BOOL
        ty.const_bool = c.as_bool()
        ty.inner = doc.add(SchemaType(ST_BOOL, name))
    else:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    return doc.add(ty^)


def _resolve_ref(ref_path: String, mut doc: SchemaDoc) raises DecodeError -> Int:
    if ref_path == "#":
        return doc.root
    var prefix_defs = String("#/$defs/")
    var prefix_old = String("#/definitions/")
    if _starts(ref_path, prefix_defs):
        return _lookup_def(
            _cut(ref_path, prefix_defs.byte_length(), ref_path.byte_length()), doc
        )
    if _starts(ref_path, prefix_old):
        return _lookup_def(
            _cut(ref_path, prefix_old.byte_length(), ref_path.byte_length()), doc
        )
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


def _lookup_def(name: String, mut doc: SchemaDoc) raises DecodeError -> Int:
    var i = 0
    while i < len(doc.def_names):
        if doc.def_names[i] == name:
            return doc.def_types[i]
        i += 1
    raise DecodeError(DecodeError.KIND_SCHEMA, 0)


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
