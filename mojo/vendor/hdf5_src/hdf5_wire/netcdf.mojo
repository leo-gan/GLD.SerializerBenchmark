from std.collections import List, Span
from std.memory import bitcast

from hdf5_runtime.bytes import Buf, append_f64, load_f64, u32be
from hdf5_runtime.doc import DT_F64, H5Doc, NcFile
from hdf5_runtime.error import FormatError
from hdf5_wire.hdf5 import read_hdf5, write_hdf5


def _pad4(mut buf: Buf):
    buf.pad4()


def _name(mut buf: Buf, text: String):
    var raw = text.as_bytes()
    buf.be32(len(raw))
    var i = 0
    while i < len(raw):
        buf.u8(Int(raw[i]))
        i += 1
    _pad4(buf)


def _be_f64(v: Float64) -> List[Byte]:
    var bits = Int(bitcast[DType.uint64](v))
    var buf = Buf()
    var i = 7
    while i >= 0:
        buf.u8((bits >> (i * 8)) & 255)
        i -= 1
    return buf.take()


def write_cdf1(nc: NcFile) raises -> List[Byte]:
    """Write a classic NetCDF CDF-1 file. Variables are float64, non-record."""
    var buf = Buf()
    buf.ascii(String("CDF"))
    buf.u8(1)
    buf.be32(0)
    buf.be32(10)
    buf.be32(len(nc.dim_name))
    var i = 0
    while i < len(nc.dim_name):
        if nc.dim_len[i] <= 0:
            raise FormatError(0, String("CDF-1 writer does not emit record dimensions"))
        _name(buf, nc.dim_name[i])
        buf.be32(nc.dim_len[i])
        i += 1
    var gcount = 0
    i = 0
    while i < len(nc.attr_name):
        if nc.attr_var[i] < 0:
            gcount += 1
        i += 1
    buf.be32(12)
    buf.be32(gcount)
    i = 0
    while i < len(nc.attr_name):
        if nc.attr_var[i] < 0:
            _name(buf, nc.attr_name[i])
            var raw = nc.attr_text[i].as_bytes()
            buf.be32(2)
            buf.be32(len(raw))
            var k = 0
            while k < len(raw):
                buf.u8(Int(raw[k]))
                k += 1
            _pad4(buf)
        i += 1
    buf.be32(11)
    buf.be32(len(nc.var_name))
    var begins = List[Int]()
    i = 0
    while i < len(nc.var_name):
        if nc.var_type[i] != DT_F64:
            raise FormatError(0, String("CDF-1 writer emits float64 variables"))
        _name(buf, nc.var_name[i])
        if nc.var_dim[i] < 0:
            buf.be32(0)
        else:
            buf.be32(1)
            buf.be32(nc.var_dim[i])
        var ac = 0
        var a = 0
        while a < len(nc.attr_name):
            if nc.attr_var[a] == i:
                ac += 1
            a += 1
        buf.be32(12)
        buf.be32(ac)
        a = 0
        while a < len(nc.attr_name):
            if nc.attr_var[a] == i:
                _name(buf, nc.attr_name[a])
                var raw = nc.attr_text[a].as_bytes()
                buf.be32(2)
                buf.be32(len(raw))
                var k = 0
                while k < len(raw):
                    buf.u8(Int(raw[k]))
                    k += 1
                _pad4(buf)
            a += 1
        var nval = 1
        if nc.var_dim[i] >= 0:
            nval = nc.dim_len[nc.var_dim[i]]
        if len(nc.var_data[i]) != nval:
            raise FormatError(0, String("variable length does not match its dimension"))
        buf.be32(6)
        buf.be32(nval * 8)
        begins.append(buf.n())
        buf.be32(0)
        i += 1
    i = 0
    while i < len(nc.var_name):
        var at = buf.n()
        var patch = begins[i]
        buf.b[patch] = Byte((at >> 24) & 255)
        buf.b[patch + 1] = Byte((at >> 16) & 255)
        buf.b[patch + 2] = Byte((at >> 8) & 255)
        buf.b[patch + 3] = Byte(at & 255)
        var k = 0
        while k < len(nc.var_data[i]):
            buf.blob(_be_f64(nc.var_data[i][k]))
            k += 1
        i += 1
    return buf.take()


def _read_name[origin: ImmOrigin](raw: Span[Byte, origin], mut pos: Int) raises -> String:
    var n = u32be(raw, pos)
    pos += 4
    if n < 0 or pos + n > len(raw):
        raise FormatError(pos, String("CDF name overruns the file"))
    var tmp = List[Byte]()
    var i = 0
    while i < n:
        tmp.append(raw[pos + i])
        i += 1
    pos += n
    if pos % 4 != 0:
        pos += 4 - (pos % 4)
    if len(tmp) == 0:
        return String()
    return String(unsafe_from_utf8=Span(tmp))


def _skip_values[origin: ImmOrigin](raw: Span[Byte, origin], mut pos: Int, typ: Int, ne: Int) raises:
    var width = 1
    if typ == 3:
        width = 2
    elif typ == 4 or typ == 5:
        width = 4
    elif typ == 6:
        width = 8
    elif typ != 1 and typ != 2:
        raise FormatError(pos, String("unsupported netCDF type"))
    var nbytes = ne * width
    pos += nbytes
    if pos % 4 != 0:
        pos += 4 - (pos % 4)
    if pos > len(raw):
        raise FormatError(pos, String("netCDF values overrun the file"))


def _read_attrs[origin: ImmOrigin](raw: Span[Byte, origin], mut pos: Int, mut nc: NcFile, owner: Int) raises:
    var tag = u32be(raw, pos)
    pos += 4
    if tag != 12:
        raise FormatError(pos, String("expected an attribute list"))
    var count = u32be(raw, pos)
    pos += 4
    var i = 0
    while i < count:
        var name = _read_name(raw, pos)
        var typ = u32be(raw, pos)
        pos += 4
        var ne = u32be(raw, pos)
        pos += 4
        if typ == 2:
            var tmp = List[Byte]()
            var k = 0
            while k < ne:
                tmp.append(raw[pos + k])
                k += 1
            var text = String()
            if len(tmp) > 0:
                text = String(unsafe_from_utf8=Span(tmp))
            nc.add_attr(owner, name, text)
            pos += ne
            if pos % 4 != 0:
                pos += 4 - (pos % 4)
        else:
            _skip_values(raw, pos, typ, ne)
        i += 1


def _f64be[origin: ImmOrigin](raw: Span[Byte, origin], at: Int) raises -> Float64:
    var u = UInt64(0)
    var s = 0
    while s < 8:
        u = (u << 8) | UInt64(Int(raw[at + s]))
        s += 1
    return bitcast[DType.float64](u)


def read_cdf1[origin: ImmOrigin](raw: Span[Byte, origin]) raises -> NcFile:
    """Read a classic CDF-1 file written by `write_cdf1`."""
    if len(raw) < 8 or Int(raw[0]) != 67 or Int(raw[1]) != 68 or Int(raw[2]) != 70 or Int(raw[3]) != 1:
        raise FormatError(0, String("not a CDF-1 file"))
    var pos = 4
    var numrecs = u32be(raw, pos)
    pos += 4
    _ = numrecs
    var nc = NcFile()
    var tag = u32be(raw, pos)
    pos += 4
    if tag != 10:
        raise FormatError(pos, String("expected a dimension list"))
    var nd = u32be(raw, pos)
    pos += 4
    var i = 0
    while i < nd:
        var name = _read_name(raw, pos)
        var ln = u32be(raw, pos)
        pos += 4
        if ln == 0:
            raise FormatError(pos, String("record dimensions are not supported"))
        _ = nc.add_dim(name, ln)
        i += 1
    _read_attrs(raw, pos, nc, -1)
    tag = u32be(raw, pos)
    pos += 4
    if tag != 11:
        raise FormatError(pos, String("expected a variable list"))
    var nv = u32be(raw, pos)
    pos += 4
    var begins = List[Int]()
    var counts = List[Int]()
    i = 0
    while i < nv:
        var name = _read_name(raw, pos)
        var ndims = u32be(raw, pos)
        pos += 4
        var dim = -1
        if ndims > 1:
            raise FormatError(pos, String("only scalar and 1-D variables are supported"))
        if ndims == 1:
            dim = u32be(raw, pos)
            pos += 4
        var attr_at = len(nc.attr_name)
        _read_attrs(raw, pos, nc, i)
        _ = attr_at
        var typ = u32be(raw, pos)
        pos += 4
        var vsize = u32be(raw, pos)
        pos += 4
        var begin = u32be(raw, pos)
        pos += 4
        _ = vsize
        if typ != 6:
            raise FormatError(pos, String("CDF-1 reader supports float64 variables"))
        var nval = 1
        if dim >= 0:
            nval = nc.dim_len[dim]
        _ = nc.add_var(name, DT_F64, dim, List[Float64]())
        begins.append(begin)
        counts.append(nval)
        i += 1
    i = 0
    while i < nv:
        var vals = List[Float64]()
        var k = 0
        var at = begins[i]
        while k < counts[i]:
            vals.append(_f64be(raw, at + k * 8))
            k += 1
        nc.var_data[i] = vals^
        i += 1
    return nc^


def _dim_info(name: String, length: Int) -> String:
    return String("name=") + name + String(";length=") + String(length) + String(";unlimited=0")


def write_nc4(nc: NcFile) raises -> List[Byte]:
    """NetCDF-4 as HDF5 plus dimension-scale attributes and `_netcdf_dim_info`."""
    var doc = H5Doc()
    var root = doc.add_group(-1, String(""))
    doc.add_text_attr_group(root, String("_NCProperties"), String("version=2,netcdf=4.9.2,hdf5=gld"))
    var i = 0
    while i < len(nc.attr_name):
        if nc.attr_var[i] < 0:
            doc.add_text_attr_group(root, nc.attr_name[i], nc.attr_text[i])
        i += 1
    var dim_ds = List[Int]()
    i = 0
    while i < len(nc.dim_name):
        var coords = List[Float64]()
        var k = 0
        while k < nc.dim_len[i]:
            coords.append(Float64(k))
            k += 1
        var ds = doc.add_f64(root, nc.dim_name[i], coords^, 0, 0)
        doc.add_text_attr_dataset(ds, String("CLASS"), String("DIMENSION_SCALE"))
        doc.add_text_attr_dataset(ds, String("NAME"), nc.dim_name[i])
        doc.add_text_attr_dataset(ds, String("_netcdf_dim_info"), _dim_info(nc.dim_name[i], nc.dim_len[i]))
        var idraw = List[Byte]()
        idraw.append(Byte(i & 255))
        idraw.append(Byte((i >> 8) & 255))
        idraw.append(Byte((i >> 16) & 255))
        idraw.append(Byte((i >> 24) & 255))
        doc.add_num_attr_dataset(ds, String("_Netcdf4Dimid"), 3, idraw^)
        dim_ds.append(ds)
        i += 1
    i = 0
    while i < len(nc.var_name):
        if nc.var_type[i] != DT_F64:
            raise FormatError(0, String("NetCDF-4 writer emits float64 variables"))
        if nc.var_dim[i] < 0:
            var one = List[Float64]()
            if len(nc.var_data[i]) != 1:
                raise FormatError(0, String("scalar variable needs one value"))
            one.append(nc.var_data[i][0])
            var scalar_ds = doc.add_f64(root, nc.var_name[i], one^, 0, 0)
            var a = 0
            while a < len(nc.attr_name):
                if nc.attr_var[a] == i:
                    doc.add_text_attr_dataset(scalar_ds, nc.attr_name[a], nc.attr_text[a])
                a += 1
        else:
            var dim = nc.var_dim[i]
            var var_ds = dim_ds[dim]
            if nc.var_name[i] != nc.dim_name[dim]:
                var_ds = doc.add_f64(root, nc.var_name[i], nc.var_data[i], 0, 0)
            doc.add_text_attr_dataset(var_ds, String("_netcdf_dim_info"), String("dims=") + nc.dim_name[dim])
            var a = 0
            while a < len(nc.attr_name):
                if nc.attr_var[a] == i:
                    doc.add_text_attr_dataset(var_ds, nc.attr_name[a], nc.attr_text[a])
                a += 1
        i += 1
    return write_hdf5(doc)


def _starts(text: String, prefix: String) -> Bool:
    var a = text.as_bytes()
    var b = prefix.as_bytes()
    if len(a) < len(b):
        return False
    var i = 0
    while i < len(b):
        if Int(a[i]) != Int(b[i]):
            return False
        i += 1
    return True


def _after(text: String, prefix: String) -> String:
    var a = text.as_bytes()
    var b = prefix.as_bytes()
    var tmp = List[Byte]()
    var i = len(b)
    while i < len(a):
        tmp.append(a[i])
        i += 1
    if len(tmp) == 0:
        return String()
    return String(unsafe_from_utf8=Span(tmp))


def _f64s_of(raw: List[Byte]) raises -> List[Float64]:
    var out = List[Float64]()
    var i = 0
    while i + 8 <= len(raw):
        out.append(load_f64(Span(raw), i))
        i += 8
    return out^


def read_nc4[origin: ImmOrigin](raw: Span[Byte, origin]) raises -> NcFile:
    """Read a NetCDF-4 file written by `write_nc4`."""
    var doc = read_hdf5(raw)
    var nc = NcFile()
    var dim_index = List[Int]()
    var i = 0
    while i < len(doc.d_name):
        if doc.d_parent[i] != 0:
            i += 1
            continue
        var is_dim = 0
        var a = 0
        while a < len(doc.a_name):
            if doc.a_kind[a] == 1 and doc.a_owner[a] == i:
                if doc.a_name[a] == String("CLASS") and doc.a_text[a] == String("DIMENSION_SCALE"):
                    is_dim = 1
                if doc.a_name[a] == String("_netcdf_dim_info") and _starts(doc.a_text[a], String("name=")):
                    is_dim = 1
            a += 1
        if is_dim != 0:
            _ = nc.add_dim(doc.d_name[i], doc.d_n0[i])
            dim_index.append(i)
        i += 1
    i = 0
    while i < len(doc.d_name):
        if doc.d_parent[i] != 0:
            i += 1
            continue
        var dims_name = String()
        var a = 0
        while a < len(doc.a_name):
            if doc.a_kind[a] == 1 and doc.a_owner[a] == i and doc.a_name[a] == String("_netcdf_dim_info"):
                if _starts(doc.a_text[a], String("dims=")):
                    dims_name = _after(doc.a_text[a], String("dims="))
            a += 1
        var is_dim = 0
        var dslot = 0
        while dslot < len(dim_index):
            if dim_index[dslot] == i:
                is_dim = 1
            dslot += 1
        if dims_name.byte_length() == 0 and is_dim == 0:
            i += 1
            continue
        if dims_name.byte_length() == 0 and is_dim != 0:
            # Pure dimension scale, not also a coordinate variable.
            var named = 0
            a = 0
            while a < len(doc.a_name):
                if doc.a_kind[a] == 1 and doc.a_owner[a] == i and doc.a_name[a] == String("units"):
                    named = 1
                a += 1
            if named == 0:
                i += 1
                continue
        var dim = -1
        if dims_name.byte_length() > 0:
            var d = 0
            while d < len(nc.dim_name):
                if nc.dim_name[d] == dims_name:
                    dim = d
                d += 1
        var vals = _f64s_of(doc.d_data[i])
        var vi = nc.add_var(doc.d_name[i], DT_F64, dim, vals^)
        a = 0
        while a < len(doc.a_name):
            if doc.a_kind[a] == 1 and doc.a_owner[a] == i:
                var nm = doc.a_name[a]
                if nm != String("CLASS") and nm != String("NAME") and nm != String("_netcdf_dim_info") and nm != String("_Netcdf4Dimid") and nm != String("_NCProperties"):
                    if doc.a_dtype[a] == 11:
                        nc.add_attr(vi, nm, doc.a_text[a])
            a += 1
        i += 1
    i = 0
    while i < len(doc.a_name):
        if doc.a_kind[i] == 0 and doc.a_owner[i] == 0:
            var nm = doc.a_name[i]
            if nm != String("_NCProperties") and doc.a_dtype[i] == 11:
                nc.add_attr(-1, nm, doc.a_text[i])
        i += 1
    return nc^
