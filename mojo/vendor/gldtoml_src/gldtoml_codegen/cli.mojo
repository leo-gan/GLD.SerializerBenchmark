from std.collections import List
from std.os.process import Process
from std.sys import argv

from gldtoml_codegen.emit import emit_all
from gldtoml_schema.parse import parse_schema_file


def _usage() -> String:
    return "gld-tomlgen-mojo --schema FILE --out DIR"


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
    var doc = parse_schema_file(schema_path)
    var files = emit_all(doc)
    var mkdir_args = List[String]()
    mkdir_args.append("-p")
    mkdir_args.append(out_dir)
    var proc = Process.run("mkdir", mkdir_args)
    _ = proc.wait()
    var k = 0
    while k + 1 < len(files):
        var path = out_dir + "/" + files[k] + ".mojo"
        var f = open(path, "w")
        f.write(files[k + 1])
        f.close()
        print("wrote", path)
        k += 2
