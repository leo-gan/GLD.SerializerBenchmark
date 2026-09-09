from std.collections import List
from std.os.process import Process
from std.sys import argv

from gldjson_codegen.emit import emit_all
from gldjson_schema.parse import parse_schema_file


def _usage() -> String:
    return "gld-jsongen-mojo --schema FILE --out DIR"


def _mkdir_p(path: String) raises:
    if path.byte_length() == 0 or path == ".":
        return
    var args = List[String]()
    args.append("-p")
    args.append(path)
    var proc = Process.run("mkdir", args)
    _ = proc.wait()


def _write_text(path: String, body: String) raises:
    var f = open(path, "w")
    f.write(body)
    f.close()


def main() raises:
    var args = argv()
    var out_dir = String()
    var schema_path = String()
    var i = 1
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
    var doc = parse_schema_file(schema_path)
    var files = emit_all(doc)
    _mkdir_p(out_dir)
    var k = 0
    while k + 1 < len(files):
        var path = out_dir + "/" + files[k] + ".mojo"
        _write_text(path, files[k + 1])
        print("wrote", path)
        k += 2
