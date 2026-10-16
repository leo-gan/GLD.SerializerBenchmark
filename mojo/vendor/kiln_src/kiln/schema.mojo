from std.collections import List

from kiln.error import KilnError
from kiln.json import J_ARR, J_OBJ, J_STR, JDoc, parse_json


comptime TY_BOOL = 1
comptime TY_I8 = 2
comptime TY_I16 = 3
comptime TY_I32 = 4
comptime TY_I64 = 5
comptime TY_U8 = 6
comptime TY_U16 = 7
comptime TY_U32 = 8
comptime TY_U64 = 9
comptime TY_F32 = 10
comptime TY_F64 = 11
comptime TY_STR = 12
comptime TY_BYTES = 13
comptime TY_LIST = 14
comptime TY_OPT = 15
comptime TY_STRUCT = 16
comptime TY_DICT = 17


struct Schema(Movable):
    """A runtime description of a Kiln value.

    `kind[i]` is the type at index `i`. `aux[i]` is the element, inner,
    or dict value type. Struct fields live in `field_name` / `field_type`
    from `field_start[i]` for `field_n[i]` entries, in declaration order.
    """

    var kind: List[Int]
    var aux: List[Int]
    var name: List[String]
    var field_name: List[String]
    var field_type: List[Int]
    var field_start: List[Int]
    var field_n: List[Int]
    var root: Int
    var def_name: List[String]
    var def_id: List[Int]
    var def_state: List[Int]

    def __init__(out self):
        self.kind = List[Int]()
        self.aux = List[Int]()
        self.name = List[String]()
        self.field_name = List[String]()
        self.field_type = List[Int]()
        self.field_start = List[Int]()
        self.field_n = List[Int]()
        self.root = 0
        self.def_name = List[String]()
        self.def_id = List[Int]()
        self.def_state = List[Int]()

    def add(mut self, kind: Int, aux: Int, var label: String) -> Int:
        var id = len(self.kind)
        self.kind.append(kind)
        self.aux.append(aux)
        self.name.append(label^)
        self.field_start.append(0)
        self.field_n.append(0)
        return id


def schema_from_json(text: String) raises KilnError -> Schema:
    var doc = parse_json(text)
    if doc.kind(doc.root) != J_OBJ:
        raise KilnError(KilnError.SCHEMA, 0)
    var dest = Schema()
    var title = String("Root")
    var tnode = doc.get(doc.root, "title")
    if tnode >= 0 and doc.kind(tnode) == J_STR:
        var got = doc.as_str(tnode)
        if got.byte_length() > 0:
            title = got
    _index_defs(doc, doc.root, dest)
    dest.root = _type(doc, doc.root, dest, title, True)
    return dest^


def _index_defs(doc: JDoc, root: Int, mut dest: Schema):
    var defs = doc.get(root, "$defs")
    if defs < 0 or doc.kind(defs) != J_OBJ:
        return
    var i = 0
    while i < doc.count(defs):
        var name = doc.key_at(defs, i)
        dest.def_name.append(name)
        dest.def_id.append(-1)
        dest.def_state.append(0)
        i += 1


def _find_def(dest: Schema, name: String) -> Int:
    var i = 0
    while i < len(dest.def_name):
        if dest.def_name[i] == name:
            return i
        i += 1
    return -1


def _type(doc: JDoc, id: Int, mut dest: Schema, var label: String, required_obj: Bool) raises KilnError -> Int:
    if doc.kind(id) != J_OBJ:
        raise KilnError(KilnError.SCHEMA, 0)
    var ref_id = doc.get(id, "$ref")
    if ref_id >= 0:
        if doc.kind(ref_id) != J_STR:
            raise KilnError(KilnError.SCHEMA, 0)
        return _resolve_ref(doc, dest, doc.as_str(ref_id))
    var tnode = doc.get(id, "type")
    if tnode < 0 or doc.kind(tnode) != J_STR:
        raise KilnError(KilnError.SCHEMA, 0)
    var t = doc.as_str(tnode)
    if t == "boolean":
        return dest.add(TY_BOOL, 0, String(""))
    if t == "string":
        var fmt = doc.get(id, "format")
        if fmt >= 0 and doc.kind(fmt) == J_STR and doc.as_str(fmt) == "binary":
            return dest.add(TY_BYTES, 0, String(""))
        return dest.add(TY_STR, 0, String(""))
    if t == "integer":
        return dest.add(_int_kind(doc, id), 0, String(""))
    if t == "number":
        var fmt = doc.get(id, "format")
        if fmt >= 0 and doc.kind(fmt) == J_STR and doc.as_str(fmt) == "float":
            return dest.add(TY_F32, 0, String(""))
        return dest.add(TY_F64, 0, String(""))
    if t == "array":
        var items = doc.get(id, "items")
        if items < 0:
            raise KilnError(KilnError.SCHEMA, 0)
        var elem_name = label + "Item"
        var elem = _type(doc, items, dest, elem_name^, False)
        return dest.add(TY_LIST, elem, String(""))
    if t == "object":
        var extra = doc.get(id, "additionalProperties")
        var props = doc.get(id, "properties")
        if extra >= 0 and doc.kind(extra) == J_OBJ and (props < 0 or doc.count(props) == 0):
            var vn = label + "Value"
            var inner = _type(doc, extra, dest, vn^, False)
            return dest.add(TY_DICT, inner, String(""))
        return _object(doc, id, dest, label^, required_obj)
    raise KilnError(KilnError.SCHEMA, 0)


def _int_kind(doc: JDoc, id: Int) -> Int:
    var fmt = doc.get(id, "format")
    if fmt < 0 or doc.kind(fmt) != J_STR:
        return TY_I64
    var s = doc.as_str(fmt)
    if s == "int8":
        return TY_I8
    if s == "int16":
        return TY_I16
    if s == "int32":
        return TY_I32
    if s == "int64":
        return TY_I64
    if s == "uint8":
        return TY_U8
    if s == "uint16":
        return TY_U16
    if s == "uint32":
        return TY_U32
    if s == "uint64":
        return TY_U64
    return TY_I64


def _object(doc: JDoc, id: Int, mut dest: Schema, var label: String, is_root: Bool) raises KilnError -> Int:
    _ = is_root
    var sid = dest.add(TY_STRUCT, 0, label^)
    var props = doc.get(id, "properties")
    var names = List[String]()
    var types = List[Int]()
    if props >= 0 and doc.kind(props) == J_OBJ:
        var i = 0
        while i < doc.count(props):
            var fname = doc.key_at(props, i)
            var body = doc.at(props, i)
            var child_name = dest.name[sid] + "_" + fname
            var tid = _type(doc, body, dest, child_name^, False)
            if not _is_required(doc, id, fname):
                tid = dest.add(TY_OPT, tid, String(""))
            names.append(fname)
            types.append(tid)
            i += 1
    # Nested structs append their own fields before these, so the
    # parent's field records stay in one contiguous range.
    var start = len(dest.field_name)
    var i = 0
    while i < len(names):
        var stored = names[i]
        dest.field_name.append(stored)
        dest.field_type.append(types[i])
        i += 1
    dest.field_start[sid] = start
    dest.field_n[sid] = len(names)
    return sid


def _is_required(doc: JDoc, id: Int, name: String) -> Bool:
    var req = doc.get(id, "required")
    if req < 0 or doc.kind(req) != J_ARR:
        return True
    var i = 0
    while i < doc.count(req):
        var item = doc.at(req, i)
        if doc.kind(item) == J_STR and doc.as_str(item) == name:
            return True
        i += 1
    return False


def _resolve_ref(doc: JDoc, mut dest: Schema, ref_text: String) raises KilnError -> Int:
    var prefix = "#/$defs/"
    var raw = ref_text.as_bytes()
    var pre = prefix.as_bytes()
    if len(raw) <= len(pre):
        raise KilnError(KilnError.SCHEMA, 0)
    var i = 0
    while i < len(pre):
        if raw[i] != pre[i]:
            raise KilnError(KilnError.SCHEMA, 0)
        i += 1
    var name = String(unsafe_from_utf8=raw[len(pre):])
    var slot = _find_def(dest, name)
    if slot < 0:
        raise KilnError(KilnError.SCHEMA, 0)
    if dest.def_state[slot] == 2:
        return dest.def_id[slot]
    if dest.def_state[slot] == 1:
        raise KilnError(KilnError.SCHEMA, 0)
    dest.def_state[slot] = 1
    var defs = doc.get(doc.root, "$defs")
    var body = doc.get(defs, name)
    if body < 0:
        raise KilnError(KilnError.SCHEMA, 0)
    var tid = _type(doc, body, dest, name, False)
    dest.def_id[slot] = tid
    dest.def_state[slot] = 2
    return tid
