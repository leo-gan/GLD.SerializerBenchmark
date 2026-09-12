struct DecodeError(Copyable, ImplicitlyCopyable, Writable, Equatable):
    """Typed decode failure. Kind tags are integers (Mojo 1.0 comptime-safe)."""

    var kind: Int
    var offset: Int
    var field: Int

    comptime KIND_EOF = 1
    comptime KIND_SYNTAX = 2
    comptime KIND_NUMBER = 3
    comptime KIND_RANGE = 4
    comptime KIND_UTF8 = 5
    comptime KIND_ESCAPE = 6
    comptime KIND_TYPE = 7
    comptime KIND_DEPTH = 8
    comptime KIND_TRAILING = 9
    comptime KIND_DUP_KEY = 10
    comptime KIND_SCHEMA = 11
    comptime KIND_INDENT = 12
    comptime KIND_ALIAS = 13
    comptime KIND_TAG = 14
    comptime KIND_BINARY = 15

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
