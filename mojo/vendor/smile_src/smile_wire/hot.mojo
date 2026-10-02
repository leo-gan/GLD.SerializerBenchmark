"""Flat encoder and decoder for objects of integers and short ASCII text.

The loop is in this small module so the compiler keeps the back-reference check
next to the bytes it emits. Any other token is refused and the general codec
handles that document.
"""

from std.collections import List, Span

from smile_runtime.doc import (
    K_BOOL,
    K_I32,
    K_I64,
    K_NULL,
    K_OBJECT,
    K_STRING,
    Edge,
    Node,
    SmileDoc,
)
from smile_runtime.options import EncodeOptions


struct HotEncode(Movable):
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


struct HotDecode(Movable):
    var ok: Bool
    var doc: SmileDoc

    def __init__(out self):
        self.ok = False
        self.doc = SmileDoc()

    def take_doc(mut self) -> SmileDoc:
        var empty = SmileDoc()
        var out = self.doc^
        self.doc = empty^
        return out^


def _ascii(doc: SmileDoc, tid: Int) -> Bool:
    if tid < 0 or tid >= len(doc.texts):
        return False
    var raw = doc.texts[tid].as_bytes()
    if len(raw) > 64:
        return False
    var i = 0
    while i < len(raw):
        if Int(raw[i]) >= 0x80:
            return False
        i += 1
    return True


def _leaf(k: Int) -> Bool:
    if k == K_I64 or k == K_I32 or k == K_STRING or k == K_NULL or k == K_BOOL:
        return True
    return False


def _shape(doc: SmileDoc) -> Bool:
    var i = 0
    while i < len(doc.top):
        var n = doc.nodes[doc.top[i]]
        if n.kind != K_OBJECT:
            return False
        var j = 0
        while j < n.nchild:
            var e = doc.edges[n.child + j]
            if not _ascii(doc, e.key):
                return False
            var vn = doc.nodes[e.val]
            if not _leaf(vn.kind):
                return False
            if vn.kind == K_STRING and not _ascii(doc, vn.a):
                return False
            if vn.kind == K_I32 and (vn.a < -16 or vn.a > 15):
                return False
            if vn.kind == K_I64 and (vn.a < 0 or vn.a > 31):
                return False
            j += 1
        i += 1
    return True


def _find(doc: SmileDoc, ids: List[Int], text: Int) -> Int:
    var i = 0
    while i < len(ids):
        if (i & 0xFF) < 0xFE and ids[i] == text:
            return i
        i += 1
    if len(ids) == 0:
        return -1
    var target = doc.texts[text]
    i = 0
    while i < len(ids):
        if (i & 0xFF) < 0xFE and doc.texts[ids[i]] == target:
            return i
        i += 1
    return -1


def _put_text(mut buf: List[Byte], doc: SmileDoc, tid: Int, key_mode: Bool):
    var raw = doc.texts[tid].as_bytes()
    var n = len(raw)
    if n == 0:
        buf.append(Byte(0x20))
        return
    if key_mode:
        buf.append(Byte(0x7F + n))
    else:
        buf.append(Byte(0x3F + n))
    var i = 0
    while i < n:
        buf.append(raw[i])
        i += 1


def encode_hot(doc: SmileDoc, options: EncodeOptions) -> HotEncode:
    var out = HotEncode()
    if not _shape(doc):
        return out^
    var values_on = False
    if options.header:
        values_on = options.shared_values
    var buf = List[Byte]()
    buf.reserve(512)
    if options.header:
        var flags = 0
        if options.shared_names:
            flags |= 0x01
        if options.shared_values:
            flags |= 0x02
        if options.raw_binary:
            flags |= 0x04
        buf.append(Byte(0x3A))
        buf.append(Byte(0x29))
        buf.append(Byte(0x0A))
        buf.append(Byte(flags))
    var names = List[Int]()
    var values = List[Int]()
    var nt0 = -1
    var ni0 = -1
    var nt1 = -1
    var ni1 = -1
    var vt0 = -1
    var vi0 = -1
    var vt1 = -1
    var vi1 = -1
    var t = 0
    while t < len(doc.top):
        var n = doc.nodes[doc.top[t]]
        buf.append(Byte(0xFA))
        var j = 0
        var child = n.child
        while j < n.nchild:
            var e = doc.edges[child + j]
            var key = e.key
            var nix = -1
            if options.shared_names and key == nt0 and ni0 >= 0 and (ni0 & 0xFF) < 0xFE:
                nix = ni0
            elif options.shared_names and key == nt1 and ni1 >= 0 and (ni1 & 0xFF) < 0xFE:
                nix = ni1
            elif options.shared_names:
                nix = _find(doc, names, key)
                if nix >= 0:
                    nt1 = nt0
                    ni1 = ni0
                    nt0 = key
                    ni0 = nix
            if nix >= 0 and nix < 64:
                buf.append(Byte(0x40 + nix))
            elif nix >= 0:
                buf.append(Byte(0x30 + (nix >> 8)))
                buf.append(Byte(nix & 0xFF))
            else:
                var kn = doc.texts[key].byte_length()
                _put_text(buf, doc, key, True)
                if options.shared_names and kn > 0:
                    if len(names) == 1024:
                        names.resize(0, 0)
                        nt0 = -1
                        ni0 = -1
                        nt1 = -1
                        ni1 = -1
                    var ix = len(names)
                    names.append(key)
                    if (ix & 0xFF) < 0xFE:
                        nt1 = nt0
                        ni1 = ni0
                        nt0 = key
                        ni0 = ix
            var vn = doc.nodes[e.val]
            if vn.kind == K_I64:
                var z = vn.a << 1
                buf.append(Byte(0x25))
                buf.append(Byte(0))
                buf.append(Byte(0))
                buf.append(Byte(0))
                buf.append(Byte(0))
                buf.append(Byte(0x80 | z))
            elif vn.kind == K_I32:
                var z32 = vn.a << 1
                if vn.a < 0:
                    z32 = ((0 - vn.a) << 1) - 1
                buf.append(Byte(0xC0 + z32))
            elif vn.kind == K_NULL:
                buf.append(Byte(0x21))
            elif vn.kind == K_BOOL:
                if vn.a == 0:
                    buf.append(Byte(0x22))
                else:
                    buf.append(Byte(0x23))
            else:
                var text = vn.a
                var vix = -1
                if values_on and text == vt0 and vi0 >= 0 and (vi0 & 0xFF) < 0xFE:
                    vix = vi0
                elif values_on and text == vt1 and vi1 >= 0 and (vi1 & 0xFF) < 0xFE:
                    vix = vi1
                elif values_on:
                    vix = _find(doc, values, text)
                    if vix >= 0:
                        vt1 = vt0
                        vi1 = vi0
                        vt0 = text
                        vi0 = vix
                if vix >= 0 and vix < 31:
                    buf.append(Byte(1 + vix))
                elif vix >= 0:
                    buf.append(Byte(0xEC + (vix >> 8)))
                    buf.append(Byte(vix & 0xFF))
                else:
                    var sn = doc.texts[text].byte_length()
                    _put_text(buf, doc, text, False)
                    if values_on and sn > 0:
                        if len(values) == 1024:
                            values.resize(0, 0)
                            vt0 = -1
                            vi0 = -1
                            vt1 = -1
                            vi1 = -1
                        var ix = len(values)
                        values.append(text)
                        if (ix & 0xFF) < 0xFE:
                            vt1 = vt0
                            vi1 = vi0
                            vt0 = text
                            vi0 = ix
            j += 1
        buf.append(Byte(0xFB))
        t += 1
    if options.end_marker:
        buf.append(Byte(0xFF))
    out.ok = True
    out.buf = buf^
    return out^


def _copy_ascii[origin: ImmOrigin](raw: Span[Byte, origin], at: Int, n: Int) -> String:
    var tmp = List[Byte]()
    var k = 0
    while k < n:
        tmp.append(raw[at + k])
        k += 1
    return String(unsafe_from_utf8=Span(tmp))


def _ascii_at[origin: ImmOrigin](raw: Span[Byte, origin], at: Int, n: Int) -> Bool:
    if at < 0 or n < 0 or at + n > len(raw):
        return False
    var k = 0
    while k < n:
        if Int(raw[at + k]) >= 0x80:
            return False
        k += 1
    return True


def decode_hot[origin: ImmOrigin](raw: Span[Byte, origin]) -> HotDecode:
    var out = HotDecode()
    var n = len(raw)
    if n == 0:
        out.ok = True
        return out^
    var doc = SmileDoc()
    doc.nodes.reserve(n)
    doc.edges.reserve(n)
    var i = 0
    var names_on = True
    var values_on = False
    if n >= 4 and Int(raw[0]) == 0x3A:
        if Int(raw[1]) != 0x29 or Int(raw[2]) != 0x0A or ((Int(raw[3]) >> 4) & 0xF) != 0:
            return out^
        var flags = Int(raw[3])
        names_on = (flags & 0x01) != 0
        values_on = (flags & 0x02) != 0
        i = 4
    var name_ids = List[Int]()
    var value_ids = List[Int]()
    var p = raw.unsafe_ptr()
    while i < n:
        var c = Int(p.unsafe_load(i))
        if c == 0xFF and i + 1 == n:
            i += 1
            break
        if c != 0xFA:
            return out^
        i += 1
        var oid = len(doc.nodes)
        var obj = Node(K_OBJECT)
        doc.nodes.append(obj^)
        var base = len(doc.edges)
        var nchild = 0
        # A repeated record is often a shared name, a small int64, another shared
        # name, and a shared string. Those ten bytes are one check, then two nodes.
        var paired = False
        if i + 10 <= n and names_on and values_on:
            var k0 = Int(p.unsafe_load(i))
            var t25 = Int(p.unsafe_load(i + 1))
            var z0 = Int(p.unsafe_load(i + 2))
            var z1 = Int(p.unsafe_load(i + 3))
            var z2 = Int(p.unsafe_load(i + 4))
            var z3 = Int(p.unsafe_load(i + 5))
            var zend = Int(p.unsafe_load(i + 6))
            var k1 = Int(p.unsafe_load(i + 7))
            var vs = Int(p.unsafe_load(i + 8))
            var endb = Int(p.unsafe_load(i + 9))
            if (
                k0 >= 0x40
                and k0 <= 0x7F
                and t25 == 0x25
                and (z0 | z1 | z2 | z3) == 0
                and (zend & 0x80) != 0
                and k1 >= 0x40
                and k1 <= 0x7F
                and vs >= 0x01
                and vs <= 0x1F
                and endb == 0xFB
            ):
                var ix0 = k0 - 0x40
                var ix1 = k1 - 0x40
                var six = vs - 1
                if ix0 < len(name_ids) and ix1 < len(name_ids) and six < len(value_ids):
                    var z = zend & 0x3F
                    var iv = z >> 1
                    if (z & 1) != 0:
                        iv = -iv - 1
                    var nn = Node(K_I64)
                    nn.a = iv
                    var iid = len(doc.nodes)
                    doc.nodes.append(nn^)
                    var sn = Node(K_STRING)
                    sn.a = value_ids[six]
                    var sid = len(doc.nodes)
                    doc.nodes.append(sn^)
                    base = len(doc.edges)
                    doc.edges.append(Edge(name_ids[ix0], iid))
                    doc.edges.append(Edge(name_ids[ix1], sid))
                    nchild = 2
                    i += 10
                    paired = True
        if not paired:
            while True:
                if i >= n:
                    return out^
                var kb = Int(p.unsafe_load(i))
                if kb == 0xFB:
                    i += 1
                    break
                var key: Int
                if kb >= 0x40 and kb <= 0x7F:
                    var ix = kb - 0x40
                    if not names_on or ix >= len(name_ids):
                        return out^
                    i += 1
                    key = name_ids[ix]
                elif kb >= 0x80 and kb <= 0xBF:
                    var ln = 1 + (kb & 0x3F)
                    i += 1
                    if not _ascii_at(raw, i, ln):
                        return out^
                    key = doc._text(_copy_ascii(raw, i, ln))
                    i += ln
                    if names_on:
                        if len(name_ids) == 1024:
                            name_ids.resize(0, 0)
                        name_ids.append(key)
                else:
                    return out^
                if i >= n:
                    return out^
                var vb = Int(p.unsafe_load(i))
                var val: Int
                var high = 0
                if vb == 0x25 and i + 6 <= n:
                    high = Int(p.unsafe_load(i + 1)) | Int(p.unsafe_load(i + 2)) | Int(p.unsafe_load(i + 3)) | Int(p.unsafe_load(i + 4))
                if vb == 0x25 and i + 6 <= n and high == 0 and (Int(p.unsafe_load(i + 5)) & 0x80) != 0:
                    var z = Int(p.unsafe_load(i + 5)) & 0x3F
                    i += 6
                    var v = z >> 1
                    if (z & 1) != 0:
                        v = -v - 1
                    var nn = Node(K_I64)
                    nn.a = v
                    val = len(doc.nodes)
                    doc.nodes.append(nn^)
                elif vb >= 0x01 and vb <= 0x1F:
                    var six = vb - 1
                    if not values_on or six >= len(value_ids):
                        return out^
                    i += 1
                    var sn = Node(K_STRING)
                    sn.a = value_ids[six]
                    val = len(doc.nodes)
                    doc.nodes.append(sn^)
                elif vb >= 0xC0 and vb <= 0xDF:
                    i += 1
                    var z32 = vb & 0x1F
                    var mag = z32 >> 1
                    if (z32 & 1) != 0:
                        mag = -mag - 1
                    var nn = Node(K_I32)
                    nn.a = mag
                    val = len(doc.nodes)
                    doc.nodes.append(nn^)
                elif vb >= 0x40 and vb <= 0x7F:
                    var ln = 1 + (vb & 0x3F)
                    i += 1
                    if not _ascii_at(raw, i, ln):
                        return out^
                    var tid = doc._text(_copy_ascii(raw, i, ln))
                    i += ln
                    var sn = Node(K_STRING)
                    sn.a = tid
                    val = len(doc.nodes)
                    doc.nodes.append(sn^)
                    if values_on:
                        if len(value_ids) == 1024:
                            value_ids.resize(0, 0)
                        value_ids.append(tid)
                elif vb == 0x20:
                    i += 1
                    val = doc.add_string(String())
                elif vb == 0x21:
                    i += 1
                    val = doc.add_null()
                elif vb == 0x22 or vb == 0x23:
                    i += 1
                    val = doc.add_bool(vb == 0x23)
                else:
                    return out^
                if nchild == 0:
                    base = len(doc.edges)
                doc.edges.append(Edge(key, val))
                nchild += 1
        var parent = doc.nodes[oid]
        if nchild == 0:
            parent.child = -1
        else:
            parent.child = base
        parent.nchild = nchild
        doc.nodes[oid] = parent
        doc.add_top(oid)
    if i != n:
        return out^
    out.ok = True
    out.doc = doc^
    return out^
