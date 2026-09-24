from std.collections import List, Span

from fb_flex.kind import (
    F_BLOB,
    F_BOOL,
    F_FLOAT,
    F_INT,
    F_INDIRECT_FLOAT,
    F_INDIRECT_INT,
    F_INDIRECT_UINT,
    F_KEY,
    F_MAP,
    F_NULL,
    F_STRING,
    F_UINT,
    F_VECTOR,
    bit_width_f,
    bit_width_i,
    bit_width_u,
    flex_byte_width,
    flex_inline,
    flex_pack,
    padding_bytes,
)


struct FlexItem(Copyable, ImplicitlyCopyable, Movable):
    var kind: Int
    var width: Int
    var i: Int64
    var u: UInt64
    var f: Float64
    var offset: Int

    def __init__(out self):
        self.kind = F_NULL
        self.width = 0
        self.i = 0
        self.u = 0
        self.f = 0.0
        self.offset = 0

    def elem_width(self, buf_size: Int, elem_index: Int) raises -> Int:
        if flex_inline(self.kind):
            return self.width
        var byte_width = 1
        while byte_width <= 8:
            var offset_loc = buf_size + padding_bytes(buf_size, byte_width) + elem_index * byte_width
            var rel = offset_loc - self.offset
            if rel < 0:
                raise Error("relative offset")
            var bits = bit_width_u(UInt64(rel))
            if byte_width == flex_byte_width(bits):
                return bits
            byte_width *= 2
        raise Error("relative offset is too big")

    def stored_width(self, parent_bits: Int) -> Int:
        if flex_inline(self.kind):
            if parent_bits > self.width:
                return parent_bits
            return self.width
        return self.width

    def packed(self, parent_bits: Int) -> Int:
        return flex_pack(self.kind, self.stored_width(parent_bits))


def _item_null() -> FlexItem:
    var v = FlexItem()
    v.kind = F_NULL
    v.width = 0
    return v


def _item_bool(value: Bool) -> FlexItem:
    var v = FlexItem()
    v.kind = F_BOOL
    v.width = 0
    if value:
        v.u = 1
    return v


def _item_int(value: Int64, width: Int) -> FlexItem:
    var v = FlexItem()
    v.kind = F_INT
    v.width = width
    v.i = value
    return v


def _item_uint(value: UInt64, width: Int) -> FlexItem:
    var v = FlexItem()
    v.kind = F_UINT
    v.width = width
    v.u = value
    return v


def _item_float(value: Float64, width: Int) -> FlexItem:
    var v = FlexItem()
    v.kind = F_FLOAT
    v.width = width
    v.f = value
    return v


def _item_key(offset: Int) -> FlexItem:
    var v = FlexItem()
    v.kind = F_KEY
    v.width = 0
    v.offset = offset
    return v


def _item_ref(offset: Int, kind: Int, width: Int) -> FlexItem:
    var v = FlexItem()
    v.kind = kind
    v.width = width
    v.offset = offset
    return v


struct FlexBuilder:
    """Builds a FlexBuffers buffer forward, choosing the narrowest width.

    Keys are shared inside one buffer. Strings are not, unless
    `share_strings` is set. One root value must sit on the stack at `finish`.
    """

    var buf: List[Byte]
    var stack: List[FlexItem]
    var key_offs: List[Int]
    var share_strings: Bool
    var string_offs: List[Int]
    var finished: Bool

    def __init__(out self):
        self.buf = List[Byte]()
        self.stack = List[FlexItem]()
        self.key_offs = List[Int]()
        self.share_strings = False
        self.string_offs = List[Int]()
        self.finished = False

    def clear(mut self):
        self.buf = List[Byte]()
        self.stack = List[FlexItem]()
        self.key_offs = List[Int]()
        self.string_offs = List[Int]()
        self.finished = False

    def finish(mut self) raises -> List[Byte]:
        if self.finished:
            raise Error("flex builder is finished")
        if len(self.stack) != 1:
            raise Error("flex builder needs one root")
        var value = self.stack[0]
        var byte_width = self._align(value.elem_width(len(self.buf), 0))
        self._write_any(value, byte_width)
        self._write_u(UInt64(value.packed(0)), 1)
        self._write_u(UInt64(byte_width), 1)
        self.finished = True
        var out = List[Byte](capacity=len(self.buf))
        for i in range(len(self.buf)):
            out.append(self.buf[i])
        return out^

    def null(mut self):
        self.stack.append(_item_null())

    def bool(mut self, value: Bool):
        self.stack.append(_item_bool(value))

    def int(mut self, value: Int64):
        self.stack.append(_item_int(value, bit_width_i(value)))

    def uint(mut self, value: UInt64):
        self.stack.append(_item_uint(value, bit_width_u(value)))

    def float(mut self, value: Float64):
        self.stack.append(_item_float(value, bit_width_f(value)))

    def string(mut self, value: String) raises:
        _ = self._write_blob(value.as_bytes(), True, F_STRING)

    def blob[origin: ImmOrigin](mut self, value: Span[Byte, origin]) raises:
        _ = self._write_blob(value, False, F_BLOB)

    def key(mut self, value: String) raises:
        var raw = value.as_bytes()
        for i in range(len(raw)):
            if raw[i] == 0:
                raise Error("key contains a zero byte")
        for i in range(len(self.key_offs)):
            if self._bytes_eq(self.key_offs[i], raw):
                self.stack.append(_item_key(self.key_offs[i]))
                return
        var loc = len(self.buf)
        for i in range(len(raw)):
            self.buf.append(raw[i])
        self.buf.append(Byte(0))
        self.key_offs.append(loc)
        self.stack.append(_item_key(loc))

    def start_vector(self) -> Int:
        return len(self.stack)

    def end_vector(mut self, start: Int) raises:
        var elems = self._take(start)
        var vec = self._create_vector(elems, False, False, False, _item_null())
        self.stack.append(vec)

    def start_map(self) -> Int:
        return len(self.stack)

    def end_map(mut self, start: Int) raises:
        var n = len(self.stack) - start
        if (n & 1) != 0:
            raise Error("map needs pairs")
        var pairs = n // 2
        var order = List[Int]()
        for p in range(pairs):
            order.append(p)
        for a in range(pairs):
            var best = a
            for b in range(a + 1, pairs):
                if self._key_less(start + order[b] * 2, start + order[best] * 2):
                    best = b
            if best != a:
                var tmp = order[a]
                order[a] = order[best]
                order[best] = tmp
        var sorted = List[FlexItem]()
        for p in range(pairs):
            var idx = start + order[p] * 2
            sorted.append(self.stack[idx])
            sorted.append(self.stack[idx + 1])
        var kept = List[FlexItem]()
        for i in range(start):
            kept.append(self.stack[i])
        for i in range(len(sorted)):
            kept.append(sorted[i])
        self.stack = kept^
        var keys_list = List[FlexItem]()
        var vals_list = List[FlexItem]()
        for p in range(pairs):
            keys_list.append(self.stack[start + p * 2])
            if self.stack[start + p * 2].kind != F_KEY:
                raise Error("map key")
            vals_list.append(self.stack[start + p * 2 + 1])
        var keys = self._create_vector(keys_list, True, False, False, _item_null())
        var values = self._create_vector(vals_list, False, False, True, keys)
        var tail = List[FlexItem]()
        for i in range(start):
            tail.append(self.stack[i])
        tail.append(values)
        self.stack = tail^

    def _take(mut self, start: Int) -> List[FlexItem]:
        var elems = List[FlexItem]()
        for i in range(start, len(self.stack)):
            elems.append(self.stack[i])
        var kept = List[FlexItem]()
        for i in range(start):
            kept.append(self.stack[i])
        self.stack = kept^
        return elems^

    def _align(mut self, bit_width: Int) -> Int:
        var byte_width = flex_byte_width(bit_width)
        var pad = padding_bytes(len(self.buf), byte_width)
        for _ in range(pad):
            self.buf.append(Byte(0))
        return byte_width

    def _write_u(mut self, value: UInt64, byte_width: Int):
        for i in range(byte_width):
            var shift = UInt64(i) * 8
            self.buf.append(Byte(UInt8((value >> shift) & 0xFF)))

    def _write_i(mut self, value: Int64, byte_width: Int):
        self._write_u(UInt64(value), byte_width)

    def _write_f(mut self, value: Float64, byte_width: Int):
        if byte_width == 4:
            var narrow = Float32(value)
            self._write_u(UInt64(UInt32(narrow.to_bits())), 4)
        else:
            self._write_u(UInt64(value.to_bits()), 8)

    def _write_offset(mut self, offset: Int, byte_width: Int) raises:
        var rel = len(self.buf) - offset
        if rel < 0:
            raise Error("relative offset")
        if byte_width < 8:
            var limit = UInt64(1) << (UInt64(byte_width) * 8)
            if UInt64(rel) >= limit:
                raise Error("relative offset")
        self._write_u(UInt64(rel), byte_width)

    def _write_any(mut self, value: FlexItem, byte_width: Int) raises:
        if value.kind == F_NULL or value.kind == F_BOOL or value.kind == F_UINT:
            self._write_u(value.u, byte_width)
        elif value.kind == F_INT:
            self._write_i(value.i, byte_width)
        elif value.kind == F_FLOAT:
            self._write_f(value.f, byte_width)
        else:
            self._write_offset(value.offset, byte_width)

    def _write_blob[origin: ImmOrigin](mut self, data: Span[Byte, origin], add_zero: Bool, kind: Int) raises -> Int:
        var bits = bit_width_u(UInt64(len(data)))
        var byte_width = self._align(bits)
        self._write_u(UInt64(len(data)), byte_width)
        var loc = len(self.buf)
        for i in range(len(data)):
            self.buf.append(data[i])
        if add_zero:
            self.buf.append(Byte(0))
        self.stack.append(_item_ref(loc, kind, bits))
        return loc

    def _create_vector(mut self, elems: List[FlexItem], typed: Bool, fixed: Bool, has_keys: Bool, keys: FlexItem) raises -> FlexItem:
        var length = len(elems)
        var bit_width = bit_width_u(UInt64(length))
        var prefix = 1
        if has_keys:
            bit_width = _max(bit_width, keys.elem_width(len(self.buf), 0))
            prefix += 2
        var vector_type = F_KEY
        for i in range(length):
            bit_width = _max(bit_width, elems[i].elem_width(len(self.buf), prefix + i))
            if typed:
                if i == 0:
                    vector_type = elems[i].kind
                elif vector_type != elems[i].kind:
                    raise Error("typed vector")
        var byte_width = self._align(bit_width)
        if has_keys:
            self._write_offset(keys.offset, byte_width)
            self._write_u(UInt64(flex_byte_width(keys.width)), byte_width)
        if not fixed:
            self._write_u(UInt64(length), byte_width)
        var loc = len(self.buf)
        for i in range(length):
            self._write_any(elems[i], byte_width)
        if not typed:
            for i in range(length):
                self.buf.append(Byte(elems[i].packed(bit_width)))
        var kind = F_VECTOR
        if has_keys:
            kind = F_MAP
        elif typed:
            kind = _typed_vector_kind(vector_type)
        return _item_ref(loc, kind, bit_width)

    def _bytes_eq[origin: ImmOrigin](self, offset: Int, raw: Span[Byte, origin]) -> Bool:
        var i = 0
        while i < len(raw):
            if offset + i >= len(self.buf) or self.buf[offset + i] != raw[i]:
                return False
            i += 1
        if offset + i >= len(self.buf):
            return False
        return self.buf[offset + i] == 0

    def _key_less(self, left: Int, right: Int) -> Bool:
        var a = self.stack[left].offset
        var b = self.stack[right].offset
        while True:
            var ca = self.buf[a]
            var cb = self.buf[b]
            if ca != cb:
                return ca < cb
            if ca == 0:
                return False
            a += 1
            b += 1


def _max(a: Int, b: Int) -> Int:
    if a > b:
        return a
    return b


def _typed_vector_kind(elem: Int) -> Int:
    if elem == F_INT:
        return 11
    if elem == F_UINT:
        return 12
    if elem == F_FLOAT:
        return 13
    if elem == F_KEY:
        return 14
    if elem == F_STRING:
        return 15
    if elem == F_BOOL:
        return 36
    return 10
