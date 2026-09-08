from std.collections import List, Span

from cbor_runtime.error import DecodeError
from cbor_runtime.value import (
    CK_ARRAY,
    CK_BYTES,
    CK_FALSE,
    CK_INT,
    CK_MAP,
    CK_NULL,
    CK_SIMPLE,
    CK_TAG,
    CK_TEXT,
    CK_TRUE,
    CK_UNDEFINED,
    CborNode,
    CborValue,
    FLAG_INDEF,
)
from cbor_wire.utf8 import string_from_utf8


struct _Diag[origin: ImmOrigin](Movable):
    var data: Span[Byte, Self.origin]
    var pos: Int

    def __init__(out self, data: Span[Byte, Self.origin]):
        self.data = data
        self.pos = 0

    def remaining(self) -> Int:
        return len(self.data) - self.pos

    def peek(self) -> Int:
        if self.pos >= len(self.data):
            return -1
        return Int(self.data[self.pos])

    def skip_ws(mut self):
        while self.pos < len(self.data):
            var c = Int(self.data[self.pos])
            if c == 32 or c == 9 or c == 10 or c == 13:
                self.pos += 1
                continue
            if c == 35:
                # # comment to EOL
                while self.pos < len(self.data) and Int(self.data[self.pos]) != 10:
                    self.pos += 1
                continue
            break


def _is_digit(c: Int) -> Bool:
    return c >= 48 and c <= 57


def _is_alpha(c: Int) -> Bool:
    return (c >= 65 and c <= 90) or (c >= 97 and c <= 122)


def _parse_int(mut p: _Diag) raises DecodeError -> Int64:
    p.skip_ws()
    var at = p.pos
    var neg = False
    if p.peek() == 45:
        neg = True
        p.pos += 1
    if p.peek() == 48 and p.pos + 1 < len(p.data) and Int(p.data[p.pos + 1]) == 120:
        # 0x hex
        p.pos += 2
        var hv: Int64 = 0
        var anyh = False
        while True:
            var c = p.peek()
            var d = -1
            if c >= 48 and c <= 57:
                d = c - 48
            elif c >= 97 and c <= 102:
                d = c - 87
            elif c >= 65 and c <= 70:
                d = c - 55
            if d < 0:
                break
            hv = hv * Int64(16) + Int64(d)
            p.pos += 1
            anyh = True
        if not anyh:
            raise DecodeError(DecodeError.KIND_DIAG, at)
        if neg:
            return -hv
        return hv
    if not _is_digit(p.peek()):
        raise DecodeError(DecodeError.KIND_DIAG, at)
    var v: Int64 = 0
    while _is_digit(p.peek()):
        v = v * Int64(10) + Int64(p.peek() - 48)
        p.pos += 1
    if neg:
        return -v
    return v


def _parse_text(mut p: _Diag, mut v: CborValue) raises DecodeError -> Int:
    p.skip_ws()
    if p.peek() != 34:
        raise DecodeError(DecodeError.KIND_DIAG, p.pos)
    p.pos += 1
    var raw = List[Byte]()
    while p.remaining() > 0:
        var c = Int(p.data[p.pos])
        p.pos += 1
        if c == 34:
            var s = string_from_utf8(raw, p.pos)
            var tidx = len(v.texts)
            v.texts.append(s^)
            return v.add(CborNode(CK_TEXT, a=Int64(tidx)))
        if c == 92:
            if p.remaining() == 0:
                raise DecodeError(DecodeError.KIND_DIAG, p.pos)
            var e = Int(p.data[p.pos])
            p.pos += 1
            if e == 34 or e == 92:
                raw.append(Byte(e))
            elif e == 110:
                raw.append(Byte(10))
            elif e == 116:
                raw.append(Byte(9))
            else:
                raise DecodeError(DecodeError.KIND_DIAG, p.pos)
        else:
            raw.append(Byte(c))
    raise DecodeError(DecodeError.KIND_DIAG, p.pos)


def _hex_val(c: Int) -> Int:
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 97 and c <= 102:
        return c - 87
    if c >= 65 and c <= 70:
        return c - 55
    return -1


def _parse_bstr(mut p: _Diag, mut v: CborValue) raises DecodeError -> Int:
    p.skip_ws()
    # h'...'
    if p.peek() != 104:
        raise DecodeError(DecodeError.KIND_DIAG, p.pos)
    p.pos += 1
    if p.peek() != 39:
        raise DecodeError(DecodeError.KIND_DIAG, p.pos)
    p.pos += 1
    var digits = List[Int]()
    while p.remaining() > 0:
        var c = p.peek()
        if c == 39:
            p.pos += 1
            break
        if c == 32 or c == 10 or c == 9:
            p.pos += 1
            continue
        var d = _hex_val(c)
        if d < 0:
            raise DecodeError(DecodeError.KIND_DIAG, p.pos)
        digits.append(d)
        p.pos += 1
    if len(digits) % 2 != 0:
        raise DecodeError(DecodeError.KIND_DIAG, p.pos)
    var start = len(v.bytes)
    var i = 0
    while i < len(digits):
        v.bytes.append(Byte((digits[i] << 4) | digits[i + 1]))
        i += 2
    return v.add(CborNode(CK_BYTES, a=Int64(start), b=UInt64((len(digits) // 2))))


def _ident(mut p: _Diag) raises DecodeError -> String:
    var start = p.pos
    while p.remaining() > 0:
        var c = p.peek()
        if _is_alpha(c) or _is_digit(c) or c == 95:
            p.pos += 1
        else:
            break
    try:
        return String(from_utf8=p.data[start : p.pos])
    except _:
        raise DecodeError(DecodeError.KIND_DIAG, start)


def parse_item(mut p: _Diag, mut v: CborValue) raises DecodeError -> Int:
    p.skip_ws()
    var c = p.peek()
    if c == 34:
        return _parse_text(p, v)
    if c == 104:
        return _parse_bstr(p, v)
    if c == 91:
        p.pos += 1
        p.skip_ws()
        var flags = 0
        if p.peek() == 95:
            flags = FLAG_INDEF
            p.pos += 1
        var kstart = len(v.kids)
        var count = 0
        p.skip_ws()
        while p.peek() != 93 and p.peek() != -1:
            var ch = parse_item(p, v)
            v.kids.append(ch)
            count += 1
            p.skip_ws()
            if p.peek() == 44:
                p.pos += 1
                p.skip_ws()
        if p.peek() != 93:
            raise DecodeError(DecodeError.KIND_DIAG, p.pos)
        p.pos += 1
        return v.add(CborNode(CK_ARRAY, a=Int64(kstart), b=UInt64(count), flags=flags))
    if c == 123:
        p.pos += 1
        p.skip_ws()
        var mflags = 0
        if p.peek() == 95:
            mflags = FLAG_INDEF
            p.pos += 1
        var mstart = len(v.kids)
        var pairs = 0
        p.skip_ws()
        while p.peek() != 125 and p.peek() != -1:
            var key = parse_item(p, v)
            p.skip_ws()
            if p.peek() != 58:
                raise DecodeError(DecodeError.KIND_DIAG, p.pos)
            p.pos += 1
            var val = parse_item(p, v)
            v.kids.append(key)
            v.kids.append(val)
            pairs += 1
            p.skip_ws()
            if p.peek() == 44:
                p.pos += 1
                p.skip_ws()
        if p.peek() != 125:
            raise DecodeError(DecodeError.KIND_DIAG, p.pos)
        p.pos += 1
        return v.add(CborNode(CK_MAP, a=Int64(mstart), b=UInt64(pairs), flags=mflags))
    if _is_alpha(c):
        var id = _ident(p)
        if id == "true":
            return v.add(CborNode(CK_TRUE))
        if id == "false":
            return v.add(CborNode(CK_FALSE))
        if id == "null":
            return v.add(CborNode(CK_NULL))
        if id == "undefined":
            return v.add(CborNode(CK_UNDEFINED))
        if id == "simple":
            p.skip_ws()
            if p.peek() != 40:
                raise DecodeError(DecodeError.KIND_DIAG, p.pos)
            p.pos += 1
            var n = _parse_int(p)
            p.skip_ws()
            if p.peek() != 41:
                raise DecodeError(DecodeError.KIND_DIAG, p.pos)
            p.pos += 1
            return v.add(CborNode(CK_SIMPLE, a=n))
        if id == "Infinity" or id == "NaN":
            # store as float64 bits
            if id == "NaN":
                return v.add(CborNode(15, b=UInt64(0x7FF8000000000000)))
            return v.add(CborNode(15, b=UInt64(0x7FF0000000000000)))
        raise DecodeError(DecodeError.KIND_DIAG, p.pos)
    if c == 45 or _is_digit(c):
        var start = p.pos
        var iv = _parse_int(p)
        p.skip_ws()
        if p.peek() == 40:
            # tag
            p.pos += 1
            var inner = parse_item(p, v)
            p.skip_ws()
            if p.peek() != 41:
                raise DecodeError(DecodeError.KIND_DIAG, p.pos)
            p.pos += 1
            if iv < Int64(0):
                raise DecodeError(DecodeError.KIND_DIAG, start)
            return v.add(CborNode(CK_TAG, b=UInt64(iv), c=inner))
        return v.add(CborNode(CK_INT, a=iv))
    raise DecodeError(DecodeError.KIND_DIAG, p.pos)


def decode_diag(text: String) raises DecodeError -> CborValue:
    var b = text.as_bytes()
    var p = _Diag(b)
    var v = CborValue()
    v.root = parse_item(p, v)
    p.skip_ws()
    if p.remaining() > 0:
        raise DecodeError(DecodeError.KIND_DIAG, p.pos)
    return v^
