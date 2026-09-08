from std.collections import List, Optional

from pb_codegen.names import (
    ResolvedType,
    mojo_field_name,
    mojo_type_name,
    resolve_type_name,
    safe_stem,
)
from pb_descriptor.model import (
    EnumDesc,
    FieldDesc,
    FileDesc,
    FileDescSet,
    LABEL_REPEATED,
    LABEL_REQUIRED,
    MessageDesc,
    TYPE_BOOL,
    TYPE_BYTES,
    TYPE_DOUBLE,
    TYPE_ENUM,
    TYPE_FIXED32,
    TYPE_FIXED64,
    TYPE_FLOAT,
    TYPE_GROUP,
    TYPE_INT32,
    TYPE_INT64,
    TYPE_MESSAGE,
    TYPE_SFIXED32,
    TYPE_SFIXED64,
    TYPE_SINT32,
    TYPE_SINT64,
    TYPE_STRING,
    TYPE_UINT32,
    TYPE_UINT64,
    is_packed,
    proto3_error,
)


struct EmitError(Copyable, Movable, Defaultable, Writable):
    var message: String

    def __init__(out self):
        self.message = String()

    def __init__(out self, message: String):
        self.message = message

    def write_to[W: Writer](self, mut writer: W):
        writer.write(self.message)


def _check_field(field: FieldDesc) raises EmitError:
    if field.label == LABEL_REQUIRED:
        raise EmitError("required fields are proto2: " + field.name)
    if field.type == TYPE_GROUP:
        raise EmitError("groups are not supported: " + field.name)
    if field.type < 1 or field.type > 18:
        raise EmitError("unknown field type: " + field.name)


def _is_real_oneof(field: FieldDesc) -> Bool:
    return Bool(field.oneof_index) and not field.proto3_optional


def _which_ident(msg: MessageDesc, field: FieldDesc) -> String:
    var idx = field.oneof_index.value()
    return mojo_field_name("which_" + msg.oneofs[idx].name)


def _resolve(set: FileDescSet, file: FileDesc, type_name: String) raises EmitError -> ResolvedType:
    try:
        return resolve_type_name(set, file.name, type_name)
    except _:
        raise EmitError("type_name resolve failed: " + type_name)


def _full_name(file: FileDesc, msg: MessageDesc) -> String:
    if file.package.byte_length() != 0:
        return "." + file.package + "." + msg.dotted_name()
    return "." + msg.dotted_name()


def _message_points_at(msg: MessageDesc, type_name: String) -> Bool:
    for i in range(len(msg.fields)):
        if msg.fields[i].is_map:
            continue
        if msg.fields[i].type == TYPE_MESSAGE and msg.fields[i].type_name == type_name:
            return True
    return False


def _skip_as_unknown(
    set: FileDescSet, file: FileDesc, msg: MessageDesc, field: FieldDesc
) -> Bool:
    """True when a typed member would form a Mojo layout cycle (Deinitable)."""
    if field.is_map or field.type != TYPE_MESSAGE:
        return False
    var self_name = _full_name(file, msg)
    if field.type_name == self_name:
        return True
    try:
        var other = _find_message(set, field.type_name)
        return _message_points_at(other, self_name)
    except _:
        return False


def _find_message(set: FileDescSet, type_name: String) raises EmitError -> MessageDesc:
    for i in range(len(set.files)):
        var file = set.files[i].copy()
        var prefix = String(".")
        if file.package.byte_length() != 0:
            prefix = "." + file.package + "."
        for j in range(len(file.messages)):
            var full = prefix + file.messages[j].dotted_name()
            if full == type_name or file.messages[j].dotted_name() == type_name:
                return file.messages[j].copy()
    raise EmitError("message not found: " + type_name)


def _scalar_mojo(type_id: Int) -> String:
    if type_id == TYPE_BOOL:
        return "Bool"
    if type_id == TYPE_INT32 or type_id == TYPE_SINT32 or type_id == TYPE_SFIXED32:
        return "Int32"
    if type_id == TYPE_INT64 or type_id == TYPE_SINT64 or type_id == TYPE_SFIXED64:
        return "Int64"
    if type_id == TYPE_UINT32 or type_id == TYPE_FIXED32:
        return "UInt32"
    if type_id == TYPE_UINT64 or type_id == TYPE_FIXED64:
        return "UInt64"
    if type_id == TYPE_FLOAT:
        return "Float32"
    if type_id == TYPE_DOUBLE:
        return "Float64"
    if type_id == TYPE_STRING:
        return "String"
    if type_id == TYPE_BYTES:
        return "List[Byte]"
    return String()


def _elem_type(set: FileDescSet, file: FileDesc, field: FieldDesc) raises EmitError -> String:
    if field.type == TYPE_MESSAGE:
        var resolved = _resolve(set, file, field.type_name)
        if not resolved.ok:
            raise EmitError(resolved.error)
        return resolved.mojo_name
    if field.type == TYPE_ENUM:
        var resolved = _resolve(set, file, field.type_name)
        if not resolved.ok:
            raise EmitError(resolved.error)
        return resolved.mojo_name
    var s = _scalar_mojo(field.type)
    if s.byte_length() == 0:
        raise EmitError("unsupported field type: " + field.name)
    return s


def _map_entry_kv(
    set: FileDescSet, file: FileDesc, field: FieldDesc
) raises EmitError -> Tuple[FieldDesc, FieldDesc]:
    var entry = _find_message(set, field.type_name)
    var key = FieldDesc()
    var val = FieldDesc()
    var have_key = False
    var have_val = False
    for i in range(len(entry.fields)):
        if entry.fields[i].number == 1:
            key = entry.fields[i].copy()
            have_key = True
        elif entry.fields[i].number == 2:
            val = entry.fields[i].copy()
            have_val = True
    if not have_key or not have_val:
        raise EmitError("map entry missing key/value: " + field.name)
    return (key^, val^)


def _field_type(set: FileDescSet, file: FileDesc, field: FieldDesc) raises EmitError -> String:
    if field.is_map:
        var kv = _map_entry_kv(set, file, field)
        var kt = _elem_type(set, file, kv[0])
        var vt = _elem_type(set, file, kv[1])
        return "Dict[" + kt + ", " + vt + "]"
    var elem = _elem_type(set, file, field)
    if field.label == LABEL_REPEATED:
        return "List[" + elem + "]"
    if field.type == TYPE_MESSAGE or field.proto3_optional:
        return "Optional[" + elem + "]"
    return elem


def _default_expr(set: FileDescSet, file: FileDesc, field: FieldDesc) raises EmitError -> String:
    if field.is_map:
        return _field_type(set, file, field) + "()"
    if field.label == LABEL_REPEATED:
        return _field_type(set, file, field) + "()"
    if field.type == TYPE_MESSAGE or field.proto3_optional:
        return "None"
    if field.type == TYPE_BOOL:
        return "False"
    if field.type == TYPE_INT32 or field.type == TYPE_SINT32 or field.type == TYPE_SFIXED32:
        return "Int32(0)"
    if field.type == TYPE_INT64 or field.type == TYPE_SINT64 or field.type == TYPE_SFIXED64:
        return "Int64(0)"
    if field.type == TYPE_UINT32 or field.type == TYPE_FIXED32:
        return "UInt32(0)"
    if field.type == TYPE_UINT64 or field.type == TYPE_FIXED64:
        return "UInt64(0)"
    if field.type == TYPE_FLOAT:
        return "Float32(0.0)"
    if field.type == TYPE_DOUBLE:
        return "0.0"
    if field.type == TYPE_BYTES:
        return "List[Byte]()"
    if field.type == TYPE_ENUM:
        return _elem_type(set, file, field) + "()"
    return "String()"


def _is_varint(type_id: Int) -> Bool:
    return (
        type_id == TYPE_BOOL
        or type_id == TYPE_INT32
        or type_id == TYPE_INT64
        or type_id == TYPE_UINT32
        or type_id == TYPE_UINT64
        or type_id == TYPE_SINT32
        or type_id == TYPE_SINT64
        or type_id == TYPE_ENUM
    )


def _is_i32(type_id: Int) -> Bool:
    return (
        type_id == TYPE_FLOAT
        or type_id == TYPE_FIXED32
        or type_id == TYPE_SFIXED32
    )


def _is_i64(type_id: Int) -> Bool:
    return (
        type_id == TYPE_DOUBLE
        or type_id == TYPE_FIXED64
        or type_id == TYPE_SFIXED64
    )


def _u64_expr(type_id: Int, expr: String) -> String:
    if type_id == TYPE_BOOL:
        return "UInt64(Int(" + expr + "))"
    if type_id == TYPE_INT32:
        return "i32_to_u64(" + expr + ")"
    if type_id == TYPE_INT64:
        return "i64_to_u64(" + expr + ")"
    if type_id == TYPE_UINT32:
        return "UInt64(" + expr + ")"
    if type_id == TYPE_UINT64:
        return expr
    if type_id == TYPE_SINT32:
        return "UInt64(zigzag_encode_i32(" + expr + "))"
    if type_id == TYPE_SINT64:
        return "zigzag_encode_i64(" + expr + ")"
    if type_id == TYPE_ENUM:
        return "i32_to_u64(" + expr + ".value)"
    return expr


def _i32_bits(type_id: Int, expr: String) -> String:
    if type_id == TYPE_FLOAT:
        return "UInt32(" + expr + ".to_bits())"
    if type_id == TYPE_SFIXED32:
        return "UInt32(" + expr + ")"
    return expr


def _i64_bits(type_id: Int, expr: String) -> String:
    if type_id == TYPE_DOUBLE:
        return "UInt64(" + expr + ".to_bits())"
    if type_id == TYPE_SFIXED64:
        return "UInt64(" + expr + ")"
    return expr


def _from_varint(set: FileDescSet, file: FileDesc, field: FieldDesc, word: String) raises EmitError -> String:
    if field.type == TYPE_BOOL:
        return word + " != 0"
    if field.type == TYPE_INT32:
        return "u64_to_i32(" + word + ")"
    if field.type == TYPE_INT64:
        return "u64_to_i64(" + word + ")"
    if field.type == TYPE_UINT32:
        return "UInt32(" + word + ")"
    if field.type == TYPE_UINT64:
        return word
    if field.type == TYPE_SINT32:
        return "zigzag_decode_i32(UInt32(" + word + "))"
    if field.type == TYPE_SINT64:
        return "zigzag_decode_i64(" + word + ")"
    if field.type == TYPE_ENUM:
        return _elem_type(set, file, field) + "(u64_to_i32(" + word + "))"
    raise EmitError("not a varint type: " + field.name)


def _from_i32(type_id: Int, bits: String) -> String:
    if type_id == TYPE_FLOAT:
        return "Float32(from_bits=" + bits + ")"
    if type_id == TYPE_SFIXED32:
        return "Int32(" + bits + ")"
    return bits


def _from_i64(type_id: Int, bits: String) -> String:
    if type_id == TYPE_DOUBLE:
        return "Float64(from_bits=" + bits + ")"
    if type_id == TYPE_SFIXED64:
        return "Int64(" + bits + ")"
    return bits


def _implicit_nonzero(type_id: Int, expr: String) -> String:
    if type_id == TYPE_BOOL:
        return expr
    if type_id == TYPE_STRING:
        return expr + ".byte_length() != 0"
    if type_id == TYPE_BYTES:
        return "len(" + expr + ") != 0"
    if type_id == TYPE_FLOAT or type_id == TYPE_DOUBLE:
        return expr + " != 0.0"
    if type_id == TYPE_ENUM:
        return expr + ".value != 0"
    return expr + " != 0"


def _payload_len_expr(type_id: Int, expr: String) -> String:
    if _is_varint(type_id):
        return "varint_len(" + _u64_expr(type_id, expr) + ")"
    if _is_i32(type_id):
        return "4"
    if _is_i64(type_id):
        return "8"
    if type_id == TYPE_STRING:
        return expr + ".byte_length()"
    if type_id == TYPE_BYTES:
        return "len(" + expr + ")"
    if type_id == TYPE_MESSAGE:
        return expr + ".encoded_len()"
    return "0"


def _write_scalar(num: String, type_id: Int, expr: String, indent: String) -> String:
    if _is_varint(type_id):
        return (
            indent
            + "enc.write_tag("
            + num
            + ", WireType.VARINT)\n"
            + indent
            + "enc.write_varint("
            + _u64_expr(type_id, expr)
            + ")\n"
        )
    if _is_i32(type_id):
        return (
            indent
            + "enc.write_tag("
            + num
            + ", WireType.I32)\n"
            + indent
            + "enc.write_i32_le("
            + _i32_bits(type_id, expr)
            + ")\n"
        )
    if _is_i64(type_id):
        return (
            indent
            + "enc.write_tag("
            + num
            + ", WireType.I64)\n"
            + indent
            + "enc.write_i64_le("
            + _i64_bits(type_id, expr)
            + ")\n"
        )
    if type_id == TYPE_STRING:
        return (
            indent
            + "enc.write_len_header("
            + num
            + ", "
            + expr
            + ".byte_length())\n"
            + indent
            + "enc.write_bytes("
            + expr
            + ".as_bytes())\n"
        )
    if type_id == TYPE_BYTES:
        return (
            indent
            + "enc.write_len_header("
            + num
            + ", len("
            + expr
            + "))\n"
            + indent
            + "enc.write_bytes("
            + expr
            + ")\n"
        )
    return String()


def _len_scalar(num: String, type_id: Int, expr: String) -> String:
    if _is_varint(type_id):
        return "tag_varint_len(" + num + ", " + _u64_expr(type_id, expr) + ")"
    if _is_i32(type_id):
        return "tag_fixed32_len(" + num + ")"
    if _is_i64(type_id):
        return "tag_fixed64_len(" + num + ")"
    if type_id == TYPE_STRING:
        return "tag_len_len(" + num + ", " + expr + ".byte_length())"
    if type_id == TYPE_BYTES:
        return "tag_len_len(" + num + ", len(" + expr + "))"
    if type_id == TYPE_MESSAGE:
        return "tag_len_len(" + num + ", " + expr + ".encoded_len())"
    return "0"


def _kw(first: Bool) -> String:
    if first:
        return "if"
    return "elif"


def _emit_encoded_len(
    set: FileDescSet, file: FileDesc, msg: MessageDesc, field: FieldDesc, fname: String
) raises EmitError -> String:
    var num = String(field.number)
    if _is_real_oneof(field):
        var which = _which_ident(msg, field)
        var expr = "self." + fname
        if field.type == TYPE_MESSAGE:
            return (
                "        if self."
                + which
                + " == "
                + num
                + ":\n            n += tag_len_len("
                + num
                + ", "
                + expr
                + ".encoded_len())\n"
            )
        return (
            "        if self."
            + which
            + " == "
            + num
            + ":\n            n += "
            + _len_scalar(num, field.type, expr)
            + "\n"
        )
    if field.is_map:
        var kv = _map_entry_kv(set, file, field)
        var key = kv[0]
        var val = kv[1]
        var out = String()
        out += "        for item in self." + fname + ".items():\n"
        out += "            var entry_len = 0\n"
        if key.type == TYPE_STRING:
            out += (
                "            if item.key.byte_length() != 0:\n"
                "                entry_len += tag_len_len(1, item.key.byte_length())\n"
            )
        else:
            out += (
                "            if "
                + _implicit_nonzero(key.type, "item.key")
                + ":\n                entry_len += "
                + _len_scalar("1", key.type, "item.key")
                + "\n"
            )
        if val.type == TYPE_MESSAGE:
            out += "            entry_len += tag_len_len(2, item.value.encoded_len())\n"
        else:
            out += (
                "            if "
                + _implicit_nonzero(val.type, "item.value")
                + ":\n                entry_len += "
                + _len_scalar("2", val.type, "item.value")
                + "\n"
            )
        out += "            n += tag_len_len(" + num + ", entry_len)\n"
        return out
    if field.label == LABEL_REPEATED and is_packed(field):
        if _is_i32(field.type):
            return (
                "        if len(self."
                + fname
                + ") != 0:\n            n += tag_len_len("
                + num
                + ", len(self."
                + fname
                + ") * 4)\n"
            )
        if _is_i64(field.type):
            return (
                "        if len(self."
                + fname
                + ") != 0:\n            n += tag_len_len("
                + num
                + ", len(self."
                + fname
                + ") * 8)\n"
            )
        var out = String()
        out += "        if len(self." + fname + ") != 0:\n"
        out += "            var payload = 0\n"
        out += "            for i in range(len(self." + fname + ")):\n"
        out += (
            "                payload += "
            + _payload_len_expr(field.type, "self." + fname + "[i]")
            + "\n"
        )
        out += "            n += tag_len_len(" + num + ", payload)\n"
        return out
    if field.label == LABEL_REPEATED:
        if field.type == TYPE_MESSAGE:
            return (
                "        for i in range(len(self."
                + fname
                + ")):\n            n += tag_len_len("
                + num
                + ", self."
                + fname
                + "[i].encoded_len())\n"
            )
        return (
            "        for i in range(len(self."
            + fname
            + ")):\n            n += "
            + _len_scalar(num, field.type, "self." + fname + "[i]")
            + "\n"
        )
    if field.type == TYPE_MESSAGE or field.proto3_optional:
        var inner = "self." + fname + ".value()"
        if field.type == TYPE_MESSAGE:
            return (
                "        if self."
                + fname
                + ":\n            n += tag_len_len("
                + num
                + ", "
                + inner
                + ".encoded_len())\n"
            )
        return (
            "        if self."
            + fname
            + ":\n            n += "
            + _len_scalar(num, field.type, inner)
            + "\n"
        )
    return (
        "        if "
        + _implicit_nonzero(field.type, "self." + fname)
        + ":\n            n += "
        + _len_scalar(num, field.type, "self." + fname)
        + "\n"
    )


def _emit_encode(
    set: FileDescSet, file: FileDesc, msg: MessageDesc, field: FieldDesc, fname: String
) raises EmitError -> String:
    var num = String(field.number)
    if _is_real_oneof(field):
        var which = _which_ident(msg, field)
        if field.type == TYPE_MESSAGE:
            return (
                "        if self."
                + which
                + " == "
                + num
                + ":\n            enc.write_len_header("
                + num
                + ", self."
                + fname
                + ".encoded_len())\n            self."
                + fname
                + ".encode_to(enc)\n"
            )
        return (
            "        if self."
            + which
            + " == "
            + num
            + ":\n"
            + _write_scalar(num, field.type, "self." + fname, "            ")
        )
    if field.is_map:
        var kv = _map_entry_kv(set, file, field)
        var key = kv[0]
        var val = kv[1]
        var out = String()
        out += "        for item in self." + fname + ".items():\n"
        out += "            var entry_len = 0\n"
        if key.type == TYPE_STRING:
            out += (
                "            if item.key.byte_length() != 0:\n"
                "                entry_len += tag_len_len(1, item.key.byte_length())\n"
            )
        else:
            out += (
                "            if "
                + _implicit_nonzero(key.type, "item.key")
                + ":\n                entry_len += "
                + _len_scalar("1", key.type, "item.key")
                + "\n"
            )
        if val.type == TYPE_MESSAGE:
            out += "            entry_len += tag_len_len(2, item.value.encoded_len())\n"
        else:
            out += (
                "            if "
                + _implicit_nonzero(val.type, "item.value")
                + ":\n                entry_len += "
                + _len_scalar("2", val.type, "item.value")
                + "\n"
            )
        out += "            enc.write_len_header(" + num + ", entry_len)\n"
        if key.type == TYPE_STRING:
            out += (
                "            if item.key.byte_length() != 0:\n"
                + _write_scalar("1", key.type, "item.key", "                ")
            )
        else:
            out += (
                "            if "
                + _implicit_nonzero(key.type, "item.key")
                + ":\n"
                + _write_scalar("1", key.type, "item.key", "                ")
            )
        if val.type == TYPE_MESSAGE:
            out += (
                "            enc.write_len_header(2, item.value.encoded_len())\n"
                "            item.value.encode_to(enc)\n"
            )
        else:
            out += (
                "            if "
                + _implicit_nonzero(val.type, "item.value")
                + ":\n"
                + _write_scalar("2", val.type, "item.value", "                ")
            )
        return out
    if field.label == LABEL_REPEATED and is_packed(field):
        if _is_i32(field.type):
            return (
                "        if len(self."
                + fname
                + ") != 0:\n            enc.write_len_header("
                + num
                + ", len(self."
                + fname
                + ") * 4)\n            for i in range(len(self."
                + fname
                + ")):\n                enc.write_i32_le("
                + _i32_bits(field.type, "self." + fname + "[i]")
                + ")\n"
            )
        if _is_i64(field.type):
            return (
                "        if len(self."
                + fname
                + ") != 0:\n            enc.write_len_header("
                + num
                + ", len(self."
                + fname
                + ") * 8)\n            for i in range(len(self."
                + fname
                + ")):\n                enc.write_i64_le("
                + _i64_bits(field.type, "self." + fname + "[i]")
                + ")\n"
            )
        return (
            "        if len(self."
            + fname
            + ") != 0:\n            var payload = 0\n            for i in range(len(self."
            + fname
            + ")):\n                payload += "
            + _payload_len_expr(field.type, "self." + fname + "[i]")
            + "\n            enc.write_len_header("
            + num
            + ", payload)\n            for i in range(len(self."
            + fname
            + ")):\n                enc.write_varint("
            + _u64_expr(field.type, "self." + fname + "[i]")
            + ")\n"
        )
    if field.label == LABEL_REPEATED:
        if field.type == TYPE_MESSAGE:
            return (
                "        for i in range(len(self."
                + fname
                + ")):\n            enc.write_len_header("
                + num
                + ", self."
                + fname
                + "[i].encoded_len())\n            self."
                + fname
                + "[i].encode_to(enc)\n"
            )
        return (
            "        for i in range(len(self."
            + fname
            + ")):\n"
            + _write_scalar(num, field.type, "self." + fname + "[i]", "            ")
        )
    if field.type == TYPE_MESSAGE:
        return (
            "        if self."
            + fname
            + ":\n            ref child = self."
            + fname
            + ".value()\n            enc.write_len_header("
            + num
            + ", child.encoded_len())\n            child.encode_to(enc)\n"
        )
    if field.proto3_optional:
        return (
            "        if self."
            + fname
            + ":\n"
            + _write_scalar(num, field.type, "self." + fname + ".value()", "            ")
        )
    return (
        "        if "
        + _implicit_nonzero(field.type, "self." + fname)
        + ":\n"
        + _write_scalar(num, field.type, "self." + fname, "            ")
    )


def _reset_oneof(
    set: FileDescSet, file: FileDesc, msg: MessageDesc, keep: FieldDesc
) raises EmitError -> String:
    var out = String()
    for i in range(len(msg.fields)):
        var f = msg.fields[i]
        if not _is_real_oneof(f):
            continue
        if _skip_as_unknown(set, file, msg, f):
            continue
        if f.oneof_index.value() != keep.oneof_index.value():
            continue
        if f.number == keep.number:
            continue
        var default: String
        if f.type == TYPE_MESSAGE:
            default = _elem_type(set, file, f) + "()"
        else:
            default = _default_expr(set, file, f)
        out += (
            "                self."
            + mojo_field_name(f.name)
            + " = "
            + default
            + "\n"
        )
    return out


def _assign_optional(expr: String) -> String:
    return "Optional(" + expr + ")"


def _emit_decode(
    set: FileDescSet,
    file: FileDesc,
    msg: MessageDesc,
    field: FieldDesc,
    fname: String,
    first: Bool,
) raises EmitError -> String:
    var num = String(field.number)
    var kw = _kw(first)
    var elem = _elem_type(set, file, field)
    if field.is_map:
        var kv = _map_entry_kv(set, file, field)
        var key = kv[0]
        var val = kv[1]
        var out = String()
        out += (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.LEN:\n"
        )
        out += "                var inner = dec.subreader(dec.read_len_span())\n"
        out += (
            "                var map_key = "
            + _default_expr(set, file, key)
            + "\n"
        )
        var val_zero: String
        if val.type == TYPE_MESSAGE:
            val_zero = _elem_type(set, file, val) + "()"
        else:
            val_zero = _default_expr(set, file, val)
        out += "                var map_val = " + val_zero + "\n"
        out += "                while inner.remaining() > 0:\n"
        out += "                    var et = inner.read_tag()\n"
        out += "                    var ef = et[0]\n"
        out += "                    var ew = et[1]\n"
        if _is_varint(key.type):
            out += (
                "                    if ef == 1 and ew == WireType.VARINT:\n"
                "                        map_key = "
                + _from_varint(set, file, key, "inner.read_varint()")
                + "\n"
            )
        elif _is_i32(key.type):
            out += (
                "                    if ef == 1 and ew == WireType.I32:\n"
                "                        map_key = "
                + _from_i32(key.type, "inner.read_i32_le()")
                + "\n"
            )
        elif _is_i64(key.type):
            out += (
                "                    if ef == 1 and ew == WireType.I64:\n"
                "                        map_key = "
                + _from_i64(key.type, "inner.read_i64_le()")
                + "\n"
            )
        elif key.type == TYPE_STRING:
            out += (
                "                    if ef == 1 and ew == WireType.LEN:\n"
                "                        map_key = inner.read_string()\n"
            )
        else:
            raise EmitError("unsupported map key type: " + field.name)
        if _is_varint(val.type):
            out += (
                "                    elif ef == 2 and ew == WireType.VARINT:\n"
                "                        map_val = "
                + _from_varint(set, file, val, "inner.read_varint()")
                + "\n"
            )
        elif _is_i32(val.type):
            out += (
                "                    elif ef == 2 and ew == WireType.I32:\n"
                "                        map_val = "
                + _from_i32(val.type, "inner.read_i32_le()")
                + "\n"
            )
        elif _is_i64(val.type):
            out += (
                "                    elif ef == 2 and ew == WireType.I64:\n"
                "                        map_val = "
                + _from_i64(val.type, "inner.read_i64_le()")
                + "\n"
            )
        elif val.type == TYPE_STRING:
            out += (
                "                    elif ef == 2 and ew == WireType.LEN:\n"
                "                        map_val = inner.read_string()\n"
            )
        elif val.type == TYPE_BYTES:
            out += (
                "                    elif ef == 2 and ew == WireType.LEN:\n"
                "                        map_val = inner.read_bytes()\n"
            )
        elif val.type == TYPE_MESSAGE:
            var vt = _elem_type(set, file, val)
            out += (
                "                    elif ef == 2 and ew == WireType.LEN:\n"
                "                        var vin = inner.subreader(inner.read_len_span())\n"
                "                        map_val.merge_from(vin)\n"
            )
            _ = vt
        else:
            raise EmitError("unsupported map value type: " + field.name)
        out += "                    else:\n                        inner.skip_field(ew)\n"
        out += "                self." + fname + "[map_key] = map_val^\n"
        return out
    if field.label == LABEL_REPEATED and _is_varint(field.type):
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.VARINT:\n                self."
            + fname
            + ".append("
            + _from_varint(set, file, field, "dec.read_varint()")
            + ")\n            elif field == "
            + num
            + " and wire == WireType.LEN:\n                var words = List[UInt64]()\n                dec.read_packed_varint(words)\n                for i in range(len(words)):\n                    self."
            + fname
            + ".append("
            + _from_varint(set, file, field, "words[i]")
            + ")\n"
        )
    if field.label == LABEL_REPEATED and _is_i32(field.type):
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.I32:\n                self."
            + fname
            + ".append("
            + _from_i32(field.type, "dec.read_i32_le()")
            + ")\n            elif field == "
            + num
            + " and wire == WireType.LEN:\n                var words = List[UInt32]()\n                dec.read_packed_fixed32(words)\n                for i in range(len(words)):\n                    self."
            + fname
            + ".append("
            + _from_i32(field.type, "words[i]")
            + ")\n"
        )
    if field.label == LABEL_REPEATED and _is_i64(field.type):
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.I64:\n                self."
            + fname
            + ".append("
            + _from_i64(field.type, "dec.read_i64_le()")
            + ")\n            elif field == "
            + num
            + " and wire == WireType.LEN:\n                var words = List[UInt64]()\n                dec.read_packed_fixed64(words)\n                for i in range(len(words)):\n                    self."
            + fname
            + ".append("
            + _from_i64(field.type, "words[i]")
            + ")\n"
        )
    if field.label == LABEL_REPEATED and field.type == TYPE_STRING:
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.LEN:\n                self."
            + fname
            + ".append(dec.read_string())\n"
        )
    if field.label == LABEL_REPEATED and field.type == TYPE_BYTES:
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.LEN:\n                self."
            + fname
            + ".append(dec.read_bytes())\n"
        )
    if field.label == LABEL_REPEATED and field.type == TYPE_MESSAGE:
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.LEN:\n                var inner = dec.subreader(dec.read_len_span())\n                var item = "
            + elem
            + "()\n                item.merge_from(inner)\n                self."
            + fname
            + ".append(item^)\n"
        )
    if _is_real_oneof(field):
        var which = _which_ident(msg, field)
        var reset = _reset_oneof(set, file, msg, field)
        if _is_varint(field.type):
            return (
                "            "
                + kw
                + " field == "
                + num
                + " and wire == WireType.VARINT:\n                self."
                + which
                + " = "
                + num
                + "\n"
                + reset
                + "                self."
                + fname
                + " = "
                + _from_varint(set, file, field, "dec.read_varint()")
                + "\n"
            )
        if _is_i32(field.type):
            return (
                "            "
                + kw
                + " field == "
                + num
                + " and wire == WireType.I32:\n                self."
                + which
                + " = "
                + num
                + "\n"
                + reset
                + "                self."
                + fname
                + " = "
                + _from_i32(field.type, "dec.read_i32_le()")
                + "\n"
            )
        if _is_i64(field.type):
            return (
                "            "
                + kw
                + " field == "
                + num
                + " and wire == WireType.I64:\n                self."
                + which
                + " = "
                + num
                + "\n"
                + reset
                + "                self."
                + fname
                + " = "
                + _from_i64(field.type, "dec.read_i64_le()")
                + "\n"
            )
        if field.type == TYPE_STRING:
            return (
                "            "
                + kw
                + " field == "
                + num
                + " and wire == WireType.LEN:\n                self."
                + which
                + " = "
                + num
                + "\n"
                + reset
                + "                self."
                + fname
                + " = dec.read_string()\n"
            )
        if field.type == TYPE_BYTES:
            return (
                "            "
                + kw
                + " field == "
                + num
                + " and wire == WireType.LEN:\n                self."
                + which
                + " = "
                + num
                + "\n"
                + reset
                + "                self."
                + fname
                + " = dec.read_bytes()\n"
            )
        if field.type == TYPE_MESSAGE:
            return (
                "            "
                + kw
                + " field == "
                + num
                + " and wire == WireType.LEN:\n                self."
                + which
                + " = "
                + num
                + "\n"
                + reset
                + "                var inner = dec.subreader(dec.read_len_span())\n                self."
                + fname
                + " = "
                + elem
                + "()\n                self."
                + fname
                + ".merge_from(inner)\n"
            )
    if field.type == TYPE_MESSAGE:
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.LEN:\n                var inner = dec.subreader(dec.read_len_span())\n                if not self."
            + fname
            + ":\n                    self."
            + fname
            + " = "
            + elem
            + "()\n                self."
            + fname
            + ".value().merge_from(inner)\n"
        )
    var assign: String
    if _is_varint(field.type):
        assign = _from_varint(set, file, field, "dec.read_varint()")
        if field.proto3_optional:
            assign = _assign_optional(assign)
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.VARINT:\n                self."
            + fname
            + " = "
            + assign
            + "\n"
        )
    if _is_i32(field.type):
        assign = _from_i32(field.type, "dec.read_i32_le()")
        if field.proto3_optional:
            assign = _assign_optional(assign)
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.I32:\n                self."
            + fname
            + " = "
            + assign
            + "\n"
        )
    if _is_i64(field.type):
        assign = _from_i64(field.type, "dec.read_i64_le()")
        if field.proto3_optional:
            assign = _assign_optional(assign)
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.I64:\n                self."
            + fname
            + " = "
            + assign
            + "\n"
        )
    if field.type == TYPE_STRING:
        assign = "dec.read_string()"
        if field.proto3_optional:
            assign = _assign_optional(assign)
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.LEN:\n                self."
            + fname
            + " = "
            + assign
            + "\n"
        )
    if field.type == TYPE_BYTES:
        assign = "dec.read_bytes()"
        if field.proto3_optional:
            assign = _assign_optional(assign)
        return (
            "            "
            + kw
            + " field == "
            + num
            + " and wire == WireType.LEN:\n                self."
            + fname
            + " = "
            + assign
            + "\n"
        )
    return String()


def _emit_eq(field: FieldDesc, fname: String) -> String:
    if field.is_map:
        return (
            "        if self."
            + fname
            + " != other."
            + fname
            + ":\n            return False\n"
        )
    if field.label == LABEL_REPEATED:
        return (
            "        if len(self."
            + fname
            + ") != len(other."
            + fname
            + "):\n            return False\n        for i in range(len(self."
            + fname
            + ")):\n            if self."
            + fname
            + "[i] != other."
            + fname
            + "[i]:\n                return False\n"
        )
    if (field.type == TYPE_MESSAGE or field.proto3_optional) and not _is_real_oneof(
        field
    ):
        return (
            "        if Bool(self."
            + fname
            + ") != Bool(other."
            + fname
            + "):\n            return False\n        if self."
            + fname
            + ":\n            if self."
            + fname
            + ".value() != other."
            + fname
            + ".value():\n                return False\n"
        )
    return (
        "        if self."
        + fname
        + " != other."
        + fname
        + ":\n            return False\n"
    )


def emit_enum(enum: EnumDesc, mojo_name: String) -> String:
    var out = String()
    out += "struct "
    out += mojo_name
    out += (
        "(\n    Copyable, Movable, Defaultable, ImplicitlyCopyable, Equatable, Writable\n):\n"
    )
    out += "    var value: Int32\n\n"
    out += "    def __init__(out self):\n        self.value = 0\n\n"
    out += "    def __init__(out self, value: Int32):\n        self.value = value\n\n"
    out += "    def __eq__(self, other: Self) -> Bool:\n        return self.value == other.value\n\n"
    out += (
        "    def write_to[W: Writer](self, mut writer: W):\n        writer.write(\""
        + mojo_name
        + "(\", self.value, \")\")\n"
    )
    for i in range(len(enum.values)):
        out += (
            "\ncomptime "
            + mojo_name
            + "_"
            + enum.values[i].name
            + " = Int32("
            + String(enum.values[i].number)
            + ")\n"
        )
    out += "\n"
    return out


def _real_oneof_indexes(msg: MessageDesc) -> List[Int]:
    var seen = List[Int]()
    for i in range(len(msg.fields)):
        if not _is_real_oneof(msg.fields[i]):
            continue
        var idx = msg.fields[i].oneof_index.value()
        var have = False
        for j in range(len(seen)):
            if seen[j] == idx:
                have = True
        if not have:
            seen.append(idx)
    return seen^


def emit_message(
    set: FileDescSet, file: FileDesc, msg: MessageDesc, preserve: Bool
) raises EmitError -> String:
    var tname: String
    try:
        tname = mojo_type_name(msg.dotted_name())
    except _:
        raise EmitError("type name mapping failed")
    var out = String()
    out += "struct "
    out += tname
    out += "(\n    Copyable, Movable, Defaultable, Deinitable, Writable, Equatable, ProtoMessage\n):\n"
    var oneofs = _real_oneof_indexes(msg)
    for i in range(len(oneofs)):
        var wname = mojo_field_name("which_" + msg.oneofs[oneofs[i]].name)
        out += "    var " + wname + ": Int32\n"
    for i in range(len(msg.fields)):
        if _skip_as_unknown(set, file, msg, msg.fields[i]):
            continue
        _check_field(msg.fields[i])
        var ft = _field_type(set, file, msg.fields[i])
        if _is_real_oneof(msg.fields[i]) and msg.fields[i].type == TYPE_MESSAGE:
            ft = _elem_type(set, file, msg.fields[i])
        out += "    var "
        out += mojo_field_name(msg.fields[i].name)
        out += ": "
        out += ft
        out += "\n"
    if preserve:
        out += "    var unknown: UnknownFieldSet\n"
    out += "\n    def __init__(out self):\n"
    var inited = False
    for i in range(len(oneofs)):
        var wname = mojo_field_name("which_" + msg.oneofs[oneofs[i]].name)
        out += "        self." + wname + " = 0\n"
        inited = True
    for i in range(len(msg.fields)):
        if _skip_as_unknown(set, file, msg, msg.fields[i]):
            continue
        var field_ident = mojo_field_name(msg.fields[i].name)
        var default: String
        if _is_real_oneof(msg.fields[i]) and msg.fields[i].type == TYPE_MESSAGE:
            default = _elem_type(set, file, msg.fields[i]) + "()"
        else:
            default = _default_expr(set, file, msg.fields[i])
        out += "        self." + field_ident + " = " + default + "\n"
        inited = True
    if preserve:
        out += "        self.unknown = UnknownFieldSet()\n"
        inited = True
    if not inited:
        out += "        pass\n"
    out += "\n    def encoded_len(self) -> Int:\n        var n = 0\n"
    for i in range(len(msg.fields)):
        if _skip_as_unknown(set, file, msg, msg.fields[i]):
            continue
        out += _emit_encoded_len(
            set, file, msg, msg.fields[i], mojo_field_name(msg.fields[i].name)
        )
    if preserve:
        out += "        n += self.unknown.encoded_len()\n"
    out += "        return n\n"
    out += "\n    def encode_to(self, mut enc: WireWriter):\n"
    var wrote = False
    for i in range(len(msg.fields)):
        if _skip_as_unknown(set, file, msg, msg.fields[i]):
            continue
        var chunk = _emit_encode(
            set, file, msg, msg.fields[i], mojo_field_name(msg.fields[i].name)
        )
        if chunk.byte_length() != 0:
            wrote = True
        out += chunk
    if preserve:
        out += "        self.unknown.encode_to(enc)\n"
        wrote = True
    if not wrote:
        out += "        pass\n"
    out += "\n    def merge_from[origin: ImmOrigin](mut self, mut dec: WireReader[origin]) raises DecodeError:\n        while dec.remaining() > 0:\n            var tag = dec.read_tag()\n            var field = tag[0]\n            var wire = tag[1]\n"
    var decode_any = False
    for i in range(len(msg.fields)):
        if not _skip_as_unknown(set, file, msg, msg.fields[i]):
            decode_any = True
    if not decode_any:
        if preserve:
            out += "            self.unknown.add(field, wire, dec)\n"
        else:
            out += "            dec.skip_field(wire)\n"
    else:
        var first = True
        for i in range(len(msg.fields)):
            if _skip_as_unknown(set, file, msg, msg.fields[i]):
                continue
            out += _emit_decode(
                set,
                file,
                msg,
                msg.fields[i],
                mojo_field_name(msg.fields[i].name),
                first,
            )
            first = False
        if preserve:
            out += "            else:\n                self.unknown.add(field, wire, dec)\n"
        else:
            out += "            else:\n                dec.skip_field(wire)\n"
    out += "\n    def encode(self) -> List[Byte]:\n        return pb_encode(self)\n\n    @staticmethod\n    def decode[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Self:\n        return pb_decode[Self, origin](buf)\n"
    out += "\n    def __eq__(self, other: Self) -> Bool:\n"
    var eq_any = False
    for i in range(len(oneofs)):
        var wname = mojo_field_name("which_" + msg.oneofs[oneofs[i]].name)
        out += (
            "        if self."
            + wname
            + " != other."
            + wname
            + ":\n            return False\n"
        )
        eq_any = True
    for i in range(len(msg.fields)):
        if _skip_as_unknown(set, file, msg, msg.fields[i]):
            continue
        out += _emit_eq(msg.fields[i], mojo_field_name(msg.fields[i].name))
        eq_any = True
    if preserve:
        out += "        if self.unknown != other.unknown:\n            return False\n"
        eq_any = True
    if eq_any:
        out += "        return True\n"
    else:
        out += "        return True\n"
    out += "\n    def write_to[W: Writer](self, mut writer: W):\n        writer.write(\""
    out += tname
    out += "()\")\n"
    return out


def _maybe_import(mut imports: List[String], line: String):
    for i in range(len(imports)):
        if imports[i] == line:
            return
    imports.append(line)


def _collect_field_import(
    set: FileDescSet, file: FileDesc, field: FieldDesc, mut imports: List[String]
) raises EmitError:
    if field.type != TYPE_MESSAGE and field.type != TYPE_ENUM:
        return
    if field.is_map:
        return
    var resolved = _resolve(set, file, field.type_name)
    if resolved.ok and resolved.import_pkg.byte_length() != 0:
        _maybe_import(
            imports,
            "from " + resolved.import_pkg + " import " + resolved.mojo_name + "\n",
        )


def emit_file(set: FileDescSet, file: FileDesc, preserve: Bool = True) raises EmitError -> String:
    var gate = proto3_error(file)
    if gate.byte_length() != 0:
        raise EmitError(gate)
    var out = String()
    out += "from std.collections import Dict, List, Optional, Span\n"
    out += "from protobuf import (\n"
    out += "    DecodeError,\n    ProtoMessage,\n    UnknownFieldSet,\n"
    out += "    WireReader,\n    WireType,\n    WireWriter,\n"
    out += "    decode as pb_decode,\n    encode as pb_encode,\n"
    out += "    i32_to_u64,\n    i64_to_u64,\n"
    out += "    tag_fixed32_len,\n    tag_fixed64_len,\n    tag_len_len,\n    tag_varint_len,\n"
    out += "    u64_to_i32,\n    u64_to_i64,\n    varint_len,\n"
    out += "    zigzag_decode_i32,\n    zigzag_decode_i64,\n"
    out += "    zigzag_encode_i32,\n    zigzag_encode_i64,\n)\n\n"
    var imports = List[String]()
    for i in range(len(file.messages)):
        for j in range(len(file.messages[i].fields)):
            var f = file.messages[i].fields[j]
            if f.is_map:
                var kv = _map_entry_kv(set, file, f)
                _collect_field_import(set, file, kv[0], imports)
                _collect_field_import(set, file, kv[1], imports)
            else:
                _collect_field_import(set, file, f, imports)
    for i in range(len(imports)):
        out += imports[i]
    if len(imports) != 0:
        out += "\n"
    for i in range(len(file.enums)):
        var ename: String
        try:
            ename = mojo_type_name(file.enums[i].name)
        except _:
            raise EmitError("enum name mapping failed")
        out += emit_enum(file.enums[i], ename)
    for i in range(len(file.messages)):
        if file.messages[i].map_entry:
            continue
        for j in range(len(file.messages[i].enums)):
            var nested = file.messages[i].dotted_name() + "." + file.messages[i].enums[j].name
            var nname: String
            try:
                nname = mojo_type_name(nested)
            except _:
                raise EmitError("enum name mapping failed")
            out += emit_enum(file.messages[i].enums[j], nname)
        out += emit_message(set, file, file.messages[i], preserve)
        out += "\n"
    return out


def output_path(out_dir: String, module_prefix: String, package: String, stem: String) raises -> String:
    var path = out_dir
    if module_prefix.byte_length() != 0:
        path += "/" + module_prefix
    if package.byte_length() != 0:
        var buf = List[Byte]()
        for i in range(package.byte_length()):
            var b = package.as_bytes()[i]
            if b == Byte(ord(".")):
                buf.append(Byte(ord("/")))
            else:
                buf.append(b)
        path += "/" + String(from_utf8=buf)
    var file_stem_name: String
    try:
        file_stem_name = safe_stem(stem + ".proto")
    except _:
        file_stem_name = stem
    path += "/" + file_stem_name + ".mojo"
    return path


def stem_of(path: String) raises -> String:
    var start = 0
    var end = path.byte_length()
    for i in range(path.byte_length()):
        if path.as_bytes()[i] == Byte(ord("/")):
            start = i + 1
    if end >= 6:
        var looks = True
        var suf = String(".proto")
        for i in range(6):
            if path.as_bytes()[end - 6 + i] != suf.as_bytes()[i]:
                looks = False
        if looks:
            end = end - 6
    var buf = List[Byte]()
    var i = start
    while i < end:
        buf.append(path.as_bytes()[i])
        i += 1
    return String(from_utf8=buf)
