from std.collections import List, Span
from std.memory import unsafe_memcpy

from msgpack_runtime.error import DecodeError
from msgpack_runtime.ext import MsgpackExt
from msgpack_runtime.options import DecodeOptions, EncodeOptions
from msgpack_runtime.timestamp import MsgpackTimestamp
from msgpack_wire.reader import WireReader, timestamp_from_payload
from msgpack_wire.writer import WireWriter


comptime CK_NIL = 0
comptime CK_BOOL = 1
comptime CK_INT = 2
comptime CK_UINT = 3
comptime CK_F32 = 4
comptime CK_F64 = 5
comptime CK_STR = 6
comptime CK_BIN = 7
comptime CK_ARRAY = 8
comptime CK_MAP = 9
comptime CK_EXT = 10
comptime CK_TIMESTAMP = 11


struct MsgpackNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int64
    var b: UInt64
    var c: Int

    def __init__(out self, kind: Int, a: Int64 = 0, b: UInt64 = 0, c: Int = 0):
        self.kind = kind
        self.a = a
        self.b = b
        self.c = c


struct MsgpackValue(Movable):
    """Arena of MessagePack objects. Nested containers use `kids` as indexes."""

    var nodes: List[MsgpackNode]
    var kids: List[Int]
    var texts: List[String]
    var bytes: List[Byte]
    var exts: List[MsgpackExt]
    var root: Int

    def __init__(out self):
        self.nodes = List[MsgpackNode]()
        self.kids = List[Int]()
        self.texts = List[String]()
        self.bytes = List[Byte]()
        self.exts = List[MsgpackExt]()
        self.root = 0

    def add(mut self, node: MsgpackNode) -> Int:
        var idx = len(self.nodes)
        self.nodes.append(node)
        return idx

    def kind(self) -> Int:
        return self.nodes[self.root].kind

    def as_nil(self) raises DecodeError:
        if self.nodes[self.root].kind != CK_NIL:
            raise DecodeError(DecodeError.KIND_TYPE, 0)

    def as_bool(self) raises DecodeError -> Bool:
        if self.nodes[self.root].kind != CK_BOOL:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.nodes[self.root].a != Int64(0)

    def as_int(self) raises DecodeError -> Int64:
        if self.nodes[self.root].kind != CK_INT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.nodes[self.root].a

    def as_uint(self) raises DecodeError -> UInt64:
        if self.nodes[self.root].kind != CK_UINT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.nodes[self.root].b

    def as_f64(self) raises DecodeError -> Float64:
        var k = self.nodes[self.root].kind
        if k == CK_F64:
            return Float64(from_bits=self.nodes[self.root].b)
        if k == CK_F32:
            return Float64(Float32(from_bits=UInt32(self.nodes[self.root].b)))
        if k == CK_INT:
            return Float64(self.nodes[self.root].a)
        if k == CK_UINT:
            return Float64(self.nodes[self.root].b)
        raise DecodeError(DecodeError.KIND_TYPE, 0)

    def as_str(self) raises DecodeError -> String:
        if self.nodes[self.root].kind != CK_STR:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.texts[Int(self.nodes[self.root].a)]

    def as_bin(self) raises DecodeError -> List[Byte]:
        if self.nodes[self.root].kind != CK_BIN:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var start = Int(self.nodes[self.root].a)
        var n = Int(self.nodes[self.root].b)
        var out = List[Byte](capacity=n)
        var i = 0
        while i < n:
            out.append(self.bytes[start + i])
            i += 1
        return out^

    def as_ext(self) raises DecodeError -> MsgpackExt:
        if self.nodes[self.root].kind != CK_EXT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.exts[Int(self.nodes[self.root].a)].copy()

    def as_timestamp(self) raises DecodeError -> MsgpackTimestamp:
        if self.nodes[self.root].kind != CK_TIMESTAMP:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return MsgpackTimestamp(self.nodes[self.root].a, Int(self.nodes[self.root].b))

    def count(self) -> Int:
        var k = self.nodes[self.root].kind
        if k == CK_ARRAY:
            return Int(self.nodes[self.root].b)
        if k == CK_MAP:
            return Int(self.nodes[self.root].b)
        return 0

    def at(self, i: Int) raises DecodeError -> MsgpackValue:
        if self.nodes[self.root].kind != CK_ARRAY:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        if i < 0 or i >= Int(self.nodes[self.root].b):
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var child = self.kids[Int(self.nodes[self.root].a) + i]
        return _view(self, child)

    def pair(self, i: Int) raises DecodeError -> Tuple[MsgpackValue, MsgpackValue]:
        if self.nodes[self.root].kind != CK_MAP:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        if i < 0 or i >= Int(self.nodes[self.root].b):
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var base = Int(self.nodes[self.root].a) + i * 2
        return (_view(self, self.kids[base]), _view(self, self.kids[base + 1]))

    def get(self, key: String) raises DecodeError -> MsgpackValue:
        if self.nodes[self.root].kind != CK_MAP:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var n = Int(self.nodes[self.root].b)
        var found = -1
        var i = n - 1
        while i >= 0:
            var kid = self.kids[Int(self.nodes[self.root].a) + i * 2]
            if self.nodes[kid].kind == CK_STR:
                if self.texts[Int(self.nodes[kid].a)] == key:
                    found = self.kids[Int(self.nodes[self.root].a) + i * 2 + 1]
                    break
            i -= 1
        if found < 0:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return _view(self, found)

    def get_int(self, key: Int64) raises DecodeError -> MsgpackValue:
        if self.nodes[self.root].kind != CK_MAP:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var n = Int(self.nodes[self.root].b)
        var found = -1
        var i = n - 1
        while i >= 0:
            var kid = self.kids[Int(self.nodes[self.root].a) + i * 2]
            if self.nodes[kid].kind == CK_INT and self.nodes[kid].a == key:
                found = self.kids[Int(self.nodes[self.root].a) + i * 2 + 1]
                break
            if (
                self.nodes[kid].kind == CK_UINT
                and key >= Int64(0)
                and self.nodes[kid].b == UInt64(key)
            ):
                found = self.kids[Int(self.nodes[self.root].a) + i * 2 + 1]
                break
            i -= 1
        if found < 0:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return _view(self, found)


def _view(src: MsgpackValue, root: Int) -> MsgpackValue:
    var out = MsgpackValue()
    out.nodes = src.nodes.copy()
    out.kids = src.kids.copy()
    out.texts = src.texts.copy()
    var nb = len(src.bytes)
    out.bytes = List[Byte](capacity=nb)
    var i = 0
    while i < nb:
        out.bytes.append(src.bytes[i])
        i += 1
    var ne = len(src.exts)
    var j = 0
    while j < ne:
        out.exts.append(src.exts[j].copy())
        j += 1
    out.root = root
    return out^


def _append_bytes(mut v: MsgpackValue, src: List[Byte]) -> Int:
    var start = len(v.bytes)
    var n = len(src)
    if n == 0:
        return start
    v.bytes.resize(unsafe_uninit_length=start + n)
    unsafe_memcpy(
        dest=v.bytes.unsafe_ptr().unsafe_offset(start),
        src=src.unsafe_ptr(),
        count=n,
    )
    return start


def decode_item[
    origin: ImmOrigin
](mut r: WireReader[origin], mut v: MsgpackValue) raises DecodeError -> Int:
    r.enter()
    var at = r.position()
    var b = r.peek_byte()
    var idx: Int
    if b == 0xC1:
        raise DecodeError(DecodeError.KIND_UNUSED, at)
    if b == 0xC0:
        r.pos += 1
        idx = v.add(MsgpackNode(CK_NIL))
    elif b == 0xC2 or b == 0xC3:
        var truth = r.read_bool()
        var av = Int64(0)
        if truth:
            av = Int64(1)
        idx = v.add(MsgpackNode(CK_BOOL, a=av))
    elif r.peek_is_int():
        var t = r.try_read_int()
        if t[0]:
            idx = v.add(MsgpackNode(CK_INT, a=t[1]))
        else:
            idx = v.add(MsgpackNode(CK_UINT, b=t[2]))
    elif b == 0xCA:
        var f32 = r.read_f32()
        idx = v.add(MsgpackNode(CK_F32, b=UInt64(UInt32(f32.to_bits()))))
    elif b == 0xCB:
        var f64 = r.read_f64()
        idx = v.add(MsgpackNode(CK_F64, b=UInt64(f64.to_bits())))
    elif r.peek_is_str():
        var s = r.read_str()
        var ti = len(v.texts)
        v.texts.append(s^)
        idx = v.add(MsgpackNode(CK_STR, a=Int64(ti)))
    elif r.peek_is_bin():
        var raw = r.read_bin()
        var start = _append_bytes(v, raw)
        idx = v.add(MsgpackNode(CK_BIN, a=Int64(start), b=UInt64(len(raw))))
    elif r.peek_is_ext():
        var saved = r.pos
        var ext = r.read_ext()
        if Int(ext[0]) == -1:
            if len(ext[1]) == 4 or len(ext[1]) == 8 or len(ext[1]) == 12:
                var ts = timestamp_from_payload(ext[1], saved)
                idx = v.add(MsgpackNode(CK_TIMESTAMP, a=ts[0], b=UInt64(ts[1])))
            else:
                raise DecodeError(DecodeError.KIND_EXT, saved)
        else:
            var ei = len(v.exts)
            v.exts.append(MsgpackExt(ext[0], ext[1].copy()))
            idx = v.add(MsgpackNode(CK_EXT, a=Int64(ei)))
    elif (b >= 0x90 and b <= 0x9F) or b == 0xDC or b == 0xDD:
        var n = r.read_array_header()
        var ids = List[Int]()
        var i = 0
        while i < n:
            ids.append(decode_item(r, v))
            i += 1
        var kstart = len(v.kids)
        i = 0
        while i < len(ids):
            v.kids.append(ids[i])
            i += 1
        idx = v.add(MsgpackNode(CK_ARRAY, a=Int64(kstart), b=UInt64(n)))
    elif (b >= 0x80 and b <= 0x8F) or b == 0xDE or b == 0xDF:
        var pn = r.read_map_header()
        var ids = List[Int]()
        var j = 0
        while j < pn:
            ids.append(decode_item(r, v))
            ids.append(decode_item(r, v))
            j += 1
        var mstart = len(v.kids)
        j = 0
        while j < len(ids):
            v.kids.append(ids[j])
            j += 1
        idx = v.add(MsgpackNode(CK_MAP, a=Int64(mstart), b=UInt64(pn)))
    else:
        raise DecodeError(DecodeError.KIND_SYNTAX, at)
    r.leave()
    return idx


def decode_value[
    origin: ImmOrigin
](
    buf: Span[Byte, origin], options: DecodeOptions = DecodeOptions.default
) raises DecodeError -> MsgpackValue:
    var r = WireReader[origin](buf, options)
    var v = MsgpackValue()
    if r.remaining() == 0:
        raise DecodeError(DecodeError.KIND_EOF, 0)
    v.root = decode_item(r, v)
    if r.remaining() > 0:
        raise DecodeError(DecodeError.KIND_TRAILING, r.position())
    return v^


def encode_item(v: MsgpackValue, idx: Int, mut w: WireWriter) raises DecodeError:
    var n = v.nodes[idx]
    if n.kind == CK_NIL:
        w.write_nil()
    elif n.kind == CK_BOOL:
        w.write_bool(n.a != Int64(0))
    elif n.kind == CK_INT:
        w.write_int(n.a)
    elif n.kind == CK_UINT:
        w.write_uint(n.b)
    elif n.kind == CK_F32:
        w.write_f32_bits(UInt32(n.b))
    elif n.kind == CK_F64:
        w.write_f64_bits(n.b)
    elif n.kind == CK_STR:
        w.write_str(v.texts[Int(n.a)])
    elif n.kind == CK_BIN:
        var start = Int(n.a)
        var nb = Int(n.b)
        var tmp = List[Byte](capacity=nb)
        var i = 0
        while i < nb:
            tmp.append(v.bytes[start + i])
            i += 1
        w.write_bin(tmp)
    elif n.kind == CK_ARRAY:
        var count = Int(n.b)
        w.write_array_header(count)
        var j = 0
        while j < count:
            encode_item(v, v.kids[Int(n.a) + j], w)
            j += 1
    elif n.kind == CK_MAP:
        var pairs = Int(n.b)
        w.write_map_header(pairs)
        var k = 0
        while k < pairs:
            encode_item(v, v.kids[Int(n.a) + k * 2], w)
            encode_item(v, v.kids[Int(n.a) + k * 2 + 1], w)
            k += 1
    elif n.kind == CK_EXT:
        var e = v.exts[Int(n.a)].copy()
        w.write_ext(e.type, e.data)
    elif n.kind == CK_TIMESTAMP:
        var ts = MsgpackTimestamp(n.a, Int(n.b))
        ts.encode_to(w)
    else:
        raise DecodeError(DecodeError.KIND_TYPE, 0)


def encode_value(
    v: MsgpackValue, options: EncodeOptions = EncodeOptions.default
) raises DecodeError -> List[Byte]:
    _ = options
    var w = WireWriter(capacity=256, exact=True)
    encode_item(v, v.root, w)
    return w^.finish()


def make_nil() -> MsgpackValue:
    var v = MsgpackValue()
    v.root = v.add(MsgpackNode(CK_NIL))
    return v^


def make_bool(x: Bool) -> MsgpackValue:
    var v = MsgpackValue()
    var a = Int64(0)
    if x:
        a = Int64(1)
    v.root = v.add(MsgpackNode(CK_BOOL, a=a))
    return v^


def make_int(x: Int64) -> MsgpackValue:
    var v = MsgpackValue()
    v.root = v.add(MsgpackNode(CK_INT, a=x))
    return v^


def make_str(s: String) -> MsgpackValue:
    var v = MsgpackValue()
    var ti = len(v.texts)
    v.texts.append(s)
    v.root = v.add(MsgpackNode(CK_STR, a=Int64(ti)))
    return v^
