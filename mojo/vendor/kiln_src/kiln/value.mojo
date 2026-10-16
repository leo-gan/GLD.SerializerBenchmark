from std.collections import List, Span

from kiln.error import KilnError
from kiln.schema import (
    TY_BOOL,
    TY_BYTES,
    TY_DICT,
    TY_F32,
    TY_F64,
    TY_I16,
    TY_I32,
    TY_I64,
    TY_I8,
    TY_LIST,
    TY_OPT,
    TY_STR,
    TY_STRUCT,
    TY_U16,
    TY_U32,
    TY_U64,
    TY_U8,
    Schema,
)
from kiln.wire import MAX_DEPTH, Reader, Writer


comptime VK_NONE = 0
comptime VK_BOOL = 1
comptime VK_I64 = 2
comptime VK_U64 = 3
comptime VK_F32 = 4
comptime VK_F64 = 5
comptime VK_STR = 6
comptime VK_BYTES = 7
comptime VK_LIST = 8
comptime VK_STRUCT = 9
comptime VK_DICT = 10


struct VEdge(Copyable, ImplicitlyCopyable):
    var key: Int
    var val: Int

    def __init__(out self, key: Int, val: Int):
        self.key = key
        self.val = val


struct VNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int
    var child: Int
    var nchild: Int

    def __init__(out self, kind: Int):
        self.kind = kind
        self.a = 0
        self.child = -1
        self.nchild = 0


struct Value(Movable):
    """A schema-directed Kiln value.

    Integers are stored as `Int64` or `UInt64` bits and checked against
    the schema type at encode time. Struct children are in field order.
    Dict entries carry their key on the edge.
    """

    var nodes: List[VNode]
    var edges: List[VEdge]
    var texts: List[String]
    var words: List[UInt64]
    var blob: List[UInt8]
    var blob_at: List[Int]
    var blob_n: List[Int]
    var root: Int

    def __init__(out self):
        self.nodes = List[VNode]()
        self.edges = List[VEdge]()
        self.texts = List[String]()
        self.words = List[UInt64]()
        self.blob = List[UInt8]()
        self.blob_at = List[Int]()
        self.blob_n = List[Int]()
        self.root = 0

    def _node(mut self, kind: Int) -> Int:
        var id = len(self.nodes)
        self.nodes.append(VNode(kind))
        return id

    def _text(mut self, var s: String) -> Int:
        var id = len(self.texts)
        self.texts.append(s^)
        return id

    def _word(mut self, id: Int, bits: UInt64):
        var n = self.nodes[id]
        n.a = len(self.words)
        self.words.append(bits)
        self.nodes[id] = n

    def add_none(mut self) -> Int:
        return self._node(VK_NONE)

    def add_bool(mut self, v: Bool) -> Int:
        var id = self._node(VK_BOOL)
        var n = self.nodes[id]
        if v:
            n.a = 1
        self.nodes[id] = n
        return id

    def add_i64(mut self, v: Int64) -> Int:
        var id = self._node(VK_I64)
        self._word(id, UInt64(v.to_bits()))
        return id

    def add_u64(mut self, v: UInt64) -> Int:
        var id = self._node(VK_U64)
        self._word(id, v)
        return id

    def add_f32(mut self, v: Float32) -> Int:
        var id = self._node(VK_F32)
        self._word(id, UInt64(UInt32(v.to_bits())))
        return id

    def add_f64(mut self, v: Float64) -> Int:
        var id = self._node(VK_F64)
        self._word(id, UInt64(v.to_bits()))
        return id

    def add_str(mut self, var s: String) -> Int:
        var id = self._node(VK_STR)
        var n = self.nodes[id]
        n.a = self._text(s^)
        self.nodes[id] = n
        return id

    def add_bytes(mut self, data: List[UInt8]) -> Int:
        var id = self._node(VK_BYTES)
        var at = len(self.blob)
        var i = 0
        while i < len(data):
            self.blob.append(data[i])
            i += 1
        var slot = len(self.blob_at)
        self.blob_at.append(at)
        self.blob_n.append(len(data))
        var n = self.nodes[id]
        n.a = slot
        self.nodes[id] = n
        return id

    def start_list(mut self) -> Int:
        return self._node(VK_LIST)

    def start_struct(mut self) -> Int:
        return self._node(VK_STRUCT)

    def start_dict(mut self) -> Int:
        return self._node(VK_DICT)

    def _attach(mut self, parent: Int, key: Int, val: Int):
        var n = self.nodes[parent]
        if n.child < 0 or n.child + n.nchild != len(self.edges):
            var start = len(self.edges)
            var i = 0
            var base = n.child
            while i < n.nchild:
                self.edges.append(self.edges[base + i])
                i += 1
            n.child = start
        self.edges.append(VEdge(key, val))
        n.nchild += 1
        self.nodes[parent] = n

    def push(mut self, parent: Int, child: Int):
        self._attach(parent, -1, child)

    def add_entry(mut self, parent: Int, var key: String, child: Int):
        var kid = self._text(key^)
        self._attach(parent, kid, child)

    def child(self, id: Int, index: Int) -> Int:
        return self.edges[self.nodes[id].child + index].val

    def child_key(self, id: Int, index: Int) -> String:
        return self.texts[self.edges[self.nodes[id].child + index].key]


def encode_value(schema: Schema, value: Value, mut w: Writer, max_depth: Int = MAX_DEPTH) raises KilnError:
    w.length = 0
    w.depth = 0
    w.max_depth = max_depth
    _enc(schema, schema.root, value, value.root, w)


def encode_value_bytes(schema: Schema, value: Value, max_depth: Int = MAX_DEPTH) raises KilnError -> List[UInt8]:
    var w = Writer(256)
    encode_value(schema, value, w, max_depth)
    return w.copy_bytes()


def decode_value[
    origin: ImmOrigin
](schema: Schema, data: Span[UInt8, origin], check_utf8: Bool = True, max_depth: Int = MAX_DEPTH) raises KilnError -> Value:
    var r = Reader[origin](data, check_utf8, max_depth)
    var dest = Value()
    dest.root = _dec(schema, schema.root, r, dest)
    if r.pos != len(data):
        raise KilnError(KilnError.TRAILING, r.pos)
    return dest^


def _need(value: Value, id: Int, kind: Int) raises KilnError:
    if id < 0 or id >= len(value.nodes) or value.nodes[id].kind != kind:
        raise KilnError(KilnError.TYPE, 0)


def _enc(schema: Schema, sid: Int, value: Value, nid: Int, mut w: Writer) raises KilnError:
    var sk = schema.kind[sid]
    if sk == TY_BOOL:
        _need(value, nid, VK_BOOL)
        if value.nodes[nid].a != 0:
            w.put_u8(UInt8(1))
        else:
            w.put_u8(UInt8(0))
        return
    if sk == TY_I8 or sk == TY_I16 or sk == TY_I32 or sk == TY_I64:
        _need(value, nid, VK_I64)
        var wide = Int64(from_bits=value.words[value.nodes[nid].a])
        _put_signed(w, sk, wide)
        return
    if sk == TY_U8 or sk == TY_U16 or sk == TY_U32 or sk == TY_U64:
        _need(value, nid, VK_U64)
        _put_unsigned(w, sk, value.words[value.nodes[nid].a])
        return
    if sk == TY_F32:
        _need(value, nid, VK_F32)
        w.put_u32(UInt32(value.words[value.nodes[nid].a]))
        return
    if sk == TY_F64:
        _need(value, nid, VK_F64)
        w.put_u64(value.words[value.nodes[nid].a])
        return
    if sk == TY_STR:
        _need(value, nid, VK_STR)
        var text = value.texts[value.nodes[nid].a]
        var sp = text.as_bytes()
        w.put_u32(UInt32(len(sp)))
        w.put_span(sp)
        return
    if sk == TY_BYTES:
        _need(value, nid, VK_BYTES)
        var slot = value.nodes[nid].a
        var at = value.blob_at[slot]
        var n = value.blob_n[slot]
        w.put_u32(UInt32(n))
        var i = 0
        while i < n:
            w.put_u8(value.blob[at + i])
            i += 1
        return
    if sk == TY_OPT:
        if value.nodes[nid].kind == VK_NONE:
            w.put_u8(UInt8(0))
            return
        w.put_u8(UInt8(1))
        w.enter()
        _enc(schema, schema.aux[sid], value, nid, w)
        w.leave()
        return
    if sk == TY_LIST:
        _need(value, nid, VK_LIST)
        w.enter()
        var n = value.nodes[nid].nchild
        w.put_u32(UInt32(n))
        var i = 0
        while i < n:
            _enc(schema, schema.aux[sid], value, value.child(nid, i), w)
            i += 1
        w.leave()
        return
    if sk == TY_DICT:
        _need(value, nid, VK_DICT)
        w.enter()
        _enc_dict(schema, sid, value, nid, w)
        w.leave()
        return
    if sk == TY_STRUCT:
        _need(value, nid, VK_STRUCT)
        w.enter()
        var n = schema.field_n[sid]
        if value.nodes[nid].nchild != n:
            raise KilnError(KilnError.SCHEMA, w.length)
        var i = 0
        while i < n:
            var ft = schema.field_type[schema.field_start[sid] + i]
            _enc(schema, ft, value, value.child(nid, i), w)
            i += 1
        w.leave()
        return
    raise KilnError(KilnError.SCHEMA, w.length)


def _put_signed(mut w: Writer, kind: Int, v: Int64) raises KilnError:
    if kind == TY_I8:
        if v < Int64(-128) or v > Int64(127):
            raise KilnError(KilnError.RANGE, w.length)
        w.put_u8(UInt8(Int8(v).to_bits()))
        return
    if kind == TY_I16:
        if v < Int64(-32768) or v > Int64(32767):
            raise KilnError(KilnError.RANGE, w.length)
        w.put_u16(UInt16(Int16(v).to_bits()))
        return
    if kind == TY_I32:
        if v < Int64(-2147483648) or v > Int64(2147483647):
            raise KilnError(KilnError.RANGE, w.length)
        w.put_i32(Int32(v))
        return
    w.put_i64(v)


def _put_unsigned(mut w: Writer, kind: Int, v: UInt64) raises KilnError:
    if kind == TY_U8:
        if v > UInt64(255):
            raise KilnError(KilnError.RANGE, w.length)
        w.put_u8(UInt8(v))
        return
    if kind == TY_U16:
        if v > UInt64(65535):
            raise KilnError(KilnError.RANGE, w.length)
        w.put_u16(UInt16(v))
        return
    if kind == TY_U32:
        if v > UInt64(4294967295):
            raise KilnError(KilnError.RANGE, w.length)
        w.put_u32(UInt32(v))
        return
    w.put_u64(v)


def _enc_dict(schema: Schema, sid: Int, value: Value, nid: Int, mut w: Writer) raises KilnError:
    var n = value.nodes[nid].nchild
    var keys = List[String]()
    var idx = List[Int]()
    var i = 0
    while i < n:
        keys.append(value.child_key(nid, i))
        idx.append(i)
        i += 1
    _sort_idx(keys, idx)
    w.put_u32(UInt32(n))
    i = 0
    while i < n:
        var at = idx[i]
        var key = keys[at]
        var sp = key.as_bytes()
        w.put_u32(UInt32(len(sp)))
        w.put_span(sp)
        _enc(schema, schema.aux[sid], value, value.child(nid, at), w)
        i += 1


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
    while i < len(idx):
        var j = i
        while j > 0 and _less(keys[idx[j]], keys[idx[j - 1]]):
            var tmp = idx[j]
            idx[j] = idx[j - 1]
            idx[j - 1] = tmp
            j -= 1
        i += 1


def _dec[origin: ImmOrigin](schema: Schema, sid: Int, mut r: Reader[origin], mut dest: Value) raises KilnError -> Int:
    var sk = schema.kind[sid]
    if sk == TY_BOOL:
        return dest.add_bool(r.boolean())
    if sk == TY_I8:
        return dest.add_i64(Int64(Int8(from_bits=r.u8())))
    if sk == TY_I16:
        return dest.add_i64(Int64(Int16(from_bits=r.u16())))
    if sk == TY_I32:
        return dest.add_i64(Int64(r.i32()))
    if sk == TY_I64:
        return dest.add_i64(r.i64())
    if sk == TY_U8:
        return dest.add_u64(UInt64(r.u8()))
    if sk == TY_U16:
        return dest.add_u64(UInt64(r.u16()))
    if sk == TY_U32:
        return dest.add_u64(UInt64(r.u32()))
    if sk == TY_U64:
        return dest.add_u64(r.u64())
    if sk == TY_F32:
        return dest.add_f32(r.f32())
    if sk == TY_F64:
        return dest.add_f64(r.f64())
    if sk == TY_STR:
        var s = r.read_string()
        return dest.add_str(s^)
    if sk == TY_BYTES:
        var n = r.count()
        var sp = r.take(n)
        var tmp = List[UInt8]()
        var i = 0
        while i < n:
            tmp.append(sp[i])
            i += 1
        return dest.add_bytes(tmp)
    if sk == TY_OPT:
        var tag = Int(r.u8())
        if tag == 0:
            return dest.add_none()
        if tag != 1:
            raise KilnError(KilnError.TYPE, r.pos - 1)
        r.enter()
        var inner = _dec(schema, schema.aux[sid], r, dest)
        r.leave()
        return inner
    if sk == TY_LIST:
        r.enter()
        var n = r.count()
        var id = dest.start_list()
        var i = 0
        while i < n:
            var child = _dec(schema, schema.aux[sid], r, dest)
            dest.push(id, child)
            i += 1
        r.leave()
        return id
    if sk == TY_DICT:
        r.enter()
        var n = r.count()
        var id = dest.start_dict()
        var i = 0
        while i < n:
            var key = r.read_string()
            var child = _dec(schema, schema.aux[sid], r, dest)
            dest.add_entry(id, key^, child)
            i += 1
        r.leave()
        return id
    if sk == TY_STRUCT:
        r.enter()
        var id = dest.start_struct()
        var n = schema.field_n[sid]
        var i = 0
        while i < n:
            var ft = schema.field_type[schema.field_start[sid] + i]
            var child = _dec(schema, ft, r, dest)
            dest.push(id, child)
            i += 1
        r.leave()
        return id
    raise KilnError(KilnError.SCHEMA, r.pos)
