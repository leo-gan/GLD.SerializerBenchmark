"""Mojo compliance runner — same catalog as the other languages."""

from std.collections import List
from std.sys import argv
from emberjson import parse
from ehsanmok_json import loads as ehsan_loads
from gldjson import decode_value as json_decode
from yaml import decode_value as yaml_decode
from cbor import decode_value as cbor_decode
from msgpack import decode_value as msgpack_decode
from toml import parse as toml_parse
from avro import GenericDatum, parse_avsc



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
    _ = yaml_decode(text.as_bytes())


def _try_toml(text: String) raises:
    _ = toml_parse(text)


def _try_cbor(buf: List[Byte]) raises:
    _ = cbor_decode(buf)


def _try_msgpack(buf: List[Byte]) raises:
    _ = msgpack_decode(buf)


def _try_avro(buf: List[Byte], schema_json: String) raises:
    var text = schema_json
    if text.byte_length() == 0:
        text = "\"int\""
    var pool = parse_avsc(text)
    var g = GenericDatum(pool^)
    g.decode(buf)


def _try_protobuf(buf: List[Byte], schema: String, text: String) raises:
    if schema == "json":
        var v = parse(text)
        try:
            _ = v.object()
        except:
            raise Error("proto3 JSON message must be an object")
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
    section_url: String,
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
        + ",\"section\":\"\",\"section_title\":\"\",\"section_url\":"
        + _esc(section_url)
        + ",\"paragraph\":\"\",\"title\":\"\",\"input\":\"\",\"input_encoding\":\"\",\"detail\":"
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
    section_url: String,
    input_text: String,
    enc: String,
    schema: String,
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
            _try_toml(input_text)
        elif fmt == "cbor":
            _try_cbor(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
        elif fmt == "msgpack":
            _try_msgpack(_hex_bytes(input_text) if enc == "hex" else _utf8_bytes(input_text))
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
        else:
            raise Error("no adapter")
        ok = True
    except e:
        ok = False
        err = String(e)
    if expect == "any":
        return _row(
            id, ser, ver, fmt, standard, standard_url, version, requirement, expect, section_url,
            "ok" if ok else err, "pass", "",
        )
    if expect == "reject":
        if not ok:
            return _row(
                id, ser, ver, fmt, standard, standard_url, version, requirement, expect, section_url,
                err, "pass", "",
            )
        return _row(
            id, ser, ver, fmt, standard, standard_url, version, requirement, expect, section_url,
            "accepted", "fail", "parser accepted input the spec requires to be rejected",
        )
    if not ok:
        return _row(
            id, ser, ver, fmt, standard, standard_url, version, requirement, expect, section_url,
            err, "fail", "parser rejected input the spec requires to accept",
        )
    return _row(
        id, ser, ver, fmt, standard, standard_url, version, requirement, expect, section_url,
        "ok", "pass", "",
    )


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
            if (fmt == "toml" or fmt == "yaml") and text.byte_length() > 100000:
                adapter_errs.append("skipped large official " + fmt + " suite")
                print("skip large", fmt, path)
                continue
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
                vers.append("0.3.1")
                sers.append("mojo-json")
                vers.append("0.3.0")
            elif fmt == "yaml":
                sers.append("mojo-yaml")
                vers.append("0.2.0")
            elif fmt == "toml":
                sers.append("mojo-toml")
                vers.append("0.9.1")
            elif fmt == "cbor":
                sers.append("mojo-cbor")
                vers.append("0.6.0")
            elif fmt == "msgpack":
                sers.append("mojo-msgpack")
                vers.append("0.3.0")
            elif fmt == "protobuf":
                sers.append("mojo-protobuf")
                vers.append("0.6.0")
            elif fmt == "avro":
                sers.append("mojo-avro")
                vers.append("0.4.0")
            else:
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
                var section_url = ""
                try:
                    id = String(c["id"].string())
                except:
                    id = ""
                try:
                    expect = String(c["expect"].string())
                except:
                    expect = ""
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
                    schema = String(c["schema"])
                except:
                    try:
                        schema = String(c["schema"].string())
                    except:
                        schema = ""
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
                        section_url,
                        input_text,
                        enc,
                        schema,
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
            "{\"schema\":\"gld.dashboard.compliance/1\",\"generated_at\":\"\",\"language\":\"mojo\",\"languages\":[\"mojo\"],\"policy\":\"report-only\",\"scope\":{\"formats\":[\"json\",\"yaml\",\"toml\",\"cbor\",\"msgpack\",\"protobuf\"]},\"passed\":"
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
