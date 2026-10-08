from std.collections import List
from std.sys import argv

from parquet_codegen.emit import emit_schema


def _arg(name: String) -> String:
    var args = argv()
    var i = 0
    while i < len(args):
        if args[i] == name and i + 1 < len(args):
            return args[i + 1]
        i += 1
    return ""


def main() raises:
    var schema = _arg("--schema")
    var out = _arg("--out")
    if schema == "" or schema == "--help" or _arg("--help") == "--help":
        print("gld-parquetgen-mojo --schema <file.json> --out <dir>")
        return
    var raw = open(schema, "r").read_bytes()
    var text = emit_schema(raw)
    var name = "Record"
    var marker = "struct "
    var bytes = text.as_bytes()
    var key = marker.as_bytes()
    var i = 0
    while i + len(key) < len(bytes):
        var ok = 1
        var k = 0
        while k < len(key):
            if bytes[i + k] != key[k]:
                ok = 0
            k += 1
        if ok != 0:
            var start = i + len(key)
            var end = start
            while end < len(bytes) and Int(bytes[end]) != 58:
                end += 1
            var buf = List[Byte]()
            var j = start
            while j < end:
                buf.append(bytes[j])
                j += 1
            name = String(unsafe_from_utf8=Span(buf))
            break
        i += 1
    var path = out + "/" + name + ".mojo"
    var f = open(path, "w")
    f.write_bytes(text.as_bytes())
    f.close()
    print(path)
