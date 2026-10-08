from std.collections import List

from ion_runtime.doc import (
    K_BLOB,
    K_BOOL,
    K_CLOB,
    K_DECIMAL,
    K_LIST,
    K_SEXP,
    K_STRING,
    K_STRUCT,
    K_SYMBOL,
    K_TIMESTAMP,
    IonDoc,
)
from ion_runtime.error import DecodeError
from ion_wire.text import decode_text
from ion_runtime.symtab import Catalog


comptime TY_INT = 1
comptime TY_BOOL = 2
comptime TY_STRING = 3
comptime TY_FLOAT = 4
comptime TY_ION = 5
comptime TY_BYTES = 6
comptime TY_STRUCT = 7
comptime TY_LIST = 8


struct Schema:
    """Flat schema. Primitive types occupy indexes 0 through 9. Later indexes are structs and lists."""

    var type_name: List[String]
    var type_kind: List[Int]
    var type_expect: List[Int]
    var type_inner: List[Int]
    var type_ref: List[String]
    var type_closed: List[Int]
    var field_at: List[Int]
    var field_n: List[Int]
    var field_name: List[String]
    var field_type: List[Int]
    var field_req: List[Bool]
    var field_ref: List[String]

    def __init__(out self):
        self.type_name = List[String]()
        self.type_kind = List[Int]()
        self.type_expect = List[Int]()
        self.type_inner = List[Int]()
        self.type_ref = List[String]()
        self.type_closed = List[Int]()
        self.field_at = List[Int]()
        self.field_n = List[Int]()
        self.field_name = List[String]()
        self.field_type = List[Int]()
        self.field_req = List[Bool]()
        self.field_ref = List[String]()
        self._prim("int", TY_INT, 0)
        self._prim("bool", TY_BOOL, 0)
        self._prim("string", TY_STRING, 0)
        self._prim("float", TY_FLOAT, 0)
        self._prim("decimal", TY_ION, K_DECIMAL)
        self._prim("timestamp", TY_ION, K_TIMESTAMP)
        self._prim("symbol", TY_ION, K_SYMBOL)
        self._prim("blob", TY_BYTES, K_BLOB)
        self._prim("clob", TY_BYTES, K_CLOB)
        self._prim("sexp", TY_ION, K_SEXP)

    def _prim(mut self, name: String, kind: Int, expect: Int):
        self.type_name.append(name)
        self.type_kind.append(kind)
        self.type_expect.append(expect)
        self.type_inner.append(-1)
        self.type_ref.append(String())
        self.type_closed.append(0)
        self.field_at.append(0)
        self.field_n.append(0)

    def find(self, name: String) -> Int:
        var i = 0
        while i < len(self.type_name):
            if self.type_name[i] == name:
                return i
            i += 1
        return -1


def parse_schema_file(path: String) raises -> Schema:
    var f = open(path, "r")
    var data = f.read_bytes()
    f.close()
    var cat = Catalog()
    var doc = decode_text(Span(data), cat)
    return schema_from_doc(doc)


def schema_from_doc(doc: IonDoc) raises DecodeError -> Schema:
    var schema = Schema()
    if len(doc.top) == 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var first = doc.top[0]
    if _is_json(doc, first):
        _json_root(doc, schema, first, String("Document"))
    else:
        var i = 0
        while i < len(doc.top):
            _register_ion(doc, schema, doc.top[i])
            i += 1
        i = 0
        while i < len(doc.top):
            _fill_ion(doc, schema, doc.top[i])
            i += 1
    _resolve(schema)
    return schema^


def _is_json(doc: IonDoc, id: Int) -> Bool:
    if doc.nodes[id].kind != K_STRUCT:
        return False
    if doc.nodes[id].ann_n != 0:
        return False
    return _find(doc, id, "properties") >= 0 or _find(doc, id, "$defs") >= 0 or _find(doc, id, "definitions") >= 0


def _register_ion(doc: IonDoc, mut schema: Schema, id: Int) raises DecodeError:
    if doc.nodes[id].kind != K_STRUCT:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var name = _type_name(doc, id, String())
    if name.byte_length() == 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    if schema.find(name) < 0:
        _ = _alloc(schema, name, TY_STRUCT, 0, -1)


def _fill_ion(doc: IonDoc, mut schema: Schema, id: Int) raises DecodeError:
    var name = _type_name(doc, id, String())
    var idx = schema.find(name)
    if idx < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    _fill_struct(doc, schema, idx, id, name)


def _json_root(doc: IonDoc, mut schema: Schema, id: Int, fallback: String) raises DecodeError:
    var defs = _find(doc, id, "$defs")
    if defs < 0:
        defs = _find(doc, id, "definitions")
    if defs >= 0:
        var i = 0
        while i < doc.nodes[defs].nchild:
            var nm = _field_name(doc, defs, i)
            if schema.find(nm) < 0:
                _ = _alloc(schema, nm, TY_STRUCT, 0, -1)
            i += 1
        i = 0
        while i < doc.nodes[defs].nchild:
            var child = doc.child_at(defs, i)
            var nm = _field_name(doc, defs, i)
            var idx = schema.find(nm)
            _fill_struct(doc, schema, idx, child, nm)
            i += 1
    var name = _type_name(doc, id, fallback)
    var idx = schema.find(name)
    if idx < 0:
        idx = _alloc(schema, name, TY_STRUCT, 0, -1)
    _fill_struct(doc, schema, idx, id, name)


def _fill_struct(doc: IonDoc, mut schema: Schema, idx: Int, id: Int, parent: String) raises DecodeError:
    if schema.field_n[idx] != 0:
        return
    var closed = 0
    var addl = _find(doc, id, "additionalProperties")
    if addl >= 0 and doc.nodes[addl].kind == K_BOOL and doc.nodes[addl].a == 0:
        closed = 1
    var content = _find(doc, id, "content")
    if content >= 0 and _node_text(doc, content) == "closed":
        closed = 1
    schema.type_closed[idx] = closed
    var fields = _find(doc, id, "fields")
    if fields < 0:
        fields = _find(doc, id, "properties")
    var required = _find(doc, id, "required")
    var at = len(schema.field_name)
    var n = 0
    if fields >= 0 and doc.nodes[fields].kind == K_STRUCT:
        var i = 0
        while i < doc.nodes[fields].nchild:
            var fname = _field_name(doc, fields, i)
            var child = doc.child_at(fields, i)
            var req = True
            if required >= 0:
                req = _list_has(doc, required, fname)
            elif _occurs_optional(doc, child):
                req = False
            var tid = _value_type(doc, schema, parent, fname, _bare_type(doc, child))
            schema.field_name.append(fname)
            schema.field_type.append(tid)
            schema.field_req.append(req)
            if tid < 0:
                schema.field_ref.append(_ref_name(doc, child))
            else:
                schema.field_ref.append(String())
            n += 1
            i += 1
    schema.field_at[idx] = at
    schema.field_n[idx] = n


def _value_type(doc: IonDoc, mut schema: Schema, parent: String, hint: String, id: Int) raises DecodeError -> Int:
    if id < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var kind = doc.nodes[id].kind
    if kind == K_SYMBOL or kind == K_STRING:
        return _lookup(schema, _node_text(doc, id))
    if kind != K_STRUCT:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    var link = _find(doc, id, "$ref")
    if link >= 0:
        return _lookup(schema, _last(_node_text(doc, link)))
    var label = String()
    var ion_t = _find(doc, id, "ionType")
    if ion_t >= 0:
        label = _node_text(doc, ion_t)
    else:
        var ty = _find(doc, id, "type")
        if ty >= 0:
            label = _node_text(doc, ty)
    if label == "object" or label == "struct" or _find(doc, id, "properties") >= 0 or _find(doc, id, "fields") >= 0:
        var nm = _type_name(doc, id, parent + "_" + hint)
        var idx = schema.find(nm)
        if idx < 0:
            idx = _alloc(schema, nm, TY_STRUCT, 0, -1)
        _fill_struct(doc, schema, idx, id, nm)
        return idx
    if label == "array" or label == "list":
        var elem = _find(doc, id, "items")
        if elem < 0:
            elem = _find(doc, id, "element")
        if elem < 0:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var inner = _value_type(doc, schema, parent, hint + "_item", elem)
        var list_id = _alloc(schema, String(), TY_LIST, 0, inner)
        if inner < 0:
            schema.type_ref[list_id] = _ref_name(doc, elem)
        return list_id
    if label == "sexp":
        return 9
    if label.byte_length() == 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    return _lookup(schema, label)


def _lookup(schema: Schema, name: String) -> Int:
    if name == "integer":
        return 0
    if name == "boolean":
        return 1
    if name == "number":
        return 3
    return schema.find(name)


def _bare_type(doc: IonDoc, id: Int) -> Int:
    if doc.nodes[id].kind != K_STRUCT:
        return id
    if _find(doc, id, "type") >= 0 or _find(doc, id, "ionType") >= 0 or _find(doc, id, "$ref") >= 0:
        return id
    return id


def _ref_name(doc: IonDoc, id: Int) -> String:
    if doc.nodes[id].kind == K_SYMBOL or doc.nodes[id].kind == K_STRING:
        return _node_text(doc, id)
    var link = _find(doc, id, "$ref")
    if link >= 0:
        return _last(_node_text(doc, link))
    var ty = _find(doc, id, "type")
    if ty >= 0:
        return _node_text(doc, ty)
    var elem = _find(doc, id, "element")
    if elem < 0:
        elem = _find(doc, id, "items")
    if elem >= 0:
        return _ref_name(doc, elem)
    return String()


def _occurs_optional(doc: IonDoc, id: Int) -> Bool:
    if doc.nodes[id].kind != K_STRUCT:
        return False
    var occ = _find(doc, id, "occurs")
    if occ < 0:
        return False
    var text = _node_text(doc, occ)
    return text == "optional"


def _resolve(mut schema: Schema) raises DecodeError:
    var i = 0
    while i < len(schema.field_name):
        if schema.field_type[i] < 0:
            var idx = schema.find(schema.field_ref[i])
            if idx < 0:
                raise DecodeError(DecodeError.KIND_SCHEMA, 0)
            schema.field_type[i] = idx
        i += 1
    i = 0
    while i < len(schema.type_name):
        if schema.type_kind[i] == TY_LIST and schema.type_inner[i] < 0:
            var idx = schema.find(schema.type_ref[i])
            if idx < 0:
                raise DecodeError(DecodeError.KIND_SCHEMA, 0)
            schema.type_inner[i] = idx
        i += 1


def _alloc(mut schema: Schema, name: String, kind: Int, expect: Int, inner: Int) -> Int:
    schema.type_name.append(name)
    schema.type_kind.append(kind)
    schema.type_expect.append(expect)
    schema.type_inner.append(inner)
    schema.type_ref.append(String())
    schema.type_closed.append(0)
    schema.field_at.append(0)
    schema.field_n.append(0)
    return len(schema.type_name) - 1


def _type_name(doc: IonDoc, id: Int, fallback: String) -> String:
    var title = _find(doc, id, "title")
    if title >= 0:
        var text = _node_text(doc, title)
        if text.byte_length() != 0:
            return text
    var name = _find(doc, id, "name")
    if name >= 0:
        var text = _node_text(doc, name)
        if text.byte_length() != 0:
            return text
    var id_field = _find(doc, id, "$id")
    if id_field >= 0:
        return _last(_node_text(doc, id_field))
    return fallback


def _last(text: String) -> String:
    var raw = text.as_bytes()
    var start = 0
    var i = 0
    while i < len(raw):
        if Int(raw[i]) == 47:
            start = i + 1
        i += 1
    var out = List[Byte]()
    while start < len(raw):
        out.append(raw[start])
        start += 1
    return String(unsafe_from_utf8=out^)


def _find(doc: IonDoc, id: Int, name: String) -> Int:
    if id < 0 or doc.nodes[id].kind != K_STRUCT:
        return -1
    var i = 0
    while i < doc.nodes[id].nchild:
        if _field_name(doc, id, i) == name:
            return doc.child_at(id, i)
        i += 1
    return -1


def _field_name(doc: IonDoc, id: Int, index: Int) -> String:
    var sym = doc.field_at(id, index)
    if sym < 0:
        return String()
    return doc.sym_text(sym)


def _node_text(doc: IonDoc, id: Int) -> String:
    var kind = doc.nodes[id].kind
    if kind == K_STRING:
        return doc.text_at(id)
    if kind == K_SYMBOL:
        return doc.sym_text(doc.nodes[id].a)
    return String()


def _list_has(doc: IonDoc, id: Int, name: String) -> Bool:
    if doc.nodes[id].kind != K_LIST:
        return False
    var i = 0
    while i < doc.nodes[id].nchild:
        if _node_text(doc, doc.child_at(id, i)) == name:
            return True
        i += 1
    return False
