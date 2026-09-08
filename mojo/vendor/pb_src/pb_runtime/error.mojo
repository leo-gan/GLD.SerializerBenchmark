struct DecodeError(Copyable, ImplicitlyCopyable, Writable, Equatable):
    """Typed decode failure. Kind tags are integers (Mojo 1.0 comptime-safe)."""

    var kind: Int
    var offset: Int
    var field: UInt32

    comptime KIND_TRUNCATED = 1
    comptime KIND_OVERFLOW = 2
    comptime KIND_INVALID_WIRE = 3
    comptime KIND_BAD_UTF8 = 4
    comptime KIND_OVERSIZE = 5
    comptime KIND_BAD_FIELD = 6
    comptime KIND_DEPTH = 7
    comptime KIND_BAD_PACKED = 8

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
