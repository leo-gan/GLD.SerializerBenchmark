from std.collections import List


comptime JSON_NULL = 0
comptime JSON_BOOL = 1
comptime JSON_INT = 2
comptime JSON_FLOAT = 3
comptime JSON_STRING = 4
comptime JSON_ARRAY = 5
comptime JSON_OBJECT = 6


struct JsonError(Copyable, ImplicitlyCopyable, Writable):
    var message: String
    var offset: Int

    def __init__(out self, message: String, offset: Int = 0):
        self.message = message
        self.offset = offset

    def write_to[W: Writer](self, mut writer: W):
        writer.write("JsonError(", self.message, ", offset=", self.offset, ")")


struct JsonNode(Copyable, Movable):
    var kind: Int
    var b: Bool
    var i: Int64
    var f: Float64
    var s: String
    var first: Int
    var count: Int

    def __init__(out self):
        self.kind = JSON_NULL
        self.b = False
        self.i = 0
        self.f = 0.0
        self.s = String()
        self.first = -1
        self.count = 0


struct JsonDoc(Movable):
    var nodes: List[JsonNode]
    var refs: List[Int]
    var root: Int

    def __init__(out self):
        self.nodes = List[JsonNode]()
        self.refs = List[Int]()
        self.root = -1

    def add(mut self, var node: JsonNode) -> Int:
        var id = len(self.nodes)
        self.nodes.append(node^)
        return id

    def kind(self, id: Int) -> Int:
        return self.nodes[id].kind

    def as_bool(self, id: Int) -> Bool:
        return self.nodes[id].b

    def as_int(self, id: Int) -> Int64:
        return self.nodes[id].i

    def as_float(self, id: Int) -> Float64:
        return self.nodes[id].f

    def as_string(self, id: Int) -> String:
        return self.nodes[id].s

    def child(self, id: Int, index: Int) -> Int:
        return self.refs[self.nodes[id].first + index]

    def obj_key(self, id: Int, index: Int) -> String:
        return self.nodes[self.refs[self.nodes[id].first + index * 2]].s

    def obj_val(self, id: Int, index: Int) -> Int:
        return self.refs[self.nodes[id].first + index * 2 + 1]

    def find(self, id: Int, key: String) -> Int:
        if self.nodes[id].kind != JSON_OBJECT:
            return -1
        var i = 0
        var count = self.nodes[id].count
        var first = self.nodes[id].first
        while i < count:
            var kid = self.refs[first + i * 2]
            if self.nodes[kid].s == key:
                return self.refs[first + i * 2 + 1]
            i += 1
        return -1
