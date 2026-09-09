from gldjson_runtime.error import DecodeError
from gldjson_runtime.value import JsonValue
from gldjson_schema.model import (
    ST_ARRAY,
    ST_BOOL,
    ST_CONST,
    ST_ENUM,
    ST_INT,
    ST_NULL,
    ST_NUMBER,
    ST_OBJECT,
    ST_OPTIONAL,
    ST_REF,
    ST_STRING,
    ST_UNION,
    SchemaDoc,
)


comptime VK_OK = 0
comptime VK_TYPE = 1
comptime VK_REQUIRED = 2
comptime VK_ENUM = 3
comptime VK_CONST = 4
comptime VK_ITEMS = 5


struct ValidationResult(Copyable, ImplicitlyCopyable):
    var path: String
    var kind: Int

    def __init__(out self, path: String = "", kind: Int = 0):
        self.path = path
        self.kind = kind

    def ok(self) -> Bool:
        return self.kind == VK_OK


def is_valid(doc: SchemaDoc, inst: JsonValue) -> Bool:
    return validate(doc, inst).ok()


def validate(doc: SchemaDoc, inst: JsonValue) -> ValidationResult:
    return _check(doc, doc.root, inst, String())


def _check(doc: SchemaDoc, tid: Int, inst: JsonValue, path: String) -> ValidationResult:
    var ty = doc.types[tid].copy()
    if ty.kind == ST_REF:
        return _check(doc, ty.inner, inst, path)
    if ty.kind == ST_OPTIONAL:
        if inst.is_null():
            return ValidationResult(path, VK_OK)
        return _check(doc, ty.inner, inst, path)
    if ty.kind == ST_NULL:
        if inst.is_null():
            return ValidationResult(path, VK_OK)
        return ValidationResult(path, VK_TYPE)
    if ty.kind == ST_BOOL:
        if inst.is_bool():
            return ValidationResult(path, VK_OK)
        return ValidationResult(path, VK_TYPE)
    if ty.kind == ST_INT:
        if inst.is_int():
            return ValidationResult(path, VK_OK)
        return ValidationResult(path, VK_TYPE)
    if ty.kind == ST_NUMBER:
        if inst.is_int() or inst.is_float():
            return ValidationResult(path, VK_OK)
        return ValidationResult(path, VK_TYPE)
    if ty.kind == ST_STRING:
        if inst.is_string():
            return ValidationResult(path, VK_OK)
        return ValidationResult(path, VK_TYPE)
    if ty.kind == ST_ARRAY:
        if not inst.is_array():
            return ValidationResult(path, VK_TYPE)
        var i = 0
        while i < inst.count():
            try:
                var r = _check(doc, ty.inner, inst.at(i), path)
                if not r.ok():
                    return ValidationResult(path, VK_ITEMS)
            except _:
                return ValidationResult(path, VK_ITEMS)
            i += 1
        return ValidationResult(path, VK_OK)
    if ty.kind == ST_OBJECT:
        if not inst.is_object():
            return ValidationResult(path, VK_TYPE)
        var i = 0
        while i < len(ty.props):
            var p = ty.props[i].copy()
            var present = True
            var child = JsonValue()
            try:
                child = inst.get(p.name)
            except _:
                present = False
            if p.required and not present:
                return ValidationResult(path, VK_REQUIRED)
            if present:
                var r = _check(doc, p.type_id, child, path)
                if not r.ok():
                    return r
            i += 1
        return ValidationResult(path, VK_OK)
    if ty.kind == ST_UNION:
        var i = 0
        while i < len(ty.branch_ids):
            var r = _check(doc, ty.branch_ids[i], inst, path)
            if r.ok():
                return r
            i += 1
        return ValidationResult(path, VK_TYPE)
    if ty.kind == ST_ENUM:
        if len(ty.enum_strings) > 0:
            try:
                var s = inst.as_str()
                var i = 0
                while i < len(ty.enum_strings):
                    if ty.enum_strings[i] == s:
                        return ValidationResult(path, VK_OK)
                    i += 1
            except _:
                return ValidationResult(path, VK_ENUM)
            return ValidationResult(path, VK_ENUM)
        try:
            var n = inst.as_int()
            var i = 0
            while i < len(ty.enum_ints):
                if ty.enum_ints[i] == n:
                    return ValidationResult(path, VK_OK)
                i += 1
        except _:
            return ValidationResult(path, VK_ENUM)
        return ValidationResult(path, VK_ENUM)
    if ty.kind == ST_CONST:
        if ty.const_kind == ST_STRING:
            try:
                if inst.as_str() == ty.const_str:
                    return ValidationResult(path, VK_OK)
            except _:
                pass
            return ValidationResult(path, VK_CONST)
        if ty.const_kind == ST_INT:
            try:
                if inst.as_int() == ty.const_int:
                    return ValidationResult(path, VK_OK)
            except _:
                pass
            return ValidationResult(path, VK_CONST)
        try:
            if inst.as_bool() == ty.const_bool:
                return ValidationResult(path, VK_OK)
        except _:
            pass
        return ValidationResult(path, VK_CONST)
    return ValidationResult(path, VK_TYPE)
