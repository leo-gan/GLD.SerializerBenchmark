from std.collections import List


comptime ST_NULL = 0
comptime ST_BOOL = 1
comptime ST_INT = 2
comptime ST_LONG = 3
comptime ST_FLOAT = 4
comptime ST_DOUBLE = 5
comptime ST_BYTES = 6
comptime ST_STRING = 7
comptime ST_RECORD = 8
comptime ST_ENUM = 9
comptime ST_ARRAY = 10
comptime ST_MAP = 11
comptime ST_UNION = 12
comptime ST_FIXED = 13
comptime ST_REF = 14


struct SchemaError(Copyable, ImplicitlyCopyable, Writable):
    var message: String

    def __init__(out self, message: String):
        self.message = message

    def write_to[W: Writer](self, mut writer: W):
        writer.write("SchemaError(", self.message, ")")


struct SchemaNode(Copyable, Movable, Defaultable, Deinitable, ImplicitlyCopyable):
    var kind: Int
    var name: String
    var namespace: String
    var doc: String
    var logical_type: String
    var enum_default: String
    var item_id: Int
    var value_id: Int
    var size: Int
    var ref_id: Int
    var field_start: Int
    var field_count: Int
    var branch_start: Int
    var branch_count: Int
    var symbol_start: Int
    var symbol_count: Int
    var is_error: Bool

    def __init__(out self):
        self.kind = ST_NULL
        self.name = String()
        self.namespace = String()
        self.doc = String()
        self.logical_type = String()
        self.enum_default = String()
        self.item_id = -1
        self.value_id = -1
        self.size = 0
        self.ref_id = -1
        self.field_start = 0
        self.field_count = 0
        self.branch_start = 0
        self.branch_count = 0
        self.symbol_start = 0
        self.symbol_count = 0
        self.is_error = False


struct SchemaPool(Movable):
    var nodes: List[SchemaNode]
    var names: List[String]
    var name_ids: List[Int]
    var field_name: List[String]
    var field_type: List[Int]
    var field_has_default: List[Bool]
    var field_default: List[String]
    var branch_id: List[Int]
    var symbol: List[String]
    var leftover_owner: List[Int]
    var leftover_key: List[String]
    var leftover_val: List[String]
    var alias_owner: List[Int]
    var alias_name: List[String]
    var root: Int
    var original_json: String

    def __init__(out self):
        self.nodes = List[SchemaNode]()
        self.names = List[String]()
        self.name_ids = List[Int]()
        self.field_name = List[String]()
        self.field_type = List[Int]()
        self.field_has_default = List[Bool]()
        self.field_default = List[String]()
        self.branch_id = List[Int]()
        self.symbol = List[String]()
        self.leftover_owner = List[Int]()
        self.leftover_key = List[String]()
        self.leftover_val = List[String]()
        self.alias_owner = List[Int]()
        self.alias_name = List[String]()
        self.root = -1
        self.original_json = String()

    def add(mut self, var node: SchemaNode) -> Int:
        var id = len(self.nodes)
        if node.name.byte_length() > 0:
            self.names.append(node.name)
            self.name_ids.append(id)
        self.nodes.append(node)
        return id

    def find_name(self, full: String) -> Int:
        var i = 0
        while i < len(self.names):
            if self.names[i] == full:
                return self.name_ids[i]
            i += 1
        return -1

    def resolve(self, id: Int) -> Int:
        var cur = id
        var guard = 0
        while self.nodes[cur].kind == ST_REF and guard < 32:
            cur = self.nodes[cur].ref_id
            guard += 1
        return cur

    def kind_of(self, id: Int) -> Int:
        return self.nodes[self.resolve(id)].kind

    def add_field(mut self, owner: Int, name: String, type_id: Int, has_def: Bool, defj: String):
        if self.nodes[owner].field_count == 0:
            self.nodes[owner].field_start = len(self.field_name)
        self.field_name.append(name)
        self.field_type.append(type_id)
        self.field_has_default.append(has_def)
        self.field_default.append(defj)
        self.nodes[owner].field_count += 1

    def add_branch(mut self, owner: Int, bid: Int):
        if self.nodes[owner].branch_count == 0:
            self.nodes[owner].branch_start = len(self.branch_id)
        self.branch_id.append(bid)
        self.nodes[owner].branch_count += 1

    def add_symbol(mut self, owner: Int, sym: String):
        if self.nodes[owner].symbol_count == 0:
            self.nodes[owner].symbol_start = len(self.symbol)
        self.symbol.append(sym)
        self.nodes[owner].symbol_count += 1

    def add_alias(mut self, owner: Int, name: String):
        self.alias_owner.append(owner)
        self.alias_name.append(name)

    def add_leftover(mut self, owner: Int, key: String, val: String):
        self.leftover_owner.append(owner)
        self.leftover_key.append(key)
        self.leftover_val.append(val)

    def leftover(self, owner: Int, key: String) -> String:
        var i = 0
        while i < len(self.leftover_owner):
            if self.leftover_owner[i] == owner and self.leftover_key[i] == key:
                return self.leftover_val[i]
            i += 1
        return String()

