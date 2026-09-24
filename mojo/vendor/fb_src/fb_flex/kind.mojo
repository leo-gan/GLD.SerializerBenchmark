comptime F_NULL: Int = 0
comptime F_INT: Int = 1
comptime F_UINT: Int = 2
comptime F_FLOAT: Int = 3
comptime F_KEY: Int = 4
comptime F_STRING: Int = 5
comptime F_INDIRECT_INT: Int = 6
comptime F_INDIRECT_UINT: Int = 7
comptime F_INDIRECT_FLOAT: Int = 8
comptime F_MAP: Int = 9
comptime F_VECTOR: Int = 10
comptime F_VECTOR_INT: Int = 11
comptime F_VECTOR_UINT: Int = 12
comptime F_VECTOR_FLOAT: Int = 13
comptime F_VECTOR_KEY: Int = 14
comptime F_VECTOR_STRING_DEPRECATED: Int = 15
comptime F_VECTOR_INT2: Int = 16
comptime F_VECTOR_UINT2: Int = 17
comptime F_VECTOR_FLOAT2: Int = 18
comptime F_VECTOR_INT3: Int = 19
comptime F_VECTOR_UINT3: Int = 20
comptime F_VECTOR_FLOAT3: Int = 21
comptime F_VECTOR_INT4: Int = 22
comptime F_VECTOR_UINT4: Int = 23
comptime F_VECTOR_FLOAT4: Int = 24
comptime F_BLOB: Int = 25
comptime F_BOOL: Int = 26
comptime F_VECTOR_BOOL: Int = 36


def flex_inline(kind: Int) -> Bool:
    return kind <= F_FLOAT or kind == F_BOOL


def flex_pack(kind: Int, bit_width: Int) -> Int:
    return (kind << 2) | bit_width


def flex_byte_width(bit_width: Int) -> Int:
    return 1 << bit_width


def bit_width_u(value: UInt64) -> Int:
    if value < 0x100:
        return 0
    if value < 0x10000:
        return 1
    if value < 0x100000000:
        return 2
    return 3


def bit_width_i(value: Int64) -> Int:
    if value >= -128 and value <= 127:
        return 0
    if value >= -32768 and value <= 32767:
        return 1
    if value >= -2147483648 and value <= 2147483647:
        return 2
    return 3


def bit_width_f(value: Float64) -> Int:
    var narrow = Float32(value)
    if Float64(narrow) == value:
        return 2
    return 3


def padding_bytes(buf_size: Int, scalar_size: Int) -> Int:
    return (-buf_size) & (scalar_size - 1)
