from std.collections import List

from gldjson_runtime.error import DecodeError
from gldjson_runtime.value import (
    JK_ARRAY,
    JK_OBJECT,
    JK_STRING,
    JsonNode,
    JsonValue,
    _copy_into,
    json_array,
    json_object,
)


def pointer_get(doc: JsonValue, ptr: String) raises DecodeError -> JsonValue:
    var tokens = _split(ptr)
    return _get(doc, tokens, 0)


def pointer_set(
    doc: JsonValue, ptr: String, value: JsonValue
) raises DecodeError -> JsonValue:
    var tokens = _split(ptr)
    if len(tokens) == 0:
        return _copy_root(value)
    return _set(doc, tokens, 0, value)


def _copy_root(v: JsonValue) -> JsonValue:
    var out = JsonValue()
    out.root = _copy_into(v, v.root, out)
    return out^


def _split(ptr: String) raises DecodeError -> List[String]:
    var out = List[String]()
    if ptr.byte_length() == 0:
        return out^
    var b = ptr.as_bytes()
    if Int(b[0]) != 47:
        raise DecodeError(DecodeError.KIND_POINTER, 0)
    var i = 1
    var cur = List[Byte]()
    while i <= len(b):
        if i == len(b) or Int(b[i]) == 47:
            out.append(_unescape(cur))
            cur = List[Byte]()
            i += 1
            continue
        if Int(b[i]) == 126:
            if i + 1 >= len(b):
                raise DecodeError(DecodeError.KIND_POINTER, i)
            var n = Int(b[i + 1])
            if n == 48:
                cur.append(Byte(126))
            elif n == 49:
                cur.append(Byte(47))
            else:
                raise DecodeError(DecodeError.KIND_POINTER, i)
            i += 2
            continue
        cur.append(b[i])
        i += 1
    return out^


def _unescape(cur: List[Byte]) raises DecodeError -> String:
    try:
        return String(from_utf8=cur)
    except _:
        raise DecodeError(DecodeError.KIND_UTF8, 0)


def _get(doc: JsonValue, tokens: List[String], i: Int) raises DecodeError -> JsonValue:
    if i >= len(tokens):
        return _copy_root(doc)
    var tok = tokens[i]
    if doc.is_array():
        var idx = _array_index(tok, doc.count(), False)
        return _get(doc.at(idx), tokens, i + 1)
    if doc.is_object():
        return _get(doc.get(tok), tokens, i + 1)
    raise DecodeError(DecodeError.KIND_POINTER, 0)


def _array_index(tok: String, n: Int, allow_end: Bool) raises DecodeError -> Int:
    if tok == "-":
        if allow_end:
            return n
        raise DecodeError(DecodeError.KIND_POINTER, 0)
    var b = tok.as_bytes()
    if len(b) == 0:
        raise DecodeError(DecodeError.KIND_POINTER, 0)
    if Int(b[0]) == 48 and len(b) > 1:
        raise DecodeError(DecodeError.KIND_POINTER, 0)
    var v = 0
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c < 48 or c > 57:
            raise DecodeError(DecodeError.KIND_POINTER, 0)
        v = v * 10 + (c - 48)
        i += 1
    if allow_end:
        if v < 0 or v > n:
            raise DecodeError(DecodeError.KIND_POINTER, 0)
    else:
        if v < 0 or v >= n:
            raise DecodeError(DecodeError.KIND_POINTER, 0)
    return v


def _set(
    doc: JsonValue, tokens: List[String], i: Int, value: JsonValue
) raises DecodeError -> JsonValue:
    if i >= len(tokens):
        return _copy_root(value)
    var tok = tokens[i]
    var last = i + 1 == len(tokens)
    if doc.is_array():
        var n = doc.count()
        var idx = _array_index(tok, n, last)
        var items = List[JsonValue]()
        var k = 0
        while k < n:
            var ch = doc.at(k)
            items.append(ch^)
            k += 1
        if last:
            if idx == n:
                items.append(_copy_root(value))
            else:
                items[idx] = _copy_root(value)
        else:
            items[idx] = _set(items[idx], tokens, i + 1, value)
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
                    pairs.append((p[0], _copy_root(value)))
                else:
                    pairs.append((p[0], _set(p[1], tokens, i + 1, value)))
            else:
                pairs.append(p^)
            k += 1
        if not found:
            if last:
                pairs.append((tok, _copy_root(value)))
            else:
                raise DecodeError(DecodeError.KIND_POINTER, 0)
        return json_object(pairs)
    raise DecodeError(DecodeError.KIND_POINTER, 0)
