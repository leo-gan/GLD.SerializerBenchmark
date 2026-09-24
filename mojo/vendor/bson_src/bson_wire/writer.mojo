from std.collections import List, Span
from std.memory import unsafe_memcpy

from bson_wire.types import (
    TY_ARRAY,
    TY_BINARY,
    TY_BOOL,
    TY_CODE,
    TY_CODEWS,
    TY_DATETIME,
    TY_DBPOINTER,
    TY_DECIMAL128,
    TY_DOCUMENT,
    TY_DOUBLE,
    TY_INT32,
    TY_INT64,
    TY_MAXKEY,
    TY_MINKEY,
    TY_NULL,
    TY_OBJECTID,
    TY_REGEX,
    TY_STRING,
    TY_SYMBOL,
    TY_TIMESTAMP,
    TY_UNDEFINED,
)


def digit_count(n: Int) -> Int:
    var x = n
    if x < 0:
        x = -x
    var c = 1
    while x >= 10:
        x //= 10
        c += 1
    return c


struct WireWriter(Movable):
    """Writes BSON into one buffer.

    `encode` sets the list length to `encoded_len` before the first store.
    A length-only reservation would grow on every byte. Document lengths are
    patched in place, which is the same close-frame libbson uses, so a nested
    value is written once.
    """

    var buf: List[Byte]
    var pos: Int

    def __init__(out self, *, capacity: Int = 64):
        if capacity > 0:
            self.buf = List[Byte](unsafe_uninit_length=capacity)
        else:
            self.buf = List[Byte]()
        self.pos = 0

    def ensure(mut self, n: Int):
        var need = self.pos + n
        if need > len(self.buf):
            var cap = len(self.buf)
            if cap < 64:
                cap = 64
            while cap < need:
                cap = cap * 2
            self.buf.resize(unsafe_uninit_length=cap)

    def write_byte(mut self, b: Byte):
        self.ensure(1)
        self.buf[self.pos] = b
        self.pos += 1

    def write_bytes[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        var n = len(data)
        if n == 0:
            return
        self.ensure(n)
        unsafe_memcpy(
            dest=self.buf.unsafe_ptr().unsafe_offset(self.pos),
            src=data.unsafe_ptr(),
            count=n,
        )
        self.pos += n

    def write_list(mut self, data: List[Byte]):
        var n = len(data)
        if n == 0:
            return
        self.ensure(n)
        unsafe_memcpy(
            dest=self.buf.unsafe_ptr().unsafe_offset(self.pos),
            src=data.unsafe_ptr(),
            count=n,
        )
        self.pos += n

    def write_i32(mut self, v: Int32):
        # BSON integers are little-endian. This package targets linux-64.
        self.ensure(4)
        self.buf.unsafe_ptr().unsafe_offset(self.pos).unsafe_bitcast[Int32]()[] = v
        self.pos += 4

    def write_i64(mut self, v: Int64):
        self.ensure(8)
        self.buf.unsafe_ptr().unsafe_offset(self.pos).unsafe_bitcast[Int64]()[] = v
        self.pos += 8

    def write_f64(mut self, v: Float64):
        self.ensure(8)
        var bits = UInt64(v.to_bits())
        self.buf.unsafe_ptr().unsafe_offset(self.pos).unsafe_bitcast[UInt64]()[] = bits
        self.pos += 8

    def patch_i32(mut self, at: Int, v: Int32):
        var saved = self.pos
        self.pos = at
        self.write_i32(v)
        self.pos = saved

    def write_cstring(mut self, s: String):
        var b = s.as_bytes()
        self.write_bytes(b)
        self.write_byte(Byte(0))

    def write_index_cstring(mut self, n: Int):
        if n == 0:
            self.write_byte(Byte(48))
            self.write_byte(Byte(0))
            return
        var tmp = List[Byte]()
        var x = n
        while x > 0:
            tmp.append(Byte(48 + (x % 10)))
            x //= 10
        var i = len(tmp)
        while i > 0:
            i -= 1
            self.write_byte(tmp[i])
        self.write_byte(Byte(0))

    def write_bson_string(mut self, s: String):
        var n = s.byte_length() + 1
        self.write_i32(Int32(n))
        self.write_cstring(s)

    def write_type_key(mut self, typ: Int, key: String):
        self.write_byte(Byte(typ))
        self.write_cstring(key)

    def write_type_index(mut self, typ: Int, index: Int):
        self.write_byte(Byte(typ))
        self.write_index_cstring(index)

    def begin_document(mut self) -> Int:
        var at = self.pos
        self.write_i32(Int32(0))
        return at

    def end_document(mut self, at: Int):
        self.write_byte(Byte(0))
        var n = self.pos - at
        self.patch_i32(at, Int32(n))

    def write_f64_field(mut self, key: String, v: Float64):
        self.write_type_key(TY_DOUBLE, key)
        self.write_f64(v)

    def write_string_field(mut self, key: String, v: String):
        self.write_type_key(TY_STRING, key)
        self.write_bson_string(v)

    def write_bool_field(mut self, key: String, v: Bool):
        self.write_type_key(TY_BOOL, key)
        if v:
            self.write_byte(Byte(1))
        else:
            self.write_byte(Byte(0))

    def write_i32_field(mut self, key: String, v: Int32):
        self.write_type_key(TY_INT32, key)
        self.write_i32(v)

    def write_i64_field(mut self, key: String, v: Int64):
        self.write_type_key(TY_INT64, key)
        self.write_i64(v)

    def write_null_field(mut self, key: String):
        self.write_type_key(TY_NULL, key)

    def write_undefined_field(mut self, key: String):
        self.write_type_key(TY_UNDEFINED, key)

    def write_minkey_field(mut self, key: String):
        self.write_type_key(TY_MINKEY, key)

    def write_maxkey_field(mut self, key: String):
        self.write_type_key(TY_MAXKEY, key)

    def write_datetime_field(mut self, key: String, ms: Int64):
        self.write_type_key(TY_DATETIME, key)
        self.write_i64(ms)

    def write_timestamp_field(mut self, key: String, t: Int32, inc: Int32):
        self.write_type_key(TY_TIMESTAMP, key)
        # Spec order is increment then timestamp, each uint32 little-endian.
        self.write_i32(inc)
        self.write_i32(t)

    def write_oid_field[origin: ImmOrigin](mut self, key: String, raw: Span[Byte, origin]):
        self.write_type_key(TY_OBJECTID, key)
        self.write_bytes(raw)

    def write_decimal_field[origin: ImmOrigin](mut self, key: String, raw: Span[Byte, origin]):
        self.write_type_key(TY_DECIMAL128, key)
        self.write_bytes(raw)

    def write_binary_field[origin: ImmOrigin](mut self, key: String, subtype: Int, raw: Span[Byte, origin]):
        self.write_type_key(TY_BINARY, key)
        self.write_i32(Int32(len(raw)))
        self.write_byte(Byte(subtype))
        self.write_bytes(raw)

    def write_regex_field(mut self, key: String, pattern: String, options: String):
        self.write_type_key(TY_REGEX, key)
        self.write_cstring(pattern)
        self.write_cstring(options)

    def write_code_field(mut self, key: String, code: String):
        self.write_type_key(TY_CODE, key)
        self.write_bson_string(code)

    def write_symbol_field(mut self, key: String, symbol: String):
        self.write_type_key(TY_SYMBOL, key)
        self.write_bson_string(symbol)

    def write_dbpointer_field[origin: ImmOrigin](mut self, key: String, ns: String, oid: Span[Byte, origin]):
        self.write_type_key(TY_DBPOINTER, key)
        self.write_bson_string(ns)
        self.write_bytes(oid)

    def begin_codews(mut self, key: String) -> Int:
        self.write_type_key(TY_CODEWS, key)
        return self.begin_document()

    def begin_array_field(mut self, key: String) -> Int:
        self.write_type_key(TY_ARRAY, key)
        return self.begin_document()

    def begin_doc_field(mut self, key: String) -> Int:
        self.write_type_key(TY_DOCUMENT, key)
        return self.begin_document()

    def write_f64_index(mut self, index: Int, v: Float64):
        self.write_type_index(TY_DOUBLE, index)
        self.write_f64(v)

    def write_i32_index(mut self, index: Int, v: Int32):
        self.write_type_index(TY_INT32, index)
        self.write_i32(v)

    def write_i64_index(mut self, index: Int, v: Int64):
        self.write_type_index(TY_INT64, index)
        self.write_i64(v)

    def write_bool_index(mut self, index: Int, v: Bool):
        self.write_type_index(TY_BOOL, index)
        if v:
            self.write_byte(Byte(1))
        else:
            self.write_byte(Byte(0))

    def write_string_index(mut self, index: Int, v: String):
        self.write_type_index(TY_STRING, index)
        self.write_bson_string(v)

    def finish(deinit self) -> List[Byte]:
        if self.pos < len(self.buf):
            self.buf.resize(unsafe_uninit_length=self.pos)
        return self.buf^
