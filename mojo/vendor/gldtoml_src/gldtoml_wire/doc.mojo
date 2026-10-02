from std.collections import List

from gldtoml_runtime.error import DecodeError
from gldtoml_wire.utf8 import string_from_bytes


comptime TK_STRING = 1
comptime TK_INT = 2
comptime TK_FLOAT = 3
comptime TK_TRUE = 4
comptime TK_FALSE = 5
comptime TK_ARRAY = 6
comptime TK_TABLE = 7
comptime TK_DATETIME = 8

comptime DT_OFFSET = 1
comptime DT_LOCAL = 2
comptime DT_DATE = 3
comptime DT_TIME = 4

comptime FLAG_EXPLICIT = 1
comptime FLAG_FROZEN = 2

comptime MAX_DEPTH = 128


struct TomlNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int64
    var b: UInt64
    var c: Int
    var parent: Int
    var flags: Int
    var tail: Int

    def __init__(
        out self,
        kind: Int,
        a: Int64 = 0,
        b: UInt64 = 0,
        c: Int = 0,
        parent: Int = -1,
    ):
        self.kind = kind
        self.a = a
        self.b = b
        self.c = c
        self.parent = parent
        self.flags = 0
        self.tail = -1


struct Edge(Copyable, ImplicitlyCopyable):
    var key: Int
    var child: Int
    var next: Int

    def __init__(out self, key: Int, child: Int, next: Int):
        self.key = key
        self.child = child
        self.next = next


struct TomlDateTime(Copyable, ImplicitlyCopyable):
    var sub: Int
    var year: Int
    var month: Int
    var day: Int
    var hour: Int
    var minute: Int
    var second: Int
    var has_second: Bool
    var nanos: Int
    var offset_minutes: Int
    var offset_z: Bool

    def __init__(out self):
        self.sub = 0
        self.year = 0
        self.month = 0
        self.day = 0
        self.hour = 0
        self.minute = 0
        self.second = 0
        self.has_second = False
        self.nanos = 0
        self.offset_minutes = 0
        self.offset_z = False


struct TomlDoc(Movable):
    """Arena of TOML values. Containers link children through `edges` in document order."""

    var nodes: List[TomlNode]
    var edges: List[Edge]
    var texts: List[String]
    var dates: List[TomlDateTime]
    var root: Int

    def __init__(out self):
        self.nodes = List[TomlNode](capacity=16)
        self.edges = List[Edge](capacity=16)
        self.texts = List[String](capacity=8)
        self.dates = List[TomlDateTime]()
        self.nodes.append(TomlNode(TK_TABLE, a=Int64(-1), parent=-1))
        self.root = 0

    def _push(mut self, node: TomlNode, parent: Int) -> Int:
        var idx = len(self.nodes)
        var stored = node
        stored.parent = parent
        self.nodes.append(stored)
        return idx

    def add_text(mut self, var text: String) -> Int:
        var idx = len(self.texts)
        self.texts.append(text^)
        return idx

    def add_date(mut self, dt: TomlDateTime) -> Int:
        var idx = len(self.dates)
        self.dates.append(dt)
        return idx

    def make_string(mut self, var text: String, parent: Int) -> Int:
        var ti = self.add_text(text^)
        return self._push(TomlNode(TK_STRING, a=Int64(ti)), parent)

    def make_int(mut self, v: Int64, parent: Int) -> Int:
        return self._push(TomlNode(TK_INT, a=v), parent)

    def make_float(mut self, bits: UInt64, parent: Int) -> Int:
        return self._push(TomlNode(TK_FLOAT, b=bits), parent)

    def make_bool(mut self, v: Bool, parent: Int) -> Int:
        if v:
            return self._push(TomlNode(TK_TRUE), parent)
        return self._push(TomlNode(TK_FALSE), parent)

    def make_array(mut self, parent: Int) -> Int:
        return self._push(TomlNode(TK_ARRAY, a=Int64(-1)), parent)

    def make_table(mut self, parent: Int) -> Int:
        return self._push(TomlNode(TK_TABLE, a=Int64(-1)), parent)

    def make_datetime(mut self, dt: TomlDateTime, parent: Int) -> Int:
        var di = self.add_date(dt)
        return self._push(TomlNode(TK_DATETIME, a=Int64(di), c=dt.sub), parent)

    def kind(self, node: Int) -> Int:
        return self.nodes[node].kind

    def set_flag(mut self, node: Int, bit: Int):
        self.nodes[node].flags = self.nodes[node].flags | bit

    def has_flag(self, node: Int, bit: Int) -> Bool:
        if node < 0:
            return False
        return (self.nodes[node].flags & bit) != 0

    def frozen(self, node: Int) -> Bool:
        var n = node
        while n >= 0:
            if (self.nodes[n].flags & FLAG_FROZEN) != 0:
                return True
            n = self.nodes[n].parent
        return False

    def append_child(mut self, parent: Int, key: Int, child: Int):
        var e = len(self.edges)
        self.edges.append(Edge(key, child, -1))
        self.nodes[child].parent = parent
        var last = self.nodes[parent].tail
        if last < 0:
            self.nodes[parent].a = Int64(e)
        else:
            self.edges[last].next = e
        self.nodes[parent].tail = e
        self.nodes[parent].c += 1

    def child_count(self, node: Int) -> Int:
        return self.nodes[node].c

    def first_edge(self, node: Int) -> Int:
        return Int(self.nodes[node].a)

    def find_key(self, table: Int, key: String) -> Int:
        var e = self.first_edge(table)
        while e >= 0:
            var edge = self.edges[e]
            if edge.key >= 0 and self.text_eq(edge.key, key):
                return edge.child
            e = edge.next
        return -1

    def text_eq(self, idx: Int, key: String) -> Bool:
        ref stored = self.texts[idx]
        if stored.byte_length() != key.byte_length():
            return False
        var a = stored.as_bytes()
        var b = key.as_bytes()
        var i = 0
        while i < len(a):
            if a[i] != b[i]:
                return False
            i += 1
        return True

    def text_at(self, node: Int) -> String:
        return self.texts[Int(self.nodes[node].a)]

    def int_at(self, node: Int) -> Int64:
        return self.nodes[node].a

    def float_at(self, node: Int) -> Float64:
        return Float64(from_bits=self.nodes[node].b)

    def date_at(self, node: Int) -> TomlDateTime:
        return self.dates[Int(self.nodes[node].a)]


def bytes_to_string(buf: List[Byte], offset: Int) raises DecodeError -> String:
    return string_from_bytes(buf, offset)
