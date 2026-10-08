from std.collections import List, Span


def xxh32[origin: ImmOrigin](raw: Span[Byte, origin]) -> UInt32:
    var p1 = UInt32(0x9E3779B1)
    var p2 = UInt32(0x85EBCA77)
    var p3 = UInt32(0xC2B2AE3D)
    var p4 = UInt32(0x27D4EB2F)
    var p5 = UInt32(0x165667B1)
    var n = len(raw)
    var i = 0
    var h = p5
    if n >= 16:
        var v1 = p1 + p2
        var v2 = p2
        var v3 = UInt32(0)
        var v4 = UInt32(0) - p1
        while i + 16 <= n:
            v1 = _round32(v1, _load32(raw, i), p1, p2)
            v2 = _round32(v2, _load32(raw, i + 4), p1, p2)
            v3 = _round32(v3, _load32(raw, i + 8), p1, p2)
            v4 = _round32(v4, _load32(raw, i + 12), p1, p2)
            i += 16
        h = _rotl32(v1, 1) + _rotl32(v2, 7) + _rotl32(v3, 12) + _rotl32(v4, 18)
    h = h + UInt32(n)
    while i + 4 <= n:
        h = h + _load32(raw, i) * p3
        h = _rotl32(h, 17) * p4
        i += 4
    while i < n:
        h = h + UInt32(Int(raw[i])) * p5
        h = _rotl32(h, 11) * p1
        i += 1
    h = h ^ (h >> 15)
    h = h * p2
    h = h ^ (h >> 13)
    h = h * p3
    h = h ^ (h >> 16)
    return h


def xxh64[origin: ImmOrigin](raw: Span[Byte, origin]) -> UInt64:
    var p1 = UInt64(0x9E3779B185EBCA87)
    var p2 = UInt64(0xC2B2AE3D27D4EB4F)
    var p3 = UInt64(0x165667B19E3779F9)
    var p4 = UInt64(0x85EBCA77C2B2AE63)
    var p5 = UInt64(0x27D4EB2F165667C5)
    var n = len(raw)
    var i = 0
    var h = p5
    if n >= 32:
        var v1 = p1 + p2
        var v2 = p2
        var v3 = UInt64(0)
        var v4 = UInt64(0) - p1
        while i + 32 <= n:
            v1 = _round64(v1, _load64(raw, i), p1, p2)
            v2 = _round64(v2, _load64(raw, i + 8), p1, p2)
            v3 = _round64(v3, _load64(raw, i + 16), p1, p2)
            v4 = _round64(v4, _load64(raw, i + 24), p1, p2)
            i += 32
        h = _rotl64(v1, 1) + _rotl64(v2, 7) + _rotl64(v3, 12) + _rotl64(v4, 18)
        h = _merge64(h, v1, p1, p2, p4)
        h = _merge64(h, v2, p1, p2, p4)
        h = _merge64(h, v3, p1, p2, p4)
        h = _merge64(h, v4, p1, p2, p4)
    h = h + UInt64(n)
    while i + 8 <= n:
        var k1 = _round64(UInt64(0), _load64(raw, i), p1, p2)
        h = h ^ k1
        h = _rotl64(h, 27) * p1 + p4
        i += 8
    if i + 4 <= n:
        h = h ^ (UInt64(_load32(raw, i)) * p1)
        h = _rotl64(h, 23) * p2 + p3
        i += 4
    while i < n:
        h = h ^ (UInt64(Int(raw[i])) * p5)
        h = _rotl64(h, 11) * p1
        i += 1
    h = h ^ (h >> 33)
    h = h * p2
    h = h ^ (h >> 29)
    h = h * p3
    h = h ^ (h >> 32)
    return h


def xxh32_list(raw: List[Byte]) -> UInt32:
    return xxh32(Span(raw))


def xxh64_list(raw: List[Byte]) -> UInt64:
    return xxh64(Span(raw))


def _round32(acc: UInt32, lane: UInt32, p1: UInt32, p2: UInt32) -> UInt32:
    var x = acc + lane * p2
    x = _rotl32(x, 13)
    return x * p1


def _rotl32(x: UInt32, r: Int) -> UInt32:
    var n = UInt32(r)
    return (x << n) | (x >> (UInt32(32) - n))


def _load32[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) -> UInt32:
    return (
        UInt32(Int(raw[i]))
        | (UInt32(Int(raw[i + 1])) << 8)
        | (UInt32(Int(raw[i + 2])) << 16)
        | (UInt32(Int(raw[i + 3])) << 24)
    )


def _round64(acc: UInt64, lane: UInt64, p1: UInt64, p2: UInt64) -> UInt64:
    var x = acc + lane * p2
    x = _rotl64(x, 31)
    return x * p1


def _merge64(acc: UInt64, val: UInt64, p1: UInt64, p2: UInt64, p4: UInt64) -> UInt64:
    var mixed = acc ^ _round64(UInt64(0), val, p1, p2)
    return mixed * p1 + p4


def _rotl64(x: UInt64, r: Int) -> UInt64:
    var n = UInt64(r)
    return (x << n) | (x >> (UInt64(64) - n))


def _load64[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) -> UInt64:
    var x = UInt64(0)
    var k = 7
    while k >= 0:
        x = (x << 8) | UInt64(Int(raw[i + k]))
        k -= 1
    return x
