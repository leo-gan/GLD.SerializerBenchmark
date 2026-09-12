from yaml_runtime.value import (
    YK_BINARY,
    YK_FALSE,
    YK_FLOAT,
    YK_INT,
    YK_MAP,
    YK_NULL,
    YK_SEQ,
    YK_STRING,
    YK_TRUE,
    YamlValue,
)
from yaml_schema.model import (
    ST_ARRAY,
    ST_BOOL,
    ST_BYTES,
    ST_INT,
    ST_NULL,
    ST_NUMBER,
    ST_OBJECT,
    ST_OPTIONAL,
    ST_REF,
    ST_STRING,
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


def is_valid(instance: YamlValue, schema: SchemaDoc) -> Bool:
    return validate(instance, schema).code == VK_OK


def validate(instance: YamlValue, schema: SchemaDoc) -> ValidationResult:
    return _check(instance, schema, schema.root, "")


def _unwrap(schema: SchemaDoc, tid: Int) -> SchemaType:
    var t = schema.types[tid].copy()
    while t.kind == ST_REF or t.kind == ST_OPTIONAL:
        if t.inner < 0:
            break
        t = schema.types[t.inner].copy()
    return t^


def _check(
    instance: YamlValue, schema: SchemaDoc, tid: Int, path: String
) -> ValidationResult:
    var t = schema.types[tid].copy()
    if t.kind == ST_OPTIONAL:
        if instance.kind() == YK_NULL:
            return ValidationResult()
        return _check(instance, schema, t.inner, path)
    if t.kind == ST_REF:
        return _check(instance, schema, t.inner, path)
    t = _unwrap(schema, tid)
    var k = instance.kind()
    if t.kind == ST_NULL:
        if k != YK_NULL:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_BOOL:
        if k != YK_TRUE and k != YK_FALSE:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_INT:
        if k != YK_INT:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_NUMBER:
        if k != YK_INT and k != YK_FLOAT:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_STRING:
        if k != YK_STRING:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_BYTES:
        if k != YK_BINARY and k != YK_STRING:
            return ValidationResult(VK_TYPE, path)
        return ValidationResult()
    if t.kind == ST_ARRAY:
        if k != YK_SEQ:
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
        if k != YK_MAP:
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
