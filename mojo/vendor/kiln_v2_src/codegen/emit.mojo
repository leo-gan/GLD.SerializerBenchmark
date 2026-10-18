from std.collections import List

from kiln.schema import (
    TY_BOOL,
    TY_BYTES,
    TY_DICT,
    TY_F32,
    TY_F64,
    TY_I16,
    TY_I32,
    TY_I64,
    TY_I8,
    TY_LIST,
    TY_OPT,
    TY_STR,
    TY_STRUCT,
    TY_U16,
    TY_U32,
    TY_U64,
    TY_U8,
    Schema,
)


def emit_source(schema: Schema) -> String:
    """Mojo source for every struct reachable from the schema root."""
    var order = List[Int]()
    var seen = List[Int]()
    _walk(schema, schema.root, seen, order)
    var out = String(
        "from std.collections import Dict, List, Optional, Span\n\n"
        "from kiln import Writer, decode, encode, encoded_size\n\n"
    )
    var i = 0
    while i < len(order):
        out = out + _emit_struct(schema, order[i])
        out = out + "\n"
        i += 1
    return out


def _seen(seen: List[Int], id: Int) -> Bool:
    var i = 0
    while i < len(seen):
        if seen[i] == id:
            return True
        i += 1
    return False


def _walk(schema: Schema, id: Int, mut seen: List[Int], mut order: List[Int]):
    var kind = schema.kind[id]
    if kind == TY_LIST or kind == TY_OPT or kind == TY_DICT:
        _walk(schema, schema.aux[id], seen, order)
        return
    if kind != TY_STRUCT:
        return
    if _seen(seen, id):
        return
    seen.append(id)
    var n = schema.field_n[id]
    var start = schema.field_start[id]
    var i = 0
    while i < n:
        _walk(schema, schema.field_type[start + i], seen, order)
        i += 1
    order.append(id)


def _mojo_type(schema: Schema, id: Int) -> String:
    var kind = schema.kind[id]
    if kind == TY_BOOL:
        return "Bool"
    if kind == TY_I8:
        return "Int8"
    if kind == TY_I16:
        return "Int16"
    if kind == TY_I32:
        return "Int32"
    if kind == TY_I64:
        return "Int64"
    if kind == TY_U8:
        return "UInt8"
    if kind == TY_U16:
        return "UInt16"
    if kind == TY_U32:
        return "UInt32"
    if kind == TY_U64:
        return "UInt64"
    if kind == TY_F32:
        return "Float32"
    if kind == TY_F64:
        return "Float64"
    if kind == TY_STR:
        return "String"
    if kind == TY_BYTES:
        return "List[UInt8]"
    if kind == TY_LIST:
        return "List[" + _mojo_type(schema, schema.aux[id]) + "]"
    if kind == TY_OPT:
        return "Optional[" + _mojo_type(schema, schema.aux[id]) + "]"
    if kind == TY_DICT:
        return "Dict[String, " + _mojo_type(schema, schema.aux[id]) + "]"
    if kind == TY_STRUCT:
        return _ident(schema.name[id])
    return "Int"


def _default(schema: Schema, id: Int) -> String:
    var kind = schema.kind[id]
    if kind == TY_BOOL:
        return "False"
    if kind == TY_F32:
        return "Float32(0)"
    if kind == TY_F64:
        return "0.0"
    if kind == TY_STR:
        return "String(\"\")"
    if kind == TY_I8 or kind == TY_I16 or kind == TY_I32 or kind == TY_I64 or kind == TY_U8 or kind == TY_U16 or kind == TY_U32 or kind == TY_U64:
        return "0"
    var ty = _mojo_type(schema, id)
    if kind == TY_OPT:
        return ty + "(None)"
    return ty + "()"


def _emit_struct(schema: Schema, id: Int) -> String:
    var name = _ident(schema.name[id])
    var n = schema.field_n[id]
    var start = schema.field_start[id]
    var out = String("@fieldwise_init\nstruct ")
    out = out + name + "(Copyable, Movable, Defaultable):\n"
    var i = 0
    while i < n:
        var fname = _ident(schema.field_name[start + i])
        var ty = _mojo_type(schema, schema.field_type[start + i])
        out = out + "    var " + fname + ": " + ty + "\n"
        i += 1
    out = out + "\n    def __init__(out self):\n"
    if n == 0:
        out = out + "        pass\n"
    i = 0
    while i < n:
        var fname = _ident(schema.field_name[start + i])
        var init = _default(schema, schema.field_type[start + i])
        out = out + "        self." + fname + " = " + init + "\n"
        i += 1
    out = out + "\n    def encoded_len(self) -> Int:\n"
    out = out + "        return encoded_size(self)\n\n"
    out = out + "    def encode_to(self, mut w: Writer) raises:\n"
    out = out + "        encode(self, w)\n\n"
    out = out + "    @staticmethod\n"
    out = out + "    def decode_from[o: ImmOrigin](data: Span[UInt8, o]) raises -> Self:\n"
    out = out + "        return decode[Self](data)\n"
    return out


def _ident(name: String) -> String:
    var raw = name.as_bytes()
    var out = String()
    var i = 0
    while i < len(raw):
        var c = Int(raw[i])
        var ok = (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
        if i > 0 and c >= 48 and c <= 57:
            ok = True
        if ok:
            out = out + chr(c)
        else:
            out = out + "_"
        i += 1
    if out.byte_length() == 0:
        return "Root"
    if _keyword(out):
        return out + "_"
    return out


def _keyword(name: String) -> Bool:
    if name == "def" or name == "fn" or name == "var" or name == "struct":
        return True
    if name == "alias" or name == "trait" or name == "comptime" or name == "type":
        return True
    if name == "if" or name == "else" or name == "elif" or name == "for" or name == "while":
        return True
    if name == "return" or name == "from" or name == "import" or name == "as":
        return True
    if name == "try" or name == "except" or name == "raise" or name == "raises":
        return True
    if name == "self" or name == "Self" or name == "True" or name == "False" or name == "None":
        return True
    if name == "and" or name == "or" or name == "not" or name == "in":
        return True
    if name == "ref" or name == "mut" or name == "out" or name == "owned":
        return True
    if name == "pass" or name == "break" or name == "continue":
        return True
    return False
