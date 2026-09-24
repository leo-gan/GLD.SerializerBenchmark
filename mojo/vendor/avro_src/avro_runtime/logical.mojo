from std.collections import List, Span

from avro_runtime.error import DecodeError
from avro_schema.model import ST_BYTES, ST_FIXED, ST_INT, ST_LONG, ST_STRING
from avro_wire.reader import WireReader
from avro_wire.writer import WireWriter


comptime LT_NONE = 0
comptime LT_DECIMAL = 1
comptime LT_UUID = 2
comptime LT_DATE = 3
comptime LT_TIME_MILLIS = 4
comptime LT_TIME_MICROS = 5
comptime LT_TIMESTAMP_MILLIS = 6
comptime LT_TIMESTAMP_MICROS = 7
comptime LT_LOCAL_TIMESTAMP_MILLIS = 8
comptime LT_LOCAL_TIMESTAMP_MICROS = 9
comptime LT_DURATION = 10


def logical_underlying_ok(schema_kind: Int, size: Int, kind: Int) -> Bool:
    """True when the stored logicalType matches the Avro 1.11 underlying type."""
    if kind == LT_DECIMAL:
        return schema_kind == ST_BYTES or schema_kind == ST_FIXED
    if kind == LT_UUID:
        return schema_kind == ST_STRING
    if kind == LT_DATE or kind == LT_TIME_MILLIS:
        return schema_kind == ST_INT
    if (
        kind == LT_TIME_MICROS
        or kind == LT_TIMESTAMP_MILLIS
        or kind == LT_TIMESTAMP_MICROS
        or kind == LT_LOCAL_TIMESTAMP_MILLIS
        or kind == LT_LOCAL_TIMESTAMP_MICROS
    ):
        return schema_kind == ST_LONG
    if kind == LT_DURATION:
        return schema_kind == ST_FIXED and size == 12
    return False


def logical_kind(name: String) -> Int:
    if name == "decimal":
        return LT_DECIMAL
    if name == "uuid":
        return LT_UUID
    if name == "date":
        return LT_DATE
    if name == "time-millis":
        return LT_TIME_MILLIS
    if name == "time-micros":
        return LT_TIME_MICROS
    if name == "timestamp-millis":
        return LT_TIMESTAMP_MILLIS
    if name == "timestamp-micros":
        return LT_TIMESTAMP_MICROS
    if name == "local-timestamp-millis":
        return LT_LOCAL_TIMESTAMP_MILLIS
    if name == "local-timestamp-micros":
        return LT_LOCAL_TIMESTAMP_MICROS
    if name == "duration":
        return LT_DURATION
    return LT_NONE


def uuid_is_valid(s: String) -> Bool:
    if s.byte_length() != 36:
        return False
    var b = s.as_bytes()
    var i = 0
    while i < 36:
        if i == 8 or i == 13 or i == 18 or i == 23:
            if Int(b[i]) != 45:
                return False
        else:
            var c = Int(b[i])
            var hex = (c >= 48 and c <= 57) or (c >= 97 and c <= 102) or (
                c >= 65 and c <= 70
            )
            if not hex:
                return False
        i += 1
    return True


def time_millis_valid(ms: Int32) -> Bool:
    return ms >= 0 and ms < Int32(86400000)


def time_micros_valid(us: Int64) -> Bool:
    return us >= 0 and us < Int64(86400000000)


def days_from_civil(year: Int, month: Int, day: Int) -> Int32:
    """Days since 1970-01-01 (Howard Hinnant civil calendar)."""
    var y = year
    var m = month
    if m <= 2:
        y -= 1
    var era = y
    if y < 0:
        era = y - 399
    era = era // 400
    var yoe = y - era * 400
    var adj = m + 9
    if m > 2:
        adj = m - 3
    var doy = (153 * adj + 2) // 5 + day - 1
    var doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return Int32(era * 146097 + doe - 719468)


struct CivilDate(Copyable, Movable, Defaultable, ImplicitlyCopyable):
    var year: Int
    var month: Int
    var day: Int

    def __init__(out self):
        self.year = 1970
        self.month = 1
        self.day = 1

    def __init__(out self, year: Int, month: Int, day: Int):
        self.year = year
        self.month = month
        self.day = day


def civil_from_days(z0: Int32) -> CivilDate:
    var z = Int(z0) + 719468
    var era = z
    if z < 0:
        era = z - 146096
    era = era // 146097
    var doe = z - era * 146097
    var yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    var y = yoe + era * 400
    var doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    var mp = (5 * doy + 2) // 153
    var d = doy - (153 * mp + 2) // 5 + 1
    var m = mp + 3
    if mp >= 10:
        m = mp - 9
    if m <= 2:
        y += 1
    return CivilDate(y, m, d)


struct LogicalDuration(Copyable, Movable, Defaultable, ImplicitlyCopyable):
    var months: UInt32
    var days: UInt32
    var millis: UInt32

    def __init__(out self):
        self.months = 0
        self.days = 0
        self.millis = 0

    def __init__(out self, months: UInt32, days: UInt32, millis: UInt32):
        self.months = months
        self.days = days
        self.millis = millis


def duration_to_fixed(d: LogicalDuration) -> List[Byte]:
    var out = List[Byte]()
    _append_u32_le(out, d.months)
    _append_u32_le(out, d.days)
    _append_u32_le(out, d.millis)
    return out^


def duration_from_fixed(buf: List[Byte]) raises DecodeError -> LogicalDuration:
    if len(buf) != 12:
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    return LogicalDuration(_read_u32_le(buf, 0), _read_u32_le(buf, 4), _read_u32_le(buf, 8))


def decimal_unscaled_from_i64(value: Int64) -> List[Byte]:
    """Big-endian two's complement, at least one byte."""
    var bits = UInt64(value)
    var tmp = List[Byte]()
    var i = 7
    while i >= 0:
        tmp.append(Byte(Int((bits >> (UInt64(i) * 8)) & 0xFF)))
        i -= 1
    var start = 0
    while start < 7:
        var cur = Int(tmp[start])
        var nxt = Int(tmp[start + 1])
        if cur == 0 and (nxt & 0x80) == 0:
            start += 1
            continue
        if cur == 0xFF and (nxt & 0x80) != 0:
            start += 1
            continue
        break
    var out = List[Byte]()
    while start < 8:
        out.append(tmp[start])
        start += 1
    return out^


def decimal_unscaled_to_i64(buf: List[Byte]) raises DecodeError -> Int64:
    if len(buf) == 0 or len(buf) > 8:
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    var neg = Int(buf[0]) >= 0x80
    var bits: UInt64 = 0
    if neg:
        bits = 0xFFFFFFFFFFFFFFFF
    var i = 0
    while i < len(buf):
        bits = (bits << 8) | UInt64(buf[i])
        i += 1
    return Int64(bits)


def _append_u32_le(mut out: List[Byte], v: UInt32):
    var x = UInt64(v)
    out.append(Byte(Int(x & 0xFF)))
    out.append(Byte(Int((x >> 8) & 0xFF)))
    out.append(Byte(Int((x >> 16) & 0xFF)))
    out.append(Byte(Int((x >> 24) & 0xFF)))


def _read_u32_le(buf: List[Byte], off: Int) -> UInt32:
    var x = UInt64(buf[off])
    x |= UInt64(buf[off + 1]) << 8
    x |= UInt64(buf[off + 2]) << 16
    x |= UInt64(buf[off + 3]) << 24
    return UInt32(x)


def _write_byte_list(mut enc: WireWriter, data: List[Byte]):
    var i = 0
    while i < len(data):
        enc.write_byte(data[i])
        i += 1


def encode_date(year: Int, month: Int, day: Int) -> List[Byte]:
    var enc = WireWriter()
    enc.write_int(days_from_civil(year, month, day))
    return enc^.finish()


def decode_date[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> CivilDate:
    var dec = WireReader[origin](buf)
    return civil_from_days(dec.read_int())


def encode_uuid(s: String) raises DecodeError -> List[Byte]:
    if not uuid_is_valid(s):
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    var enc = WireWriter()
    enc.write_string(s)
    return enc^.finish()


def decode_uuid[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> String:
    var dec = WireReader[origin](buf)
    var s = dec.read_string()
    if not uuid_is_valid(s):
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    return s


def encode_time_millis(ms: Int32) raises DecodeError -> List[Byte]:
    if not time_millis_valid(ms):
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    var enc = WireWriter()
    enc.write_int(ms)
    return enc^.finish()


def decode_time_millis[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Int32:
    var dec = WireReader[origin](buf)
    var ms = dec.read_int()
    if not time_millis_valid(ms):
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    return ms


def encode_time_micros(us: Int64) raises DecodeError -> List[Byte]:
    if not time_micros_valid(us):
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    var enc = WireWriter()
    enc.write_long(us)
    return enc^.finish()


def decode_time_micros[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Int64:
    var dec = WireReader[origin](buf)
    var us = dec.read_long()
    if not time_micros_valid(us):
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    return us


def encode_timestamp_millis(ms: Int64) -> List[Byte]:
    var enc = WireWriter()
    enc.write_long(ms)
    return enc^.finish()


def decode_timestamp_millis[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Int64:
    var dec = WireReader[origin](buf)
    return dec.read_long()


def encode_timestamp_micros(us: Int64) -> List[Byte]:
    var enc = WireWriter()
    enc.write_long(us)
    return enc^.finish()


def decode_timestamp_micros[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Int64:
    var dec = WireReader[origin](buf)
    return dec.read_long()


def encode_local_timestamp_millis(ms: Int64) -> List[Byte]:
    return encode_timestamp_millis(ms)


def decode_local_timestamp_millis[
    origin: ImmOrigin
](buf: Span[Byte, origin]) raises DecodeError -> Int64:
    return decode_timestamp_millis(buf)


def encode_local_timestamp_micros(us: Int64) -> List[Byte]:
    return encode_timestamp_micros(us)


def decode_local_timestamp_micros[
    origin: ImmOrigin
](buf: Span[Byte, origin]) raises DecodeError -> Int64:
    return decode_timestamp_micros(buf)


def encode_duration(d: LogicalDuration) -> List[Byte]:
    var raw = duration_to_fixed(d)
    var enc = WireWriter()
    _write_byte_list(enc, raw)
    return enc^.finish()


def decode_duration[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> LogicalDuration:
    var dec = WireReader[origin](buf)
    return duration_from_fixed(dec.read_fixed(12))


def encode_decimal(value: Int64) -> List[Byte]:
    """Decimal on `bytes`: length-prefixed unscaled big-endian two's complement."""
    var raw = decimal_unscaled_from_i64(value)
    var enc = WireWriter()
    enc.write_long(Int64(len(raw)))
    _write_byte_list(enc, raw)
    return enc^.finish()


def decode_decimal[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> Int64:
    var dec = WireReader[origin](buf)
    return decimal_unscaled_to_i64(dec.read_bytes())


def encode_decimal_fixed(value: Int64, size: Int) raises DecodeError -> List[Byte]:
    """Decimal on `fixed`: sign-extended unscaled integer, no length prefix."""
    var raw = decimal_unscaled_from_i64(value)
    if size < 1 or len(raw) > size:
        raise DecodeError(DecodeError.KIND_RANGE, 0)
    var pad = Byte(0)
    if Int(raw[0]) >= 0x80:
        pad = Byte(0xFF)
    var enc = WireWriter()
    var i = 0
    while i < size - len(raw):
        enc.write_byte(pad)
        i += 1
    _write_byte_list(enc, raw)
    return enc^.finish()


def decode_decimal_fixed[
    origin: ImmOrigin
](buf: Span[Byte, origin], size: Int) raises DecodeError -> Int64:
    var dec = WireReader[origin](buf)
    return decimal_unscaled_to_i64(dec.read_fixed(size))
