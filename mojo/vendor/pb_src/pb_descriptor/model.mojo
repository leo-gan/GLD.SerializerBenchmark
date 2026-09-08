from std.collections import List, Optional


comptime TYPE_DOUBLE = 1
comptime TYPE_FLOAT = 2
comptime TYPE_INT64 = 3
comptime TYPE_UINT64 = 4
comptime TYPE_INT32 = 5
comptime TYPE_FIXED64 = 6
comptime TYPE_FIXED32 = 7
comptime TYPE_BOOL = 8
comptime TYPE_STRING = 9
comptime TYPE_GROUP = 10
comptime TYPE_MESSAGE = 11
comptime TYPE_BYTES = 12
comptime TYPE_UINT32 = 13
comptime TYPE_ENUM = 14
comptime TYPE_SFIXED32 = 15
comptime TYPE_SFIXED64 = 16
comptime TYPE_SINT32 = 17
comptime TYPE_SINT64 = 18

comptime LABEL_OPTIONAL = 1
comptime LABEL_REQUIRED = 2
comptime LABEL_REPEATED = 3


struct FieldDesc(Copyable, Movable, Defaultable, Deinitable, ImplicitlyCopyable):
    var name: String
    var number: Int32
    var label: Int
    var type: Int
    var type_name: String
    var oneof_index: Optional[Int]
    var proto3_optional: Bool
    var packed: Optional[Bool]
    var is_map: Bool

    def __init__(out self):
        self.name = String()
        self.number = 0
        self.label = 0
        self.type = 0
        self.type_name = String()
        self.oneof_index = None
        self.proto3_optional = False
        self.packed = None
        self.is_map = False


struct EnumValueDesc(Copyable, Movable, Defaultable, Deinitable, ImplicitlyCopyable):
    var name: String
    var number: Int32

    def __init__(out self):
        self.name = String()
        self.number = 0


struct EnumDesc(Copyable, Movable, Defaultable, Deinitable):
    var name: String
    var values: List[EnumValueDesc]

    def __init__(out self):
        self.name = String()
        self.values = List[EnumValueDesc]()


struct OneofDesc(Copyable, Movable, Defaultable, Deinitable, ImplicitlyCopyable):
    var name: String

    def __init__(out self):
        self.name = String()


struct MessageDesc(Copyable, Movable, Defaultable, Deinitable):
    """One message type. Nested proto types are flattened onto the file list
    (`enclosing` is `Outer` or `Outer.Inner`; empty for file-scope)."""

    var name: String
    var enclosing: String
    var fields: List[FieldDesc]
    var enums: List[EnumDesc]
    var oneofs: List[OneofDesc]
    var map_entry: Bool

    def __init__(out self):
        self.name = String()
        self.enclosing = String()
        self.fields = List[FieldDesc]()
        self.enums = List[EnumDesc]()
        self.oneofs = List[OneofDesc]()
        self.map_entry = False

    def field(self, name: String) -> Optional[FieldDesc]:
        for i in range(len(self.fields)):
            if self.fields[i].name == name:
                return self.fields[i].copy()
        return None

    def dotted_name(self) -> String:
        if self.enclosing.byte_length() == 0:
            return self.name
        return self.enclosing + "." + self.name


struct FileDesc(Copyable, Movable, Defaultable, Deinitable):
    var name: String
    var package: String
    var dependency: List[String]
    var public_dependency: List[Int32]
    var messages: List[MessageDesc]
    var enums: List[EnumDesc]
    var syntax: String
    var has_edition: Bool
    var edition: Int32

    def __init__(out self):
        self.name = String()
        self.package = String()
        self.dependency = List[String]()
        self.public_dependency = List[Int32]()
        self.messages = List[MessageDesc]()
        self.enums = List[EnumDesc]()
        self.syntax = String()
        self.has_edition = False
        self.edition = 0

    def message(self, name: String) -> Optional[MessageDesc]:
        for i in range(len(self.messages)):
            if self.messages[i].name == name:
                return self.messages[i].copy()
        return None


struct FileDescSet(Copyable, Movable, Defaultable, Deinitable):
    var files: List[FileDesc]

    def __init__(out self):
        self.files = List[FileDesc]()

    def file_named(self, name: String) -> Optional[FileDesc]:
        for i in range(len(self.files)):
            if self.files[i].name == name:
                return self.files[i].copy()
        return None


def proto3_error(file: FileDesc) -> String:
    """Empty string if the file may be used as a proto3 codegen input."""
    if file.has_edition:
        return "editions are not supported: " + file.name
    if file.syntax.byte_length() == 0:
        return "missing syntax (proto2 default): " + file.name
    if file.syntax != "proto3":
        return "syntax must be proto3, got '" + file.syntax + "': " + file.name
    return String()


def is_packable(type_id: Int) -> Bool:
    return (
        type_id == TYPE_DOUBLE
        or type_id == TYPE_FLOAT
        or type_id == TYPE_INT64
        or type_id == TYPE_UINT64
        or type_id == TYPE_INT32
        or type_id == TYPE_FIXED64
        or type_id == TYPE_FIXED32
        or type_id == TYPE_BOOL
        or type_id == TYPE_UINT32
        or type_id == TYPE_ENUM
        or type_id == TYPE_SFIXED32
        or type_id == TYPE_SFIXED64
        or type_id == TYPE_SINT32
        or type_id == TYPE_SINT64
    )


def is_packed(field: FieldDesc) -> Bool:
    """Proto3 default: packable repeated is packed unless [packed=false]."""
    if field.label != LABEL_REPEATED:
        return False
    if not is_packable(field.type):
        return False
    if field.packed:
        return field.packed.value()
    return True
