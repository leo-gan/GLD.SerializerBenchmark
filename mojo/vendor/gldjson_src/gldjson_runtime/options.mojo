struct EncodeOptions(Copyable, ImplicitlyCopyable):
    var mode: Int
    var indent: Int

    comptime COMPACT = 0
    comptime PRETTY = 1

    comptime compact = EncodeOptions(mode=Self.COMPACT, indent=0)
    comptime pretty = EncodeOptions(mode=Self.PRETTY, indent=2)

    def __init__(out self, mode: Int = 0, indent: Int = 0):
        self.mode = mode
        self.indent = indent

    def is_pretty(self) -> Bool:
        return self.mode == Self.PRETTY


struct DecodeOptions(Copyable, ImplicitlyCopyable):
    var strict_keys: Bool
    var max_depth: Int

    comptime default = DecodeOptions(strict_keys=False, max_depth=100)
    comptime strict = DecodeOptions(strict_keys=True, max_depth=100)

    def __init__(out self, strict_keys: Bool = False, max_depth: Int = 100):
        self.strict_keys = strict_keys
        self.max_depth = max_depth
