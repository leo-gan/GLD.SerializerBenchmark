struct EncodeOptions(Copyable, ImplicitlyCopyable):
    var mode: Int

    comptime PREFERRED = 0
    comptime CDE = 1
    comptime IDENTITY = 2
    comptime DCBOR = 3

    comptime preferred = EncodeOptions(mode=Self.PREFERRED)
    comptime cde = EncodeOptions(mode=Self.CDE)
    comptime identity = EncodeOptions(mode=Self.IDENTITY)
    comptime dcbor = EncodeOptions(mode=Self.DCBOR)

    def __init__(out self, mode: Int = 0):
        self.mode = mode

    def is_preferred(self) -> Bool:
        return self.mode == Self.PREFERRED

    def is_cde(self) -> Bool:
        return self.mode == Self.CDE

    def is_identity(self) -> Bool:
        return self.mode == Self.IDENTITY

    def is_dcbor(self) -> Bool:
        return self.mode == Self.DCBOR
