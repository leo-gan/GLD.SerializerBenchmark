from std.collections import List, Span

from flight.hpack import Hpack
from flight.proto import (
    each_bytes,
    each_string,
    encode_action_type,
    encode_cancel_result,
    encode_close_result,
    encode_descriptor_path,
    encode_endpoint,
    encode_flight_data,
    encode_handshake,
    encode_info,
    encode_option_bool,
    encode_option_entry,
    encode_option_int,
    encode_option_string,
    encode_poll,
    encode_put_result,
    encode_result,
    encode_schema_result,
    encode_set_options,
    f64_of,
    find_bytes,
    find_fixed,
    find_string,
    find_varint,
    has_field,
    parse_fields,
    slice_of,
)
from arrow_runtime.error import DecodeError


comptime REUSE = "arrow-flight-reuse-connection://?"
comptime SERVICE = "/arrow.flight.protocol.FlightService/"


struct FlightMem:
    var schema: List[Byte]
    var batch: List[Byte]
    var session: String
    var closed: Int
    var opt_key: List[String]
    var opt_kind: List[Int]
    var opt_str: List[String]
    var opt_i64: List[Int]

    def __init__(out self):
        self.schema = List[Byte]()
        self.batch = List[Byte]()
        self.session = String("")
        self.closed = 0
        self.opt_key = List[String]()
        self.opt_kind = List[Int]()
        self.opt_str = List[String]()
        self.opt_i64 = List[Int]()


struct RpcReply:
    var status: Int
    var cookie: String
    var bodies: List[Byte]
    var lens: List[Int]

    def __init__(out self):
        self.status = 0
        self.cookie = String("")
        self.bodies = List[Byte]()
        self.lens = List[Int]()


def flight_call(mut mem: FlightMem, method: String, payload: List[Byte], cookie: String) raises DecodeError -> RpcReply:
    var req = _client_bytes(method, payload, cookie)
    var resp = _serve(mem, req)
    return _parse_response(resp)


def _client_bytes(method: String, payload: List[Byte], cookie: String) -> List[Byte]:
    var out = List[Byte]()
    _ascii(out, "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    var empty = List[Byte]()
    _frame(out, 4, 0, 0, empty)
    var enc = Hpack()
    var block = List[Byte]()
    enc.encode_indexed(block, 3)
    enc.encode_indexed(block, 6)
    var path = SERVICE + method
    enc.encode_named(block, 4, path)
    enc.encode_named(block, 1, "localhost")
    enc.encode_literal(block, "content-type", "application/grpc", 0)
    enc.encode_literal(block, "te", "trailers", 0)
    if cookie != "":
        enc.encode_named(block, 32, cookie)
    _frame(out, 1, 0x04, 1, block)
    var data = _grpc_one(payload)
    _frame(out, 0, 0x01, 1, data)
    return out^


def _serve(mut mem: FlightMem, raw: List[Byte]) raises DecodeError -> List[Byte]:
    var names = List[String]()
    var values = List[String]()
    var data = List[Byte]()
    var dec = Hpack()
    var i = 0
    if _has_preface(raw):
        i = 24
    var n = len(raw)
    while i + 9 <= n:
        var length = (Int(raw[i]) << 16) | (Int(raw[i + 1]) << 8) | Int(raw[i + 2])
        var typ = Int(raw[i + 3])
        var stream = Int(raw[i + 5] & 0x7F) << 24
        stream = stream | (Int(raw[i + 6]) << 16) | (Int(raw[i + 7]) << 8) | Int(raw[i + 8])
        if length < 0 or i + 9 + length > n:
            raise DecodeError(DecodeError.KIND_FLIGHT, i)
        var payload = slice_of(raw, i + 9, length)
        i += 9 + length
        if stream == 1 and typ == 1:
            dec.decode(payload, names, values)
        elif stream == 1 and typ == 0:
            var k = 0
            while k < len(payload):
                data.append(payload[k])
                k += 1
    var path = _header(names, values, ":path")
    var cookie = _header(names, values, "cookie")
    var method = _method_of(path)
    var messages = List[Byte]()
    var mlens = List[Int]()
    _grpc_split(data, messages, mlens)
    var first = List[Byte]()
    if len(mlens) > 0:
        first = slice_of(messages, 0, mlens[0])
    var status = 0
    var set_cookie = String("")
    var bodies = List[Byte]()
    var lens = List[Int]()
    if method == "Handshake":
        var fields = parse_fields(first, 0, len(first))
        var version = find_varint(fields, 1, 0)
        var payload = find_bytes(first, fields, 2)
        _push(bodies, lens, encode_handshake(version, payload))
    elif method == "ListFlights":
        _push(bodies, lens, _info(mem))
    elif method == "GetFlightInfo":
        if _known(first) == 0:
            status = 5
        else:
            _push(bodies, lens, _info(mem))
    elif method == "PollFlightInfo":
        if _known(first) == 0:
            status = 5
        else:
            _push(bodies, lens, encode_poll(_info(mem), Float64(1.0), 1700000000))
    elif method == "GetSchema":
        if _known(first) == 0:
            status = 5
        else:
            _push(bodies, lens, encode_schema_result(mem.schema))
    elif method == "DoGet":
        var fields = parse_fields(first, 0, len(first))
        var ticket = find_bytes(first, fields, 1)
        if not _bytes_eq(ticket, _text_bytes("t1")):
            status = 5
        else:
            var meta = _text_bytes("ok")
            _push(bodies, lens, encode_flight_data(mem.schema, mem.batch, meta))
    elif method == "DoPut":
        var fields = parse_fields(first, 0, len(first))
        var meta = find_bytes(first, fields, 3)
        if len(meta) == 0:
            meta = _text_bytes("ok")
        _push(bodies, lens, encode_put_result(meta))
    elif method == "DoExchange":
        var fields = parse_fields(first, 0, len(first))
        var body = find_bytes(first, fields, 1000)
        var meta = _text_bytes("echo")
        var header = List[Byte]()
        _push(bodies, lens, encode_flight_data(header, body, meta))
    elif method == "DoAction":
        status = _action(mem, first, cookie, bodies, lens, set_cookie)
    elif method == "ListActions":
        _push(bodies, lens, encode_action_type("CancelFlightInfo", "Cancel a query"))
        _push(bodies, lens, encode_action_type("RenewFlightEndpoint", "Renew an endpoint"))
        _push(bodies, lens, encode_action_type("CloseSession", "Close the session"))
        _push(bodies, lens, encode_action_type("SetSessionOptions", "Set session options"))
        _push(bodies, lens, encode_action_type("GetSessionOptions", "Read session options"))
    else:
        status = 12
    var out = List[Byte]()
    var empty = List[Byte]()
    _frame(out, 4, 0, 0, empty)
    _frame(out, 4, 0x01, 0, empty)
    var enc = Hpack()
    var block = List[Byte]()
    enc.encode_indexed(block, 8)
    enc.encode_named(block, 31, "application/grpc")
    if set_cookie != "":
        enc.encode_named(block, 55, set_cookie)
    _frame(out, 1, 0x04, 1, block)
    if len(lens) > 0:
        var framed = _grpc_join(bodies, lens)
        _frame(out, 0, 0, 1, framed)
    var trail = List[Byte]()
    enc.encode_literal(trail, "grpc-status", _status_text(status), 0)
    _frame(out, 1, 0x05, 1, trail)
    return out^


def _action(mut mem: FlightMem, raw: List[Byte], cookie: String, mut bodies: List[Byte], mut lens: List[Int], mut set_cookie: String) raises DecodeError -> Int:
    var fields = parse_fields(raw, 0, len(raw))
    var kind = find_string(raw, fields, 1)
    var body = find_bytes(raw, fields, 2)
    if kind == "CancelFlightInfo":
        _push(bodies, lens, encode_result(encode_cancel_result(1)))
        return 0
    if kind == "RenewFlightEndpoint":
        var inner = parse_fields(body, 0, len(body))
        var endpoint = find_bytes(body, inner, 1)
        _push(bodies, lens, encode_result(endpoint))
        return 0
    if kind == "CloseSession":
        var expect = "arrow_flight_session_id=" + mem.session
        if mem.session == "" or mem.closed != 0 or cookie != expect:
            return 5
        mem.session = String("")
        mem.closed = 1
        mem.opt_key = List[String]()
        mem.opt_kind = List[Int]()
        mem.opt_str = List[String]()
        mem.opt_i64 = List[Int]()
        _push(bodies, lens, encode_result(encode_close_result(1)))
        return 0
    if kind == "SetSessionOptions":
        _store_options(mem, body)
        if mem.session == "":
            mem.session = String("s1")
            mem.closed = 0
        set_cookie = "arrow_flight_session_id=" + mem.session
        var none = List[Byte]()
        var nl = List[Int]()
        _push(bodies, lens, encode_set_options(none, nl))
        return 0
    if kind == "GetSessionOptions":
        var expect = "arrow_flight_session_id=" + mem.session
        if mem.closed != 0 or mem.session == "" or cookie != expect:
            return 5
        _push(bodies, lens, _options_message(mem))
        return 0
    return 12


def _store_options(mut mem: FlightMem, raw: List[Byte]) raises DecodeError:
    mem.opt_key = List[String]()
    mem.opt_kind = List[Int]()
    mem.opt_str = List[String]()
    mem.opt_i64 = List[Int]()
    var fields = parse_fields(raw, 0, len(raw))
    var ids = each_bytes(raw, fields, 1)
    var i = 0
    while i < len(ids):
        var entry = fields[ids[i]]
        var bytes = slice_of(raw, entry.start, entry.size)
        var inner = parse_fields(bytes, 0, len(bytes))
        var key = find_string(bytes, inner, 1)
        var value = find_bytes(bytes, inner, 2)
        var vf = parse_fields(value, 0, len(value))
        mem.opt_key.append(key)
        if has_field(vf, 1) != 0:
            mem.opt_kind.append(1)
            mem.opt_str.append(find_string(value, vf, 1))
            mem.opt_i64.append(0)
        elif has_field(vf, 2) != 0:
            mem.opt_kind.append(2)
            mem.opt_str.append(String(""))
            mem.opt_i64.append(find_varint(vf, 2, 0))
        elif has_field(vf, 3) != 0:
            mem.opt_kind.append(3)
            mem.opt_str.append(String(""))
            mem.opt_i64.append(_as_fixed(find_fixed(vf, 3)))
        else:
            mem.opt_kind.append(0)
            mem.opt_str.append(String(""))
            mem.opt_i64.append(0)
        i += 1


def _options_message(mem: FlightMem) -> List[Byte]:
    var packed = List[Byte]()
    var lens = List[Int]()
    var i = 0
    while i < len(mem.opt_key):
        var value = List[Byte]()
        if mem.opt_kind[i] == 1:
            value = encode_option_string(mem.opt_str[i])
        elif mem.opt_kind[i] == 2:
            value = encode_option_bool(mem.opt_i64[i])
        elif mem.opt_kind[i] == 3:
            value = encode_option_int(mem.opt_i64[i])
        var entry = encode_option_entry(mem.opt_key[i], value)
        var k = 0
        while k < len(entry):
            packed.append(entry[k])
            k += 1
        lens.append(len(entry))
        i += 1
    return encode_set_options(packed, lens)


def _info(mem: FlightMem) -> List[Byte]:
    var path = List[String]()
    path.append("orders")
    var desc = encode_descriptor_path(path)
    var ticket = _text_bytes("t1")
    var endpoint = encode_endpoint(ticket, REUSE)
    return encode_info(mem.schema, desc, endpoint, 3, len(mem.batch))


def _known(raw: List[Byte]) raises DecodeError -> Int:
    if len(raw) == 0:
        return 0
    var fields = parse_fields(raw, 0, len(raw))
    var kind = find_varint(fields, 1, 0)
    if kind == 1:
        var paths = each_string(raw, fields, 3)
        if len(paths) == 1 and paths[0] == "orders":
            return 1
        return 0
    if kind == 2:
        var cmd = find_bytes(raw, fields, 2)
        if _bytes_eq(cmd, _text_bytes("orders")):
            return 1
    return 0


def _parse_response(raw: List[Byte]) raises DecodeError -> RpcReply:
    var reply = RpcReply()
    var names = List[String]()
    var values = List[String]()
    var data = List[Byte]()
    var dec = Hpack()
    var i = 0
    var n = len(raw)
    while i + 9 <= n:
        var length = (Int(raw[i]) << 16) | (Int(raw[i + 1]) << 8) | Int(raw[i + 2])
        var typ = Int(raw[i + 3])
        var stream = Int(raw[i + 5] & 0x7F) << 24
        stream = stream | (Int(raw[i + 6]) << 16) | (Int(raw[i + 7]) << 8) | Int(raw[i + 8])
        if length < 0 or i + 9 + length > n:
            raise DecodeError(DecodeError.KIND_FLIGHT, i)
        var payload = slice_of(raw, i + 9, length)
        i += 9 + length
        if stream == 1 and typ == 1:
            dec.decode(payload, names, values)
        elif stream == 1 and typ == 0:
            var k = 0
            while k < len(payload):
                data.append(payload[k])
                k += 1
    reply.cookie = _header(names, values, "set-cookie")
    var status_text = _header(names, values, "grpc-status")
    reply.status = _parse_status(status_text)
    _grpc_split(data, reply.bodies, reply.lens)
    return reply^


def _method_of(path: String) -> String:
    var prefix = String(SERVICE)
    if path.byte_length() <= prefix.byte_length():
        return String("")
    var pb = prefix.as_bytes()
    var hb = path.as_bytes()
    var i = 0
    while i < len(pb):
        if hb[i] != pb[i]:
            return String("")
        i += 1
    var rest = List[Byte]()
    while i < len(hb):
        rest.append(hb[i])
        i += 1
    return String(unsafe_from_utf8=Span(rest))


def _header(names: List[String], values: List[String], key: String) -> String:
    var i = 0
    while i < len(names):
        if names[i] == key:
            return values[i]
        i += 1
    return String("")


def _status_text(code: Int) -> String:
    if code == 0:
        return String("0")
    if code == 5:
        return String("5")
    if code == 12:
        return String("12")
    return String("2")


def _parse_status(text: String) -> Int:
    if text == "0":
        return 0
    if text == "5":
        return 5
    if text == "12":
        return 12
    if text == "":
        return 2
    return 2


def _push(mut bodies: List[Byte], mut lens: List[Int], msg: List[Byte]):
    var i = 0
    while i < len(msg):
        bodies.append(msg[i])
        i += 1
    lens.append(len(msg))


def _frame(mut out: List[Byte], typ: Int, flags: Int, stream: Int, payload: List[Byte]):
    var n = len(payload)
    out.append(Byte((n >> 16) & 255))
    out.append(Byte((n >> 8) & 255))
    out.append(Byte(n & 255))
    out.append(Byte(typ))
    out.append(Byte(flags))
    out.append(Byte((stream >> 24) & 0x7F))
    out.append(Byte((stream >> 16) & 255))
    out.append(Byte((stream >> 8) & 255))
    out.append(Byte(stream & 255))
    var i = 0
    while i < n:
        out.append(payload[i])
        i += 1


def _grpc_one(msg: List[Byte]) -> List[Byte]:
    var out = List[Byte]()
    var n = len(msg)
    out.append(Byte(0))
    out.append(Byte((n >> 24) & 255))
    out.append(Byte((n >> 16) & 255))
    out.append(Byte((n >> 8) & 255))
    out.append(Byte(n & 255))
    var i = 0
    while i < n:
        out.append(msg[i])
        i += 1
    return out^


def _grpc_join(bodies: List[Byte], lens: List[Int]) -> List[Byte]:
    var out = List[Byte]()
    var off = 0
    var i = 0
    while i < len(lens):
        var part = slice_of(bodies, off, lens[i])
        var framed = _grpc_one(part)
        var k = 0
        while k < len(framed):
            out.append(framed[k])
            k += 1
        off += lens[i]
        i += 1
    return out^


def _grpc_split(data: List[Byte], mut bodies: List[Byte], mut lens: List[Int]) raises DecodeError:
    var i = 0
    while i < len(data):
        if i + 5 > len(data):
            raise DecodeError(DecodeError.KIND_FLIGHT, i)
        if Int(data[i]) != 0:
            raise DecodeError(DecodeError.KIND_FLIGHT, i)
        var n = (Int(data[i + 1]) << 24) | (Int(data[i + 2]) << 16) | (Int(data[i + 3]) << 8) | Int(data[i + 4])
        i += 5
        if n < 0 or i + n > len(data):
            raise DecodeError(DecodeError.KIND_FLIGHT, i)
        var k = 0
        while k < n:
            bodies.append(data[i + k])
            k += 1
        lens.append(n)
        i += n


def _has_preface(raw: List[Byte]) -> Bool:
    var text = String("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    var b = text.as_bytes()
    if len(raw) < len(b):
        return False
    var i = 0
    while i < len(b):
        if raw[i] != b[i]:
            return False
        i += 1
    return True


def _ascii(mut out: List[Byte], text: String):
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        out.append(b[i])
        i += 1


def _text_bytes(text: String) -> List[Byte]:
    var out = List[Byte]()
    _ascii(out, text)
    return out^


def _bytes_eq(a: List[Byte], b: List[Byte]) -> Bool:
    if len(a) != len(b):
        return False
    var i = 0
    while i < len(a):
        if a[i] != b[i]:
            return False
        i += 1
    return True


def _as_fixed(u: UInt64) -> Int:
    if u <= UInt64(9223372036854775807):
        return Int(u)
    var neg = UInt64(0) - u
    return 0 - Int(neg)
