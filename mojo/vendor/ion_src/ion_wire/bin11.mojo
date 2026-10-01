from std.collections import List

from ion_runtime.doc import (
    K_BLOB,
    K_BOOL,
    K_CLOB,
    K_DECIMAL,
    K_FLOAT,
    K_INT,
    K_LIST,
    K_NULL,
    K_SEXP,
    K_STRING,
    K_STRUCT,
    K_SYMBOL,
    K_TIMESTAMP,
    IonDoc,
    IonTime,
    PREC_DAY,
    PREC_FRAC,
    PREC_MIN,
    PREC_MONTH,
    PREC_SEC,
)
from ion_runtime.error import DecodeError
from ion_runtime.intx import BigInt
from ion_wire.ion11 import write_flex_int, write_flex_uint


def encode_values11(doc: IonDoc, mut buf: List[Byte]) raises DecodeError:
    """Write Ion 1.1 values. Symbols are inline text, so no symbol table is required."""
    var i = 0
    while i < len(doc.top):
        _value(doc, doc.top[i], buf)
        i += 1


def _value(doc: IonDoc, id: Int, mut buf: List[Byte]) raises DecodeError:
    var n = doc.nodes[id]
    var i = 0
    while i < n.ann_n:
        var sym = doc.anns[n.ann + i]
        _annotation(doc, sym, buf)
        i += 1
    if n.kind == K_NULL:
        _null(n.a, buf)
        return
    if n.kind == K_BOOL:
        if n.a == 0:
            buf.append(Byte(0x6F))
        else:
            buf.append(Byte(0x6E))
        return
    if n.kind == K_INT:
        _int(doc, n.a, n.b, n.c != 0, buf)
        return
    if n.kind == K_FLOAT:
        _float(doc, n.a, n.b, buf)
        return
    if n.kind == K_DECIMAL:
        _decimal(doc, n.a, n.b, n.c != 0, n.d, buf)
        return
    if n.kind == K_TIMESTAMP:
        _time(doc, doc.times[n.a], buf)
        return
    if n.kind == K_STRING:
        _text_opcode(doc.texts[n.a], 0x90, 0xF8, buf)
        return
    if n.kind == K_SYMBOL:
        var s = doc.syms[n.a]
        if s.text < 0:
            buf.append(Byte(0x50 | (s.sid & 7)))
            write_flex_uint(buf, s.sid >> 3)
        else:
            _text_opcode(doc.texts[s.text], 0xA0, 0xF9, buf)
        return
    if n.kind == K_BLOB or n.kind == K_CLOB:
        var raw = _bytes_of(doc, n.a)
        if n.kind == K_BLOB:
            buf.append(Byte(0xFE))
        else:
            buf.append(Byte(0xFF))
        write_flex_uint(buf, len(raw))
        _append(buf, raw)
        return
    if n.kind == K_LIST or n.kind == K_SEXP or n.kind == K_STRUCT:
        _container(doc, id, buf)
        return
    raise DecodeError(DecodeError.KIND_TYPE, 0)


def _null(type_kind: Int, mut buf: List[Byte]):
    if type_kind == 0:
        buf.append(Byte(0x8E))
        return
    var code = 0
    if type_kind == K_BOOL:
        code = 1
    elif type_kind == K_INT:
        code = 2
    elif type_kind == K_FLOAT:
        code = 3
    elif type_kind == K_DECIMAL:
        code = 4
    elif type_kind == K_TIMESTAMP:
        code = 5
    elif type_kind == K_STRING:
        code = 6
    elif type_kind == K_SYMBOL:
        code = 7
    elif type_kind == K_BLOB:
        code = 8
    elif type_kind == K_CLOB:
        code = 9
    elif type_kind == K_LIST:
        code = 10
    elif type_kind == K_SEXP:
        code = 11
    elif type_kind == K_STRUCT:
        code = 12
    if code == 0:
        buf.append(Byte(0x8E))
        return
    buf.append(Byte(0x8F))
    buf.append(Byte(code))


def _annotation(doc: IonDoc, sym: Int, mut buf: List[Byte]):
    var s = doc.syms[sym]
    if s.text < 0:
        buf.append(Byte(0x58))
        write_flex_uint(buf, s.sid)
        return
    var raw = doc.texts[s.text].as_bytes()
    buf.append(Byte(0x59))
    write_flex_uint(buf, len(raw))
    var i = 0
    while i < len(raw):
        buf.append(raw[i])
        i += 1


def _text_opcode(text: String, short_base: Int, long_op: Int, mut buf: List[Byte]):
    var raw = text.as_bytes()
    var n = len(raw)
    if n <= 15:
        buf.append(Byte(short_base + n))
    else:
        buf.append(Byte(long_op))
        write_flex_uint(buf, n)
    var i = 0
    while i < n:
        buf.append(raw[i])
        i += 1


def _bytes_of(doc: IonDoc, slot: Int) -> List[Byte]:
    var out = List[Byte]()
    var at = doc.blob_at[slot]
    var n = doc.blob_len[slot]
    var i = 0
    while i < n:
        out.append(doc.blob_bytes[at + i])
        i += 1
    return out^


def _append(mut buf: List[Byte], raw: List[Byte]):
    var i = 0
    while i < len(raw):
        buf.append(raw[i])
        i += 1


def _mag_le(doc: IonDoc, at: Int, n: Int) -> List[Byte]:
    var out = List[Byte]()
    var i = 0
    while i < n:
        var limb = UInt32(doc.limbs[at + i])
        var s = 0
        while s < 32:
            out.append(Byte(Int((limb >> UInt32(s)) & UInt32(255))))
            s += 8
        i += 1
    while len(out) > 1 and Int(out[len(out) - 1]) == 0:
        _ = out.pop()
    if len(out) == 1 and Int(out[0]) == 0:
        _ = out.pop()
    return out^


def _twos(mag: List[Byte], width: Int, neg: Bool) -> List[Byte]:
    var out = List[Byte]()
    if not neg:
        var i = 0
        while i < width:
            if i < len(mag):
                out.append(mag[i])
            else:
                out.append(Byte(0))
            i += 1
        return out^
    var carry = 1
    var i = 0
    while i < width:
        var b = 0
        if i < len(mag):
            b = Int(mag[i])
        var inv = (b ^ 255) + carry
        out.append(Byte(inv & 255))
        carry = inv >> 8
        i += 1
    return out^


def _signed_bytes(mag: List[Byte], neg: Bool) -> List[Byte]:
    if len(mag) == 0 and not neg:
        return List[Byte]()
    var width = len(mag)
    if width == 0:
        width = 1
    while True:
        var raw = _twos(mag, width, neg)
        var high = Int(raw[len(raw) - 1]) & 128
        if neg and high != 0:
            return raw^
        if not neg and high == 0:
            return raw^
        width += 1


def _put_int_bytes(raw: List[Byte], mut buf: List[Byte]):
    var n = len(raw)
    if n == 0:
        buf.append(Byte(0x60))
        return
    if n <= 8:
        buf.append(Byte(0x60 + n))
    else:
        buf.append(Byte(0xF5))
        write_flex_uint(buf, n)
    _append(buf, raw)


def _int(doc: IonDoc, at: Int, n: Int, neg: Bool, mut buf: List[Byte]):
    if n == 0 and not neg:
        buf.append(Byte(0x60))
        return
    var mag = _mag_le(doc, at, n)
    var raw = _signed_bytes(mag^, neg)
    _put_int_bytes(raw^, buf)


def _float(doc: IonDoc, width: Int, slot: Int, mut buf: List[Byte]):
    if width == 0:
        buf.append(Byte(0x6A))
        return
    var op = 0x6D
    var n = 8
    if width == 2:
        op = 0x6B
        n = 2
    elif width == 4:
        op = 0x6C
        n = 4
    buf.append(Byte(op))
    var bits = doc.floats[slot]
    var k = 0
    while k < n:
        buf.append(Byte(Int((bits >> UInt64(k * 8)) & UInt64(255))))
        k += 1


def _decimal(doc: IonDoc, at: Int, n: Int, neg: Bool, exp: Int, mut buf: List[Byte]):
    if n == 0 and not neg and exp == 0:
        buf.append(Byte(0x70))
        return
    var body = List[Byte]()
    write_flex_int(body, exp)
    if n > 0 or neg:
        var mag = _mag_le(doc, at, n)
        if len(mag) == 0 and neg:
            body.append(Byte(0))
        else:
            var raw = _signed_bytes(mag^, neg)
            _append(body, raw^)
    var ln = len(body)
    if ln <= 15:
        buf.append(Byte(0x70 + ln))
    else:
        buf.append(Byte(0xF6))
        write_flex_uint(buf, ln)
    _append(buf, body^)


def _container(doc: IonDoc, id: Int, mut buf: List[Byte]) raises DecodeError:
    var n = doc.nodes[id]
    var body = List[Byte]()
    var edge = n.child
    var i = 0
    while i < n.nchild:
        if n.kind == K_STRUCT:
            var field = doc.edges[edge].field
            var text = String("")
            if field >= 0 and doc.syms[field].text >= 0:
                text = doc.texts[doc.syms[field].text]
            var nb = text.as_bytes()
            write_flex_int(body, -1 - len(nb))
            var k = 0
            while k < len(nb):
                body.append(nb[k])
                k += 1
        _value(doc, doc.edges[edge].child, body)
        edge = doc.edges[edge].next
        i += 1
    if n.kind == K_STRUCT and len(body) == 0:
        buf.append(Byte(0xD0))
        return
    var ln = len(body)
    if n.kind == K_STRUCT:
        buf.append(Byte(0xFD))
        write_flex_uint(buf, ln)
    elif ln <= 15:
        var base = 0xB0
        if n.kind == K_SEXP:
            base = 0xC0
        buf.append(Byte(base + ln))
    else:
        if n.kind == K_SEXP:
            buf.append(Byte(0xFB))
        else:
            buf.append(Byte(0xFA))
        write_flex_uint(buf, ln)
    _append(buf, body^)


def _put_bits(mut raw: List[Byte], mut nbits: Int, value: Int, width: Int):
    var k = 0
    while k < width:
        var bit = (value >> k) & 1
        var pos = nbits
        var bi = pos // 8
        while len(raw) <= bi:
            raw.append(Byte(0))
        var b = Int(raw[bi]) | (bit << (pos % 8))
        raw[bi] = Byte(b)
        nbits += 1
        k += 1


def _time(doc: IonDoc, t: IonTime, mut buf: List[Byte]) raises DecodeError:
    var raw = List[Byte]()
    var nbits = 0
    _put_bits(raw, nbits, t.year, 14)
    var length = 2
    if t.prec >= PREC_MONTH:
        var month = t.month
        var day = 0
        if t.prec >= PREC_DAY:
            day = t.day
        _put_bits(raw, nbits, month, 4)
        _put_bits(raw, nbits, day, 5)
        length = 3
    if t.prec >= PREC_MIN:
        _put_bits(raw, nbits, t.hour, 5)
        _put_bits(raw, nbits, t.minute, 6)
        var off = 4095
        if not t.unknown:
            off = t.off + 1440
            if off < 0 or off > 4094:
                raise DecodeError(DecodeError.KIND_RANGE, 0)
        _put_bits(raw, nbits, off, 12)
        length = 6
    if t.prec >= PREC_SEC:
        _put_bits(raw, nbits, t.second, 6)
        length = 7
    var frac = List[Byte]()
    if t.prec == PREC_FRAC:
        var scale = 0 - t.frac_exp
        if scale < 1:
            raise DecodeError(DecodeError.KIND_SYNTAX, 0)
        write_flex_uint(frac, scale)
        var mag = _mag_le(doc, t.frac_at, t.frac_len)
        if len(mag) == 0:
            frac.append(Byte(0))
        else:
            _append(frac, mag^)
        length = 7 + len(frac)
    buf.append(Byte(0xF7))
    write_flex_uint(buf, length)
    var i = 0
    while i < length and i < len(raw):
        buf.append(raw[i])
        i += 1
    while i < length and t.prec < PREC_FRAC:
        buf.append(Byte(0))
        i += 1
    if t.prec == PREC_FRAC:
        _append(buf, frac^)
