from std.collections import Span

from fb_wire.scalar import (
    int_from_i32,
    load_u16,
    load_u32,
    load_u64,
    read_bool,
    read_f32,
    read_f64,
    read_i16,
    read_i32,
    read_i64,
    read_i8,
    read_u16,
    read_u32,
    read_u64,
    read_u8,
)


def root_pos[origin: ImmOrigin](data: Span[Byte, origin], size_prefixed: Bool) raises -> Int:
    """Return the absolute position of the root table."""
    var base = 0
    if size_prefixed:
        if len(data) < 8:
            raise Error("truncated")
        base = 4
    else:
        if len(data) < 4:
            raise Error("truncated")
    var rel = Int(read_u32(data, base))
    var pos = base + rel
    if rel < 4 or pos < 0 or pos + 4 > len(data):
        raise Error("bad root")
    return pos


def file_identifier[origin: ImmOrigin](data: Span[Byte, origin]) raises -> String:
    """Four bytes after the root uoffset. Empty when the buffer is shorter."""
    if len(data) < 8:
        raise Error("truncated")
    return String(from_utf8=data[4:8])


def field_voffset[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int) raises -> Int:
    """Byte offset of field `id` inside the table object, or 0 when absent."""
    if table < 0 or table + 4 > len(data):
        raise Error("truncated")
    var raw_soff = read_i32(data, table)
    var soff = int_from_i32(raw_soff)
    var vtable = table - soff
    if vtable < 0 or vtable + 4 > len(data):
        raise Error("bad vtable")
    var vbytes = Int(read_u16(data, vtable))
    if vbytes < 4 or vtable + vbytes > len(data):
        raise Error("bad vtable")
    var entry = 4 + 2 * id
    if entry >= vbytes:
        return 0
    return Int(read_u16(data, vtable + entry))


struct TableRef[origin: ImmOrigin]:
    """One table with its vtable loaded once.

    Generated views call `field_voffset` per field, which re-reads the vtable
    header every time. This cursor pays that cost once, then each field is a
    16-bit load.
    """

    var data: Span[Byte, Self.origin]
    var table: Int
    var vt: Int
    var vbytes: Int

    def __init__(out self, data: Span[Byte, Self.origin], table: Int) raises:
        self.data = data
        self.table = table
        if table < 0 or table + 4 > len(data):
            raise Error("truncated")
        var soff = int_from_i32(read_i32(data, table))
        var vtable = table - soff
        if vtable < 0 or vtable + 4 > len(data):
            raise Error("bad vtable")
        var vbytes = Int(load_u16(data, vtable))
        if vbytes < 4 or vtable + vbytes > len(data):
            raise Error("bad vtable")
        self.vt = vtable
        self.vbytes = vbytes

    def off(self, id: Int) -> Int:
        var entry = 4 + 2 * id
        if entry >= self.vbytes:
            return 0
        return Int(load_u16(self.data, self.vt + entry))

    def i32(self, id: Int, default: Int32) -> Int32:
        var o = self.off(id)
        if o == 0:
            return default
        return Int32(load_u32(self.data, self.table + o))

    def i64(self, id: Int, default: Int64) -> Int64:
        var o = self.off(id)
        if o == 0:
            return default
        return Int64(load_u64(self.data, self.table + o))

    def f64(self, id: Int, default: Float64) -> Float64:
        var o = self.off(id)
        if o == 0:
            return default
        return Float64(from_bits=load_u64(self.data, self.table + o))

    def boolean(self, id: Int, default: Bool) -> Bool:
        var o = self.off(id)
        if o == 0:
            return default
        return UInt8(self.data[self.table + o]) != 0

    def uoffset(self, id: Int) raises -> Int:
        var o = self.off(id)
        if o == 0:
            return -1
        var pos = self.table + o
        var rel = Int(load_u32(self.data, pos))
        var dest = pos + rel
        if rel < 4 or dest < 0 or dest > len(self.data):
            raise Error("bad offset")
        return dest

    def string(self, id: Int) raises -> String:
        var pos = self.uoffset(id)
        if pos < 0:
            return String()
        return read_string_at(self.data, pos)


def indirect[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> Int:
    var rel = Int(read_u32(data, pos))
    var dest = pos + rel
    if rel < 4 or dest < 0 or dest > len(data):
        raise Error("bad offset")
    return dest


def indirect_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int) raises -> Int:
    """Absolute position of a uoffset field, or -1 when the field is absent."""
    var off = field_voffset(data, table, id)
    if off == 0:
        return -1
    return indirect(data, table + off)


def read_string_at[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> String:
    var n = Int(read_u32(data, pos))
    if n < 0 or pos + 4 + n + 1 > len(data):
        raise Error("bad string")
    if data[pos + 4 + n] != 0:
        raise Error("bad string")
    if n == 0:
        return String()
    # Length and the trailing NUL are already checked. Skip the UTF-8 scan.
    return String(unsafe_from_utf8=data[pos + 4 : pos + 4 + n])


def vector_len[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> Int:
    return Int(read_u32(data, pos))


def vector_elem[origin: ImmOrigin](data: Span[Byte, origin], pos: Int, index: Int, width: Int) raises -> Int:
    var n = vector_len(data, pos)
    if index < 0 or index >= n:
        raise Error("vector index")
    var at = pos + 4 + index * width
    if at < 0 or at + width > len(data):
        raise Error("truncated")
    return at


def vector_offset_at[origin: ImmOrigin](data: Span[Byte, origin], pos: Int, index: Int) raises -> Int:
    var slot = vector_elem(data, pos, index, 4)
    return indirect(data, slot)


def read_i32_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: Int32) raises -> Int32:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_i32(data, table + off)


def read_u32_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: UInt32) raises -> UInt32:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_u32(data, table + off)


def read_i64_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: Int64) raises -> Int64:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_i64(data, table + off)


def read_u64_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: UInt64) raises -> UInt64:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_u64(data, table + off)


def read_i16_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: Int16) raises -> Int16:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_i16(data, table + off)


def read_u16_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: UInt16) raises -> UInt16:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_u16(data, table + off)


def read_i8_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: Int8) raises -> Int8:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_i8(data, table + off)


def read_u8_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: UInt8) raises -> UInt8:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_u8(data, table + off)


def read_f32_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: Float32) raises -> Float32:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_f32(data, table + off)


def read_f64_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: Float64) raises -> Float64:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_f64(data, table + off)


def read_bool_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int, default: Bool) raises -> Bool:
    var off = field_voffset(data, table, id)
    if off == 0:
        return default
    return read_bool(data, table + off)


def read_string_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int) raises -> String:
    var pos = indirect_field(data, table, id)
    if pos < 0:
        return String()
    return read_string_at(data, pos)


def struct_field[origin: ImmOrigin](data: Span[Byte, origin], table: Int, id: Int) raises -> Int:
    """Absolute position of an inline struct, or -1 when absent."""
    var off = field_voffset(data, table, id)
    if off == 0:
        return -1
    return table + off
