from std.collections import List

from bson_runtime.decimal import decimal_parse, decimal_to_string, decimal_from_list
from bson_runtime.error import DecodeError
from bson_runtime.text import (
    base64_decode,
    base64_encode,
    format_datetime,
    hex_decode,
    hex_encode,
    parse_datetime,
)
from bson_runtime.jsonparse import JK_ARR, JK_BOOL, JK_NULL, JK_NUM, JK_OBJ, JK_STR, JsonDoc, parse_json
from bson_runtime.value import BsonValue
from bson_wire.types import (
    BK_ARRAY,
    BK_BINARY,
    BK_BOOL,
    BK_CODE,
    BK_CODEWS,
    BK_DATETIME,
    BK_DBPOINTER,
    BK_DECIMAL,
    BK_DOC,
    BK_DOUBLE,
    BK_INT32,
    BK_INT64,
    BK_MAXKEY,
    BK_MINKEY,
    BK_NULL,
    BK_OID,
    BK_REGEX,
    BK_STRING,
    BK_SYMBOL,
    BK_TIMESTAMP,
    BK_UNDEFINED,
)


def _find(doc: JsonDoc, obj: Int, key: String) -> Int:
    var i = 0
    while i < len(doc.nodes[obj].keys):
        if doc.nodes[obj].keys[i] == key:
            return doc.nodes[obj].kids[i]
        i += 1
    return -1


def _str_at(doc: JsonDoc, idx: Int) raises DecodeError -> String:
    if doc.nodes[idx].kind != JK_STR:
        raise DecodeError(DecodeError.KIND_TYPE, idx, doc.nodes[idx].kind)
    return doc.nodes[idx].text


def _num_text(text: String) -> Bool:
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        var c = b[i]
        if c == Byte(ord(".")) or c == Byte(ord("e")) or c == Byte(ord("E")):
            return False
        i += 1
    return True


def _parse_i64(text: String) raises DecodeError -> Int64:
    var b = text.as_bytes()
    var i = 0
    var neg = False
    if len(b) > 0 and b[0] == Byte(ord("-")):
        neg = True
        i = 1
    if i >= len(b):
        raise DecodeError(DecodeError.KIND_SYNTAX, 0, 0)
    var v = Int64(0)
    while i < len(b):
        var c = Int(b[i])
        if c < 48 or c > 57:
            raise DecodeError(DecodeError.KIND_SYNTAX, i, c)
        v = v * Int64(10) + Int64(c - 48)
        i += 1
    if neg:
        v = -v
    return v


def _json_number(mut docv: BsonValue, parent: Int, key: String, text: String) raises DecodeError:
    if not _num_text(text):
        var f = Float64(0)
        try:
            f = Float64(text)
        except _:
            raise DecodeError(DecodeError.KIND_NUMBER, 0, 0)
        docv.put_f64(parent, key, f)
        return
    var v = _parse_i64(text)
    if v >= Int64(-2147483648) and v <= Int64(2147483647):
        docv.put_i32(parent, key, Int32(v))
    else:
        docv.put_i64(parent, key, v)


def _from_json(js: JsonDoc, idx: Int, mut docv: BsonValue, parent: Int, key: String, as_root: Bool) raises DecodeError -> Int:
    var kind = js.nodes[idx].kind
    var slot = parent
    if kind == JK_NULL:
        if as_root:
            raise DecodeError(DecodeError.KIND_TYPE, 0, kind)
        docv.put_null(parent, key)
        return parent
    if kind == JK_BOOL:
        docv.put_bool(parent, key, js.nodes[idx].flag)
        return parent
    if kind == JK_NUM:
        _json_number(docv, parent, key, js.nodes[idx].text)
        return parent
    if kind == JK_STR:
        docv.put_string(parent, key, js.nodes[idx].text)
        return parent
    if kind == JK_ARR:
        var arr = 0
        if as_root:
            raise DecodeError(DecodeError.KIND_TYPE, 0, kind)
        arr = docv.put_array(parent, key)
        var i = 0
        while i < len(js.nodes[idx].kids):
            _ = _from_json(js, js.nodes[idx].kids[i], docv, arr, String(i), False)
            i += 1
        return arr
    if kind != JK_OBJ:
        raise DecodeError(DecodeError.KIND_TYPE, idx, kind)
    var nkeys = len(js.nodes[idx].keys)
    if not as_root and nkeys >= 1:
        var k0 = js.nodes[idx].keys[0]
        if k0 == "$numberInt" and nkeys == 1:
            var v = _parse_i64(_str_at(js, js.nodes[idx].kids[0]))
            docv.put_i32(parent, key, Int32(v))
            return parent
        if k0 == "$numberLong" and nkeys == 1:
            docv.put_i64(parent, key, _parse_i64(_str_at(js, js.nodes[idx].kids[0])))
            return parent
        if k0 == "$numberDouble" and nkeys == 1:
            var t = _str_at(js, js.nodes[idx].kids[0])
            if t == "NaN":
                docv.put_f64(parent, key, Float64(from_bits=UInt64(0x7FF8000000000000)))
            elif t == "Infinity":
                docv.put_f64(parent, key, Float64(from_bits=UInt64(0x7FF0000000000000)))
            elif t == "-Infinity":
                docv.put_f64(parent, key, Float64(from_bits=UInt64(0xFFF0000000000000)))
            elif t == "-0.0":
                docv.put_f64(parent, key, Float64(from_bits=UInt64(0x8000000000000000)))
            else:
                var f = Float64(0)
                try:
                    f = Float64(t)
                except _:
                    raise DecodeError(DecodeError.KIND_NUMBER, 0, 0)
                docv.put_f64(parent, key, f)
            return parent
        if k0 == "$numberDecimal" and nkeys == 1:
            var dec = decimal_parse(_str_at(js, js.nodes[idx].kids[0]))
            var child = docv._child(parent, BK_DECIMAL, key)
            docv.nodes[child].raw = dec.to_bytes()
            return parent
        if k0 == "$oid" and nkeys == 1:
            var child = docv._child(parent, BK_OID, key)
            docv.nodes[child].raw = hex_decode(_str_at(js, js.nodes[idx].kids[0]))
            return parent
        if k0 == "$symbol" and nkeys == 1:
            var child = docv._child(parent, BK_SYMBOL, key)
            docv.nodes[child].s0 = _str_at(js, js.nodes[idx].kids[0])
            return parent
        if k0 == "$undefined" and nkeys == 1:
            _ = docv._child(parent, BK_UNDEFINED, key)
            return parent
        if k0 == "$minKey" and nkeys == 1:
            _ = docv._child(parent, BK_MINKEY, key)
            return parent
        if k0 == "$maxKey" and nkeys == 1:
            _ = docv._child(parent, BK_MAXKEY, key)
            return parent
        if k0 == "$date" and nkeys == 1:
            var inner = js.nodes[idx].kids[0]
            var ms = Int64(0)
            if js.nodes[inner].kind == JK_STR:
                ms = parse_datetime(js.nodes[inner].text)
            else:
                var long_i = _find(js, inner, "$numberLong")
                ms = _parse_i64(_str_at(js, long_i))
            var child = docv._child(parent, BK_DATETIME, key)
            docv.nodes[child].i64 = ms
            return parent
        if k0 == "$code":
            var scope_i = _find(js, idx, "$scope")
            if scope_i < 0 and nkeys == 1:
                var child = docv._child(parent, BK_CODE, key)
                docv.nodes[child].s0 = _str_at(js, js.nodes[idx].kids[0])
                return parent
            var child = docv._child(parent, BK_CODEWS, key)
            docv.nodes[child].s0 = _str_at(js, _find(js, idx, "$code"))
            var scope = docv._child(child, BK_DOC, "")
            _ = _fill_object(js, scope_i, docv, scope)
            return parent
        if k0 == "$binary" and nkeys == 1:
            var inner = js.nodes[idx].kids[0]
            var b64 = _str_at(js, _find(js, inner, "base64"))
            var sub = hex_decode(_str_at(js, _find(js, inner, "subType")))
            var child = docv._child(parent, BK_BINARY, key)
            docv.nodes[child].sub = Int(sub[0])
            docv.nodes[child].raw = base64_decode(b64)
            return parent
        if k0 == "$regularExpression" and nkeys == 1:
            var inner = js.nodes[idx].kids[0]
            var child = docv._child(parent, BK_REGEX, key)
            docv.nodes[child].s0 = _str_at(js, _find(js, inner, "pattern"))
            docv.nodes[child].s1 = _str_at(js, _find(js, inner, "options"))
            return parent
        if k0 == "$timestamp" and nkeys == 1:
            var inner = js.nodes[idx].kids[0]
            var t = Int(_parse_i64(js.nodes[_find(js, inner, "t")].text))
            var inc = Int(_parse_i64(js.nodes[_find(js, inner, "i")].text))
            var child = docv._child(parent, BK_TIMESTAMP, key)
            docv.nodes[child].i64 = (Int64(t) << Int64(32)) | Int64(inc)
            return parent
        if k0 == "$dbPointer" and nkeys == 1:
            var inner = js.nodes[idx].kids[0]
            var idobj = _find(js, inner, "$id")
            var oid = hex_decode(_str_at(js, _find(js, idobj, "$oid")))
            var child = docv._child(parent, BK_DBPOINTER, key)
            docv.nodes[child].s0 = _str_at(js, _find(js, inner, "$ref"))
            docv.nodes[child].raw = oid^
            return parent
    var target = parent
    if not as_root:
        target = docv.put_doc(parent, key)
    else:
        target = docv.new_document()
    _ = _fill_object(js, idx, docv, target)
    return target


def _fill_object(js: JsonDoc, idx: Int, mut docv: BsonValue, target: Int) raises DecodeError -> Int:
    var i = 0
    while i < len(js.nodes[idx].keys):
        _ = _from_json(js, js.nodes[idx].kids[i], docv, target, js.nodes[idx].keys[i], False)
        i += 1
    return target


def decode_extjson(text: String) raises DecodeError -> BsonValue:
    var js = parse_json(text)
    var docv = BsonValue()
    _ = _from_json(js, js.root, docv, 0, "", True)
    return docv^


def _esc(s: String) -> String:
    var b = s.as_bytes()
    var out = String("\"")
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 34 or c == 92:
            out += "\\"
            out += String(chr(c))
        elif c == 8:
            out += "\\b"
        elif c == 12:
            out += "\\f"
        elif c == 10:
            out += "\\n"
        elif c == 13:
            out += "\\r"
        elif c == 9:
            out += "\\t"
        elif c < 32:
            var hex = "0123456789abcdef"
            out += "\\u00"
            out += hex[byte = (c >> 4) & 15]
            out += hex[byte = c & 15]
        else:
            out += String(chr(c))
        i += 1
    out += "\""
    return out


def _fmt_f64(v: Float64) -> String:
    var bits = UInt64(v.to_bits())
    if (bits & UInt64(0x7FF0000000000000)) == UInt64(0x7FF0000000000000):
        if (bits & UInt64(0x000FFFFFFFFFFFFF)) != UInt64(0):
            return "NaN"
        if (bits >> UInt64(63)) != UInt64(0):
            return "-Infinity"
        return "Infinity"
    if bits == UInt64(0x8000000000000000):
        return "-0.0"
    if v == Float64(0):
        return "0.0"
    var iv = Int64(v)
    if Float64(iv) == v and iv > Int64(-1000000000000000) and iv < Int64(1000000000000000):
        return String(iv) + ".0"
    var neg = v < Float64(0)
    var x = v
    if neg:
        x = -v
    var exp = 0
    while x >= Float64(10) and exp < 350:
        x = x / Float64(10)
        exp += 1
    while x < Float64(1) and exp > -350:
        x = x * Float64(10)
        exp -= 1
    var digits = String()
    var k = 0
    while k < 16:
        var d = Int(x)
        if d < 0:
            d = 0
        if d > 9:
            d = 9
        digits += String(d)
        x = (x - Float64(d)) * Float64(10)
        k += 1
    var body = String()
    if neg:
        body = "-"
    body += digits[byte = 0]
    body += "."
    var end = 16
    while end > 1:
        var ch = Int(digits.as_bytes()[end - 1])
        if ch != 48:
            break
        end -= 1
    var p = 1
    var db = digits.as_bytes()
    while p < end:
        body += String(chr(Int(db[p])))
        p += 1
    if end == 1:
        body = String(digits[byte = 0])
        if neg:
            body = "-" + body
    if exp == 0 and end > 1:
        return body
    if exp == 0:
        return body + ".0"
    var es = String(exp)
    if exp > 0:
        es = "+" + es
    return body + "e" + es


def _emit(doc: BsonValue, idx: Int, canonical: Bool, mut out: String) raises DecodeError:
    var k = doc.nodes[idx].kind
    if k == BK_NULL:
        out += "null"
    elif k == BK_BOOL:
        if doc.nodes[idx].i64 != Int64(0):
            out += "true"
        else:
            out += "false"
    elif k == BK_STRING:
        out += _esc(doc.nodes[idx].s0)
    elif k == BK_INT32:
        if canonical:
            out += "{\"$numberInt\":" + _esc(String(doc.nodes[idx].i64)) + "}"
        else:
            out += String(doc.nodes[idx].i64)
    elif k == BK_INT64:
        if canonical:
            out += "{\"$numberLong\":" + _esc(String(doc.nodes[idx].i64)) + "}"
        else:
            out += String(doc.nodes[idx].i64)
    elif k == BK_DOUBLE:
        var text = _fmt_f64(doc.nodes[idx].f64)
        var bits = UInt64(doc.nodes[idx].f64.to_bits())
        var special = (bits & UInt64(0x7FF0000000000000)) == UInt64(0x7FF0000000000000) or bits == UInt64(0x8000000000000000)
        if canonical or special:
            out += "{\"$numberDouble\":" + _esc(text) + "}"
        else:
            out += text
    elif k == BK_DECIMAL:
        var dec = decimal_from_list(doc.nodes[idx].raw)
        out += "{\"$numberDecimal\":" + _esc(decimal_to_string(dec)) + "}"
    elif k == BK_OID:
        out += "{\"$oid\":" + _esc(hex_encode(Span(doc.nodes[idx].raw))) + "}"
    elif k == BK_BINARY:
        var one = List[Byte]()
        one.append(Byte(doc.nodes[idx].sub))
        var sub = hex_encode(Span(one))
        out += "{\"$binary\":{\"base64\":" + _esc(base64_encode(Span(doc.nodes[idx].raw))) + ",\"subType\":" + _esc(sub) + "}}"
    elif k == BK_DATETIME:
        if canonical:
            out += "{\"$date\":{\"$numberLong\":" + _esc(String(doc.nodes[idx].i64)) + "}}"
        else:
            out += "{\"$date\":" + _esc(format_datetime(doc.nodes[idx].i64)) + "}"
    elif k == BK_REGEX:
        out += "{\"$regularExpression\":{\"pattern\":" + _esc(doc.nodes[idx].s0) + ",\"options\":" + _esc(doc.nodes[idx].s1) + "}}"
    elif k == BK_TIMESTAMP:
        var t = Int(doc.nodes[idx].i64 >> Int64(32))
        var inc = Int(doc.nodes[idx].i64 & Int64(0xFFFFFFFF))
        out += "{\"$timestamp\":{\"t\":" + String(t) + ",\"i\":" + String(inc) + "}}"
    elif k == BK_MINKEY:
        out += "{\"$minKey\":1}"
    elif k == BK_MAXKEY:
        out += "{\"$maxKey\":1}"
    elif k == BK_UNDEFINED:
        out += "{\"$undefined\":true}"
    elif k == BK_CODE:
        out += "{\"$code\":" + _esc(doc.nodes[idx].s0) + "}"
    elif k == BK_SYMBOL:
        out += "{\"$symbol\":" + _esc(doc.nodes[idx].s0) + "}"
    elif k == BK_DBPOINTER:
        out += "{\"$dbPointer\":{\"$ref\":" + _esc(doc.nodes[idx].s0) + ",\"$id\":{\"$oid\":" + _esc(hex_encode(Span(doc.nodes[idx].raw))) + "}}}"
    elif k == BK_CODEWS:
        out += "{\"$code\":" + _esc(doc.nodes[idx].s0) + ",\"$scope\":"
        if len(doc.nodes[idx].kids) > 0:
            _emit(doc, doc.nodes[idx].kids[0], canonical, out)
        else:
            out += "{}"
        out += "}"
    elif k == BK_DOC or k == BK_ARRAY:
        if k == BK_ARRAY:
            out += "["
        else:
            out += "{"
        var i = 0
        var kids = len(doc.nodes[idx].kids)
        while i < kids:
            if i != 0:
                out += ","
            var c = doc.nodes[idx].kids[i]
            if k == BK_DOC:
                out += _esc(doc.nodes[c].key) + ":"
            _emit(doc, c, canonical, out)
            i += 1
        if k == BK_ARRAY:
            out += "]"
        else:
            out += "}"


def encode_extjson(doc: BsonValue, canonical: Bool) raises DecodeError -> String:
    var out = String()
    _emit(doc, doc.root, canonical, out)
    return out
