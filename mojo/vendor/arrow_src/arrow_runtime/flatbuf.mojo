from std.collections import List, Span

from arrow_runtime.buf import copy_span, list_i32, list_u16, list_u32, list_u64, set_u16, set_u32, set_u64, string_from
from arrow_runtime.error import DecodeError


struct FBBuilder:
    """Backward FlatBuffers builder.

    Returned offsets are distances from the end of the staging buffer.
    That distance stays valid when the staging buffer grows toward lower addresses.
    A uoffset stored in the finished buffer is `target - field`, so it points at a higher address.
    """

    var data: List[Byte]
    var cursor: Int
    var field_at: List[Int]
    var nfields: Int
    var high: Int
    var align_need: Int

    def __init__(out self):
        self.data = List[Byte]()
        self.data.resize(2048, Byte(0))
        self.cursor = len(self.data)
        self.field_at = List[Int]()
        self.nfields = 0
        self.high = self.cursor
        self.align_need = 4

    def _tok(self, abs_pos: Int) -> Int:
        return len(self.data) - abs_pos

    def _abs(self, tok: Int) -> Int:
        return len(self.data) - tok

    def _grow(mut self, need: Int):
        if self.cursor >= need:
            return
        var cap = len(self.data)
        var bigger_n = cap * 2
        if bigger_n < cap + need + 64:
            bigger_n = cap + need + 64
        while bigger_n - (cap - self.cursor) < need + 64:
            bigger_n *= 2
        var bigger = List[Byte]()
        bigger.resize(bigger_n, Byte(0))
        var used = cap - self.cursor
        var shift = bigger_n - cap
        var i = 0
        while i < used:
            bigger[self.cursor + shift + i] = self.data[self.cursor + i]
            i += 1
        self.cursor += shift
        self.high += shift
        var f = 0
        while f < len(self.field_at):
            if self.field_at[f] >= 0:
                self.field_at[f] += shift
            f += 1
        self.data = bigger^

    def place(mut self, size: Int, align: Int):
        self._grow(size + align)
        var start = self.cursor - size
        var mis = start % align
        if mis != 0:
            self.cursor -= mis
        self.cursor -= size

    def start_table(mut self, nfields: Int):
        while len(self.field_at) < nfields:
            self.field_at.append(-1)
        var i = 0
        while i < nfields:
            self.field_at[i] = -1
            i += 1
        self.nfields = nfields
        self.high = self.cursor
        self.align_need = 4

    def _note(mut self, id: Int, align: Int):
        self.field_at[id] = self.cursor
        if align > self.align_need:
            self.align_need = align

    def add_bool(mut self, id: Int, v: Bool, default: Bool):
        if v == default:
            return
        var n = 0
        if v:
            n = 1
        self.place(1, 1)
        self.data[self.cursor] = Byte(n)
        self._note(id, 1)

    def add_u8(mut self, id: Int, v: Int, default: Int):
        if v == default:
            return
        self.place(1, 1)
        self.data[self.cursor] = Byte(v & 255)
        self._note(id, 1)

    def add_u16(mut self, id: Int, v: Int, default: Int):
        if v == default:
            return
        self.place(2, 2)
        set_u16(self.data, self.cursor, v)
        self._note(id, 2)

    def add_i32(mut self, id: Int, v: Int, default: Int):
        if v == default:
            return
        self.place(4, 4)
        var u = v
        if u < 0:
            u = u + 4294967296
        set_u32(self.data, self.cursor, u)
        self._note(id, 4)

    def add_u32(mut self, id: Int, v: Int, default: Int):
        self.add_i32(id, v, default)

    def add_i64(mut self, id: Int, v: Int, default: Int):
        if v == default:
            return
        self.place(8, 8)
        set_u64(self.data, self.cursor, UInt64(v))
        self._note(id, 8)

    def add_i64_pair(mut self, id: Int, first: Int, second: Int):
        self.place(16, 8)
        set_u64(self.data, self.cursor, UInt64(first))
        set_u64(self.data, self.cursor + 8, UInt64(second))
        self._note(id, 8)

    def add_offset(mut self, id: Int, tok: Int):
        if tok < 0:
            return
        self.place(4, 4)
        var target = self._abs(tok)
        set_u32(self.data, self.cursor, target - self.cursor)
        self._note(id, 4)

    def end_table(mut self) -> Int:
        self.place(4, self.align_need)
        var table = self.cursor
        set_u32(self.data, table, 0)
        var table_tok = self._tok(table)
        var obj = self.high - table
        var vtsize = 4 + 2 * self.nfields
        self.place(vtsize, 2)
        table = self._abs(table_tok)
        set_u16(self.data, self.cursor, vtsize)
        set_u16(self.data, self.cursor + 2, obj)
        var i = 0
        while i < self.nfields:
            var rel = 0
            if self.field_at[i] >= 0:
                rel = self.field_at[i] - table
            set_u16(self.data, self.cursor + 4 + i * 2, rel)
            i += 1
        var soff = table - self.cursor
        var u = soff
        if u < 0:
            u = u + 4294967296
        set_u32(self.data, table, u)
        return table_tok

    def write_string(mut self, text: String) -> Int:
        var raw = text.as_bytes()
        return self.write_bytes(raw, True)

    def write_blob[origin: ImmOrigin](mut self, raw: Span[Byte, origin]) -> Int:
        return self.write_bytes(raw, False)

    def write_bytes[origin: ImmOrigin](mut self, raw: Span[Byte, origin], null_term: Bool) -> Int:
        var n = len(raw)
        var extra = 0
        if null_term:
            extra = 1
        var total = n + extra
        self._grow(total + 8)
        var mis = (self.cursor - total) % 4
        if mis != 0:
            self.cursor -= mis
        var start = self.cursor - total
        var i = 0
        while i < n:
            self.data[start + i] = raw[i]
            i += 1
        if null_term:
            self.data[start + n] = Byte(0)
        self.cursor = start
        self.place(4, 4)
        set_u32(self.data, self.cursor, n)
        return self._tok(self.cursor)

    def write_u32_vec(mut self, vals: List[Int]) -> Int:
        var i = len(vals) - 1
        while i >= 0:
            self.place(4, 4)
            var v = vals[i]
            if v < 0:
                v = v + 4294967296
            set_u32(self.data, self.cursor, v)
            i -= 1
        self.place(4, 4)
        set_u32(self.data, self.cursor, len(vals))
        return self._tok(self.cursor)

    def write_u16_vec(mut self, vals: List[Int]) -> Int:
        var nbytes = len(vals) * 2
        self._grow(nbytes + 8)
        var mis = (self.cursor - nbytes) % 4
        if mis != 0:
            self.cursor -= mis
        var i = len(vals) - 1
        while i >= 0:
            self.cursor -= 2
            set_u16(self.data, self.cursor, vals[i])
            i -= 1
        self.place(4, 4)
        set_u32(self.data, self.cursor, len(vals))
        return self._tok(self.cursor)

    def write_u64_vec(mut self, vals: List[Int]) -> Int:
        var i = len(vals) - 1
        while i >= 0:
            self.place(8, 8)
            set_u64(self.data, self.cursor, UInt64(vals[i]))
            i -= 1
        self.place(4, 4)
        set_u32(self.data, self.cursor, len(vals))
        return self._tok(self.cursor)

    def write_offset_vec(mut self, targets: List[Int]) -> Int:
        var i = len(targets) - 1
        while i >= 0:
            self.place(4, 4)
            var target = self._abs(targets[i])
            set_u32(self.data, self.cursor, target - self.cursor)
            i -= 1
        self.place(4, 4)
        set_u32(self.data, self.cursor, len(targets))
        return self._tok(self.cursor)

    def write_i64_pairs(mut self, first: List[Int], second: List[Int]) -> Int:
        var n = len(first)
        var nbytes = n * 16
        self._grow(nbytes + 16)
        var mis = (self.cursor - nbytes) % 8
        if mis != 0:
            self.cursor -= mis
        var i = n - 1
        while i >= 0:
            self.cursor -= 16
            set_u64(self.data, self.cursor, UInt64(first[i]))
            set_u64(self.data, self.cursor + 8, UInt64(second[i]))
            i -= 1
        self.place(4, 4)
        set_u32(self.data, self.cursor, n)
        return self._tok(self.cursor)

    def write_struct_vec(mut self, raw: List[Byte], elem: Int) -> Int:
        var n = 0
        if elem > 0:
            n = len(raw) // elem
        var align = 4
        if elem >= 8:
            align = 8
        self._grow(len(raw) + align + 8)
        var mis = (self.cursor - len(raw)) % align
        if mis != 0:
            self.cursor -= mis
        var i = len(raw) - 1
        while i >= 0:
            self.cursor -= 1
            self.data[self.cursor] = raw[i]
            i -= 1
        self.place(4, 4)
        set_u32(self.data, self.cursor, n)
        return self._tok(self.cursor)

    def finish(mut self, tok: Int) -> List[Byte]:
        self.place(4, 8)
        var root = self._abs(tok)
        set_u32(self.data, self.cursor, root - self.cursor)
        var n = len(self.data) - self.cursor
        var out = List[Byte]()
        out.resize(n, Byte(0))
        var i = 0
        while i < n:
            out[i] = self.data[self.cursor + i]
            i += 1
        return out^


struct FBReader:
    var data: List[Byte]

    def __init__(out self, var data: List[Byte]):
        self.data = data^

    def root(self) raises DecodeError -> Int:
        return list_u32(self.data, 0)

    def field(self, table: Int, id: Int) raises DecodeError -> Int:
        var soff = list_i32(self.data, table)
        var vt = table - soff
        if vt < 0 or vt + 2 > len(self.data):
            raise DecodeError(DecodeError.KIND_SYNTAX, table)
        var vtsize = list_u16(self.data, vt)
        if vtsize < 4 or vt + vtsize > len(self.data):
            raise DecodeError(DecodeError.KIND_SYNTAX, vt)
        if 4 + id * 2 + 2 > vtsize:
            return -1
        var rel = list_u16(self.data, vt + 4 + id * 2)
        if rel == 0:
            return -1
        var pos = table + rel
        if pos < 0 or pos >= len(self.data):
            raise DecodeError(DecodeError.KIND_SYNTAX, pos)
        return pos

    def follow(self, pos: Int) raises DecodeError -> Int:
        var rel = list_u32(self.data, pos)
        var at = pos + rel
        if at < 0 or at > len(self.data):
            raise DecodeError(DecodeError.KIND_SYNTAX, pos)
        return at

    def vec_len(self, pos: Int) raises DecodeError -> Int:
        return list_u32(self.data, self.follow(pos))

    def vec_data(self, pos: Int) raises DecodeError -> Int:
        return self.follow(pos) + 4

    def string_at(self, pos: Int) raises DecodeError -> String:
        var at = self.follow(pos)
        var n = list_u32(self.data, at)
        if n < 0 or at + 4 + n > len(self.data):
            raise DecodeError(DecodeError.KIND_SYNTAX, at)
        var tmp = copy_span(Span(self.data), at + 4, n)
        return string_from(Span(tmp))

    def bytes_at(self, pos: Int) raises DecodeError -> List[Byte]:
        var at = self.follow(pos)
        var n = list_u32(self.data, at)
        if n < 0 or at + 4 + n > len(self.data):
            raise DecodeError(DecodeError.KIND_SYNTAX, at)
        return copy_span(Span(self.data), at + 4, n)

    def u8(self, pos: Int) raises DecodeError -> Int:
        if pos < 0 or pos >= len(self.data):
            raise DecodeError(DecodeError.KIND_EOF, pos)
        return Int(self.data[pos])

    def u16(self, pos: Int) raises DecodeError -> Int:
        return list_u16(self.data, pos)

    def i32(self, pos: Int) raises DecodeError -> Int:
        return list_i32(self.data, pos)

    def u32(self, pos: Int) raises DecodeError -> Int:
        return list_u32(self.data, pos)

    def i64(self, pos: Int) raises DecodeError -> Int:
        return Int(list_u64(self.data, pos))
