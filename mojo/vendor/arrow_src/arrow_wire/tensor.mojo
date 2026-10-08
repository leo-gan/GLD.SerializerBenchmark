from std.collections import List

from arrow_runtime.buf import put_i64, put_u32
from arrow_runtime.error import DecodeError
from arrow_runtime.flatbuf import FBBuilder, FBReader
from arrow_runtime.model import Columnar, FieldRec, TensorRec, byte_width_of
from arrow_wire.schema_fb import _read_type, _type_table, kind_from_code, type_code


def read_tensor(mut c: Columnar, r: FBReader, header: Int, body: List[Byte], sparse: Bool) raises DecodeError:
    if sparse:
        _read_sparse(c, r, header, body)
    else:
        _read_dense(c, r, header, body)


def encode_tensor_stream(c: Columnar) raises DecodeError -> List[Byte]:
    var out = List[Byte]()
    var i = 0
    while i < len(c.tensors):
        var msg = _encode_one(c, i)
        var k = 0
        while k < len(msg):
            out.append(msg[k])
            k += 1
        i += 1
    return out^


def _read_dense(mut c: Columnar, r: FBReader, header: Int, body: List[Byte]) raises DecodeError:
    var fid = _tensor_type(c, r, header)
    var t = TensorRec()
    t.field = fid
    t.sparse_kind = 0
    _read_shape(c, r, header, t)
    var sp = r.field(header, 3)
    if sp >= 0:
        t.stride0 = len(c.strides)
        var n = r.vec_len(sp)
        var data = r.vec_data(sp)
        var i = 0
        while i < n:
            c.strides.append(r.i64(data + i * 8))
            i += 1
        t.nstride = n
    else:
        _row_major(c, t)
    var dp = r.field(header, 4)
    if dp < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, header)
    t.data_buf = _copy_struct_buf(c, r, dp, body)
    c.tensors.append(t)


def _read_sparse(mut c: Columnar, r: FBReader, header: Int, body: List[Byte]) raises DecodeError:
    var fid = _tensor_type(c, r, header)
    var t = TensorRec()
    t.field = fid
    _read_shape(c, r, header, t)
    var nz = r.field(header, 3)
    if nz >= 0:
        t.nz = r.i64(nz)
    var kt = r.field(header, 4)
    var kp = r.field(header, 5)
    if kt < 0 or kp < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, header)
    var kind = r.u8(kt)
    var idx = r.follow(kp)
    t.sparse_kind = kind
    if kind == 1:
        _read_coo(c, r, idx, body, t)
    elif kind == 2:
        _read_csx(c, r, idx, body, t)
    elif kind == 3:
        _read_csf(c, r, idx, body, t)
    else:
        raise DecodeError(DecodeError.KIND_TYPE, kind)
    var dp = r.field(header, 6)
    if dp < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, header)
    t.data_buf = _copy_struct_buf(c, r, dp, body)
    c.tensors.append(t)


def _tensor_type(mut c: Columnar, r: FBReader, header: Int) raises DecodeError -> Int:
    var tp = r.field(header, 0)
    var tt = r.field(header, 1)
    if tp < 0 or tt < 0:
        raise DecodeError(DecodeError.KIND_TYPE, header)
    var f = FieldRec()
    f.kind = kind_from_code(r.u8(tp))
    f.nullable = 0
    _read_type(r, r.follow(tt), f, c)
    return c.add_field(f)


def _read_shape(mut c: Columnar, r: FBReader, header: Int, mut t: TensorRec) raises DecodeError:
    var sp = r.field(header, 2)
    if sp < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, header)
    var n = r.vec_len(sp)
    var data = r.vec_data(sp)
    t.shape0 = len(c.shapes)
    t.nshape = n
    var i = 0
    while i < n:
        var rel = r.u32(data + i * 4)
        var dim = data + i * 4 + rel
        var sz = r.field(dim, 0)
        if sz < 0:
            raise DecodeError(DecodeError.KIND_SCHEMA, dim)
        c.shapes.append(r.i64(sz))
        var nm = r.field(dim, 1)
        if nm >= 0:
            c.shape_names.append(c.intern(r.string_at(nm)))
        else:
            c.shape_names.append(-1)
        i += 1


def _row_major(mut c: Columnar, mut t: TensorRec):
    var width = byte_width_of(c.fields[t.field])
    if width <= 0:
        width = 1
    t.stride0 = len(c.strides)
    t.nstride = t.nshape
    var prod = width
    var i = t.nshape - 1
    while i >= 0:
        c.strides.append(prod)
        prod = prod * c.shapes[t.shape0 + i]
        i -= 1
    var tmp = List[Int]()
    i = 0
    while i < t.nstride:
        tmp.append(c.strides[t.stride0 + t.nstride - 1 - i])
        i += 1
    i = 0
    while i < t.nstride:
        c.strides[t.stride0 + i] = tmp[i]
        i += 1


def _copy_struct_buf(mut c: Columnar, r: FBReader, pos: Int, body: List[Byte]) raises DecodeError -> Int:
    var off = r.i64(pos)
    var ln = r.i64(pos + 8)
    if ln == 0:
        return c.add_empty_buf()
    if off < 0 or ln < 0 or off + ln > len(body):
        raise DecodeError(DecodeError.KIND_RANGE, off)
    var raw = List[Byte]()
    var i = 0
    while i < ln:
        raw.append(body[off + i])
        i += 1
    return c.add_buf_list(raw)


def _read_int_type(r: FBReader, table: Int, mut width: Int, mut signed: Int) raises DecodeError:
    var w = r.field(table, 0)
    if w >= 0:
        width = r.i32(w)
    var s = r.field(table, 1)
    if s >= 0 and r.u8(s) != 0:
        signed = 1
    else:
        signed = 0


def _read_coo(mut c: Columnar, r: FBReader, table: Int, body: List[Byte], mut t: TensorRec) raises DecodeError:
    var tp = r.field(table, 0)
    if tp < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, table)
    _read_int_type(r, r.follow(tp), t.index_width, t.index_signed)
    var bp = r.field(table, 2)
    if bp < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, table)
    t.index_buf0 = len(c.abufs)
    c.abufs.append(_copy_struct_buf(c, r, bp, body))
    t.nindex = 1
    var flag = r.field(table, 3)
    if flag >= 0 and r.u8(flag) != 0:
        t.coo_canonical = 1


def _read_csx(mut c: Columnar, r: FBReader, table: Int, body: List[Byte], mut t: TensorRec) raises DecodeError:
    var ax = r.field(table, 0)
    if ax >= 0:
        t.csx_axis = r.u16(ax)
    var ip = r.field(table, 1)
    if ip < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, table)
    _read_int_type(r, r.follow(ip), t.index_width, t.index_signed)
    var ib = r.field(table, 2)
    var xb = r.field(table, 4)
    if ib < 0 or xb < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, table)
    t.index_buf0 = len(c.abufs)
    c.abufs.append(_copy_struct_buf(c, r, ib, body))
    c.abufs.append(_copy_struct_buf(c, r, xb, body))
    t.nindex = 2


def _read_csf(mut c: Columnar, r: FBReader, table: Int, body: List[Byte], mut t: TensorRec) raises DecodeError:
    var ip = r.field(table, 0)
    if ip < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, table)
    _read_int_type(r, r.follow(ip), t.index_width, t.index_signed)
    t.index_buf0 = len(c.abufs)
    var n = 0
    var pb = r.field(table, 1)
    if pb >= 0:
        n = _read_buf_vec(c, r, pb, body)
    var ib = r.field(table, 3)
    if ib >= 0:
        n = n + _read_buf_vec(c, r, ib, body)
    t.nindex = n
    var ao = r.field(table, 4)
    if ao >= 0:
        var nv = r.vec_len(ao)
        var data = r.vec_data(ao)
        var i = 0
        while i < nv:
            c.strides.append(r.i32(data + i * 4))
            i += 1
        if t.nstride == 0:
            t.stride0 = len(c.strides) - nv
            t.nstride = nv


def _read_buf_vec(mut c: Columnar, r: FBReader, pos: Int, body: List[Byte]) raises DecodeError -> Int:
    var n = r.vec_len(pos)
    var data = r.vec_data(pos)
    var i = 0
    while i < n:
        c.abufs.append(_copy_struct_buf(c, r, data + i * 16, body))
        i += 1
    return n


struct OffLen(Copyable, ImplicitlyCopyable):
    var off: Int
    var length: Int

    def __init__(out self, off: Int, length: Int):
        self.off = off
        self.length = length


def _append_body(mut body: List[Byte], c: Columnar, buf: Int) -> OffLen:
    while len(body) % 8 != 0:
        body.append(Byte(0))
    var off = len(body)
    var src = c.buf_copy(buf)
    var i = 0
    while i < len(src):
        body.append(src[i])
        i += 1
    return OffLen(off, len(src))


def _encode_one(c: Columnar, index: Int) raises DecodeError -> List[Byte]:
    var t = c.tensors[index]
    var body = List[Byte]()
    var data_loc = _append_body(body, c, t.data_buf)
    var index_locs = List[OffLen]()
    var i = 0
    while i < t.nindex:
        index_locs.append(_append_body(body, c, c.abufs[t.index_buf0 + i]))
        i += 1
    while len(body) % 8 != 0:
        body.append(Byte(0))
    var b = FBBuilder()
    var f = c.fields[t.field]
    var ty = _type_table(b, c, f)
    var shape = _shape_vec(b, c, t)
    var strides = -1
    if t.nstride > 0 and t.sparse_kind == 0:
        var vals = List[Int]()
        i = 0
        while i < t.nstride:
            vals.append(c.strides[t.stride0 + i])
            i += 1
        strides = b.write_u64_vec(vals)
    if t.sparse_kind == 0:
        b.start_table(5)
        b.add_u8(0, type_code(f.kind), 0)
        b.add_offset(1, ty)
        b.add_offset(2, shape)
        if strides >= 0:
            b.add_offset(3, strides)
        b.add_i64_pair(4, data_loc.off, data_loc.length)
        return _wrap(b, 4, b.end_table(), body)
    var index_tok = _sparse_index(b, c, t, index_locs)
    b.start_table(7)
    b.add_u8(0, type_code(f.kind), 0)
    b.add_offset(1, ty)
    b.add_offset(2, shape)
    b.add_i64(3, t.nz, -1)
    b.add_u8(4, t.sparse_kind, 0)
    b.add_offset(5, index_tok)
    b.add_i64_pair(6, data_loc.off, data_loc.length)
    return _wrap(b, 5, b.end_table(), body)


def _shape_vec(mut b: FBBuilder, c: Columnar, t: TensorRec) -> Int:
    var offs = List[Int]()
    var i = 0
    while i < t.nshape:
        var name = -1
        if t.shape0 + i < len(c.shape_names):
            var ni = c.shape_names[t.shape0 + i]
            if ni >= 0:
                name = b.write_string(c.strings[ni])
        b.start_table(2)
        b.add_i64(0, c.shapes[t.shape0 + i], -1)
        if name >= 0:
            b.add_offset(1, name)
        offs.append(b.end_table())
        i += 1
    return b.write_offset_vec(offs)


def _wrap(mut b: FBBuilder, kind: Int, header: Int, body: List[Byte]) -> List[Byte]:
    b.start_table(5)
    b.add_u16(0, 4, 0)
    b.add_u8(1, kind, 0)
    b.add_offset(2, header)
    b.add_i64(3, len(body), 0)
    var meta = b.finish(b.end_table())
    while len(meta) % 8 != 0:
        meta.append(Byte(0))
    var out = List[Byte]()
    put_u32(out, 0xFFFFFFFF)
    put_u32(out, len(meta))
    var i = 0
    while i < len(meta):
        out.append(meta[i])
        i += 1
    i = 0
    while i < len(body):
        out.append(body[i])
        i += 1
    return out^


def _sparse_index(mut b: FBBuilder, c: Columnar, t: TensorRec, locs: List[OffLen]) -> Int:
    b.start_table(2)
    b.add_i32(0, t.index_width, 0)
    b.add_bool(1, t.index_signed != 0, False)
    var itype = b.end_table()
    if t.sparse_kind == 1:
        b.start_table(4)
        b.add_offset(0, itype)
        b.add_i64_pair(2, locs[0].off, locs[0].length)
        b.add_bool(3, t.coo_canonical != 0, False)
        return b.end_table()
    if t.sparse_kind == 2:
        b.start_table(5)
        b.add_u16(0, t.csx_axis, 0)
        b.add_offset(1, itype)
        b.add_i64_pair(2, locs[0].off, locs[0].length)
        b.add_offset(3, itype)
        b.add_i64_pair(4, locs[1].off, locs[1].length)
        return b.end_table()
    var raw_p = List[Byte]()
    var half = t.nindex // 2
    var i = 0
    while i < half:
        put_i64(raw_p, locs[i].off)
        put_i64(raw_p, locs[i].length)
        i += 1
    var pvec = b.write_struct_vec(raw_p, 16)
    var raw_i = List[Byte]()
    while i < t.nindex:
        put_i64(raw_i, locs[i].off)
        put_i64(raw_i, locs[i].length)
        i += 1
    var ivec = b.write_struct_vec(raw_i, 16)
    var order = -1
    if t.nstride > 0:
        var vals = List[Int]()
        var k = 0
        while k < t.nstride:
            vals.append(c.strides[t.stride0 + k])
            k += 1
        order = b.write_u32_vec(vals)
    b.start_table(5)
    b.add_offset(0, itype)
    b.add_offset(1, pvec)
    b.add_offset(2, itype)
    b.add_offset(3, ivec)
    if order >= 0:
        b.add_offset(4, order)
    return b.end_table()