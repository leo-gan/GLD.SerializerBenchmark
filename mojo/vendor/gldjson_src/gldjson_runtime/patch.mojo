from std.collections import List

from gldjson_runtime.error import DecodeError
from gldjson_runtime.pointer import _array_index, _split, pointer_get, pointer_set
from gldjson_runtime.value import JsonValue, json_array, json_object, json_null


def apply_patch(doc: JsonValue, patch: JsonValue) raises DecodeError -> JsonValue:
    if not patch.is_array():
        raise DecodeError(DecodeError.KIND_PATCH, 0)
    var cur = pointer_set(doc, "", doc)
    var i = 0
    while i < patch.count():
        var op = patch.at(i)
        if not op.is_object():
            raise DecodeError(DecodeError.KIND_PATCH, 0)
        var name = op.get("op").as_str()
        var path = op.get("path").as_str()
        if name == "add":
            cur = _add(cur, path, op.get("value"))
        elif name == "remove":
            cur = _remove(cur, path)
        elif name == "replace":
            cur = _replace(cur, path, op.get("value"))
        elif name == "move":
            cur = _move(cur, path, op.get("from").as_str())
        elif name == "copy":
            cur = _copy_op(cur, path, op.get("from").as_str())
        elif name == "test":
            _test(cur, path, op.get("value"))
        else:
            raise DecodeError(DecodeError.KIND_PATCH, 0)
        i += 1
    return cur^


def _add(doc: JsonValue, path: String, value: JsonValue) raises DecodeError -> JsonValue:
    if path.byte_length() == 0:
        return pointer_set(doc, "", value)
    return _insert(doc, path, value, True)


def _replace(doc: JsonValue, path: String, value: JsonValue) raises DecodeError -> JsonValue:
    if path.byte_length() == 0:
        return pointer_set(doc, "", value)
    _ = pointer_get(doc, path)
    return pointer_set(doc, path, value)


def _remove(doc: JsonValue, path: String) raises DecodeError -> JsonValue:
    if path.byte_length() == 0:
        raise DecodeError(DecodeError.KIND_PATCH, 0)
    _ = pointer_get(doc, path)
    return _delete(doc, path)


def _move(doc: JsonValue, path: String, src: String) raises DecodeError -> JsonValue:
    if _is_prefix(src, path):
        raise DecodeError(DecodeError.KIND_PATCH, 0)
    var val = pointer_get(doc, src)
    var after = _remove(doc, src)
    return _add(after, path, val)


def _copy_op(doc: JsonValue, path: String, src: String) raises DecodeError -> JsonValue:
    var val = pointer_get(doc, src)
    return _add(doc, path, val)


def _test(doc: JsonValue, path: String, value: JsonValue) raises DecodeError:
    var got = pointer_get(doc, path)
    if not json_equal(got, value):
        raise DecodeError(DecodeError.KIND_PATCH, 0)


def _is_prefix(src: String, dest: String) -> Bool:
    if src.byte_length() == 0:
        return dest.byte_length() > 0
    if dest.byte_length() < src.byte_length():
        return False
    var a = src.as_bytes()
    var b = dest.as_bytes()
    var i = 0
    while i < len(a):
        if Int(a[i]) != Int(b[i]):
            return False
        i += 1
    if dest.byte_length() == src.byte_length():
        return False
    return Int(b[src.byte_length()]) == 47


def _insert(
    doc: JsonValue, path: String, value: JsonValue, allow_new: Bool
) raises DecodeError -> JsonValue:
    var tokens = _split(path)
    if len(tokens) == 0:
        return pointer_set(doc, "", value)
    return _insert_at(doc, tokens, 0, value, allow_new)


def _insert_at(
    doc: JsonValue,
    tokens: List[String],
    i: Int,
    value: JsonValue,
    allow_new: Bool,
) raises DecodeError -> JsonValue:
    var tok = tokens[i]
    var last = i + 1 == len(tokens)
    if doc.is_array():
        var n = doc.count()
        var idx = _array_index(tok, n, last)
        var items = List[JsonValue]()
        var k = 0
        while k < n:
            var ch0 = doc.at(k)
            items.append(ch0^)
            k += 1
        if last:
            if idx == n:
                items.append(pointer_set(value, "", value))
            else:
                var shifted = List[JsonValue]()
                k = 0
                while k < n:
                    if k == idx:
                        shifted.append(pointer_set(value, "", value))
                    var chs = doc.at(k)
                    shifted.append(chs^)
                    k += 1
                return json_array(shifted)
        else:
            items[idx] = _insert_at(items[idx], tokens, i + 1, value, allow_new)
        return json_array(items)
    if doc.is_object():
        var pairs = List[Tuple[String, JsonValue]]()
        var n = doc.count()
        var found = False
        var k = 0
        while k < n:
            var p = doc.pair(k)
            if p[0] == tok:
                found = True
                if last:
                    pairs.append((p[0], pointer_set(value, "", value)))
                else:
                    pairs.append((p[0], _insert_at(p[1], tokens, i + 1, value, allow_new)))
            else:
                pairs.append(p^)
            k += 1
        if not found:
            if last and allow_new:
                pairs.append((tok, pointer_set(value, "", value)))
            else:
                raise DecodeError(DecodeError.KIND_POINTER, 0)
        return json_object(pairs)
    raise DecodeError(DecodeError.KIND_PATCH, 0)


def _delete(doc: JsonValue, path: String) raises DecodeError -> JsonValue:
    var tokens = _split(path)
    return _delete_at(doc, tokens, 0)


def _delete_at(
    doc: JsonValue, tokens: List[String], i: Int
) raises DecodeError -> JsonValue:
    var tok = tokens[i]
    var last = i + 1 == len(tokens)
    if doc.is_array():
        var n = doc.count()
        var idx = _array_index(tok, n, False)
        var items = List[JsonValue]()
        var k = 0
        while k < n:
            if last and k == idx:
                k += 1
                continue
            if last:
                var ch3 = doc.at(k)
                items.append(ch3^)
            elif k == idx:
                items.append(_delete_at(doc.at(k), tokens, i + 1))
            else:
                var ch4 = doc.at(k)
                items.append(ch4^)
            k += 1
        return json_array(items)
    if doc.is_object():
        var pairs = List[Tuple[String, JsonValue]]()
        var n = doc.count()
        var k = 0
        while k < n:
            var p = doc.pair(k)
            if p[0] == tok:
                if not last:
                    pairs.append((p[0], _delete_at(p[1], tokens, i + 1)))
            else:
                pairs.append(p^)
            k += 1
        return json_object(pairs)
    raise DecodeError(DecodeError.KIND_PATCH, 0)


def json_equal(a: JsonValue, b: JsonValue) -> Bool:
    if a.is_null() and b.is_null():
        return True
    if a.is_bool() and b.is_bool():
        try:
            return a.as_bool() == b.as_bool()
        except _:
            return False
    if (a.is_int() or a.is_float()) and (b.is_int() or b.is_float()):
        try:
            return a.as_float() == b.as_float()
        except _:
            return False
    if a.is_string() and b.is_string():
        try:
            return a.as_str() == b.as_str()
        except _:
            return False
    if a.is_array() and b.is_array():
        if a.count() != b.count():
            return False
        var i = 0
        while i < a.count():
            try:
                if not json_equal(a.at(i), b.at(i)):
                    return False
            except _:
                return False
            i += 1
        return True
    if a.is_object() and b.is_object():
        return _obj_equal(a, b)
    return False


def _obj_equal(a: JsonValue, b: JsonValue) -> Bool:
    var n = a.count()
    if n != b.count():
        # last-key-wins may collapse; compare by key set
        pass
    var i = 0
    var keys = List[String]()
    while i < a.count():
        try:
            var p = a.pair(i)
            var seen = False
            var k = 0
            while k < len(keys):
                if keys[k] == p[0]:
                    seen = True
                k += 1
            if not seen:
                keys.append(p[0])
        except _:
            return False
        i += 1
    i = 0
    while i < b.count():
        try:
            var p = b.pair(i)
            var seen = False
            var k = 0
            while k < len(keys):
                if keys[k] == p[0]:
                    seen = True
                k += 1
            if not seen:
                keys.append(p[0])
        except _:
            return False
        i += 1
    i = 0
    while i < len(keys):
        try:
            if not json_equal(a.get(keys[i]), b.get(keys[i])):
                return False
        except _:
            return False
        i += 1
    return True
