from std.collections import List


def deflate_raw(data: List[Byte]) -> List[Byte]:
    """Raw DEFLATE stored blocks (legal RFC 1951). Official readers accept this."""
    var out = List[Byte]()
    var i = 0
    var n = len(data)
    if n == 0:
        # empty stored final block
        out.append(Byte(1))
        out.append(Byte(0))
        out.append(Byte(0))
        out.append(Byte(0xFF))
        out.append(Byte(0xFF))
        return out^
    while i < n:
        var remain = n - i
        var chunk = remain
        if chunk > 65535:
            chunk = 65535
        var last = 0
        if i + chunk >= n:
            last = 1
        out.append(Byte(last))  # BFINAL, BTYPE=00
        out.append(Byte(chunk & 0xFF))
        out.append(Byte((chunk >> 8) & 0xFF))
        var nlen = chunk ^ 0xFFFF
        out.append(Byte(nlen & 0xFF))
        out.append(Byte((nlen >> 8) & 0xFF))
        var j = 0
        while j < chunk:
            out.append(data[i + j])
            j += 1
        i += chunk
    return out^
