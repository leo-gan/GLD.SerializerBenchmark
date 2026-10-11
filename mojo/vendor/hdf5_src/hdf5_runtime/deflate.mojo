from std.collections import List, Span

from hdf5_runtime.error import FormatError


comptime ADLER_MOD = 65521


def adler32[origin: ImmOrigin](data: Span[Byte, origin]) -> Int:
    """Adler-32 checksum used by the zlib wrapper around deflate."""
    var a = 1
    var b = 0
    var i = 0
    var n = len(data)
    while i < n:
        a = a + Int(data[i])
        b = b + a
        if a >= ADLER_MOD:
            a = a - ADLER_MOD
        if b >= ADLER_MOD:
            b = b - ADLER_MOD
        # `b` can exceed the modulus twice when `a` is large.
        if b >= ADLER_MOD:
            b = b - ADLER_MOD
        i += 1
    return (b << 16) | a


def zlib_store[origin: ImmOrigin](data: Span[Byte, origin]) -> List[Byte]:
    """Zlib stream (RFC 1950) of deflate stored blocks (BTYPE 00).

    Stored blocks are valid deflate. HDF5 filter id 1 accepts them.
    """
    var out = List[Byte]()
    out.append(Byte(0x78))
    out.append(Byte(0x01))
    var i = 0
    var n = len(data)
    while True:
        var take = n - i
        if take > 65535:
            take = 65535
        var last = i + take >= n
        if last:
            out.append(Byte(1))
        else:
            out.append(Byte(0))
        out.append(Byte(take & 255))
        out.append(Byte((take >> 8) & 255))
        var nlen = (~take) & 0xFFFF
        out.append(Byte(nlen & 255))
        out.append(Byte((nlen >> 8) & 255))
        var k = 0
        while k < take:
            out.append(data[i + k])
            k += 1
        i += take
        if last:
            break
    var sum = adler32(data)
    out.append(Byte((sum >> 24) & 255))
    out.append(Byte((sum >> 16) & 255))
    out.append(Byte((sum >> 8) & 255))
    out.append(Byte(sum & 255))
    return out^


def zlib_inflate[origin: ImmOrigin](data: Span[Byte, origin]) raises -> List[Byte]:
    """Inflate a zlib stream of stored deflate blocks."""
    if len(data) < 6:
        raise FormatError(0, String("deflate: truncated zlib header"))
    var cmf = Int(data[0])
    var flg = Int(data[1])
    if (cmf & 0x0F) != 8:
        raise FormatError(0, String("deflate: compression method is not deflate"))
    if ((cmf << 8) + flg) % 31 != 0:
        raise FormatError(0, String("deflate: zlib flag check failed"))
    var pos = 2
    var out = List[Byte]()
    while True:
        if pos >= len(data):
            raise FormatError(pos, String("deflate: truncated block"))
        var hdr = Int(data[pos])
        pos += 1
        var bfinal = hdr & 1
        var btype = (hdr >> 1) & 3
        if btype != 0:
            raise FormatError(pos, String("deflate: only stored blocks are implemented"))
        if pos + 4 > len(data):
            raise FormatError(pos, String("deflate: truncated stored header"))
        var ln = Int(data[pos]) | (Int(data[pos + 1]) << 8)
        var nlen = Int(data[pos + 2]) | (Int(data[pos + 3]) << 8)
        pos += 4
        if nlen != ((~ln) & 0xFFFF):
            raise FormatError(pos, String("deflate: stored length complement mismatch"))
        if pos + ln > len(data):
            raise FormatError(pos, String("deflate: stored block overruns the stream"))
        var k = 0
        while k < ln:
            out.append(data[pos + k])
            k += 1
        pos += ln
        if bfinal != 0:
            break
    if pos + 4 > len(data):
        raise FormatError(pos, String("deflate: missing adler32"))
    var expect = (Int(data[pos]) << 24) | (Int(data[pos + 1]) << 16) | (Int(data[pos + 2]) << 8) | Int(data[pos + 3])
    var got = adler32(Span(out))
    if got != expect:
        raise FormatError(pos, String("deflate: adler32 mismatch"))
    return out^
