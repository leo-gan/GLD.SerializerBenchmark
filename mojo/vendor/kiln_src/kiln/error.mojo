struct KilnError(Copyable, ImplicitlyCopyable, Writable, Equatable):
    """A Kiln encode or decode failure.

    `kind` is the reason. `offset` is the byte index in the buffer
    where the failure was noticed. Encode failures use the number of
    bytes written so far as the offset.
    """

    var kind: Int
    var offset: Int

    comptime EOF = 1
    comptime RANGE = 2
    comptime UTF8 = 3
    comptime TYPE = 4
    comptime DEPTH = 5
    comptime LIMIT = 6
    comptime SCHEMA = 7
    comptime TRAILING = 8
    comptime FRAME = 9

    def __init__(out self, kind: Int, offset: Int):
        self.kind = kind
        self.offset = offset

    def __eq__(self, other: Self) -> Bool:
        return self.kind == other.kind and self.offset == other.offset

    def write_to[W: Writer](self, mut writer: W):
        writer.write("KilnError(kind=", self.kind, ", offset=", self.offset, ")")
