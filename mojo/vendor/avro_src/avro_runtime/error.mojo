struct DecodeError(Copyable, ImplicitlyCopyable, Writable, Equatable):
    """Typed decode failure. Kind tags are integers (Mojo 1.0 comptime-safe)."""

    var kind: Int
    var offset: Int
    var field: UInt32

    comptime KIND_EOF = 1
    comptime KIND_BAD_VARINT = 2
    comptime KIND_RANGE = 3
    comptime KIND_BAD_BOOL = 4
    comptime KIND_BAD_UTF8 = 5
    comptime KIND_BAD_ENUM = 6
    comptime KIND_BAD_UNION = 7
    comptime KIND_BAD_BLOCK = 8
    comptime KIND_SCHEMA = 9
    comptime KIND_RESOLVE = 10
    comptime KIND_OCF = 11
    comptime KIND_DEFLATE = 12
    comptime KIND_JSON = 13
    comptime KIND_SOE = 14
    comptime KIND_BAD_JSON_NUMBER = 15
    comptime KIND_OVERFLOW = 2
    comptime KIND_TRUNCATED = 1

    def __init__(out self, kind: Int, offset: Int, field: UInt32 = 0):
        self.kind = kind
        self.offset = offset
        self.field = field

    def __eq__(self, other: Self) -> Bool:
        return (
            self.kind == other.kind
            and self.offset == other.offset
            and self.field == other.field
        )

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "DecodeError(kind=",
            self.kind,
            ", offset=",
            self.offset,
            ", field=",
            self.field,
            ")",
        )
