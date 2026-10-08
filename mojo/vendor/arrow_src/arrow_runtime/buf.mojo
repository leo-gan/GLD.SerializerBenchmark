from std.collections import List, Span

from arrow_runtime.error import DecodeError


comptime MAX_BYTES = 268435456


def buf_need(have: Int, want: Int, at: Int) raises DecodeError:
    if want < 0 or at < 0 or at > have or want > have - at:
        raise DecodeError(DecodeError.KIND_EOF, at)
    if want > MAX_BYTES:
        raise DecodeError(DecodeError.KIND_RANGE, at)


def put_u8(mut b: List[Byte], v: Int):
    b.append(Byte(v & 255))


def put_u16(mut b: List[Byte], v: Int):
    put_u8(b, v)
    put_u8(b, v >> 8)


def put_u32(mut b: List[Byte], v: Int):
    put_u8(b, v)
    put_u8(b, v >> 8)
    put_u8(b, v >> 16)
    put_u8(b, v >> 24)


def put_u64(mut b: List[Byte], v: UInt64):
    var x = v
    var i = 0
    while i < 8:
        b.append(Byte(Int(x & 0xFF)))
        x = x >> 8
        i += 1


def put_i32(mut b: List[Byte], v: Int):
    var u = v
    if u < 0:
        u = u + 4294967296
    put_u32(b, u)


def put_i64(mut b: List[Byte], v: Int):
    put_u64(b, UInt64(v))


def put_bytes[origin: ImmOrigin](mut b: List[Byte], raw: Span[Byte, origin]):
    extend_span(b, raw)


def copy_span[origin: ImmOrigin](raw: Span[Byte, origin], off: Int, n: Int) -> List[Byte]:
    var out = List[Byte]()
    if n <= 0:
        return out^
    out.resize(n, Byte(0))
    var i = 0
    while i < n:
        out[i] = raw[off + i]
        i += 1
    return out^


def extend_span[origin: ImmOrigin](mut dst: List[Byte], raw: Span[Byte, origin]):
    var base = len(dst)
    var n = len(raw)
    if n == 0:
        return
    dst.resize(base + n, Byte(0))
    var i = 0
    while i < n:
        dst[base + i] = raw[i]
        i += 1


def extend_list(mut dst: List[Byte], raw: List[Byte]):
    extend_span(dst, Span(raw))


def u8_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    buf_need(len(raw), 1, i)
    return Int(raw[i])


def u16_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    buf_need(len(raw), 2, i)
    return Int(raw[i]) | (Int(raw[i + 1]) << 8)


def u32_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    buf_need(len(raw), 4, i)
    return Int(raw[i]) | (Int(raw[i + 1]) << 8) | (Int(raw[i + 2]) << 16) | (Int(raw[i + 3]) << 24)


def u64_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> UInt64:
    buf_need(len(raw), 8, i)
    var x = UInt64(0)
    var k = 7
    while k >= 0:
        x = (x << 8) | UInt64(Int(raw[i + k]))
        k -= 1
    return x


def i32_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    var u = u32_at(raw, i)
    if u >= 2147483648:
        return u - 4294967296
    return u


def i64_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    return Int(u64_at(raw, i))


def list_u8(data: List[Byte], i: Int) raises DecodeError -> Int:
    return u8_at(Span(data), i)


def list_u16(data: List[Byte], i: Int) raises DecodeError -> Int:
    return u16_at(Span(data), i)


def list_u32(data: List[Byte], i: Int) raises DecodeError -> Int:
    return u32_at(Span(data), i)


def list_u64(data: List[Byte], i: Int) raises DecodeError -> UInt64:
    return u64_at(Span(data), i)


def list_i32(data: List[Byte], i: Int) raises DecodeError -> Int:
    return i32_at(Span(data), i)


def list_i64(data: List[Byte], i: Int) raises DecodeError -> Int:
    return i64_at(Span(data), i)


def set_u32(mut data: List[Byte], i: Int, v: Int):
    data[i] = Byte(v & 255)
    data[i + 1] = Byte((v >> 8) & 255)
    data[i + 2] = Byte((v >> 16) & 255)
    data[i + 3] = Byte((v >> 24) & 255)


def set_u16(mut data: List[Byte], i: Int, v: Int):
    data[i] = Byte(v & 255)
    data[i + 1] = Byte((v >> 8) & 255)


def set_u64(mut data: List[Byte], i: Int, v: UInt64):
    var x = v
    var k = 0
    while k < 8:
        data[i + k] = Byte(Int(x & 0xFF))
        x = x >> 8
        k += 1


def align_up(n: Int, a: Int) -> Int:
    var m = n % a
    if m == 0:
        return n
    return n + (a - m)


def copy_list[origin: ImmOrigin](raw: Span[Byte, origin]) -> List[Byte]:
    var out = List[Byte]()
    put_bytes(out, raw)
    return out^


def slice_list(data: List[Byte], off: Int, n: Int) -> List[Byte]:
    return copy_span(Span(data), off, n)


def utf8_ok[origin: ImmOrigin](raw: Span[Byte, origin]) -> Bool:
    var i = 0
    var n = len(raw)
    while i < n:
        var c = Int(raw[i])
        if c < 128:
            i += 1
        elif c >= 194 and c <= 223:
            if i + 1 >= n:
                return False
            var c1 = Int(raw[i + 1])
            if c1 < 128 or c1 > 191:
                return False
            i += 2
        elif c == 224:
            if i + 2 >= n:
                return False
            var c1 = Int(raw[i + 1])
            var c2 = Int(raw[i + 2])
            if c1 < 160 or c1 > 191 or c2 < 128 or c2 > 191:
                return False
            i += 3
        elif (c >= 225 and c <= 236) or c == 238 or c == 239:
            if i + 2 >= n:
                return False
            var c1 = Int(raw[i + 1])
            var c2 = Int(raw[i + 2])
            if c1 < 128 or c1 > 191 or c2 < 128 or c2 > 191:
                return False
            i += 3
        elif c == 237:
            if i + 2 >= n:
                return False
            var c1 = Int(raw[i + 1])
            var c2 = Int(raw[i + 2])
            if c1 < 128 or c1 > 159 or c2 < 128 or c2 > 191:
                return False
            i += 3
        elif c == 240:
            if i + 3 >= n:
                return False
            var c1 = Int(raw[i + 1])
            var c2 = Int(raw[i + 2])
            var c3 = Int(raw[i + 3])
            if c1 < 144 or c1 > 191 or c2 < 128 or c2 > 191 or c3 < 128 or c3 > 191:
                return False
            i += 4
        elif c >= 241 and c <= 243:
            if i + 3 >= n:
                return False
            var c1 = Int(raw[i + 1])
            var c2 = Int(raw[i + 2])
            var c3 = Int(raw[i + 3])
            if c1 < 128 or c1 > 191 or c2 < 128 or c2 > 191 or c3 < 128 or c3 > 191:
                return False
            i += 4
        elif c == 244:
            if i + 3 >= n:
                return False
            var c1 = Int(raw[i + 1])
            var c2 = Int(raw[i + 2])
            var c3 = Int(raw[i + 3])
            if c1 < 128 or c1 > 143 or c2 < 128 or c2 > 191 or c3 < 128 or c3 > 191:
                return False
            i += 4
        else:
            return False
    return True


def string_from[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> String:
    if not utf8_ok(raw):
        raise DecodeError(DecodeError.KIND_UTF8, 0)
    return String(unsafe_from_utf8=raw)
