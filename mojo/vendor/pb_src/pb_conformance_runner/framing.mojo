from std.collections import List, Optional
from std.io import FileDescriptor


def u32_to_le(n: UInt32) -> List[Byte]:
    var out = List[Byte](capacity=4)
    out.append(Byte(n & 0xFF))
    out.append(Byte((n >> 8) & 0xFF))
    out.append(Byte((n >> 16) & 0xFF))
    out.append(Byte((n >> 24) & 0xFF))
    return out^


def u32_from_le(buf: List[Byte]) -> UInt32:
    var n: UInt32 = 0
    n |= UInt32(buf[0])
    n |= UInt32(buf[1]) << 8
    n |= UInt32(buf[2]) << 16
    n |= UInt32(buf[3]) << 24
    return n


def _read_exact(mut fd: FileDescriptor, n: Int) raises -> Optional[List[Byte]]:
    var out = List[Byte](capacity=n)
    var got = 0
    while got < n:
        var chunk = List[Byte](length=n - got, fill=0)
        var k = fd.read_bytes(chunk)
        if k == 0:
            if got == 0:
                return None
            raise Error("truncated conformance frame")
        for i in range(k):
            out.append(chunk[i])
        got += k
    return out^


def read_frame(mut fd: FileDescriptor) raises -> Optional[List[Byte]]:
    var header = _read_exact(fd, 4)
    if not header:
        return None
    var n = Int(u32_from_le(header.value()))
    if n < 0:
        raise Error("negative conformance frame length")
    return _read_exact(fd, n)


def write_frame(mut fd: FileDescriptor, payload: List[Byte]) raises:
    var header = u32_to_le(UInt32(len(payload)))
    fd.write_bytes(header)
    if len(payload) != 0:
        fd.write_bytes(payload)
