from std.collections import List
from std.os.process import Process
from std.sys import argv

from fb_codegen.emit import emit_module
from fb_schema.bfbs import parse_bfbs_file
from fb_schema.fbs import parse_fbs_file


def _usage() -> String:
    return "gld-flatc-mojo (--fbs FILE | --bfbs FILE) --out DIR"


def _parent(path: String) raises -> String:
    var raw = path.as_bytes()
    var last = -1
    for i in range(len(raw)):
        if raw[i] == Byte(ord("/")):
            last = i
    if last <= 0:
        return "."
    var buf = List[Byte]()
    for i in range(last):
        buf.append(raw[i])
    return String(from_utf8=Span(buf))


def _stem(path: String) raises -> String:
    var raw = path.as_bytes()
    var start = 0
    var end = len(raw)
    for i in range(len(raw)):
        if raw[i] == Byte(ord("/")):
            start = i + 1
        if raw[i] == Byte(ord(".")):
            end = i
    if end < start:
        end = len(raw)
    var buf = List[Byte]()
    for i in range(start, end):
        buf.append(raw[i])
    return String(from_utf8=Span(buf))


def _mkdir(path: String) raises:
    if path == "" or path == ".":
        return
    var args = List[String]()
    args.append("-p")
    args.append(path)
    var proc = Process.run("mkdir", args)
    _ = proc.wait()


def _write(path: String, body: String) raises:
    _mkdir(_parent(path))
    var handle = open(path, "w")
    handle.write(body)
    handle.close()


def main() raises:
    var args = argv()
    var fbs = String()
    var bfbs = String()
    var out_dir = String()
    var i = 1
    while i < len(args):
        var arg = args[i]
        if arg == "--fbs":
            i += 1
            fbs = args[i]
        elif arg == "--bfbs":
            i += 1
            bfbs = args[i]
        elif arg == "--out":
            i += 1
            out_dir = args[i]
        elif arg == "--help":
            print(_usage())
            return
        else:
            raise Error("unknown argument " + arg)
        i += 1
    if out_dir.byte_length() == 0 or (fbs.byte_length() == 0 and bfbs.byte_length() == 0):
        raise Error(_usage())
    if fbs.byte_length() != 0:
        var schema = parse_fbs_file(fbs)
        var body = emit_module(schema)
        var path = out_dir + "/" + _stem(fbs) + ".mojo"
        _write(path, body)
        print(path)
    else:
        var schema = parse_bfbs_file(bfbs)
        var body = emit_module(schema)
        var path = out_dir + "/" + _stem(bfbs) + ".mojo"
        _write(path, body)
        print(path)
