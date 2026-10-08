from std.collections import List, Span

from arrow_runtime.error import DecodeError
from arrow_runtime.model import (
    TY_BOOL,
    TY_DATE,
    TY_DECIMAL,
    TY_FLOAT,
    TY_INT,
    TY_LIST,
    TY_NULL,
    TY_STRUCT,
    TY_TIMESTAMP,
    TY_UTF8,
    Columnar,
    FieldRec,
)
from arrow_schema.json import J_ARR, J_BOOL, J_NUM, J_OBJ, J_STR, JsonDoc, parse_json


def load_schema[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> Columnar:
    var doc = parse_json(raw)
    var c = Columnar()
    if doc.find(doc.root, "fields") >= 0 and doc.find(doc.root, "properties") < 0:
        _arrow_schema(doc, doc.root, c)
    else:
        var root = _json_schema(doc, doc.root, c, "Root", 1)
        c.add_top(root)
    return c^


def schema_title(doc: JsonDoc) -> String:
    var t = doc.find(doc.root, "title")
    if t >= 0 and doc.kind(t) == J_STR:
        return doc.text(t)
    return "Root"


def _arrow_schema(doc: JsonDoc, id: Int, mut c: Columnar) raises DecodeError:
    var fields = doc.find(id, "fields")
    if fields < 0 or doc.kind(fields) != J_ARR:
        raise DecodeError(DecodeError.KIND_SCHEMA, id)
    var i = 0
    while i < doc.count(fields):
        c.add_top(_arrow_field(doc, doc.child(fields, i), c))
        i += 1


def _arrow_field(doc: JsonDoc, id: Int, mut c: Columnar) raises DecodeError -> Int:
    var f = FieldRec()
    var nm = doc.find(id, "name")
    if nm >= 0 and doc.kind(nm) == J_STR:
        f.name = c.intern(doc.text(nm))
    var nu = doc.find(id, "nullable")
    if nu >= 0 and doc.kind(nu) == J_BOOL and not doc.boolean(nu):
        f.nullable = 0
    var ty = doc.find(id, "type")
    if ty < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, id)
    _arrow_type(doc, ty, f)
    var fid = c.add_field(f)
    var ch = doc.find(id, "children")
    var direct = List[Int]()
    if ch >= 0 and doc.kind(ch) == J_ARR:
        var i = 0
        while i < doc.count(ch):
            direct.append(_arrow_field(doc, doc.child(ch, i), c))
            i += 1
    var start = len(c.kids)
    var i = 0
    while i < len(direct):
        c.kids.append(direct[i])
        i += 1
    var stored = c.fields[fid]
    stored.child0 = start
    stored.nchild = len(direct)
    c.fields[fid] = stored
    return fid


def _arrow_type(doc: JsonDoc, id: Int, mut f: FieldRec) raises DecodeError:
    if doc.kind(id) == J_STR:
        _apply_name(doc.text(id), f)
        return
    var name = doc.find(id, "name")
    if name < 0 or doc.kind(name) != J_STR:
        raise DecodeError(DecodeError.KIND_SCHEMA, id)
    var n = doc.text(name)
    _apply_name(n, f)
    var bits = doc.find(id, "bitWidth")
    if bits >= 0:
        f.bit_width = _int(doc, bits)
    var signed = doc.find(id, "isSigned")
    if signed >= 0 and doc.kind(signed) == J_BOOL:
        f.is_signed = 0
        if doc.boolean(signed):
            f.is_signed = 1
    var prec = doc.find(id, "precision")
    if prec >= 0 and doc.kind(prec) == J_NUM:
        f.precision = _int(doc, prec)
    elif prec >= 0 and doc.kind(prec) == J_STR:
        var p = doc.text(prec)
        if p == "HALF":
            f.unit = 0
        elif p == "SINGLE":
            f.unit = 1
        else:
            f.unit = 2
    var scale = doc.find(id, "scale")
    if scale >= 0:
        f.scale = _int(doc, scale)
    var unit = doc.find(id, "unit")
    if unit >= 0 and doc.kind(unit) == J_STR:
        f.unit = _unit_name(doc.text(unit))
    if f.kind == TY_DECIMAL and f.bit_width == 0:
        f.bit_width = 128


def _apply_name(name: String, mut f: FieldRec):
    if name == "null":
        f.kind = TY_NULL
    elif name == "bool" or name == "boolean":
        f.kind = TY_BOOL
    elif name == "int" or name == "int32":
        f.kind = TY_INT
        if f.bit_width == 0:
            f.bit_width = 32
    elif name == "int64":
        f.kind = TY_INT
        f.bit_width = 64
    elif name == "utf8" or name == "string":
        f.kind = TY_UTF8
    elif name == "floatingpoint" or name == "float64":
        f.kind = TY_FLOAT
        f.unit = 2
    elif name == "float32":
        f.kind = TY_FLOAT
        f.unit = 1
    elif name == "decimal":
        f.kind = TY_DECIMAL
    elif name == "date" or name == "date32":
        f.kind = TY_DATE
        f.unit = 0
    elif name == "timestamp":
        f.kind = TY_TIMESTAMP
    elif name == "list":
        f.kind = TY_LIST
    elif name == "struct":
        f.kind = TY_STRUCT
    else:
        f.kind = TY_UTF8


def _json_schema(doc: JsonDoc, id: Int, mut c: Columnar, name: String, nullable: Int) raises DecodeError -> Int:
    var arrow = doc.find(id, "x-arrow-type")
    if arrow >= 0 and doc.kind(arrow) == J_STR:
        var f = FieldRec()
        f.name = c.intern(name)
        f.nullable = nullable
        _apply_name(doc.text(arrow), f)
        return c.add_field(f)
    var typ = doc.find(id, "type")
    if typ >= 0 and doc.kind(typ) == J_ARR and doc.count(typ) == 2:
        var inner = doc.child(typ, 0)
        if doc.kind(inner) == J_STR and doc.text(inner) == "null":
            inner = doc.child(typ, 1)
        return _named_type(doc, id, doc.text(inner), c, name, 1)
    if typ >= 0 and doc.kind(typ) == J_STR:
        return _named_type(doc, id, doc.text(typ), c, name, nullable)
    if doc.find(id, "properties") >= 0:
        return _object(doc, id, c, name, nullable)
    raise DecodeError(DecodeError.KIND_SCHEMA, id)


def _named_type(
    doc: JsonDoc, id: Int, name: String, mut c: Columnar, field_name: String, nullable: Int
) raises DecodeError -> Int:
    if name == "object":
        return _object(doc, id, c, field_name, nullable)
    if name == "array":
        var items = doc.find(id, "items")
        if items < 0:
            raise DecodeError(DecodeError.KIND_SCHEMA, id)
        var child = _json_schema(doc, items, c, field_name + "Item", 1)
        var f = FieldRec()
        f.name = c.intern(field_name)
        f.kind = TY_LIST
        f.nullable = nullable
        var fid = c.add_field(f)
        var start = len(c.kids)
        c.kids.append(child)
        var stored = c.fields[fid]
        stored.child0 = start
        stored.nchild = 1
        c.fields[fid] = stored
        return fid
    var f = FieldRec()
    f.name = c.intern(field_name)
    f.nullable = nullable
    if name == "integer":
        f.kind = TY_INT
        f.bit_width = 64
    elif name == "number":
        f.kind = TY_FLOAT
        f.unit = 2
    elif name == "string":
        f.kind = TY_UTF8
    elif name == "boolean":
        f.kind = TY_BOOL
    elif name == "null":
        f.kind = TY_NULL
    else:
        raise DecodeError(DecodeError.KIND_SCHEMA, id)
    return c.add_field(f)


def _object(doc: JsonDoc, id: Int, mut c: Columnar, name: String, nullable: Int) raises DecodeError -> Int:
    var f = FieldRec()
    f.name = c.intern(name)
    f.kind = TY_STRUCT
    f.nullable = nullable
    var fid = c.add_field(f)
    var props = doc.find(id, "properties")
    var direct = List[Int]()
    if props >= 0 and doc.kind(props) == J_OBJ:
        var i = 0
        while i < doc.count(props):
            var req = _required(doc, id, doc.key(props, i))
            var child_null = 1
            if req:
                child_null = 0
            direct.append(_json_schema(doc, doc.child(props, i), c, doc.key(props, i), child_null))
            i += 1
    var start = len(c.kids)
    var i = 0
    while i < len(direct):
        c.kids.append(direct[i])
        i += 1
    var stored = c.fields[fid]
    stored.child0 = start
    stored.nchild = len(direct)
    c.fields[fid] = stored
    return fid


def _required(doc: JsonDoc, id: Int, name: String) -> Bool:
    var req = doc.find(id, "required")
    if req < 0 or doc.kind(req) != J_ARR:
        return False
    var i = 0
    while i < doc.count(req):
        var item = doc.child(req, i)
        if doc.kind(item) == J_STR and doc.text(item) == name:
            return True
        i += 1
    return False


def _int(doc: JsonDoc, id: Int) raises DecodeError -> Int:
    if doc.kind(id) != J_NUM:
        raise DecodeError(DecodeError.KIND_SCHEMA, id)
    var text = doc.text(id)
    var raw = text.as_bytes()
    var n = 0
    var i = 0
    var neg = False
    if len(raw) > 0 and Int(raw[0]) == 45:
        neg = True
        i = 1
    while i < len(raw) and Int(raw[i]) >= 48 and Int(raw[i]) <= 57:
        n = n * 10 + (Int(raw[i]) - 48)
        i += 1
    if neg:
        n = -n
    return n


def _unit_name(name: String) -> Int:
    if name == "SECOND":
        return 0
    if name == "MILLISECOND":
        return 1
    if name == "MICROSECOND":
        return 2
    if name == "NANOSECOND":
        return 3
    if name == "DAY":
        return 0
    return 1
