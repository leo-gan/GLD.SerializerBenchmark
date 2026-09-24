from avro_json.value import (
    JSON_ARRAY,
    JSON_BOOL,
    JSON_FLOAT,
    JSON_INT,
    JSON_NULL,
    JSON_OBJECT,
    JSON_STRING,
    JsonDoc,
)


def emit_json(doc: JsonDoc, id: Int) -> String:
    var k = doc.kind(id)
    if k == JSON_NULL:
        return String("null")
    if k == JSON_BOOL:
        if doc.as_bool(id):
            return String("true")
        return String("false")
    if k == JSON_INT:
        return String(doc.as_int(id))
    if k == JSON_FLOAT:
        return String(doc.as_float(id))
    if k == JSON_STRING:
        return _quote(doc.as_string(id))
    if k == JSON_ARRAY:
        var s = String("[")
        var i = 0
        var n = doc.nodes[id].count
        while i < n:
            if i > 0:
                s += ","
            s += emit_json(doc, doc.child(id, i))
            i += 1
        s += "]"
        return s
    var s = String("{")
    var i = 0
    var n = doc.nodes[id].count
    while i < n:
        if i > 0:
            s += ","
        s += _quote(doc.obj_key(id, i))
        s += ":"
        s += emit_json(doc, doc.obj_val(id, i))
        i += 1
    s += "}"
    return s


def _quote(s: String) -> String:
    var out = String("\"")
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 34:
            out += "\\\""
        elif c == 92:
            out += "\\\\"
        elif c == 10:
            out += "\\n"
        elif c == 13:
            out += "\\r"
        elif c == 9:
            out += "\\t"
        else:
            out += s[byte=i]
        i += 1
    out += "\""
    return out
