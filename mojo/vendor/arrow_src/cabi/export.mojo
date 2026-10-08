from std.collections import List, Span
from std.memory import Pointer

from arrow_runtime.buf import set_u32, set_u64
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


comptime SCHEMA_BYTES = 72
comptime ARRAY_BYTES = 80
comptime DEVICE_BYTES = 128
comptime FLAG_DICTIONARY_ORDERED = 1
comptime FLAG_NULLABLE = 2
comptime FLAG_MAP_KEYS_SORTED = 4


struct CExport:
    """A CPU view of one array. Pointers stay valid while this value is alive.

    `release` is null. The Columnar that produced the buffers still owns them.
    """

    var bytes: List[Byte]
    var schema_at: Int
    var array_at: Int

    def __init__(out self):
        self.bytes = List[Byte]()
        self.schema_at = 0
        self.array_at = 0

    def schema_addr(mut self) -> Int:
        return Int(Span(self.bytes).unsafe_ptr()) + self.schema_at

    def array_addr(mut self) -> Int:
        return Int(Span(self.bytes).unsafe_ptr()) + self.array_at


def format_of(f: FieldRec) -> String:
    if f.dict_id >= 0:
        return _int_format(f.dict_index_width, f.dict_index_signed != 0)
    return value_format(f)


def value_format(f: FieldRec) -> String:
    var k = f.kind
    if k == TY_NULL:
        return "n"
    if k == TY_BOOL:
        return "b"
    if k == TY_INT:
        return _int_format(f.bit_width, f.is_signed != 0)
    if k == TY_FLOAT:
        if f.unit == 0:
            return "e"
        if f.unit == 1:
            return "f"
        return "g"
    if k == TY_BINARY:
        return "z"
    if k == TY_LARGE_BINARY:
        return "Z"
    if k == TY_BINARY_VIEW:
        return "vz"
    if k == TY_UTF8:
        return "u"
    if k == TY_LARGE_UTF8:
        return "U"
    if k == TY_UTF8_VIEW:
        return "vu"
    if k == TY_FIXED_BINARY:
        return "w:" + String(f.fixed_size)
    if k == TY_DECIMAL:
        var s = "d:" + String(f.precision) + "," + String(f.scale)
        if f.bit_width != 128:
            s = s + "," + String(f.bit_width)
        return s
    if k == TY_DATE:
        if f.unit == 0:
            return "tdD"
        return "tdm"
    if k == TY_TIME:
        if f.unit == 0:
            return "tts"
        if f.unit == 1:
            return "ttm"
        if f.unit == 2:
            return "ttu"
        return "ttn"
    if k == TY_TIMESTAMP:
        var u = "s"
        if f.unit == 1:
            u = "m"
        elif f.unit == 2:
            u = "u"
        elif f.unit == 3:
            u = "n"
        return "ts" + u + ":"
    if k == TY_DURATION:
        if f.unit == 0:
            return "tDs"
        if f.unit == 1:
            return "tDm"
        if f.unit == 2:
            return "tDu"
        return "tDn"
    if k == TY_INTERVAL:
        if f.unit == 0:
            return "tiM"
        if f.unit == 1:
            return "tiD"
        return "tin"
    if k == TY_LIST:
        return "+l"
    if k == TY_LARGE_LIST:
        return "+L"
    if k == TY_LIST_VIEW:
        return "+vl"
    if k == TY_LARGE_LIST_VIEW:
        return "+vL"
    if k == TY_FIXED_LIST:
        return "+w:" + String(f.fixed_size)
    if k == TY_STRUCT:
        return "+s"
    if k == TY_MAP:
        return "+m"
    if k == TY_RUN_END:
        return "+r"
    if k == TY_UNION:
        var s = "+us:"
        if f.union_mode == 1:
            s = "+ud:"
        return s
    return ""


def _int_format(width: Int, signed: Bool) -> String:
    if width == 8:
        if signed:
            return "c"
        return "C"
    if width == 16:
        if signed:
            return "s"
        return "S"
    if width == 64:
        if signed:
            return "l"
        return "L"
    if signed:
        return "i"
    return "I"


def load_i64(addr: Int) -> Int:
    var p = Pointer[Byte, ImmutAnyOrigin](unsafe_from_address=addr)
    var x = UInt64(0)
    var i = 7
    while i >= 0:
        x = (x << 8) | UInt64(Int(p[unsafe_offset=i]))
        i -= 1
    return Int(x)


def load_bytes(addr: Int, n: Int) -> List[Byte]:
    var p = Pointer[Byte, ImmutAnyOrigin](unsafe_from_address=addr)
    var out = List[Byte]()
    var i = 0
    while i < n:
        out.append(p[i])
        i += 1
    return out^


def cstring_at(addr: Int) -> String:
    if addr == 0:
        return ""
    var p = Pointer[Byte, ImmutAnyOrigin](unsafe_from_address=addr)
    var raw = List[Byte]()
    var i = 0
    while Int(p[unsafe_offset=i]) != 0:
        raw.append(p[unsafe_offset=i])
        i += 1
    return String(unsafe_from_utf8=Span(raw))


struct _Piece:
    var kind: Int
    var at: Int

    def __init__(out self, kind: Int, at: Int):
        self.kind = kind
        self.at = at


def export_array(c: Columnar, array_id: Int, tail: Int = 0) -> CExport:
    var ex = CExport()
    var f = c.fields[c.arrays[array_id].field]
    var fmt = format_of(f)
    if f.kind == TY_TIMESTAMP and f.timezone >= 0:
        fmt = fmt + c.strings[f.timezone]
    if f.kind == TY_UNION:
        var i = 0
        while i < f.n_type_ids:
            if i > 0:
                fmt = fmt + ","
            fmt = fmt + String(c.type_ids[f.type_ids0 + i])
            i += 1
        if f.n_type_ids == 0:
            i = 0
            while i < f.nchild:
                if i > 0:
                    fmt = fmt + ","
                fmt = fmt + String(i)
                i += 1
    var name = String("")
    if f.name >= 0:
        name = c.strings[f.name]
    _put_cstr(ex.bytes, fmt)
    var fmt_at = 0
    _put_cstr(ex.bytes, name)
    var name_at = _cstr_end(ex.bytes, fmt_at)
    var meta = _metadata(c, f)
    var meta_at = len(ex.bytes)
    var i = 0
    while i < len(meta):
        ex.bytes.append(meta[i])
        i += 1
    ex.schema_at = len(ex.bytes)
    _zeros(ex.bytes, SCHEMA_BYTES)
    ex.array_at = len(ex.bytes)
    _zeros(ex.bytes, ARRAY_BYTES)
    var nbuf = c.arrays[array_id].nbuf
    var buf_table = len(ex.bytes)
    _zeros(ex.bytes, 8 * nbuf)
    if tail > 0:
        _zeros(ex.bytes, tail)
    var base = Int(Span(ex.bytes).unsafe_ptr())
    _poke_ptr(ex.bytes, ex.schema_at + 0, base + fmt_at)
    _poke_ptr(ex.bytes, ex.schema_at + 8, base + name_at)
    if len(meta) > 0:
        _poke_ptr(ex.bytes, ex.schema_at + 16, base + meta_at)
    var flags = 0
    if f.nullable != 0:
        flags = flags | FLAG_NULLABLE
    if f.dict_ordered != 0:
        flags = flags | FLAG_DICTIONARY_ORDERED
    if f.keys_sorted != 0:
        flags = flags | FLAG_MAP_KEYS_SORTED
    _poke_i64(ex.bytes, ex.schema_at + 24, flags)
    var a = c.arrays[array_id]
    _poke_i64(ex.bytes, ex.array_at + 0, a.length)
    _poke_i64(ex.bytes, ex.array_at + 8, a.null_count)
    _poke_i64(ex.bytes, ex.array_at + 24, nbuf)
    _poke_ptr(ex.bytes, ex.array_at + 40, base + buf_table)
    i = 0
    while i < nbuf:
        var id = c.abufs[a.buf0 + i]
        var rec = c.bufs[id]
        var addr = 0
        if rec.length > 0:
            addr = Int(Span(c.bytes).unsafe_ptr()) + rec.off
        _poke_ptr(ex.bytes, buf_table + i * 8, addr)
        i += 1
    return ex^


def export_device(c: Columnar, array_id: Int, device_type: Int, device_id: Int) -> CExport:
    var ex = export_array(c, array_id, DEVICE_BYTES)
    var arr = ex.array_at
    var dev = len(ex.bytes) - DEVICE_BYTES
    var i = 0
    while i < ARRAY_BYTES:
        ex.bytes[dev + i] = ex.bytes[arr + i]
        i += 1
    _poke_i64(ex.bytes, dev + 80, device_id)
    set_u32(ex.bytes, dev + 88, device_type)
    ex.array_at = dev
    return ex^


def _metadata(c: Columnar, f: FieldRec) -> List[Byte]:
    var out = List[Byte]()
    if f.nmeta <= 0:
        return out^
    var n = f.nmeta
    out.append(Byte(n & 255))
    out.append(Byte((n >> 8) & 255))
    out.append(Byte((n >> 16) & 255))
    out.append(Byte((n >> 24) & 255))
    var i = 0
    while i < n:
        _meta_str(out, c.strings[c.meta_k[f.meta0 + i]])
        _meta_str(out, c.strings[c.meta_v[f.meta0 + i]])
        i += 1
    out.append(Byte(0))
    return out^


def _meta_str(mut out: List[Byte], text: String):
    var raw = text.as_bytes()
    var n = len(raw)
    out.append(Byte(n & 255))
    out.append(Byte((n >> 8) & 255))
    out.append(Byte((n >> 16) & 255))
    out.append(Byte((n >> 24) & 255))
    var i = 0
    while i < n:
        out.append(raw[i])
        i += 1


def _put_cstr(mut b: List[Byte], text: String):
    var raw = text.as_bytes()
    var i = 0
    while i < len(raw):
        b.append(raw[i])
        i += 1
    b.append(Byte(0))


def _cstr_end(b: List[Byte], start: Int) -> Int:
    var i = start
    while i < len(b) and Int(b[i]) != 0:
        i += 1
    return i + 1


def _zeros(mut b: List[Byte], n: Int):
    var i = 0
    while i < n:
        b.append(Byte(0))
        i += 1


def _poke_i64(mut b: List[Byte], at: Int, v: Int):
    set_u64(b, at, UInt64(v))


def _poke_ptr(mut b: List[Byte], at: Int, addr: Int):
    set_u64(b, at, UInt64(addr))
