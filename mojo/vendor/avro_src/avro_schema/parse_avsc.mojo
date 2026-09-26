from std.collections import List

from avro_json.emit import emit_json
from avro_json.parse import parse_json
from avro_json.value import (
    JSON_ARRAY,
    JSON_OBJECT,
    JSON_STRING,
    JsonDoc,
)
from avro_schema.names import fullname_of, namespace_of, unqualified_name, valid_unqualified_name
from avro_schema.model import (
    ST_ARRAY,
    ST_BOOL,
    ST_BYTES,
    ST_DOUBLE,
    ST_ENUM,
    ST_FIXED,
    ST_FLOAT,
    ST_INT,
    ST_LONG,
    ST_MAP,
    ST_NULL,
    ST_RECORD,
    ST_REF,
    ST_STRING,
    ST_UNION,
    SchemaError,
    SchemaNode,
    SchemaPool,
)


def _prim_kind(name: String) -> Int:
    if name == "null":
        return ST_NULL
    if name == "boolean":
        return ST_BOOL
    if name == "int":
        return ST_INT
    if name == "long":
        return ST_LONG
    if name == "float":
        return ST_FLOAT
    if name == "double":
        return ST_DOUBLE
    if name == "bytes":
        return ST_BYTES
    if name == "string":
        return ST_STRING
    return -1


def parse_schema(
    mut pool: SchemaPool, doc: JsonDoc, id: Int, ns: String
) raises SchemaError -> Int:
    var k = doc.kind(id)
    if k == JSON_STRING:
        return _named(pool, doc.as_string(id), ns)
    if k == JSON_ARRAY:
        return _union(pool, doc, id, ns)
    if k == JSON_OBJECT:
        return _object(pool, doc, id, ns)
    raise SchemaError("schema must be string, array, or object")


def _named(mut pool: SchemaPool, name: String, ns: String) raises SchemaError -> Int:
    var pk = _prim_kind(name)
    if pk >= 0:
        var n = SchemaNode()
        n.kind = pk
        return pool.add(n)
    var full = fullname_of(name, ns)
    var existing = pool.find_name(full)
    if existing < 0:
        existing = pool.find_name(name)
    if existing < 0:
        var stub = SchemaNode()
        stub.kind = ST_RECORD
        stub.name = full
        stub.namespace = namespace_of(full)
        existing = pool.add(stub)
    var r = SchemaNode()
    r.kind = ST_REF
    r.ref_id = existing
    return pool.add(r)


def _union(
    mut pool: SchemaPool, doc: JsonDoc, id: Int, ns: String
) raises SchemaError -> Int:
    var n = doc.nodes[id].count
    if n == 0:
        raise SchemaError("empty union")
    var node = SchemaNode()
    node.kind = ST_UNION
    var uid = pool.add(node)
    var seen_prim = List[Int]()
    var i = 0
    while i < n:
        var bid = parse_schema(pool, doc, doc.child(id, i), ns)
        var bk = pool.kind_of(bid)
        if bk == ST_UNION:
            raise SchemaError("nested union")
        if bk != ST_RECORD and bk != ST_ENUM and bk != ST_FIXED and bk != ST_REF:
            var s = 0
            while s < len(seen_prim):
                if seen_prim[s] == bk:
                    raise SchemaError("duplicate union branch kind")
                s += 1
            seen_prim.append(bk)
        pool.add_branch(uid, bid)
        i += 1
    return uid


def _decl_ns(doc: JsonDoc, id: Int, outer: String) -> String:
    var n = doc.find(id, String("namespace"))
    if n >= 0 and doc.kind(n) == JSON_STRING:
        return doc.as_string(n)
    return outer


def _known_object_key(tname: String, key: String) -> Bool:
    if (
        key == "type"
        or key == "logicalType"
        or key == "doc"
        or key == "aliases"
        or key == "namespace"
        or key == "name"
    ):
        return True
    if tname == "record" or tname == "error":
        return key == "fields" or key == "order" or key == "default"
    if tname == "enum":
        return key == "symbols" or key == "default"
    if tname == "fixed":
        return key == "size"
    if tname == "array":
        return key == "items"
    if tname == "map":
        return key == "values"
    return False


def _apply_logical_and_leftovers(
    mut pool: SchemaPool, doc: JsonDoc, obj: Int, nid: Int, tname: String
):
    var lt = doc.find(obj, String("logicalType"))
    if lt >= 0 and doc.kind(lt) == JSON_STRING:
        pool.nodes[nid].logical_type = doc.as_string(lt)
    if doc.kind(obj) != JSON_OBJECT:
        return
    var n = doc.nodes[obj].count
    var i = 0
    while i < n:
        var key = doc.obj_key(obj, i)
        if not _known_object_key(tname, key):
            pool.add_leftover(nid, key, emit_json(doc, doc.obj_val(obj, i)))
        i += 1


def _object(
    mut pool: SchemaPool, doc: JsonDoc, id: Int, ns: String
) raises SchemaError -> Int:
    var type_id = doc.find(id, String("type"))
    if type_id < 0:
        raise SchemaError("object schema missing type")
    var tk = doc.kind(type_id)
    if tk == JSON_ARRAY or tk == JSON_OBJECT:
        return parse_schema(pool, doc, type_id, ns)
    if tk != JSON_STRING:
        raise SchemaError("type must be string, array, or object")
    var tname = doc.as_string(type_id)
    var pk = _prim_kind(tname)
    if pk >= 0:
        var n = SchemaNode()
        n.kind = pk
        var nid = pool.add(n)
        _apply_logical_and_leftovers(pool, doc, id, nid, tname)
        return nid
    if tname == "record" or tname == "error":
        var rid = _record(pool, doc, id, ns)
        if tname == "error":
            pool.nodes[rid].is_error = True
        _apply_logical_and_leftovers(pool, doc, id, rid, tname)
        return rid
    if tname == "enum":
        var eid = _enum(pool, doc, id, ns)
        _apply_logical_and_leftovers(pool, doc, id, eid, tname)
        return eid
    if tname == "array":
        var aid = _array(pool, doc, id, ns)
        _apply_logical_and_leftovers(pool, doc, id, aid, tname)
        return aid
    if tname == "map":
        var mid = _map(pool, doc, id, ns)
        _apply_logical_and_leftovers(pool, doc, id, mid, tname)
        return mid
    if tname == "fixed":
        var fid = _fixed(pool, doc, id, ns)
        _apply_logical_and_leftovers(pool, doc, id, fid, tname)
        return fid
    return _named(pool, tname, ns)


def _record(
    mut pool: SchemaPool, doc: JsonDoc, id: Int, ns: String
) raises SchemaError -> Int:
    var name_id = doc.find(id, String("name"))
    if name_id < 0:
        raise SchemaError("record missing name")
    var raw = doc.as_string(name_id)
    if not valid_unqualified_name(unqualified_name(raw)):
        raise SchemaError("illegal record name")
    var dns = _decl_ns(doc, id, ns)
    var full = fullname_of(raw, dns)
    var node = SchemaNode()
    node.kind = ST_RECORD
    node.name = full
    node.namespace = namespace_of(full)
    var rec_ns = node.namespace
    var existing = pool.find_name(full)
    var self_id: Int
    if existing >= 0:
        self_id = existing
        pool.nodes[self_id].kind = ST_RECORD
        pool.nodes[self_id].name = full
        pool.nodes[self_id].namespace = rec_ns
    else:
        self_id = pool.add(node)
    var al = doc.find(id, String("aliases"))
    if al >= 0 and doc.kind(al) == JSON_ARRAY:
        var ai = 0
        while ai < doc.nodes[al].count:
            pool.add_alias(self_id, doc.as_string(doc.child(al, ai)))
            ai += 1
    var fields_id = doc.find(id, String("fields"))
    if fields_id < 0 or doc.kind(fields_id) != JSON_ARRAY:
        raise SchemaError("record missing fields")
    var i = 0
    var n = doc.nodes[fields_id].count
    while i < n:
        var fid = doc.child(fields_id, i)
        var fname_id = doc.find(fid, String("name"))
        if fname_id < 0:
            raise SchemaError("field missing name")
        var fname = doc.as_string(fname_id)
        var ft = doc.find(fid, String("type"))
        if ft < 0:
            raise SchemaError("field missing type")
        var ftid = parse_schema(pool, doc, ft, rec_ns)
        var has_def = False
        var defj = String()
        var def_id = doc.find(fid, String("default"))
        if def_id >= 0:
            has_def = True
            defj = emit_json(doc, def_id)
            if pool.kind_of(ftid) == ST_UNION:
                var u = pool.resolve(ftid)
                var b0 = pool.kind_of(
                    pool.branch_id[pool.nodes[u].branch_start]
                )
                if b0 == ST_NULL and defj != "null":
                    raise SchemaError("union default must match first branch")
                if b0 == ST_STRING and (
                    defj.byte_length() == 0 or defj.as_bytes()[0] != Byte(34)
                ):
                    raise SchemaError("union default must match first branch")
        pool.add_field(self_id, fname, ftid, has_def, defj)
        i += 1
    return self_id


def _enum(
    mut pool: SchemaPool, doc: JsonDoc, id: Int, ns: String
) raises SchemaError -> Int:
    var name_id = doc.find(id, String("name"))
    if name_id < 0:
        raise SchemaError("enum missing name")
    var raw = doc.as_string(name_id)
    if not valid_unqualified_name(unqualified_name(raw)):
        raise SchemaError("illegal enum name")
    var dns = _decl_ns(doc, id, ns)
    var node = SchemaNode()
    node.kind = ST_ENUM
    node.name = fullname_of(raw, dns)
    node.namespace = namespace_of(node.name)
    var eid = pool.add(node)
    var syms = doc.find(id, String("symbols"))
    if syms < 0 or doc.kind(syms) != JSON_ARRAY:
        raise SchemaError("enum missing symbols")
    var i = 0
    var n = doc.nodes[syms].count
    while i < n:
        pool.add_symbol(eid, doc.as_string(doc.child(syms, i)))
        i += 1
    var ed = doc.find(id, String("default"))
    if ed >= 0:
        pool.nodes[eid].enum_default = doc.as_string(ed)
    return eid


def _array(
    mut pool: SchemaPool, doc: JsonDoc, id: Int, ns: String
) raises SchemaError -> Int:
    var items = doc.find(id, String("items"))
    if items < 0:
        raise SchemaError("array missing items")
    var node = SchemaNode()
    node.kind = ST_ARRAY
    node.item_id = parse_schema(pool, doc, items, ns)
    return pool.add(node)


def _map(
    mut pool: SchemaPool, doc: JsonDoc, id: Int, ns: String
) raises SchemaError -> Int:
    var values = doc.find(id, String("values"))
    if values < 0:
        raise SchemaError("map missing values")
    var node = SchemaNode()
    node.kind = ST_MAP
    node.value_id = parse_schema(pool, doc, values, ns)
    return pool.add(node)


def _fixed(
    mut pool: SchemaPool, doc: JsonDoc, id: Int, ns: String
) raises SchemaError -> Int:
    var name_id = doc.find(id, String("name"))
    var size_id = doc.find(id, String("size"))
    if name_id < 0 or size_id < 0:
        raise SchemaError("fixed missing name or size")
    var raw = doc.as_string(name_id)
    if not valid_unqualified_name(unqualified_name(raw)):
        raise SchemaError("illegal fixed name")
    var dns = _decl_ns(doc, id, ns)
    var node = SchemaNode()
    node.kind = ST_FIXED
    node.name = fullname_of(raw, dns)
    node.namespace = namespace_of(node.name)
    node.size = Int(doc.as_int(size_id))
    return pool.add(node)


def parse_avsc(text: String) raises SchemaError -> SchemaPool:
    var doc: JsonDoc
    try:
        doc = parse_json(text)
    except _:
        raise SchemaError("invalid JSON schema")
    var pool = SchemaPool()
    pool.original_json = text
    if doc.kind(doc.root) == JSON_ARRAY:
        var n = doc.nodes[doc.root].count
        if n == 0:
            raise SchemaError("empty schema array")
        if _array_is_decls(doc, doc.root):
            var i = 0
            var first = -1
            while i < n:
                var sid = parse_schema(pool, doc, doc.child(doc.root, i), String())
                if first < 0:
                    first = sid
                i += 1
            pool.root = first
        else:
            pool.root = parse_schema(pool, doc, doc.root, String())
    else:
        pool.root = parse_schema(pool, doc, doc.root, String())
    return pool^


def _array_is_decls(doc: JsonDoc, id: Int) -> Bool:
    """True when the array is a list of named type declarations, not a union."""
    var n = doc.nodes[id].count
    if n == 0:
        return False
    var i = 0
    while i < n:
        var c = doc.child(id, i)
        if doc.kind(c) != JSON_OBJECT:
            return False
        var t = doc.find(c, String("type"))
        if t < 0 or doc.kind(t) != JSON_STRING:
            return False
        var tn = doc.as_string(t)
        if tn != "record" and tn != "enum" and tn != "fixed" and tn != "error":
            return False
        i += 1
    return True
