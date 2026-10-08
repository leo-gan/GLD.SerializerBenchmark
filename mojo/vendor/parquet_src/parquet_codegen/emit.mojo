from std.collections import List, Span

from parquet_runtime.buf import string_from
from parquet_runtime.error import DecodeError


def _skip_ws[origin: ImmOrigin](raw: Span[Byte, origin], mut i: Int):
    while i < len(raw):
        var c = Int(raw[i])
        if c != 32 and c != 9 and c != 10 and c != 13:
            return
        i += 1


def _string[origin: ImmOrigin](raw: Span[Byte, origin], mut i: Int) raises DecodeError -> String:
    _skip_ws(raw, i)
    if i >= len(raw) or Int(raw[i]) != 34:
        raise DecodeError(DecodeError.KIND_SYNTAX, i)
    i += 1
    var out = List[Byte]()
    while i < len(raw) and Int(raw[i]) != 34:
        if Int(raw[i]) == 92:
            i += 1
        out.append(raw[i])
        i += 1
    if i >= len(raw):
        raise DecodeError(DecodeError.KIND_SYNTAX, i)
    i += 1
    return string_from(Span(out), i)


def _ident(name: String) -> String:
    if name == "type" or name == "struct" or name == "var" or name == "def":
        return name + "_"
    return name


def emit_schema[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> String:
    var title = "Record"
    var names = List[String]()
    var jtypes = List[String]()
    var ptypes = List[String]()
    var reqs = List[Int]()
    var req_names = List[String]()
    var i = 0
    var n = len(raw)
    while i < n:
        _skip_ws(raw, i)
        if i >= n or Int(raw[i]) != 34:
            i += 1
            continue
        var key = _string(raw, i)
        _skip_ws(raw, i)
        if i >= n or Int(raw[i]) != 58:
            continue
        i += 1
        if key == "title":
            title = _string(raw, i)
        elif key == "required":
            while i < n and Int(raw[i]) != 93:
                _skip_ws(raw, i)
                if i < n and Int(raw[i]) == 34:
                    var nm = _string(raw, i)
                    req_names.append(nm)
                else:
                    i += 1
        elif key == "x-parquet-type" and len(names) > 0:
            ptypes[len(names) - 1] = _string(raw, i)
        elif key == "type" and len(names) > 0:
            _skip_ws(raw, i)
            if i < n and Int(raw[i]) == 34:
                jtypes[len(names) - 1] = _string(raw, i)
        elif key != "properties" and key != "required" and key != "type":
            names.append(key)
            jtypes.append("string")
            ptypes.append("")
            var is_req = 0
            var rq = 0
            while rq < len(req_names):
                if req_names[rq] == key:
                    is_req = 1
                rq += 1
            reqs.append(is_req)
        i += 1
    var text = "from std.collections import List, Span\n\n"
    text = text + "from parquet_runtime.model import Cols, Schema, WriteOpts\n"
    text = text + "from parquet_wire.decode import Table, decode_table\n"
    text = text + "from parquet_wire.encode import encode_table\n\n\n"
    text = text + "struct " + title + ":\n"
    var p = 0
    while p < len(names):
        var ty = "String"
        if jtypes[p] == "integer" or ptypes[p] == "int64" or ptypes[p] == "int32":
            ty = "Int"
        elif jtypes[p] == "boolean":
            ty = "Int"
        elif jtypes[p] == "number":
            ty = "Float64"
        text = text + "    var " + _ident(names[p]) + ": " + ty + "\n"
        p += 1
    text = text + "\n    def __init__(out self):\n"
    p = 0
    while p < len(names):
        var init = "\"\""
        if jtypes[p] == "integer" or jtypes[p] == "boolean" or jtypes[p] == "number" or ptypes[p] == "int64":
            init = "0"
        text = text + "        self." + _ident(names[p]) + " = " + init + "\n"
        p += 1
    text = text + "\n    def encoded_len(self) raises -> Int:\n"
    text = text + "        var raw = self.encode_bytes()\n"
    text = text + "        return len(raw)\n\n"
    text = text + "    def encode_to(self, mut buf: List[Byte]) raises:\n"
    text = text + "        var raw = self.encode_bytes()\n"
    text = text + "        var i = 0\n"
    text = text + "        while i < len(raw):\n"
    text = text + "            buf.append(raw[i])\n"
    text = text + "            i += 1\n\n"
    text = text + "    def encode_bytes(self) raises -> List[Byte]:\n"
    text = text + "        var schema = Schema()\n"
    text = text + "        schema.add(\"schema\", -1, -1, 0, " + String(len(names)) + ", 0)\n"
    p = 0
    while p < len(names):
        var phy = "6"
        var logical = "1"
        var rep = "1"
        if reqs[p] != 0:
            rep = "0"
        if jtypes[p] == "integer" or ptypes[p] == "int64":
            phy = "2"
            logical = "10"
        elif jtypes[p] == "boolean":
            phy = "0"
            logical = "0"
        elif jtypes[p] == "number":
            phy = "5"
            logical = "0"
        text = text + "        schema.add(\"" + names[p] + "\", " + phy + ", " + rep + ", 0, 0, " + logical + ")\n"
        if phy == "2":
            text = text + "        schema.bit_width[" + String(p + 1) + "] = 64\n"
            text = text + "        schema.is_signed[" + String(p + 1) + "] = 1\n"
        p += 1
    text = text + "        schema.finish()\n"
    text = text + "        var cols = Cols()\n"
    p = 0
    while p < len(names):
        var phy = "6"
        if jtypes[p] == "integer" or ptypes[p] == "int64":
            phy = "2"
        elif jtypes[p] == "boolean":
            phy = "0"
        elif jtypes[p] == "number":
            phy = "5"
        text = text + "        cols.begin(" + String(p + 1) + ", " + phy + ")\n"
        if reqs[p] == 0:
            text = text + "        cols.add_level(1, 0)\n"
        if phy == "2" or phy == "0":
            text = text + "        cols.add_i64(self." + _ident(names[p]) + ")\n"
        elif phy == "5":
            text = text + "        cols.add_bits(self." + _ident(names[p]) + ".to_bits())\n"
        else:
            text = text + "        var raw_" + String(p) + " = List[Byte]()\n"
            text = text + "        var bytes_" + String(p) + " = self." + _ident(names[p]) + ".as_bytes()\n"
            text = text + "        var k_" + String(p) + " = 0\n"
            text = text + "        while k_" + String(p) + " < len(bytes_" + String(p) + "):\n"
            text = text + "            raw_" + String(p) + ".append(bytes_" + String(p) + "[k_" + String(p) + "])\n"
            text = text + "            k_" + String(p) + " += 1\n"
            text = text + "        cols.add_bytes(raw_" + String(p) + ")\n"
        p += 1
    text = text + "        var table = Table()\n"
    text = text + "        table.nrows = 1\n"
    text = text + "        table.cols = cols^\n"
    text = text + "        table.foot.schema = schema^\n"
    text = text + "        var opts = WriteOpts()\n"
    text = text + "        return encode_table(table, opts)\n\n"
    text = text + "    @staticmethod\n"
    text = text + "    def decode_from[origin: ImmOrigin](raw: Span[Byte, origin]) raises -> Self:\n"
    text = text + "        var table = decode_table(raw)\n"
    text = text + "        var out = Self()\n"
    p = 0
    while p < len(names):
        var phy = "6"
        if jtypes[p] == "integer" or ptypes[p] == "int64":
            phy = "2"
        if phy == "2" or jtypes[p] == "boolean":
            text = text + "        if table.cols.val_n[" + String(p) + "] > 0:\n"
            text = text + "            out." + _ident(names[p]) + " = table.cols.i64s[table.cols.val_b[" + String(p) + "]]\n"
        p += 1
    text = text + "        return out^\n"
    return text
