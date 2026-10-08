struct DecodeError(Copyable, ImplicitlyCopyable, Writable, Equatable):
    """A decode or encode failure. `field` is 0 when the failure is not tied to one field."""

    var kind: Int
    var offset: Int
    var field: Int

    comptime KIND_EOF = 1
    comptime KIND_SYNTAX = 2
    comptime KIND_RANGE = 3
    comptime KIND_UTF8 = 4
    comptime KIND_TYPE = 5
    comptime KIND_DEPTH = 6
    comptime KIND_SCHEMA = 7
    comptime KIND_VERSION = 8
    comptime KIND_COMPRESSION = 9
    comptime KIND_ENCODING = 10

    def __init__(out self, kind: Int, offset: Int, field: Int = 0):
        self.kind = kind
        self.offset = offset
        self.field = field

    def __eq__(self, other: Self) -> Bool:
        return self.kind == other.kind and self.offset == other.offset and self.field == other.field

    def write_to[W: Writer](self, mut writer: W):
        writer.write("DecodeError(kind=", self.kind, ", offset=", self.offset, ", field=", self.field, ")")
