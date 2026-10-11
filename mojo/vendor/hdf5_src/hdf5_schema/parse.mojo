from std.collections import List, Span

from hdf5_runtime.error import FormatError


struct Schema:
    """One generated dataset struct. `dtype` is a public type name such as `float64`."""

    var name: String
    var dataset: String
    var dtype: String
    var rank: Int

    def __init__(out self):
        self.name = String()
        self.dataset = String()
        self.dtype = String()
        self.rank = 1


def _find_key(text: String, key: String) raises -> Int:
    var raw = text.as_bytes()
    var kb = key.as_bytes()
    var i = 0
    while i + len(kb) + 2 <= len(raw):
        if Int(raw[i]) == 34:
            var same = 1
            var k = 0
            while k < len(kb):
                if Int(raw[i + 1 + k]) != Int(kb[k]):
                    same = 0
                k += 1
            if same == 1 and Int(raw[i + 1 + len(kb)]) == 34:
                return i + 2 + len(kb)
        i += 1
    raise FormatError(0, String("schema is missing ") + key)


def _string_value(text: String, key: String) raises -> String:
    var raw = text.as_bytes()
    var pos = _find_key(text, key)
    while pos < len(raw) and Int(raw[pos]) != 34:
        pos += 1
    if pos >= len(raw):
        raise FormatError(pos, String("schema string is missing"))
    pos += 1
    var tmp = List[Byte]()
    while pos < len(raw) and Int(raw[pos]) != 34:
        tmp.append(raw[pos])
        pos += 1
    if len(tmp) == 0:
        return String()
    return String(unsafe_from_utf8=Span(tmp))


def _int_value(text: String, key: String) raises -> Int:
    var raw = text.as_bytes()
    var pos = _find_key(text, key)
    while pos < len(raw) and (Int(raw[pos]) < 48 or Int(raw[pos]) > 57):
        pos += 1
    if pos >= len(raw):
        raise FormatError(pos, String("schema integer is missing"))
    var n = 0
    while pos < len(raw) and Int(raw[pos]) >= 48 and Int(raw[pos]) <= 57:
        n = n * 10 + (Int(raw[pos]) - 48)
        pos += 1
    return n


def parse_schema_text(text: String) raises -> Schema:
    var schema = Schema()
    schema.name = _string_value(text, String("name"))
    schema.dataset = _string_value(text, String("dataset"))
    schema.dtype = _string_value(text, String("dtype"))
    schema.rank = _int_value(text, String("rank"))
    if schema.rank != 1:
        raise FormatError(0, String("code generation supports rank 1 only"))
    if schema.dtype != String("float64"):
        raise FormatError(0, String("code generation supports float64 only"))
    return schema^


def parse_schema_file(path: String) raises -> Schema:
    var handle = open(path, "r")
    var data = handle.read_bytes()
    handle.close()
    return parse_schema_text(String(unsafe_from_utf8=Span(data)))
