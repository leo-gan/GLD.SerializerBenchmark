"""Mojo compliance runner — same catalog as the other languages."""

from std.collections import List, Span
from std.os.process import Process
from std.sys import argv
from emberjson import parse, to_string
from ehsanmok_json import loads as ehsan_loads
from gldjson import decode_value as json_decode
from yaml import decode_all_values as yaml_decode_all
from cbor import decode_value as cbor_decode
from msgpack import decode_value as msgpack_decode
from bson_runtime.value import decode_document
from smile import decode_bytes as smile_decode
from ion import decode as ion_decode
from ion_runtime.symtab import Catalog
from toml import parse as toml_parse
from gldtoml import decode_toml as gld_decode_toml
from avro import GenericDatum, parse_avsc
from emberjson import Value
from fb_flex.kind import (
    F_BLOB,
    F_BOOL,
    F_FLOAT,
    F_INDIRECT_FLOAT,
    F_INDIRECT_INT,
    F_INDIRECT_UINT,
    F_INT,
    F_MAP,
    F_NULL,
    F_STRING,
    F_UINT,
    F_VECTOR,
)
from fb_flex.reader import FlexTree, flex_loads
from fb_wire.verify import verify_file_identifier, verify_root
from arrow_wire.ipc import decode_ipc_stream
from parquet_wire.decode import decode_table
from hdf5 import VERSION, read_bp5, read_cdf1, read_hdf5, read_nc4, write_bp5
from kiln import decode_framed, decode_value, read_f64, schema_from_json
from kiln.error import KilnError
from kiln.schema import (
    TY_BOOL,
    TY_BYTES,
    TY_DICT,
    TY_F32,
    TY_F64,
    TY_I16,
    TY_I32,
    TY_I64,
    TY_I8,
    TY_LIST,
    TY_OPT,
    TY_STR,
    TY_STRUCT,
    TY_U16,
    TY_U32,
    TY_U64,
    TY_U8,
    Schema,
)
from kiln.value import VK_NONE, Value as KilnValue


struct KilnPoint(Defaultable, Movable):
    """Destination type for the Kiln frame cases. Fields are i32 x then i32 y."""

    var x: Int32
    var y: Int32

    def __init__(out self):
        self.x = 0
        self.y = 0
from hdf5_runtime.doc import BpStep



def _contains(hay: String, needle: String) -> Bool:
    if needle.byte_length() == 0:
        return True
    var h = hay.as_bytes()
    var n = needle.as_bytes()
    if len(n) > len(h):
        return False
    var i = 0
    while i <= len(h) - len(n):
        var ok = True
        var j = 0
        while j < len(n):
            if Int(h[i + j]) != Int(n[j]):
                ok = False
                break
            j += 1
        if ok:
            return True
        i += 1
    return False


def _hex_nibble(c: Int) -> Int:
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 65 and c <= 70:
        return c - 55
    if c >= 97 and c <= 102:
        return c - 87
    return -1


def _hex_bytes(s: String) -> List[Byte]:
    var raw = s.as_bytes()
    var compact = List[Byte]()
    var i = 0
    while i < len(raw):
        var c = Int(raw[i])
        if c != 32 and c != 10 and c != 13 and c != 9:
            compact.append(raw[i])
        i += 1
    var out = List[Byte]()
    i = 0
    while i + 1 < len(compact):
        var hi = _hex_nibble(Int(compact[i]))
        var lo = _hex_nibble(Int(compact[i + 1]))
        if hi < 0 or lo < 0:
            i += 2
            continue
        out.append(Byte(hi * 16 + lo))
        i += 2
    return out^


def _too_deep(s: String) -> Bool:
    if s.byte_length() > 200000:
        return True
    var n = 0
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 91 or c == 123:
            n += 1
            if n > 4000:
                return True
        i += 1
    return False


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


def _utf8_bytes(s: String) -> List[Byte]:
    var raw = s.as_bytes()
    var out = List[Byte]()
    var i = 0
    while i < len(raw):
        out.append(raw[i])
        i += 1
    return out^


def _try_json(text: String) raises:
    _ = parse(text)


def _try_ehsan(text: String) raises:
    _ = ehsan_loads(text)


def _try_gldjson(text: String) raises:
    _ = json_decode(text.as_bytes())


def _try_yaml(text: String) raises:
    if text.byte_length() > 16384:
        raise Error("yaml input too large")
    _ = yaml_decode_all(text.as_bytes())


def _try_toml(text: String) raises:
    _ = toml_parse(text)


def _try_gldtoml(text: String) raises:
    _ = gld_decode_toml(text)


def _try_cbor(buf: List[Byte]) raises:
    _ = cbor_decode(buf)


def _try_msgpack(buf: List[Byte]) raises:
    _ = msgpack_decode(buf)


def _try_bson(buf: List[Byte]) raises:
    _ = decode_document(Span(buf))


def _try_smile(buf: List[Byte]) raises:
    _ = smile_decode(Span(buf))


def _try_arrow(buf: List[Byte]) raises:
    var decoded = decode_ipc_stream(Span(buf))
    # An empty buffer has no schema message. A real stream starts with one.
    if len(decoded.fields) == 0:
        raise Error("arrow ipc: missing schema")


def _try_parquet(buf: List[Byte]) raises:
    _ = decode_table(Span(buf))


def _try_hdf5(buf: List[Byte]) raises:
    _ = read_hdf5(Span(buf))


def _try_netcdf(buf: List[Byte]) raises:
    # Magic only picks which gld reader to call. Success is that reader returning.
    if len(buf) >= 4 and Int(buf[0]) == 67 and Int(buf[1]) == 68 and Int(buf[2]) == 70 and Int(buf[3]) == 1:
        _ = read_cdf1(Span(buf))
        return
    if len(buf) >= 4 and Int(buf[0]) == 67 and Int(buf[1]) == 68 and Int(buf[2]) == 70 and Int(buf[3]) == 2:
        raise Error("gld-netcdf has no CDF-2 reader")
    if len(buf) >= 4 and Int(buf[0]) == 0x89 and Int(buf[1]) == 72 and Int(buf[2]) == 68 and Int(buf[3]) == 70:
        _ = read_nc4(Span(buf))
        return
    raise Error("not a NetCDF file")


def _rm_rf(path: String) raises:
    var args = List[String]()
    args.append(String("-rf"))
    args.append(path)
    var proc = Process.run(String("rm"), args^)
    _ = proc.wait()


def _mkdir_p(path: String) raises:
    var args = List[String]()
    args.append(String("-p"))
    args.append(path)
    var proc = Process.run(String("mkdir"), args^)
    _ = proc.wait()


def _try_adios2(marker: String) raises:
    # The catalog names a directory entry. gld writes its own BP5 directory and
    # reads it back. It does not open an official ADIOS2 directory.
    if marker.byte_length() == 0:
        var empty = String("/tmp/gld-cmp-adios-empty")
        _rm_rf(empty)
        _mkdir_p(empty)
        _ = read_bp5(empty)
        return
    var root = String("/tmp/gld-cmp-adios-bp5")
    _rm_rf(root)
    var step = BpStep()
    step.var_name = String("grid")
    step.values.append(Float64(1.0))
    step.attr_name = String("unit")
    step.attr_text = String("1")
    write_bp5(root, step)
    var handle = open(root + String("/") + marker, "r")
    var data = handle.read_bytes()
    handle.close()
    if len(data) == 0:
        raise Error("BP5 entry is empty")
    _ = read_bp5(root)


def _try_ion(buf: List[Byte]) raises:
    _ = ion_decode(Span(buf), Catalog())


def _try_avro(buf: List[Byte], schema_json: String) raises:
    var text = schema_json
    if text.byte_length() == 0:
        text = "\"int\""
    var pool = parse_avsc(text)
    var g = GenericDatum(pool^)
    g.decode(buf)


def _is_flex_vector(kind: Int) -> Bool:
    return kind >= F_VECTOR and kind != F_BLOB and kind != F_BOOL


def _flex_int(tree: FlexTree, node: Int) -> Int64:
    var kind = tree.nodes[node].kind
    if kind == F_INT or kind == F_INDIRECT_INT:
        return tree.nodes[node].i
    if kind == F_UINT or kind == F_INDIRECT_UINT:
        return Int64(tree.nodes[node].u)
    return Int64(0)


def _hex_eq(blob: List[Byte], hextext: String) -> Bool:
    var want = _hex_bytes(hextext)
    if len(want) != len(blob):
        return False
    var i = 0
    while i < len(blob):
        if blob[i] != want[i]:
            return False
        i += 1
    return True


def _flex_matches(tree: FlexTree, node: Int, expected: Value) raises -> Bool:
    var kind = tree.nodes[node].kind
    if expected.is_null():
        return kind == F_NULL
    if expected.is_bool():
        if kind != F_BOOL:
            return False
        var on = tree.nodes[node].u != 0
        return on == expected.bool()
    if expected.is_string():
        return kind == F_STRING and tree.nodes[node].s == expected.string()
    if expected.is_int() or expected.is_uint():
        var want = expected.int()
        if kind == F_FLOAT or kind == F_INDIRECT_FLOAT:
            return tree.nodes[node].f == Float64(want)
        if kind == F_INT or kind == F_INDIRECT_INT or kind == F_UINT or kind == F_INDIRECT_UINT:
            return _flex_int(tree, node) == want
        return False
    if expected.is_float():
        var want = expected.float()
        if kind == F_FLOAT or kind == F_INDIRECT_FLOAT:
            return tree.nodes[node].f == want
        if kind == F_INT or kind == F_INDIRECT_INT or kind == F_UINT or kind == F_INDIRECT_UINT:
            return Float64(_flex_int(tree, node)) == want
        return False
    if expected.is_array():
        if not _is_flex_vector(kind):
            return False
        if len(tree.nodes[node].kids) != len(expected.array()):
            return False
        var i = 0
        while i < len(expected.array()):
            if not _flex_matches(tree, tree.nodes[node].kids[i], expected.array()[i]):
                return False
            i += 1
        return True
    if expected.is_object():
        if len(expected.object()) == 1:
            var hex_only = False
            var hextext = String("")
            try:
                hextext = String(expected.object()["$hex"].string())
                hex_only = True
            except:
                hex_only = False
            if hex_only:
                return kind == F_BLOB and _hex_eq(tree.nodes[node].blob, hextext)
        if kind != F_MAP:
            return False
        if len(tree.nodes[node].keys) != len(expected.object()):
            return False
        for key in expected.object().keys():
            var name = String(key)
            var child = tree.find(node, name)
            if child < 0:
                return False
            if not _flex_matches(tree, child, expected.object()[name]):
                return False
        return True
    return False


def _try_flatbuffers(buf: List[Byte], version: String, has_decoded: Bool, decoded_json: String) raises:
    if version == "flexbuffers":
        var tree = flex_loads(buf)
        if has_decoded:
            var expected = parse(decoded_json)
            if not _flex_matches(tree, tree.root, expected):
                raise Error("decoded value does not match")
        return
    if version == "file-id":
        verify_file_identifier(buf)
        return
    verify_root(buf, False)


def _digit_string(s: String) -> Bool:
    var b = s.as_bytes()
    if len(b) == 0:
        return False
    var i = 0
    if Int(b[0]) == 45:
        i = 1
        if i >= len(b):
            return False
    while i < len(b):
        var c = Int(b[i])
        if c < 48 or c > 57:
            return False
        i += 1
    return True


def _proto_int_like(v: Value) -> Bool:
    if v.is_null() or v.is_int() or v.is_uint() or v.is_float():
        return True
    if v.is_string():
        return _digit_string(v.string())
    return False


def _try_protobuf(buf: List[Byte], schema: String, text: String) raises:
    if schema == "json":
        # Same probe as C and C++: the catalog message is {n,s,ok,tags}, not a generic JSON parse.
        var root = parse(text)
        if not root.is_object():
            raise Error("proto3 JSON message must be an object")
        # Object and Value are not implicitly copyable; index them in place.
        if "n" in root.object():
            if not _proto_int_like(root.object()["n"]):
                raise Error("int32 must be a number or digit string")
        if "s" in root.object():
            if not root.object()["s"].is_null() and not root.object()["s"].is_string():
                raise Error("s must be a string")
        if "ok" in root.object():
            if not root.object()["ok"].is_null() and not root.object()["ok"].is_bool():
                raise Error("ok must be a bool")
        if "tags" in root.object():
            if not root.object()["tags"].is_null():
                if not root.object()["tags"].is_array():
                    raise Error("tags must be an array")
                var ntags = len(root.object()["tags"].array())
                var ti = 0
                while ti < ntags:
                    if not _proto_int_like(root.object()["tags"].array()[ti]):
                        raise Error("int32 must be a number or digit string")
                    ti += 1
        return
    var i = 0
    while i < len(buf):
        var kv = _pb_varint(buf, i)
        var key = kv[0]
        i = kv[1]
        var wt = Int(key & UInt64(7))
        if wt == 0:
            var vv = _pb_varint(buf, i)
            i = vv[1]
        elif wt == 1:
            if i + 8 > len(buf):
                raise Error("truncated fixed64")
            i += 8
        elif wt == 5:
            if i + 4 > len(buf):
                raise Error("truncated fixed32")
            i += 4
        elif wt == 2:
            var ln = _pb_varint(buf, i)
            i = ln[1]
            var n = Int(ln[0])
            if i + n > len(buf):
                raise Error("truncated length-delimited")
            i += n
        else:
            raise Error("invalid wire type")


def _pb_varint(data: List[Byte], start: Int) raises -> Tuple[UInt64, Int]:
    var i = start
    var result = UInt64(0)
    var shift = 0
    while i < len(data):
        var b = Int(data[i])
        i += 1
        result |= UInt64(b & 127) << UInt64(shift)
        if (b & 128) == 0:
            return (result, i)
        shift += 7
        if shift > 63:
            raise Error("varint too long")
    raise Error("truncated varint")


def _word_eq_hex(v: UInt64, nbytes: Int, hextext: String) -> Bool:
    var want = _hex_bytes(hextext)
    if len(want) != nbytes:
        return False
    var i = 0
    while i < nbytes:
        var shift = UInt64(i) * 8
        var b = UInt8((v >> shift) & UInt64(255))
        if b != want[i]:
            return False
        i += 1
    return True


def _expect_i64(expected: Value) raises -> Int64:
    if expected.is_int() or expected.is_uint():
        return expected.int()
    if expected.is_float():
        return Int64(expected.float())
    raise Error("expected an integer")


def _kiln_bits_marker(expected: Value, key: String) raises -> String:
    if not expected.is_object() or len(expected.object()) != 1:
        return String("")
    try:
        return String(expected.object()[key].string())
    except:
        return String("")


def _kiln_eq(
    schema: Schema,
    sid: Int,
    value: KilnValue,
    nid: Int,
    expected: Value,
) raises -> Bool:
    var sk = schema.kind[sid]
    if sk == TY_OPT:
        if expected.is_null():
            return value.nodes[nid].kind == VK_NONE
        return _kiln_eq(schema, schema.aux[sid], value, nid, expected)
    if sk == TY_BOOL:
        if not expected.is_bool():
            return False
        var on = value.nodes[nid].a != 0
        return on == expected.bool()
    if sk == TY_I8 or sk == TY_I16 or sk == TY_I32 or sk == TY_I64:
        var got = Int64(from_bits=value.words[value.nodes[nid].a])
        return got == _expect_i64(expected)
    if sk == TY_U8 or sk == TY_U16 or sk == TY_U32 or sk == TY_U64:
        var got = value.words[value.nodes[nid].a]
        var want = _expect_i64(expected)
        if want < 0:
            return False
        return got == UInt64(want)
    if sk == TY_F32 or sk == TY_F64:
        var marker = String("$f32bits")
        if sk == TY_F64:
            marker = String("$f64bits")
        var bits_hex = _kiln_bits_marker(expected, marker)
        if bits_hex.byte_length() > 0:
            var width = 8 if sk == TY_F64 else 4
            return _word_eq_hex(value.words[value.nodes[nid].a], width, bits_hex)
        var got = Float64(from_bits=value.words[value.nodes[nid].a])
        if sk == TY_F32:
            got = Float64(Float32(from_bits=UInt32(value.words[value.nodes[nid].a])))
        if expected.is_float():
            return got == expected.float()
        if expected.is_int() or expected.is_uint():
            return got == Float64(expected.int())
        return False
    if sk == TY_STR:
        if not expected.is_string():
            return False
        return value.texts[value.nodes[nid].a] == expected.string()
    if sk == TY_BYTES:
        var hextext = _kiln_bits_marker(expected, String("$hex"))
        if hextext.byte_length() == 0:
            return False
        var slot = value.nodes[nid].a
        var at = value.blob_at[slot]
        var n = value.blob_n[slot]
        var tmp = List[Byte]()
        var i = 0
        while i < n:
            tmp.append(value.blob[at + i])
            i += 1
        return _hex_eq(tmp, hextext)
    if sk == TY_LIST:
        if not expected.is_array():
            return False
        if value.nodes[nid].nchild != len(expected.array()):
            return False
        var i = 0
        while i < value.nodes[nid].nchild:
            if not _kiln_eq(
                schema,
                schema.aux[sid],
                value,
                value.child(nid, i),
                expected.array()[i],
            ):
                return False
            i += 1
        return True
    if sk == TY_DICT:
        if not expected.is_object():
            return False
        if value.nodes[nid].nchild != len(expected.object()):
            return False
        for key in expected.object().keys():
            var name = String(key)
            var found = False
            var i = 0
            while i < value.nodes[nid].nchild:
                if value.child_key(nid, i) == name:
                    if not _kiln_eq(
                        schema,
                        schema.aux[sid],
                        value,
                        value.child(nid, i),
                        expected.object()[name],
                    ):
                        return False
                    found = True
                    break
                i += 1
            if not found:
                return False
        return True
    if sk == TY_STRUCT:
        if not expected.is_object():
            return False
        var n = schema.field_n[sid]
        if len(expected.object()) != n:
            return False
        var i = 0
        while i < n:
            var name = schema.field_name[schema.field_start[sid] + i]
            var ft = schema.field_type[schema.field_start[sid] + i]
            try:
                if not _kiln_eq(schema, ft, value, value.child(nid, i), expected.object()[name]):
                    return False
            except:
                return False
            i += 1
        return True
    return False


def _raise_kiln(e: KilnError) raises:
    var text = String("KilnError(kind=")
    text += String(e.kind)
    text += ", offset="
    text += String(e.offset)
    text += ")"
    raise Error(text)


def _try_kiln_tensor(buf: List[Byte], has_decoded: Bool, decoded_json: String) raises:
    var got = List[Float64]()
    try:
        got = read_f64(Span(buf))
    except e:
        _raise_kiln(e)
    if not has_decoded:
        return
    var expected = parse(decoded_json)
    if not expected.is_array() or len(got) != len(expected.array()):
        raise Error("decoded value does not match")
    var i = 0
    while i < len(got):
        var want = expected.array()[i].copy()
        var same = False
        if want.is_float():
            same = got[i] == want.float()
        elif want.is_int() or want.is_uint():
            same = got[i] == Float64(want.int())
        if not same:
            raise Error("decoded value does not match")
        i += 1


def _try_kiln_frame(buf: List[Byte], has_decoded: Bool, decoded_json: String) raises:
    var point = KilnPoint()
    try:
        point = decode_framed[KilnPoint](Span(buf))
    except e:
        _raise_kiln(e)
    if not has_decoded:
        return
    var expected = parse(decoded_json)
    if not expected.is_object():
        raise Error("decoded value does not match")
    if Int64(point.x) != expected.object()["x"].int() or Int64(point.y) != expected.object()["y"].int():
        raise Error("decoded value does not match")


def _try_kiln_value(buf: List[Byte], schema_json: String, has_decoded: Bool, decoded_json: String) raises:
    var sch = Schema()
    var decoded = KilnValue()
    try:
        sch = schema_from_json(schema_json)
        decoded = decode_value(sch, Span(buf))
    except e:
        _raise_kiln(e)
    if not has_decoded:
        return
    var expected = parse(decoded_json)
    if not _kiln_eq(sch, sch.root, decoded, decoded.root, expected):
        raise Error("decoded value does not match")


def _try_kiln(buf: List[Byte], schema: String, has_decoded: Bool, decoded_json: String) raises:
    if schema == "\"tensor\"":
        _try_kiln_tensor(buf, has_decoded, decoded_json)
        return
    if schema == "\"frame\"":
        _try_kiln_frame(buf, has_decoded, decoded_json)
        return
    _try_kiln_value(buf, schema, has_decoded, decoded_json)


def _row(
    id: String,
    ser: String,
    ver: String,
    fmt: String,
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
        + ",\"language\":\"mojo\",\"serializer\":"
        + _esc(ser)
        + ",\"serializer_version\":"
        + _esc(ver)
        + ",\"format\":"
        + _esc(fmt)
        + ",\"standard\":"
        + _esc(standard)
        + ",\"standard_url\":"
        + _esc(standard_url)
        + ",\"version\":"
        + _esc(version)
        + ",\"version_key\":"
        + _esc(fmt + "." + version)
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


def _run_one(
    ser: String,
    ver: String,
    fmt: String,
    standard: String,
    standard_url: String,
    version: String,
    id: String,
    requirement: String,
    expect: String,
    section: String,
    section_title: String,
    section_url: String,
    paragraph: String,
    title: String,
    input_text: String,
    enc: String,
    schema: String,
    has_decoded: Bool,
    decoded_json: String,
) -> String:
    var ok = False
    var err = ""
    try:
        if fmt == "json":
            if ser == "EmberJson":
                _try_json(input_text)
            elif ser == "ehsanmok-json":
                _try_ehsan(input_text)
            else:
                _try_gldjson(input_text)
        elif fmt == "yaml":
            _try_yaml(input_text)
        elif fmt == "toml":
            if ser == "gld-toml":
                _try_gldtoml(input_text)
            else:
                _try_toml(input_text)
        elif fmt == "cbor":
            _try_cbor(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
        elif fmt == "msgpack":
            _try_msgpack(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
        elif fmt == "bson":
            _try_bson(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
        elif fmt == "protobuf":
            _try_protobuf(
                _hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text),
                schema,
                input_text,
            )
        elif fmt == "avro":
            _try_avro(
                _hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text),
                schema,
            )
        elif fmt == "ion":
            _try_ion(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
        elif fmt == "smile":
            _try_smile(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
        elif fmt == "arrow":
            _try_arrow(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
        elif fmt == "parquet":
            _try_parquet(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
        elif fmt == "flatbuffers":
            _try_flatbuffers(
                _hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text),
                version,
                has_decoded,
                decoded_json,
            )
        elif fmt == "hdf5":
            _try_hdf5(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
        elif fmt == "netcdf":
            _try_netcdf(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
        elif fmt == "adios2":
            _try_adios2(input_text)
        elif fmt == "kiln":
            _try_kiln(
                _hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text),
                schema,
                has_decoded,
                decoded_json,
            )
        else:
            raise Error("no adapter")
        ok = True
    except e:
        ok = False
        err = String(e)
    if expect == "any":
        return _row(
            id, ser, ver, fmt, standard, standard_url, version, requirement, expect,
            section, section_title, section_url, paragraph, title, input_text, enc,
            "ok" if ok else err, "pass", "",
        )
    if expect == "reject":
        if not ok:
            return _row(
                id, ser, ver, fmt, standard, standard_url, version, requirement, expect,
            section, section_title, section_url, paragraph, title, input_text, enc,
                err, "pass", "",
            )
        return _row(
            id, ser, ver, fmt, standard, standard_url, version, requirement, expect,
            section, section_title, section_url, paragraph, title, input_text, enc,
            "accepted", "fail", "parser accepted input the spec requires to be rejected",
        )
    if not ok:
        return _row(
            id, ser, ver, fmt, standard, standard_url, version, requirement, expect,
            section, section_title, section_url, paragraph, title, input_text, enc,
            err, "fail", "parser rejected input the spec requires to accept",
        )
    return _row(
        id, ser, ver, fmt, standard, standard_url, version, requirement, expect,
        section, section_title, section_url, paragraph, title, input_text, enc,
        "ok", "pass", "",
    )


def _mapped_mojo(name: String, fmt: String) -> Bool:
    var path = "../compliance/serializer-standards.json"
    var text = ""
    try:
        text = open(path, "r").read()
    except:
        try:
            text = open("compliance/serializer-standards.json", "r").read()
        except:
            return True
    try:
        var doc = parse(text)
        var arr = doc.object()["languages"].object()["mojo"].object()[name].copy()
        var i = 0
        var items = arr.array().copy()
        while i < len(items):
            if String(items[i].string()) == fmt:
                return True
            i += 1
        return False
    except:
        return True


def _want_fmt(formats: List[String], fmt: String) -> Bool:
    if len(formats) == 0:
        return True
    var i = 0
    while i < len(formats):
        if formats[i] == fmt:
            return True
        i += 1
    return False


def main() raises:
    var args = argv()
    var json_out = ""
    var list_path = ""
    var formats = List[String]()
    var ai = 1
    while ai < len(args):
        var a = String(args[ai])
        if (a == "--json-out" or a == "-o") and ai + 1 < len(args):
            ai += 1
            json_out = String(args[ai])
        elif a == "--list" and ai + 1 < len(args):
            ai += 1
            list_path = String(args[ai])
        elif (a == "--format" or a == "-f") and ai + 1 < len(args):
            ai += 1
            formats.append(String(args[ai]))
        ai += 1
    if list_path.byte_length() == 0:
        raise Error("--list <catalog-file-list> is required")

    var listing = open(list_path, "r").read()
    var lines = List[String]()
    var cur = String()
    var lb = listing.as_bytes()
    var bi = 0
    while bi < len(lb):
        var ch = Int(lb[bi])
        if ch == 10:
            lines.append(cur)
            cur = String()
        elif ch != 13:
            cur += String(chr(ch))
        bi += 1
    if cur.byte_length() > 0:
        lines.append(cur)
    var rows_path = json_out
    if rows_path.byte_length() == 0:
        rows_path = "/tmp/mojo-compliance-rows.json"
    rows_path = rows_path + ".rows"
    var first = True
    var passed = 0
    var failed = 0
    var skipped = 0
    var adapter_errs = List[String]()
    var seen_skip = List[String]()
    var li = 0
    with open(rows_path, "w") as rows_out:
        rows_out.write("[")
        while li < len(lines):
            var path = String(lines[li])
            li += 1
            if path.byte_length() == 0:
                continue
            var text = ""
            try:
                text = open(path, "r").read()
            except:
                continue
            var suite = parse(text)
            var fmt = ""
            try:
                fmt = String(suite.object()["format"].string())
            except:
                continue
            if not _want_fmt(formats, fmt):
                continue
            # Official catalogs are split into small chunks by run-compliance.sh.
            # A single unsplit TOML file is still large enough to OOM EmberJson.
            var standard = ""
            var version = ""
            var standard_url = ""
            try:
                standard = String(suite.object()["standard"].string())
            except:
                standard = ""
            try:
                version = String(suite.object()["version"].string())
            except:
                version = ""
            try:
                standard_url = String(suite.object()["standard_url"].string())
            except:
                standard_url = ""
            var sers = List[String]()
            var vers = List[String]()
            if fmt == "json":
                sers.append("EmberJson")
                vers.append("0.3.4")
                sers.append("ehsanmok-json")
                vers.append("0.4.0")
                sers.append("mojo-json")
                vers.append("0.5.0")
            elif fmt == "yaml":
                sers.append("gld-yaml")
                vers.append("0.6.0")
            elif fmt == "toml":
                sers.append("mojo-toml")
                vers.append("0.9.1")
                sers.append("gld-toml")
                vers.append("0.1.0")
            elif fmt == "cbor":
                sers.append("mojo-cbor")
                vers.append("0.8.0")
            elif fmt == "msgpack":
                sers.append("mojo-msgpack")
                vers.append("0.4.0")
            elif fmt == "bson":
                sers.append("mojo-bson")
                vers.append("0.1.0")
            elif fmt == "protobuf":
                sers.append("mojo-protobuf")
                vers.append("0.7.0")
            elif fmt == "avro":
                sers.append("mojo-avro")
                vers.append("0.4.0")
            elif fmt == "flatbuffers":
                sers.append("mojo-flatbuffers")
                vers.append("0.4.0")
            elif fmt == "ion":
                sers.append("mojo-ion")
                vers.append("0.2.0")
            elif fmt == "smile":
                sers.append("mojo-smile")
                vers.append("0.2.0")
            elif fmt == "arrow":
                sers.append("arrow-ipc")
                vers.append("0.2.0")
            elif fmt == "parquet":
                sers.append("parquet")
                vers.append("0.2.0")
                sers.append("parquet-uncompressed")
                vers.append("0.2.0")
            elif fmt == "hdf5":
                sers.append("gld-hdf5")
                vers.append(String(VERSION))
            elif fmt == "netcdf":
                sers.append("gld-netcdf")
                vers.append(String(VERSION))
            elif fmt == "adios2":
                sers.append("gld-adios2")
                vers.append(String(VERSION))
            elif fmt == "kiln":
                sers.append("gld-kiln")
                vers.append("0.2.0")
            else:
                var msg = "No adapter registered for format " + fmt + " (" + standard + " (" + version + "))"
                var already = False
                var si = 0
                while si < len(seen_skip):
                    if seen_skip[si] == msg:
                        already = True
                    si += 1
                if not already:
                    seen_skip.append(msg)
                    adapter_errs.append(msg)
                continue
            var keep_s = List[String]()
            var keep_v = List[String]()
            var mi = 0
            while mi < len(sers):
                if _mapped_mojo(sers[mi], fmt):
                    keep_s.append(sers[mi])
                    keep_v.append(vers[mi])
                mi += 1
            sers = keep_s^
            vers = keep_v^
            if len(sers) == 0:
                var msg = "No adapter registered for format " + fmt + " (" + standard + " (" + version + "))"
                var already = False
                var si = 0
                while si < len(seen_skip):
                    if seen_skip[si] == msg:
                        already = True
                        break
                    si += 1
                if not already:
                    seen_skip.append(msg)
                    adapter_errs.append(msg)
                continue
            var cases = suite.object()["cases"].array().copy()
            var ci = 0
            while ci < len(cases):
                var c = cases[ci].object().copy()
                var id = ""
                var expect = ""
                var input_text = ""
                var enc = "utf-8"
                var requirement = ""
                var section = ""
                var section_title = ""
                var section_url = ""
                var paragraph = ""
                var title = ""
                try:
                    id = String(c["id"].string())
                except:
                    id = ""
                try:
                    expect = String(c["expect"].string())
                except:
                    expect = ""
                try:
                    title = String(c["title"].string())
                except:
                    title = ""
                try:
                    section = String(c["section"].string())
                except:
                    section = ""
                try:
                    section_title = String(c["section_title"].string())
                except:
                    section_title = ""
                try:
                    paragraph = String(c["paragraph"].string())
                except:
                    paragraph = ""
                try:
                    input_text = String(c["input"].string())
                except:
                    input_text = ""
                try:
                    enc = String(c["input_encoding"].string())
                except:
                    enc = "utf-8"
                try:
                    requirement = String(c["requirement"].string())
                except:
                    requirement = ""
                try:
                    section_url = String(c["section_url"].string())
                except:
                    section_url = ""
                var schema = ""
                try:
                    schema = to_string(c["schema"])
                except:
                    schema = ""
                # proto3 JSON mapping is flagged with the string "json".
                if schema == "\"json\"":
                    schema = "json"
                var has_decoded = False
                var decoded_json = String("")
                try:
                    decoded_json = to_string(c["decoded"])
                    has_decoded = True
                except:
                    has_decoded = False
                    decoded_json = String("")
                if _too_deep(input_text):
                    skipped += 1
                    ci += 1
                    continue
                var si = 0
                while si < len(sers):
                    var row = _run_one(
                        sers[si],
                        vers[si],
                        fmt,
                        standard,
                        standard_url,
                        version,
                        id,
                        requirement,
                        expect,
                        section,
                        section_title,
                        section_url,
                        paragraph,
                        title,
                        input_text,
                        enc,
                        schema,
                        has_decoded,
                        decoded_json,
                    )
                    if _contains(row, "\"outcome\":\"fail\""):
                        failed += 1
                    else:
                        passed += 1
                    if not first:
                        rows_out.write(",")
                    first = False
                    rows_out.write(row)
                    si += 1
                ci += 1
        rows_out.write("]")
    print("Serialization compliance (library deviations are catalogued, not a red build)")
    print(" ", passed, "pass ", failed, "fail ", skipped, "skip  0 error ", passed + failed, "total")
    if json_out.byte_length() > 0:
        var errs = String("[")
        var ei = 0
        while ei < len(adapter_errs):
            if ei > 0:
                errs += ","
            errs += _esc(adapter_errs[ei])
            ei += 1
        errs += "]"
        var rows = open(rows_path, "r").read()
        var head = (
            "{\"schema\":\"gld.dashboard.compliance/1\",\"generated_at\":\"\",\"language\":\"mojo\",\"languages\":[\"mojo\"],\"policy\":\"report-only\",\"scope\":{\"formats\":[\"json\",\"yaml\",\"toml\",\"cbor\",\"msgpack\",\"protobuf\",\"avro\",\"flatbuffers\",\"bson\",\"ion\",\"smile\",\"arrow\",\"parquet\"]},\"passed\":"
            + String(passed)
            + ",\"failed\":"
            + String(failed)
            + ",\"skipped\":"
            + String(skipped)
            + ",\"errors\":0,\"catalog_errors\":[],\"serializer_errors\":"
            + errs
            + ",\"results\":"
        )
        with open(json_out, "w") as f:
            f.write(head)
            f.write(rows)
            f.write("}\n")
        print("\nWrote", json_out)
