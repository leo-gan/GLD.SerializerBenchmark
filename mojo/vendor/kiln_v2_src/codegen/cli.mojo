from std.collections import List
from std.os.process import Process
from std.sys import argv

from codegen.emit import emit_source
from kiln.schema import schema_from_json


def _usage() -> String:
    return "gld-kilngen-mojo --schema FILE --out DIR"


def _stem(path: String) -> String:
    var raw = path.as_bytes()
    var start = 0
    var i = 0
    while i < len(raw):
        if Int(raw[i]) == 47:
            start = i + 1
        i += 1
    var end = len(raw)
    i = start
    while i < len(raw):
        if Int(raw[i]) == 46:
            end = i
            break
        i += 1
    var name = String()
    i = start
    while i < end:
        name = name + chr(Int(raw[i]))
        i += 1
    if name.byte_length() == 0:
        return "Root"
    return name


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
    var f = open(schema_path, "r")
    var text = f.read()
    f.close()
    var schema = schema_from_json(text)
    var source = emit_source(schema)
    var mkdir_args = List[String]()
    mkdir_args.append("-p")
    mkdir_args.append(out_dir)
    var proc = Process.run("mkdir", mkdir_args)
    _ = proc.wait()
    var file_name = schema.name[schema.root]
    if file_name.byte_length() == 0:
        file_name = _stem(schema_path)
    var path = out_dir + "/" + file_name + ".mojo"
    var out = open(path, "w")
    out.write(source)
    out.close()
    print("wrote", path)
