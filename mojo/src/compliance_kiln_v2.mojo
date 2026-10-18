"""Score compliance/data/kiln/v2.json with gld-kiln 0.3.0.

Compile against vendor/kiln_v2_src, not vendor/kiln_src. The bench pin stays
0.2.0. This program does not time anything.
"""

from std.collections import List, Span
from std.sys import argv
from emberjson import Value, parse
from kiln import KilnError, TensorDir, decode, decode_framed, type_hash
from kiln.tensor import (
    DTYPE_BF16,
    DTYPE_BOOL,
    DTYPE_E2M1,
    DTYPE_E8M0,
    DTYPE_F16,
    DTYPE_F32,
    DTYPE_F64,
    DTYPE_F8E4M3,
    DTYPE_F8E5M2,
    DTYPE_I16,
    DTYPE_I32,
    DTYPE_I4,
    DTYPE_I64,
    DTYPE_I8,
    DTYPE_U16,
    DTYPE_U32,
    DTYPE_U4,
    DTYPE_U64,
    DTYPE_U8,
)


@fieldwise_init
struct OneI64(Copyable, Movable, Defaultable):
    var a: Int64

    def __init__(out self):
        self.a = 0


@fieldwise_init
struct IdBatch(Copyable, Movable, Defaultable):
    var id: Int64
    var batch: TensorDir

    def __init__(out self):
        self.id = 0
        self.batch = TensorDir()


def _hex_nibble(c: Int) -> Int:
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 97 and c <= 102:
        return c - 87
    if c >= 65 and c <= 70:
        return c - 55
    return -1


def _hex_bytes(s: String) -> List[UInt8]:
    var raw = s.as_bytes()
    var compact = List[UInt8]()
    var i = 0
    while i < len(raw):
        var c = Int(raw[i])
        if c != 32 and c != 10 and c != 13 and c != 9:
            compact.append(raw[i])
        i += 1
    var out = List[UInt8]()
    i = 0
    while i + 1 < len(compact):
        var hi = _hex_nibble(Int(compact[i]))
        var lo = _hex_nibble(Int(compact[i + 1]))
        if hi < 0 or lo < 0:
            i += 2
            continue
        out.append(UInt8(hi * 16 + lo))
        i += 2
    return out^


def _esc(s: String) -> String:
    var out = String("\"")
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 92:
            out += "\\\\"
        elif c == 34:
            out += "\\\""
        elif c == 10:
            out += "\\n"
        elif c == 13:
            out += "\\r"
        elif c == 9:
            out += "\\t"
        elif c < 32:
            out += " "
        else:
            out += String(chr(c))
        i += 1
    out += "\""
    return out^


def _dtype_name(code: Int) -> String:
    if code == DTYPE_F64:
        return "f64"
    if code == DTYPE_F32:
        return "f32"
    if code == DTYPE_F16:
        return "f16"
    if code == DTYPE_BF16:
        return "bf16"
    if code == DTYPE_F8E4M3:
        return "f8e4m3"
    if code == DTYPE_F8E5M2:
        return "f8e5m2"
    if code == DTYPE_BOOL:
        return "bool"
    if code == DTYPE_I8:
        return "i8"
    if code == DTYPE_U8:
        return "u8"
    if code == DTYPE_I16:
        return "i16"
    if code == DTYPE_U16:
        return "u16"
    if code == DTYPE_I32:
        return "i32"
    if code == DTYPE_U32:
        return "u32"
    if code == DTYPE_I64:
        return "i64"
    if code == DTYPE_U64:
        return "u64"
    if code == DTYPE_I4:
        return "i4"
    if code == DTYPE_U4:
        return "u4"
    if code == DTYPE_E2M1:
        return "e2m1"
    if code == DTYPE_E8M0:
        return "e8m0"
    return String(code)


def _hex_lower(data: List[UInt8]) -> String:
    var out = String()
    var i = 0
    while i < len(data):
        var b = Int(data[i])
        var hi = b >> 4
        var lo = b & 15
        var hc = 48 + hi
        if hi >= 10:
            hc = 87 + hi
        var lc = 48 + lo
        if lo >= 10:
            lc = 87 + lo
        out += String(chr(hc))
        out += String(chr(lc))
        i += 1
    return out^


def _u64_of(v: Value) raises -> UInt64:
    if v.is_uint():
        return v.uint()
    if v.is_int():
        var n = v.int()
        if n < 0:
            raise Error("negative integer")
        return UInt64(n)
    if v.is_float():
        return UInt64(v.float())
    raise Error("expected an integer")


def _flags_ok(named: Bool, expected: Value) raises -> Bool:
    var arr = expected.object()["flags"].array().copy()
    if named:
        if len(arr) != 2:
            return False
        return String(arr[0].string()) == "names" and String(arr[1].string()) == "le"
    if len(arr) != 1:
        return False
    return String(arr[0].string()) == "le"


def _dir_ok(dir: TensorDir, expected: Value) raises -> Bool:
    if Int(_u64_of(expected.object()["version"])) != 2:
        return False
    var want_block = Int(_u64_of(expected.object()["block_length"]))
    if dir.kiln_size() != want_block:
        raise Error("block " + String(dir.kiln_size()) + " != " + String(want_block))
    var named = False
    var i = 0
    while i < len(dir.items):
        if dir.items[i].name.byte_length() > 0:
            named = True
        i += 1
    if not _flags_ok(named, expected):
        return False
    var tensors = expected.object()["tensors"].array().copy()
    if len(tensors) != len(dir.items):
        return False
    i = 0
    while i < len(dir.items):
        var want = tensors[i].object().copy()
        var got = dir.items[i].copy()
        var want_name = want["name"].copy()
        if want_name.is_null():
            if got.name.byte_length() != 0:
                return False
        elif String(want_name.string()) != got.name:
            return False
        var want_dtype = ""
        var dtype_v = want["dtype"].copy()
        if dtype_v.is_string():
            want_dtype = String(dtype_v.string())
        else:
            want_dtype = String(Int(_u64_of(dtype_v)))
        if want_dtype != _dtype_name(got.dtype):
            raise Error("dtype " + _dtype_name(got.dtype) + " != " + want_dtype)
        var shape = want["shape"].array().copy()
        if len(shape) != len(got.shape):
            return False
        var s = 0
        while s < len(shape):
            if _u64_of(shape[s]) != got.shape[s]:
                return False
            s += 1
        if Int(_u64_of(want["quant_scheme"])) != got.quant_scheme:
            return False
        if String(want["data_hex"].string()) != _hex_lower(got.data):
            return False
        i += 1
    return True


def _list_f32_ok(got: List[Float32], expected: Value) raises -> Bool:
    if not expected.is_array() or len(got) != len(expected.array()):
        return False
    var i = 0
    while i < len(got):
        var want = Float64(got[i])
        var item = expected.array()[i].copy()
        var same = False
        if item.is_float():
            same = want == item.float()
        elif item.is_int():
            same = want == Float64(item.int())
        elif item.is_uint():
            same = want == Float64(item.uint())
        if not same:
            return False
        i += 1
    return True


def _kind_text(e: Error) -> String:
    return String(e)


def _raise_kiln(e: KilnError) raises:
    var text = String("KilnError(kind=")
    text += String(e.kind)
    text += ", offset="
    text += String(e.offset)
    text += ")"
    raise Error(text)


def _check(buf: List[UInt8], schema: Value, expected: Value, has_decoded: Bool) raises:
    if schema.is_string():
        var name = String(schema.string())
        if name == "tensor-v2":
            var got = TensorDir()
            try:
                got = decode[TensorDir](Span(buf))
            except e:
                _raise_kiln(e)
            if has_decoded and not _dir_ok(got, expected):
                raise Error("decoded value does not match")
            return
        if name == "frame":
            var got = IdBatch()
            try:
                got = decode_framed[IdBatch](Span(buf))
            except e:
                _raise_kiln(e)
            if not has_decoded:
                return
            if got.id != Int64(_u64_of(expected.object()["id"])):
                raise Error("decoded value does not match")
            if type_hash[IdBatch]() != _u64_of(expected.object()["hash"]):
                raise Error("decoded value does not match")
            if not _dir_ok(got.batch, expected.object()["batch"]):
                raise Error("decoded value does not match")
            return
        raise Error("no kiln v2 schema")
    var kind = String(schema.object()["type"].string())
    if kind == "list":
        var elem = String(schema.object()["element"].string())
        if elem == "f32":
            var got = List[Float32]()
            try:
                got = decode[List[Float32]](Span(buf))
            except e:
                _raise_kiln(e)
            if has_decoded and not _list_f32_ok(got, expected):
                raise Error("decoded value does not match")
            return
        if elem == "str":
            try:
                _ = decode[List[String]](Span(buf))
            except e:
                _raise_kiln(e)
            return
        if elem == "struct{a:i64}":
            try:
                _ = decode[List[OneI64]](Span(buf))
            except e:
                _raise_kiln(e)
            return
        raise Error("no kiln v2 schema")
    if kind == "struct":
        var got = IdBatch()
        try:
            got = decode[IdBatch](Span(buf))
        except e:
            _raise_kiln(e)
        if has_decoded:
            if got.id != Int64(_u64_of(expected.object()["id"])):
                raise Error("decoded value does not match")
            if not _dir_ok(got.batch, expected.object()["batch"]):
                raise Error("decoded value does not match")
        return
    raise Error("no kiln v2 schema")


def _row(
    id: String,
    standard: String,
    standard_url: String,
    version: String,
    requirement: String,
    expect: String,
    section: String,
    section_title: String,
    section_url: String,
    paragraph: String,
    title: String,
    input_text: String,
    enc: String,
    observed: String,
    outcome: String,
    detail: String,
) -> String:
    return (
        "{\"id\":"
        + _esc(id)
        + ",\"language\":\"mojo\",\"serializer\":\"gld-kiln\",\"serializer_version\":\"0.3.0\",\"format\":\"kiln\",\"standard\":"
        + _esc(standard)
        + ",\"standard_url\":"
        + _esc(standard_url)
        + ",\"version\":"
        + _esc(version)
        + ",\"version_key\":"
        + _esc("kiln." + version)
        + ",\"requirement\":"
        + _esc(requirement)
        + ",\"expect\":"
        + _esc(expect)
        + ",\"section\":"
        + _esc(section)
        + ",\"section_title\":"
        + _esc(section_title)
        + ",\"section_url\":"
        + _esc(section_url)
        + ",\"paragraph\":"
        + _esc(paragraph)
        + ",\"title\":"
        + _esc(title)
        + ",\"input\":"
        + _esc(input_text)
        + ",\"input_encoding\":"
        + _esc(enc)
        + ",\"detail\":"
        + _esc(detail)
        + ",\"observed\":"
        + _esc(observed)
        + ",\"outcome\":"
        + _esc(outcome)
        + "}"
    )


def _field(obj: Value, key: String) -> String:
    try:
        return String(obj.object()[key].string())
    except:
        return String("")


def main() raises:
    var args = argv()
    var catalog = ""
    var json_out = ""
    var i = 1
    while i < len(args):
        var a = String(args[i])
        if a == "--catalog" and i + 1 < len(args):
            catalog = String(args[i + 1])
            i += 2
            continue
        if a == "--json-out" and i + 1 < len(args):
            json_out = String(args[i + 1])
            i += 2
            continue
        i += 1
    if catalog.byte_length() == 0 or json_out.byte_length() == 0:
        raise Error("--catalog and --json-out are required")
    var suite = parse(open(catalog, "r").read())
    var standard = _field(suite, "standard")
    var version = _field(suite, "version")
    var standard_url = _field(suite, "standard_url")
    var cases = suite.object()["cases"].array().copy()
    var rows = String("[")
    var passed = 0
    var failed = 0
    var ci = 0
    while ci < len(cases):
        var c = Value(cases[ci].object().copy())
        var id = _field(c, "id")
        var expect = _field(c, "expect")
        var title = _field(c, "title")
        var section = _field(c, "section")
        var section_title = _field(c, "section_title")
        var section_url = _field(c, "section_url")
        var paragraph = _field(c, "paragraph")
        var requirement = _field(c, "requirement")
        var input_text = _field(c, "input")
        var enc = _field(c, "input_encoding")
        if enc.byte_length() == 0:
            enc = "utf-8"
        var schema = c["schema"].copy()
        var has_decoded = False
        var expected = Value()
        try:
            expected = c["decoded"].copy()
            has_decoded = True
        except:
            has_decoded = False
        var known = False
        if schema.is_string():
            var name = String(schema.string())
            known = name == "tensor-v2" or name == "frame"
        else:
            var kind = String(schema.object()["type"].string())
            if kind == "struct":
                known = True
            elif kind == "list":
                var elem = String(schema.object()["element"].string())
                known = elem == "f32" or elem == "str" or elem == "struct{a:i64}"
        var observed = ""
        var outcome = ""
        var detail = ""
        if not known:
            observed = "no schema"
            outcome = "error"
            detail = "no kiln v2 schema for this case"
        else:
            var ok = False
            var err = ""
            try:
                _check(_hex_bytes(input_text), schema, expected, has_decoded)
                ok = True
            except e:
                ok = False
                err = _kind_text(e)
            if expect == "reject":
                if ok:
                    observed = "accepted"
                    outcome = "fail"
                    detail = "parser accepted input the spec requires to be rejected"
                else:
                    observed = err
                    outcome = "pass"
            else:
                if ok:
                    observed = "ok"
                    outcome = "pass"
                else:
                    observed = err
                    outcome = "fail"
                    detail = err
        if outcome == "pass":
            passed += 1
        else:
            failed += 1
        if ci > 0:
            rows += ","
        rows += _row(
            id,
            standard,
            standard_url,
            version,
            requirement,
            expect,
            section,
            section_title,
            section_url,
            paragraph,
            title,
            input_text,
            enc,
            observed,
            outcome,
            detail,
        )
        ci += 1
    rows += "]"
    var head = (
        "{\"schema\":\"gld.dashboard.compliance/1\",\"generated_at\":\"\",\"language\":\"mojo\",\"languages\":[\"mojo\"],\"policy\":\"report-only\",\"scope\":{\"formats\":[\"kiln\"]},\"passed\":"
        + String(passed)
        + ",\"failed\":"
        + String(failed)
        + ",\"skipped\":0,\"errors\":0,\"catalog_errors\":[],\"serializer_errors\":[],\"results\":"
    )
    with open(json_out, "w") as f:
        f.write(head)
        f.write(rows)
        f.write("}\n")
    print(passed, "pass", failed, "fail", len(cases), "total")
    print("Wrote", json_out)
