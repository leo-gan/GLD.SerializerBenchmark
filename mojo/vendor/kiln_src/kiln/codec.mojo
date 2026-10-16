from std.builtin.rebind import downcast
from std.collections import Dict, List, Optional, Span
from std.memory import unsafe_memcpy
from std.sys import is_little_endian

from kiln.error import KilnError
from kiln.wire import (
    FRAME_LEN,
    MAX_BYTES,
    MAX_COUNT,
    MAX_DEPTH,
    PROFILE_FROZEN,
    Reader,
    Writer,
)


comptime _Pod = Copyable & Movable
comptime _Init = Defaultable & Movable & Deinitable

# FNV-1a 64. The separator after every token is a zero byte.
comptime _FNV_OFFSET = UInt64(14695981039346656037)
comptime _FNV_PRIME = UInt64(1099511628211)


trait KilnEmit:
    """Container wire format. List, Optional, and Dict conform."""

    def kiln_encode(self, mut w: Writer) raises KilnError:
        ...

    def kiln_size(self) -> Int:
        ...


trait KilnRead:
    """Fill an uninitialized slot from the reader."""

    @staticmethod
    def read_into[
        o: ImmOrigin, po: MutOrigin
    ](mut r: Reader[o], ptr: Pointer[Self, po]) raises KilnError:
        ...


trait KilnHash:
    """Canonical type name for the schema hash. No value is required."""

    @staticmethod
    def kiln_hash(mut h: UInt64):
        ...


trait KilnCodec:
    """Override the derived layout for one user type.

    Scalars, String, List, Optional, and Dict keep the spec layout.
    A struct that conforms uses these methods instead of its fields.
    `kiln_size` must equal the number of bytes `kiln_encode` writes.
    """

    def kiln_encode(self, mut w: Writer) raises KilnError:
        ...

    def kiln_size(self) -> Int:
        ...

    @staticmethod
    def kiln_decode[
        o: ImmOrigin, po: MutOrigin
    ](mut r: Reader[o], ptr: Pointer[Self, po]) raises KilnError:
        ...

    @staticmethod
    def kiln_hash(mut h: UInt64):
        ...


def _mix_span[origin: ImmOrigin](mut h: UInt64, sp: Span[UInt8, origin]):
    var i = 0
    var n = len(sp)
    while i < n:
        h ^= UInt64(sp[i])
        h = h * _FNV_PRIME
        i += 1
    h = h * _FNV_PRIME


def _mix_lit(mut h: UInt64, lit: StringLiteral):
    _mix_span(h, lit.as_bytes())


def _hash_type[T: AnyType](mut h: UInt64):
    comptime if T == Bool:
        _mix_lit(h, "bool")
    elif T == Int8:
        _mix_lit(h, "i8")
    elif T == Int16:
        _mix_lit(h, "i16")
    elif T == Int32:
        _mix_lit(h, "i32")
    elif T == Int64:
        _mix_lit(h, "i64")
    elif T == Int:
        _mix_lit(h, "int")
    elif T == UInt8:
        _mix_lit(h, "u8")
    elif T == UInt16:
        _mix_lit(h, "u16")
    elif T == UInt32:
        _mix_lit(h, "u32")
    elif T == UInt64:
        _mix_lit(h, "u64")
    elif T == UInt:
        _mix_lit(h, "uint")
    elif T == Float32:
        _mix_lit(h, "f32")
    elif T == Float64:
        _mix_lit(h, "f64")
    elif T == String:
        _mix_lit(h, "str")
    elif conforms_to(T, KilnCodec):
        comptime C = downcast[T, KilnCodec]
        C.kiln_hash(h)
    elif conforms_to(T, KilnHash):
        comptime C = downcast[T, KilnHash]
        C.kiln_hash(h)
    elif reflect[T].is_struct():
        _mix_lit(h, "struct{")
        comptime names = reflect[T].field_names()
        comptime types = reflect[T].field_types()
        comptime nfields = reflect[T].field_count()
        comptime for idx in range(nfields):
            comptime fname = names[idx]
            comptime ftype = types[idx]
            _mix_span(h, fname.as_bytes())
            _mix_lit(h, ":")
            _hash_type[ftype](h)
            _mix_lit(h, ",")
        _mix_lit(h, "}")
    else:
        comptime assert False, "kiln: unsupported type " + reflect[T].name()


def type_hash[T: AnyType]() -> UInt64:
    """FNV-1a 64 over the canonical type description."""
    var h = _FNV_OFFSET
    _hash_type[T](h)
    return h


def _write_pod[T: _Pod](mut w: Writer, data: List[T], width: Int) raises KilnError:
    var n = len(data)
    if n > MAX_COUNT:
        raise KilnError(KilnError.LIMIT, w.length)
    var nbytes = n * width
    if nbytes > MAX_BYTES:
        raise KilnError(KilnError.LIMIT, w.length)
    w.put_u32(UInt32(n))
    if nbytes == 0:
        return
    var i = w.reserve(nbytes)
    unsafe_memcpy(
        dest=w.buf.unsafe_ptr().unsafe_offset(i),
        src=data.unsafe_ptr().unsafe_bitcast[UInt8](),
        count=nbytes,
    )


def _read_pod[T: _Pod, o: ImmOrigin](mut r: Reader[o], width: Int) raises KilnError -> List[T]:
    var n = r.count()
    var nbytes = n * width
    if nbytes > r.remaining():
        raise KilnError(KilnError.EOF, r.pos)
    var out = List[T](unsafe_uninit_length=n)
    if nbytes > 0:
        unsafe_memcpy(
            dest=out.unsafe_ptr().unsafe_bitcast[UInt8](),
            src=r.data.unsafe_ptr().unsafe_offset(r.pos),
            count=nbytes,
        )
    r.pos += nbytes
    return out^


def _less(a: String, b: String) -> Bool:
    var ab = a.as_bytes()
    var bb = b.as_bytes()
    var n = len(ab)
    var m = len(bb)
    var k = n
    if m < k:
        k = m
    var i = 0
    while i < k:
        if ab[i] < bb[i]:
            return True
        if ab[i] > bb[i]:
            return False
        i += 1
    return n < m


def _sort_idx(keys: List[String], mut idx: List[Int]):
    var i = 1
    var n = len(idx)
    while i < n:
        var j = i
        while j > 0 and _less(keys[idx[j]], keys[idx[j - 1]]):
            var tmp = idx[j]
            idx[j] = idx[j - 1]
            idx[j - 1] = tmp
            j -= 1
        i += 1


def _poke_type[T: AnyType]() -> Bool:
    """Scalars and strings have a width known before any nested walk."""
    comptime if (
        T == Bool
        or T == Int8
        or T == Int16
        or T == Int32
        or T == Int64
        or T == Int
        or T == UInt8
        or T == UInt16
        or T == UInt32
        or T == UInt64
        or T == UInt
        or T == Float32
        or T == Float64
        or T == String
    ):
        return True
    return False


def _fields_poke[T: AnyType]() -> Bool:
    """True when every field is a scalar or a string, up to 16 fields.

    Wider structs use the checked writer. Recursing on the field index
    crashed the Mojo 1.1 compiler, so the limit is unrolled.
    """
    comptime n = reflect[T].field_count()
    comptime types = reflect[T].field_types()
    comptime if n > 16:
        return False
    comptime if n > 0 and not _poke_type[types[0]]():
        return False
    comptime if n > 1 and not _poke_type[types[1]]():
        return False
    comptime if n > 2 and not _poke_type[types[2]]():
        return False
    comptime if n > 3 and not _poke_type[types[3]]():
        return False
    comptime if n > 4 and not _poke_type[types[4]]():
        return False
    comptime if n > 5 and not _poke_type[types[5]]():
        return False
    comptime if n > 6 and not _poke_type[types[6]]():
        return False
    comptime if n > 7 and not _poke_type[types[7]]():
        return False
    comptime if n > 8 and not _poke_type[types[8]]():
        return False
    comptime if n > 9 and not _poke_type[types[9]]():
        return False
    comptime if n > 10 and not _poke_type[types[10]]():
        return False
    comptime if n > 11 and not _poke_type[types[11]]():
        return False
    comptime if n > 12 and not _poke_type[types[12]]():
        return False
    comptime if n > 13 and not _poke_type[types[13]]():
        return False
    comptime if n > 14 and not _poke_type[types[14]]():
        return False
    comptime if n > 15 and not _poke_type[types[15]]():
        return False
    return True


@always_inline
def _store_u16[o: MutOrigin](p: Pointer[UInt8, o], i: Int, v: UInt16):
    p[unsafe_offset=i] = UInt8(v)
    p[unsafe_offset=i + 1] = UInt8(v >> 8)


@always_inline
def _store_u32[o: MutOrigin](p: Pointer[UInt8, o], i: Int, v: UInt32):
    # Pointer.unsafe_store is the documented unaligned SIMD store.
    # It writes host byte order, so it is the little-endian wire only
    # when the target is little-endian. Byte stores stay for the other case.
    comptime if is_little_endian():
        var q = p.unsafe_offset(i).unsafe_bitcast[Scalar[DType.uint32]]()
        q.unsafe_store[alignment=1](0, v)
    else:
        p[unsafe_offset=i] = UInt8(v)
        p[unsafe_offset=i + 1] = UInt8(v >> 8)
        p[unsafe_offset=i + 2] = UInt8(v >> 16)
        p[unsafe_offset=i + 3] = UInt8(v >> 24)


@always_inline
def _store_u64[o: MutOrigin](p: Pointer[UInt8, o], i: Int, v: UInt64):
    comptime if is_little_endian():
        var q = p.unsafe_offset(i).unsafe_bitcast[Scalar[DType.uint64]]()
        q.unsafe_store[alignment=1](0, v)
    else:
        p[unsafe_offset=i] = UInt8(v)
        p[unsafe_offset=i + 1] = UInt8(v >> 8)
        p[unsafe_offset=i + 2] = UInt8(v >> 16)
        p[unsafe_offset=i + 3] = UInt8(v >> 24)
        p[unsafe_offset=i + 4] = UInt8(v >> 32)
        p[unsafe_offset=i + 5] = UInt8(v >> 40)
        p[unsafe_offset=i + 6] = UInt8(v >> 48)
        p[unsafe_offset=i + 7] = UInt8(v >> 56)


@always_inline
def _poke[T: AnyType, o: MutOrigin](p: Pointer[UInt8, o], mut i: Int, value: T):
    """Store one scalar or string. The caller has already reserved the bytes."""
    comptime if T == Bool:
        if rebind[Bool](value):
            p[unsafe_offset=i] = UInt8(1)
        else:
            p[unsafe_offset=i] = UInt8(0)
        i += 1
    elif T == Int8:
        p[unsafe_offset=i] = UInt8(rebind[Int8](value).to_bits())
        i += 1
    elif T == Int16:
        _store_u16(p, i, UInt16(rebind[Int16](value).to_bits()))
        i += 2
    elif T == Int32:
        _store_u32(p, i, UInt32(rebind[Int32](value).to_bits()))
        i += 4
    elif T == Int64:
        _store_u64(p, i, UInt64(rebind[Int64](value).to_bits()))
        i += 8
    elif T == Int:
        _store_u64(p, i, UInt64(Int64(rebind[Int](value)).to_bits()))
        i += 8
    elif T == UInt8:
        p[unsafe_offset=i] = rebind[UInt8](value)
        i += 1
    elif T == UInt16:
        _store_u16(p, i, rebind[UInt16](value))
        i += 2
    elif T == UInt32:
        _store_u32(p, i, rebind[UInt32](value))
        i += 4
    elif T == UInt64:
        _store_u64(p, i, rebind[UInt64](value))
        i += 8
    elif T == UInt:
        _store_u64(p, i, UInt64(rebind[UInt](value)))
        i += 8
    elif T == Float32:
        _store_u32(p, i, UInt32(rebind[Float32](value).to_bits()))
        i += 4
    elif T == Float64:
        _store_u64(p, i, UInt64(rebind[Float64](value).to_bits()))
        i += 8
    elif T == String:
        var sp = rebind[String](value).as_bytes()
        var n = len(sp)
        _store_u32(p, i, UInt32(n))
        i += 4
        if n > 0:
            unsafe_memcpy(dest=p.unsafe_offset(i), src=sp.unsafe_ptr(), count=n)
            i += n
    else:
        comptime assert False, "kiln: poke is only for scalars and strings"


@always_inline
def encoded_size[T: AnyType](value: T) -> Int:
    comptime if T == Bool or T == Int8 or T == UInt8:
        return 1
    elif T == Int16 or T == UInt16:
        return 2
    elif T == Int32 or T == UInt32 or T == Float32:
        return 4
    elif T == Int64 or T == UInt64 or T == Int or T == UInt or T == Float64:
        return 8
    elif T == String:
        return 4 + len(rebind[String](value).as_bytes())
    elif conforms_to(T, KilnCodec):
        return rebind[downcast[T, KilnCodec]](value).kiln_size()
    elif conforms_to(T, KilnEmit):
        return rebind[downcast[T, KilnEmit]](value).kiln_size()
    elif reflect[T].is_struct():
        return _size_struct[T](value)
    else:
        comptime assert False, "kiln: unsupported type " + reflect[T].name()
        return 0


@always_inline
def _size_struct[T: AnyType](value: T) -> Int:
    comptime types = reflect[T].field_types()
    comptime nfields = reflect[T].field_count()
    var n = 0
    comptime for idx in range(nfields):
        comptime ft = types[idx]
        ref field = reflect[T].field_ref[idx](value)
        n += encoded_size[ft](rebind[ft](field))
    return n


@always_inline
def _write[T: AnyType](mut w: Writer, value: T) raises KilnError:
    comptime if T == Bool:
        if rebind[Bool](value):
            w.put_u8(UInt8(1))
        else:
            w.put_u8(UInt8(0))
    elif T == Int8:
        w.put_u8(UInt8(rebind[Int8](value).to_bits()))
    elif T == Int16:
        w.put_u16(UInt16(rebind[Int16](value).to_bits()))
    elif T == Int32:
        w.put_i32(rebind[Int32](value))
    elif T == Int64:
        w.put_i64(rebind[Int64](value))
    elif T == Int:
        w.put_i64(Int64(rebind[Int](value)))
    elif T == UInt8:
        w.put_u8(rebind[UInt8](value))
    elif T == UInt16:
        w.put_u16(rebind[UInt16](value))
    elif T == UInt32:
        w.put_u32(rebind[UInt32](value))
    elif T == UInt64:
        w.put_u64(rebind[UInt64](value))
    elif T == UInt:
        w.put_u64(UInt64(rebind[UInt](value)))
    elif T == Float32:
        w.put_f32(rebind[Float32](value))
    elif T == Float64:
        w.put_f64(rebind[Float64](value))
    elif T == String:
        var sp = rebind[String](value).as_bytes()
        var n = len(sp)
        if n > MAX_BYTES:
            raise KilnError(KilnError.LIMIT, w.length)
        w.put_u32(UInt32(n))
        w.put_span(sp)
    elif conforms_to(T, KilnCodec):
        rebind[downcast[T, KilnCodec]](value).kiln_encode(w)
    elif conforms_to(T, KilnEmit):
        rebind[downcast[T, KilnEmit]](value).kiln_encode(w)
    elif reflect[T].is_struct():
        _write_struct[T](w, value)
    else:
        comptime assert False, "kiln: unsupported type " + reflect[T].name()


@always_inline
def _write_struct[T: AnyType](mut w: Writer, value: T) raises KilnError:
    w.enter()
    comptime types = reflect[T].field_types()
    comptime nfields = reflect[T].field_count()
    # One capacity check for a leaf struct, then straight-line stores.
    # A nested list or struct keeps the checked writer so a short field
    # cannot reserve past the bytes this value actually owns.
    comptime if _fields_poke[T]():
        var need = _size_struct[T](value)
        if need > MAX_BYTES:
            raise KilnError(KilnError.LIMIT, w.length)
        w.ensure(need)
        var i = w.length
        var p = w.buf.unsafe_ptr()
        comptime for idx in range(nfields):
            comptime ft = types[idx]
            ref field = reflect[T].field_ref[idx](value)
            _poke[ft](p, i, rebind[ft](field))
        w.length = i
    else:
        comptime for idx in range(nfields):
            comptime ft = types[idx]
            ref field = reflect[T].field_ref[idx](value)
            _write[ft](w, rebind[ft](field))
    w.leave()


@always_inline
def _fill[T: AnyType, o: ImmOrigin, po: MutOrigin](
    mut r: Reader[o], ptr: Pointer[T, po]
) raises KilnError:
    comptime if T == Bool:
        var p = ptr.unsafe_bitcast[Bool]()
        p.unsafe_write(r.boolean())
    elif T == Int8:
        var p = ptr.unsafe_bitcast[Int8]()
        p.unsafe_write(Int8(from_bits=r.u8()))
    elif T == Int16:
        var p = ptr.unsafe_bitcast[Int16]()
        p.unsafe_write(Int16(from_bits=r.u16()))
    elif T == Int32:
        var p = ptr.unsafe_bitcast[Int32]()
        p.unsafe_write(r.i32())
    elif T == Int64:
        var p = ptr.unsafe_bitcast[Int64]()
        p.unsafe_write(r.i64())
    elif T == Int:
        var p = ptr.unsafe_bitcast[Int]()
        p.unsafe_write(Int(r.i64()))
    elif T == UInt8:
        var p = ptr.unsafe_bitcast[UInt8]()
        p.unsafe_write(r.u8())
    elif T == UInt16:
        var p = ptr.unsafe_bitcast[UInt16]()
        p.unsafe_write(r.u16())
    elif T == UInt32:
        var p = ptr.unsafe_bitcast[UInt32]()
        p.unsafe_write(r.u32())
    elif T == UInt64:
        var p = ptr.unsafe_bitcast[UInt64]()
        p.unsafe_write(r.u64())
    elif T == UInt:
        var p = ptr.unsafe_bitcast[UInt]()
        p.unsafe_write(UInt(r.u64()))
    elif T == Float32:
        var p = ptr.unsafe_bitcast[Float32]()
        p.unsafe_write(r.f32())
    elif T == Float64:
        var p = ptr.unsafe_bitcast[Float64]()
        p.unsafe_write(r.f64())
    elif T == String:
        var sp = ptr.unsafe_bitcast[String]()
        sp.unsafe_deinit_pointee()
        sp.unsafe_write(r.read_string())
    elif conforms_to(T, KilnCodec):
        comptime C = downcast[T, KilnCodec & Deinitable]
        var sp = ptr.unsafe_bitcast[C]()
        sp.unsafe_deinit_pointee()
        C.kiln_decode(r, sp)
    elif conforms_to(T, KilnRead):
        comptime C = downcast[T, KilnRead & Deinitable]
        var sp = ptr.unsafe_bitcast[C]()
        sp.unsafe_deinit_pointee()
        C.read_into(r, sp)
    elif reflect[T].is_struct():
        _fill_struct[T](r, ptr)
    else:
        comptime assert False, "kiln: unsupported type " + reflect[T].name()


@always_inline
def _fill_struct[T: AnyType, o: ImmOrigin, po: MutOrigin](
    mut r: Reader[o], ptr: Pointer[T, po]
) raises KilnError:
    r.enter()
    comptime types = reflect[T].field_types()
    comptime nfields = reflect[T].field_count()
    ref target = ptr[]
    comptime for idx in range(nfields):
        comptime ft = types[idx]
        ref field = reflect[T].field_ref[idx](target)
        _fill[ft](r, Pointer(to=field).unsafe_bitcast[ft]())
    r.leave()


def encode[T: AnyType](value: T, mut w: Writer, max_depth: Int = MAX_DEPTH) raises KilnError:
    """Encode `value` into `w`, replacing any bytes already written.

    The writer keeps its allocation. A later call reuses that storage
    when the new value fits.
    """
    w.length = 0
    encode_append[T](value, w, max_depth)


def encode_append[T: AnyType](value: T, mut w: Writer, max_depth: Int = MAX_DEPTH) raises KilnError:
    """Append one value. Does not clear bytes already written."""
    w.depth = 0
    w.max_depth = max_depth
    _write[T](w, value)


def encode_bytes[T: AnyType](value: T, max_depth: Int = MAX_DEPTH) raises KilnError -> List[UInt8]:
    var w = Writer(encoded_size[T](value) + 8)
    encode[T](value, w, max_depth)
    return w.copy_bytes()


def decode[
    T: Defaultable & Movable & Deinitable, o: ImmOrigin
](data: Span[UInt8, o], check_utf8: Bool = True, max_depth: Int = MAX_DEPTH) raises KilnError -> T:
    """Decode one value. The buffer must hold that value and nothing after it."""
    var r = Reader[o](data, check_utf8, max_depth)
    var out = T()
    _fill[T](r, Pointer(to=out))
    if r.pos != len(data):
        raise KilnError(KilnError.TRAILING, r.pos)
    return out^


def decode_bytes[
    T: Defaultable & Movable & Deinitable
](data: List[UInt8], check_utf8: Bool = True, max_depth: Int = MAX_DEPTH) raises KilnError -> T:
    return decode[T](Span(data), check_utf8, max_depth)


def encode_framed[T: AnyType](value: T, mut w: Writer, max_depth: Int = MAX_DEPTH) raises KilnError:
    """Write a 16-byte KLN0 header and one Frozen value."""
    w.length = 0
    w.depth = 0
    w.max_depth = max_depth
    w.ensure(FRAME_LEN + encoded_size[T](value))
    w.put_u8(UInt8(0x4B))
    w.put_u8(UInt8(0x4C))
    w.put_u8(UInt8(0x4E))
    w.put_u8(UInt8(0x30))
    w.put_u8(UInt8(PROFILE_FROZEN))
    w.put_u8(UInt8(0))
    w.put_u16(UInt16(0))
    w.put_u64(type_hash[T]())
    _write[T](w, value)


def decode_framed[
    T: Defaultable & Movable & Deinitable, o: ImmOrigin
](data: Span[UInt8, o], check_utf8: Bool = True, max_depth: Int = MAX_DEPTH) raises KilnError -> T:
    if len(data) < FRAME_LEN:
        raise KilnError(KilnError.FRAME, 0)
    if (
        data[0] != UInt8(0x4B)
        or data[1] != UInt8(0x4C)
        or data[2] != UInt8(0x4E)
        or data[3] != UInt8(0x30)
    ):
        raise KilnError(KilnError.FRAME, 0)
    var r = Reader[o](data, check_utf8, max_depth)
    r.pos = 4
    var profile = r.u8()
    if Int(profile) != PROFILE_FROZEN:
        raise KilnError(KilnError.FRAME, 4)
    _ = r.u8()
    _ = r.u16()
    var got = r.u64()
    if got != type_hash[T]():
        raise KilnError(KilnError.SCHEMA, 8)
    var out = T()
    _fill[T](r, Pointer(to=out))
    if r.pos != len(data):
        raise KilnError(KilnError.TRAILING, r.pos)
    return out^


def _pod_arm[T: AnyType]() -> Int:
    comptime if T == Int8 or T == UInt8:
        return 1
    elif T == Int16 or T == UInt16:
        return 2
    elif T == Int32 or T == UInt32 or T == Float32:
        return 4
    elif T == Int64 or T == UInt64 or T == Int or T == UInt or T == Float64:
        return 8
    else:
        return 0


__extension List(KilnEmit, KilnRead, KilnHash):
    def kiln_size(self) -> Int:
        comptime width = _pod_arm[Self.T]()
        comptime if width > 0:
            return 4 + len(self) * width
        else:
            var n = 4
            var i = 0
            while i < len(self):
                n += encoded_size[Self.T](self[i])
                i += 1
            return n

    def kiln_encode(self, mut w: Writer) raises KilnError:
        w.enter()
        var width = _pod_arm[Self.T]()
        if width > 0:
            var n = len(self)
            if n > MAX_COUNT:
                raise KilnError(KilnError.LIMIT, w.length)
            var nbytes = n * width
            if nbytes > MAX_BYTES:
                raise KilnError(KilnError.LIMIT, w.length)
            w.put_u32(UInt32(n))
            if nbytes > 0:
                var at = w.reserve(nbytes)
                unsafe_memcpy(
                    dest=w.buf.unsafe_ptr().unsafe_offset(at),
                    src=self.unsafe_ptr().unsafe_bitcast[UInt8](),
                    count=nbytes,
                )
        else:
            var n = len(self)
            if n > MAX_COUNT:
                raise KilnError(KilnError.LIMIT, w.length)
            w.put_u32(UInt32(n))
            var i = 0
            while i < n:
                _write[Self.T](w, self[i])
                i += 1
        w.leave()

    @staticmethod
    def read_into[
        o: ImmOrigin, po: MutOrigin
    ](mut r: Reader[o], ptr: Pointer[Self, po]) raises KilnError:
        r.enter()
        var width = _pod_arm[Self.T]()
        if width > 0:
            comptime E = downcast[Self.T, Copyable & Deinitable]
            var n = r.count()
            var nbytes = n * width
            if nbytes > r.remaining():
                raise KilnError(KilnError.EOF, r.pos)
            var out = List[E](unsafe_uninit_length=n)
            if nbytes > 0:
                unsafe_memcpy(
                    dest=out.unsafe_ptr().unsafe_bitcast[UInt8](),
                    src=r.data.unsafe_ptr().unsafe_offset(r.pos),
                    count=nbytes,
                )
            r.pos += nbytes
            ptr.unsafe_bitcast[List[E]]().unsafe_write(out^)
        else:
            comptime E = downcast[Self.T, _Init]
            var n = r.count()
            var out = List[E]()
            if n > 0:
                out.reserve(n)
            var i = 0
            while i < n:
                var item = E()
                _fill[E](r, Pointer(to=item))
                out.append(item^)
                i += 1
            ptr.unsafe_bitcast[List[E]]().unsafe_write(out^)
        r.leave()

    @staticmethod
    def kiln_hash(mut h: UInt64):
        _mix_lit(h, "list<")
        _hash_type[Self.T](h)
        _mix_lit(h, ">")


__extension Optional(KilnEmit, KilnRead, KilnHash):
    def kiln_size(self) -> Int:
        if self:
            return 1 + encoded_size(self.value())
        return 1

    def kiln_encode(self, mut w: Writer) raises KilnError:
        w.enter()
        if self:
            w.put_u8(UInt8(1))
            _write(w, self.value())
        else:
            w.put_u8(UInt8(0))
        w.leave()

    @staticmethod
    def read_into[
        o: ImmOrigin, po: MutOrigin
    ](mut r: Reader[o], ptr: Pointer[Self, po]) raises KilnError:
        r.enter()
        comptime E = downcast[Self.T, _Init]
        var tag = Int(r.u8())
        if tag == 0:
            ptr.unsafe_bitcast[Optional[E]]().unsafe_write(Optional[E](None))
            r.leave()
            return
        if tag != 1:
            raise KilnError(KilnError.TYPE, r.pos - 1)
        var item = E()
        _fill[E](r, Pointer(to=item))
        ptr.unsafe_bitcast[Optional[E]]().unsafe_write(Optional[E](item^))
        r.leave()

    @staticmethod
    def kiln_hash(mut h: UInt64):
        _mix_lit(h, "opt<")
        _hash_type[Self.T](h)
        _mix_lit(h, ">")


__extension Dict(KilnEmit, KilnRead, KilnHash):
    def kiln_size(self) -> Int:
        comptime if Self.K != String:
            comptime assert False, "Kiln Dict keys are String"
            return 0
        else:
            var n = 4
            for entry in self.items():
                n += encoded_size(rebind[String](entry.key))
                n += encoded_size(entry.value)
            return n

    def kiln_encode(self, mut w: Writer) raises KilnError:
        comptime if Self.K != String:
            comptime assert False, "Kiln Dict keys are String"
        else:
            w.enter()
            comptime V = downcast[Self.V, Copyable & Deinitable]
            var vals = List[V]()
            var keys = List[String]()
            var idx = List[Int]()
            var n = 0
            for entry in self.items():
                keys.append(rebind[String](entry.key))
                vals.append(rebind[V](entry.value).copy())
                idx.append(n)
                n += 1
            if n > MAX_COUNT:
                raise KilnError(KilnError.LIMIT, w.length)
            _sort_idx(keys, idx)
            w.put_u32(UInt32(n))
            var i = 0
            while i < n:
                var key = keys[idx[i]]
                _write[String](w, key)
                _write[V](w, vals[idx[i]])
                i += 1
            w.leave()

    @staticmethod
    def read_into[
        o: ImmOrigin, po: MutOrigin
    ](mut r: Reader[o], ptr: Pointer[Self, po]) raises KilnError:
        comptime if Self.K != String:
            comptime assert False, "Kiln Dict keys are String"
        else:
            r.enter()
            comptime V = downcast[Self.V, _Init]
            var n = r.count()
            var out = Dict[String, V]()
            var i = 0
            while i < n:
                var key = r.read_string()
                var item = V()
                _fill[V](r, Pointer(to=item))
                out[key] = item^
                i += 1
            ptr.unsafe_bitcast[Dict[String, V]]().unsafe_write(out^)
            r.leave()

    @staticmethod
    def kiln_hash(mut h: UInt64):
        comptime if Self.K != String:
            comptime assert False, "Kiln Dict keys are String"
        else:
            _mix_lit(h, "dict<str,")
            _hash_type[Self.V](h)
            _mix_lit(h, ">")
