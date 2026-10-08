from std.collections import List, Span

from parquet_runtime.error import DecodeError


comptime MAX_BYTES = 268435456


def buf_need(have: Int, want: Int, at: Int) raises DecodeError:
    if want < 0 or at < 0 or at > have or want > have - at:
        raise DecodeError(DecodeError.KIND_EOF, at)
    if want > MAX_BYTES:
        raise DecodeError(DecodeError.KIND_RANGE, at)


def put_u8(mut b: List[Byte], v: Int):
    b.append(Byte(v & 255))


def put_u16(mut b: List[Byte], v: Int):
    put_u8(b, v)
    put_u8(b, v >> 8)


def put_u32(mut b: List[Byte], v: Int):
    put_u8(b, v)
    put_u8(b, v >> 8)
    put_u8(b, v >> 16)
    put_u8(b, v >> 24)


def put_u64(mut b: List[Byte], v: UInt64):
    var x = v
    var i = 0
    while i < 8:
        b.append(Byte(Int(x & 0xFF)))
        x = x >> UInt64(8)
        i += 1


def put_i32(mut b: List[Byte], v: Int):
    var u = v
    if u < 0:
        u = u + 4294967296
    put_u32(b, u)


def put_i64(mut b: List[Byte], v: Int):
    put_u64(b, UInt64(v))


def extend_span[origin: ImmOrigin](mut dst: List[Byte], raw: Span[Byte, origin]):
    var base = len(dst)
    var n = len(raw)
    if n == 0:
        return
    dst.resize(base + n, Byte(0))
    var i = 0
    while i < n:
        dst[base + i] = raw[i]
        i += 1


def extend_list(mut dst: List[Byte], raw: List[Byte]):
    extend_span(dst, Span(raw))


def u8_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    buf_need(len(raw), 1, i)
    return Int(raw[i])


def u32_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    buf_need(len(raw), 4, i)
    return Int(raw[i]) | (Int(raw[i + 1]) << 8) | (Int(raw[i + 2]) << 16) | (Int(raw[i + 3]) << 24)


def u64_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> UInt64:
    buf_need(len(raw), 8, i)
    var x = UInt64(0)
    var k = 7
    while k >= 0:
        x = (x << UInt64(8)) | UInt64(Int(raw[i + k]))
        k -= 1
    return x


def i32_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    var u = u32_at(raw, i)
    if u >= 2147483648:
        return u - 4294967296
    return u


def i64_of(u: UInt64) -> Int:
    if u > 9223372036854775807:
        return Int(u - 9223372036854775808) - 9223372036854775807 - 1
    return Int(u)


def i64_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    return i64_of(u64_at(raw, i))


def list_u32(data: List[Byte], i: Int) raises DecodeError -> Int:
    return u32_at(Span(data), i)


def list_i32(data: List[Byte], i: Int) raises DecodeError -> Int:
    return i32_at(Span(data), i)


def list_i64(data: List[Byte], i: Int) raises DecodeError -> Int:
    return i64_at(Span(data), i)


def slice_list(data: List[Byte], off: Int, n: Int) -> List[Byte]:
    var out = List[Byte]()
    if n <= 0:
        return out^
    out.resize(n, Byte(0))
    var i = 0
    while i < n:
        out[i] = data[off + i]
        i += 1
    return out^


comptime _CRC_TABLE: List[Int] = [
        0, 1996959894, 3993919788, 2567524794, 124634137, 1886057615, 3915621685, 2657392035,
        249268274, 2044508324, 3772115230, 2547177864, 162941995, 2125561021, 3887607047, 2428444049,
        498536548, 1789927666, 4089016648, 2227061214, 450548861, 1843258603, 4107580753, 2211677639,
        325883990, 1684777152, 4251122042, 2321926636, 335633487, 1661365465, 4195302755, 2366115317,
        997073096, 1281953886, 3579855332, 2724688242, 1006888145, 1258607687, 3524101629, 2768942443,
        901097722, 1119000684, 3686517206, 2898065728, 853044451, 1172266101, 3705015759, 2882616665,
        651767980, 1373503546, 3369554304, 3218104598, 565507253, 1454621731, 3485111705, 3099436303,
        671266974, 1594198024, 3322730930, 2970347812, 795835527, 1483230225, 3244367275, 3060149565,
        1994146192, 31158534, 2563907772, 4023717930, 1907459465, 112637215, 2680153253, 3904427059,
        2013776290, 251722036, 2517215374, 3775830040, 2137656763, 141376813, 2439277719, 3865271297,
        1802195444, 476864866, 2238001368, 4066508878, 1812370925, 453092731, 2181625025, 4111451223,
        1706088902, 314042704, 2344532202, 4240017532, 1658658271, 366619977, 2362670323, 4224994405,
        1303535960, 984961486, 2747007092, 3569037538, 1256170817, 1037604311, 2765210733, 3554079995,
        1131014506, 879679996, 2909243462, 3663771856, 1141124467, 855842277, 2852801631, 3708648649,
        1342533948, 654459306, 3188396048, 3373015174, 1466479909, 544179635, 3110523913, 3462522015,
        1591671054, 702138776, 2966460450, 3352799412, 1504918807, 783551873, 3082640443, 3233442989,
        3988292384, 2596254646, 62317068, 1957810842, 3939845945, 2647816111, 81470997, 1943803523,
        3814918930, 2489596804, 225274430, 2053790376, 3826175755, 2466906013, 167816743, 2097651377,
        4027552580, 2265490386, 503444072, 1762050814, 4150417245, 2154129355, 426522225, 1852507879,
        4275313526, 2312317920, 282753626, 1742555852, 4189708143, 2394877945, 397917763, 1622183637,
        3604390888, 2714866558, 953729732, 1340076626, 3518719985, 2797360999, 1068828381, 1219638859,
        3624741850, 2936675148, 906185462, 1090812512, 3747672003, 2825379669, 829329135, 1181335161,
        3412177804, 3160834842, 628085408, 1382605366, 3423369109, 3138078467, 570562233, 1426400815,
        3317316542, 2998733608, 733239954, 1555261956, 3268935591, 3050360625, 752459403, 1541320221,
        2607071920, 3965973030, 1969922972, 40735498, 2617837225, 3943577151, 1913087877, 83908371,
        2512341634, 3803740692, 2075208622, 213261112, 2463272603, 3855990285, 2094854071, 198958881,
        2262029012, 4057260610, 1759359992, 534414190, 2176718541, 4139329115, 1873836001, 414664567,
        2282248934, 4279200368, 1711684554, 285281116, 2405801727, 4167216745, 1634467795, 376229701,
        2685067896, 3608007406, 1308918612, 956543938, 2808555105, 3495958263, 1231636301, 1047427035,
        2932959818, 3654703836, 1088359270, 936918000, 2847714899, 3736837829, 1202900863, 817233897,
        3183342108, 3401237130, 1404277552, 615818150, 3134207493, 3453421203, 1423857449, 601450431,
        3009837614, 3294710456, 1567103746, 711928724, 3020668471, 3272380065, 1510334235, 755167117,
]


def crc32_bytes(data: List[Byte], off: Int, n: Int) -> Int:
    var tab = materialize[_CRC_TABLE]()
    var crc = 0xFFFFFFFF
    var i = 0
    while i < n:
        var idx = (crc ^ Int(data[off + i])) & 255
        crc = (crc >> 8) ^ tab[idx]
        i += 1
    crc = crc ^ 0xFFFFFFFF
    if crc >= 2147483648:
        return crc - 4294967296
    return crc


def utf8_ok[origin: ImmOrigin](raw: Span[Byte, origin]) -> Bool:
    var i = 0
    var n = len(raw)
    while i < n:
        var c = Int(raw[i])
        if c < 0x80:
            i += 1
        elif c < 0xC2 or c > 0xF4:
            return False
        else:
            var need = 1
            var minv = 0x80
            var maxv = 0xBF
            if c >= 0xE0:
                need = 2
            if c >= 0xF0:
                need = 3
            if i + need >= n:
                return False
            if c == 0xE0:
                minv = 0xA0
            if c == 0xED:
                maxv = 0x9F
            if c == 0xF0:
                minv = 0x90
            if c == 0xF4:
                maxv = 0x8F
            var k = 1
            while k <= need:
                var cc = Int(raw[i + k])
                var lo = 0x80
                var hi = 0xBF
                if k == 1:
                    lo = minv
                    hi = maxv
                if cc < lo or cc > hi:
                    return False
                k += 1
            i += need + 1
    return True


def string_from[origin: ImmOrigin](raw: Span[Byte, origin], at: Int) raises DecodeError -> String:
    if not utf8_ok(raw):
        raise DecodeError(DecodeError.KIND_UTF8, at)
    return String(unsafe_from_utf8=raw)


def bytes_of(text: String) -> List[Byte]:
    var out = List[Byte]()
    var raw = text.as_bytes()
    extend_span(out, raw)
    return out^
