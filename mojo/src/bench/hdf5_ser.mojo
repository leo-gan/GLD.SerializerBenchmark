"""gld-hdf5, gld-netcdf, and gld-adios2 on the five suite types.

HDF5 writes typed datasets (i32, i64, f64, uint8 text). NetCDF-4 writes the
same numbers as float64 variables and the text blob as float64 bit patterns,
because this library's NetCDF variables are float64. ADIOS2 BP5 here is one
float64 variable plus one string attribute, so the record is packed into that
variable and the directory is framed as the byte size. Graph is not a grid.
"""

from std.collections import List, Span
from std.memory import bitcast
from std.os.process import Process
from std.time import perf_counter_ns

from bench.data import (
    Document,
    DocumentItem,
    DocumentMeta,
    Event,
    EventAttr,
    Fixture,
    Message,
    Strings,
    Telemetry,
    fidelity,
)
from hdf5 import (
    DT_F64,
    DT_I32,
    DT_I64,
    DT_U8,
    VERSION,
    read_bp5,
    read_hdf5,
    read_nc4,
    write_bp5,
    write_hdf5,
    write_nc4,
)
from hdf5_runtime.doc import BpStep, H5Doc, NcFile


struct RawDoc:
    var i32s: List[Int]
    var i64s: List[Int]
    var f64s: List[Float64]
    var text: List[Byte]

    def __init__(out self):
        self.i32s = List[Int]()
        self.i64s = List[Int]()
        self.f64s = List[Float64]()
        self.text = List[Byte]()


def _put_u32(mut b: List[Byte], v: Int):
    var x = v
    var i = 0
    while i < 4:
        b.append(Byte(x & 255))
        x = x >> 8
        i += 1


def _put_u64(mut b: List[Byte], v: Int):
    var x = v
    var i = 0
    while i < 8:
        b.append(Byte(x & 255))
        x = x >> 8
        i += 1


def _put_f64(mut b: List[Byte], v: Float64):
    _put_u64(b, Int(bitcast[DType.uint64](v)))


def _put_str(mut b: List[Byte], text: String):
    var raw = text.as_bytes()
    _put_u32(b, len(raw))
    var i = 0
    while i < len(raw):
        b.append(raw[i])
        i += 1


def _take_u32(b: List[Byte], mut at: Int) raises -> Int:
    if at < 0 or at + 4 > len(b):
        raise Error("truncated u32")
    var v = (
        Int(b[at])
        | (Int(b[at + 1]) << 8)
        | (Int(b[at + 2]) << 16)
        | (Int(b[at + 3]) << 24)
    )
    at += 4
    if (v & 2147483648) != 0:
        v = v - 4294967296
    return v


def _take_u64(b: List[Byte], mut at: Int) raises -> Int:
    if at < 0 or at + 8 > len(b):
        raise Error("truncated u64")
    var v = 0
    var s = 0
    while s < 8:
        v = v | (Int(b[at + s]) << (s * 8))
        s += 1
    at += 8
    return v


def _take_f64(b: List[Byte], mut at: Int) raises -> Float64:
    if at < 0 or at + 8 > len(b):
        raise Error("truncated f64")
    var u = UInt64(0)
    var s = 0
    while s < 8:
        u = u | (UInt64(Int(b[at + s])) << UInt64(s * 8))
        s += 1
    at += 8
    return Float64(from_bits=u)


def _take_str(b: List[Byte], mut at: Int) raises -> String:
    var n = _take_u32(b, at)
    if n < 0 or at + n > len(b):
        raise Error("truncated string")
    if n == 0:
        return String()
    var tmp = List[Byte]()
    var i = 0
    while i < n:
        tmp.append(b[at + i])
        i += 1
    at += n
    return String(unsafe_from_utf8=Span(tmp))


def _bit(v: Bool) -> Int:
    if v:
        return 1
    return 0


def _pack(fx: Fixture) raises -> RawDoc:
    var doc = RawDoc()
    if fx.type_id == "message":
        var n = len(fx.messages)
        doc.i32s.append(n)
        var i = 0
        while i < n:
            var m = fx.messages[i].copy()
            doc.i32s.append(_bit(m.f_bool))
            doc.i32s.append(Int(m.f_int32))
            doc.i32s.append(_bit(m.f_bool_2))
            doc.i32s.append(Int(m.f_int32_2))
            doc.i64s.append(Int(m.f_int64))
            doc.f64s.append(m.f_float64)
            _put_str(doc.text, m.f_string)
            _put_str(doc.text, m.f_string_2)
            i += 1
        return doc^
    if fx.type_id == "document":
        var n = len(fx.documents)
        doc.i32s.append(n)
        var i = 0
        while i < n:
            var d = fx.documents[i].copy()
            doc.i32s.append(Int(d.status))
            doc.i32s.append(Int(d.meta.version))
            doc.i32s.append(len(d.items))
            _put_str(doc.text, d.id)
            _put_str(doc.text, d.meta.region)
            var j = 0
            while j < len(d.items):
                doc.i32s.append(Int(d.items[j].qty))
                doc.i64s.append(Int(d.items[j].price_minor))
                _put_str(doc.text, d.items[j].sku)
                j += 1
            i += 1
        return doc^
    if fx.type_id == "telemetry":
        var n = len(fx.telemetries)
        doc.i32s.append(n)
        var i = 0
        while i < n:
            var t = fx.telemetries[i].copy()
            doc.i32s.append(len(t.tags))
            doc.i32s.append(len(t.values))
            doc.i64s.append(Int(t.ts))
            _put_str(doc.text, t.source)
            var j = 0
            while j < len(t.tags):
                _put_str(doc.text, t.tags[j])
                j += 1
            j = 0
            while j < len(t.values):
                doc.f64s.append(t.values[j])
                j += 1
            i += 1
        return doc^
    if fx.type_id == "strings":
        var n = len(fx.strings)
        doc.i32s.append(n)
        var i = 0
        while i < n:
            var s = fx.strings[i].copy()
            doc.i32s.append(len(s.items))
            var j = 0
            while j < len(s.items):
                _put_str(doc.text, s.items[j])
                j += 1
            i += 1
        return doc^
    if fx.type_id == "event":
        var n = len(fx.events)
        doc.i32s.append(n)
        var i = 0
        while i < n:
            var ev = fx.events[i].copy()
            doc.i32s.append(len(ev.attrs))
            doc.i64s.append(Int(ev.occurred_at))
            _put_str(doc.text, ev.event_id)
            _put_str(doc.text, ev.event_type)
            _put_str(doc.text, ev.producer)
            var j = 0
            while j < len(ev.attrs):
                _put_str(doc.text, ev.attrs[j].key)
                _put_str(doc.text, ev.attrs[j].value)
                j += 1
            i += 1
        return doc^
    raise Error("gld scientific row does not support " + fx.type_id)


def _blank(fx: Fixture) -> Fixture:
    return Fixture(
        fx.type_id,
        fx.n,
        fx.hash,
        List[Message](),
        List[Document](),
        List[Telemetry](),
        List[Strings](),
        List[Event](),
    )


def _unpack(fx: Fixture, doc: RawDoc) raises -> Fixture:
    var out = _blank(fx)
    var at = 0
    if len(doc.i32s) < 1:
        raise Error("empty scientific record")
    var n = doc.i32s[0]
    if fx.type_id == "message":
        var need = 1 + (4 * n)
        if len(doc.i32s) != need or len(doc.i64s) != n or len(doc.f64s) != n:
            raise Error("message shape")
        var i = 0
        var p = 1
        while i < n:
            var m = Message()
            m.f_bool = doc.i32s[p] != 0
            m.f_int32 = Int32(doc.i32s[p + 1])
            m.f_bool_2 = doc.i32s[p + 2] != 0
            m.f_int32_2 = Int32(doc.i32s[p + 3])
            m.f_int64 = Int64(doc.i64s[i])
            m.f_float64 = doc.f64s[i]
            m.f_string = _take_str(doc.text, at)
            m.f_string_2 = _take_str(doc.text, at)
            out.messages.append(m^)
            p += 4
            i += 1
        return out^
    if fx.type_id == "document":
        var i = 0
        var p = 1
        var q = 0
        while i < n:
            if p + 3 > len(doc.i32s):
                raise Error("document shape")
            var nitem = doc.i32s[p + 2]
            var d = Document()
            d.status = Int32(doc.i32s[p])
            d.meta.version = Int32(doc.i32s[p + 1])
            d.id = _take_str(doc.text, at)
            d.meta.region = _take_str(doc.text, at)
            var j = 0
            while j < nitem:
                var item = DocumentItem()
                item.qty = Int32(doc.i32s[p + 3 + j])
                item.price_minor = Int64(doc.i64s[q])
                item.sku = _take_str(doc.text, at)
                d.items.append(item^)
                q += 1
                j += 1
            out.documents.append(d^)
            p += 3 + nitem
            i += 1
        return out^
    if fx.type_id == "telemetry":
        var i = 0
        var p = 1
        var q = 0
        while i < n:
            if p + 2 > len(doc.i32s):
                raise Error("telemetry shape")
            var nt = doc.i32s[p]
            var nv = doc.i32s[p + 1]
            var t = Telemetry()
            t.ts = Int64(doc.i64s[i])
            t.source = _take_str(doc.text, at)
            var j = 0
            while j < nt:
                t.tags.append(_take_str(doc.text, at))
                j += 1
            j = 0
            while j < nv:
                t.values.append(doc.f64s[q])
                q += 1
                j += 1
            out.telemetries.append(t^)
            p += 2
            i += 1
        return out^
    if fx.type_id == "strings":
        var i = 0
        var p = 1
        while i < n:
            if p >= len(doc.i32s):
                raise Error("strings shape")
            var ns = doc.i32s[p]
            var s = Strings()
            var j = 0
            while j < ns:
                s.items.append(_take_str(doc.text, at))
                j += 1
            out.strings.append(s^)
            p += 1
            i += 1
        return out^
    if fx.type_id == "event":
        var i = 0
        var p = 1
        while i < n:
            if p >= len(doc.i32s):
                raise Error("event shape")
            var na = doc.i32s[p]
            var ev = Event()
            ev.occurred_at = Int64(doc.i64s[i])
            ev.event_id = _take_str(doc.text, at)
            ev.event_type = _take_str(doc.text, at)
            ev.producer = _take_str(doc.text, at)
            var j = 0
            while j < na:
                var a = EventAttr()
                a.key = _take_str(doc.text, at)
                a.value = _take_str(doc.text, at)
                ev.attrs.append(a^)
                j += 1
            out.events.append(ev^)
            p += 1
            i += 1
        return out^
    raise Error("gld scientific row does not support " + fx.type_id)


def _i32_bytes(vals: List[Int]) -> List[Byte]:
    var raw = List[Byte]()
    var i = 0
    while i < len(vals):
        _put_u32(raw, vals[i])
        i += 1
    return raw^


def _i64_bytes(vals: List[Int]) -> List[Byte]:
    var raw = List[Byte]()
    var i = 0
    while i < len(vals):
        _put_u64(raw, vals[i])
        i += 1
    return raw^


def _find_ds(doc: H5Doc, name: String) -> Int:
    var i = 0
    while i < len(doc.d_name):
        if doc.d_name[i] == name:
            return i
        i += 1
    return -1


def _read_i32s(doc: H5Doc) raises -> List[Int]:
    var out = List[Int]()
    var id = _find_ds(doc, String("i32s"))
    if id < 0:
        return out^
    var n = doc.d_n0[id]
    var i = 0
    while i < n:
        var o = i * 4
        var v = (
            Int(doc.d_data[id][o])
            | (Int(doc.d_data[id][o + 1]) << 8)
            | (Int(doc.d_data[id][o + 2]) << 16)
            | (Int(doc.d_data[id][o + 3]) << 24)
        )
        if (v & 2147483648) != 0:
            v = v - 4294967296
        out.append(v)
        i += 1
    return out^


def _read_i64s(doc: H5Doc) raises -> List[Int]:
    var out = List[Int]()
    var id = _find_ds(doc, String("i64s"))
    if id < 0:
        return out^
    var n = doc.d_n0[id]
    var i = 0
    while i < n:
        var o = i * 8
        var v = 0
        var s = 0
        while s < 8:
            v = v | (Int(doc.d_data[id][o + s]) << (s * 8))
            s += 1
        out.append(v)
        i += 1
    return out^


def _read_f64s(doc: H5Doc) raises -> List[Float64]:
    var out = List[Float64]()
    var id = _find_ds(doc, String("f64s"))
    if id < 0:
        return out^
    var n = doc.d_n0[id]
    var i = 0
    while i < n:
        var o = i * 8
        var u = UInt64(0)
        var s = 0
        while s < 8:
            u = u | (UInt64(Int(doc.d_data[id][o + s])) << UInt64(s * 8))
            s += 1
        out.append(Float64(from_bits=u))
        i += 1
    return out^


def _read_text(doc: H5Doc) -> List[Byte]:
    var out = List[Byte]()
    var id = _find_ds(doc, String("text"))
    if id < 0:
        return out^
    var n = doc.d_n0[id]
    var i = 0
    while i < n:
        out.append(doc.d_data[id][i])
        i += 1
    return out^


def _emit_h5(src: RawDoc) raises -> List[Byte]:
    var doc = H5Doc()
    var root = doc.add_group(-1, String(""))
    if len(src.i32s) > 0:
        var raw = _i32_bytes(src.i32s)
        _ = doc.add_dataset(root, String("i32s"), DT_I32, 1, len(src.i32s), 0, raw^, 0, 0, 0, 0)
    if len(src.i64s) > 0:
        var raw = _i64_bytes(src.i64s)
        _ = doc.add_dataset(root, String("i64s"), DT_I64, 1, len(src.i64s), 0, raw^, 0, 0, 0, 0)
    if len(src.f64s) > 0:
        _ = doc.add_f64(root, String("f64s"), src.f64s, 0, 0)
    if len(src.text) > 0:
        var raw = List[Byte]()
        var i = 0
        while i < len(src.text):
            raw.append(src.text[i])
            i += 1
        var ntext = len(raw)
        _ = doc.add_dataset(root, String("text"), DT_U8, 1, ntext, 0, raw^, 0, 0, 0, 0)
    return write_hdf5(doc)


def _load_h5(raw: List[Byte]) raises -> RawDoc:
    var parsed = read_hdf5(Span(raw))
    var doc = RawDoc()
    doc.i32s = _read_i32s(parsed)
    doc.i64s = _read_i64s(parsed)
    doc.f64s = _read_f64s(parsed)
    doc.text = _read_text(parsed)
    return doc^


def _f64_list(vals: List[Int]) -> List[Float64]:
    var out = List[Float64]()
    var i = 0
    while i < len(vals):
        out.append(Float64(vals[i]))
        i += 1
    return out^


def _bits_of(raw: List[Byte]) -> List[Float64]:
    var n = (len(raw) + 7) // 8
    var out = List[Float64]()
    var i = 0
    while i < n:
        var u = UInt64(0)
        var s = 0
        while s < 8:
            var idx = i * 8 + s
            if idx < len(raw):
                u = u | (UInt64(Int(raw[idx])) << UInt64(s * 8))
            s += 1
        out.append(Float64(from_bits=u))
        i += 1
    return out^


def _bytes_of(vals: List[Float64], nbytes: Int) -> List[Byte]:
    var out = List[Byte]()
    var i = 0
    while i < len(vals) and len(out) < nbytes:
        var bits = Int(bitcast[DType.uint64](vals[i]))
        var s = 0
        while s < 8 and len(out) < nbytes:
            out.append(Byte(bits & 255))
            bits = bits >> 8
            s += 1
        i += 1
    return out^


def _find_var(nc: NcFile, name: String) -> Int:
    var i = 0
    while i < len(nc.var_name):
        if nc.var_name[i] == name:
            return i
        i += 1
    return -1


def _var_f64(nc: NcFile, name: String) -> List[Float64]:
    var out = List[Float64]()
    var id = _find_var(nc, name)
    if id < 0:
        return out^
    var i = 0
    while i < len(nc.var_data[id]):
        out.append(nc.var_data[id][i])
        i += 1
    return out^


def _as_ints(vals: List[Float64]) -> List[Int]:
    var out = List[Int]()
    var i = 0
    while i < len(vals):
        out.append(Int(vals[i]))
        i += 1
    return out^


def _add_f64_var(mut nc: NcFile, dim_name: String, var_name: String, vals: List[Float64]):
    if len(vals) == 0:
        return
    var dim = nc.add_dim(dim_name, len(vals))
    _ = nc.add_var(var_name, DT_F64, dim, vals)


def _emit_nc(src: RawDoc) raises -> List[Byte]:
    var nc = NcFile()
    var i32s = _f64_list(src.i32s)
    var i64s = _f64_list(src.i64s)
    _add_f64_var(nc, String("axis_i32"), String("i32s"), i32s^)
    _add_f64_var(nc, String("axis_i64"), String("i64s"), i64s^)
    _add_f64_var(nc, String("axis_f64"), String("f64s"), src.f64s)
    if len(src.text) > 0:
        var bits = _bits_of(src.text)
        _add_f64_var(nc, String("axis_text"), String("text_bits"), bits^)
        var one = List[Float64]()
        one.append(Float64(len(src.text)))
        _add_f64_var(nc, String("axis_nbytes"), String("text_nbytes"), one^)
    return write_nc4(nc)


def _load_nc(raw: List[Byte]) raises -> RawDoc:
    var nc = read_nc4(Span(raw))
    var doc = RawDoc()
    var i32s = _var_f64(nc, String("i32s"))
    var i64s = _var_f64(nc, String("i64s"))
    doc.i32s = _as_ints(i32s^)
    doc.i64s = _as_ints(i64s^)
    doc.f64s = _var_f64(nc, String("f64s"))
    var nbytes_v = _var_f64(nc, String("text_nbytes"))
    if len(nbytes_v) == 1:
        var nbytes = Int(nbytes_v[0])
        var bits = _var_f64(nc, String("text_bits"))
        doc.text = _bytes_of(bits^, nbytes)
    return doc^


def _frame(src: RawDoc) -> List[Byte]:
    var b = List[Byte]()
    _put_u32(b, len(src.i32s))
    _put_u32(b, len(src.i64s))
    _put_u32(b, len(src.f64s))
    _put_u32(b, len(src.text))
    var i = 0
    while i < len(src.i32s):
        _put_u32(b, src.i32s[i])
        i += 1
    i = 0
    while i < len(src.i64s):
        _put_u64(b, src.i64s[i])
        i += 1
    i = 0
    while i < len(src.f64s):
        _put_f64(b, src.f64s[i])
        i += 1
    i = 0
    while i < len(src.text):
        b.append(src.text[i])
        i += 1
    return b^


def _unframe_doc(raw: List[Byte]) raises -> RawDoc:
    var doc = RawDoc()
    var at = 0
    var ni = _take_u32(raw, at)
    var nl = _take_u32(raw, at)
    var nf = _take_u32(raw, at)
    var nt = _take_u32(raw, at)
    var i = 0
    while i < ni:
        doc.i32s.append(_take_u32(raw, at))
        i += 1
    i = 0
    while i < nl:
        doc.i64s.append(_take_u64(raw, at))
        i += 1
    i = 0
    while i < nf:
        doc.f64s.append(_take_f64(raw, at))
        i += 1
    i = 0
    while i < nt:
        if at >= len(raw):
            raise Error("truncated text")
        doc.text.append(raw[at])
        at += 1
        i += 1
    return doc^


def _slurp(path: String) raises -> List[Byte]:
    var handle = open(path, "r")
    var data = handle.read_bytes()
    handle.close()
    return data^


def _spit(path: String, data: List[Byte]) raises:
    var handle = open(path, "w")
    handle.write_bytes(Span(data))
    handle.close()


def _rm_rf(path: String) raises:
    var args = List[String]()
    args.append(String("-rf"))
    args.append(path)
    var proc = Process.run(String("rm"), args^)
    _ = proc.wait()


def _pack_dir(path: String) raises -> List[Byte]:
    var data = _slurp(path + String("/data.0"))
    var idx = _slurp(path + String("/md.idx"))
    var md = _slurp(path + String("/md.0"))
    var mmd = _slurp(path + String("/mmd.0"))
    var out = List[Byte]()
    _put_u32(out, len(data))
    _put_u32(out, len(idx))
    _put_u32(out, len(md))
    _put_u32(out, len(mmd))
    var i = 0
    while i < len(data):
        out.append(data[i])
        i += 1
    i = 0
    while i < len(idx):
        out.append(idx[i])
        i += 1
    i = 0
    while i < len(md):
        out.append(md[i])
        i += 1
    i = 0
    while i < len(mmd):
        out.append(mmd[i])
        i += 1
    return out^


def _unpack_dir(path: String, raw: List[Byte]) raises:
    var at = 0
    var nd = _take_u32(raw, at)
    var ni = _take_u32(raw, at)
    var nm = _take_u32(raw, at)
    var nn = _take_u32(raw, at)
    var data = List[Byte]()
    var idx = List[Byte]()
    var md = List[Byte]()
    var mmd = List[Byte]()
    var i = 0
    while i < nd:
        data.append(raw[at])
        at += 1
        i += 1
    i = 0
    while i < ni:
        idx.append(raw[at])
        at += 1
        i += 1
    i = 0
    while i < nm:
        md.append(raw[at])
        at += 1
        i += 1
    i = 0
    while i < nn:
        mmd.append(raw[at])
        at += 1
        i += 1
    var args = List[String]()
    args.append(String("-p"))
    args.append(path)
    var proc = Process.run(String("mkdir"), args^)
    _ = proc.wait()
    _spit(path + String("/data.0"), data^)
    _spit(path + String("/md.idx"), idx^)
    _spit(path + String("/md.0"), md^)
    _spit(path + String("/mmd.0"), mmd^)


def _emit_bp(src: RawDoc, path: String) raises -> List[Byte]:
    var framed = _frame(src)
    var step = BpStep()
    step.var_name = String("payload")
    step.attr_name = String("nbytes")
    step.attr_text = String(len(framed))
    step.values = _bits_of(framed)
    write_bp5(path, step^)
    var packed = _pack_dir(path)
    _rm_rf(path)
    return packed^


def _load_bp(raw: List[Byte], path: String) raises -> RawDoc:
    _unpack_dir(path, raw)
    var step = read_bp5(path)
    _rm_rf(path)
    var nbytes = 0
    var text = step.attr_text
    var digits = text.as_bytes()
    var i = 0
    while i < len(digits):
        var c = Int(digits[i])
        if c < 48 or c > 57:
            raise Error("bp5 nbytes")
        nbytes = nbytes * 10 + (c - 48)
        i += 1
    var blob = _bytes_of(step.values, nbytes)
    return _unframe_doc(blob^)


struct Hdf5Ser:
    var version: String

    def __init__(out self):
        self.version = String(VERSION)

    def name(self) -> String:
        return "gld-hdf5"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var doc = _pack(fx)
        return _emit_h5(doc^)

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var doc = _load_h5(data)
        return _unpack(fx, doc^)

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))


struct NcSer:
    var version: String

    def __init__(out self):
        self.version = String(VERSION)

    def name(self) -> String:
        return "gld-netcdf"

    def serialize_bytes(self, fx: Fixture) raises -> List[Byte]:
        var doc = _pack(fx)
        return _emit_nc(doc^)

    def deserialize_bytes(self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var doc = _load_nc(data)
        return _unpack(fx, doc^)

    def check(self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))


struct AdiosSer:
    var version: String
    var seq: Int

    def __init__(out self):
        self.version = String(VERSION)
        self.seq = 0

    def name(self) -> String:
        return "gld-adios2"

    def _path(mut self) -> String:
        self.seq += 1
        return (
            String("/tmp/gld-bp5-")
            + String(self.seq)
            + String("-")
            + String(Int(perf_counter_ns()))
        )

    def serialize_bytes(mut self, fx: Fixture) raises -> List[Byte]:
        var doc = _pack(fx)
        return _emit_bp(doc^, self._path())

    def deserialize_bytes(mut self, fx: Fixture, data: List[Byte]) raises -> Fixture:
        var doc = _load_bp(data, self._path())
        return _unpack(fx, doc^)

    def check(mut self, fx: Fixture, data: List[Byte]) raises -> Bool:
        return fidelity(fx, self.deserialize_bytes(fx, data))
