struct DecodeError(Copyable, ImplicitlyCopyable, Writable, Equatable):
    """A Smile decode failure. `kind` is the reason and `offset` is the byte index."""

    var kind: Int
    var offset: Int

    comptime KIND_EOF = 1
    comptime KIND_SYNTAX = 2
    comptime KIND_RANGE = 3
    comptime KIND_UTF8 = 4
    comptime KIND_TYPE = 5
    comptime KIND_DEPTH = 6
    comptime KIND_TRAILING = 7
    comptime KIND_VERSION = 8
    comptime KIND_SHARED = 9
    comptime KIND_SCHEMA = 10

    def __init__(out self, kind: Int, offset: Int):
        self.kind = kind
        self.offset = offset

    def __eq__(self, other: Self) -> Bool:
        return self.kind == other.kind and self.offset == other.offset

    def write_to[W: Writer](self, mut writer: W):
        writer.write("DecodeError(kind=", self.kind, ", offset=", self.offset, ")")
