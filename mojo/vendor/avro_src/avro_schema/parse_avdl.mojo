from std.collections import List

from avro_json.emit import emit_json
from avro_json.parse import parse_json
from avro_json.value import JSON_ARRAY, JSON_OBJECT, JSON_STRING
from avro_schema.model import SchemaError, SchemaPool
from avro_schema.parse_avpr import parse_avpr
from avro_schema.parse_avsc import parse_avsc


struct FileImportResolver(Copyable, Movable, Defaultable):
    """Reads import paths relative to the including file."""

    var _pad: Int

    def __init__(out self):
        self._pad = 0

    def resolve(
        self, kind: String, path: String, from_file: String
    ) raises SchemaError -> String:
        _ = kind
        return _read_rel(from_file, path)


# DESIGN name ImportResolver. A Mojo trait here hung the compiler; this is the
# concrete type parse_avdl accepts.
comptime ImportResolver = FileImportResolver


def parse_avdl(text: String) raises SchemaError -> SchemaPool:
    return parse_avsc(_idl_to_avsc(text))


def parse_avdl(
    text: String, resolver: FileImportResolver
) raises SchemaError -> SchemaPool:
    return parse_avdl(text, String(), resolver)


def parse_avdl(text: String, from_file: String) raises SchemaError -> SchemaPool:
    var r = FileImportResolver()
    return parse_avdl(text, from_file, r)


def parse_avdl(
    text: String, from_file: String, resolver: FileImportResolver
) raises SchemaError -> SchemaPool:
    var stack = List[String]()
    return _parse_avdl_res(text, from_file, resolver, stack)


def _parse_avdl_res(
    text: String,
    from_file: String,
    resolver: FileImportResolver,
    mut stack: List[String],
) raises SchemaError -> SchemaPool:
    var i = 0
    while i < len(stack):
        if stack[i] == from_file:
            raise SchemaError("IDL: cyclic import " + from_file)
        i += 1
    stack.append(from_file)
    var json = _idl_to_avsc(text)
    var p = 0
    var extra = List[String]()
    while True:
        var ip = _find_from(text, String("import "), p)
        if ip < 0:
            break
        p = ip + 7
        var kind = _ident_at(text, _skip_ws(text, p))
        var qs = _find_from(text, String("\""), p)
        if qs < 0:
            raise SchemaError("IDL: import missing path")
        var path = _until(text, qs + 1, 34)
        var body = resolver.resolve(kind, path, from_file)
        if kind == "idl":
            var nested = _join_dir(from_file, path)
            var np = _parse_avdl_res(body, nested, resolver, stack)
            extra.append(np.original_json)
        elif kind == "schema":
            extra.append(body)
        elif kind == "protocol":
            _ = parse_avpr(body)
            var tjs = _avpr_type_jsons(body)
            var ti = 0
            while ti < len(tjs):
                extra.append(tjs[ti])
                ti += 1
        else:
            raise SchemaError("IDL: unknown import kind")
        p = qs + path.byte_length() + 1
    if len(extra) == 0:
        return parse_avsc(json)
    extra.append(json)
    var arr = String("[")
    var j = 0
    while j < len(extra):
        if j > 0:
            arr += ","
        arr += extra[j]
        j += 1
    arr += "]"
    return parse_avsc(arr)


def _avpr_type_jsons(text: String) raises SchemaError -> List[String]:
    var out = List[String]()
    try:
        var doc = parse_json(text)
        if doc.kind(doc.root) != JSON_OBJECT:
            return out^
        var ns = String()
        var nsf = doc.find(doc.root, String("namespace"))
        if nsf >= 0 and doc.kind(nsf) == JSON_STRING:
            ns = doc.as_string(nsf)
        var types = doc.find(doc.root, String("types"))
        if types < 0 or doc.kind(types) != JSON_ARRAY:
            return out^
        var n = doc.nodes[types].count
        var i = 0
        while i < n:
            var child = doc.child(types, i)
            var js = emit_json(doc, child)
            if (
                ns.byte_length() > 0
                and doc.kind(child) == JSON_OBJECT
                and doc.find(child, String("namespace")) < 0
            ):
                js = _inject_ns(js, ns)
            out.append(js)
            i += 1
    except _:
        raise SchemaError("IDL: invalid imported protocol")
    return out^


def _inject_ns(js: String, ns: String) -> String:
    if js.byte_length() == 0 or Int(js.as_bytes()[0]) != 123:
        return js
    var rest = List[Byte]()
    var b = js.as_bytes()
    var i = 1
    while i < len(b):
        rest.append(b[i])
        i += 1
    try:
        return String("{\"namespace\":\"") + ns + "\"," + String(from_utf8=rest)
    except _:
        return js


def _join_dir(from_file: String, path: String) -> String:
    var b = from_file.as_bytes()
    var last = -1
    var i = 0
    while i < len(b):
        if Int(b[i]) == 47:
            last = i
        i += 1
    if last <= 0:
        return path
    return _slice(from_file, 0, last) + "/" + path


def _idl_to_avsc(text: String) raises SchemaError -> String:
    var ns = String()
    var npos = _find_from(text, String("@namespace(\""), 0)
    if npos >= 0:
        ns = _until(text, npos + 12, 34)
    var types = List[String]()
    var pos = 0
    var guard = 0
    while guard < 64:
        guard += 1
        var kp = _next_decl(text, pos)
        if kp < 0:
            break
        var kind = _ident_at(text, kp)
        if kind == "record" or kind == "error":
            types.append(_convert_record(text, kp, ns))
            pos = _after_block(text, _find_from(text, String("{"), kp))
        elif kind == "enum":
            types.append(_convert_enum(text, kp, ns))
            pos = _after_block(text, _find_from(text, String("{"), kp))
        elif kind == "fixed":
            var fx = _convert_fixed(text, kp, ns)
            types.append(fx)
            var par = _find_from(text, String(")"), kp)
            if par >= 0:
                pos = par + 1
            else:
                pos = kp + kind.byte_length()
        else:
            pos = kp + kind.byte_length()
    if len(types) == 0:
        raise SchemaError("IDL: no record")
    if len(types) == 1:
        return types[0]
    var json = String("[")
    var i = 0
    while i < len(types):
        if i > 0:
            json += ","
        json += types[i]
        i += 1
    json += "]"
    return json


def _convert_record(text: String, rec_pos: Int, ns: String) raises SchemaError -> String:
    var after_kw = _skip_ws(text, rec_pos + _ident_at(text, rec_pos).byte_length())
    var name = _ident_at(text, after_kw)
    if name.byte_length() == 0:
        raise SchemaError("IDL: record missing name")
    var brace = _find_from(text, String("{"), rec_pos)
    if brace < 0:
        raise SchemaError("IDL: record missing body")
    var end = _after_block(text, brace)
    var body = _slice(text, brace + 1, end - 1)
    var kw = _ident_at(text, rec_pos)
    var tlabel = String("record")
    if kw == "error":
        tlabel = String("error")
    var json = String("{\"type\":\"") + tlabel + "\",\"name\":\"" + name + "\""
    if ns.byte_length() > 0:
        json += ",\"namespace\":\"" + ns + "\""
    json += ",\"fields\":["
    var first = True
    var i = 0
    var guard = 0
    while i < body.byte_length() and guard < 256:
        guard += 1
        i = _skip_ws(body, i)
        if i >= body.byte_length():
            break
        var logical = String()
        while i < body.byte_length() and _byte(body, i) == 64:
            var aname = _ident_at(body, i + 1)
            var par = _find_from(body, String("("), i)
            if par < 0:
                i += 1
                break
            var cl = _find_from(body, String(")"), par)
            if cl < 0:
                i += 1
                break
            if aname == "logicalType":
                var qs = _find_from(body, String("\""), par)
                if qs >= 0 and qs < cl:
                    logical = _until(body, qs + 1, 34)
            i = _skip_ws(body, cl + 1)
        if i >= body.byte_length():
            break
        var ty = _apply_logical(_type_at(body, i), logical)
        i = _skip_ws(body, i + _type_span(body, i))
        var fname = _ident_at(body, i)
        if fname.byte_length() == 0:
            break
        i = _skip_ws(body, i + fname.byte_length())
        var defj = String()
        if i < body.byte_length() and _byte(body, i) == 61:
            i = _skip_ws(body, i + 1)
            defj = _literal_at(body, i)
            i += _literal_span(body, i)
        var semi = _find_from(body, String(";"), i)
        if semi < 0:
            raise SchemaError("IDL: field missing ;")
        i = semi + 1
        if not first:
            json += ","
        first = False
        json += "{\"name\":\"" + fname + "\",\"type\":" + ty
        if defj.byte_length() > 0:
            json += ",\"default\":" + defj
        json += "}"
    json += "]}"
    return json


def _convert_enum(text: String, pos: Int, ns: String) -> String:
    var name = _ident_at(text, _skip_ws(text, pos + 4))
    var brace = _find_from(text, String("{"), pos)
    var end = _after_block(text, brace)
    var body = _slice(text, brace + 1, end - 1)
    var json = String("{\"type\":\"enum\",\"name\":\"") + name + "\""
    if ns.byte_length() > 0:
        json += ",\"namespace\":\"" + ns + "\""
    json += ",\"symbols\":["
    var first = True
    var i = 0
    while i < body.byte_length():
        i = _skip_ws(body, i)
        if i >= body.byte_length():
            break
        if _byte(body, i) == 44:
            i += 1
            continue
        var sym = _ident_at(body, i)
        if sym.byte_length() == 0:
            break
        if not first:
            json += ","
        first = False
        json += "\"" + sym + "\""
        i += sym.byte_length()
    json += "]}"
    return json


def _convert_fixed(text: String, pos: Int, ns: String) -> String:
    var name = _ident_at(text, _skip_ws(text, pos + 5))
    var par = _find_from(text, String("("), pos)
    var size = String("0")
    if par >= 0:
        size = _until(text, par + 1, 41)
    var json = String("{\"type\":\"fixed\",\"name\":\"") + name + "\""
    if ns.byte_length() > 0:
        json += ",\"namespace\":\"" + ns + "\""
    json += ",\"size\":" + size + "}"
    return json


def _apply_logical(ty: String, logical: String) -> String:
    if logical.byte_length() == 0 or ty.byte_length() == 0:
        return ty
    if _starts_at(ty, 0, String("[\"null\",")):
        var inner = _slice(ty, 8, ty.byte_length() - 1)
        return "[\"null\"," + _wrap_logical(inner, logical) + "]"
    return _wrap_logical(ty, logical)


def _wrap_logical(ty: String, logical: String) -> String:
    if _byte(ty, 0) == 34:
        return "{\"type\":" + ty + ",\"logicalType\":\"" + logical + "\"}"
    if _byte(ty, 0) == 123:
        return "{\"logicalType\":\"" + logical + "\"," + _slice(ty, 1, ty.byte_length())
    return ty


def _type_at(text: String, start: Int) -> String:
    var i = _skip_ws(text, start)
    if _starts_at(text, i, String("array")):
        var inner = _type_at(text, _find_from(text, String("<"), i) + 1)
        var t = "{\"type\":\"array\",\"items\":" + inner + "}"
        if _has_q(text, start):
            return "[\"null\"," + t + "]"
        return t
    if _starts_at(text, i, String("map")):
        var inner = _type_at(text, _find_from(text, String("<"), i) + 1)
        var t = "{\"type\":\"map\",\"values\":" + inner + "}"
        if _has_q(text, start):
            return "[\"null\"," + t + "]"
        return t
    if _starts_at(text, i, String("union")):
        return _union_at(text, i)
    var id = _ident_at(text, i)
    var t = "\"" + id + "\""
    var after = _skip_ws(text, i + id.byte_length())
    if after < text.byte_length() and _byte(text, after) == 63:
        return "[\"null\"," + t + "]"
    return t


def _union_at(text: String, start: Int) -> String:
    var brace = _find_from(text, String("{"), start)
    var end = _after_block(text, brace)
    var body = _slice(text, brace + 1, end - 1)
    var s = String("[")
    var first = True
    var i = 0
    while i < body.byte_length():
        i = _skip_ws(body, i)
        if i >= body.byte_length():
            break
        if _byte(body, i) == 44:
            i += 1
            continue
        var t = _type_at(body, i)
        if not first:
            s += ","
        first = False
        s += t
        i += _type_span(body, i)
    s += "]"
    return s


def _type_span(text: String, start: Int) -> Int:
    var i = _skip_ws(text, start)
    if _starts_at(text, i, String("array")) or _starts_at(text, i, String("map")):
        var open_a = _find_from(text, String("<"), i)
        var close_a = _find_from(text, String(">"), open_a)
        i = close_a + 1
    elif _starts_at(text, i, String("union")):
        i = _after_block(text, _find_from(text, String("{"), i))
    else:
        i += _ident_at(text, i).byte_length()
    i = _skip_ws(text, i)
    if i < text.byte_length() and _byte(text, i) == 63:
        i += 1
    return i - start


def _has_q(text: String, start: Int) -> Bool:
    var i = start + _type_span(text, start) - 1
    return i >= 0 and i < text.byte_length() and _byte(text, i) == 63


def _literal_at(text: String, start: Int) -> String:
    """Convert one IDL literal to Avro JSON. Iterative so nested arrays/objects compile."""
    var i = _skip_ws(text, start)
    var c0 = _byte(text, i)
    if c0 != 91 and c0 != 123:
        return _atom_lit(text, i)
    var end: Int
    if c0 == 91:
        end = _after_match(text, i, 91, 93)
    else:
        end = _after_match(text, i, 123, 125)
    var out = String()
    var pos = i
    while pos < end:
        var c = _byte(text, pos)
        if c == 32 or c == 9 or c == 10 or c == 13:
            pos += 1
            continue
        if c == 61:
            out += ":"
            pos += 1
            continue
        if c == 91 or c == 93 or c == 123 or c == 125 or c == 44 or c == 58:
            out += _ch(c)
            pos += 1
            continue
        if c == 34:
            var s = _until(text, pos + 1, 34)
            out += "\"" + s + "\""
            pos += s.byte_length() + 2
            continue
        if c == 45 or (c >= 48 and c <= 57):
            var num = _number_at(text, pos)
            out += num
            pos += num.byte_length()
            continue
        var id = _ident_at(text, pos)
        if id.byte_length() == 0:
            pos += 1
            continue
        var after = _skip_ws(text, pos + id.byte_length())
        var as_key = after < end and (_byte(text, after) == 58 or _byte(text, after) == 61)
        if as_key:
            out += "\"" + id + "\""
        elif id == "null" or id == "true" or id == "false":
            out += id
        else:
            out += "\"" + id + "\""
        pos += id.byte_length()
    return out


def _atom_lit(text: String, i: Int) -> String:
    if _starts_at(text, i, String("null")):
        return String("null")
    if _starts_at(text, i, String("true")):
        return String("true")
    if _starts_at(text, i, String("false")):
        return String("false")
    if _byte(text, i) == 34:
        return "\"" + _until(text, i + 1, 34) + "\""
    if _byte(text, i) == 45 or (_byte(text, i) >= 48 and _byte(text, i) <= 57):
        return _number_at(text, i)
    return "\"" + _ident_at(text, i) + "\""


def _literal_span(text: String, start: Int) -> Int:
    var i = _skip_ws(text, start)
    if _starts_at(text, i, String("null")):
        return 4
    if _starts_at(text, i, String("true")):
        return 4
    if _starts_at(text, i, String("false")):
        return 5
    if _byte(text, i) == 34:
        return _until(text, i + 1, 34).byte_length() + 2
    if _byte(text, i) == 91:
        return _after_match(text, i, 91, 93) - i
    if _byte(text, i) == 123:
        return _after_match(text, i, 123, 125) - i
    if _byte(text, i) == 45 or (_byte(text, i) >= 48 and _byte(text, i) <= 57):
        return _number_at(text, i).byte_length()
    return _ident_at(text, i).byte_length()


def _ch(c: Int) -> String:
    var b = List[Byte]()
    b.append(Byte(c))
    try:
        return String(from_utf8=b)
    except _:
        return String()


def _after_match(text: String, open_at: Int, open_ch: Int, close_ch: Int) -> Int:
    var depth = 0
    var i = open_at
    while i < text.byte_length():
        var c = _byte(text, i)
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return text.byte_length()


def _number_at(text: String, start: Int) -> String:
    var i = start
    if _byte(text, i) == 45:
        i += 1
    while i < text.byte_length():
        var c = _byte(text, i)
        if (c >= 48 and c <= 57) or c == 46:
            i += 1
        else:
            break
    return _slice(text, start, i)


def _next_decl(text: String, start: Int) -> Int:
    var keys = List[String]()
    keys.append(String("record "))
    keys.append(String("error "))
    keys.append(String("enum "))
    keys.append(String("fixed "))
    var best = -1
    var i = 0
    while i < len(keys):
        var p = _find_from(text, keys[i], start)
        if p >= 0 and (best < 0 or p < best):
            best = p
        i += 1
    return best


def _after_block(text: String, brace: Int) -> Int:
    if brace < 0:
        return text.byte_length()
    var depth = 0
    var i = brace
    while i < text.byte_length():
        var c = _byte(text, i)
        if c == 123:
            depth += 1
        elif c == 125:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return text.byte_length()


def _find_from(text: String, pat: String, start: Int) -> Int:
    var tb = text.as_bytes()
    var pb = pat.as_bytes()
    if len(pb) == 0 or start + len(pb) > len(tb):
        return -1
    var i = start
    while i <= len(tb) - len(pb):
        var ok = True
        var j = 0
        while j < len(pb):
            if tb[i + j] != pb[j]:
                ok = False
                break
            j += 1
        if ok:
            return i
        i += 1
    return -1


def _starts_at(text: String, i: Int, word: String) -> Bool:
    var wb = word.as_bytes()
    var tb = text.as_bytes()
    if i + len(wb) > len(tb):
        return False
    var j = 0
    while j < len(wb):
        if tb[i + j] != wb[j]:
            return False
        j += 1
    return True


def _ident_at(text: String, start: Int) -> String:
    var i = _skip_ws(text, start)
    if i >= text.byte_length():
        return String()
    var c = _byte(text, i)
    if not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95):
        return String()
    var j = i + 1
    while j < text.byte_length():
        var d = _byte(text, j)
        if (d >= 65 and d <= 90) or (d >= 97 and d <= 122) or d == 95 or (d >= 48 and d <= 57):
            j += 1
        else:
            break
    return _slice(text, i, j)


def _skip_ws(text: String, start: Int) -> Int:
    var i = start
    while i < text.byte_length():
        var c = _byte(text, i)
        if c == 32 or c == 9 or c == 10 or c == 13:
            i += 1
        else:
            return i
    return i


def _byte(text: String, i: Int) -> Int:
    return Int(text.as_bytes()[i])


def _slice(text: String, start: Int, end: Int) -> String:
    var out = List[Byte]()
    var b = text.as_bytes()
    var i = start
    while i < end and i < len(b):
        out.append(b[i])
        i += 1
    try:
        return String(from_utf8=out)
    except _:
        return String()


def _until(text: String, start: Int, stop: Int) -> String:
    var i = start
    while i < text.byte_length() and _byte(text, i) != stop:
        i += 1
    return _slice(text, start, i)


def _read_rel(from_file: String, path: String) raises SchemaError -> String:
    var b = from_file.as_bytes()
    var last = -1
    var i = 0
    while i < len(b):
        if Int(b[i]) == 47:
            last = i
        i += 1
    var full = path
    if last > 0:
        full = _slice(from_file, 0, last) + "/" + path
    try:
        var f = open(full, "r")
        var s = String(f.read())
        f.close()
        return s
    except _:
        raise SchemaError("import not found: " + path)
