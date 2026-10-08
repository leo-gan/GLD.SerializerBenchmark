from std.collections import List

from arrow_runtime.error import DecodeError
from arrow_runtime.flatbuf import FBBuilder, FBReader
from arrow_runtime.model import (
    TY_BINARY,
    TY_BINARY_VIEW,
    TY_BOOL,
    TY_DATE,
    TY_DECIMAL,
    TY_DURATION,
    TY_FIXED_BINARY,
    TY_FIXED_LIST,
    TY_FLOAT,
    TY_INT,
    TY_INTERVAL,
    TY_LARGE_BINARY,
    TY_LARGE_LIST,
    TY_LARGE_LIST_VIEW,
    TY_LARGE_UTF8,
    TY_LIST,
    TY_LIST_VIEW,
    TY_MAP,
    TY_NULL,
    TY_RUN_END,
    TY_STRUCT,
    TY_TIME,
    TY_TIMESTAMP,
    TY_UNION,
    TY_UTF8,
    TY_UTF8_VIEW,
    Columnar,
    FieldRec,
)


def type_code(kind: Int) -> Int:
    if kind == TY_NULL:
        return 1
    if kind == TY_INT:
        return 2
    if kind == TY_FLOAT:
        return 3
    if kind == TY_BINARY:
        return 4
    if kind == TY_UTF8:
        return 5
    if kind == TY_BOOL:
        return 6
    if kind == TY_DECIMAL:
        return 7
    if kind == TY_DATE:
        return 8
    if kind == TY_TIME:
        return 9
    if kind == TY_TIMESTAMP:
        return 10
    if kind == TY_INTERVAL:
        return 11
    if kind == TY_LIST:
        return 12
    if kind == TY_STRUCT:
        return 13
    if kind == TY_UNION:
        return 14
    if kind == TY_FIXED_BINARY:
        return 15
    if kind == TY_FIXED_LIST:
        return 16
    if kind == TY_MAP:
        return 17
    if kind == TY_DURATION:
        return 18
    if kind == TY_LARGE_BINARY:
        return 19
    if kind == TY_LARGE_UTF8:
        return 20
    if kind == TY_LARGE_LIST:
        return 21
    if kind == TY_RUN_END:
        return 22
    if kind == TY_BINARY_VIEW:
        return 23
    if kind == TY_UTF8_VIEW:
        return 24
    if kind == TY_LIST_VIEW:
        return 25
    if kind == TY_LARGE_LIST_VIEW:
        return 26
    return 0


def kind_from_code(code: Int) raises DecodeError -> Int:
    if code == 1:
        return TY_NULL
    if code == 2:
        return TY_INT
    if code == 3:
        return TY_FLOAT
    if code == 4:
        return TY_BINARY
    if code == 5:
        return TY_UTF8
    if code == 6:
        return TY_BOOL
    if code == 7:
        return TY_DECIMAL
    if code == 8:
        return TY_DATE
    if code == 9:
        return TY_TIME
    if code == 10:
        return TY_TIMESTAMP
    if code == 11:
        return TY_INTERVAL
    if code == 12:
        return TY_LIST
    if code == 13:
        return TY_STRUCT
    if code == 14:
        return TY_UNION
    if code == 15:
        return TY_FIXED_BINARY
    if code == 16:
        return TY_FIXED_LIST
    if code == 17:
        return TY_MAP
    if code == 18:
        return TY_DURATION
    if code == 19:
        return TY_LARGE_BINARY
    if code == 20:
        return TY_LARGE_UTF8
    if code == 21:
        return TY_LARGE_LIST
    if code == 22:
        return TY_RUN_END
    if code == 23:
        return TY_BINARY_VIEW
    if code == 24:
        return TY_UTF8_VIEW
    if code == 25:
        return TY_LIST_VIEW
    if code == 26:
        return TY_LARGE_LIST_VIEW
    raise DecodeError(DecodeError.KIND_TYPE, code)


def encode_schema(c: Columnar) raises DecodeError -> List[Byte]:
    var b = FBBuilder()
    var tok = _schema(b, c)
    return b.finish(tok)


def schema_token(mut b: FBBuilder, c: Columnar) raises DecodeError -> Int:
    return _schema(b, c)


def _schema(mut b: FBBuilder, c: Columnar) raises DecodeError -> Int:
    var offs = List[Int]()
    var i = 0
    while i < len(c.top):
        offs.append(_field(b, c, c.top[i]))
        i += 1
    var fields = b.write_offset_vec(offs)
    var meta = _meta_vec(b, c, c.schema_meta0, c.nschema_meta)
    var bits = c.features
    if c.codec >= 0:
        bits = bits | 2
    var bi = 0
    while bi < len(c.batches):
        if c.batches[bi].codec >= 0:
            bits = bits | 2
        bi += 1
    var feats = _features(b, bits)
    b.start_table(4)
    if c.endian != 0:
        b.add_u16(0, c.endian, 0)
    b.add_offset(1, fields)
    if meta >= 0:
        b.add_offset(2, meta)
    if feats >= 0:
        b.add_offset(3, feats)
    return b.end_table()


def _features(mut b: FBBuilder, bits: Int) -> Int:
    var vals = List[Int]()
    if (bits & 1) != 0:
        vals.append(1)
    if (bits & 2) != 0:
        vals.append(2)
    if len(vals) == 0:
        return -1
    return b.write_u64_vec(vals)


def _meta_vec(mut b: FBBuilder, c: Columnar, at: Int, n: Int) -> Int:
    if n <= 0:
        return -1
    var offs = List[Int]()
    var i = 0
    while i < n:
        var k = b.write_string(c.strings[c.meta_k[at + i]])
        var v = b.write_string(c.strings[c.meta_v[at + i]])
        b.start_table(2)
        b.add_offset(0, k)
        b.add_offset(1, v)
        offs.append(b.end_table())
        i += 1
    return b.write_offset_vec(offs)


def _field(mut b: FBBuilder, c: Columnar, id: Int) raises DecodeError -> Int:
    var f = c.fields[id]
    var name = -1
    if f.name >= 0:
        name = b.write_string(c.strings[f.name])
    var ty = _type_table(b, c, f)
    var dict = _dict(b, f)
    var children = -1
    if f.nchild > 0:
        var offs = List[Int]()
        var i = 0
        while i < f.nchild:
            offs.append(_field(b, c, c.kids[f.child0 + i]))
            i += 1
        children = b.write_offset_vec(offs)
    var meta = _meta_vec(b, c, f.meta0, f.nmeta)
    var code = type_code(f.kind)
    if code == 0:
        raise DecodeError(DecodeError.KIND_TYPE, f.kind)
    b.start_table(7)
    if name >= 0:
        b.add_offset(0, name)
    b.add_bool(1, f.nullable != 0, False)
    b.add_u8(2, code, 0)
    b.add_offset(3, ty)
    if dict >= 0:
        b.add_offset(4, dict)
    if children >= 0:
        b.add_offset(5, children)
    if meta >= 0:
        b.add_offset(6, meta)
    return b.end_table()


def _dict(mut b: FBBuilder, f: FieldRec) -> Int:
    if f.dict_id < 0:
        return -1
    b.start_table(2)
    b.add_i32(0, f.dict_index_width, 0)
    b.add_bool(1, f.dict_index_signed != 0, False)
    var index = b.end_table()
    b.start_table(4)
    b.add_i64(0, f.dict_id, -1)
    b.add_offset(1, index)
    b.add_bool(2, f.dict_ordered != 0, False)
    return b.end_table()


def _type_table(mut b: FBBuilder, c: Columnar, f: FieldRec) -> Int:
    var k = f.kind
    if k == TY_INT:
        b.start_table(2)
        b.add_i32(0, f.bit_width, 0)
        b.add_bool(1, f.is_signed != 0, False)
        return b.end_table()
    if k == TY_FLOAT:
        b.start_table(1)
        b.add_u16(0, f.unit, 0)
        return b.end_table()
    if k == TY_DECIMAL:
        b.start_table(3)
        b.add_i32(0, f.precision, 0)
        b.add_i32(1, f.scale, 0)
        b.add_i32(2, f.bit_width, 128)
        return b.end_table()
    if k == TY_DATE:
        b.start_table(1)
        b.add_u16(0, f.unit, 1)
        return b.end_table()
    if k == TY_TIME:
        b.start_table(2)
        b.add_u16(0, f.unit, 1)
        b.add_i32(1, f.bit_width, 32)
        return b.end_table()
    if k == TY_TIMESTAMP:
        var tz = -1
        if f.timezone >= 0:
            tz = b.write_string(c.strings[f.timezone])
        b.start_table(2)
        b.add_u16(0, f.unit, 0)
        if tz >= 0:
            b.add_offset(1, tz)
        return b.end_table()
    if k == TY_INTERVAL:
        b.start_table(1)
        b.add_u16(0, f.unit, 0)
        return b.end_table()
    if k == TY_DURATION:
        b.start_table(1)
        b.add_u16(0, f.unit, 1)
        return b.end_table()
    if k == TY_FIXED_BINARY:
        b.start_table(1)
        b.add_i32(0, f.fixed_size, 0)
        return b.end_table()
    if k == TY_FIXED_LIST:
        b.start_table(1)
        b.add_i32(0, f.fixed_size, 0)
        return b.end_table()
    if k == TY_MAP:
        b.start_table(1)
        b.add_bool(0, f.keys_sorted != 0, False)
        return b.end_table()
    if k == TY_UNION:
        var ids = -1
        if f.n_type_ids > 0:
            var vals = List[Int]()
            var i = 0
            while i < f.n_type_ids:
                vals.append(c.type_ids[f.type_ids0 + i])
                i += 1
            ids = b.write_u32_vec(vals)
        b.start_table(2)
        b.add_u16(0, f.union_mode, 0)
        if ids >= 0:
            b.add_offset(1, ids)
        return b.end_table()
    b.start_table(0)
    return b.end_table()


def decode_schema(r: FBReader, table: Int, mut c: Columnar) raises DecodeError:
    var endp = r.field(table, 0)
    if endp >= 0:
        c.endian = r.u16(endp)
    else:
        c.endian = 0
    var fp = r.field(table, 1)
    if fp < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, table)
    var n = r.vec_len(fp)
    var data = r.vec_data(fp)
    var i = 0
    while i < n:
        var rel = r.u32(data + i * 4)
        var fid = _read_field(r, data + i * 4 + rel, c, 0)
        c.top.append(fid)
        i += 1
    var mp = r.field(table, 2)
    if mp >= 0:
        c.schema_meta0 = len(c.meta_k)
        c.nschema_meta = _read_meta(r, mp, c)
    var feat = r.field(table, 3)
    if feat >= 0:
        c.features = _read_features(r, feat)


def _read_features(r: FBReader, pos: Int) raises DecodeError -> Int:
    var n = r.vec_len(pos)
    var data = r.vec_data(pos)
    var bits = 0
    var i = 0
    while i < n:
        var v = r.i64(data + i * 8)
        if v == 1 or v == 2:
            bits = bits | v
        i += 1
    return bits


def _read_meta(r: FBReader, pos: Int, mut c: Columnar) raises DecodeError -> Int:
    var n = r.vec_len(pos)
    var data = r.vec_data(pos)
    var i = 0
    while i < n:
        var rel = r.u32(data + i * 4)
        var kv = data + i * 4 + rel
        var k = String("")
        var v = String("")
        var kp = r.field(kv, 0)
        if kp >= 0:
            k = r.string_at(kp)
        var vp = r.field(kv, 1)
        if vp >= 0:
            v = r.string_at(vp)
        _ = c.add_meta(k, v)
        i += 1
    return n


def _read_field(r: FBReader, table: Int, mut c: Columnar, depth: Int) raises DecodeError -> Int:
    if depth > 64:
        raise DecodeError(DecodeError.KIND_DEPTH, table)
    var f = FieldRec()
    var np = r.field(table, 0)
    if np >= 0:
        f.name = c.intern(r.string_at(np))
    var nul = r.field(table, 1)
    if nul >= 0 and r.u8(nul) != 0:
        f.nullable = 1
    else:
        f.nullable = 0
    var tp = r.field(table, 2)
    if tp < 0:
        raise DecodeError(DecodeError.KIND_TYPE, table)
    var code = r.u8(tp)
    f.kind = kind_from_code(code)
    var typ = r.field(table, 3)
    if typ < 0:
        raise DecodeError(DecodeError.KIND_TYPE, table)
    _read_type(r, r.follow(typ), f, c)
    var dp = r.field(table, 4)
    if dp >= 0:
        _read_dict(r, r.follow(dp), f)
    var id = c.add_field(f)
    var cp = r.field(table, 5)
    var direct = List[Int]()
    if cp >= 0:
        var n = r.vec_len(cp)
        var data = r.vec_data(cp)
        var i = 0
        while i < n:
            var rel = r.u32(data + i * 4)
            direct.append(_read_field(r, data + i * 4 + rel, c, depth + 1))
            i += 1
    var start = len(c.kids)
    var di = 0
    while di < len(direct):
        c.kids.append(direct[di])
        di += 1
    var mp = r.field(table, 6)
    var meta_at = len(c.meta_k)
    var nmeta = 0
    if mp >= 0:
        nmeta = _read_meta(r, mp, c)
    var stored = c.fields[id]
    stored.child0 = start
    stored.nchild = len(direct)
    stored.meta0 = meta_at
    stored.nmeta = nmeta
    c.fields[id] = stored
    return id


def _read_dict(r: FBReader, table: Int, mut f: FieldRec) raises DecodeError:
    var ip = r.field(table, 0)
    if ip >= 0:
        f.dict_id = r.i64(ip)
    else:
        f.dict_id = 0
    var tp = r.field(table, 1)
    if tp >= 0:
        var it = r.follow(tp)
        var w = r.field(it, 0)
        if w >= 0:
            f.dict_index_width = r.i32(w)
        var s = r.field(it, 1)
        if s >= 0 and r.u8(s) != 0:
            f.dict_index_signed = 1
        else:
            f.dict_index_signed = 0
    var op = r.field(table, 2)
    if op >= 0 and r.u8(op) != 0:
        f.dict_ordered = 1


def _read_type(r: FBReader, table: Int, mut f: FieldRec, mut c: Columnar) raises DecodeError:
    var k = f.kind
    if k == TY_INT:
        var w = r.field(table, 0)
        if w < 0:
            raise DecodeError(DecodeError.KIND_TYPE, table)
        f.bit_width = r.i32(w)
        var s = r.field(table, 1)
        if s >= 0 and r.u8(s) != 0:
            f.is_signed = 1
        else:
            f.is_signed = 0
        return
    if k == TY_FLOAT:
        var p = r.field(table, 0)
        if p >= 0:
            f.unit = r.u16(p)
        return
    if k == TY_DECIMAL:
        var p = r.field(table, 0)
        if p >= 0:
            f.precision = r.i32(p)
        var s = r.field(table, 1)
        if s >= 0:
            f.scale = r.i32(s)
        var w = r.field(table, 2)
        if w >= 0:
            f.bit_width = r.i32(w)
        else:
            f.bit_width = 128
        return
    if k == TY_DATE:
        var u = r.field(table, 0)
        if u >= 0:
            f.unit = r.u16(u)
        else:
            f.unit = 1
        return
    if k == TY_TIME:
        var u = r.field(table, 0)
        if u >= 0:
            f.unit = r.u16(u)
        else:
            f.unit = 1
        var w = r.field(table, 1)
        if w >= 0:
            f.bit_width = r.i32(w)
        else:
            f.bit_width = 32
        return
    if k == TY_TIMESTAMP:
        var u = r.field(table, 0)
        if u >= 0:
            f.unit = r.u16(u)
        var z = r.field(table, 1)
        if z >= 0:
            f.timezone = c.intern(r.string_at(z))
        return
    if k == TY_INTERVAL:
        var u = r.field(table, 0)
        if u >= 0:
            f.unit = r.u16(u)
        return
    if k == TY_DURATION:
        var u = r.field(table, 0)
        if u >= 0:
            f.unit = r.u16(u)
        else:
            f.unit = 1
        return
    if k == TY_FIXED_BINARY or k == TY_FIXED_LIST:
        var w = r.field(table, 0)
        if w >= 0:
            f.fixed_size = r.i32(w)
        return
    if k == TY_MAP:
        var s = r.field(table, 0)
        if s >= 0 and r.u8(s) != 0:
            f.keys_sorted = 1
        return
    if k == TY_UNION:
        var m = r.field(table, 0)
        if m >= 0:
            f.union_mode = r.u16(m)
        var ids = r.field(table, 1)
        if ids >= 0:
            var n = r.vec_len(ids)
            var data = r.vec_data(ids)
            f.type_ids0 = len(c.type_ids)
            f.n_type_ids = n
            var i = 0
            while i < n:
                var v = r.i32(data + i * 4)
                c.type_ids.append(v)
                i += 1
        return
