struct DecodeError(Copyable, ImplicitlyCopyable, Writable, Equatable):
    """Typed decode failure. Kind tags are integers (Mojo 1.0 comptime-safe)."""

    var kind: Int
    var offset: Int
    var field: Int

    comptime KIND_EOF = 1
    comptime KIND_RESERVED_AI = 2
    comptime KIND_INDEF = 3
    comptime KIND_RANGE = 4
    comptime KIND_UTF8 = 5
    comptime KIND_TYPE = 6
    comptime KIND_BREAK = 7
    comptime KIND_MAP_PAIR = 8
    comptime KIND_DEPTH = 9
    comptime KIND_TRAILING = 10
    comptime KIND_DUP_KEY = 11
    comptime KIND_CDE = 12
    comptime KIND_TAG = 13
    comptime KIND_CDDL = 14
    comptime KIND_DIAG = 15
    comptime KIND_SIMPLE = 16

    def __init__(out self, kind: Int, offset: Int, field: Int = 0):
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
