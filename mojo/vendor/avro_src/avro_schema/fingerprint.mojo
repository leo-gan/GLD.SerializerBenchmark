from std.collections import List


comptime EMPTY64 = UInt64(0xC15D213AA4D7A795)


def _table() -> List[UInt64]:
    var t = List[UInt64](capacity=256)
    var i = 0
    while i < 256:
        var fp = UInt64(i)
        var j = 0
        while j < 8:
            var mask = UInt64(0) - (fp & 1)
            fp = (fp >> 1) ^ (EMPTY64 & mask)
            j += 1
        t.append(fp)
        i += 1
    return t^


def crc64_avro(data: String) -> UInt64:
    """CRC-64-AVRO / Rabin fingerprint of UTF-8 bytes."""
    var table = _table()
    var result = EMPTY64
    var b = data.as_bytes()
    var i = 0
    while i < len(b):
        var idx = Int((result ^ UInt64(b[i])) & 0xFF)
        result = (result >> 8) ^ table[idx]
        i += 1
    return result
