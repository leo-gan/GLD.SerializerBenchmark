from std.collections import List, Span

from smile_runtime.error import DecodeError
from smile_runtime.utf8 import string_from_span


comptime K_NULL = 1
comptime K_BOOL = 2
comptime K_I32 = 3
comptime K_I64 = 4
comptime K_BIGINT = 5
comptime K_F32 = 6
comptime K_F64 = 7
comptime K_DECIMAL = 8
comptime K_STRING = 9
comptime K_BINARY = 10
comptime K_ARRAY = 11
comptime K_OBJECT = 12

comptime MAX_DEPTH = 1024
# A corrupt length must not allocate without a bound. 64 MiB is above any
# test value and below the spec's theoretical 2 GiB length field.
comptime MAX_BLOB = 67108864

comptime I32_MIN = -2147483648
comptime I32_MAX = 2147483647


struct Slice(Copyable, ImplicitlyCopyable):
    var at: Int
    var n: Int

    def __init__(out self, at: Int, n: Int):
        self.at = at
        self.n = n


struct Edge(Copyable, ImplicitlyCopyable):
    """One array element (`key` is -1) or one object field (`key` is a text index)."""

    var key: Int
    var val: Int

    def __init__(out self, key: Int, val: Int):
        self.key = key
        self.val = val


struct Node(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int
    var b: Int
    var child: Int
    var nchild: Int

    def __init__(out self, kind: Int):
        self.kind = kind
        self.a = 0
        self.b = 0
        self.child = -1
        self.nchild = 0


struct SmileDoc(Movable):
    """Arena of Smile values. Nodes are integers so the graph is not a recursive struct."""

    var nodes: List[Node]
    var edges: List[Edge]
    var texts: List[String]
    var bytes: List[Byte]
    var slices: List[Slice]
    var f64s: List[UInt64]
    var top: List[Int]

    def __init__(out self):
        self.nodes = List[Node]()
        self.edges = List[Edge]()
        self.texts = List[String]()
        self.bytes = List[Byte]()
        self.slices = List[Slice]()
        self.f64s = List[UInt64]()
        self.top = List[Int]()

    def _node(mut self, kind: Int) -> Int:
        var id = len(self.nodes)
        self.nodes.append(Node(kind))
        return id

    def _text(mut self, var s: String) -> Int:
        # Repeated short keys share one slot so the encoder can match them by index.
        # The scan stops at 64 so a long document of unique strings stays linear.
        var limit = len(self.texts)
        if limit > 64:
            limit = 64
        var i = 0
        while i < limit:
            if self.texts[i] == s:
                return i
            i += 1
        var id = len(self.texts)
        self.texts.append(s^)
        return id

    def _save(mut self, var raw: List[Byte]) -> Int:
        var sl = Slice(len(self.bytes), len(raw))
        var i = 0
        while i < len(raw):
            self.bytes.append(raw[i])
            i += 1
        var id = len(self.slices)
        self.slices.append(sl)
        return id

    def _push(mut self, var n: Node) -> Int:
        var id = len(self.nodes)
        self.nodes.append(n^)
        return id

    def add_null(mut self) -> Int:
        return self._push(Node(K_NULL))

    def add_bool(mut self, v: Bool) -> Int:
        var n = Node(K_BOOL)
        if v:
            n.a = 1
        return self._push(n^)

    def add_i32(mut self, v: Int) -> Int:
        var n = Node(K_I32)
        n.a = v
        return self._push(n^)

    def add_i64(mut self, v: Int) -> Int:
        var n = Node(K_I64)
        n.a = v
        return self._push(n^)

    def add_f32(mut self, v: Float32) -> Int:
        var id = self._node(K_F32)
        var n = self.nodes[id]
        n.a = Int(UInt32(v.to_bits()))
        self.nodes[id] = n
        return id

    def add_f32_bits(mut self, bits: Int) -> Int:
        var id = self._node(K_F32)
        var n = self.nodes[id]
        n.a = bits
        self.nodes[id] = n
        return id

    def add_f64(mut self, v: Float64) -> Int:
        return self.add_f64_bits(UInt64(v.to_bits()))

    def add_f64_bits(mut self, bits: UInt64) -> Int:
        var id = self._node(K_F64)
        var n = self.nodes[id]
        n.a = len(self.f64s)
        self.f64s.append(bits)
        self.nodes[id] = n
        return id

    def add_string(mut self, var s: String) -> Int:
        return self.add_string_index(self._text(s^))

    def add_string_index(mut self, text_index: Int) -> Int:
        """A second node for text that is already in the arena. Shared refs use this."""
        var n = Node(K_STRING)
        n.a = text_index
        return self._push(n^)

    def add_string_span[origin: ImmOrigin](mut self, raw: Span[Byte, origin], offset: Int) raises DecodeError -> Int:
        var s = string_from_span(raw, offset)
        return self.add_string(s^)

    def add_binary(mut self, var raw: List[Byte]) -> Int:
        var id = self._node(K_BINARY)
        var n = self.nodes[id]
        n.a = self._save(raw^)
        self.nodes[id] = n
        return id

    def add_bigint(mut self, var raw: List[Byte]) -> Int:
        var id = self._node(K_BIGINT)
        var n = self.nodes[id]
        n.a = self._save(raw^)
        self.nodes[id] = n
        return id

    def add_decimal(mut self, scale: Int, var raw: List[Byte]) -> Int:
        var id = self._node(K_DECIMAL)
        var n = self.nodes[id]
        n.a = scale
        n.b = self._save(raw^)
        self.nodes[id] = n
        return id

    def start_array(mut self) -> Int:
        return self._node(K_ARRAY)

    def start_object(mut self) -> Int:
        return self._node(K_OBJECT)

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
        self.edges.append(Edge(key, val))
        n.nchild += 1
        self.nodes[parent] = n

    def add_elem(mut self, parent: Int, val: Int):
        self._attach(parent, -1, val)

    def add_field(mut self, parent: Int, key: Int, val: Int):
        self._attach(parent, key, val)

    def add_top(mut self, id: Int):
        self.top.append(id)

    def text_at(self, id: Int) -> String:
        return self.texts[id]

    def slice_copy(self, sid: Int) -> List[Byte]:
        var sl = self.slices[sid]
        var out = List[Byte]()
        var i = 0
        while i < sl.n:
            out.append(self.bytes[sl.at + i])
            i += 1
        return out^
