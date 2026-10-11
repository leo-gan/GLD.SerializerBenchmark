struct FormatError(Copyable, ImplicitlyCopyable, Writable):
    """A read or write failure. `offset` is a file position when one applies."""

    var offset: Int
    var detail: String

    def __init__(out self, offset: Int, detail: String):
        self.offset = offset
        self.detail = detail

    def write_to[W: Writer](self, mut writer: W):
        writer.write("FormatError(offset=", self.offset, ", ", self.detail, ")")


def fail(offset: Int, detail: String) raises -> None:
    raise FormatError(offset, detail)
