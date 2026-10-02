struct EncodeOptions(Copyable, ImplicitlyCopyable):
    """Layout choices for one Smile encode.

    A missing header on decode means shared names are on, shared values are off,
    and raw binary is off. The encoder writes unused bits as 0.
    """

    var header: Bool
    var shared_names: Bool
    var shared_values: Bool
    var raw_binary: Bool
    var end_marker: Bool

    def __init__(
        out self,
        header: Bool = True,
        shared_names: Bool = True,
        shared_values: Bool = False,
        raw_binary: Bool = False,
        end_marker: Bool = False,
    ):
        self.header = header
        self.shared_names = shared_names
        self.shared_values = shared_values
        self.raw_binary = raw_binary
        self.end_marker = end_marker


struct DecodeOptions(Copyable, ImplicitlyCopyable):
    """`strict` rejects unused 1-bits. The default ignores them, as the spec requires."""

    var strict: Bool

    def __init__(out self, strict: Bool = False):
        self.strict = strict
