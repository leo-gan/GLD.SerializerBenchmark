from std.collections import List

from fb_schema.model import (
    BT_OBJ,
    BT_UNION,
    BT_UTYPE,
    BT_VECTOR,
    EnumDef,
    EnumVal,
    FieldDef,
    ObjectDef,
    Schema,
    TypeRef,
    is_scalar,
    scalar_size,
)


def finish_fbs(mut schema: Schema) raises:
    _resolve_all(schema)
    _expand_unions(schema)
    _defaults(schema)
    _mark_references(schema)
    _layout_structs(schema)
    normalize_schema(schema)


def normalize_schema(mut schema: Schema) raises:
    _sort_enums(schema)
    _sort_objects(schema)
    _sort_members(schema)
    if schema.root_name.byte_length() != 0:
        schema.root = schema.find_object(schema.root_name)
    elif schema.root >= 0:
        schema.root_name = schema.objects[schema.root].name


def _resolve_all(mut schema: Schema) raises:
    for oi in range(len(schema.objects)):
        for fi in range(len(schema.objects[oi].fields)):
            var ty = schema.objects[oi].fields[fi].ty
            _resolve_type(schema, ty)
            schema.objects[oi].fields[fi].ty = ty


def _resolve_type(schema: Schema, mut ty: TypeRef) raises:
    if ty.base == BT_VECTOR:
        if ty.element == 0 and ty.type_name.byte_length() != 0:
            var oi = schema.find_object(ty.type_name)
            if oi >= 0:
                ty.element = BT_OBJ
                ty.index = oi
                return
            var ei = schema.find_enum(ty.type_name)
            if ei < 0:
                raise Error("unknown type " + ty.type_name)
            ty.element = schema.enums[ei].underlying
            ty.index = ei
        return
    if ty.base != 0 or ty.type_name.byte_length() == 0:
        return
    var oi = schema.find_object(ty.type_name)
    if oi >= 0:
        ty.base = BT_OBJ
        ty.index = oi
        return
    var ei = schema.find_enum(ty.type_name)
    if ei < 0:
        raise Error("unknown type " + ty.type_name)
    ty.index = ei
    if schema.enums[ei].is_union:
        ty.base = BT_UNION
    else:
        ty.base = schema.enums[ei].underlying


def _expand_unions(mut schema: Schema) raises:
    for oi in range(len(schema.objects)):
        if schema.objects[oi].is_struct:
            for fi in range(len(schema.objects[oi].fields)):
                if not schema.objects[oi].fields[fi].has_id:
                    schema.objects[oi].fields[fi].id = fi
                    schema.objects[oi].fields[fi].has_id = True
            continue
        var rebuilt = List[FieldDef]()
        var next = 0
        var count = len(schema.objects[oi].fields)
        for fi in range(count):
            var field = _copy_field(schema.objects[oi].fields[fi])
            if field.has_id:
                next = field.id
            if field.ty.base == BT_UNION:
                var tag = FieldDef()
                tag.name = field.name + "_type"
                tag.ty.base = BT_UTYPE
                tag.ty.index = field.ty.index
                tag.id = next
                tag.has_id = True
                next += 1
                rebuilt.append(tag^)
                field.id = next
                field.has_id = True
                field.optional = True
                next += 1
                rebuilt.append(field^)
            else:
                field.id = next
                field.has_id = True
                next += 1
                rebuilt.append(field^)
        schema.objects[oi].fields = rebuilt^


def _defaults(mut schema: Schema) raises:
    for oi in range(len(schema.objects)):
        for fi in range(len(schema.objects[oi].fields)):
            var name = schema.objects[oi].fields[fi].default_name
            if name.byte_length() == 0:
                continue
            var ei = schema.objects[oi].fields[fi].ty.index
            if ei < 0 or ei >= len(schema.enums):
                raise Error("bad enum default")
            var found = False
            for vi in range(len(schema.enums[ei].values)):
                if schema.enums[ei].values[vi].name == name:
                    schema.objects[oi].fields[fi].default_int = schema.enums[ei].values[vi].value
                    found = True
            if not found:
                raise Error("unknown enum value " + name)
    for ei in range(len(schema.enums)):
        if not schema.enums[ei].is_union:
            continue
        for vi in range(len(schema.enums[ei].values)):
            var uname = schema.enums[ei].values[vi].union_name
            if uname.byte_length() == 0:
                schema.enums[ei].values[vi].union_object = -1
            else:
                schema.enums[ei].values[vi].union_object = schema.find_object(uname)


def _mark_references(mut schema: Schema):
    for oi in range(len(schema.objects)):
        if schema.objects[oi].is_struct:
            continue
        for fi in range(len(schema.objects[oi].fields)):
            var base = schema.objects[oi].fields[fi].ty.base
            if not is_scalar(base):
                schema.objects[oi].fields[fi].optional = True


def _layout_structs(mut schema: Schema) raises:
    var guard = 0
    while True:
        var pending = 0
        var progress = False
        for oi in range(len(schema.objects)):
            if not schema.objects[oi].is_struct or schema.objects[oi].laid_out:
                continue
            var ready = True
            for fi in range(len(schema.objects[oi].fields)):
                var ty = schema.objects[oi].fields[fi].ty
                if ty.base == BT_OBJ and not schema.objects[ty.index].laid_out:
                    ready = False
            if not ready:
                pending += 1
                continue
            _layout_one(schema, oi)
            progress = True
        if pending == 0:
            return
        if not progress or guard > len(schema.objects):
            raise Error("struct cycle")
        guard += 1


def _layout_one(mut schema: Schema, oi: Int):
    var cursor = 0
    var max_align = 1
    var n = len(schema.objects[oi].fields)
    for fi in range(n):
        var al = _align_of(schema, schema.objects[oi].fields[fi])
        var sz = _size_of(schema, schema.objects[oi].fields[fi])
        if al < 1:
            al = 1
        if al > max_align:
            max_align = al
        cursor += (-cursor) & (al - 1)
        schema.objects[oi].fields[fi].offset = cursor
        cursor += sz
    var trailing = (-cursor) & (max_align - 1)
    var total = cursor + trailing
    for fi in range(n):
        var sz = _size_of(schema, schema.objects[oi].fields[fi])
        var end = schema.objects[oi].fields[fi].offset + sz
        var nxt = total
        if fi + 1 < n:
            nxt = schema.objects[oi].fields[fi + 1].offset
        schema.objects[oi].fields[fi].padding = nxt - end
    schema.objects[oi].bytesize = total
    schema.objects[oi].minalign = max_align
    schema.objects[oi].laid_out = True


def _size_of(schema: Schema, field: FieldDef) -> Int:
    if is_scalar(field.ty.base):
        return scalar_size(field.ty.base)
    if field.ty.base == BT_OBJ:
        return schema.objects[field.ty.index].bytesize
    return 0


def _align_of(schema: Schema, field: FieldDef) -> Int:
    if is_scalar(field.ty.base):
        var sz = scalar_size(field.ty.base)
        if sz == 0:
            return 1
        return sz
    if field.ty.base == BT_OBJ:
        return schema.objects[field.ty.index].minalign
    return 1


def _sort_objects(mut schema: Schema):
    var n = len(schema.objects)
    var order = List[Int]()
    var map = List[Int]()
    for i in range(n):
        order.append(i)
        map.append(0)
    for a in range(n):
        var best = a
        for b in range(a + 1, n):
            if schema.objects[order[b]].name < schema.objects[order[best]].name:
                best = b
        if best != a:
            var tmp = order[a]
            order[a] = order[best]
            order[best] = tmp
    for new_i in range(n):
        map[order[new_i]] = new_i
    var fresh = List[ObjectDef]()
    for new_i in range(n):
        fresh.append(_clone_object(schema.objects[order[new_i]]))
    schema.objects = fresh^
    _remap_objects(schema, map)
    if schema.root >= 0 and schema.root < n:
        schema.root = map[schema.root]


def _remap_objects(mut schema: Schema, map: List[Int]):
    for oi in range(len(schema.objects)):
        for fi in range(len(schema.objects[oi].fields)):
            var base = schema.objects[oi].fields[fi].ty.base
            var elem = schema.objects[oi].fields[fi].ty.element
            var index = schema.objects[oi].fields[fi].ty.index
            if index < 0:
                continue
            if base == BT_OBJ or (base == BT_VECTOR and elem == BT_OBJ):
                schema.objects[oi].fields[fi].ty.index = map[index]
    for ei in range(len(schema.enums)):
        for vi in range(len(schema.enums[ei].values)):
            var uo = schema.enums[ei].values[vi].union_object
            if uo >= 0:
                schema.enums[ei].values[vi].union_object = map[uo]


def _sort_enums(mut schema: Schema):
    var n = len(schema.enums)
    var order = List[Int]()
    var map = List[Int]()
    for i in range(n):
        order.append(i)
        map.append(0)
    for a in range(n):
        var best = a
        for b in range(a + 1, n):
            if schema.enums[order[b]].name < schema.enums[order[best]].name:
                best = b
        if best != a:
            var tmp = order[a]
            order[a] = order[best]
            order[best] = tmp
    for new_i in range(n):
        map[order[new_i]] = new_i
    var fresh = List[EnumDef]()
    for new_i in range(n):
        fresh.append(_clone_enum(schema.enums[order[new_i]]))
    schema.enums = fresh^
    for oi in range(len(schema.objects)):
        for fi in range(len(schema.objects[oi].fields)):
            var base = schema.objects[oi].fields[fi].ty.base
            var elem = schema.objects[oi].fields[fi].ty.element
            var index = schema.objects[oi].fields[fi].ty.index
            if index < 0:
                continue
            if base == BT_UNION or base == BT_UTYPE:
                schema.objects[oi].fields[fi].ty.index = map[index]
            elif base == BT_VECTOR and is_scalar(elem):
                schema.objects[oi].fields[fi].ty.index = map[index]
            elif is_scalar(base):
                schema.objects[oi].fields[fi].ty.index = map[index]


def _sort_members(mut schema: Schema):
    for oi in range(len(schema.objects)):
        var n = len(schema.objects[oi].fields)
        for a in range(n):
            var best = a
            for b in range(a + 1, n):
                if schema.objects[oi].fields[b].id < schema.objects[oi].fields[best].id:
                    best = b
            if best != a:
                var tmp = _copy_field(schema.objects[oi].fields[a])
                schema.objects[oi].fields[a] = _copy_field(schema.objects[oi].fields[best])
                schema.objects[oi].fields[best] = tmp^
    for ei in range(len(schema.enums)):
        var n = len(schema.enums[ei].values)
        for a in range(n):
            var best = a
            for b in range(a + 1, n):
                if schema.enums[ei].values[b].value < schema.enums[ei].values[best].value:
                    best = b
            if best != a:
                var tmp = _copy_val(schema.enums[ei].values[a])
                schema.enums[ei].values[a] = _copy_val(schema.enums[ei].values[best])
                schema.enums[ei].values[best] = tmp^


def _clone_object(obj: ObjectDef) -> ObjectDef:
    var out = ObjectDef()
    out.name = obj.name
    out.is_struct = obj.is_struct
    out.minalign = obj.minalign
    out.bytesize = obj.bytesize
    out.laid_out = obj.laid_out
    for i in range(len(obj.fields)):
        out.fields.append(_copy_field(obj.fields[i]))
    return out^


def _clone_enum(en: EnumDef) -> EnumDef:
    var out = EnumDef()
    out.name = en.name
    out.is_union = en.is_union
    out.underlying = en.underlying
    for i in range(len(en.values)):
        out.values.append(_copy_val(en.values[i]))
    return out^


def _copy_field(field: FieldDef) -> FieldDef:
    var out = FieldDef()
    out.name = field.name
    out.ty = field.ty
    out.id = field.id
    out.offset = field.offset
    out.default_int = field.default_int
    out.default_real = field.default_real
    out.deprecated = field.deprecated
    out.required = field.required
    out.optional = field.optional
    out.padding = field.padding
    out.has_id = field.has_id
    out.default_name = field.default_name
    return out^


def _copy_val(val: EnumVal) -> EnumVal:
    var out = EnumVal()
    out.name = val.name
    out.value = val.value
    out.union_object = val.union_object
    out.union_name = val.union_name
    return out^
