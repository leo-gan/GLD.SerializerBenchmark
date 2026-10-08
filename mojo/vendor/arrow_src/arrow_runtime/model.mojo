from std.collections import List, Span

from arrow_runtime.buf import put_i32, put_i64, put_u32, put_u64
from arrow_runtime.error import DecodeError


comptime TY_NULL = 1
comptime TY_BOOL = 2
comptime TY_INT = 3
comptime TY_FLOAT = 4
comptime TY_BINARY = 5
comptime TY_UTF8 = 6
comptime TY_DECIMAL = 7
comptime TY_DATE = 8
comptime TY_TIME = 9
comptime TY_TIMESTAMP = 10
comptime TY_INTERVAL = 11
comptime TY_LIST = 12
comptime TY_STRUCT = 13
comptime TY_UNION = 14
comptime TY_FIXED_BINARY = 15
comptime TY_FIXED_LIST = 16
comptime TY_MAP = 17
comptime TY_DURATION = 18
comptime TY_LARGE_BINARY = 19
comptime TY_LARGE_UTF8 = 20
comptime TY_LARGE_LIST = 21
comptime TY_RUN_END = 22
comptime TY_BINARY_VIEW = 23
comptime TY_UTF8_VIEW = 24
comptime TY_LIST_VIEW = 25
comptime TY_LARGE_LIST_VIEW = 26

comptime MAX_DEPTH = 64


struct FieldRec(Copyable, ImplicitlyCopyable):
    var name: Int
    var nullable: Int
    var kind: Int
    var bit_width: Int
    var is_signed: Int
    var precision: Int
    var scale: Int
    var unit: Int
    var timezone: Int
    var union_mode: Int
    var type_ids0: Int
    var n_type_ids: Int
    var child0: Int
    var nchild: Int
    var meta0: Int
    var nmeta: Int
    var dict_id: Int
    var dict_index_width: Int
    var dict_index_signed: Int
    var dict_ordered: Int
    var keys_sorted: Int
    var fixed_size: Int

    def __init__(out self):
        self.name = -1
        self.nullable = 1
        self.kind = TY_NULL
        self.bit_width = 0
        self.is_signed = 1
        self.precision = 0
        self.scale = 0
        self.unit = 0
        self.timezone = -1
        self.union_mode = 0
        self.type_ids0 = 0
        self.n_type_ids = 0
        self.child0 = 0
        self.nchild = 0
        self.meta0 = 0
        self.nmeta = 0
        self.dict_id = -1
        self.dict_index_width = 32
        self.dict_index_signed = 1
        self.dict_ordered = 0
        self.keys_sorted = 0
        self.fixed_size = 0


struct BufRec(Copyable, ImplicitlyCopyable):
    var off: Int
    var length: Int

    def __init__(out self, off: Int, length: Int):
        self.off = off
        self.length = length


struct ArrayRec(Copyable, ImplicitlyCopyable):
    var field: Int
    var length: Int
    var null_count: Int
    var buf0: Int
    var nbuf: Int
    var child0: Int
    var nchild: Int
    var dict: Int

    def __init__(out self):
        self.field = -1
        self.length = 0
        self.null_count = 0
        self.buf0 = 0
        self.nbuf = 0
        self.child0 = 0
        self.nchild = 0
        self.dict = -1


struct BatchRec(Copyable, ImplicitlyCopyable):
    var length: Int
    var col0: Int
    var ncol: Int
    var codec: Int

    def __init__(out self, length: Int, col0: Int, ncol: Int, codec: Int = -1):
        self.length = length
        self.col0 = col0
        self.ncol = ncol
        self.codec = codec


struct DictRec(Copyable, ImplicitlyCopyable):
    var id: Int
    var array: Int
    var is_delta: Int
    var batch_index: Int

    def __init__(out self, id: Int, array: Int, is_delta: Int, batch_index: Int):
        self.id = id
        self.array = array
        self.is_delta = is_delta
        self.batch_index = batch_index


struct TensorRec(Copyable, ImplicitlyCopyable):
    var field: Int
    var shape0: Int
    var nshape: Int
    var stride0: Int
    var nstride: Int
    var data_buf: Int
    var sparse_kind: Int
    var index_buf0: Int
    var nindex: Int
    var nz: Int
    var coo_canonical: Int
    var csx_axis: Int
    var index_width: Int
    var index_signed: Int

    def __init__(out self):
        self.field = -1
        self.shape0 = 0
        self.nshape = 0
        self.stride0 = 0
        self.nstride = 0
        self.data_buf = -1
        self.sparse_kind = 0
        self.index_buf0 = 0
        self.nindex = 0
        self.nz = 0
        self.coo_canonical = 0
        self.csx_axis = 0
        self.index_width = 64
        self.index_signed = 1


struct Columnar:
    var strings: List[String]
    var fields: List[FieldRec]
    var kids: List[Int]
    var type_ids: List[Int]
    var meta_k: List[Int]
    var meta_v: List[Int]
    var top: List[Int]
    var endian: Int
    var features: Int
    var schema_meta0: Int
    var nschema_meta: Int
    var bufs: List[BufRec]
    var bytes: List[Byte]
    var abufs: List[Int]
    var achilds: List[Int]
    var arrays: List[ArrayRec]
    var batches: List[BatchRec]
    var batch_cols: List[Int]
    var dicts: List[DictRec]
    var shapes: List[Int]
    var shape_names: List[Int]
    var strides: List[Int]
    var tensors: List[TensorRec]
    var codec: Int

    def __init__(out self):
        self.strings = List[String]()
        self.fields = List[FieldRec]()
        self.kids = List[Int]()
        self.type_ids = List[Int]()
        self.meta_k = List[Int]()
        self.meta_v = List[Int]()
        self.top = List[Int]()
        self.endian = 0
        self.features = 0
        self.schema_meta0 = 0
        self.nschema_meta = 0
        self.bufs = List[BufRec]()
        self.bytes = List[Byte]()
        self.abufs = List[Int]()
        self.achilds = List[Int]()
        self.arrays = List[ArrayRec]()
        self.batches = List[BatchRec]()
        self.batch_cols = List[Int]()
        self.dicts = List[DictRec]()
        self.shapes = List[Int]()
        self.shape_names = List[Int]()
        self.strides = List[Int]()
        self.tensors = List[TensorRec]()
        self.codec = -1

    def intern(mut self, text: String) -> Int:
        var i = 0
        while i < len(self.strings):
            if self.strings[i] == text:
                return i
            i += 1
        self.strings.append(text)
        return len(self.strings) - 1

    def add_field(mut self, f: FieldRec) -> Int:
        self.fields.append(f)
        return len(self.fields) - 1

    def add_top(mut self, field_id: Int):
        self.top.append(field_id)

    def add_buf[origin: ImmOrigin](mut self, raw: Span[Byte, origin]) -> Int:
        var id = len(self.bufs)
        var off = len(self.bytes)
        var n = len(raw)
        if n > 0:
            self.bytes.resize(off + n, Byte(0))
            var i = 0
            while i < n:
                self.bytes[off + i] = raw[i]
                i += 1
        self.bufs.append(BufRec(off, n))
        return id

    def add_buf_list(mut self, raw: List[Byte]) -> Int:
        return self.add_buf(Span(raw))

    def add_buf_at[origin: ImmOrigin](mut self, raw: Span[Byte, origin], off: Int, n: Int) -> Int:
        var id = len(self.bufs)
        var dest = len(self.bytes)
        if n > 0:
            self.bytes.resize(dest + n, Byte(0))
            var i = 0
            while i < n:
                self.bytes[dest + i] = raw[off + i]
                i += 1
        self.bufs.append(BufRec(dest if n > 0 else 0, n))
        return id

    def add_empty_buf(mut self) -> Int:
        var id = len(self.bufs)
        self.bufs.append(BufRec(0, 0))
        return id

    def buf_copy(self, id: Int) -> List[Byte]:
        var out = List[Byte]()
        if id < 0:
            return out^
        var b = self.bufs[id]
        if b.length <= 0:
            return out^
        out.resize(b.length, Byte(0))
        var i = 0
        while i < b.length:
            out[i] = self.bytes[b.off + i]
            i += 1
        return out^

    def add_meta(mut self, key: String, value: String) -> Int:
        var at = len(self.meta_k)
        self.meta_k.append(self.intern(key))
        self.meta_v.append(self.intern(value))
        return at

    def push_array(mut self, a: ArrayRec) -> Int:
        self.arrays.append(a)
        return len(self.arrays) - 1

    def add_batch(mut self, length: Int, cols: List[Int]):
        var rec = BatchRec(length, len(self.batch_cols), len(cols), self.codec)
        var i = 0
        while i < len(cols):
            self.batch_cols.append(cols[i])
            i += 1
        self.batches.append(rec)


def bit_get(raw: List[Byte], i: Int) -> Bool:
    var b = Int(raw[i // 8])
    return ((b >> (i % 8)) & 1) != 0


def bit_set(mut raw: List[Byte], i: Int):
    var at = i // 8
    var b = Int(raw[at])
    b = b | (1 << (i % 8))
    raw[at] = Byte(b)


def bitmap_bytes(n: Int, nulls: List[Int]) -> List[Byte]:
    var out = List[Byte]()
    var nbytes = (n + 7) // 8
    var i = 0
    while i < nbytes:
        out.append(Byte(0))
        i += 1
    i = 0
    while i < n:
        if i >= len(nulls) or nulls[i] == 0:
            bit_set(out, i)
        i += 1
    return out^


def null_count_of(nulls: List[Int], n: Int) -> Int:
    var c = 0
    var i = 0
    while i < n:
        if i < len(nulls) and nulls[i] != 0:
            c += 1
        i += 1
    return c


def put_width(mut raw: List[Byte], v: Int, width: Int):
    if width == 1:
        raw.append(Byte(v & 255))
    elif width == 2:
        raw.append(Byte(v & 255))
        raw.append(Byte((v >> 8) & 255))
    elif width == 4:
        put_i32(raw, v)
    else:
        put_i64(raw, v)


def put_width_u(mut raw: List[Byte], v: UInt64, width: Int):
    if width == 1:
        raw.append(Byte(Int(v & 0xFF)))
    elif width == 2:
        var x = v
        raw.append(Byte(Int(x & 0xFF)))
        x = x >> 8
        raw.append(Byte(Int(x & 0xFF)))
    elif width == 4:
        put_u32(raw, Int(v & 0xFFFFFFFF))
    else:
        put_u64(raw, v)


def read_width(raw: List[Byte], at: Int, width: Int, signed: Bool) raises DecodeError -> Int:
    if at < 0 or at + width > len(raw):
        raise DecodeError(DecodeError.KIND_EOF, at)
    if width == 1:
        var u = Int(raw[at])
        if signed and u >= 128:
            return u - 256
        return u
    if width == 2:
        var u = Int(raw[at]) | (Int(raw[at + 1]) << 8)
        if signed and u >= 32768:
            return u - 65536
        return u
    if width == 4:
        var u = Int(raw[at]) | (Int(raw[at + 1]) << 8) | (Int(raw[at + 2]) << 16) | (Int(raw[at + 3]) << 24)
        if signed and u >= 2147483648:
            return u - 4294967296
        return u
    var x = UInt64(0)
    var k = 7
    while k >= 0:
        x = (x << 8) | UInt64(Int(raw[at + k]))
        k -= 1
    return Int(x)


def byte_width_of(f: FieldRec) -> Int:
    if f.kind == TY_BOOL:
        return 0
    if f.kind == TY_INT or f.kind == TY_DATE or f.kind == TY_TIME or f.kind == TY_TIMESTAMP or f.kind == TY_DURATION:
        if f.kind == TY_DATE:
            if f.unit == 0:
                return 4
            return 8
        if f.kind == TY_TIME:
            if f.unit <= 1:
                return 4
            return 8
        if f.kind == TY_INT:
            return f.bit_width // 8
        return 8
    if f.kind == TY_FLOAT:
        if f.unit == 0:
            return 2
        if f.unit == 1:
            return 4
        return 8
    if f.kind == TY_DECIMAL or f.kind == TY_FIXED_BINARY:
        if f.kind == TY_DECIMAL:
            return f.bit_width // 8
        return f.fixed_size
    if f.kind == TY_INTERVAL:
        if f.unit == 0:
            return 4
        if f.unit == 1:
            return 8
        return 16
    return 0


def is_variadic(kind: Int) -> Bool:
    return kind == TY_BINARY_VIEW or kind == TY_UTF8_VIEW


def has_validity(kind: Int) -> Bool:
    if kind == TY_NULL or kind == TY_UNION or kind == TY_RUN_END:
        return False
    return True


def swap_fixed(mut raw: List[Byte], width: Int):
    if width <= 1:
        return
    var i = 0
    while i + width <= len(raw):
        var a = 0
        var b = width - 1
        while a < b:
            var t = raw[i + a]
            raw[i + a] = raw[i + b]
            raw[i + b] = t
            a += 1
            b -= 1
        i += width


def f16_to_f64(h: Int) -> Float64:
    var sign = (h >> 15) & 1
    var exp = (h >> 10) & 31
    var frac = h & 1023
    var bits = UInt64(0)
    if sign != 0:
        bits = UInt64(1) << 63
    if exp == 0:
        if frac == 0:
            return Float64(from_bits=bits)
        var e = -14
        while (frac & 1024) == 0:
            frac = frac << 1
            e -= 1
        frac = frac & 1023
        var eb = UInt64(e + 1023)
        bits = bits | (eb << 52) | (UInt64(frac) << 42)
        return Float64(from_bits=bits)
    if exp == 31:
        bits = bits | (UInt64(2047) << 52) | (UInt64(frac) << 42)
        return Float64(from_bits=bits)
    var eb = UInt64(exp - 15 + 1023)
    bits = bits | (eb << 52) | (UInt64(frac) << 42)
    return Float64(from_bits=bits)


def f64_to_f16(v: Float64) -> Int:
    var bits = UInt64(v.to_bits())
    var sign = Int((bits >> 63) & 1)
    var exp = Int((bits >> 52) & 2047)
    var frac = bits & 0x000FFFFFFFFFFFFF
    var out = sign << 15
    if exp == 2047:
        var f = 0
        if frac != 0:
            f = 512
        return out | (31 << 10) | f
    var unbiased = exp - 1023
    if exp == 0:
        return out
    if unbiased > 15:
        return out | (31 << 10)
    if unbiased < -14:
        return out
    var e = unbiased + 15
    var f = Int((frac >> 42) & 1023)
    return out | (e << 10) | f
