struct DecodeError(Copyable, ImplicitlyCopyable, Writable, Equatable):
    """Typed decode failure. Kind tags are integers so they stay comptime-safe on Mojo 1.0."""

    var kind: Int
    var offset: Int
    var detail: Int

    comptime KIND_EOF = 1
    comptime KIND_SYNTAX = 2
    comptime KIND_RANGE = 3
    comptime KIND_UTF8 = 4
    comptime KIND_TYPE = 5
    comptime KIND_DEPTH = 6
    comptime KIND_TRAILING = 7
    comptime KIND_SIZE = 8
    comptime KIND_NUMBER = 9
    comptime KIND_SCHEMA = 10

    def __init__(out self, kind: Int, offset: Int, detail: Int = 0):
        self.kind = kind
        self.offset = offset
        self.detail = detail

    def __eq__(self, other: Self) -> Bool:
        return self.kind == other.kind and self.offset == other.offset and self.detail == other.detail

    def write_to[W: Writer](self, mut writer: W):
        writer.write("DecodeError(kind=", self.kind, ", offset=", self.offset, ", detail=", self.detail, ")")
