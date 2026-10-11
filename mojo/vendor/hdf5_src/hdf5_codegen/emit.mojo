from std.collections import List

from hdf5_codegen.names import sanitize
from hdf5_runtime.error import FormatError
from hdf5_schema.parse import Schema


def emit_source(schema: Schema) raises -> String:
    var name = sanitize(schema.name)
    if name.byte_length() == 0:
        raise FormatError(0, String("schema name is empty"))
    var ds = schema.dataset
    var src = String()
    src = src + "from std.collections import List, Span\n"
    src = src + "from std.memory import bitcast\n\n"
    src = src + "from hdf5 import DT_F64, H5Doc, read_hdf5, write_hdf5\n\n\n"
    src = src + "struct " + name + "(Movable):\n"
    src = src + "    var values: List[Float64]\n\n"
    src = src + "    def __init__(out self):\n"
    src = src + "        self.values = List[Float64]()\n\n"
    src = src + "    def encode(self) raises -> List[Byte]:\n"
    src = src + "        var doc = H5Doc()\n"
    src = src + "        var root = doc.add_group(-1, String(\"\"))\n"
    src = src + "        _ = doc.add_f64(root, String(\"" + ds + "\"), self.values, 0, 0)\n"
    src = src + "        return write_hdf5(doc)\n\n"
    src = src + "    @staticmethod\n"
    src = src + "    def decode_from(raw: List[Byte]) raises -> " + name + ":\n"
    src = src + "        var doc = read_hdf5(Span(raw))\n"
    src = src + "        var out = " + name + "()\n"
    src = src + "        var i = 0\n"
    src = src + "        while i < len(doc.d_name):\n"
    src = src + "            if doc.d_name[i] == String(\"" + ds + "\") and doc.d_dtype[i] == DT_F64:\n"
    src = src + "                var k = 0\n"
    src = src + "                while k + 8 <= len(doc.d_data[i]):\n"
    src = src + "                    var bits = UInt64(0)\n"
    src = src + "                    var s = 7\n"
    src = src + "                    while s >= 0:\n"
    src = src + "                        bits = (bits << 8) | UInt64(Int(doc.d_data[i][k + s]))\n"
    src = src + "                        s -= 1\n"
    src = src + "                    out.values.append(bitcast[DType.float64](bits))\n"
    src = src + "                    k += 8\n"
    src = src + "                return out^\n"
    src = src + "            i += 1\n"
    src = src + "        raise Error(\"generated dataset was not found\")\n"
    return src


def emit_all(schema: Schema) raises -> List[String]:
    var out = List[String]()
    out.append(sanitize(schema.name))
    out.append(emit_source(schema))
    return out^
