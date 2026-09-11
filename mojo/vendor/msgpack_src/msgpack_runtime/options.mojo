comptime MAX_ITEM_BYTES = 64_194_304
comptime MAX_COUNT = 1_048_576
comptime MAX_DEPTH = 100


struct EncodeOptions(Copyable, ImplicitlyCopyable):
    var _reserved: Int

    comptime default = EncodeOptions(_reserved=0)

    def __init__(out self, _reserved: Int = 0):
        self._reserved = _reserved


struct DecodeOptions(Copyable, ImplicitlyCopyable):
    var max_depth: Int
    var strict_keys: Bool

    comptime default = DecodeOptions(max_depth=MAX_DEPTH, strict_keys=False)
    comptime strict = DecodeOptions(max_depth=MAX_DEPTH, strict_keys=True)

    def __init__(out self, max_depth: Int = MAX_DEPTH, strict_keys: Bool = False):
        self.max_depth = max_depth
        self.strict_keys = strict_keys
