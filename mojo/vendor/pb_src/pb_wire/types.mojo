struct WireType(Equatable, ImplicitlyCopyable, TrivialRegisterPassable, Writable):
    var value: UInt8

    comptime VARINT = WireType(0)
    comptime I64 = WireType(1)
    comptime LEN = WireType(2)
    comptime SGROUP = WireType(3)
    comptime EGROUP = WireType(4)
    comptime I32 = WireType(5)

    def __init__(out self, value: UInt8):
        self.value = value

    def is_implemented(self) -> Bool:
        return (
            self.value == 0
            or self.value == 1
            or self.value == 2
            or self.value == 5
        )

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def write_to[W: Writer](self, mut writer: W):
        writer.write("WireType(", self.value, ")")
