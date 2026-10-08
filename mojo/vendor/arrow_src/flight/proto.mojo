from std.collections import List, Span
from std.memory import bitcast

from arrow_runtime.error import DecodeError


struct PField(Copyable, ImplicitlyCopyable):
    var num: Int
    var wire: Int
    var start: Int
    var size: Int
    var u: UInt64

    def __init__(out self, num: Int, wire: Int, start: Int, size: Int, u: UInt64):
        self.num = num
        self.wire = wire
        self.start = start
        self.size = size
        self.u = u


def parse_fields(raw: List[Byte], begin: Int, end: Int) raises DecodeError -> List[PField]:
    var out = List[PField]()
    var i = begin
    while i < end:
        var tag = _varint(raw, i, end)
        var field = Int(tag >> 3)
        var wire = Int(tag & 7)
        if field <= 0:
            raise DecodeError(DecodeError.KIND_FLIGHT, i)
        if wire == 0:
            var u = _varint(raw, i, end)
            out.append(PField(field, 0, i, 0, u))
        elif wire == 1:
            if i + 8 > end:
                raise DecodeError(DecodeError.KIND_FLIGHT, i)
            var u = _u64(raw, i)
            out.append(PField(field, 1, i, 8, u))
            i += 8
        elif wire == 2:
            var ln = Int(_varint(raw, i, end))
            if ln < 0 or i + ln > end:
                raise DecodeError(DecodeError.KIND_FLIGHT, i)
            out.append(PField(field, 2, i, ln, UInt64(ln)))
            i += ln
        elif wire == 5:
            if i + 4 > end:
                raise DecodeError(DecodeError.KIND_FLIGHT, i)
            i += 4
        else:
            raise DecodeError(DecodeError.KIND_FLIGHT, i)
    return out^


def put_varint(mut b: List[Byte], v: UInt64):
    var x = v
    while True:
        var byte = Int(x & 0x7F)
        x = x >> 7
        if x != 0:
            b.append(Byte(byte | 0x80))
        else:
            b.append(Byte(byte))
            break


def put_key(mut b: List[Byte], field: Int, wire: Int):
    put_varint(b, UInt64((field << 3) | wire))


def put_int(mut b: List[Byte], field: Int, v: Int):
    put_key(b, field, 0)
    put_varint(b, _i64_bits(v))


def put_bool(mut b: List[Byte], field: Int, v: Int):
    put_key(b, field, 0)
    if v != 0:
        b.append(Byte(1))
    else:
        b.append(Byte(0))


def put_bytes(mut b: List[Byte], field: Int, raw: List[Byte]):
    put_key(b, field, 2)
    put_varint(b, UInt64(len(raw)))
    var i = 0
    while i < len(raw):
        b.append(raw[i])
        i += 1


def put_str(mut b: List[Byte], field: Int, text: String):
    var raw = List[Byte]()
    var bytes = text.as_bytes()
    var i = 0
    while i < len(bytes):
        raw.append(bytes[i])
        i += 1
    put_bytes(b, field, raw)


def put_msg(mut b: List[Byte], field: Int, raw: List[Byte]):
    put_bytes(b, field, raw)


def put_sfixed64(mut b: List[Byte], field: Int, v: Int):
    put_key(b, field, 1)
    var u = _i64_bits(v)
    var i = 0
    while i < 8:
        b.append(Byte(Int((u >> UInt64(8 * i)) & 0xFF)))
        i += 1


def put_f64(mut b: List[Byte], field: Int, v: Float64):
    put_key(b, field, 1)
    var u = UInt64(bitcast[DType.uint64](v))
    var i = 0
    while i < 8:
        b.append(Byte(Int((u >> UInt64(8 * i)) & 0xFF)))
        i += 1


def slice_of(raw: List[Byte], start: Int, size: Int) -> List[Byte]:
    var out = List[Byte]()
    var i = 0
    while i < size:
        out.append(raw[start + i])
        i += 1
    return out^


def as_string(raw: List[Byte], start: Int, size: Int) -> String:
    var tmp = slice_of(raw, start, size)
    return String(unsafe_from_utf8=Span(tmp))


def find_varint(fields: List[PField], num: Int, default: Int) -> Int:
    var i = 0
    while i < len(fields):
        if fields[i].num == num and fields[i].wire == 0:
            return _as_i64(fields[i].u)
        i += 1
    return default


def find_fixed(fields: List[PField], num: Int) -> UInt64:
    var i = 0
    while i < len(fields):
        if fields[i].num == num and fields[i].wire == 1:
            return fields[i].u
        i += 1
    return UInt64(0)


def has_field(fields: List[PField], num: Int) -> Int:
    var i = 0
    while i < len(fields):
        if fields[i].num == num:
            return 1
        i += 1
    return 0


def find_bytes(raw: List[Byte], fields: List[PField], num: Int) -> List[Byte]:
    var i = 0
    while i < len(fields):
        if fields[i].num == num and fields[i].wire == 2:
            return slice_of(raw, fields[i].start, fields[i].size)
        i += 1
    return List[Byte]()


def find_string(raw: List[Byte], fields: List[PField], num: Int) -> String:
    var i = 0
    while i < len(fields):
        if fields[i].num == num and fields[i].wire == 2:
            return as_string(raw, fields[i].start, fields[i].size)
        i += 1
    return String("")


def each_bytes(raw: List[Byte], fields: List[PField], num: Int) -> List[Int]:
    var at = List[Int]()
    var i = 0
    while i < len(fields):
        if fields[i].num == num and fields[i].wire == 2:
            at.append(i)
        i += 1
    return at^


def each_string(raw: List[Byte], fields: List[PField], num: Int) -> List[String]:
    var out = List[String]()
    var ids = each_bytes(raw, fields, num)
    var i = 0
    while i < len(ids):
        var f = fields[ids[i]]
        out.append(as_string(raw, f.start, f.size))
        i += 1
    return out^


def f64_of(u: UInt64) -> Float64:
    return Float64(from_bits=u)


def encode_handshake(version: Int, payload: List[Byte]) -> List[Byte]:
    var b = List[Byte]()
    put_int(b, 1, version)
    put_bytes(b, 2, payload)
    return b^


def encode_descriptor_path(path: List[String]) -> List[Byte]:
    var b = List[Byte]()
    put_int(b, 1, 1)
    var i = 0
    while i < len(path):
        put_str(b, 3, path[i])
        i += 1
    return b^


def encode_descriptor_cmd(cmd: List[Byte]) -> List[Byte]:
    var b = List[Byte]()
    put_int(b, 1, 2)
    put_bytes(b, 2, cmd)
    return b^


def encode_ticket(ticket: List[Byte]) -> List[Byte]:
    var b = List[Byte]()
    put_bytes(b, 1, ticket)
    return b^


def encode_location(uri: String) -> List[Byte]:
    var b = List[Byte]()
    put_str(b, 1, uri)
    return b^


def encode_timestamp(seconds: Int, nanos: Int) -> List[Byte]:
    var b = List[Byte]()
    if seconds != 0:
        put_int(b, 1, seconds)
    if nanos != 0:
        put_int(b, 2, nanos)
    return b^


def encode_endpoint(ticket: List[Byte], uri: String) -> List[Byte]:
    var b = List[Byte]()
    var t = encode_ticket(ticket)
    put_msg(b, 1, t)
    var loc = encode_location(uri)
    put_msg(b, 2, loc)
    return b^


def encode_info(schema: List[Byte], desc: List[Byte], endpoint: List[Byte], records: Int, nbytes: Int) -> List[Byte]:
    var b = List[Byte]()
    put_bytes(b, 1, schema)
    put_msg(b, 2, desc)
    put_msg(b, 3, endpoint)
    put_int(b, 4, records)
    put_int(b, 5, nbytes)
    put_bool(b, 6, 1)
    return b^


def encode_poll(info: List[Byte], progress: Float64, seconds: Int) -> List[Byte]:
    var b = List[Byte]()
    put_msg(b, 1, info)
    put_f64(b, 3, progress)
    var ts = encode_timestamp(seconds, 0)
    put_msg(b, 4, ts)
    return b^


def encode_flight_data(header: List[Byte], body: List[Byte], meta: List[Byte]) -> List[Byte]:
    var b = List[Byte]()
    if len(header) > 0:
        put_bytes(b, 2, header)
    if len(meta) > 0:
        put_bytes(b, 3, meta)
    put_bytes(b, 1000, body)
    return b^


def encode_action(kind: String, body: List[Byte]) -> List[Byte]:
    var b = List[Byte]()
    put_str(b, 1, kind)
    put_bytes(b, 2, body)
    return b^


def encode_result(body: List[Byte]) -> List[Byte]:
    var b = List[Byte]()
    put_bytes(b, 1, body)
    return b^


def encode_action_type(kind: String, description: String) -> List[Byte]:
    var b = List[Byte]()
    put_str(b, 1, kind)
    put_str(b, 2, description)
    return b^


def encode_schema_result(schema: List[Byte]) -> List[Byte]:
    var b = List[Byte]()
    put_bytes(b, 1, schema)
    return b^


def encode_put_result(meta: List[Byte]) -> List[Byte]:
    var b = List[Byte]()
    put_bytes(b, 1, meta)
    return b^


def encode_cancel_result(status: Int) -> List[Byte]:
    var b = List[Byte]()
    put_int(b, 1, status)
    return b^


def encode_close_result(status: Int) -> List[Byte]:
    var b = List[Byte]()
    put_int(b, 1, status)
    return b^


def encode_option_string(text: String) -> List[Byte]:
    var b = List[Byte]()
    put_str(b, 1, text)
    return b^


def encode_option_bool(v: Int) -> List[Byte]:
    var b = List[Byte]()
    put_bool(b, 2, v)
    return b^


def encode_option_int(v: Int) -> List[Byte]:
    var b = List[Byte]()
    put_sfixed64(b, 3, v)
    return b^


def encode_option_entry(key: String, value: List[Byte]) -> List[Byte]:
    var b = List[Byte]()
    put_str(b, 1, key)
    put_msg(b, 2, value)
    return b^


def encode_set_options(entries: List[Byte], lens: List[Int]) -> List[Byte]:
    var b = List[Byte]()
    var off = 0
    var i = 0
    while i < len(lens):
        var part = slice_of(entries, off, lens[i])
        put_msg(b, 1, part)
        off += lens[i]
        i += 1
    return b^


def _varint(raw: List[Byte], mut i: Int, end: Int) raises DecodeError -> UInt64:
    var shift = UInt64(0)
    var out = UInt64(0)
    var guard = 0
    while i < end and guard < 10:
        var b = UInt64(Int(raw[i]))
        i += 1
        out = out | ((b & 0x7F) << shift)
        if (b & 0x80) == 0:
            return out
        shift += 7
        guard += 1
    raise DecodeError(DecodeError.KIND_FLIGHT, i)


def _u64(raw: List[Byte], i: Int) -> UInt64:
    var x = UInt64(0)
    var k = 0
    while k < 8:
        x = x | (UInt64(Int(raw[i + k])) << UInt64(8 * k))
        k += 1
    return x


def _i64_bits(v: Int) -> UInt64:
    return UInt64(v)


def _as_i64(u: UInt64) -> Int:
    if u <= UInt64(9223372036854775807):
        return Int(u)
    var neg = UInt64(0) - u
    return 0 - Int(neg)
