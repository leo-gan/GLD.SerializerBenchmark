from std.collections import List, Span
from std.os.process import Process

from hdf5_runtime.bytes import append_f64, copy_bytes, load_f64
from hdf5_runtime.doc import BpStep
from hdf5_runtime.error import FormatError


def _write_file(path: String, data: List[Byte]) raises:
    var f = open(path, "w")
    f.write_bytes(Span(data))
    f.close()


def _read_file(path: String) raises -> List[Byte]:
    var f = open(path, "r")
    var data = f.read_bytes()
    f.close()
    return data^


def _meta(step: BpStep) -> List[Byte]:
    var text = String("GLD-BP5\nversion 1\nvar ") + step.var_name + String("\ncount ") + String(len(step.values))
    text = text + String("\nattr ") + step.attr_name + String("\ntext ") + step.attr_text + String("\n")
    var raw = text.as_bytes()
    var out = List[Byte]()
    var i = 0
    while i < len(raw):
        out.append(raw[i])
        i += 1
    return out^


def _mkdir(path: String) raises:
    var args = List[String]()
    args.append(String("-p"))
    args.append(path)
    var proc = Process.run(String("mkdir"), args^)
    _ = proc.wait()


def write_bp5(path: String, step: BpStep) raises:
    """Write one BP5 directory.

    `data.0` is the raw little-endian payload, which is the BP5 data-file
    layout for an uncompressed local array. `md.idx`, `md.0`, and `mmd.0`
    carry a pure-Mojo metadata record. That record is not FFS, so `bpls`
    does not open the directory. `read_bp5` does.
    """
    if step.var_name.byte_length() == 0:
        raise FormatError(0, String("BP5 variable name is empty"))
    _mkdir(path)
    var data = List[Byte]()
    var i = 0
    while i < len(step.values):
        append_f64(data, step.values[i])
        i += 1
    var meta = _meta(step)
    _write_file(path + String("/data.0"), data^)
    _write_file(path + String("/md.idx"), copy_bytes(meta))
    _write_file(path + String("/md.0"), copy_bytes(meta))
    var mmd_bytes = List[Byte]()
    var note = String("not-ffs\n").as_bytes()
    i = 0
    while i < len(note):
        mmd_bytes.append(note[i])
        i += 1
    i = 0
    while i < len(meta):
        mmd_bytes.append(meta[i])
        i += 1
    _write_file(path + String("/mmd.0"), mmd_bytes^)


def _field(text: String, key: String) raises -> String:
    var raw = text.as_bytes()
    var kb = key.as_bytes()
    var i = 0
    while i + len(kb) <= len(raw):
        var same = 1
        var k = 0
        while k < len(kb):
            if Int(raw[i + k]) != Int(kb[k]):
                same = 0
            k += 1
        if same == 1 and (i == 0 or Int(raw[i - 1]) == 10):
            var start = i + len(kb)
            var tmp = List[Byte]()
            while start < len(raw) and Int(raw[start]) != 10:
                tmp.append(raw[start])
                start += 1
            if len(tmp) == 0:
                return String()
            return String(unsafe_from_utf8=Span(tmp))
        i += 1
    raise FormatError(0, String("BP5 metadata field is missing"))


def _parse_int(text: String) raises -> Int:
    var raw = text.as_bytes()
    var n = 0
    var i = 0
    if len(raw) == 0:
        raise FormatError(0, String("empty integer"))
    while i < len(raw):
        var c = Int(raw[i])
        if c < 48 or c > 57:
            raise FormatError(0, String("bad integer"))
        n = n * 10 + (c - 48)
        i += 1
    return n


def read_bp5(path: String) raises -> BpStep:
    """Read one step written by `write_bp5`."""
    var idx = _read_file(path + String("/md.idx"))
    var data = _read_file(path + String("/data.0"))
    var text = String(unsafe_from_utf8=Span(idx))
    if text.byte_length() < 7:
        raise FormatError(0, String("BP5 metadata is empty"))
    var step = BpStep()
    step.var_name = _field(text, String("var "))
    var count = _parse_int(_field(text, String("count ")))
    step.attr_name = _field(text, String("attr "))
    step.attr_text = _field(text, String("text "))
    if len(data) < count * 8:
        raise FormatError(0, String("BP5 data file is shorter than the variable"))
    var i = 0
    while i < count:
        step.values.append(load_f64(Span(data), i * 8))
        i += 1
    return step^
