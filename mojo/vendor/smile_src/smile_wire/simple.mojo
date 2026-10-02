"""Straight-line codec for the common Smile subset.

Null, bool, int32, int64, short ASCII text, arrays, and objects stay in one
function so a repeated key is an integer compare next to the byte it writes.
Floats, big numbers, long text, and raw binary stay on the general codec.
A value this path does not fully recognize is left unconsumed for that codec.
"""

from std.collections import List, Span

from smile_runtime.doc import (
    I32_MAX,
    I32_MIN,
    K_ARRAY,
    K_BIGINT,
    K_BINARY,
    K_BOOL,
    K_DECIMAL,
    K_F32,
    K_F64,
    K_I32,
    K_I64,
    K_NULL,
    K_OBJECT,
    K_STRING,
    MAX_DEPTH,
    Edge,
    Node,
    SmileDoc,
)
from smile_runtime.options import EncodeOptions


comptime _SHARE = 1024
comptime _ASCII_MAX = 64


@always_inline
def _zz32(v: Int) -> UInt64:
    var u = UInt64(v) & 0xFFFFFFFF
    var shifted = (u << 1) & 0xFFFFFFFF
    var sign = UInt64(0)
    if (u & 0x80000000) != 0:
        sign = 0xFFFFFFFF
    return shifted ^ sign


@always_inline
def _zz64(v: Int) -> UInt64:
    var u = UInt64(v)
    var sign = UInt64(0)
    if v < 0:
        sign = 0xFFFFFFFFFFFFFFFF
    return (u << 1) ^ sign


@always_inline
def _zz_dec64(u: UInt64) -> Int:
    var mag = u >> 1
    if (u & 1) == 0:
        return Int(mag)
    if mag == 0x7FFFFFFFFFFFFFFF:
        return Int(UInt64(1) << 63)
    return -Int(mag) - 1


def _ascii_ok(doc: SmileDoc, tid: Int) -> Bool:
    if tid < 0 or tid >= len(doc.texts):
        return False
    var raw = doc.texts[tid].as_bytes()
    if len(raw) > _ASCII_MAX:
        return False
    var i = 0
    while i < len(raw):
        if Int(raw[i]) >= 0x80:
            return False
        i += 1
    return True


def _tree_simple(doc: SmileDoc) -> Bool:
    var stack = List[Int]()
    var i = 0
    while i < len(doc.top):
        stack.append(doc.top[i])
        i += 1
    while len(stack) > 0:
        var id = stack[len(stack) - 1]
        stack.resize(len(stack) - 1, 0)
        var n = doc.nodes[id]
        if n.kind == K_OBJECT or n.kind == K_ARRAY:
            var j = 0
            while j < n.nchild:
                var e = doc.edges[n.child + j]
                if n.kind == K_OBJECT and not _ascii_ok(doc, e.key):
                    return False
                stack.append(e.val)
                j += 1
            continue
        if n.kind == K_STRING:
            if not _ascii_ok(doc, n.a):
                return False
            continue
        if n.kind == K_I32:
            if n.a < I32_MIN or n.a > I32_MAX:
                return False
            continue
        if n.kind == K_NULL or n.kind == K_BOOL or n.kind == K_I64:
            continue
        if (
            n.kind == K_BIGINT
            or n.kind == K_F32
            or n.kind == K_F64
            or n.kind == K_DECIMAL
            or n.kind == K_BINARY
        ):
            return False
        return False
    return True


@always_inline
def _uvint(mut buf: List[Byte], u: UInt64, min_bytes: Int):
    var mag = u >> 6
    var nbytes = 1
    var tmp = mag
    while tmp > 0:
        nbytes += 1
        tmp = tmp >> 7
    if nbytes < min_bytes:
        nbytes = min_bytes
    var cont = nbytes - 1
    var i = cont
    while i > 0:
        var shift = (i - 1) * 7
        buf.append(Byte(Int((mag >> UInt64(shift)) & 0x7F)))
        i -= 1
    buf.append(Byte(0x80 | Int(u & 0x3F)))


struct _Run:
    var base: Int
    var nchild: Int

    def __init__(out self):
        self.base = 0
        self.nchild = 0


@always_inline
def _i64_bytes(mut buf: List[Byte], z: UInt64):
    # Six bits still use five data bytes so the token stays int64.
    if z < 64:
        buf.append(Byte(0x25))
        buf.append(Byte(0))
        buf.append(Byte(0))
        buf.append(Byte(0))
        buf.append(Byte(0))
        buf.append(Byte(0x80 | Int(z)))
        return
    buf.append(Byte(0x25))
    _uvint(buf, z, 5)


def _find_id(doc: SmileDoc, ids: List[Int], text_index: Int) -> Int:
    var i = 0
    while i < len(ids):
        if (i & 0xFF) < 0xFE and ids[i] == text_index:
            return i
        i += 1
    if len(ids) == 0:
        return -1
    var target = doc.texts[text_index]
    i = 0
    while i < len(ids):
        if (i & 0xFF) < 0xFE and doc.texts[ids[i]] == target:
            return i
        i += 1
    return -1


struct SimpleEncode(Movable):
    var ok: Bool
    var buf: List[Byte]

    def __init__(out self):
        self.ok = False
        self.buf = List[Byte]()

    def take_buf(mut self) -> List[Byte]:
        var empty = List[Byte]()
        var out = self.buf^
        self.buf = empty^
        return out^


struct _Enc:
    var buf: List[Byte]
    var names_on: Bool
    var values_on: Bool
    var names: List[Int]
    var values: List[Int]
    var nt0: Int
    var ni0: Int
    var nt1: Int
    var ni1: Int
    var vt0: Int
    var vi0: Int
    var vt1: Int
    var vi1: Int

    def __init__(out self, names_on: Bool, values_on: Bool, guess: Int):
        self.buf = List[Byte]()
        self.buf.reserve(guess)
        self.names_on = names_on
        self.values_on = values_on
        self.names = List[Int]()
        self.values = List[Int]()
        self.nt0 = -1
        self.ni0 = -1
        self.nt1 = -1
        self.ni1 = -1
        self.vt0 = -1
        self.vi0 = -1
        self.vt1 = -1
        self.vi1 = -1

    @always_inline
    def put(mut self, b: Int):
        self.buf.append(Byte(b & 0xFF))

    @always_inline
    def _bytes(mut self, doc: SmileDoc, tid: Int):
        var raw = doc.texts[tid].as_bytes()
        var i = 0
        while i < len(raw):
            self.buf.append(raw[i])
            i += 1

    @always_inline
    def _remember_name(mut self, text: Int, ix: Int):
        if ix < 0 or (ix & 0xFF) >= 0xFE:
            return
        self.nt1 = self.nt0
        self.ni1 = self.ni0
        self.nt0 = text
        self.ni0 = ix

    @always_inline
    def _remember_value(mut self, text: Int, ix: Int):
        if ix < 0 or (ix & 0xFF) >= 0xFE:
            return
        self.vt1 = self.vt0
        self.vi1 = self.vi0
        self.vt0 = text
        self.vi0 = ix

    @always_inline
    def _name_ix(mut self, doc: SmileDoc, text: Int) -> Int:
        if text == self.nt0 and self.ni0 >= 0 and (self.ni0 & 0xFF) < 0xFE:
            return self.ni0
        if text == self.nt1 and self.ni1 >= 0 and (self.ni1 & 0xFF) < 0xFE:
            return self.ni1
        var ix = _find_id(doc, self.names, text)
        if ix >= 0:
            self._remember_name(text, ix)
        return ix

    @always_inline
    def _value_ix(mut self, doc: SmileDoc, text: Int) -> Int:
        if text == self.vt0 and self.vi0 >= 0 and (self.vi0 & 0xFF) < 0xFE:
            return self.vi0
        if text == self.vt1 and self.vi1 >= 0 and (self.vi1 & 0xFF) < 0xFE:
            return self.vi1
        var ix = _find_id(doc, self.values, text)
        if ix >= 0:
            self._remember_value(text, ix)
        return ix

    @always_inline
    def _push_name(mut self, text: Int):
        if len(self.names) == _SHARE:
            self.names.resize(0, 0)
            self.nt0 = -1
            self.ni0 = -1
            self.nt1 = -1
            self.ni1 = -1
        self.names.append(text)
        self._remember_name(text, len(self.names) - 1)

    @always_inline
    def _push_value(mut self, text: Int):
        if len(self.values) == _SHARE:
            self.values.resize(0, 0)
            self.vt0 = -1
            self.vi0 = -1
            self.vt1 = -1
            self.vi1 = -1
        self.values.append(text)
        self._remember_value(text, len(self.values) - 1)

    @always_inline
    def _ref_name(mut self, ix: Int):
        if ix < 64:
            self.put(0x40 + ix)
            return
        self.put(0x30 + (ix >> 8))
        self.put(ix & 0xFF)

    @always_inline
    def _ref_value(mut self, ix: Int):
        if ix < 31:
            self.put(1 + ix)
            return
        self.put(0xEC + (ix >> 8))
        self.put(ix & 0xFF)

    @always_inline
    def write_key(mut self, doc: SmileDoc, text: Int):
        if self.names_on:
            var ix = self._name_ix(doc, text)
            if ix >= 0:
                self._ref_name(ix)
                return
        var n = doc.texts[text].byte_length()
        if n == 0:
            self.put(0x20)
            return
        self.put(0x7F + n)
        self._bytes(doc, text)
        if self.names_on:
            self._push_name(text)

    @always_inline
    def write_str(mut self, doc: SmileDoc, text: Int):
        if self.values_on:
            var ix = self._value_ix(doc, text)
            if ix >= 0:
                self._ref_value(ix)
                return
        var n = doc.texts[text].byte_length()
        if n == 0:
            self.put(0x20)
            return
        self.put(0x3F + n)
        self._bytes(doc, text)
        if self.values_on:
            self._push_value(text)

    def write_val(mut self, doc: SmileDoc, id: Int):
        var n = doc.nodes[id]
        if n.kind == K_NULL:
            self.put(0x21)
            return
        if n.kind == K_BOOL:
            if n.a == 0:
                self.put(0x22)
            else:
                self.put(0x23)
            return
        if n.kind == K_I32:
            var z32 = _zz32(n.a)
            if z32 <= 0x1F:
                self.put(0xC0 + Int(z32))
                return
            self.put(0x24)
            _uvint(self.buf, z32, 1)
            return
        if n.kind == K_I64:
            var z64 = _zz64(n.a)
            _i64_bytes(self.buf, z64)
            return
        if n.kind == K_STRING:
            self.write_str(doc, n.a)
            return
        if n.kind == K_ARRAY:
            self.put(0xF8)
            var i = 0
            while i < n.nchild:
                self.write_val(doc, doc.edges[n.child + i].val)
                i += 1
            self.put(0xF9)
            return
        self.put(0xFA)
        var i = 0
        while i < n.nchild:
            var e = doc.edges[n.child + i]
            self.write_key(doc, e.key)
            var vn = doc.nodes[e.val]
            if vn.kind == K_I64:
                _i64_bytes(self.buf, _zz64(vn.a))
            elif vn.kind == K_STRING:
                self.write_str(doc, vn.a)
            elif vn.kind == K_I32:
                var z32 = _zz32(vn.a)
                if z32 <= 0x1F:
                    self.put(0xC0 + Int(z32))
                else:
                    self.put(0x24)
                    _uvint(self.buf, z32, 1)
            else:
                self.write_val(doc, e.val)
            i += 1
        self.put(0xFB)

    def take_buf(mut self) -> List[Byte]:
        var empty = List[Byte]()
        var out = self.buf^
        self.buf = empty^
        return out^


def encode_simple(doc: SmileDoc, options: EncodeOptions) -> SimpleEncode:
    var out = SimpleEncode()
    if not _tree_simple(doc):
        return out^
    var values_on = False
    if options.header:
        values_on = options.shared_values
    var guess = len(doc.nodes) * 8 + 16
    if guess < 64:
        guess = 64
    var w = _Enc(options.shared_names, values_on, guess)
    if options.header:
        var flags = 0
        if options.shared_names:
            flags |= 0x01
        if options.shared_values:
            flags |= 0x02
        if options.raw_binary:
            flags |= 0x04
        w.put(0x3A)
        w.put(0x29)
        w.put(0x0A)
        w.put(flags)
    var i = 0
    while i < len(doc.top):
        var id = doc.top[i]
        var n = doc.nodes[id]
        if n.kind == K_OBJECT:
            # Top-level objects are the hot shape. The field loop stays in this
            # function so a back-reference is not a call.
            w.put(0xFA)
            var j = 0
            var child = n.child
            var nchild = n.nchild
            while j < nchild:
                var e = doc.edges[child + j]
                var key = e.key
                var hit = -1
                if w.names_on and key == w.nt0 and w.ni0 >= 0 and (w.ni0 & 0xFF) < 0xFE:
                    hit = w.ni0
                elif w.names_on and key == w.nt1 and w.ni1 >= 0 and (w.ni1 & 0xFF) < 0xFE:
                    hit = w.ni1
                if hit >= 0 and hit < 64:
                    w.buf.append(Byte(0x40 + hit))
                else:
                    w.write_key(doc, key)
                var vn = doc.nodes[e.val]
                if vn.kind == K_I64 and vn.a >= 0 and vn.a < 32:
                    var zsmall = vn.a << 1
                    w.buf.append(Byte(0x25))
                    w.buf.append(Byte(0))
                    w.buf.append(Byte(0))
                    w.buf.append(Byte(0))
                    w.buf.append(Byte(0))
                    w.buf.append(Byte(0x80 | zsmall))
                elif vn.kind == K_I64:
                    _i64_bytes(w.buf, _zz64(vn.a))
                elif vn.kind == K_STRING and w.values_on and vn.a == w.vt0 and w.vi0 >= 0 and w.vi0 < 31 and (w.vi0 & 0xFF) < 0xFE:
                    w.buf.append(Byte(1 + w.vi0))
                elif vn.kind == K_STRING and w.values_on and vn.a == w.vt1 and w.vi1 >= 0 and w.vi1 < 31 and (w.vi1 & 0xFF) < 0xFE:
                    w.buf.append(Byte(1 + w.vi1))
                elif vn.kind == K_STRING:
                    w.write_str(doc, vn.a)
                elif vn.kind == K_I32:
                    var z32 = _zz32(vn.a)
                    if z32 <= 0x1F:
                        w.put(0xC0 + Int(z32))
                    else:
                        w.put(0x24)
                        _uvint(w.buf, z32, 1)
                else:
                    w.write_val(doc, e.val)
                j += 1
            w.put(0xFB)
        else:
            w.write_val(doc, id)
        i += 1
    if options.end_marker:
        w.put(0xFF)
    out.ok = True
    out.buf = w.take_buf()
    return out^


struct PartialDecode(Movable):
    var done: Bool
    var i: Int
    var names_on: Bool
    var values_on: Bool
    var raw_bin: Bool
    var name_ids: List[Int]
    var value_ids: List[Int]
    var doc: SmileDoc

    def __init__(out self):
        self.done = False
        self.i = 0
        self.names_on = True
        self.values_on = False
        self.raw_bin = False
        self.name_ids = List[Int]()
        self.value_ids = List[Int]()
        self.doc = SmileDoc()

    def take_names(mut self) -> List[Int]:
        var empty = List[Int]()
        var out = self.name_ids^
        self.name_ids = empty^
        return out^

    def take_values(mut self) -> List[Int]:
        var empty = List[Int]()
        var out = self.value_ids^
        self.value_ids = empty^
        return out^

    def take_doc(mut self) -> SmileDoc:
        var empty = SmileDoc()
        var out = self.doc^
        self.doc = empty^
        return out^


struct _Parser[origin: ImmOrigin]:
    var raw: Span[Byte, Self.origin]
    var i: Int
    var depth: Int
    var names_on: Bool
    var values_on: Bool
    var raw_bin: Bool
    var name_ids: List[Int]
    var value_ids: List[Int]
    var doc: SmileDoc

    def __init__(out self, raw: Span[Byte, Self.origin]):
        self.raw = raw
        self.i = 0
        self.depth = 0
        self.names_on = True
        self.values_on = False
        self.raw_bin = False
        self.name_ids = List[Int]()
        self.value_ids = List[Int]()
        self.doc = SmileDoc()

    @always_inline
    def _b(self, at: Int) -> Int:
        return Int(self.raw.unsafe_ptr().unsafe_load(at))

    def _push_name(mut self, tid: Int):
        if len(self.name_ids) == _SHARE:
            self.name_ids.resize(0, 0)
        self.name_ids.append(tid)

    def _push_value(mut self, tid: Int):
        if len(self.value_ids) == _SHARE:
            self.value_ids.resize(0, 0)
        self.value_ids.append(tid)

    def _ascii(mut self, at: Int, n: Int) -> Int:
        var tmp = List[Byte]()
        var k = 0
        while k < n:
            tmp.append(Byte(self._b(at + k)))
            k += 1
        return self.doc._text(String(unsafe_from_utf8=Span(tmp)))

    def _ascii_bytes(self, at: Int, n: Int) -> Bool:
        if at < 0 or n < 0 or at + n > len(self.raw):
            return False
        var k = 0
        while k < n:
            if self._b(at + k) >= 0x80:
                return False
            k += 1
        return True

    @always_inline
    def _i64_5(mut self) -> Int:
        if self.i + 6 > len(self.raw):
            return -1
        var b0 = self._b(self.i + 1)
        var b1 = self._b(self.i + 2)
        var b2 = self._b(self.i + 3)
        var b3 = self._b(self.i + 4)
        var b4 = self._b(self.i + 5)
        if (b0 | b1 | b2 | b3) >= 128 or (b4 & 0x80) == 0:
            return -1
        self.i += 6
        var z = b4 & 0x3F
        var v = z >> 1
        if (b0 | b1 | b2 | b3) == 0:
            if (z & 1) != 0:
                v = -v - 1
        else:
            var acc = UInt64(b0)
            acc = (acc << 7) | UInt64(b1)
            acc = (acc << 7) | UInt64(b2)
            acc = (acc << 7) | UInt64(b3)
            acc = (acc << 6) | UInt64(z)
            v = _zz_dec64(acc)
        var nn = Node(K_I64)
        nn.a = v
        var id = len(self.doc.nodes)
        self.doc.nodes.append(nn^)
        return id

    def _short_ascii(mut self, n: Int, share_value: Bool) -> Int:
        if not self._ascii_bytes(self.i, n):
            return -1
        var tid = self._ascii(self.i, n)
        self.i += n
        var id = self.doc.add_string_index(tid)
        if share_value and self.values_on:
            self._push_value(tid)
        return id

    @always_inline
    def _scalar(mut self) -> Int:
        if self.i >= len(self.raw):
            return -1
        var ch = self._b(self.i)
        if ch == 0x21:
            self.i += 1
            return self.doc.add_null()
        if ch == 0x22:
            self.i += 1
            return self.doc.add_bool(False)
        if ch == 0x23:
            self.i += 1
            return self.doc.add_bool(True)
        if ch == 0x20:
            self.i += 1
            return self.doc.add_string(String())
        if ch >= 0xC0 and ch <= 0xDF:
            self.i += 1
            var z = ch & 0x1F
            var mag = z >> 1
            if (z & 1) != 0:
                mag = -mag - 1
            return self.doc.add_i32(mag)
        if ch >= 0x01 and ch <= 0x1F:
            var ix = ch - 1
            if not self.values_on or ix >= len(self.value_ids):
                return -1
            self.i += 1
            return self.doc.add_string_index(self.value_ids[ix])
        if ch >= 0xEC and ch <= 0xEF:
            if self.i + 1 >= len(self.raw):
                return -1
            var b2 = self._b(self.i + 1)
            var ix = ((ch & 0x3) << 8) | b2
            if not self.values_on or ix >= len(self.value_ids):
                return -1
            self.i += 2
            return self.doc.add_string_index(self.value_ids[ix])
        if ch == 0x25:
            return self._i64_5()
        if ch >= 0x40 and ch <= 0x7F:
            var n = 1 + (ch & 0x3F)
            self.i += 1
            return self._short_ascii(n, True)
        return -2

    @always_inline
    def _key(mut self) -> Int:
        if self.i >= len(self.raw):
            return -1
        var ch = self._b(self.i)
        if ch >= 0x40 and ch <= 0x7F:
            var ix = ch - 0x40
            if not self.names_on or ix >= len(self.name_ids):
                return -1
            self.i += 1
            return self.name_ids[ix]
        if ch >= 0x30 and ch <= 0x33:
            if self.i + 1 >= len(self.raw):
                return -1
            var b2 = self._b(self.i + 1)
            var ix = ((ch & 0x3) << 8) | b2
            if not self.names_on or ix >= len(self.name_ids):
                return -1
            self.i += 2
            return self.name_ids[ix]
        if ch == 0x20:
            self.i += 1
            return self.doc._text(String())
        if ch >= 0x80 and ch <= 0xBF:
            var n = 1 + (ch & 0x3F)
            self.i += 1
            if not self._ascii_bytes(self.i, n):
                return -1
            var tid = self._ascii(self.i, n)
            self.i += n
            if self.names_on:
                self._push_name(tid)
            return tid
        return -1

    @always_inline
    def _attach(mut self, mut run: _Run, key: Int, val: Int):
        if run.nchild == 0:
            run.base = len(self.doc.edges)
        elif run.base + run.nchild != len(self.doc.edges):
            var start = len(self.doc.edges)
            var j = 0
            while j < run.nchild:
                self.doc.edges.append(self.doc.edges[run.base + j])
                j += 1
            run.base = start
        self.doc.edges.append(Edge(key, val))
        run.nchild += 1

    @always_inline
    def _seal(mut self, id: Int, base: Int, nchild: Int):
        var parent = self.doc.nodes[id]
        if nchild == 0:
            parent.child = -1
        else:
            parent.child = base
        parent.nchild = nchild
        self.doc.nodes[id] = parent

    def _object(mut self) -> Int:
        self.depth += 1
        if self.depth > MAX_DEPTH:
            return -1
        self.i += 1
        var id = len(self.doc.nodes)
        var obj = Node(K_OBJECT)
        self.doc.nodes.append(obj^)
        var run = _Run()
        while True:
            if self.i >= len(self.raw):
                return -1
            if self._b(self.i) == 0xFB:
                self.i += 1
                break
            var key = self._key()
            if key < 0:
                return -1
            var val = self._scalar()
            if val == -2:
                val = self._val()
            if val < 0:
                return -1
            self._attach(run, key, val)
        self._seal(id, run.base, run.nchild)
        self.depth -= 1
        return id

    def _array(mut self) -> Int:
        self.depth += 1
        if self.depth > MAX_DEPTH:
            return -1
        self.i += 1
        var id = len(self.doc.nodes)
        var obj = Node(K_ARRAY)
        self.doc.nodes.append(obj^)
        var run = _Run()
        while True:
            if self.i >= len(self.raw):
                return -1
            if self._b(self.i) == 0xF9:
                self.i += 1
                break
            var val = self._scalar()
            if val == -2:
                val = self._val()
            if val < 0:
                return -1
            self._attach(run, -1, val)
        self._seal(id, run.base, run.nchild)
        self.depth -= 1
        return id

    def _val(mut self) -> Int:
        if self.i >= len(self.raw):
            return -1
        var ch = self._b(self.i)
        if ch == 0xFA:
            return self._object()
        if ch == 0xF8:
            return self._array()
        var s = self._scalar()
        if s == -2:
            return -1
        return s

    def _rewind(mut self, i0: Int, d0: Int, n0: Int, e0: Int, t0: Int, m0: Int, v0: Int):
        self.i = i0
        self.depth = d0
        if len(self.doc.nodes) != n0:
            self.doc.nodes.resize(n0, Node(K_NULL))
        if len(self.doc.edges) != e0:
            self.doc.edges.resize(e0, Edge(-1, -1))
        if len(self.doc.texts) != t0:
            self.doc.texts.resize(t0, String())
        if len(self.name_ids) != m0:
            self.name_ids.resize(m0, 0)
        if len(self.value_ids) != v0:
            self.value_ids.resize(v0, 0)

    def take_doc(mut self) -> SmileDoc:
        var empty = SmileDoc()
        var out = self.doc^
        self.doc = empty^
        return out^

    def take_names(mut self) -> List[Int]:
        var empty = List[Int]()
        var out = self.name_ids^
        self.name_ids = empty^
        return out^

    def take_values(mut self) -> List[Int]:
        var empty = List[Int]()
        var out = self.value_ids^
        self.value_ids = empty^
        return out^


def decode_simple[origin: ImmOrigin](raw: Span[Byte, origin]) -> PartialDecode:
    var p = _Parser(raw)
    var cap = len(raw)
    if cap < 8:
        cap = 8
    p.doc.nodes.reserve(cap)
    p.doc.edges.reserve(cap)
    p.doc.texts.reserve(8)
    p.doc.top.reserve(8)
    if len(raw) >= 4 and Int(raw[0]) == 0x3A:
        if Int(raw[1]) != 0x29 or Int(raw[2]) != 0x0A:
            return PartialDecode()
        var flags = Int(raw[3])
        if ((flags >> 4) & 0xF) != 0:
            return PartialDecode()
        p.names_on = (flags & 0x01) != 0
        p.values_on = (flags & 0x02) != 0
        p.raw_bin = (flags & 0x04) != 0
        p.i = 4
    while p.i < len(raw):
        var c = p._b(p.i)
        if c == 0xFF:
            if p.i + 1 != len(raw):
                break
            p.i += 1
            break
        if c == 0x3A:
            break
        var i0 = p.i
        var d0 = p.depth
        var n0 = len(p.doc.nodes)
        var e0 = len(p.doc.edges)
        var t0 = len(p.doc.texts)
        var m0 = len(p.name_ids)
        var v0 = len(p.value_ids)
        var id = -1
        if c == 0xFA:
            p.depth += 1
            if p.depth <= MAX_DEPTH:
                p.i += 1
                id = len(p.doc.nodes)
                var obj = Node(K_OBJECT)
                p.doc.nodes.append(obj^)
                var run = _Run()
                var closed = False
                while True:
                    if p.i >= len(raw):
                        id = -1
                        break
                    if p._b(p.i) == 0xFB:
                        p.i += 1
                        closed = True
                        break
                    var kb = p._b(p.i)
                    var key: Int
                    if kb >= 0x40 and kb <= 0x7F:
                        var kix = kb - 0x40
                        if not p.names_on or kix >= len(p.name_ids):
                            id = -1
                            break
                        p.i += 1
                        key = p.name_ids[kix]
                    else:
                        key = p._key()
                        if key < 0:
                            id = -1
                            break
                    if p.i >= len(raw):
                        id = -1
                        break
                    var vb = p._b(p.i)
                    var val = -1
                    if vb == 0x25 and p.i + 6 <= len(raw):
                        var b0 = p._b(p.i + 1)
                        var b1 = p._b(p.i + 2)
                        var b2 = p._b(p.i + 3)
                        var b3 = p._b(p.i + 4)
                        var b4 = p._b(p.i + 5)
                        if (b0 | b1 | b2 | b3) < 128 and (b4 & 0x80) != 0:
                            p.i += 6
                            var z6 = b4 & 0x3F
                            var iv = z6 >> 1
                            if (b0 | b1 | b2 | b3) == 0:
                                if (z6 & 1) != 0:
                                    iv = -iv - 1
                            else:
                                var acc = UInt64(b0)
                                acc = (acc << 7) | UInt64(b1)
                                acc = (acc << 7) | UInt64(b2)
                                acc = (acc << 7) | UInt64(b3)
                                acc = (acc << 6) | UInt64(z6)
                                iv = _zz_dec64(acc)
                            var nn = Node(K_I64)
                            nn.a = iv
                            val = len(p.doc.nodes)
                            p.doc.nodes.append(nn^)
                    elif vb >= 0x01 and vb <= 0x1F:
                        var six = vb - 1
                        if not p.values_on or six >= len(p.value_ids):
                            id = -1
                            break
                        p.i += 1
                        var sn = Node(K_STRING)
                        sn.a = p.value_ids[six]
                        val = len(p.doc.nodes)
                        p.doc.nodes.append(sn^)
                    elif vb >= 0xC0 and vb <= 0xDF:
                        p.i += 1
                        var z32 = vb & 0x1F
                        var mag = z32 >> 1
                        if (z32 & 1) != 0:
                            mag = -mag - 1
                        var nn = Node(K_I32)
                        nn.a = mag
                        val = len(p.doc.nodes)
                        p.doc.nodes.append(nn^)
                    else:
                        val = p._scalar()
                        if val == -2:
                            val = p._val()
                    if val < 0:
                        id = -1
                        break
                    p._attach(run, key, val)
                if closed:
                    p._seal(id, run.base, run.nchild)
                    p.depth -= 1
                else:
                    id = -1
        else:
            id = p._val()
        if id < 0:
            p._rewind(i0, d0, n0, e0, t0, m0, v0)
            break
        p.doc.add_top(id)
    var out = PartialDecode()
    out.done = p.i == len(raw)
    out.i = p.i
    out.names_on = p.names_on
    out.values_on = p.values_on
    out.raw_bin = p.raw_bin
    out.name_ids = p.take_names()
    out.value_ids = p.take_values()
    out.doc = p.take_doc()
    return out^
