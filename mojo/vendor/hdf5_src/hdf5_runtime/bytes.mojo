from std.collections import List, Span
from std.memory import bitcast

from hdf5_runtime.error import fail


struct Buf:
    """Little-endian byte sink used by the writers."""

    var b: List[Byte]

    def __init__(out self, cap: Int = 0):
        if cap > 0:
            self.b = List[Byte](capacity=cap)
        else:
            self.b = List[Byte]()

    def n(self) -> Int:
        return len(self.b)

    def u8(mut self, v: Int):
        self.b.append(Byte(v & 255))

    def u16(mut self, v: Int):
        self.b.append(Byte(v & 255))
        self.b.append(Byte((v >> 8) & 255))

    def u32(mut self, v: Int):
        var x = v
        var i = 0
        while i < 4:
            self.b.append(Byte(x & 255))
            x = x >> 8
            i += 1

    def u64(mut self, v: Int):
        var x = v
        var i = 0
        while i < 8:
            self.b.append(Byte(x & 255))
            x = x >> 8
            i += 1

    def be16(mut self, v: Int):
        self.b.append(Byte((v >> 8) & 255))
        self.b.append(Byte(v & 255))

    def be32(mut self, v: Int):
        var x = v & 0xFFFFFFFF
        self.b.append(Byte((x >> 24) & 255))
        self.b.append(Byte((x >> 16) & 255))
        self.b.append(Byte((x >> 8) & 255))
        self.b.append(Byte(x & 255))

    def be64(mut self, v: Int):
        var x = v
        var i = 7
        while i >= 0:
            self.b.append(Byte((x >> (i * 8)) & 255))
            i -= 1

    def zeros(mut self, n: Int):
        var i = 0
        while i < n:
            self.b.append(Byte(0))
            i += 1

    def ascii(mut self, text: String):
        var raw = text.as_bytes()
        var i = 0
        while i < len(raw):
            self.b.append(raw[i])
            i += 1

    def blob(mut self, src: List[Byte]):
        var i = 0
        while i < len(src):
            self.b.append(src[i])
            i += 1

    def pad8(mut self):
        while len(self.b) % 8 != 0:
            self.b.append(Byte(0))

    def pad4(mut self):
        while len(self.b) % 4 != 0:
            self.b.append(Byte(0))

    def take(mut self) -> List[Byte]:
        var out = List[Byte]()
        var i = 0
        while i < len(self.b):
            out.append(self.b[i])
            i += 1
        return out^


def u16le[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises -> Int:
    if i < 0 or i + 2 > len(raw):
        fail(i, String("truncated u16"))
    return Int(raw[i]) | (Int(raw[i + 1]) << 8)


def u32le[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises -> Int:
    if i < 0 or i + 4 > len(raw):
        fail(i, String("truncated u32"))
    var v = 0
    var s = 0
    while s < 4:
        v = v | (Int(raw[i + s]) << (s * 8))
        s += 1
    return v


def u64le[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises -> Int:
    if i < 0 or i + 8 > len(raw):
        fail(i, String("truncated u64"))
    var v = 0
    var s = 0
    while s < 8:
        v = v | (Int(raw[i + s]) << (s * 8))
        s += 1
    return v


def u16be[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises -> Int:
    if i < 0 or i + 2 > len(raw):
        fail(i, String("truncated u16be"))
    return (Int(raw[i]) << 8) | Int(raw[i + 1])


def u32be[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises -> Int:
    if i < 0 or i + 4 > len(raw):
        fail(i, String("truncated u32be"))
    var v = 0
    var s = 0
    while s < 4:
        v = (v << 8) | Int(raw[i + s])
        s += 1
    return v


def u64be[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises -> Int:
    if i < 0 or i + 8 > len(raw):
        fail(i, String("truncated u64be"))
    var v = 0
    var s = 0
    while s < 8:
        v = (v << 8) | Int(raw[i + s])
        s += 1
    return v


def pack_u64(v: Int) -> List[Byte]:
    var b = Buf()
    b.u64(v)
    return b.take()


def append_f64(mut raw: List[Byte], v: Float64):
    var bits = Int(bitcast[DType.uint64](v))
    var x = bits
    var i = 0
    while i < 8:
        raw.append(Byte(x & 255))
        x = x >> 8
        i += 1


def append_f32(mut raw: List[Byte], v: Float32):
    var bits = Int(bitcast[DType.uint32](v))
    var x = bits
    var i = 0
    while i < 4:
        raw.append(Byte(x & 255))
        x = x >> 8
        i += 1


def load_f64[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises -> Float64:
    if i < 0 or i + 8 > len(raw):
        fail(i, String("truncated f64"))
    var u = UInt64(0)
    var s = 0
    while s < 8:
        u = (u << 8) | UInt64(Int(raw[i + 7 - s]))
        s += 1
    return bitcast[DType.float64](u)


def load_f32_bits(bits: Int) -> Float32:
    return bitcast[DType.float32](UInt32(bits))


def bytes_eq(a: List[Byte], b: List[Byte]) -> Bool:
    if len(a) != len(b):
        return False
    var i = 0
    while i < len(a):
        if Int(a[i]) != Int(b[i]):
            return False
        i += 1
    return True


def blank(n: Int) -> List[Byte]:
    """A zero-filled buffer. The length is reserved up front."""
    if n <= 0:
        return List[Byte]()
    var out = List[Byte](unsafe_uninit_length=n)
    var zero = SIMD[DType.uint8, 16](0)
    var i = 0
    var n16 = n & ~15
    while i < n16:
        out.unsafe_ptr().unsafe_store(i, zero)
        i += 16
    while i < n:
        out[i] = Byte(0)
        i += 1
    return out^


def copy_span[origin: ImmOrigin](raw: Span[Byte, origin], at: Int, n: Int) -> List[Byte]:
    if n <= 0:
        return List[Byte]()
    var out = List[Byte](unsafe_uninit_length=n)
    var i = 0
    var n16 = n & ~15
    while i < n16:
        var v = raw.unsafe_ptr().unsafe_load[width=16](at + i)
        out.unsafe_ptr().unsafe_store(i, v)
        i += 16
    while i < n:
        out[i] = raw[at + i]
        i += 1
    return out^


def copy_bytes(src: List[Byte]) -> List[Byte]:
    return copy_span(Span(src), 0, len(src))


def pad_to(var content: List[Byte], target: Int) -> List[Byte]:
    if len(content) >= target:
        return content^
    var out = blank(target)
    blit(out, 0, content)
    return out^


def string_from_bytes(src: List[Byte], n: Int) -> String:
    var cut = n
    if cut > len(src):
        cut = len(src)
    var tmp = List[Byte]()
    var i = 0
    while i < cut:
        tmp.append(src[i])
        i += 1
    return String(unsafe_from_utf8=Span(tmp))


def blit(mut dst: List[Byte], at: Int, src: List[Byte]):
    var n = len(src)
    var i = 0
    var n16 = n & ~15
    while i < n16:
        var v = src.unsafe_ptr().unsafe_load[width=16](i)
        dst.unsafe_ptr().unsafe_store(at + i, v)
        i += 16
    while i < n:
        dst[at + i] = src[i]
        i += 1
