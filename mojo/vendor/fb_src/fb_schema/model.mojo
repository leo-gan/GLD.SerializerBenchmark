from std.collections import List

comptime BT_NONE: Int = 0
comptime BT_UTYPE: Int = 1
comptime BT_BOOL: Int = 2
comptime BT_BYTE: Int = 3
comptime BT_UBYTE: Int = 4
comptime BT_SHORT: Int = 5
comptime BT_USHORT: Int = 6
comptime BT_INT: Int = 7
comptime BT_UINT: Int = 8
comptime BT_LONG: Int = 9
comptime BT_ULONG: Int = 10
comptime BT_FLOAT: Int = 11
comptime BT_DOUBLE: Int = 12
comptime BT_STRING: Int = 13
comptime BT_VECTOR: Int = 14
comptime BT_OBJ: Int = 15
comptime BT_UNION: Int = 16
comptime BT_ARRAY: Int = 17
comptime BT_VECTOR64: Int = 18


def is_scalar(base: Int) -> Bool:
    return base >= BT_UTYPE and base <= BT_DOUBLE


def is_integer(base: Int) -> Bool:
    return base >= BT_UTYPE and base <= BT_ULONG


def scalar_size(base: Int) -> Int:
    if base == BT_BOOL or base == BT_BYTE or base == BT_UBYTE or base == BT_UTYPE:
        return 1
    if base == BT_SHORT or base == BT_USHORT:
        return 2
    if base == BT_INT or base == BT_UINT or base == BT_FLOAT:
        return 4
    if base == BT_LONG or base == BT_ULONG or base == BT_DOUBLE:
        return 8
    return 0


struct TypeRef(Copyable, ImplicitlyCopyable, Movable):
    var base: Int
    var element: Int
    var index: Int
    var type_name: String

    def __init__(out self):
        self.base = BT_NONE
        self.element = BT_NONE
        self.index = -1
        self.type_name = String()


struct FieldDef(Copyable, ImplicitlyCopyable, Movable):
    var name: String
    var ty: TypeRef
    var id: Int
    var offset: Int
    var default_int: Int64
    var default_real: Float64
    var deprecated: Bool
    var required: Bool
    var optional: Bool
    var padding: Int
    var has_id: Bool
    var default_name: String

    def __init__(out self):
        self.name = String()
        self.ty = TypeRef()
        self.id = 0
        self.offset = 0
        self.default_int = 0
        self.default_real = 0.0
        self.deprecated = False
        self.required = False
        self.optional = False
        self.padding = 0
        self.has_id = False
        self.default_name = String()


struct EnumVal(Copyable, ImplicitlyCopyable, Movable):
    var name: String
    var value: Int64
    var union_object: Int
    var union_name: String

    def __init__(out self):
        self.name = String()
        self.value = 0
        self.union_object = -1
        self.union_name = String()


struct EnumDef:
    var name: String
    var is_union: Bool
    var underlying: Int
    var values: List[EnumVal]

    def __init__(out self):
        self.name = String()
        self.is_union = False
        self.underlying = BT_INT
        self.values = List[EnumVal]()


struct ObjectDef:
    var name: String
    var is_struct: Bool
    var minalign: Int
    var bytesize: Int
    var fields: List[FieldDef]
    var laid_out: Bool

    def __init__(out self):
        self.name = String()
        self.is_struct = False
        self.minalign = 1
        self.bytesize = 0
        self.fields = List[FieldDef]()
        self.laid_out = False


struct Schema:
    var objects: List[ObjectDef]
    var enums: List[EnumDef]
    var file_ident: String
    var file_ext: String
    var root: Int
    var root_name: String

    def __init__(out self):
        self.objects = List[ObjectDef]()
        self.enums = List[EnumDef]()
        self.file_ident = String()
        self.file_ext = String()
        self.root = -1
        self.root_name = String()

    def find_object(self, name: String) -> Int:
        for i in range(len(self.objects)):
            if self.objects[i].name == name:
                return i
        return -1

    def find_enum(self, name: String) -> Int:
        for i in range(len(self.enums)):
            if self.enums[i].name == name:
                return i
        return -1


def builtin_type(name: String) -> Int:
    if name == "bool":
        return BT_BOOL
    if name == "byte" or name == "int8":
        return BT_BYTE
    if name == "ubyte" or name == "uint8":
        return BT_UBYTE
    if name == "short" or name == "int16":
        return BT_SHORT
    if name == "ushort" or name == "uint16":
        return BT_USHORT
    if name == "int" or name == "int32":
        return BT_INT
    if name == "uint" or name == "uint32":
        return BT_UINT
    if name == "long" or name == "int64":
        return BT_LONG
    if name == "ulong" or name == "uint64":
        return BT_ULONG
    if name == "float" or name == "float32":
        return BT_FLOAT
    if name == "double" or name == "float64":
        return BT_DOUBLE
    if name == "string":
        return BT_STRING
    return -1


def mojo_scalar(base: Int) -> String:
    if base == BT_BOOL:
        return "Bool"
    if base == BT_BYTE:
        return "Int8"
    if base == BT_UBYTE or base == BT_UTYPE:
        return "UInt8"
    if base == BT_SHORT:
        return "Int16"
    if base == BT_USHORT:
        return "UInt16"
    if base == BT_INT:
        return "Int32"
    if base == BT_UINT:
        return "UInt32"
    if base == BT_LONG:
        return "Int64"
    if base == BT_ULONG:
        return "UInt64"
    if base == BT_FLOAT:
        return "Float32"
    if base == BT_DOUBLE:
        return "Float64"
    return "Int32"
