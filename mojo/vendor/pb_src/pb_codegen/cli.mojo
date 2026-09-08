from std.collections import Dict, List, Optional
from std.os.process import Process
from std.sys import argv

from pb_codegen.emit import emit_file, output_path, stem_of, EmitError
from pb_codegen.names import mojo_type_name, safe_stem
from pb_descriptor.decode import decode_file_descriptor_set
from pb_descriptor.model import FileDescSet, proto3_error


def _usage() -> String:
    return (
        "gld-protoc-mojo --out DIR [--descriptor-set FILE | --proto FILE ...] "
        "[--proto-path DIR] [--module-prefix P] [--protoc BIN] [--unknown preserve|skip]"
    )


def _arg_eq(a: String, b: String) -> Bool:
    return a == b


def _mkdir_p(path: String) raises:
    if path.byte_length() == 0 or path == ".":
        return
    var args = List[String]()
    args.append("-p")
    args.append(path)
    var proc = Process.run("mkdir", args)
    _ = proc.wait()


def _is_under(path: String, root: String) -> Bool:
    if path == root:
        return True
    var prefix = root + "/"
    if path.byte_length() < prefix.byte_length():
        return False
    for i in range(prefix.byte_length()):
        if path.as_bytes()[i] != prefix.as_bytes()[i]:
            return False
    return True


def _parent_dir(path: String) raises -> String:
    var last = -1
    for i in range(path.byte_length()):
        if path.as_bytes()[i] == Byte(ord("/")):
            last = i
    if last <= 0:
        return "."
    var buf = List[Byte]()
    for i in range(last):
        buf.append(path.as_bytes()[i])
    return String(from_utf8=buf)


def _read_all_bytes(path: String) raises -> List[Byte]:
    var f = open(path, "r")
    var data = f.read_bytes()
    f.close()
    return data^


def _write_text(path: String, body: String) raises:
    _mkdir_p(_parent_dir(path))
    var f = open(path, "w")
    f.write(body)
    f.close()


def _basename(path: String) raises -> String:
    var start = 0
    for i in range(path.byte_length()):
        if path.as_bytes()[i] == Byte(ord("/")):
            start = i + 1
    var buf = List[Byte]()
    for i in range(start, path.byte_length()):
        buf.append(path.as_bytes()[i])
    return String(from_utf8=buf)


def _run_protoc(
    protoc: String, proto_paths: List[String], protos: List[String], tmp: String
) raises:
    var args = List[String]()
    args.append("--descriptor_set_out=" + tmp)
    args.append("--include_imports")
    for i in range(len(proto_paths)):
        args.append("-I" + proto_paths[i])
    for i in range(len(protos)):
        args.append(protos[i])
    try:
        var proc = Process.run(protoc, args)
        var status = proc.wait()
        if (
            not status.has_exited()
            or status.term_signal
            or status.exit_code != Optional(0)
        ):
            raise Error("protoc failed")
    except _:
        raise Error(
            "protoc not found; install protobuf-compiler or pass --descriptor-set"
        )


def main() raises:
    var args = argv()
    var out_dir = String()
    var module_prefix = String()
    var descriptor_set = String()
    var protoc = String("protoc")
    var unknown = String("preserve")
    var proto_paths = List[String]()
    var protos = List[String]()
    var i = 1
    while i < len(args):
        var a = String(args[i])
        if a == "--out" and i + 1 < len(args):
            i += 1
            out_dir = String(args[i])
        elif a == "--module-prefix" and i + 1 < len(args):
            i += 1
            module_prefix = String(args[i])
        elif a == "--descriptor-set" and i + 1 < len(args):
            i += 1
            descriptor_set = String(args[i])
        elif a == "--protoc" and i + 1 < len(args):
            i += 1
            protoc = String(args[i])
        elif a == "--unknown" and i + 1 < len(args):
            i += 1
            unknown = String(args[i])
        elif a == "--proto-path" and i + 1 < len(args):
            i += 1
            proto_paths.append(String(args[i]))
        elif a == "--proto" and i + 1 < len(args):
            i += 1
            protos.append(String(args[i]))
        elif a == "--" or a == "--help" or a == "-h":
            if a == "--":
                i += 1
                continue
            print(_usage())
            return
        else:
            raise Error("unknown argument: " + a + "\n" + _usage())
        i += 1

    if out_dir.byte_length() == 0:
        raise Error("--out is required\n" + _usage())
    if unknown != "skip" and unknown != "preserve":
        raise Error("--unknown must be preserve or skip\n" + _usage())
    if unknown == "skip":
        print(
            "warning: --unknown skip deviates from official proto3 (unknown fields are dropped)"
        )
    var preserve = unknown == "preserve"

    var blob: List[Byte]
    if descriptor_set.byte_length() != 0:
        blob = _read_all_bytes(descriptor_set)
    else:
        if len(protos) == 0:
            raise Error("--proto or --descriptor-set is required")
        var tmp = String("/tmp/gld-protobuf-fds.bin")
        _run_protoc(protoc, proto_paths, protos, tmp)
        blob = _read_all_bytes(tmp)

    var set = decode_file_descriptor_set(blob)
    for fi in range(len(set.files)):
        var err = proto3_error(set.files[fi].copy())
        if err.byte_length() != 0:
            raise Error(err)

    var emit_names = List[String]()
    for pi in range(len(protos)):
        emit_names.append(_basename(protos[pi]))

    var init_text = Dict[String, String]()
    for fi in range(len(set.files)):
        var file = set.files[fi].copy()
        var should = len(emit_names) == 0
        for ei in range(len(emit_names)):
            if file.name == emit_names[ei] or _basename(file.name) == emit_names[ei]:
                should = True
        if not should:
            continue
        var body: String
        try:
            body = emit_file(set, file.copy(), preserve)
        except e:
            raise Error(e.message)
        var stem = safe_stem(file.name)
        var path = output_path(out_dir, module_prefix, file.package, stem)
        _write_text(path, body)
        var exported = List[String]()
        for ei in range(len(file.enums)):
            var en = mojo_type_name(file.enums[ei].name)
            exported.append(en)
            for vi in range(len(file.enums[ei].values)):
                exported.append(en + "_" + file.enums[ei].values[vi].name)
        for mi in range(len(file.messages)):
            if file.messages[mi].map_entry:
                continue
            exported.append(mojo_type_name(file.messages[mi].dotted_name()))
            for nj in range(len(file.messages[mi].enums)):
                var nen = mojo_type_name(
                    file.messages[mi].dotted_name()
                    + "."
                    + file.messages[mi].enums[nj].name
                )
                exported.append(nen)
                for vi in range(len(file.messages[mi].enums[nj].values)):
                    exported.append(
                        nen + "_" + file.messages[mi].enums[nj].values[vi].name
                    )
        var export_dir = _parent_dir(path)
        if (
            export_dir.byte_length() != 0
            and export_dir != out_dir
            and len(exported) != 0
        ):
            var text = String("from .") + stem + " import (\n"
            for i in range(len(exported)):
                text += "    " + exported[i]
                if i + 1 != len(exported):
                    text += ","
                text += "\n"
            text += ")\n"
            if export_dir in init_text:
                init_text[export_dir] = init_text[export_dir] + text
            else:
                init_text[export_dir] = text
            var pkg_dir = _parent_dir(export_dir)
            if pkg_dir != out_dir and pkg_dir != "." and _is_under(pkg_dir, out_dir):
                if pkg_dir not in init_text:
                    init_text[pkg_dir] = String()
                var top = _parent_dir(pkg_dir)
                if top != out_dir and top != "." and _is_under(top, out_dir):
                    if top not in init_text:
                        init_text[top] = String()

    for d in init_text:
        _write_text(d + "/__init__.mojo", init_text[d])
