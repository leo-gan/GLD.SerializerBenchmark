from std.collections import List, Span
from std.os.process import Process
from std.sys import argv

from arrow_codegen.emit import emit_schema
from arrow_runtime.error import DecodeError
from arrow_runtime.model import Columnar
from arrow_schema.json import parse_json
from arrow_schema.load import load_schema
from arrow_wire.ipc import decode_ipc_file, decode_ipc_stream


def _generate(raw: List[Byte]) raises -> String:
    if _looks_json(raw):
        var doc = parse_json(Span(raw))
        var columnar = load_schema(Span(raw))
        return emit_schema(doc, columnar)
    var columnar = Columnar()
    try:
        columnar = decode_ipc_stream(Span(raw))
    except DecodeError:
        columnar = decode_ipc_file(Span(raw))
    var title = _meta_title(columnar)
    var wrapper = List[Byte]()
    var literal = "{\"title\":\"" + title + "\"}"
    var bytes = literal.as_bytes()
    var i = 0
    while i < len(bytes):
        wrapper.append(bytes[i])
        i += 1
    var doc = parse_json(Span(wrapper))
    return emit_schema(doc, columnar)


def _looks_json(raw: List[Byte]) -> Bool:
    var i = 0
    while i < len(raw):
        var c = Int(raw[i])
        if c != 32 and c != 9 and c != 10 and c != 13:
            return c == 123
        i += 1
    return False


def _meta_title(c: Columnar) -> String:
    var i = 0
    while i < c.nschema_meta:
        var k = c.meta_k[c.schema_meta0 + i]
        if c.strings[k] == "title":
            return c.strings[c.meta_v[c.schema_meta0 + i]]
        i += 1
    return "Root"


def _title_of(text: String) -> String:
    var key = "struct "
    var raw = text.as_bytes()
    var kb = key.as_bytes()
    var i = 0
    while i + len(kb) < len(raw):
        var ok = 1
        var k = 0
        while k < len(kb):
            if raw[i + k] != kb[k]:
                ok = 0
            k += 1
        if ok != 0:
            var start = i + len(kb)
            var end = start
            while end < len(raw) and Int(raw[end]) != 58:
                end += 1
            var name = List[Byte]()
            var j = start
            while j < end:
                name.append(raw[j])
                j += 1
            return String(unsafe_from_utf8=Span(name))
        i += 1
    return "Root"


def _usage() -> String:
    return "gld-arrowgen-mojo --schema FILE --out DIR"


def main() raises:
    var args = argv()
    var out_dir = String()
    var schema_path = String()
    var i = 1
    if len(args) > 1 and args[1] == "--":
        i = 2
    while i < len(args):
        if args[i] == "--out" and i + 1 < len(args):
            i += 1
            out_dir = String(args[i])
        elif args[i] == "--schema" and i + 1 < len(args):
            i += 1
            schema_path = String(args[i])
        elif args[i] == "--help" or args[i] == "-h":
            print(_usage())
            return
        i += 1
    if out_dir.byte_length() == 0 or schema_path.byte_length() == 0:
        print(_usage())
        return
    var raw = open(schema_path, "r").read_bytes()
    var text = _generate(raw)
    var mkdir_args = List[String]()
    mkdir_args.append("-p")
    mkdir_args.append(out_dir)
    var proc = Process.run("mkdir", mkdir_args)
    _ = proc.wait()
    var title = _title_of(text)
    var path = out_dir + "/" + title + ".mojo"
    var f = open(path, "w")
    f.write(text)
    f.close()
    print("wrote", path)
