from std.collections import List, Span
from std.memory import unsafe_memcpy

from kiln.error import KilnError
from kiln.wire import Writer


comptime TENSOR_HEADER = 64
comptime DTYPE_F64 = 1


def write_f64(data: List[Float64], mut w: Writer) raises KilnError:
    """Write one little-endian f64 tensor.

    The header is 64 bytes so the payload starts on a cache-line boundary
    when the writer itself starts aligned. The payload is a raw copy of
    the list on a little-endian host.
    """
    w.length = 0
    var n = len(data)
    var nbytes = n * 8
    w.ensure(TENSOR_HEADER + nbytes)
    w.put_u8(UInt8(0x4B))
    w.put_u8(UInt8(0x4C))
    w.put_u8(UInt8(0x4E))
    w.put_u8(UInt8(0x54))
    w.put_u8(UInt8(1))
    w.put_u8(UInt8(DTYPE_F64))
    w.put_u16(UInt16(0))
    w.put_u64(UInt64(n))
    var pad = TENSOR_HEADER - w.length
    var i = 0
    while i < pad:
        w.put_u8(UInt8(0))
        i += 1
    if nbytes > 0:
        var at = w.reserve(nbytes)
        unsafe_memcpy(
            dest=w.buf.unsafe_ptr().unsafe_offset(at),
            src=data.unsafe_ptr().unsafe_bitcast[UInt8](),
            count=nbytes,
        )


def read_f64[origin: ImmOrigin](data: Span[UInt8, origin]) raises KilnError -> List[Float64]:
    if len(data) < TENSOR_HEADER:
        raise KilnError(KilnError.FRAME, 0)
    if data[0] != UInt8(0x4B) or data[1] != UInt8(0x4C) or data[2] != UInt8(0x4E) or data[3] != UInt8(0x54):
        raise KilnError(KilnError.FRAME, 0)
    if data[5] != UInt8(DTYPE_F64):
        raise KilnError(KilnError.TYPE, 5)
    var count = UInt64(data[8])
    count = count | (UInt64(data[9]) << 8)
    count = count | (UInt64(data[10]) << 16)
    count = count | (UInt64(data[11]) << 24)
    count = count | (UInt64(data[12]) << 32)
    count = count | (UInt64(data[13]) << 40)
    count = count | (UInt64(data[14]) << 48)
    count = count | (UInt64(data[15]) << 56)
    var elems = Int(count)
    var nbytes = elems * 8
    if TENSOR_HEADER + nbytes > len(data):
        raise KilnError(KilnError.EOF, TENSOR_HEADER)
    var out = List[Float64](unsafe_uninit_length=elems)
    if nbytes > 0:
        unsafe_memcpy(
            dest=out.unsafe_ptr().unsafe_bitcast[UInt8](),
            src=data.unsafe_ptr().unsafe_offset(TENSOR_HEADER),
            count=nbytes,
        )
    return out^
