from bson_runtime.error import DecodeError
from bson_runtime.jsonparse import JK_OBJ, JK_STR, JsonDoc, parse_json
from bson_schema.model import SK_ARRAY, SK_BOOL, SK_F64, SK_I32, SK_I64, SK_REF, SK_STRING, Field, SchemaDoc, TypeDef


def _child(doc: JsonDoc, obj: Int, key: String) -> Int:
    var i = 0
    while i < len(doc.nodes[obj].keys):
        if doc.nodes[obj].keys[i] == key:
            return doc.nodes[obj].kids[i]
        i += 1
    return -1


def _ref_name(text: String) -> String:
    var prefix = "#/$defs/"
    var b = text.as_bytes()
    var p = prefix.as_bytes()
    if len(b) < len(p):
        return text
    var i = 0
    while i < len(p):
        if b[i] != p[i]:
            return text
        i += 1
    var out = String()
    while i < len(b):
        out += String(chr(Int(b[i])))
        i += 1
    return out


def _scalar(doc: JsonDoc, idx: Int) raises DecodeError -> Int:
    var typ = _child(doc, idx, "type")
    var bt = _child(doc, idx, "bsonType")
    var name = String()
    if bt >= 0:
        name = doc.nodes[bt].text
    elif typ >= 0:
        name = doc.nodes[typ].text
    if name == "boolean":
        return SK_BOOL
    if name == "int" or name == "integer":
        return SK_I32
    if name == "long":
        return SK_I64
    if name == "double" or name == "number":
        return SK_F64
    if name == "string":
        return SK_STRING
    raise DecodeError(DecodeError.KIND_SCHEMA, idx, 0)


def _field_from(doc: JsonDoc, name: String, idx: Int) raises DecodeError -> Field:
    var field = Field()
    field.name = name
    var ref_i = _child(doc, idx, "$ref")
    if ref_i >= 0:
        field.kind = SK_REF
        field.ref_name = _ref_name(doc.nodes[ref_i].text)
        return field^
    var typ = _child(doc, idx, "type")
    if typ >= 0 and doc.nodes[typ].text == "array":
        field.kind = SK_ARRAY
        var items = _child(doc, idx, "items")
        var iref = _child(doc, items, "$ref")
        if iref >= 0:
            field.elem_kind = SK_REF
            field.elem_ref = _ref_name(doc.nodes[iref].text)
        else:
            field.elem_kind = _scalar(doc, items)
        return field^
    var r2 = _child(doc, idx, "$ref")
    _ = r2
    field.kind = _scalar(doc, idx)
    return field^


def parse_schema(text: String) raises DecodeError -> SchemaDoc:
    var js = parse_json(text)
    if js.nodes[js.root].kind != JK_OBJ:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0, 0)
    var defs = _child(js, js.root, "$defs")
    if defs < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0, 1)
    var out = SchemaDoc()
    var i = 0
    while i < len(js.nodes[defs].keys):
        var td = TypeDef()
        td.name = js.nodes[defs].keys[i]
        var body = js.nodes[defs].kids[i]
        var props = _child(js, body, "properties")
        if props >= 0:
            var p = 0
            while p < len(js.nodes[props].keys):
                var field = _field_from(js, js.nodes[props].keys[p], js.nodes[props].kids[p])
                td.fields.append(field^)
                p += 1
        out.types.append(td^)
        i += 1
    return out^


def parse_schema_file(path: String) raises DecodeError -> SchemaDoc:
    var text = String()
    try:
        var f = open(path, "r")
        text = f.read()
        f.close()
    except _:
        raise DecodeError(DecodeError.KIND_SYNTAX, 0, 0)
    return parse_schema(text)
