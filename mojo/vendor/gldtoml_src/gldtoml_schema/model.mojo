from std.collections import List


comptime ST_ANY = 0
comptime ST_NULL = 1
comptime ST_BOOL = 2
comptime ST_INT = 3
comptime ST_NUMBER = 4
comptime ST_STRING = 5
comptime ST_ARRAY = 6
comptime ST_OBJECT = 7
comptime ST_REF = 8
comptime ST_OPTIONAL = 9
comptime ST_UNION = 10
comptime ST_ENUM = 11
comptime ST_CONST = 12
comptime ST_BYTES = 13
comptime ST_EXT = 14
comptime ST_TIMESTAMP = 15

comptime ENC_MAP = 0
comptime ENC_ARRAY = 1
comptime ENC_INTKEYS = 2


struct SchemaProp(Copyable, Movable):
    var name: String
    var type_id: Int
    var required: Bool
    var int_key: Int64
    var has_int_key: Bool

    def __init__(
        out self,
        name: String,
        type_id: Int,
        required: Bool,
        int_key: Int64 = Int64(0),
        has_int_key: Bool = False,
    ):
        self.name = name
        self.type_id = type_id
        self.required = required
        self.int_key = int_key
        self.has_int_key = has_int_key

    def copy(self) -> Self:
        return SchemaProp(self.name, self.type_id, self.required, self.int_key, self.has_int_key)


struct SchemaType(Copyable, Movable):
    var kind: Int
    var name: String
    var inner: Int
    var props: List[SchemaProp]
    var branch_ids: List[Int]
    var enum_strings: List[String]
    var enum_ints: List[Int64]
    var const_kind: Int
    var const_int: Int64
    var const_str: String
    var const_bool: Bool
    var encoding: Int

    def __init__(out self, kind: Int, name: String = ""):
        self.kind = kind
        self.name = name
        self.inner = -1
        self.props = List[SchemaProp]()
        self.branch_ids = List[Int]()
        self.enum_strings = List[String]()
        self.enum_ints = List[Int64]()
        self.const_kind = 0
        self.const_int = Int64(0)
        self.const_str = String()
        self.const_bool = False
        self.encoding = ENC_MAP

    def copy(self) -> Self:
        var out = SchemaType(self.kind, self.name)
        out.inner = self.inner
        out.encoding = self.encoding
        var i = 0
        while i < len(self.props):
            out.props.append(self.props[i].copy())
            i += 1
        i = 0
        while i < len(self.branch_ids):
            out.branch_ids.append(self.branch_ids[i])
            i += 1
        i = 0
        while i < len(self.enum_strings):
            out.enum_strings.append(self.enum_strings[i])
            i += 1
        i = 0
        while i < len(self.enum_ints):
            out.enum_ints.append(self.enum_ints[i])
            i += 1
        out.const_kind = self.const_kind
        out.const_int = self.const_int
        out.const_str = self.const_str
        out.const_bool = self.const_bool
        return out^


struct SchemaDoc(Movable):
    var types: List[SchemaType]
    var def_names: List[String]
    var def_types: List[Int]
    var root: Int
    var root_name: String

    def __init__(out self):
        self.types = List[SchemaType]()
        self.def_names = List[String]()
        self.def_types = List[Int]()
        self.root = 0
        self.root_name = String("Root")

    def add(mut self, var ty: SchemaType) -> Int:
        var idx = len(self.types)
        self.types.append(ty^)
        return idx
