from std.collections import List

from gldjson_runtime.error import DecodeError
from gldjson_runtime.patch import json_equal
from gldjson_runtime.pointer import pointer_set
from gldjson_runtime.value import JsonValue, json_null, json_object


def merge_patch(target: JsonValue, patch: JsonValue) raises DecodeError -> JsonValue:
    if not patch.is_object():
        return pointer_set(patch, "", patch)
    if not target.is_object():
        return _merge_into(json_object(List[Tuple[String, JsonValue]]()), patch)
    return _merge_into(target, patch)


def _merge_into(target: JsonValue, patch: JsonValue) raises DecodeError -> JsonValue:
    var cur = pointer_set(target, "", target)
    var i = 0
    while i < patch.count():
        var p = patch.pair(i)
        var key = p[0]
        if p[1].is_null():
            cur = _delete_obj_key(cur, key)
        elif p[1].is_object():
            var child: JsonValue
            try:
                child = cur.get(key)
            except _:
                child = json_object(List[Tuple[String, JsonValue]]())
            if not child.is_object():
                child = json_object(List[Tuple[String, JsonValue]]())
            cur = pointer_set(cur, "/" + _escape_ptr(key), _merge_into(child, p[1]))
        else:
            cur = pointer_set(cur, "/" + _escape_ptr(key), p[1])
        i += 1
    return cur^


def _delete_obj_key(doc: JsonValue, key: String) raises DecodeError -> JsonValue:
    var pairs = List[Tuple[String, JsonValue]]()
    var i = 0
    while i < doc.count():
        var p = doc.pair(i)
        if p[0] != key:
            pairs.append(p^)
        i += 1
    return json_object(pairs)


def _escape_ptr(key: String) -> String:
    var out = String()
    var b = key.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 126:
            out += "~0"
        elif c == 47:
            out += "~1"
        else:
            try:
                out += String(from_utf8=b[i : i + 1])
            except _:
                pass
        i += 1
    return out


def create_merge_patch(source: JsonValue, target: JsonValue) -> JsonValue:
    if not source.is_object() or not target.is_object():
        try:
            return pointer_set(target, "", target)
        except _:
            return json_null()
    var pairs = List[Tuple[String, JsonValue]]()
    var i = 0
    while i < source.count():
        try:
            var p = source.pair(i)
            try:
                var tv = target.get(p[0])
                if p[1].is_object() and tv.is_object():
                    var child = create_merge_patch(p[1], tv)
                    if child.is_object() and child.count() == 0:
                        pass
                    else:
                        pairs.append((p[0], child))
                elif not json_equal(p[1], tv):
                    pairs.append((p[0], pointer_set(tv, "", tv)))
            except _:
                pairs.append((p[0], json_null()))
        except _:
            pass
        i += 1
    i = 0
    while i < target.count():
        try:
            var p = target.pair(i)
            try:
                _ = source.get(p[0])
            except _:
                pairs.append((p[0], pointer_set(p[1], "", p[1])))
        except _:
            pass
        i += 1
    return json_object(pairs)
