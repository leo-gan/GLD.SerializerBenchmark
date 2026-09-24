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
    F_VECTOR_BOOL,
    F_VECTOR_FLOAT2,
    F_VECTOR_FLOAT4,
    F_VECTOR_INT,
    F_VECTOR_INT2,
    F_VECTOR_KEY,
    F_VECTOR_STRING_DEPRECATED,
    flex_byte_width,
    flex_inline,
)


def flex_inline_kind(kind: Int) -> Bool:
    return flex_inline(kind)


struct FlexNode:
    var kind: Int
    var i: Int64
    var u: UInt64
    var f: Float64
    var s: String
    var blob: List[Byte]
    var kids: List[Int]
    var keys: List[String]

    def __init__(out self):
        self.kind = F_NULL
        self.i = 0
        self.u = 0
        self.f = 0.0
        self.s = String()
        self.blob = List[Byte]()
        self.kids = List[Int]()
        self.keys = List[String]()


struct FlexTree:
    """Owned FlexBuffers value. Strings and blobs are copied out of the buffer."""

    var nodes: List[FlexNode]
    var root: Int

    def __init__(out self):
        self.nodes = List[FlexNode]()
        self.root = 0

    def kind(self) -> Int:
        return self.nodes[self.root].kind

    def find(self, node: Int, key: String) -> Int:
        for i in range(len(self.nodes[node].keys)):
            if self.nodes[node].keys[i] == key:
                return self.nodes[node].kids[i]
        return -1

    def _read(mut self, data: List[Byte], pos: Int, parent_width: Int, byte_width: Int, kind: Int) raises -> Int:
        if flex_inline_kind(kind):
            var node = FlexNode()
            node.kind = kind
            if kind == F_NULL:
                pass
            elif kind == F_BOOL:
                node.u = _read_u(data, pos, parent_width)
            elif kind == F_INT:
                node.i = _read_i(data, pos, parent_width)
            elif kind == F_UINT:
                node.u = _read_u(data, pos, parent_width)
            elif kind == F_FLOAT:
                node.f = _read_f(data, pos, parent_width)
            else:
                raise Error("bad type")
            var idx = len(self.nodes)
            self.nodes.append(node^)
            return idx

        var dest = _indirect(data, pos, parent_width)
        if kind == F_STRING or kind == F_BLOB:
            var raw = _read_sized(data, dest, byte_width)
            if kind == F_STRING:
                if dest + len(raw) >= len(data) or data[dest + len(raw)] != 0:
                    raise Error("bad string")
            var node = FlexNode()
            node.kind = kind
            if kind == F_STRING:
                node.s = String(from_utf8=Span(raw))
            else:
                node.blob = raw^
            var idx = len(self.nodes)
            self.nodes.append(node^)
            return idx
        if kind == F_KEY:
            var node = FlexNode()
            node.kind = F_KEY
            node.s = _read_cstring(data, dest)
            var idx = len(self.nodes)
            self.nodes.append(node^)
            return idx
        if kind == F_INDIRECT_INT or kind == F_INDIRECT_UINT or kind == F_INDIRECT_FLOAT:
            var node = FlexNode()
            node.kind = kind
            if kind == F_INDIRECT_INT:
                node.i = _read_i(data, dest, byte_width)
            elif kind == F_INDIRECT_UINT:
                node.u = _read_u(data, dest, byte_width)
            else:
                node.f = _read_f(data, dest, byte_width)
            var idx = len(self.nodes)
            self.nodes.append(node^)
            return idx
        if kind == F_VECTOR or kind == F_MAP or _is_typed(kind) or _is_fixed(kind):
            return self._read_vector(data, dest, byte_width, kind)
        raise Error("bad type")

    def _read_vector(mut self, data: List[Byte], dest: Int, byte_width: Int, kind: Int) raises -> Int:
        var fixed = _is_fixed(kind)
        var n: Int
        if fixed:
            n = _fixed_len(kind)
        else:
            if dest < byte_width:
                raise Error("truncated")
            n = Int(_read_u(data, dest - byte_width, byte_width))
        var kids = List[Int]()
        var keys = List[String]()
        if kind == F_MAP:
            if dest < 3 * byte_width:
                raise Error("truncated")
            var key_width = Int(_read_u(data, dest - 2 * byte_width, byte_width))
            var key_pos = _indirect(data, dest - 3 * byte_width, byte_width)
            if key_pos < key_width:
                raise Error("truncated")
            var key_len = Int(_read_u(data, key_pos - key_width, key_width))
            if key_len != n:
                raise Error("bad map")
            for i in range(n):
                var slot = key_pos + i * key_width
                var key_dest = _indirect(data, slot, key_width)
                keys.append(_read_cstring(data, key_dest))
        var elem_kind = F_NULL
        var typed = _is_typed(kind) or fixed
        if _is_typed(kind):
            elem_kind = _typed_elem(kind)
        elif fixed:
            elem_kind = _fixed_elem(kind)
        for i in range(n):
            var slot = dest + i * byte_width
            if typed:
                kids.append(self._read(data, slot, byte_width, 1, elem_kind))
            else:
                var type_at = dest + n * byte_width + i
                if type_at < 0 or type_at >= len(data):
                    raise Error("truncated")
                var packed = Int(data[type_at])
                var child_width = flex_byte_width(packed & 3)
                var child_kind = packed >> 2
                kids.append(self._read(data, slot, byte_width, child_width, child_kind))
        var node = FlexNode()
        node.kind = kind
        node.kids = kids^
        node.keys = keys^
        var idx = len(self.nodes)
        self.nodes.append(node^)
        return idx


def flex_loads(data: List[Byte]) raises -> FlexTree:
    if len(data) < 3:
        raise Error("truncated")
    var parent = Int(data[len(data) - 1])
    if parent != 1 and parent != 2 and parent != 4 and parent != 8:
        raise Error("bad width")
    var packed = Int(data[len(data) - 2])
    var child_width = flex_byte_width(packed & 3)
    var kind = packed >> 2
    var pos = len(data) - 2 - parent
    if pos < 0:
        raise Error("truncated")
    var tree = FlexTree()
    tree.root = tree._read(data, pos, parent, child_width, kind)
    return tree^


def _read_u(data: List[Byte], pos: Int, width: Int) raises -> UInt64:
    if width != 1 and width != 2 and width != 4 and width != 8:
        raise Error("bad width")
    if pos < 0 or pos + width > len(data):
        raise Error("truncated")
    var v: UInt64 = 0
    for i in range(width):
        v |= UInt64(data[pos + i]) << (UInt64(i) * 8)
    return v


def _read_i(data: List[Byte], pos: Int, width: Int) raises -> Int64:
    var u = _read_u(data, pos, width)
    if width == 1:
        if u >= 128:
            return Int64(u) - 256
        return Int64(u)
    if width == 2:
        if u >= 32768:
            return Int64(u) - 65536
        return Int64(u)
    if width == 4:
        if u >= 2147483648:
            return Int64(u) - 4294967296
        return Int64(u)
    return Int64(u)


def _read_f(data: List[Byte], pos: Int, width: Int) raises -> Float64:
    if width == 4:
        var bits = UInt32(_read_u(data, pos, 4))
        return Float64(Float32(from_bits=bits))
    if width == 8:
        return Float64(from_bits=_read_u(data, pos, 8))
    raise Error("bad float")


def _indirect(data: List[Byte], pos: Int, width: Int) raises -> Int:
    var rel = Int(_read_u(data, pos, width))
    var dest = pos - rel
    if dest < 0 or dest > len(data):
        raise Error("bad offset")
    return dest


def _is_typed(kind: Int) -> Bool:
    if kind >= F_VECTOR_INT and kind <= F_VECTOR_STRING_DEPRECATED:
        return True
    return kind == F_VECTOR_BOOL


def _is_fixed(kind: Int) -> Bool:
    return kind >= F_VECTOR_INT2 and kind <= F_VECTOR_FLOAT4


def _typed_elem(kind: Int) -> Int:
    if kind == F_VECTOR_BOOL:
        return F_BOOL
    if kind >= F_VECTOR_INT and kind <= F_VECTOR_KEY:
        return kind - F_VECTOR_INT + F_INT
    if kind == F_VECTOR_STRING_DEPRECATED:
        return F_KEY
    return F_NULL


def _fixed_elem(kind: Int) -> Int:
    var fixed = kind - F_VECTOR_INT2
    return (fixed % 3) + F_INT


def _fixed_len(kind: Int) -> Int:
    var fixed = kind - F_VECTOR_INT2
    return fixed // 3 + 2


def _read_cstring(data: List[Byte], pos: Int) raises -> String:
    var end = pos
    while end < len(data) and data[end] != 0:
        end += 1
    if end >= len(data):
        raise Error("bad key")
    var tmp = List[Byte]()
    for i in range(pos, end):
        tmp.append(data[i])
    return String(from_utf8=Span(tmp))


def _read_sized(data: List[Byte], data_pos: Int, size_width: Int) raises -> List[Byte]:
    if data_pos < size_width:
        raise Error("truncated")
    var n = Int(_read_u(data, data_pos - size_width, size_width))
    if data_pos + n > len(data):
        raise Error("truncated")
    var tmp = List[Byte]()
    for i in range(n):
        tmp.append(data[data_pos + i])
    return tmp^
