from std.collections import List


comptime CT_ANY = 0
comptime CT_BOOL = 1
comptime CT_INT = 2
comptime CT_UINT = 3
comptime CT_TSTR = 4
comptime CT_BSTR = 5
comptime CT_FLOAT = 6
comptime CT_NULL = 7
comptime CT_NAMED = 8
comptime CT_STRUCT = 9
comptime CT_ARRAY = 10
comptime CT_OPTIONAL = 11
comptime CT_CHOICE = 12
comptime CT_TAG = 13
comptime CT_SOCKET = 14
comptime CT_GENERIC = 15
comptime CT_REGEXP = 16
comptime CT_CONTROL = 17
comptime CT_VALUE = 18
comptime CT_UNWRAP = 19


comptime CK_TEXT_KEY = 0
comptime CK_INT_KEY = 1
comptime CK_POS_KEY = 2


struct CddlMember(Copyable, ImplicitlyCopyable, Movable):
    var name: String
    var type_idx: Int
    var optional: Bool
    var key_kind: Int
    var key_int: Int64

    def __init__(
        out self,
        name: String,
        type_idx: Int,
        optional: Bool = False,
        key_kind: Int = 0,
        key_int: Int64 = 0,
    ):
        self.name = name
        self.type_idx = type_idx
        self.optional = optional
        self.key_kind = key_kind
        self.key_int = key_int


struct CddlType(Copyable, ImplicitlyCopyable, Movable):
    var kind: Int
    var name: String
    var tag: UInt64
    var inner: Int
    var inner2: Int
    var members_start: Int
    var members_count: Int
    var occur_min: Int
    var occur_max: Int

    def __init__(
        out self,
        kind: Int,
        name: String = "",
        tag: UInt64 = 0,
        inner: Int = -1,
        inner2: Int = -1,
        members_start: Int = 0,
        members_count: Int = 0,
        occur_min: Int = 1,
        occur_max: Int = 1,
    ):
        self.kind = kind
        self.name = name
        self.tag = tag
        self.inner = inner
        self.inner2 = inner2
        self.members_start = members_start
        self.members_count = members_count
        self.occur_min = occur_min
        self.occur_max = occur_max


struct CddlDoc(Movable):
    var types: List[CddlType]
    var members: List[CddlMember]
    var def_names: List[String]
    var def_types: List[Int]
    var extras: List[Int]
    var param_names: List[String]
    var socket_names: List[String]
    var socket_group: List[Bool]
    var socket_start: List[Int]
    var socket_count: List[Int]
    var export_names: List[String]
    var export_all: Bool

    def __init__(out self):
        self.types = List[CddlType]()
        self.members = List[CddlMember]()
        self.def_names = List[String]()
        self.def_types = List[Int]()
        self.extras = List[Int]()
        self.param_names = List[String]()
        self.socket_names = List[String]()
        self.socket_group = List[Bool]()
        self.socket_start = List[Int]()
        self.socket_count = List[Int]()
        self.export_names = List[String]()
        self.export_all = True

    def add_type(mut self, t: CddlType) -> Int:
        var i = len(self.types)
        self.types.append(t)
        return i

    def find_socket(self, name: String) -> Int:
        for i in range(len(self.socket_names)):
            if self.socket_names[i] == name:
                return i
        return -1

    def add_socket(mut self, name: String, group: Bool) -> Int:
        var i = len(self.socket_names)
        self.socket_names.append(name)
        self.socket_group.append(group)
        self.socket_start.append(len(self.extras))
        self.socket_count.append(0)
        return i

    def add_plug(mut self, sock: Int, ty: Int):
        self.extras.append(ty)
        self.socket_count[sock] = self.socket_count[sock] + 1
