from std.collections import List

comptime SK_BOOL = 1
comptime SK_I32 = 2
comptime SK_I64 = 3
comptime SK_F64 = 4
comptime SK_STRING = 5
comptime SK_REF = 6
comptime SK_ARRAY = 7


struct Field(Copyable, Movable):
    var name: String
    var kind: Int
    var ref_name: String
    var elem_kind: Int
    var elem_ref: String

    def __init__(out self):
        self.name = ""
        self.kind = 0
        self.ref_name = ""
        self.elem_kind = 0
        self.elem_ref = ""


struct TypeDef(Movable):
    var name: String
    var fields: List[Field]

    def __init__(out self):
        self.name = ""
        self.fields = List[Field]()


struct SchemaDoc(Movable):
    var types: List[TypeDef]

    def __init__(out self):
        self.types = List[TypeDef]()
