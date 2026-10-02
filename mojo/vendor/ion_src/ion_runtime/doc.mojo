from std.collections import List, Span

from ion_runtime.error import DecodeError
from ion_runtime.intx import BigInt
from ion_runtime.utf8 import validate_utf8


comptime K_NULL = 1
comptime K_BOOL = 2
comptime K_INT = 3
comptime K_FLOAT = 4
comptime K_DECIMAL = 5
comptime K_TIMESTAMP = 6
comptime K_STRING = 7
comptime K_SYMBOL = 8
comptime K_BLOB = 9
comptime K_CLOB = 10
comptime K_LIST = 11
comptime K_SEXP = 12
comptime K_STRUCT = 13
comptime K_HOLE = 14

comptime PREC_YEAR = 0
comptime PREC_MONTH = 1
comptime PREC_DAY = 2
comptime PREC_MIN = 3
comptime PREC_SEC = 4
comptime PREC_FRAC = 5

comptime MAX_DEPTH = 1024


struct IonTime(Copyable, ImplicitlyCopyable):
    """Local-time timestamp fields. `unknown` means offset `-00:00`. Fraction limbs live in the document."""

    var prec: Int
    var off: Int
    var unknown: Bool
    var year: Int
    var month: Int
    var day: Int
    var hour: Int
    var minute: Int
    var second: Int
    var frac_exp: Int
    var frac_at: Int
    var frac_len: Int

    def __init__(out self):
        self.prec = PREC_YEAR
        self.off = 0
        self.unknown = True
        self.year = 1
        self.month = 1
        self.day = 1
        self.hour = 0
        self.minute = 0
        self.second = 0
        self.frac_exp = 0
        self.frac_at = 0
        self.frac_len = 0


struct IonNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int
    var b: Int
    var c: Int
    var d: Int
    var ann: Int
    var ann_n: Int
    var child: Int
    var nchild: Int

    def __init__(out self, kind: Int):
        self.kind = kind
        self.a = 0
        self.b = 0
        self.c = 0
        self.d = -1
        self.ann = -1
        self.ann_n = 0
        self.child = -1
        self.nchild = 0


struct IonEdge(Copyable, ImplicitlyCopyable):
    var child: Int
    var field: Int
    var next: Int

    def __init__(out self, child: Int, field: Int):
        self.child = child
        self.field = field
        self.next = -1


struct SymRef(Copyable, ImplicitlyCopyable):
    var text: Int
    var sid: Int
    var imp_name: Int
    var imp_sid: Int

    def __init__(out self, text: Int, sid: Int, imp_name: Int, imp_sid: Int):
        self.text = text
        self.sid = sid
        self.imp_name = imp_name
        self.imp_sid = imp_sid


struct IonDoc(Movable):
    var nodes: List[IonNode]
    var edges: List[IonEdge]
    var anns: List[Int]
    var texts: List[String]
    var syms: List[SymRef]
    var limbs: List[UInt32]
    var floats: List[UInt64]
    var times: List[IonTime]
    var blob_at: List[Int]
    var blob_len: List[Int]
    var blob_bytes: List[Byte]
    var top: List[Int]
    var sym_at: List[Int]

    def __init__(out self):
        self.nodes = List[IonNode]()
        self.edges = List[IonEdge]()
        self.anns = List[Int]()
        self.texts = List[String]()
        self.syms = List[SymRef]()
        self.limbs = List[UInt32]()
        self.floats = List[UInt64]()
        self.times = List[IonTime]()
        self.blob_at = List[Int]()
        self.blob_len = List[Int]()
        self.blob_bytes = List[Byte]()
        self.top = List[Int]()
        self.sym_at = List[Int]()

    def reserve(mut self, n: Int):
        var count = n
        if count < 8:
            count = 8
        self.nodes.reserve(count)
        self.edges.reserve(count)
        self.limbs.reserve(count)
        self.top.reserve(count)
        self.texts.reserve(16)
        self.syms.reserve(16)

    def intern(mut self, text: String) -> Int:
        var i = 0
        while i < len(self.texts):
            if self.texts[i] == text:
                return i
            i += 1
        self.texts.append(text)
        self.sym_at.append(-1)
        return len(self.texts) - 1

    def _add(mut self, node: IonNode) -> Int:
        self.nodes.append(node)
        return len(self.nodes) - 1

    def add_null(mut self, null_type: Int) -> Int:
        var n = IonNode(K_NULL)
        n.a = null_type
        return self._add(n)

    def add_bool(mut self, value: Bool) -> Int:
        var n = IonNode(K_BOOL)
        if value:
            n.a = 1
        return self._add(n)

    def add_int(mut self, var value: BigInt) -> Int:
        var n = IonNode(K_INT)
        n.a = len(self.limbs)
        n.b = len(value.limbs)
        if value.neg:
            n.c = 1
        var i = 0
        while i < len(value.limbs):
            self.limbs.append(value.limbs[i])
            i += 1
        return self._add(n)

    def add_i64(mut self, value: Int64) -> Int:
        """Store `value` as one or two little-endian limbs. Zero keeps an empty limb list."""
        var n = IonNode(K_INT)
        if value == Int64(0):
            return self._add(n)
        var mag = UInt64(value)
        if value < Int64(0):
            n.c = 1
            if value == Int64(-9223372036854775807) - Int64(1):
                mag = UInt64(0x8000000000000000)
            else:
                mag = UInt64(0) - UInt64(value)
        n.a = len(self.limbs)
        var lo = UInt32(mag & UInt64(0xFFFFFFFF))
        var hi = UInt32(mag >> UInt64(32))
        self.limbs.append(lo)
        n.b = 1
        if hi != UInt32(0):
            self.limbs.append(hi)
            n.b = 2
        return self._add(n)

    def add_float(mut self, width: Int, bits: UInt64) -> Int:
        var n = IonNode(K_FLOAT)
        n.a = width
        n.b = len(self.floats)
        self.floats.append(bits)
        return self._add(n)

    def add_decimal(mut self, var coef: BigInt, neg: Bool, exp: Int) -> Int:
        var n = IonNode(K_DECIMAL)
        n.a = len(self.limbs)
        n.b = len(coef.limbs)
        if neg or coef.neg:
            n.c = 1
        n.d = exp
        var i = 0
        while i < len(coef.limbs):
            self.limbs.append(coef.limbs[i])
            i += 1
        return self._add(n)

    def add_time(mut self, when: IonTime) -> Int:
        var n = IonNode(K_TIMESTAMP)
        n.a = len(self.times)
        self.times.append(when)
        return self._add(n)

    def add_string(mut self, text: String) -> Int:
        var n = IonNode(K_STRING)
        n.a = self.intern(text)
        return self._add(n)

    def add_string_at(mut self, text_i: Int) -> Int:
        var n = IonNode(K_STRING)
        n.a = text_i
        return self._add(n)

    def add_string_raw[origin: ImmOrigin](mut self, span: Span[Byte, origin], offset: Int) raises DecodeError -> Int:
        """Intern `span` and add a string node. ASCII skips the UTF-8 checker. A repeat reuses the text."""
        var n = len(span)
        var k = 0
        while k < n:
            if Int(span[k]) >= 128:
                validate_utf8(span, offset)
                break
            k += 1
        var i = 0
        while i < len(self.texts):
            var b = self.texts[i].as_bytes()
            if len(b) == n:
                var same = True
                var j = 0
                while j < n:
                    if Int(b[j]) != Int(span[j]):
                        same = False
                        break
                    j += 1
                if same:
                    return self.add_string_at(i)
            i += 1
        self.texts.append(String(unsafe_from_utf8=span))
        self.sym_at.append(-1)
        return self.add_string_at(len(self.texts) - 1)

    def add_symbol_text(mut self, text: String) -> Int:
        """A symbol whose text is known, including the empty symbol `''`.

        Repeated text reuses one symbol node. Callers that only need the text can share it.
        """
        var ti = self.intern(text)
        var cached = self.sym_at[ti]
        if cached >= 0:
            return cached
        var n = IonNode(K_SYMBOL)
        var s = SymRef(ti, 0, -1, 0)
        n.a = len(self.syms)
        self.syms.append(s)
        var id = self._add(n)
        self.sym_at[ti] = id
        return id

    def wrap_sym(mut self, sym: Int) -> Int:
        var n = IonNode(K_SYMBOL)
        n.a = sym
        return self._add(n)

    def add_symbol_ref(mut self, var sym: SymRef) -> Int:
        var n = IonNode(K_SYMBOL)
        n.a = len(self.syms)
        self.syms.append(sym^)
        return self._add(n)

    def add_bytes(mut self, kind: Int, var data: List[Byte]) -> Int:
        var n = IonNode(kind)
        n.a = len(self.blob_at)
        self.blob_at.append(len(self.blob_bytes))
        self.blob_len.append(len(data))
        var i = 0
        while i < len(data):
            self.blob_bytes.append(data[i])
            i += 1
        return self._add(n)

    def start_container(mut self, kind: Int) -> Int:
        return self._add(IonNode(kind))

    def add_child(mut self, parent: Int, child: Int, field: Int):
        var edge = IonEdge(child, field)
        var idx = len(self.edges)
        self.edges.append(edge)
        var node = self.nodes[parent]
        if node.child < 0:
            node.child = idx
        else:
            var prev = self.edges[node.d]
            prev.next = idx
            self.edges[node.d] = prev
        node.d = idx
        node.nchild += 1
        self.nodes[parent] = node

    def set_anns(mut self, id: Int, var anns: List[Int]):
        if len(anns) == 0:
            return
        var node = self.nodes[id]
        node.ann = len(self.anns)
        node.ann_n = len(anns)
        var i = 0
        while i < len(anns):
            self.anns.append(anns[i])
            i += 1
        self.nodes[id] = node

    def add_top(mut self, id: Int):
        self.top.append(id)

    def child_at(self, parent: Int, index: Int) -> Int:
        var edge = self.nodes[parent].child
        var i = 0
        while i < index:
            edge = self.edges[edge].next
            i += 1
        return self.edges[edge].child

    def field_at(self, parent: Int, index: Int) -> Int:
        var edge = self.nodes[parent].child
        var i = 0
        while i < index:
            edge = self.edges[edge].next
            i += 1
        return self.edges[edge].field

    def text_at(self, id: Int) -> String:
        return self.texts[self.nodes[id].a]

    def sym_text(self, sym: Int) -> String:
        var s = self.syms[sym]
        if s.text < 0:
            return String()
        return self.texts[s.text]

    def limbs_eq(self, a_at: Int, a_len: Int, b_at: Int, b_len: Int) -> Bool:
        if a_len != b_len:
            return False
        var i = 0
        while i < a_len:
            if self.limbs[a_at + i] != self.limbs[b_at + i]:
                return False
            i += 1
        return True
