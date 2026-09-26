from std.collections import List
from std.os.process import Process
from std.sys import argv

from avro_codegen.emit import emit_records
from avro_schema.model import SchemaPool
from avro_schema.parse_avdl import parse_avdl
from avro_schema.parse_avsc import parse_avsc


def _usage() -> String:
    return "gld-avrogen-mojo --out DIR [--schema FILE | --idl FILE]"


def _mkdir_p(path: String) raises:
    if path.byte_length() == 0 or path == ".":
        return
    var args = List[String]()
    args.append("-p")
    args.append(path)
    var proc = Process.run("mkdir", args)
    _ = proc.wait()


def _read_text(path: String) raises -> String:
    var f = open(path, "r")
    var s = String(f.read())
    f.close()
    return s


def _write_text(path: String, body: String) raises:
    var f = open(path, "w")
    f.write(body)
    f.close()


def _parent_dir(path: String) -> String:
    var last = -1
    var i = 0
    var b = path.as_bytes()
    while i < len(b):
        if Int(b[i]) == 47:
            last = i
        i += 1
    if last <= 0:
        return String(".")
    var out = List[Byte]()
    var j = 0
    while j < last:
        out.append(b[j])
        j += 1
    try:
        return String(from_utf8=out)
    except _:
        return String(".")


def main() raises:
    var args = argv()
    var out_dir = String()
    var schema_path = String()
    var idl_path = String()
    var i = 1
    while i < len(args):
        if args[i] == "--out" and i + 1 < len(args):
            i += 1
            out_dir = String(args[i])
        elif args[i] == "--schema" and i + 1 < len(args):
            i += 1
            schema_path = String(args[i])
        elif args[i] == "--idl" and i + 1 < len(args):
            i += 1
            idl_path = String(args[i])
        elif args[i] == "--help" or args[i] == "-h":
            print(_usage())
            return
        i += 1
    if out_dir.byte_length() == 0 or (
        schema_path.byte_length() == 0 and idl_path.byte_length() == 0
    ):
        print(_usage())
        return
    var text: String
    var pool: SchemaPool
    if idl_path.byte_length() > 0:
        text = _read_text(idl_path)
        pool = parse_avdl(text)
    else:
        text = _read_text(schema_path)
        pool = parse_avsc(text)
    var files = emit_records(pool, out_dir)
    var fi = 0
    while fi < len(files):
        var path = files[fi]
        fi += 1
        var body = files[fi]
        fi += 1
        _mkdir_p(_parent_dir(path))
        _write_text(path, body)
        print("wrote " + path)
