from std.collections import List

from hdf5_runtime.bytes import append_f64
from hdf5_runtime.error import FormatError


comptime DT_I8 = 1
comptime DT_I16 = 2
comptime DT_I32 = 3
comptime DT_I64 = 4
comptime DT_U8 = 5
comptime DT_U16 = 6
comptime DT_U32 = 7
comptime DT_U64 = 8
comptime DT_F32 = 9
comptime DT_F64 = 10
comptime DT_STR = 11

comptime SUPERBLOCK_VERSION = 0


def elem_size(dt: Int) -> Int:
    if dt == DT_I8 or dt == DT_U8:
        return 1
    if dt == DT_I16 or dt == DT_U16:
        return 2
    if dt == DT_I32 or dt == DT_U32 or dt == DT_F32:
        return 4
    if dt == DT_I64 or dt == DT_U64 or dt == DT_F64:
        return 8
    return 0


def dtype_name(dt: Int) -> String:
    if dt == DT_I8:
        return String("int8")
    if dt == DT_I16:
        return String("int16")
    if dt == DT_I32:
        return String("int32")
    if dt == DT_I64:
        return String("int64")
    if dt == DT_U8:
        return String("uint8")
    if dt == DT_U16:
        return String("uint16")
    if dt == DT_U32:
        return String("uint32")
    if dt == DT_U64:
        return String("uint64")
    if dt == DT_F32:
        return String("float32")
    if dt == DT_F64:
        return String("float64")
    if dt == DT_STR:
        return String("string")
    return String("unknown")


struct H5Doc:
    """In-memory HDF5 file. Group 0 is the root and has an empty name.

    Links are stored by parent index. Dataset bytes are the logical array in
    C order, little-endian, with no chunk padding.
    """

    var g_name: List[String]
    var g_parent: List[Int]
    var d_name: List[String]
    var d_parent: List[Int]
    var d_dtype: List[Int]
    var d_rank: List[Int]
    var d_n0: List[Int]
    var d_n1: List[Int]
    var d_chunked: List[Int]
    var d_c0: List[Int]
    var d_c1: List[Int]
    var d_gzip: List[Int]
    var d_data: List[List[Byte]]
    var a_kind: List[Int]
    var a_owner: List[Int]
    var a_name: List[String]
    var a_dtype: List[Int]
    var a_text: List[String]
    var a_raw: List[List[Byte]]

    def __init__(out self):
        self.g_name = List[String]()
        self.g_parent = List[Int]()
        self.d_name = List[String]()
        self.d_parent = List[Int]()
        self.d_dtype = List[Int]()
        self.d_rank = List[Int]()
        self.d_n0 = List[Int]()
        self.d_n1 = List[Int]()
        self.d_chunked = List[Int]()
        self.d_c0 = List[Int]()
        self.d_c1 = List[Int]()
        self.d_gzip = List[Int]()
        self.d_data = List[List[Byte]]()
        self.a_kind = List[Int]()
        self.a_owner = List[Int]()
        self.a_name = List[String]()
        self.a_dtype = List[Int]()
        self.a_text = List[String]()
        self.a_raw = List[List[Byte]]()

    def add_group(mut self, parent: Int, name: String) -> Int:
        var idx = len(self.g_name)
        self.g_name.append(name)
        self.g_parent.append(parent)
        return idx

    def add_dataset(
        mut self,
        parent: Int,
        name: String,
        dtype: Int,
        rank: Int,
        n0: Int,
        n1: Int,
        var data: List[Byte],
        chunked: Int,
        c0: Int,
        c1: Int,
        gzip: Int,
    ) -> Int:
        var idx = len(self.d_name)
        self.d_name.append(name)
        self.d_parent.append(parent)
        self.d_dtype.append(dtype)
        self.d_rank.append(rank)
        self.d_n0.append(n0)
        self.d_n1.append(n1)
        self.d_chunked.append(chunked)
        self.d_c0.append(c0)
        self.d_c1.append(c1)
        self.d_gzip.append(gzip)
        self.d_data.append(data^)
        return idx

    def add_f64(
        mut self,
        parent: Int,
        name: String,
        vals: List[Float64],
        chunk0: Int,
        gzip: Int,
    ) -> Int:
        var raw = List[Byte]()
        var i = 0
        while i < len(vals):
            append_f64(raw, vals[i])
            i += 1
        var chunked = 0
        if chunk0 > 0:
            chunked = 1
        return self.add_dataset(parent, name, DT_F64, 1, len(vals), 0, raw^, chunked, chunk0, 0, gzip)

    def add_f64_2d(
        mut self,
        parent: Int,
        name: String,
        rows: Int,
        cols: Int,
        vals: List[Float64],
        chunk_r: Int,
        chunk_c: Int,
        gzip: Int,
    ) raises -> Int:
        if len(vals) != rows * cols:
            raise FormatError(0, String("float64 matrix length does not match the shape"))
        var raw = List[Byte]()
        var i = 0
        while i < len(vals):
            append_f64(raw, vals[i])
            i += 1
        var chunked = 0
        if chunk_r > 0 and chunk_c > 0:
            chunked = 1
        return self.add_dataset(parent, name, DT_F64, 2, rows, cols, raw^, chunked, chunk_r, chunk_c, gzip)

    def _attr(mut self, kind: Int, owner: Int, name: String, dtype: Int, text: String, raw: List[Byte]):
        self.a_kind.append(kind)
        self.a_owner.append(owner)
        self.a_name.append(name)
        self.a_dtype.append(dtype)
        self.a_text.append(text)
        self.a_raw.append(raw.copy())

    def add_num_attr_group(mut self, group: Int, name: String, dtype: Int, raw: List[Byte]):
        self._attr(0, group, name, dtype, String(), raw)

    def add_num_attr_dataset(mut self, dataset: Int, name: String, dtype: Int, raw: List[Byte]):
        self._attr(1, dataset, name, dtype, String(), raw)

    def add_text_attr_group(mut self, group: Int, name: String, text: String):
        var raw = List[Byte]()
        var b = text.as_bytes()
        var i = 0
        while i < len(b):
            raw.append(b[i])
            i += 1
        raw.append(Byte(0))
        self._attr(0, group, name, DT_STR, text, raw)

    def add_text_attr_dataset(mut self, dataset: Int, name: String, text: String):
        var raw = List[Byte]()
        var b = text.as_bytes()
        var i = 0
        while i < len(b):
            raw.append(b[i])
            i += 1
        raw.append(Byte(0))
        self._attr(1, dataset, name, DT_STR, text, raw)


struct NcFile:
    """Classic or NetCDF-4 document. Dimensions are named lengths.

    Variables are numeric arrays. `var_dim` is -1 for a scalar and otherwise
    an index into `dim_name`. Attributes with `attr_var` -1 are global.
    """

    var dim_name: List[String]
    var dim_len: List[Int]
    var var_name: List[String]
    var var_type: List[Int]
    var var_dim: List[Int]
    var var_data: List[List[Float64]]
    var attr_var: List[Int]
    var attr_name: List[String]
    var attr_text: List[String]

    def __init__(out self):
        self.dim_name = List[String]()
        self.dim_len = List[Int]()
        self.var_name = List[String]()
        self.var_type = List[Int]()
        self.var_dim = List[Int]()
        self.var_data = List[List[Float64]]()
        self.attr_var = List[Int]()
        self.attr_name = List[String]()
        self.attr_text = List[String]()

    def add_dim(mut self, name: String, length: Int) -> Int:
        var idx = len(self.dim_name)
        self.dim_name.append(name)
        self.dim_len.append(length)
        return idx

    def add_var(mut self, name: String, dtype: Int, dim: Int, data: List[Float64]) -> Int:
        var idx = len(self.var_name)
        self.var_name.append(name)
        self.var_type.append(dtype)
        self.var_dim.append(dim)
        self.var_data.append(data.copy())
        return idx

    def add_attr(mut self, owner: Int, name: String, text: String):
        self.attr_var.append(owner)
        self.attr_name.append(name)
        self.attr_text.append(text)


struct BpStep:
    """One ADIOS step: a 1-D float64 variable and one string attribute."""

    var var_name: String
    var values: List[Float64]
    var attr_name: String
    var attr_text: String

    def __init__(out self):
        self.var_name = String()
        self.values = List[Float64]()
        self.attr_name = String()
        self.attr_text = String()
