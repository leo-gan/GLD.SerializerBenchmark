struct EncodeOptions(Copyable, ImplicitlyCopyable):
    var style: Int
    var indent: Int
    var keep_anchors: Bool

    comptime DEFAULT = 0
    comptime BLOCK = 1
    comptime FLOW = 2

    comptime default = EncodeOptions(1, 2, False)
    comptime block = EncodeOptions(1, 2, False)
    comptime flow = EncodeOptions(2, 2, False)

    def __init__(out self, style: Int = 1, indent: Int = 2, keep_anchors: Bool = False):
        self.style = style
        self.indent = indent
        self.keep_anchors = keep_anchors

    def is_flow(self) -> Bool:
        return self.style == Self.FLOW


struct DecodeOptions(Copyable, ImplicitlyCopyable):
    var max_depth: Int
    var strict_keys: Bool
    var keep_anchors: Bool

    comptime default = DecodeOptions(100, False, False)

    def __init__(
        out self,
        max_depth: Int = 100,
        strict_keys: Bool = False,
        keep_anchors: Bool = False,
    ):
        self.max_depth = max_depth
        self.strict_keys = strict_keys
        self.keep_anchors = keep_anchors
