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
    ST_STRING,
    ST_UNION,
    SchemaPool,
)


def _prim(k: Int) -> String:
    if k == ST_NULL:
        return String("null")
    if k == ST_BOOL:
        return String("boolean")
    if k == ST_INT:
        return String("int")
    if k == ST_LONG:
        return String("long")
    if k == ST_FLOAT:
        return String("float")
    if k == ST_DOUBLE:
        return String("double")
    if k == ST_BYTES:
        return String("bytes")
    return String("string")


def canonical_form(pool: SchemaPool) -> String:
    """Parsing Canonical Form. First visit of a named type is the object; later visits are the fullname."""
    var seen = List[Int]()
    return _cf(pool, pool.root, seen)


def _seen(seen: List[Int], id: Int) -> Bool:
    var i = 0
    while i < len(seen):
        if seen[i] == id:
            return True
        i += 1
    return False


def _cf(pool: SchemaPool, sid: Int, mut seen: List[Int]) -> String:
    var id = pool.resolve(sid)
    var k = pool.nodes[id].kind
    if k == ST_NULL or k == ST_BOOL or k == ST_INT or k == ST_LONG or k == ST_FLOAT or k == ST_DOUBLE or k == ST_BYTES or k == ST_STRING:
        return _prim(k)
    if k == ST_UNION:
        var s = String("[")
        var i = 0
        var bs = pool.nodes[id].branch_start
        while i < pool.nodes[id].branch_count:
            if i > 0:
                s += ","
            s += _cf(pool, pool.branch_id[bs + i], seen)
            i += 1
        s += "]"
        return s
    if k == ST_ARRAY:
        return '{"type":"array","items":' + _cf(pool, pool.nodes[id].item_id, seen) + "}"
    if k == ST_MAP:
        return '{"type":"map","values":' + _cf(pool, pool.nodes[id].value_id, seen) + "}"
    if k == ST_RECORD or k == ST_ENUM or k == ST_FIXED:
        if _seen(seen, id):
            return '"' + pool.nodes[id].name + '"'
        seen.append(id)
        if k == ST_ENUM:
            var s = String('{"name":"') + pool.nodes[id].name + '","type":"enum","symbols":['
            var i = 0
            var ss = pool.nodes[id].symbol_start
            while i < pool.nodes[id].symbol_count:
                if i > 0:
                    s += ","
                s += '"' + pool.symbol[ss + i] + '"'
                i += 1
            s += "]}"
            return s
        if k == ST_FIXED:
            return (
                '{"name":"'
                + pool.nodes[id].name
                + '","type":"fixed","size":'
                + String(pool.nodes[id].size)
                + "}"
            )
        var s = String('{"name":"') + pool.nodes[id].name + '","type":"record","fields":['
        var i = 0
        var fs = pool.nodes[id].field_start
        while i < pool.nodes[id].field_count:
            if i > 0:
                s += ","
            s += '{"name":"' + pool.field_name[fs + i] + '","type":'
            s += _cf(pool, pool.field_type[fs + i], seen)
            s += "}"
            i += 1
        s += "]}"
        return s
    return String("null")
