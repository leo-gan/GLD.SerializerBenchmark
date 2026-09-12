from std.collections import List, Span


struct MsgpackExt(Copyable, Movable, Deinitable):
    var type: Int8
    var data: List[Byte]

    def __init__(out self, type: Int8 = Int8(0), var data: List[Byte] = List[Byte]()):
        self.type = type
        self.data = data^

    def copy(self) -> Self:
        var d = List[Byte](capacity=len(self.data))
        var i = 0
        while i < len(self.data):
            d.append(self.data[i])
            i += 1
        return Self(self.type, d^)
