from std.collections import Span

from fb_wire.reader import field_voffset, indirect, read_string_at, root_pos, vector_len
from fb_wire.scalar import int_from_i32, read_i32, read_u16, read_u32


def verify_root[origin: ImmOrigin](data: Span[Byte, origin], size_prefixed: Bool) raises:
    """Reject a buffer that cannot hold a root table and a vtable."""
    if len(data) < 4:
        raise Error("truncated")
    if size_prefixed and len(data) < 8:
        raise Error("truncated")
    var table = root_pos(data, size_prefixed)
    _ = verify_table_header(data, table)


def verify_file_identifier[origin: ImmOrigin](data: Span[Byte, origin]) raises:
    """A file identifier needs four bytes after the root uoffset."""
    if len(data) < 8:
        raise Error("truncated")


def verify_table_header[origin: ImmOrigin](data: Span[Byte, origin], table: Int) raises -> Int:
    """Return the object size in bytes after checking the vtable."""
    if table < 0 or table + 4 > len(data) or (table & 3) != 0:
        raise Error("bad table")
    var raw_soff = read_i32(data, table)
    var soff = int_from_i32(raw_soff)
    var vtable = table - soff
    if vtable < 0 or (vtable & 1) != 0 or vtable + 4 > len(data):
        raise Error("bad vtable")
    var vbytes = Int(read_u16(data, vtable))
    var obj = Int(read_u16(data, vtable + 2))
    if vbytes < 4 or (vbytes & 1) != 0 or vtable + vbytes > len(data):
        raise Error("bad vtable")
    if obj < 4 or table + obj > len(data):
        raise Error("bad table")
    var id = 0
    var entry = 4
    while entry < vbytes:
        var off = field_voffset(data, table, id)
        if off != 0 and (off < 4 or off >= obj):
            raise Error("bad field")
        id += 1
        entry += 2
    return obj


def verify_string[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises:
    if pos < 0 or (pos & 3) != 0:
        raise Error("bad string")
    _ = read_string_at(data, pos)


def verify_offset_vector[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> Int:
    if pos < 0 or (pos & 3) != 0:
        raise Error("bad vector")
    var n = vector_len(data, pos)
    if pos + 4 + n * 4 > len(data):
        raise Error("truncated")
    for i in range(n):
        var slot = pos + 4 + i * 4
        _ = indirect(data, slot)
    return n


def verify_scalar_vector[origin: ImmOrigin](data: Span[Byte, origin], pos: Int, width: Int) raises -> Int:
    if pos < 0 or (pos & 3) != 0:
        raise Error("bad vector")
    var n = vector_len(data, pos)
    if width <= 0 or pos + 4 + n * width > len(data):
        raise Error("truncated")
    return n


def read_size_prefix[origin: ImmOrigin](data: Span[Byte, origin]) raises -> Int:
    if len(data) < 4:
        raise Error("truncated")
    var n = Int(read_u32(data, 0))
    if n < 0 or n > len(data) - 4:
        raise Error("bad size")
    return n
