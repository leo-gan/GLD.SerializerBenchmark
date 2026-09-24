from avro_json.emit import emit_json
from avro_json.parse import parse_json
from avro_json.value import (
    JSON_ARRAY,
    JSON_BOOL,
    JSON_FLOAT,
    JSON_INT,
    JSON_NULL,
    JSON_OBJECT,
    JSON_STRING,
    JsonDoc,
)
from avro_runtime.datum import AvroDatum, convert_to, encode
from avro_runtime.error import DecodeError
from avro_runtime.generic import (
    AV_ARRAY,
    AV_BOOL,
    AV_BYTES,
    AV_DOUBLE,
    AV_ENUM,
    AV_FIXED,
    AV_FLOAT,
    AV_INT,
    AV_LONG,
    AV_MAP,
    AV_NULL,
    AV_RECORD,
    AV_STRING,
    AV_UNION,
    AvroNode,
    GenericDatum,
)
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
from avro_schema.names import unqualified_name
from avro_schema.parse_avsc import parse_avsc


def decode_default(
    json_text: String, var pool: SchemaPool, type_id: Int
) raises DecodeError -> GenericDatum:
    """Default-only Avro JSON subset (union = first branch, no wrappers)."""
    var doc: JsonDoc
    try:
        doc = parse_json(json_text)
    except _:
        raise DecodeError(DecodeError.KIND_JSON, 0)
    var g = GenericDatum(pool^)
    g.root = _dec_json(g, doc, doc.root, type_id, True)
    return g^


def encode_json[T: AvroDatum](value: T) raises DecodeError -> String:
    var buf = encode(value)
    var pool: SchemaPool
    try:
        pool = parse_avsc(value.schema_json())
    except _:
        raise DecodeError(DecodeError.KIND_JSON, 0)
    var g = GenericDatum(pool^)
    g.decode(buf)
    return encode_json_generic(g)


def decode_json[T: AvroDatum](text: String) raises DecodeError -> T:
    var pool: SchemaPool
    try:
        pool = parse_avsc(T().schema_json())
    except _:
        raise DecodeError(DecodeError.KIND_JSON, 0)
    var root = pool.root
    var g = decode_json_generic(text, pool^, root)
    return convert_to[T](g)


def encode_json_generic(value: GenericDatum) raises DecodeError -> String:
    return _enc_json(value, value.root, value.pool.root)


def decode_json_generic(
    text: String, var schema: SchemaPool, root: Int
) raises DecodeError -> GenericDatum:
    var doc: JsonDoc
    try:
        doc = parse_json(text)
    except _:
        raise DecodeError(DecodeError.KIND_JSON, 0)
    var g = GenericDatum(schema^)
    g.root = _dec_json(g, doc, doc.root, root, False)
    return g^


def _enc_json(g: GenericDatum, nid: Int, sid: Int) raises DecodeError -> String:
    var id = g.pool.resolve(sid)
    var k = g.pool.nodes[id].kind
    if k == ST_NULL:
        return String("null")
    if k == ST_BOOL:
        if g.nodes[nid].b:
            return String("true")
        return String("false")
    if k == ST_INT or k == ST_LONG:
        return String(g.nodes[nid].i)
    if k == ST_FLOAT:
        return String(Float32(from_bits=UInt32(g.nodes[nid].i)))
    if k == ST_DOUBLE:
        return String(Float64(from_bits=UInt64(g.nodes[nid].i)))
    if k == ST_STRING:
        return _quote(g.nodes[nid].s)
    if k == ST_BYTES or k == ST_FIXED:
        return _quote(_bytes_iso(g, nid))
    if k == ST_ENUM:
        var idx = Int(g.nodes[nid].i)
        var ss = g.pool.nodes[id].symbol_start
        return _quote(g.pool.symbol[ss + idx])
    if k == ST_RECORD:
        var s = String("{")
        var fs = g.pool.nodes[id].field_start
        var fc = g.pool.nodes[id].field_count
        var i = 0
        while i < fc:
            if i > 0:
                s += ","
            s += _quote(g.pool.field_name[fs + i])
            s += ":"
            s += _enc_json(g, g.refs[g.nodes[nid].first + i], g.pool.field_type[fs + i])
            i += 1
        s += "}"
        return s
    if k == ST_ARRAY:
        var s = String("[")
        var i = 0
        var c = g.nodes[nid].count
        while i < c:
            if i > 0:
                s += ","
            s += _enc_json(
                g, g.refs[g.nodes[nid].first + i], g.pool.nodes[id].item_id
            )
            i += 1
        s += "]"
        return s
    if k == ST_MAP:
        var s = String("{")
        var i = 0
        var c = g.nodes[nid].count
        while i < c:
            if i > 0:
                s += ","
            var kid = g.refs[g.nodes[nid].first + i * 2]
            var vid = g.refs[g.nodes[nid].first + i * 2 + 1]
            s += _quote(g.nodes[kid].s)
            s += ":"
            s += _enc_json(g, vid, g.pool.nodes[id].value_id)
            i += 1
        s += "}"
        return s
    if k == ST_UNION:
        var idx = Int(g.nodes[nid].i)
        var bid = g.pool.branch_id[g.pool.nodes[id].branch_start + idx]
        if g.pool.kind_of(bid) == ST_NULL:
            return String("null")
        var key = _branch_key(g.pool, bid)
        var child = g.refs[g.nodes[nid].first]
        return "{" + _quote(key) + ":" + _enc_json(g, child, bid) + "}"
    raise DecodeError(DecodeError.KIND_JSON, 0)


def _dec_json(
    mut g: GenericDatum, doc: JsonDoc, jid: Int, sid: Int, default_mode: Bool
) raises DecodeError -> Int:
    var id = g.pool.resolve(sid)
    var k = g.pool.nodes[id].kind
    if k == ST_UNION:
        if default_mode:
            return _dec_json(
                g,
                doc,
                jid,
                g.pool.branch_id[g.pool.nodes[id].branch_start],
                True,
            )
        return _dec_union(g, doc, jid, id)
    var n = AvroNode()
    n.schema_id = id
    if k == ST_NULL:
        n.kind = AV_NULL
        return g.add_node(n)
    if k == ST_BOOL:
        n.kind = AV_BOOL
        n.b = doc.as_bool(jid)
        return g.add_node(n)
    if k == ST_INT:
        n.kind = AV_INT
        n.i = _json_int(doc, jid)
        return g.add_node(n)
    if k == ST_LONG:
        n.kind = AV_LONG
        n.i = _json_int(doc, jid)
        return g.add_node(n)
    if k == ST_FLOAT:
        n.kind = AV_FLOAT
        n.i = Int64(Float32(_json_float(doc, jid)).to_bits())
        return g.add_node(n)
    if k == ST_DOUBLE:
        n.kind = AV_DOUBLE
        n.i = Int64(Float64(_json_float(doc, jid)).to_bits())
        return g.add_node(n)
    if k == ST_STRING:
        n.kind = AV_STRING
        n.s = doc.as_string(jid)
        return g.add_node(n)
    if k == ST_BYTES or k == ST_FIXED:
        if k == ST_BYTES:
            n.kind = AV_BYTES
        else:
            n.kind = AV_FIXED
        n.i = Int64(g.store_bytes(_iso_bytes(doc.as_string(jid))))
        return g.add_node(n)
    if k == ST_ENUM:
        n.kind = AV_ENUM
        var sym = doc.as_string(jid)
        var ss = g.pool.nodes[id].symbol_start
        var sc = g.pool.nodes[id].symbol_count
        var i = 0
        while i < sc:
            if g.pool.symbol[ss + i] == sym:
                n.i = Int64(i)
                return g.add_node(n)
            i += 1
        raise DecodeError(DecodeError.KIND_BAD_ENUM, 0)
    if k == ST_RECORD:
        return _dec_record(g, doc, jid, id)
    if k == ST_ARRAY:
        n.kind = AV_ARRAY
        var first = len(g.refs)
        var c = 0
        if doc.kind(jid) == JSON_ARRAY:
            var i = 0
            while i < doc.nodes[jid].count:
                var cid = _dec_json(
                    g, doc, doc.child(jid, i), g.pool.nodes[id].item_id, default_mode
                )
                g.refs.append(cid)
                c += 1
                i += 1
        n.first = first
        n.count = c
        return g.add_node(n)
    if k == ST_MAP:
        n.kind = AV_MAP
        var first = len(g.refs)
        var c = 0
        if doc.kind(jid) == JSON_OBJECT:
            var i = 0
            while i < doc.nodes[jid].count:
                var kn = AvroNode()
                kn.kind = AV_STRING
                kn.s = doc.obj_key(jid, i)
                var kid = g.add_node(kn)
                var vid = _dec_json(
                    g, doc, doc.obj_val(jid, i), g.pool.nodes[id].value_id, default_mode
                )
                g.refs.append(kid)
                g.refs.append(vid)
                c += 1
                i += 1
        n.first = first
        n.count = c
        return g.add_node(n)
    n.kind = AV_NULL
    return g.add_node(n)


def _dec_record(
    mut g: GenericDatum, doc: JsonDoc, jid: Int, rid: Int
) raises DecodeError -> Int:
    var n = AvroNode()
    n.kind = AV_RECORD
    n.schema_id = rid
    var first = len(g.refs)
    var fs = g.pool.nodes[rid].field_start
    var fc = g.pool.nodes[rid].field_count
    var i = 0
    while i < fc:
        var fname = g.pool.field_name[fs + i]
        var ftid = g.pool.field_type[fs + i]
        var jv = doc.find(jid, fname)
        var cid: Int
        if jv >= 0:
            cid = _dec_json(g, doc, jv, ftid, False)
        elif g.pool.field_has_default[fs + i]:
            var ddoc: JsonDoc
            try:
                ddoc = parse_json(g.pool.field_default[fs + i])
            except _:
                raise DecodeError(DecodeError.KIND_JSON, 0)
            cid = _dec_json(g, ddoc, ddoc.root, ftid, True)
        else:
            raise DecodeError(DecodeError.KIND_JSON, 0)
        g.refs.append(cid)
        i += 1
    n.first = first
    n.count = fc
    return g.add_node(n)


def _dec_union(
    mut g: GenericDatum, doc: JsonDoc, jid: Int, uid: Int
) raises DecodeError -> Int:
    var n = AvroNode()
    n.kind = AV_UNION
    n.schema_id = uid
    var bs = g.pool.nodes[uid].branch_start
    var bc = g.pool.nodes[uid].branch_count
    if doc.kind(jid) == JSON_NULL:
        var i = 0
        while i < bc:
            if g.pool.kind_of(g.pool.branch_id[bs + i]) == ST_NULL:
                n.i = Int64(i)
                var child = AvroNode()
                child.kind = AV_NULL
                var cid = g.add_node(child)
                n.first = len(g.refs)
                g.refs.append(cid)
                n.count = 1
                return g.add_node(n)
            i += 1
        raise DecodeError(DecodeError.KIND_BAD_UNION, 0)
    if doc.kind(jid) != JSON_OBJECT or doc.nodes[jid].count != 1:
        raise DecodeError(DecodeError.KIND_BAD_UNION, 0)
    var key = doc.obj_key(jid, 0)
    var val = doc.obj_val(jid, 0)
    var i = 0
    while i < bc:
        var bid = g.pool.branch_id[bs + i]
        if _branch_matches(g.pool, bid, key):
            n.i = Int64(i)
            var cid = _dec_json(g, doc, val, bid, False)
            n.first = len(g.refs)
            g.refs.append(cid)
            n.count = 1
            return g.add_node(n)
        i += 1
    raise DecodeError(DecodeError.KIND_BAD_UNION, 0)


def _branch_key(pool: SchemaPool, sid: Int) -> String:
    var id = pool.resolve(sid)
    var k = pool.nodes[id].kind
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
    if k == ST_STRING:
        return String("string")
    if k == ST_ARRAY:
        return String("array")
    if k == ST_MAP:
        return String("map")
    return unqualified_name(pool.nodes[id].name)


def _branch_matches(pool: SchemaPool, sid: Int, key: String) -> Bool:
    var want = _branch_key(pool, sid)
    if want == key:
        return True
    var id = pool.resolve(sid)
    var full = pool.nodes[id].name
    return full.byte_length() > 0 and full == key


def _json_int(doc: JsonDoc, jid: Int) -> Int64:
    if doc.kind(jid) == JSON_FLOAT:
        return Int64(doc.as_float(jid))
    return doc.as_int(jid)


def _json_float(doc: JsonDoc, jid: Int) -> Float64:
    if doc.kind(jid) == JSON_INT:
        return Float64(doc.as_int(jid))
    return doc.as_float(jid)


def _quote(s: String) -> String:
    var out = String("\"")
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 34:
            out += "\\\""
        elif c == 92:
            out += "\\\\"
        elif c == 10:
            out += "\\n"
        elif c == 13:
            out += "\\r"
        elif c == 9:
            out += "\\t"
        else:
            out += s[byte=i]
        i += 1
    out += "\""
    return out


def _bytes_iso(g: GenericDatum, nid: Int) -> String:
    var bi = Int(g.nodes[nid].i)
    var start = g.bytes_start[bi]
    var n = g.bytes_len[bi]
    var out = List[Byte]()
    var i = 0
    while i < n:
        out.append(g.bytes_store[start + i])
        i += 1
    try:
        return String(from_utf8=out)
    except _:
        return String()


def _iso_bytes(s: String) -> List[Byte]:
    var out = List[Byte]()
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        out.append(b[i])
        i += 1
    return out^
