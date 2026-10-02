struct EncodeOptions(Copyable, ImplicitlyCopyable):
    """Layout switches on top of the stable table encoding.

    `inline_tables` writes tables as `{ ... }` instead of `[header]` blocks.
    `compact_arrays` writes an array of tables as a one-line array of inline tables.
    Scalar arrays are one line either way.
    """

    var inline_tables: Bool
    var compact_arrays: Bool

    comptime standard = EncodeOptions(False, False)
    comptime inline = EncodeOptions(True, False)
    comptime compact = EncodeOptions(False, True)

    def __init__(out self, inline_tables: Bool = False, compact_arrays: Bool = False):
        self.inline_tables = inline_tables
        self.compact_arrays = compact_arrays


struct DecodeOptions(Copyable, ImplicitlyCopyable):
    var max_depth: Int

    comptime default = DecodeOptions(128)

    def __init__(out self, max_depth: Int = 128):
        self.max_depth = max_depth
