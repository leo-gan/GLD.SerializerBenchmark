from std.collections import List

from fb_schema.finish import normalize_schema
from fb_schema.fbs import read_file_bytes
from fb_schema.model import (
    EnumDef,
    EnumVal,
    FieldDef,
    ObjectDef,
    Schema,
    TypeRef,
)
from fb_wire.scalar import int_from_i32
from fb_wire.reader import (
    indirect_field,
    read_bool_field,
    read_f64_field,
    read_i32_field,
    read_i64_field,
    read_string_field,
    read_u16_field,
    read_u8_field,
    root_pos,
    vector_len,
    vector_offset_at,
)


def parse_bfbs_file(path: String) raises -> Schema:
    return parse_bfbs(read_file_bytes(path))


def parse_bfbs(data: List[Byte]) raises -> Schema:
    """Decode a flatc binary schema. The bytes are a reflection.Schema table."""
    var schema = Schema()
    var root = root_pos(data, False)
    var objects = indirect_field(data, root, 0)
    if objects < 0:
        raise Error("bfbs has no objects")
    var nobj = vector_len(data, objects)
    for i in range(nobj):
        schema.objects.append(_object(data, vector_offset_at(data, objects, i)))
    var enums = indirect_field(data, root, 1)
    if enums >= 0:
        var n = vector_len(data, enums)
        for i in range(n):
            schema.enums.append(_enum(data, vector_offset_at(data, enums, i)))
    var ident = indirect_field(data, root, 2)
    if ident >= 0:
        schema.file_ident = read_string_field(data, root, 2)
    var ext = indirect_field(data, root, 3)
    if ext >= 0:
        schema.file_ext = read_string_field(data, root, 3)
    var root_obj = indirect_field(data, root, 4)
    if root_obj >= 0:
        schema.root_name = read_string_field(data, root_obj, 0)
    normalize_schema(schema)
    return schema^


def _object(data: List[Byte], pos: Int) raises -> ObjectDef:
    var obj = ObjectDef()
    obj.name = read_string_field(data, pos, 0)
    obj.is_struct = read_bool_field(data, pos, 2, False)
    obj.minalign = int_from_i32(read_i32_field(data, pos, 3, 1))
    obj.bytesize = int_from_i32(read_i32_field(data, pos, 4, 0))
    obj.laid_out = obj.is_struct
    var fields = indirect_field(data, pos, 1)
    if fields < 0:
        raise Error("bfbs object fields")
    var n = vector_len(data, fields)
    for i in range(n):
        obj.fields.append(_field(data, vector_offset_at(data, fields, i)))
    return obj^


def _field(data: List[Byte], pos: Int) raises -> FieldDef:
    var field = FieldDef()
    field.name = read_string_field(data, pos, 0)
    var ty_pos = indirect_field(data, pos, 1)
    if ty_pos < 0:
        raise Error("bfbs field type")
    field.ty = _type(data, ty_pos)
    field.id = Int(read_u16_field(data, pos, 2, 0))
    field.offset = Int(read_u16_field(data, pos, 3, 0))
    field.default_int = read_i64_field(data, pos, 4, 0)
    field.default_real = read_f64_field(data, pos, 5, 0.0)
    field.deprecated = read_bool_field(data, pos, 6, False)
    field.required = read_bool_field(data, pos, 7, False)
    field.optional = read_bool_field(data, pos, 11, False)
    field.padding = Int(read_u16_field(data, pos, 12, 0))
    field.has_id = True
    if read_bool_field(data, pos, 13, False):
        raise Error("64-bit offsets are not supported")
    return field^


def _type(data: List[Byte], pos: Int) raises -> TypeRef:
    var ty = TypeRef()
    ty.base = Int(read_u8_field(data, pos, 0, 0))
    ty.element = Int(read_u8_field(data, pos, 1, 0))
    ty.index = int_from_i32(read_i32_field(data, pos, 2, -1))
    return ty


def _enum(data: List[Byte], pos: Int) raises -> EnumDef:
    var en = EnumDef()
    en.name = read_string_field(data, pos, 0)
    en.is_union = read_bool_field(data, pos, 2, False)
    var under = indirect_field(data, pos, 3)
    if under < 0:
        raise Error("bfbs enum type")
    en.underlying = Int(read_u8_field(data, under, 0, 0))
    var values = indirect_field(data, pos, 1)
    if values < 0:
        raise Error("bfbs enum values")
    var n = vector_len(data, values)
    for i in range(n):
        en.values.append(_enum_val(data, vector_offset_at(data, values, i)))
    return en^


def _enum_val(data: List[Byte], pos: Int) raises -> EnumVal:
    var val = EnumVal()
    val.name = read_string_field(data, pos, 0)
    val.value = read_i64_field(data, pos, 1, 0)
    var ut = indirect_field(data, pos, 3)
    if ut >= 0:
        val.union_object = int_from_i32(read_i32_field(data, ut, 2, -1))
    return val^
