from std.collections import List, Span
from std.memory import unsafe_memcpy
from std.sys import is_little_endian

from kiln.codec import KilnCodec, KilnMin, _mix_lit
from kiln.error import KilnError
from kiln.utf8 import string_from_span, utf8_ok
from kiln.wire import Writer, Reader


comptime TENSOR_HEADER = 64
comptime DESC_BYTES = 128
comptime DTYPE_F64 = 1
comptime DTYPE_F32 = 2
comptime DTYPE_F16 = 3
comptime DTYPE_BF16 = 4
comptime DTYPE_F8E4M3 = 5
comptime DTYPE_F8E5M2 = 6
comptime DTYPE_BOOL = 7
comptime DTYPE_I8 = 8
comptime DTYPE_U8 = 9
comptime DTYPE_I16 = 10
comptime DTYPE_U16 = 11
comptime DTYPE_I32 = 12
comptime DTYPE_U32 = 13
comptime DTYPE_I64 = 14
comptime DTYPE_U64 = 15
comptime DTYPE_I4 = 16
comptime DTYPE_U4 = 17
comptime DTYPE_E2M1 = 18
comptime DTYPE_E8M0 = 19
comptime OPAQUE_MIN = 4096
comptime OPAQUE_MAX = 32767
comptime FLAG_NAME = 1
comptime FLAG_LE = 2


def _align64(n: Int) -> Int:
    return (n + 63) & ~63


def _u_add(a: UInt64, b: UInt64, at: Int) raises KilnError -> UInt64:
    if a > (~UInt64(0)) - b:
        raise KilnError(KilnError.LIMIT, at)
    return a + b


def _u_mul(a: UInt64, b: UInt64, at: Int) raises KilnError -> UInt64:
    if a != 0 and b > (~UInt64(0)) // a:
        raise KilnError(KilnError.LIMIT, at)
    return a * b


def _as_int(n: UInt64, at: Int) raises KilnError -> Int:
    if n > UInt64(0x7FFFFFFFFFFFFFFF):
        raise KilnError(KilnError.LIMIT, at)
    return Int(n)


def _u16_at[o: ImmOrigin](data: Span[UInt8, o], i: Int) -> UInt16:
    return UInt16(data[i]) | (UInt16(data[i + 1]) << 8)


def _u32_at[o: ImmOrigin](data: Span[UInt8, o], i: Int) -> UInt32:
    return (
        UInt32(data[i])
        | (UInt32(data[i + 1]) << 8)
        | (UInt32(data[i + 2]) << 16)
        | (UInt32(data[i + 3]) << 24)
    )


def _u64_at[o: ImmOrigin](data: Span[UInt8, o], i: Int) -> UInt64:
    var v = UInt64(data[i])
    v = v | (UInt64(data[i + 1]) << 8)
    v = v | (UInt64(data[i + 2]) << 16)
    v = v | (UInt64(data[i + 3]) << 24)
    v = v | (UInt64(data[i + 4]) << 32)
    v = v | (UInt64(data[i + 5]) << 40)
    v = v | (UInt64(data[i + 6]) << 48)
    v = v | (UInt64(data[i + 7]) << 56)
    return v


def _whole_width(dtype: Int) -> Int:
    if dtype == DTYPE_F64 or dtype == DTYPE_I64 or dtype == DTYPE_U64:
        return 8
    if dtype == DTYPE_F32 or dtype == DTYPE_I32 or dtype == DTYPE_U32:
        return 4
    if dtype == DTYPE_F16 or dtype == DTYPE_BF16 or dtype == DTYPE_I16 or dtype == DTYPE_U16:
        return 2
    if (
        dtype == DTYPE_F8E4M3
        or dtype == DTYPE_F8E5M2
        or dtype == DTYPE_BOOL
        or dtype == DTYPE_I8
        or dtype == DTYPE_U8
        or dtype == DTYPE_E8M0
    ):
        return 1
    return 0


def _packed(dtype: Int) -> Bool:
    return dtype == DTYPE_I4 or dtype == DTYPE_U4 or dtype == DTYPE_E2M1


def _elems(rank: Int, shape: List[UInt64], at: Int) raises KilnError -> UInt64:
    if rank == 0:
        return 1
    var count = UInt64(1)
    var i = 0
    while i < rank:
        count = _u_mul(count, shape[i], at)
        i += 1
    return count


def _append_bytes[o: ImmOrigin](mut heap: List[UInt8], sp: Span[UInt8, o]):
    var i = 0
    while i < len(sp):
        heap.append(sp[i])
        i += 1


struct KilnTensor(Copyable, Movable):
    """One tensor in a version-2 directory.

    `shape` has `rank` entries. Rank 0 is a scalar and `shape` is empty.
    `data` is the payload bytes in wire order. An empty `name` is an
    unnamed tensor. `scale_index` and `outer_index` are -1 when absent.
    `quant_axis` is -1 when `quant_scheme` is 0.
    """

    var dtype: Int
    var rank: Int
    var shape: List[UInt64]
    var name: String
    var layout: String
    var block_size: Int
    var quant_scheme: Int
    var quant_axis: Int
    var group_size: Int
    var scale_index: Int
    var outer_index: Int
    var data: List[UInt8]

    def __init__(out self):
        self.dtype = 0
        self.rank = 0
        self.shape = List[UInt64]()
        self.name = ""
        self.layout = ""
        self.block_size = 0
        self.quant_scheme = 0
        self.quant_axis = -1
        self.group_size = 0
        self.scale_index = -1
        self.outer_index = -1
        self.data = List[UInt8]()

    def __init__(out self, dtype: Int, var shape: List[UInt64], var data: List[UInt8]):
        self.dtype = dtype
        self.rank = len(shape)
        self.shape = shape^
        self.name = ""
        self.layout = ""
        self.block_size = 0
        self.quant_scheme = 0
        self.quant_axis = -1
        self.group_size = 0
        self.scale_index = -1
        self.outer_index = -1
        self.data = data^


struct _Raw(Copyable, Movable):
    var dtype: Int
    var rank: Int
    var reserved: Int
    var name_off: Int
    var name_len: Int
    var layout_off: Int
    var layout_len: Int
    var block_size: Int
    var quant_scheme: Int
    var quant_axis: Int
    var group_size: Int
    var scale_index: Int
    var outer_index: Int
    var byte_offset: Int
    var byte_length: Int
    var shape: List[UInt64]
    var name: String
    var layout: String

    def __init__(out self):
        self.dtype = 0
        self.rank = 0
        self.reserved = 0
        self.name_off = 0
        self.name_len = 0
        self.layout_off = 0
        self.layout_len = 0
        self.block_size = 0
        self.quant_scheme = 0
        self.quant_axis = 0
        self.group_size = 0
        self.scale_index = 0
        self.outer_index = 0
        self.byte_offset = 0
        self.byte_length = 0
        self.shape = List[UInt64]()
        self.name = ""
        self.layout = ""


def _check_meta(item: _Raw, at: Int) raises KilnError:
    if item.rank > 8:
        raise KilnError(KilnError.TYPE, at)
    var dtype = item.dtype
    if dtype == 0 or (dtype >= 20 and dtype < OPAQUE_MIN) or dtype > OPAQUE_MAX:
        raise KilnError(KilnError.TYPE, at)
    var count = _elems(item.rank, item.shape, at)
    if dtype >= OPAQUE_MIN:
        if len(item.layout.as_bytes()) == 0 or item.block_size == 0:
            raise KilnError(KilnError.TYPE, at)
        if item.block_size < 0 or item.byte_length % item.block_size != 0:
            raise KilnError(KilnError.TYPE, at)
        return
    if len(item.layout.as_bytes()) != 0 or item.block_size != 0:
        raise KilnError(KilnError.TYPE, at)
    var expect: UInt64
    var width = _whole_width(dtype)
    if width > 0:
        expect = _u_mul(count, UInt64(width), at)
    elif _packed(dtype):
        expect = (count + 1) // 2
    else:
        raise KilnError(KilnError.TYPE, at)
    if UInt64(item.byte_length) != expect:
        raise KilnError(KilnError.TYPE, at)


def _check_quant(raw: List[_Raw], at: Int) raises KilnError:
    var i = 0
    while i < len(raw):
        var item = raw[i].copy()
        if item.quant_scheme == 0:
            if (
                item.group_size != 0
                or item.quant_axis != -1
                or item.scale_index != -1
                or item.outer_index != -1
            ):
                raise KilnError(KilnError.TYPE, at)
            i += 1
            continue
        if item.quant_scheme != 1 and item.quant_scheme != 2:
            raise KilnError(KilnError.TYPE, at)
        if item.rank == 0 or item.quant_axis < 0 or item.quant_axis >= item.rank:
            raise KilnError(KilnError.TYPE, at)
        if item.group_size <= 0:
            raise KilnError(KilnError.TYPE, at)
        var scale = item.scale_index
        if scale == i or scale < 0 or scale >= len(raw):
            raise KilnError(KilnError.TYPE, at)
        var other = raw[scale].copy()
        if other.quant_scheme != 0:
            raise KilnError(KilnError.TYPE, at)
        var axis_n = item.shape[item.quant_axis]
        var g = UInt64(item.group_size)
        var groups = axis_n // g
        if axis_n % g != 0:
            groups = _u_add(groups, 1, at)
        var other_dims = UInt64(1)
        var dim = 0
        while dim < item.rank:
            if dim != item.quant_axis:
                other_dims = _u_mul(other_dims, item.shape[dim], at)
            dim += 1
        var expect = _u_mul(groups, other_dims, at)
        var scale_count = _elems(other.rank, other.shape, at)
        if scale_count != expect:
            raise KilnError(KilnError.TYPE, at)
        if item.quant_scheme == 1:
            if item.outer_index != -1:
                raise KilnError(KilnError.TYPE, at)
            i += 1
            continue
        var outer = item.outer_index
        if outer == i or outer == scale or outer < 0 or outer >= len(raw):
            raise KilnError(KilnError.TYPE, at)
        var outer_item = raw[outer].copy()
        if outer_item.quant_scheme != 0 or outer_item.dtype != DTYPE_F32:
            raise KilnError(KilnError.TYPE, at)
        if _elems(outer_item.rank, outer_item.shape, at) != 1:
            raise KilnError(KilnError.TYPE, at)
        i += 1


def _index_or_none(v: Int, none: Int) -> Int:
    if v == none:
        return -1
    return v


struct TensorDir(Copyable, Movable, Defaultable, KilnCodec, KilnMin):
    """A version-2 tensor directory. The canonical hash token is `tensors`."""

    var items: List[KilnTensor]

    def __init__(out self):
        self.items = List[KilnTensor]()

    @staticmethod
    def kiln_min() -> Int:
        return TENSOR_HEADER

    @staticmethod
    def kiln_hash(mut h: UInt64):
        _mix_lit(h, "tensors")

    def kiln_size(self) -> Int:
        var n = len(self.items)
        var name_bytes = 0
        var i = 0
        while i < n:
            name_bytes += len(self.items[i].name.as_bytes())
            name_bytes += len(self.items[i].layout.as_bytes())
            i += 1
        var directory = n * DESC_BYTES + name_bytes
        var end = 0
        i = 0
        while i < n:
            end = _align64(end)
            end += len(self.items[i].data)
            i += 1
        return _align64(TENSOR_HEADER + directory) + end

    def kiln_encode(self, mut w: Writer) raises KilnError:
        w.enter()
        var n = len(self.items)
        if n > w.max_count:
            raise KilnError(KilnError.LIMIT, w.length)
        var named = 0
        var i = 0
        while i < n:
            if len(self.items[i].name.as_bytes()) > 0:
                named += 1
            if self.items[i].rank != len(self.items[i].shape) or self.items[i].rank > 8:
                raise KilnError(KilnError.TYPE, w.length)
            i += 1
        if named != 0 and named != n:
            raise KilnError(KilnError.TYPE, w.length)
        var heap = List[UInt8]()
        var name_off = List[Int]()
        var name_len = List[Int]()
        i = 0
        while i < n:
            var sp = self.items[i].name.as_bytes()
            if len(sp) == 0:
                name_off.append(-1)
                name_len.append(0)
            else:
                name_off.append(len(heap))
                name_len.append(len(sp))
                _append_bytes(heap, sp)
            i += 1
        var layout_off = List[Int]()
        var layout_len = List[Int]()
        i = 0
        while i < n:
            var sp = self.items[i].layout.as_bytes()
            if len(sp) == 0:
                layout_off.append(-1)
                layout_len.append(0)
            else:
                layout_off.append(len(heap))
                layout_len.append(len(sp))
                _append_bytes(heap, sp)
            i += 1
        if len(heap) > w.max_bytes:
            raise KilnError(KilnError.LIMIT, w.length)
        var offsets = List[Int]()
        var end = 0
        i = 0
        while i < n:
            var off = _align64(end)
            offsets.append(off)
            end = off + len(self.items[i].data)
            i += 1
        if end > w.max_bytes:
            raise KilnError(KilnError.LIMIT, w.length)
        var flags = FLAG_LE
        if named != 0:
            flags |= FLAG_NAME
        var directory = n * DESC_BYTES + len(heap)
        var payload_base = _align64(TENSOR_HEADER + directory)
        w.put_u8(UInt8(0x4B))
        w.put_u8(UInt8(0x4C))
        w.put_u8(UInt8(0x4E))
        w.put_u8(UInt8(0x54))
        w.put_u8(UInt8(2))
        w.put_u8(UInt8(flags))
        w.put_u16(UInt16(0))
        w.put_u32(UInt32(n))
        w.put_u32(UInt32(len(heap)))
        w.put_u64(UInt64(end))
        w.put_u64(UInt64(directory))
        var pad_header = TENSOR_HEADER - 32
        var z = 0
        while z < pad_header:
            w.put_u8(UInt8(0))
            z += 1
        i = 0
        while i < n:
            w.put_u16(UInt16(self.items[i].dtype))
            w.put_u8(UInt8(self.items[i].rank))
            w.put_u8(UInt8(0))
            if name_len[i] == 0:
                w.put_u16(UInt16(0xFFFF))
                w.put_u16(UInt16(0))
            else:
                w.put_u16(UInt16(name_off[i]))
                w.put_u16(UInt16(name_len[i]))
            if layout_len[i] == 0:
                w.put_u16(UInt16(0xFFFF))
                w.put_u16(UInt16(0))
            else:
                w.put_u16(UInt16(layout_off[i]))
                w.put_u16(UInt16(layout_len[i]))
            w.put_u32(UInt32(self.items[i].block_size))
            w.put_u16(UInt16(self.items[i].quant_scheme))
            if self.items[i].quant_axis < 0:
                w.put_u16(UInt16(0xFFFF))
            else:
                w.put_u16(UInt16(self.items[i].quant_axis))
            w.put_u32(UInt32(self.items[i].group_size))
            if self.items[i].scale_index < 0:
                w.put_u32(UInt32(0xFFFFFFFF))
            else:
                w.put_u32(UInt32(self.items[i].scale_index))
            if self.items[i].outer_index < 0:
                w.put_u32(UInt32(0xFFFFFFFF))
            else:
                w.put_u32(UInt32(self.items[i].outer_index))
            w.put_u64(UInt64(offsets[i]))
            w.put_u64(UInt64(len(self.items[i].data)))
            var d = 0
            while d < 8:
                var dim = UInt64(0)
                if d < len(self.items[i].shape):
                    dim = self.items[i].shape[d]
                w.put_u64(dim)
                d += 1
            var rsv = 0
            while rsv < 16:
                w.put_u8(UInt8(0))
                rsv += 1
            i += 1
        if len(heap) > 0:
            var at = w.reserve(len(heap))
            unsafe_memcpy(
                dest=w.buf.unsafe_ptr().unsafe_offset(at),
                src=heap.unsafe_ptr(),
                count=len(heap),
            )
        var cursor = TENSOR_HEADER + directory
        while cursor < payload_base:
            w.put_u8(UInt8(0))
            cursor += 1
        var written = 0
        i = 0
        while i < n:
            var off = offsets[i]
            while written < off:
                w.put_u8(UInt8(0))
                written += 1
            var nbytes = len(self.items[i].data)
            if nbytes > 0:
                var at = w.reserve(nbytes)
                unsafe_memcpy(
                    dest=w.buf.unsafe_ptr().unsafe_offset(at),
                    src=self.items[i].data.unsafe_ptr(),
                    count=nbytes,
                )
            written = off + nbytes
            i += 1
        w.leave()

    @staticmethod
    def kiln_decode[
        o: ImmOrigin, po: MutOrigin
    ](mut r: Reader[o], ptr: Pointer[Self, po]) raises KilnError:
        var dir = _decode_dir(r)
        ptr.unsafe_write(dir^)


def _decode_dir[o: ImmOrigin](mut r: Reader[o]) raises KilnError -> TensorDir:
    r.enter()
    var base = r.pos
    var rest = len(r.data) - base
    if rest < 4:
        raise KilnError(KilnError.EOF, base)
    var data = r.data
    if (
        data[base] != UInt8(0x4B)
        or data[base + 1] != UInt8(0x4C)
        or data[base + 2] != UInt8(0x4E)
        or data[base + 3] != UInt8(0x54)
    ):
        raise KilnError(KilnError.FRAME, base)
    if rest < TENSOR_HEADER:
        raise KilnError(KilnError.EOF, base)
    if data[base + 4] != UInt8(2):
        raise KilnError(KilnError.FRAME, base + 4)
    var flags = Int(data[base + 5])
    if (flags & ~3) != 0 or (flags & FLAG_LE) == 0:
        raise KilnError(KilnError.FRAME, base + 5)
    if _u16_at(data, base + 6) != 0:
        raise KilnError(KilnError.FRAME, base + 6)
    var reserved_i = 0
    while reserved_i < 32:
        if data[base + 32 + reserved_i] != 0:
            raise KilnError(KilnError.FRAME, base + 32 + reserved_i)
        reserved_i += 1
    var count_u = _u32_at(data, base + 8)
    var name_bytes_u = _u32_at(data, base + 12)
    var payload_bytes_u = _u64_at(data, base + 16)
    var directory_bytes_u = _u64_at(data, base + 24)
    if Int(count_u) > r.max_count or Int(name_bytes_u) > r.max_bytes:
        raise KilnError(KilnError.LIMIT, base + 8)
    var expect_dir = _u_add(_u_mul(UInt64(count_u), UInt64(DESC_BYTES), base), UInt64(name_bytes_u), base)
    if directory_bytes_u != expect_dir:
        raise KilnError(KilnError.TYPE, base + 24)
    var directory_end = _u_add(UInt64(TENSOR_HEADER), directory_bytes_u, base)
    if directory_end > UInt64(rest):
        raise KilnError(KilnError.EOF, base + TENSOR_HEADER)
    var payload_base_u = _u_add(directory_end, 63, base) & ~UInt64(63)
    var block_end_u = _u_add(payload_base_u, payload_bytes_u, base)
    if block_end_u > UInt64(rest):
        raise KilnError(KilnError.EOF, base)
    var directory_end_i = _as_int(directory_end, base)
    var payload_base = _as_int(payload_base_u, base)
    var block_end = _as_int(block_end_u, base)
    var payload_bytes = _as_int(payload_bytes_u, base)
    var count = Int(count_u)
    var name_bytes = Int(name_bytes_u)
    var pad_i = directory_end_i
    while pad_i < payload_base:
        if data[base + pad_i] != 0:
            raise KilnError(KilnError.TYPE, base + pad_i)
        pad_i += 1
    if payload_bytes > r.max_bytes:
        raise KilnError(KilnError.LIMIT, base + 16)
    var raw = List[_Raw]()
    var t = 0
    while t < count:
        var at = base + TENSOR_HEADER + t * DESC_BYTES
        var item = _Raw()
        item.dtype = Int(_u16_at(data, at))
        item.rank = Int(data[at + 2])
        item.reserved = Int(data[at + 3])
        item.name_off = Int(_u16_at(data, at + 4))
        item.name_len = Int(_u16_at(data, at + 6))
        item.layout_off = Int(_u16_at(data, at + 8))
        item.layout_len = Int(_u16_at(data, at + 10))
        item.block_size = Int(_u32_at(data, at + 12))
        item.quant_scheme = Int(_u16_at(data, at + 16))
        item.quant_axis = _index_or_none(Int(_u16_at(data, at + 18)), 0xFFFF)
        item.group_size = Int(_u32_at(data, at + 20))
        item.scale_index = _index_or_none(Int(_u32_at(data, at + 24)), 0xFFFFFFFF)
        item.outer_index = _index_or_none(Int(_u32_at(data, at + 28)), 0xFFFFFFFF)
        item.byte_offset = _as_int(_u64_at(data, at + 32), at)
        item.byte_length = _as_int(_u64_at(data, at + 40), at)
        var d = 0
        while d < 8:
            item.shape.append(_u64_at(data, at + 48 + 8 * d))
            d += 1
        var tail = 0
        while tail < 16:
            if data[at + 112 + tail] != 0:
                raise KilnError(KilnError.FRAME, at + 112 + tail)
            tail += 1
        raw.append(item^)
        t += 1
    var names_flag = (flags & FLAG_NAME) != 0
    var has_name = False
    t = 0
    while t < count:
        if raw[t].name_len != 0:
            has_name = True
        t += 1
    if names_flag != has_name:
        raise KilnError(KilnError.TYPE, base + 5)
    var heap_at = base + TENSOR_HEADER + count * DESC_BYTES
    var expect_heap = List[UInt8]()
    var seen = List[String]()
    t = 0
    while t < len(raw):
        var item = raw[t].copy()
        if item.reserved != 0:
            raise KilnError(KilnError.FRAME, base + TENSOR_HEADER + t * DESC_BYTES + 3)
        if names_flag and item.name_len == 0:
            raise KilnError(KilnError.TYPE, base + 5)
        if item.name_len == 0:
            if item.name_off != 0xFFFF:
                raise KilnError(KilnError.TYPE, heap_at)
        else:
            if item.name_off == 0xFFFF or item.name_off + item.name_len > name_bytes:
                raise KilnError(KilnError.TYPE, heap_at)
            var sp = data[heap_at + item.name_off : heap_at + item.name_off + item.name_len]
            if not utf8_ok(sp):
                raise KilnError(KilnError.UTF8, heap_at + item.name_off)
            var name = string_from_span(sp, heap_at + item.name_off, False)
            var s = 0
            while s < len(seen):
                if seen[s] == name:
                    raise KilnError(KilnError.TYPE, heap_at + item.name_off)
                s += 1
            seen.append(name)
            item.name = name^
            _append_bytes(expect_heap, sp)
        raw[t] = item^
        t += 1
    t = 0
    while t < len(raw):
        var item = raw[t].copy()
        if item.layout_len == 0:
            if item.layout_off != 0xFFFF:
                raise KilnError(KilnError.TYPE, heap_at)
        else:
            if item.layout_off + item.layout_len > name_bytes:
                raise KilnError(KilnError.TYPE, heap_at)
            var sp = data[heap_at + item.layout_off : heap_at + item.layout_off + item.layout_len]
            if not utf8_ok(sp):
                raise KilnError(KilnError.UTF8, heap_at + item.layout_off)
            var layout = string_from_span(sp, heap_at + item.layout_off, False)
            item.layout = layout^
            _append_bytes(expect_heap, sp)
        raw[t] = item^
        t += 1
    if len(expect_heap) != name_bytes:
        raise KilnError(KilnError.TYPE, heap_at)
    var h = 0
    while h < name_bytes:
        if expect_heap[h] != data[heap_at + h]:
            raise KilnError(KilnError.TYPE, heap_at + h)
        h += 1
    # Shape tails are stored in the 8 slots. Keep rank entries for the value.
    t = 0
    while t < len(raw):
        var item = raw[t].copy()
        var d = item.rank
        while d < 8:
            if d >= 0 and item.shape[d] != 0:
                raise KilnError(KilnError.TYPE, base)
            d += 1
        var end = _u_add(UInt64(item.byte_offset), UInt64(item.byte_length), base)
        if _as_int(end, base) > payload_bytes:
            raise KilnError(KilnError.TYPE, base)
        _check_meta(item, base)
        t += 1
    var a = 0
    while a < len(raw):
        var b = a + 1
        while b < len(raw):
            var a0 = raw[a].byte_offset
            var a1 = a0 + raw[a].byte_length
            var b0 = raw[b].byte_offset
            var b1 = b0 + raw[b].byte_length
            if raw[a].byte_length != 0 and raw[b].byte_length != 0 and a0 < b1 and b0 < a1:
                raise KilnError(KilnError.TYPE, base)
            b += 1
        a += 1
    var running = 0
    t = 0
    while t < len(raw):
        if raw[t].byte_offset != _align64(running):
            raise KilnError(KilnError.TYPE, base)
        running = raw[t].byte_offset + raw[t].byte_length
        t += 1
    if running != payload_bytes:
        raise KilnError(KilnError.TYPE, base + 16)
    var payload_at = base + payload_base
    t = 0
    while t < len(raw):
        var item = raw[t].copy()
        var region = data[payload_at + item.byte_offset : payload_at + item.byte_offset + item.byte_length]
        if _packed(item.dtype):
            var n = _elems(item.rank, item.shape, base)
            if n % 2 == 1 and len(region) > 0 and (Int(region[len(region) - 1]) >> 4) != 0:
                raise KilnError(KilnError.TYPE, payload_at + item.byte_offset)
        if item.dtype == DTYPE_BOOL:
            var bi = 0
            while bi < len(region):
                if region[bi] > 1:
                    raise KilnError(KilnError.TYPE, payload_at + item.byte_offset + bi)
                bi += 1
        t += 1
    var covered = List[UInt8]()
    var c = 0
    while c < payload_bytes:
        covered.append(UInt8(0))
        c += 1
    t = 0
    while t < len(raw):
        var start = raw[t].byte_offset
        var n = raw[t].byte_length
        var k = 0
        while k < n:
            covered[start + k] = 1
            k += 1
        t += 1
    c = 0
    while c < payload_bytes:
        if covered[c] == 0 and data[payload_at + c] != 0:
            raise KilnError(KilnError.TYPE, payload_at + c)
        c += 1
    _check_quant(raw, base)
    var out = TensorDir()
    t = 0
    while t < len(raw):
        var item = raw[t].copy()
        var tensor = KilnTensor()
        tensor.dtype = item.dtype
        tensor.rank = item.rank
        var d = 0
        while d < item.rank:
            tensor.shape.append(item.shape[d])
            d += 1
        tensor.name = item.name
        tensor.layout = item.layout
        tensor.block_size = item.block_size
        tensor.quant_scheme = item.quant_scheme
        tensor.quant_axis = item.quant_axis
        tensor.group_size = item.group_size
        tensor.scale_index = item.scale_index
        tensor.outer_index = item.outer_index
        var nbytes = item.byte_length
        if nbytes > 0:
            var copied = List[UInt8](unsafe_uninit_length=nbytes)
            unsafe_memcpy(
                dest=copied.unsafe_ptr(),
                src=data.unsafe_ptr().unsafe_offset(payload_at + item.byte_offset),
                count=nbytes,
            )
            tensor.data = copied^
        out.items.append(tensor^)
        t += 1
    r.pos = base + block_end
    r.leave()
    return out^


def f64_directory(data: List[Float64]) -> TensorDir:
    """One unnamed `f64` tensor whose payload is the list's little-endian bits."""
    comptime if not is_little_endian():
        comptime assert False, "kiln: Float64 tensor copy requires a little-endian host"
    var nbytes = len(data) * 8
    var raw = List[UInt8](unsafe_uninit_length=nbytes)
    if nbytes > 0:
        unsafe_memcpy(
            dest=raw.unsafe_ptr(),
            src=data.unsafe_ptr().unsafe_bitcast[UInt8](),
            count=nbytes,
        )
    var shape = List[UInt64]()
    shape.append(UInt64(len(data)))
    var tensor = KilnTensor(DTYPE_F64, shape^, raw^)
    var dir = TensorDir()
    dir.items.append(tensor^)
    return dir^
