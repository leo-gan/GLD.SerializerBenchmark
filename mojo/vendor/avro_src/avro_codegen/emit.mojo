from std.collections import List

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
    SchemaError,
    SchemaPool,
)


def _type_name(pool: SchemaPool, sid: Int, cur: Int = -1) -> String:
    var id = pool.resolve(sid)
    var k = pool.nodes[id].kind
    if k == ST_BOOL:
        return String("Bool")
    if k == ST_INT:
        return String("Int32")
    if k == ST_LONG:
        return String("Int64")
    if k == ST_FLOAT:
        return String("Float32")
    if k == ST_DOUBLE:
        return String("Float64")
    if k == ST_STRING:
        return String("String")
    if k == ST_BYTES or k == ST_FIXED:
        return String("List[Byte]")
    if k == ST_RECORD:
        return _short(pool.nodes[id].name)
    if k == ST_ENUM:
        return String("Int32")
    if k == ST_ARRAY:
        var item = pool.nodes[id].item_id
        if _needs_box(pool, cur, item):
            return "List[Box[" + _type_name(pool, item, cur) + "]]"
        return "List[" + _type_name(pool, item, cur) + "]"
    if k == ST_UNION:
        return _union_mojo(pool, id, cur)
    return String("Int64")


def _short(full: String) -> String:
    var b = full.as_bytes()
    var last = 0
    var i = 0
    while i < len(b):
        if Int(b[i]) == 46:
            last = i + 1
        i += 1
    var out = List[Byte]()
    while last < len(b):
        out.append(b[last])
        last += 1
    try:
        return String(from_utf8=out)
    except _:
        return full


def _is_nullable(pool: SchemaPool, sid: Int) -> Bool:
    var id = pool.resolve(sid)
    if pool.nodes[id].kind != ST_UNION:
        return False
    if pool.nodes[id].branch_count != 2:
        return False
    var a = pool.kind_of(pool.branch_id[pool.nodes[id].branch_start])
    var b = pool.kind_of(pool.branch_id[pool.nodes[id].branch_start + 1])
    return a == ST_NULL or b == ST_NULL


def _nullable_inner(pool: SchemaPool, sid: Int) -> Int:
    var id = pool.resolve(sid)
    var bs = pool.nodes[id].branch_start
    if pool.kind_of(pool.branch_id[bs]) == ST_NULL:
        return pool.branch_id[bs + 1]
    return pool.branch_id[bs]


def _needs_box(pool: SchemaPool, cur: Int, sid: Int) -> Bool:
    var inner = pool.resolve(sid)
    return pool.nodes[inner].kind == ST_RECORD and cur >= 0 and _same_scc(pool, cur, inner)


def _named_record_id(pool: SchemaPool, sid: Int) -> Int:
    var id = pool.resolve(sid)
    if pool.nodes[id].kind == ST_RECORD:
        return id
    return -1


def _reaches(pool: SchemaPool, src: Int, dst: Int, mut seen: List[Int]) -> Bool:
    if src == dst:
        return True
    var i = 0
    while i < len(seen):
        if seen[i] == src:
            return False
        i += 1
    seen.append(src)
    var fs = pool.nodes[src].field_start
    var fc = pool.nodes[src].field_count
    var f = 0
    while f < fc:
        if _walk_reach(pool, pool.field_type[fs + f], dst, seen):
            return True
        f += 1
    return False


def _walk_reach(pool: SchemaPool, sid: Int, dst: Int, mut seen: List[Int]) -> Bool:
    var id = pool.resolve(sid)
    var k = pool.nodes[id].kind
    if k == ST_RECORD:
        return _reaches(pool, id, dst, seen)
    if k == ST_UNION:
        var i = 0
        var bs = pool.nodes[id].branch_start
        while i < pool.nodes[id].branch_count:
            if _walk_reach(pool, pool.branch_id[bs + i], dst, seen):
                return True
            i += 1
        return False
    if k == ST_ARRAY:
        return _walk_reach(pool, pool.nodes[id].item_id, dst, seen)
    if k == ST_MAP:
        return _walk_reach(pool, pool.nodes[id].value_id, dst, seen)
    return False


def _same_scc(pool: SchemaPool, a: Int, b: Int) -> Bool:
    var s1 = List[Int]()
    var s2 = List[Int]()
    return _reaches(pool, a, b, s1) and _reaches(pool, b, a, s2)


def _union_mojo(pool: SchemaPool, uid: Int, cur: Int) -> String:
    if _is_nullable(pool, uid):
        var bs = pool.nodes[uid].branch_start
        var i = 0
        while i < 2:
            var bid = pool.branch_id[bs + i]
            if pool.kind_of(bid) != ST_NULL:
                var inner = pool.resolve(bid)
                var tn = _type_name(pool, bid, cur)
                if pool.nodes[inner].kind == ST_RECORD and _same_scc(pool, cur, inner):
                    return "Optional[Box[" + tn + "]]"
                return "Optional[" + tn + "]"
            i += 1
    return _tagged_type_name(pool, cur, uid)


def _is_tagged_union(pool: SchemaPool, sid: Int) -> Bool:
    var id = pool.resolve(sid)
    return pool.nodes[id].kind == ST_UNION and not _is_nullable(pool, id)


def _tagged_type_name(pool: SchemaPool, cur: Int, uid: Int) -> String:
    if cur < 0:
        return String("Int64")
    return _short(pool.nodes[cur].name) + "U" + String(uid)


def _first_non_rec_branch(pool: SchemaPool, cur: Int, uid: Int) -> Int:
    var bs = pool.nodes[uid].branch_start
    var i = 0
    while i < pool.nodes[uid].branch_count:
        var bid = pool.branch_id[bs + i]
        var inner = pool.resolve(bid)
        if not (
            pool.nodes[inner].kind == ST_RECORD and cur >= 0 and _same_scc(pool, cur, inner)
        ):
            return i
        i += 1
    return -1


def _branch_field(pool: SchemaPool, bid: Int) -> String:
    var id = pool.resolve(bid)
    var k = pool.nodes[id].kind
    if k == ST_RECORD:
        return "as_" + _short(pool.nodes[id].name)
    if k == ST_STRING:
        return String("as_string")
    if k == ST_INT:
        return String("as_int")
    if k == ST_LONG:
        return String("as_long")
    if k == ST_BOOL:
        return String("as_bool")
    return "as_b" + String(id)


def _zero(pool: SchemaPool, sid: Int) -> String:
    var k = pool.kind_of(sid)
    if _is_nullable(pool, sid):
        return String("None")
    if k == ST_BOOL:
        return String("False")
    if k == ST_INT or k == ST_ENUM:
        return String("Int32(0)")
    if k == ST_LONG:
        return String("Int64(0)")
    if k == ST_FLOAT:
        return String("Float32(0)")
    if k == ST_DOUBLE:
        return String("0.0")
    if k == ST_STRING:
        return String("String()")
    if k == ST_BYTES or k == ST_FIXED or k == ST_ARRAY or k == ST_MAP:
        return String("List[Byte]()") if (k == ST_BYTES or k == ST_FIXED) else String("List[]()")
    if k == ST_RECORD:
        return _type_name(pool, sid) + "()"
    if _is_tagged_union(pool, sid):
        return _type_name(pool, sid) + "()"
    return String("0")


def _enc_stmt(pool: SchemaPool, sid: Int, expr: String, cur: Int = -1) -> String:
    var k = pool.kind_of(sid)
    if k == ST_BOOL:
        return "        enc.write_bool(" + expr + ")\n"
    if k == ST_INT or k == ST_ENUM:
        return "        enc.write_int(" + expr + ")\n"
    if k == ST_LONG:
        return "        enc.write_long(" + expr + ")\n"
    if k == ST_FLOAT:
        return "        enc.write_float(" + expr + ")\n"
    if k == ST_DOUBLE:
        return "        enc.write_double(" + expr + ")\n"
    if k == ST_STRING:
        return "        enc.write_string(" + expr + ")\n"
    if k == ST_BYTES:
        return "        enc.write_bytes(" + expr + ")\n"
    if k == ST_RECORD:
        return "        " + expr + ".encode_to(enc)\n"
    if _is_tagged_union(pool, sid):
        return "        " + expr + ".encode_to(enc)\n"
    if _is_nullable(pool, sid):
        var bs = pool.nodes[pool.resolve(sid)].branch_start
        var null_first = pool.kind_of(pool.branch_id[bs]) == ST_NULL
        var inner = pool.branch_id[bs + 1] if null_first else pool.branch_id[bs]
        var some_idx = "1" if null_first else "0"
        var none_idx = "0" if null_first else "1"
        var inner_expr = expr + ".value()"
        if _needs_box(pool, cur, inner):
            inner_expr = expr + ".value()[]"
        var s = String("        if ") + expr + ":\n"
        s += "            enc.write_long(" + some_idx + ")\n"
        s += _enc_stmt(pool, inner, inner_expr, cur)
        s += "        else:\n"
        s += "            enc.write_long(" + none_idx + ")\n"
        return s
    if k == ST_ARRAY:
        var item = pool.nodes[pool.resolve(sid)].item_id
        var s = String("        enc.write_block_start(Int64(len(") + expr + ")))\n"
        s += "        for _it in " + expr + ":\n"
        s += "    " + _enc_stmt(pool, item, "_it", cur)
        s += "        enc.write_block_end()\n"
        return s
    return "        # unsupported field\n"


def _dec_stmt(pool: SchemaPool, sid: Int, lhs: String, cur: Int = -1) -> String:
    var k = pool.kind_of(sid)
    if k == ST_BOOL:
        return "        " + lhs + " = dec.read_bool()\n"
    if k == ST_INT or k == ST_ENUM:
        return "        " + lhs + " = dec.read_int()\n"
    if k == ST_LONG:
        return "        " + lhs + " = dec.read_long()\n"
    if k == ST_FLOAT:
        return "        " + lhs + " = dec.read_float()\n"
    if k == ST_DOUBLE:
        return "        " + lhs + " = dec.read_double()\n"
    if k == ST_STRING:
        return "        " + lhs + " = dec.read_string()\n"
    if k == ST_BYTES:
        return "        " + lhs + " = dec.read_bytes()\n"
    if k == ST_RECORD:
        return (
            "        "
            + lhs
            + " = "
            + _type_name(pool, sid)
            + "()\n        "
            + lhs
            + ".decode_from(dec)\n"
        )
    if _is_tagged_union(pool, sid):
        return (
            "        "
            + lhs
            + " = "
            + _type_name(pool, sid, cur)
            + "()\n        "
            + lhs
            + ".decode_from(dec)\n"
        )
    if _is_nullable(pool, sid):
        var bs = pool.nodes[pool.resolve(sid)].branch_start
        var null_first = pool.kind_of(pool.branch_id[bs]) == ST_NULL
        var inner = pool.branch_id[bs + 1] if null_first else pool.branch_id[bs]
        var some_idx = "1" if null_first else "0"
        var s = String("        var _br = dec.read_long()\n")
        s += "        if _br == " + some_idx + ":\n"
        s += "            var _tmp = " + _type_name(pool, inner) + "()\n"
        if pool.kind_of(inner) == ST_RECORD:
            s += "            _tmp.decode_from(dec)\n"
            if _needs_box(pool, cur, inner):
                s += "            " + lhs + " = Box(_tmp)\n"
            else:
                s += "            " + lhs + " = _tmp\n"
        else:
            s += "    " + _dec_stmt(pool, inner, lhs, cur)
        s += "        else:\n"
        s += "            " + lhs + " = None\n"
        return s
    if k == ST_ARRAY:
        var s = String("        ") + lhs + " = List[]()\n"
        s += "        while True:\n"
        s += "            var _c, _h = dec.read_block_count()\n"
        s += "            if _c == 0:\n"
        s += "                break\n"
        return s
    return "        # unsupported decode\n"


def emit_tagged_union(pool: SchemaPool, rid: Int, uid: Int) raises SchemaError -> String:
    var tname = _tagged_type_name(pool, rid, uid)
    var first = _first_non_rec_branch(pool, rid, uid)
    if first < 0:
        raise SchemaError("tagged union every branch is recursive")
    var s = String("struct ") + tname + "(Copyable, Movable, Defaultable, Deinitable):\n"
    s += "    var branch: Int64\n"
    var bs = pool.nodes[uid].branch_start
    var bc = pool.nodes[uid].branch_count
    var i = 0
    while i < bc:
        var bid = pool.branch_id[bs + i]
        var inner = pool.resolve(bid)
        var fname = _branch_field(pool, bid)
        if pool.nodes[inner].kind == ST_RECORD and _same_scc(pool, rid, inner):
            s += "    var " + fname + ": Optional[Box[" + _short(pool.nodes[inner].name) + "]]\n"
        else:
            s += "    var " + fname + ": " + _type_name(pool, bid, rid) + "\n"
        i += 1
    s += "\n    def __init__(out self):\n"
    s += "        self.branch = Int64(" + String(first) + ")\n"
    i = 0
    while i < bc:
        var bid = pool.branch_id[bs + i]
        var inner = pool.resolve(bid)
        var fname = _branch_field(pool, bid)
        if pool.nodes[inner].kind == ST_RECORD and _same_scc(pool, rid, inner):
            s += "        self." + fname + " = None\n"
        else:
            s += "        self." + fname + " = " + _zero(pool, bid) + "\n"
        i += 1
    s += "\n    def encode_to(self, mut enc: WireWriter):\n"
    s += "        enc.write_long(self.branch)\n"
    i = 0
    while i < bc:
        var bid = pool.branch_id[bs + i]
        var inner = pool.resolve(bid)
        var fname = _branch_field(pool, bid)
        s += "        if self.branch == Int64(" + String(i) + "):\n"
        if pool.nodes[inner].kind == ST_RECORD and _same_scc(pool, rid, inner):
            s += "            self." + fname + ".value()[].encode_to(enc)\n"
        elif pool.nodes[inner].kind == ST_RECORD:
            s += "            self." + fname + ".encode_to(enc)\n"
        else:
            s += "    " + _enc_stmt(pool, bid, "self." + fname, rid)
        i += 1
    s += "\n    def decode_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:\n"
    s += "        self.branch = dec.read_long()\n"
    i = 0
    while i < bc:
        var bid = pool.branch_id[bs + i]
        var inner = pool.resolve(bid)
        var fname = _branch_field(pool, bid)
        s += "        if self.branch == Int64(" + String(i) + "):\n"
        if pool.nodes[inner].kind == ST_RECORD:
            s += "            var _tmp = " + _short(pool.nodes[inner].name) + "()\n"
            s += "            _tmp.decode_from(dec)\n"
            if _same_scc(pool, rid, inner):
                s += "            self." + fname + " = Box(_tmp)\n"
            else:
                s += "            self." + fname + " = _tmp\n"
        else:
            s += "    " + _dec_stmt(pool, bid, "self." + fname, rid)
        i += 1
    s += "\n\n"
    return s


def emit_one_record(pool: SchemaPool, rid: Int) raises SchemaError -> String:
    var name = _short(pool.nodes[rid].name)
    var fs = pool.nodes[rid].field_start
    var fc = pool.nodes[rid].field_count
    var i = 0
    while i < fc:
        var ftid = pool.field_type[fs + i]
        if (
            pool.kind_of(ftid) == ST_RECORD
            and _same_scc(pool, rid, pool.resolve(ftid))
        ):
            raise SchemaError("non-optional recursive field " + pool.field_name[fs + i])
        i += 1
    var extras = String()
    i = 0
    while i < fc:
        var ftid = pool.field_type[fs + i]
        if _is_tagged_union(pool, ftid):
            extras += emit_tagged_union(pool, rid, pool.resolve(ftid))
        i += 1
    var s = String("from std.collections import List, Optional, Span\n")
    s += "from avro import AvroDatum, Box, DecodeError, WireReader, WireWriter\n\n\n"
    s += extras
    s += "struct " + name + "(Copyable, Movable, Defaultable, Deinitable, AvroDatum):\n"
    i = 0
    while i < fc:
        s += "    var " + pool.field_name[fs + i] + ": " + _type_name(pool, pool.field_type[fs + i], rid) + "\n"
        i += 1
    s += "\n    def __init__(out self):\n"
    i = 0
    while i < fc:
        var z = _zero(pool, pool.field_type[fs + i])
        if _is_tagged_union(pool, pool.field_type[fs + i]):
            z = _type_name(pool, pool.field_type[fs + i], rid) + "()"
        s += "        self." + pool.field_name[fs + i] + " = " + z + "\n"
        i += 1
    if fc > 0:
        s += "\n    def __init__(out self"
        i = 0
        while i < fc:
            s += ", " + pool.field_name[fs + i] + ": " + _type_name(pool, pool.field_type[fs + i], rid)
            i += 1
        s += "):\n"
        i = 0
        while i < fc:
            s += "        self." + pool.field_name[fs + i] + " = " + pool.field_name[fs + i] + "\n"
            i += 1
    s += "\n    def schema_json(self) -> String:\n"
    s += "        return String(" + _quote(pool.original_json) + ")\n\n"
    s += "    def encoded_len(self) -> Int:\n        return 64\n\n"
    s += "    def encode_to(self, mut enc: WireWriter):\n"
    i = 0
    while i < fc:
        s += _enc_stmt(pool, pool.field_type[fs + i], "self." + pool.field_name[fs + i], rid)
        i += 1
    s += "\n    def decode_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:\n"
    i = 0
    while i < fc:
        s += _dec_stmt(pool, pool.field_type[fs + i], "self." + pool.field_name[fs + i], rid)
        i += 1
    return s


def _quote(s: String) -> String:
    return "\"\"\"" + s + "\"\"\""


def emit_records(pool: SchemaPool, out_dir: String) raises SchemaError -> List[String]:
    var files = List[String]()
    var i = 0
    while i < len(pool.nodes):
        if pool.nodes[i].kind == ST_RECORD:
            var name = _short(pool.nodes[i].name)
            var path = out_dir + "/" + name + ".mojo"
            files.append(path)
            files.append(emit_one_record(pool, i))
        i += 1
    return files^
