from std.collections import List, Span

from flight.huffdata import huff_bits, huff_codes
from arrow_runtime.error import DecodeError


struct Hpack:
    var dyn_name: List[String]
    var dyn_value: List[String]
    var max_size: Int
    var codes: List[Int]
    var nbits: List[Int]

    def __init__(out self):
        self.dyn_name = List[String]()
        self.dyn_value = List[String]()
        self.max_size = 4096
        self.codes = huff_codes()
        self.nbits = huff_bits()

    def table_size(self) -> Int:
        var n = 0
        var i = 0
        while i < len(self.dyn_name):
            n += self.dyn_name[i].byte_length() + self.dyn_value[i].byte_length() + 32
            i += 1
        return n

    def lookup(self, idx: Int) raises DecodeError -> Tuple[String, String]:
        if idx <= 0:
            raise DecodeError(DecodeError.KIND_FLIGHT, idx)
        if idx <= 61:
            return _static(idx)
        var at = idx - 62
        if at < 0 or at >= len(self.dyn_name):
            raise DecodeError(DecodeError.KIND_FLIGHT, idx)
        return (self.dyn_name[at], self.dyn_value[at])

    def insert(mut self, name: String, value: String):
        var nn = List[String]()
        var vv = List[String]()
        nn.append(name)
        vv.append(value)
        var i = 0
        while i < len(self.dyn_name):
            nn.append(self.dyn_name[i])
            vv.append(self.dyn_value[i])
            i += 1
        self.dyn_name = nn^
        self.dyn_value = vv^
        self.evict()

    def evict(mut self):
        while len(self.dyn_name) > 0 and self.table_size() > self.max_size:
            var nn = List[String]()
            var vv = List[String]()
            var i = 0
            var last = len(self.dyn_name) - 1
            while i < last:
                nn.append(self.dyn_name[i])
                vv.append(self.dyn_value[i])
                i += 1
            self.dyn_name = nn^
            self.dyn_value = vv^

    def encode_indexed(self, mut out: List[Byte], idx: Int):
        _write_int(out, 0x80, 7, idx)

    def encode_literal(mut self, mut out: List[Byte], name: String, value: String, indexing: Int):
        var prefix = 0x00
        var bits = 4
        if indexing != 0:
            prefix = 0x40
            bits = 6
        _write_int(out, prefix, bits, 0)
        self._write_string(out, name)
        self._write_string(out, value)
        if indexing != 0:
            self.insert(name, value)

    def encode_named(mut self, mut out: List[Byte], name_idx: Int, value: String):
        _write_int(out, 0x00, 4, name_idx)
        self._write_string(out, value)

    def decode(mut self, raw: List[Byte], mut names: List[String], mut values: List[String]) raises DecodeError:
        var i = 0
        var n = len(raw)
        while i < n:
            var first = Int(raw[i])
            i += 1
            if (first & 0x80) != 0:
                var idx = _read_int(raw, i, n, first, 7)
                var name = String("")
                var value = String("")
                name, value = self.lookup(idx)
                names.append(name)
                values.append(value)
            elif (first & 0xC0) == 0x40:
                self._literal(raw, i, n, first, 6, 1, names, values)
            elif (first & 0xE0) == 0x20:
                var sz = _read_int(raw, i, n, first, 5)
                if sz < 0 or sz > 65536:
                    raise DecodeError(DecodeError.KIND_FLIGHT, sz)
                self.max_size = sz
                self.evict()
            elif (first & 0xF0) == 0x10:
                self._literal(raw, i, n, first, 4, 0, names, values)
            elif (first & 0xF0) == 0x00:
                self._literal(raw, i, n, first, 4, 0, names, values)
            else:
                raise DecodeError(DecodeError.KIND_FLIGHT, i)

    def _literal(
        mut self,
        raw: List[Byte],
        mut i: Int,
        n: Int,
        first: Int,
        prefix: Int,
        indexing: Int,
        mut names: List[String],
        mut values: List[String],
    ) raises DecodeError:
        var name_idx = _read_int(raw, i, n, first, prefix)
        var name = String("")
        if name_idx == 0:
            name = self._read_string(raw, i, n)
        else:
            var looked = String("")
            var ignored = String("")
            looked, ignored = self.lookup(name_idx)
            name = looked
        var value = self._read_string(raw, i, n)
        if indexing != 0:
            self.insert(name, value)
        names.append(name)
        values.append(value)

    def _write_string(self, mut out: List[Byte], text: String):
        var enc = self._huff_encode(text)
        _write_int(out, 0x80, 7, len(enc))
        var i = 0
        while i < len(enc):
            out.append(enc[i])
            i += 1

    def _read_string(self, raw: List[Byte], mut i: Int, n: Int) raises DecodeError -> String:
        if i >= n:
            raise DecodeError(DecodeError.KIND_FLIGHT, i)
        var first = Int(raw[i])
        i += 1
        var huff = (first >> 7) & 1
        var ln = _read_int(raw, i, n, first, 7)
        if ln < 0 or i + ln > n:
            raise DecodeError(DecodeError.KIND_FLIGHT, i)
        if huff != 0:
            var text = self._huff_decode(raw, i, ln)
            i += ln
            return text^
        var tmp = List[Byte]()
        var k = 0
        while k < ln:
            tmp.append(raw[i + k])
            k += 1
        i += ln
        return String(unsafe_from_utf8=Span(tmp))

    def _huff_encode(self, text: String) -> List[Byte]:
        var raw = text.as_bytes()
        var acc = 0
        var nb = 0
        var out = List[Byte]()
        var i = 0
        while i < len(raw):
            var sym = Int(raw[i])
            var code = self.codes[sym]
            var bl = self.nbits[sym]
            acc = (acc << bl) | code
            nb += bl
            while nb >= 8:
                nb -= 8
                out.append(Byte((acc >> nb) & 255))
                if nb == 0:
                    acc = 0
                else:
                    acc = acc & ((1 << nb) - 1)
            i += 1
        if nb > 0:
            var pad = 8 - nb
            acc = (acc << pad) | ((1 << pad) - 1)
            out.append(Byte(acc & 255))
        return out^

    def _huff_decode(self, raw: List[Byte], start: Int, size: Int) raises DecodeError -> String:
        if size == 0:
            return String("")
        var acc = 0
        var nb = 0
        var out = List[Byte]()
        var bi = 0
        var total = size * 8
        while bi < total:
            var byte_i = start + (bi // 8)
            var shift = 7 - (bi & 7)
            var bit = (Int(raw[byte_i]) >> shift) & 1
            acc = (acc << 1) | bit
            nb += 1
            bi += 1
            var sym = _match(self.codes, self.nbits, acc, nb)
            if sym >= 0:
                if sym == 256:
                    raise DecodeError(DecodeError.KIND_FLIGHT, start)
                out.append(Byte(sym))
                acc = 0
                nb = 0
            elif nb > 30:
                raise DecodeError(DecodeError.KIND_FLIGHT, start)
        if nb > 7:
            raise DecodeError(DecodeError.KIND_FLIGHT, start)
        if nb > 0 and acc != ((1 << nb) - 1):
            raise DecodeError(DecodeError.KIND_FLIGHT, start)
        return String(unsafe_from_utf8=Span(out))


def huffman_bytes(text: String) -> List[Byte]:
    var hp = Hpack()
    return hp._huff_encode(text)


def _match(codes: List[Int], nbits: List[Int], acc: Int, nb: Int) -> Int:
    var i = 0
    while i < 256:
        if nbits[i] == nb and codes[i] == acc:
            return i
        i += 1
    return -1


def _write_int(mut out: List[Byte], prefix: Int, bits: Int, value: Int):
    var maxv = (1 << bits) - 1
    if value < maxv:
        out.append(Byte(prefix | value))
        return
    out.append(Byte(prefix | maxv))
    var rest = value - maxv
    while rest >= 128:
        out.append(Byte((rest & 127) | 128))
        rest = rest >> 7
    out.append(Byte(rest))


def _read_int(raw: List[Byte], mut i: Int, n: Int, first: Int, bits: Int) raises DecodeError -> Int:
    var maxv = (1 << bits) - 1
    var v = first & maxv
    if v < maxv:
        return v
    var m = 0
    var guard = 0
    while i < n and guard < 8:
        var b = Int(raw[i])
        i += 1
        v += (b & 127) << m
        if (b & 128) == 0:
            return v
        m += 7
        guard += 1
    raise DecodeError(DecodeError.KIND_FLIGHT, i)


def _static(idx: Int) raises DecodeError -> Tuple[String, String]:
    if idx == 1:
        return (String(":authority"), String(""))
    if idx == 2:
        return (String(":method"), String("GET"))
    if idx == 3:
        return (String(":method"), String("POST"))
    if idx == 4:
        return (String(":path"), String("/"))
    if idx == 5:
        return (String(":path"), String("/index.html"))
    if idx == 6:
        return (String(":scheme"), String("http"))
    if idx == 7:
        return (String(":scheme"), String("https"))
    if idx == 8:
        return (String(":status"), String("200"))
    if idx == 9:
        return (String(":status"), String("204"))
    if idx == 10:
        return (String(":status"), String("206"))
    if idx == 11:
        return (String(":status"), String("304"))
    if idx == 12:
        return (String(":status"), String("400"))
    if idx == 13:
        return (String(":status"), String("404"))
    if idx == 14:
        return (String(":status"), String("500"))
    if idx == 15:
        return (String("accept-charset"), String(""))
    if idx == 16:
        return (String("accept-encoding"), String("gzip, deflate"))
    if idx == 17:
        return (String("accept-language"), String(""))
    if idx == 18:
        return (String("accept-ranges"), String(""))
    if idx == 19:
        return (String("accept"), String(""))
    if idx == 20:
        return (String("access-control-allow-origin"), String(""))
    if idx == 21:
        return (String("age"), String(""))
    if idx == 22:
        return (String("allow"), String(""))
    if idx == 23:
        return (String("authorization"), String(""))
    if idx == 24:
        return (String("cache-control"), String(""))
    if idx == 25:
        return (String("content-disposition"), String(""))
    if idx == 26:
        return (String("content-encoding"), String(""))
    if idx == 27:
        return (String("content-language"), String(""))
    if idx == 28:
        return (String("content-length"), String(""))
    if idx == 29:
        return (String("content-location"), String(""))
    if idx == 30:
        return (String("content-range"), String(""))
    if idx == 31:
        return (String("content-type"), String(""))
    if idx == 32:
        return (String("cookie"), String(""))
    if idx == 33:
        return (String("date"), String(""))
    if idx == 34:
        return (String("etag"), String(""))
    if idx == 35:
        return (String("expect"), String(""))
    if idx == 36:
        return (String("expires"), String(""))
    if idx == 37:
        return (String("from"), String(""))
    if idx == 38:
        return (String("host"), String(""))
    if idx == 39:
        return (String("if-match"), String(""))
    if idx == 40:
        return (String("if-modified-since"), String(""))
    if idx == 41:
        return (String("if-none-match"), String(""))
    if idx == 42:
        return (String("if-range"), String(""))
    if idx == 43:
        return (String("if-unmodified-since"), String(""))
    if idx == 44:
        return (String("last-modified"), String(""))
    if idx == 45:
        return (String("link"), String(""))
    if idx == 46:
        return (String("location"), String(""))
    if idx == 47:
        return (String("max-forwards"), String(""))
    if idx == 48:
        return (String("proxy-authenticate"), String(""))
    if idx == 49:
        return (String("proxy-authorization"), String(""))
    if idx == 50:
        return (String("range"), String(""))
    if idx == 51:
        return (String("referer"), String(""))
    if idx == 52:
        return (String("refresh"), String(""))
    if idx == 53:
        return (String("retry-after"), String(""))
    if idx == 54:
        return (String("server"), String(""))
    if idx == 55:
        return (String("set-cookie"), String(""))
    if idx == 56:
        return (String("strict-transport-security"), String(""))
    if idx == 57:
        return (String("transfer-encoding"), String(""))
    if idx == 58:
        return (String("user-agent"), String(""))
    if idx == 59:
        return (String("vary"), String(""))
    if idx == 60:
        return (String("via"), String(""))
    if idx == 61:
        return (String("www-authenticate"), String(""))
    raise DecodeError(DecodeError.KIND_FLIGHT, idx)
