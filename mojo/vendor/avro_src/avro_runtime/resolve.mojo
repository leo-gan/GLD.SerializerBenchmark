from std.collections import List, Span

from avro_json.parse import parse_json
from avro_json.value import JSON_BOOL, JSON_FLOAT, JSON_INT, JSON_NULL, JSON_STRING, JsonDoc
from avro_runtime.error import DecodeError
from avro_runtime.generic import (
    AV_BOOL,
    AV_BYTES,
    AV_DOUBLE,
    AV_ENUM,
    AV_FIXED,
    AV_FLOAT,
    AV_INT,
    AV_LONG,
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
from avro_wire.reader import WireReader


comptime ACT_COPY = 0
comptime ACT_PROMOTE = 1
comptime ACT_REINTERPRET = 2
comptime ACT_RECORD = 3
comptime ACT_SKIP = 4
comptime ACT_DEFAULT = 5
comptime ACT_UNION = 6


struct ResolvePlan(Movable):
    """Compiled writer→reader actions. Decode walks both schemas with this plan."""

    var valid: Bool
    var actions: List[Int]
    var writer_ids: List[Int]
    var reader_ids: List[Int]

    def __init__(out self):
        self.valid = False
        self.actions = List[Int]()
        self.writer_ids = List[Int]()
        self.reader_ids = List[Int]()

    def __init__(out self, valid: Bool):
        self.valid = valid
        self.actions = List[Int]()
        self.writer_ids = List[Int]()
        self.reader_ids = List[Int]()

    def add(mut self, act: Int, wid: Int, rid: Int):
        self.actions.append(act)
        self.writer_ids.append(wid)
        self.reader_ids.append(rid)


def compile_plan(wpool: SchemaPool, rpool: SchemaPool) raises DecodeError -> ResolvePlan:
    if not can_resolve(wpool, wpool.root, rpool, rpool.root):
        raise DecodeError(DecodeError.KIND_RESOLVE, 0)
    var plan = ResolvePlan(True)
    _fill_plan(plan, wpool, wpool.root, rpool, rpool.root)
    return plan^


def _fill_plan(
    mut plan: ResolvePlan, wpool: SchemaPool, wid0: Int, rpool: SchemaPool, rid0: Int
):
    var w = wpool.resolve(wid0)
    var r = rpool.resolve(rid0)
    var wk = wpool.nodes[w].kind
    var rk = rpool.nodes[r].kind
    if wk == rk and (
        wk == ST_NULL
        or wk == ST_BOOL
        or wk == ST_INT
        or wk == ST_LONG
        or wk == ST_FLOAT
        or wk == ST_DOUBLE
        or wk == ST_STRING
        or wk == ST_BYTES
        or wk == ST_FIXED
        or wk == ST_ENUM
    ):
        plan.add(ACT_COPY, w, r)
        return
    if promote_ok(wk, rk) and wk != rk:
        plan.add(ACT_PROMOTE, w, r)
        return
    if (wk == ST_STRING and rk == ST_BYTES) or (wk == ST_BYTES and rk == ST_STRING):
        plan.add(ACT_REINTERPRET, w, r)
        return
    if wk == ST_RECORD and rk == ST_RECORD:
        plan.add(ACT_RECORD, w, r)
        var wfs = wpool.nodes[w].field_start
        var wfc = wpool.nodes[w].field_count
        var i = 0
        while i < wfc:
            var name = wpool.field_name[wfs + i]
            var rf = 0
            var found = -1
            var rfs = rpool.nodes[r].field_start
            while rf < rpool.nodes[r].field_count:
                if rpool.field_name[rfs + rf] == name:
                    found = rf
                    break
                rf += 1
            if found < 0:
                plan.add(ACT_SKIP, wpool.field_type[wfs + i], -1)
            else:
                _fill_plan(
                    plan,
                    wpool,
                    wpool.field_type[wfs + i],
                    rpool,
                    rpool.field_type[rfs + found],
                )
            i += 1
        return
    if wk == ST_UNION or rk == ST_UNION:
        plan.add(ACT_UNION, w, r)
        return
    plan.add(ACT_COPY, w, r)


def reader_aliases_match(
    wpool: SchemaPool, wid: Int, rpool: SchemaPool, rid: Int
) -> Bool:
    """True if reader aliases rewrite the writer name onto the reader name."""
    var w = wpool.resolve(wid)
    var r = rpool.resolve(rid)
    var wfull = wpool.nodes[w].name
    var wshort = unqualified_name(wfull)
    var i = 0
    while i < len(rpool.alias_owner):
        if rpool.alias_owner[i] == r:
            var a = rpool.alias_name[i]
            if a == wfull or a == wshort:
                return True
        i += 1
    return False


def named_match(
    wpool: SchemaPool, wid: Int, rpool: SchemaPool, rid: Int
) -> Bool:
    """Unqualified name after applying reader aliases. Writer aliases ignored."""
    var w = wpool.resolve(wid)
    var r = rpool.resolve(rid)
    if reader_aliases_match(wpool, w, rpool, r):
        return True
    return unqualified_name(wpool.nodes[w].name) == unqualified_name(
        rpool.nodes[r].name
    )


def promote_ok(wk: Int, rk: Int) -> Bool:
    if wk == rk:
        return True
    if wk == ST_INT and (rk == ST_LONG or rk == ST_FLOAT or rk == ST_DOUBLE):
        return True
    if wk == ST_LONG and (rk == ST_FLOAT or rk == ST_DOUBLE):
        return True
    if wk == ST_FLOAT and rk == ST_DOUBLE:
        return True
    if wk == ST_STRING and rk == ST_BYTES:
        return True
    if wk == ST_BYTES and rk == ST_STRING:
        return True
    return False


def can_resolve(
    wpool: SchemaPool, wid: Int, rpool: SchemaPool, rid: Int
) -> Bool:
    var w = wpool.resolve(wid)
    var r = rpool.resolve(rid)
    var wk = wpool.nodes[w].kind
    var rk = rpool.nodes[r].kind
    if wk == ST_UNION:
        var i = 0
        var bs = wpool.nodes[w].branch_start
        while i < wpool.nodes[w].branch_count:
            if can_resolve(wpool, wpool.branch_id[bs + i], rpool, r):
                return True
            i += 1
        return False
    if rk == ST_UNION:
        var i = 0
        var bs = rpool.nodes[r].branch_start
        while i < rpool.nodes[r].branch_count:
            if can_resolve(wpool, w, rpool, rpool.branch_id[bs + i]):
                return True
            i += 1
        return False
    if wk == ST_RECORD and rk == ST_RECORD:
        return named_match(wpool, w, rpool, r)
    if wk == ST_ENUM and rk == ST_ENUM:
        return named_match(wpool, w, rpool, r)
    if wk == ST_FIXED and rk == ST_FIXED:
        return named_match(wpool, w, rpool, r) and wpool.nodes[w].size == rpool.nodes[
            r
        ].size
    if wk == ST_ARRAY and rk == ST_ARRAY:
        return can_resolve(
            wpool, wpool.nodes[w].item_id, rpool, rpool.nodes[r].item_id
        )
    if wk == ST_MAP and rk == ST_MAP:
        return can_resolve(
            wpool, wpool.nodes[w].value_id, rpool, rpool.nodes[r].value_id
        )
    return promote_ok(wk, rk)


def decode_resolving_generic[
    origin: ImmOrigin
](
    buf: Span[Byte, origin],
    var writer: SchemaPool,
    var reader: SchemaPool,
) raises DecodeError -> GenericDatum:
    """Decode writer bytes into a reader-shaped GenericDatum."""
    _ = compile_plan(writer, reader)
    var dec = WireReader[origin](buf)
    var g = GenericDatum(reader^)
    g.root = _dec_res(g, dec, writer, writer.root, g.pool.root)
    return g^


def _dec_res[
    origin: ImmOrigin
](
    mut g: GenericDatum,
    mut dec: WireReader[origin],
    wpool: SchemaPool,
    wid0: Int,
    rid0: Int,
) raises DecodeError -> Int:
    var wid = wpool.resolve(wid0)
    var rid = g.pool.resolve(rid0)
    var wk = wpool.nodes[wid].kind
    var rk = g.pool.nodes[rid].kind
    if wk == ST_UNION:
        var idx = dec.read_long()
        if idx < 0 or idx >= Int64(wpool.nodes[wid].branch_count):
            raise DecodeError(DecodeError.KIND_BAD_UNION, dec.position())
        var wbranch = wpool.branch_id[wpool.nodes[wid].branch_start + Int(idx)]
        return _dec_res(g, dec, wpool, wbranch, rid)
    if rk == ST_UNION:
        var i = 0
        var bs = g.pool.nodes[rid].branch_start
        var bc = g.pool.nodes[rid].branch_count
        while i < bc:
            var bid = g.pool.branch_id[bs + i]
            if can_resolve(wpool, wid, g.pool, bid):
                var n = AvroNode()
                n.kind = AV_UNION
                n.schema_id = rid
                n.i = Int64(i)
                var cid = _dec_res(g, dec, wpool, wid, bid)
                n.first = len(g.refs)
                g.refs.append(cid)
                n.count = 1
                return g.add_node(n)
            i += 1
        raise DecodeError(DecodeError.KIND_RESOLVE, dec.position())
    if wk == ST_RECORD and rk == ST_RECORD:
        return _dec_record(g, dec, wpool, wid, rid)
    return _dec_scalar(g, dec, wpool, wid, rid)


def _dec_record[
    origin: ImmOrigin
](
    mut g: GenericDatum,
    mut dec: WireReader[origin],
    wpool: SchemaPool,
    wid: Int,
    rid: Int,
) raises DecodeError -> Int:
    var wfs = wpool.nodes[wid].field_start
    var wfc = wpool.nodes[wid].field_count
    var rfs = g.pool.nodes[rid].field_start
    var rfc = g.pool.nodes[rid].field_count
    var got = List[Int]()
    var i = 0
    while i < rfc:
        got.append(-1)
        i += 1
    var wf = 0
    while wf < wfc:
        var wname = wpool.field_name[wfs + wf]
        var wty = wpool.field_type[wfs + wf]
        var rf = _find_field(g.pool, rfs, rfc, wname)
        if rf < 0:
            _skip_value(dec, wpool, wty)
        else:
            got[rf] = _dec_res(g, dec, wpool, wty, g.pool.field_type[rfs + rf])
        wf += 1
    var n = AvroNode()
    n.kind = AV_RECORD
    n.schema_id = rid
    var first = len(g.refs)
    i = 0
    while i < rfc:
        if got[i] >= 0:
            g.refs.append(got[i])
        elif g.pool.field_has_default[rfs + i]:
            var defj = String(g.pool.field_default[rfs + i])
            var ftid = g.pool.field_type[rfs + i]
            g.refs.append(_default_node(g, defj, ftid))
        else:
            raise DecodeError(DecodeError.KIND_RESOLVE, dec.position())
        i += 1
    n.first = first
    n.count = rfc
    return g.add_node(n)


def _find_field(pool: SchemaPool, fs: Int, fc: Int, name: String) -> Int:
    var i = 0
    while i < fc:
        if pool.field_name[fs + i] == name:
            return i
        i += 1
    return -1


def _dec_scalar[
    origin: ImmOrigin
](
    mut g: GenericDatum,
    mut dec: WireReader[origin],
    wpool: SchemaPool,
    wid: Int,
    rid: Int,
) raises DecodeError -> Int:
    var wk = wpool.nodes[wid].kind
    var rk = g.pool.nodes[rid].kind
    var n = AvroNode()
    n.schema_id = rid
    if wk == ST_NULL:
        n.kind = AV_NULL
        return g.add_node(n)
    if wk == ST_BOOL:
        n.kind = AV_BOOL
        n.b = dec.read_bool()
        return g.add_node(n)
    if wk == ST_INT:
        var v = Int64(dec.read_int())
        if rk == ST_LONG:
            n.kind = AV_LONG
            n.i = v
        elif rk == ST_FLOAT:
            n.kind = AV_FLOAT
            n.i = Int64(Float32(v).to_bits())
        elif rk == ST_DOUBLE:
            n.kind = AV_DOUBLE
            n.i = Int64(Float64(v).to_bits())
        else:
            n.kind = AV_INT
            n.i = v
        return g.add_node(n)
    if wk == ST_LONG:
        var v = dec.read_long()
        if rk == ST_FLOAT:
            n.kind = AV_FLOAT
            n.i = Int64(Float32(v).to_bits())
        elif rk == ST_DOUBLE:
            n.kind = AV_DOUBLE
            n.i = Int64(Float64(v).to_bits())
        else:
            n.kind = AV_LONG
            n.i = v
        return g.add_node(n)
    if wk == ST_FLOAT:
        var f = dec.read_float()
        if rk == ST_DOUBLE:
            n.kind = AV_DOUBLE
            n.i = Int64(Float64(f).to_bits())
        else:
            n.kind = AV_FLOAT
            n.i = Int64(f.to_bits())
        return g.add_node(n)
    if wk == ST_DOUBLE:
        n.kind = AV_DOUBLE
        n.i = Int64(dec.read_double().to_bits())
        return g.add_node(n)
    if wk == ST_STRING:
        var s = dec.read_string()
        if rk == ST_BYTES:
            n.kind = AV_BYTES
            n.i = Int64(g.store_bytes(_str_bytes(s)))
        else:
            n.kind = AV_STRING
            n.s = s
        return g.add_node(n)
    if wk == ST_BYTES:
        var b = dec.read_bytes()
        if rk == ST_STRING:
            n.kind = AV_STRING
            n.s = _bytes_str(b)
        else:
            n.kind = AV_BYTES
            n.i = Int64(g.store_bytes(b))
        return g.add_node(n)
    if wk == ST_FIXED:
        n.kind = AV_FIXED
        n.i = Int64(g.store_bytes(dec.read_fixed(wpool.nodes[wid].size)))
        return g.add_node(n)
    if wk == ST_ENUM:
        n.kind = AV_ENUM
        var idx = Int(dec.read_int())
        var wss = wpool.nodes[wid].symbol_start
        var rss = g.pool.nodes[rid].symbol_start
        var rsc = g.pool.nodes[rid].symbol_count
        if idx >= 0 and idx < wpool.nodes[wid].symbol_count:
            var sym = wpool.symbol[wss + idx]
            var j = 0
            while j < rsc:
                if g.pool.symbol[rss + j] == sym:
                    n.i = Int64(j)
                    return g.add_node(n)
                j += 1
        var ed = g.pool.nodes[rid].enum_default
        if ed.byte_length() > 0:
            var j = 0
            while j < rsc:
                if g.pool.symbol[rss + j] == ed:
                    n.i = Int64(j)
                    return g.add_node(n)
                j += 1
        raise DecodeError(DecodeError.KIND_BAD_ENUM, dec.position())
    if wk == ST_ARRAY and rk == ST_ARRAY:
        n.kind = 10
        var first = len(g.refs)
        var total = 0
        while True:
            var count, _h = dec.read_block_count()
            if count == 0:
                break
            var j = Int64(0)
            while j < count:
                var cid = _dec_res(
                    g, dec, wpool, wpool.nodes[wid].item_id, g.pool.nodes[rid].item_id
                )
                g.refs.append(cid)
                total += 1
                j += 1
        n.first = first
        n.count = total
        return g.add_node(n)
    if wk == ST_MAP and rk == ST_MAP:
        n.kind = 11
        var first = len(g.refs)
        var total = 0
        while True:
            var count, _h = dec.read_block_count()
            if count == 0:
                break
            var j = Int64(0)
            while j < count:
                var kn = AvroNode()
                kn.kind = AV_STRING
                kn.s = dec.read_string()
                var kid = g.add_node(kn)
                var vid = _dec_res(
                    g, dec, wpool, wpool.nodes[wid].value_id, g.pool.nodes[rid].value_id
                )
                g.refs.append(kid)
                g.refs.append(vid)
                total += 1
                j += 1
        n.first = first
        n.count = total
        return g.add_node(n)
    raise DecodeError(DecodeError.KIND_RESOLVE, dec.position())


def _skip_value[
    origin: ImmOrigin
](mut dec: WireReader[origin], wpool: SchemaPool, sid: Int) raises DecodeError:
    var id = wpool.resolve(sid)
    var k = wpool.nodes[id].kind
    if k == ST_NULL:
        return
    if k == ST_BOOL:
        _ = dec.read_bool()
        return
    if k == ST_INT or k == ST_ENUM:
        _ = dec.read_int()
        return
    if k == ST_LONG:
        _ = dec.read_long()
        return
    if k == ST_FLOAT:
        _ = dec.read_float()
        return
    if k == ST_DOUBLE:
        _ = dec.read_double()
        return
    if k == ST_STRING:
        _ = dec.read_string()
        return
    if k == ST_BYTES:
        _ = dec.read_bytes()
        return
    if k == ST_FIXED:
        _ = dec.read_fixed(wpool.nodes[id].size)
        return
    if k == ST_RECORD:
        var i = 0
        var fs = wpool.nodes[id].field_start
        while i < wpool.nodes[id].field_count:
            _skip_value(dec, wpool, wpool.field_type[fs + i])
            i += 1
        return
    if k == ST_ARRAY:
        while True:
            var count, _h = dec.read_block_count()
            if count == 0:
                return
            var j = Int64(0)
            while j < count:
                _skip_value(dec, wpool, wpool.nodes[id].item_id)
                j += 1
    elif k == ST_MAP:
        while True:
            var count, _h = dec.read_block_count()
            if count == 0:
                return
            var j = Int64(0)
            while j < count:
                _ = dec.read_string()
                _skip_value(dec, wpool, wpool.nodes[id].value_id)
                j += 1
    if k == ST_UNION:
        var idx = dec.read_long()
        _skip_value(
            dec, wpool, wpool.branch_id[wpool.nodes[id].branch_start + Int(idx)]
        )


def _default_node(
    mut g: GenericDatum, json_text: String, sid: Int
) raises DecodeError -> Int:
    var doc: JsonDoc
    try:
        doc = parse_json(json_text)
    except _:
        raise DecodeError(DecodeError.KIND_JSON, 0)
    var id = g.pool.resolve(sid)
    var k = g.pool.nodes[id].kind
    if k == ST_UNION:
        return _default_node(
            g, json_text, g.pool.branch_id[g.pool.nodes[id].branch_start]
        )
    var n = AvroNode()
    n.schema_id = id
    if k == ST_NULL or doc.kind(doc.root) == JSON_NULL:
        n.kind = AV_NULL
        return g.add_node(n)
    if k == ST_BOOL:
        n.kind = AV_BOOL
        n.b = doc.as_bool(doc.root)
        return g.add_node(n)
    if k == ST_INT:
        n.kind = AV_INT
        n.i = doc.as_int(doc.root)
        return g.add_node(n)
    if k == ST_LONG:
        n.kind = AV_LONG
        n.i = doc.as_int(doc.root)
        return g.add_node(n)
    if k == ST_STRING:
        n.kind = AV_STRING
        n.s = doc.as_string(doc.root)
        return g.add_node(n)
    n.kind = AV_NULL
    return g.add_node(n)


def _str_bytes(s: String) -> List[Byte]:
    var out = List[Byte]()
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        out.append(b[i])
        i += 1
    return out^


def _bytes_str(data: List[Byte]) raises DecodeError -> String:
    try:
        return String(from_utf8=data)
    except _:
        raise DecodeError(DecodeError.KIND_BAD_UTF8, 0)
