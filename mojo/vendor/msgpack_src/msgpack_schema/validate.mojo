from msgpack_runtime.value import (
    CK_ARRAY,
    CK_BIN,
    CK_BOOL,
    CK_EXT,
    CK_F32,
    CK_F64,
    CK_INT,
    CK_MAP,
    CK_NIL,
    CK_STR,
    CK_TIMESTAMP,
    CK_UINT,
    MsgpackValue,
)
from msgpack_schema.model import (
    ST_ARRAY,
    ST_BOOL,
    ST_BYTES,
    ST_EXT,
    ST_INT,
    ST_NULL,
    ST_NUMBER,
    ST_OBJECT,
    ST_OPTIONAL,
    ST_REF,
    ST_STRING,
    ST_TIMESTAMP,
    SchemaDoc,
    SchemaType,
)


comptime VK_OK = 0
comptime VK_TYPE = 1
comptime VK_REQUIRED = 2


struct ValidationResult(Copyable, ImplicitlyCopyable):
    var code: Int
    var path: String

    def __init__(out self, code: Int = 0, path: String = ""):
        self.code = code
        self.path = path


def is_valid(instance: MsgpackValue, schema: SchemaDoc) -> Bool:
    return validate(instance, schema).code == VK_OK


def validate(instance: MsgpackValue, schema: SchemaDoc) -> ValidationResult:
    return _check(instance, schema, schema.root, "")


def _unwrap(schema: SchemaDoc, tid: Int) -> SchemaType:
    var t = schema.types[tid].copy()
    while t.kind == ST_REF or t.kind == ST_OPTIONAL:
        if t.inner < 0:
            break
        t = schema.types[t.inner].copy()
    return t^


def _check(
    instance: MsgpackValue, schema: SchemaDoc, tid: Int, path: String
) -> ValidationResult:
    var t = schema.types[tid].copy()
    if t.kind == ST_OPTIONAL:
        if instance.kind() == CK_NIL:
            return ValidationResult()
        return _check(instance, schema, t.inner, path)
    if t.kind == ST_REF:
        return _check(instance, schema, t.inner, path)
    t = _unwrap(schema, tid)
    var k = instance.kind()
    if t.kind == ST_NULL:
        if k != CK_NIL:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_BOOL:
        if k != CK_BOOL:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_INT:
        if k != CK_INT and k != CK_UINT:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_NUMBER:
        if k != CK_INT and k != CK_UINT and k != CK_F32 and k != CK_F64:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_STRING:
        if k != CK_STR:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_BYTES:
        if k != CK_BIN:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_EXT:
        if k != CK_EXT:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_TIMESTAMP:
        if k != CK_TIMESTAMP:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_ARRAY:
        if k != CK_ARRAY:
            return ValidationResult(VK_TYPE, path)
        var i = 0
        while i < instance.count():
            try:
                var child = instance.at(i)
                var r = _check(child, schema, t.inner, path)
                if r.code != VK_OK:
                    return r
            except _:
                return ValidationResult(VK_TYPE, path)
            i += 1
        return ValidationResult()
    if t.kind == ST_OBJECT:
        if k != CK_MAP:
            return ValidationResult(VK_TYPE, path)
        var j = 0
        while j < len(t.props):
            var p = t.props[j].copy()
            if p.required:
                try:
                    _ = instance.get(p.name)
                except _:
                    return ValidationResult(VK_REQUIRED, p.name)
            j += 1
        return ValidationResult()
    return ValidationResult()
