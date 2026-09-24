from std.collections import List, Span

from fb_schema.finish import finish_fbs
from fb_schema.model import (
    BT_DOUBLE,
    BT_FLOAT,
    BT_NONE,
    BT_OBJ,
    BT_STRING,
    BT_UNION,
    BT_UTYPE,
    BT_VECTOR,
    EnumDef,
    EnumVal,
    FieldDef,
    ObjectDef,
    Schema,
    TypeRef,
    builtin_type,
    is_integer,
    is_scalar,
    scalar_size,
)


struct Tok(Copyable, ImplicitlyCopyable, Movable):
    var kind: Int
    var text: String

    def __init__(out self, kind: Int, text: String):
        self.kind = kind
        self.text = text


comptime TK_EOF: Int = 0
comptime TK_IDENT: Int = 1
comptime TK_NUM: Int = 2
comptime TK_STR: Int = 3
comptime TK_SYM: Int = 4


def read_text(path: String) raises -> String:
    var handle = open(path, "r")
    var data = handle.read_bytes()
    handle.close()
    return String(from_utf8=Span(data))


def read_file_bytes(path: String) raises -> List[Byte]:
    var handle = open(path, "r")
    var data = handle.read_bytes()
    handle.close()
    return data^


def parse_fbs_file(path: String) raises -> Schema:
    var schema = Schema()
    var seen = List[String]()
    _parse_file(path, schema, seen)
    finish_fbs(schema)
    return schema^


def _parse_file(path: String, mut schema: Schema, mut seen: List[String]) raises:
    for i in range(len(seen)):
        if seen[i] == path:
            return
    seen.append(path)
    var text = read_text(path)
    var toks = _tokenize(text)
    var p = _Cursor(toks)
    var ns = String()
    while not p.eof():
        if p.at_ident("include"):
            p.bump()
            var rel = p.take_str()
            p.expect_sym(";")
            _parse_file(_join(_dir_of(path), rel), schema, seen)
        elif p.at_ident("namespace"):
            p.bump()
            ns = p.take_dotted()
            p.expect_sym(";")
        elif p.at_ident("attribute"):
            p.bump()
            _ = p.take_str()
            p.expect_sym(";")
        elif p.at_ident("root_type"):
            p.bump()
            schema.root_name = _qualify(ns, p.take_dotted())
            p.expect_sym(";")
        elif p.at_ident("file_identifier"):
            p.bump()
            schema.file_ident = p.take_str()
            p.expect_sym(";")
        elif p.at_ident("file_extension"):
            p.bump()
            schema.file_ext = p.take_str()
            p.expect_sym(";")
        elif p.at_ident("table"):
            schema.objects.append(_parse_object(p, ns, False))
        elif p.at_ident("struct"):
            schema.objects.append(_parse_object(p, ns, True))
        elif p.at_ident("enum"):
            schema.enums.append(_parse_enum(p, ns, False))
        elif p.at_ident("union"):
            schema.enums.append(_parse_enum(p, ns, True))
        elif p.at_ident("rpc_service") or p.at_ident("service"):
            _skip_block(p)
        else:
            raise Error("unexpected token " + p.peek_text())


def _parse_object(mut p: _Cursor, ns: String, is_struct: Bool) raises -> ObjectDef:
    p.bump()
    var obj = ObjectDef()
    obj.name = _qualify(ns, p.take_ident())
    obj.is_struct = is_struct
    if p.at_sym("("):
        _skip_meta(p)
    p.expect_sym("{")
    while not p.at_sym("}") and not p.eof():
        obj.fields.append(_parse_field(p, ns))
    p.expect_sym("}")
    return obj^


def _parse_field(mut p: _Cursor, ns: String) raises -> FieldDef:
    var field = FieldDef()
    field.name = p.take_ident()
    p.expect_sym(":")
    field.ty = _parse_type(p, ns)
    if p.at_sym("="):
        p.bump()
        if p.at_ident("null"):
            p.bump()
            field.optional = True
        elif p.at_ident("true"):
            p.bump()
            field.default_int = 1
        elif p.at_ident("false"):
            p.bump()
            field.default_int = 0
        elif p.tok_kind() == TK_NUM:
            var raw = p.take_num()
            if _is_real(raw):
                field.default_real = _parse_real(raw)
            else:
                field.default_int = _parse_int(raw)
        elif p.tok_kind() == TK_IDENT:
            field.default_name = p.take_ident()
        else:
            raise Error("bad default")
    if p.at_sym("("):
        _apply_meta(p, field)
    p.expect_sym(";")
    return field^


def _parse_type(mut p: _Cursor, ns: String) raises -> TypeRef:
    if p.at_sym("["):
        p.bump()
        var inner = _parse_type(p, ns)
        p.expect_sym("]")
        var ty = TypeRef()
        ty.base = BT_VECTOR
        ty.element = inner.base
        ty.index = inner.index
        ty.type_name = inner.type_name
        return ty
    var name = p.take_dotted()
    var builtin = builtin_type(name)
    var ty = TypeRef()
    if builtin >= 0:
        ty.base = builtin
        return ty
    ty.type_name = _qualify(ns, name)
    return ty


def _parse_enum(mut p: _Cursor, ns: String, is_union: Bool) raises -> EnumDef:
    p.bump()
    var en = EnumDef()
    en.name = _qualify(ns, p.take_ident())
    en.is_union = is_union
    if not is_union:
        p.expect_sym(":")
        var under = p.take_dotted()
        var b = builtin_type(under)
        if b < 0:
            raise Error("bad enum type")
        en.underlying = b
    else:
        en.underlying = BT_UTYPE
        var none = EnumVal()
        none.name = "NONE"
        none.value = 0
        en.values.append(none^)
    if p.at_sym("("):
        _skip_meta(p)
    p.expect_sym("{")
    var auto = Int64(0)
    if is_union:
        auto = 1
    while not p.at_sym("}") and not p.eof():
        if p.at_sym(","):
            p.bump()
            continue
        var val = EnumVal()
        val.name = p.take_ident()
        if is_union:
            val.union_name = _qualify(ns, val.name)
        if p.at_sym("="):
            p.bump()
            val.value = _parse_int(p.take_num())
            auto = val.value + 1
        else:
            val.value = auto
            auto += 1
        en.values.append(val^)
        if p.at_sym(","):
            p.bump()
    p.expect_sym("}")
    return en^


def _apply_meta(mut p: _Cursor, mut field: FieldDef) raises:
    p.expect_sym("(")
    while not p.at_sym(")") and not p.eof():
        var name = p.take_ident()
        if name == "required":
            field.required = True
        elif name == "deprecated":
            field.deprecated = True
        elif name == "id":
            p.expect_sym(":")
            field.id = Int(_parse_int(p.take_num()))
            field.has_id = True
        else:
            if p.at_sym(":"):
                p.bump()
                if p.tok_kind() == TK_STR:
                    _ = p.take_str()
                elif p.tok_kind() == TK_NUM:
                    _ = p.take_num()
                elif p.tok_kind() == TK_IDENT:
                    _ = p.take_ident()
        if p.at_sym(","):
            p.bump()
    p.expect_sym(")")


def _skip_meta(mut p: _Cursor) raises:
    var dummy = FieldDef()
    _apply_meta(p, dummy)


def _skip_block(mut p: _Cursor) raises:
    var depth = 0
    while not p.eof():
        if p.at_sym("{"):
            depth += 1
        elif p.at_sym("}"):
            depth -= 1
            p.bump()
            if depth == 0:
                return
            continue
        elif p.at_sym(";") and depth == 0:
            p.bump()
            return
        p.bump()


struct _Cursor:
    var toks: List[Tok]
    var i: Int

    def __init__(out self, toks: List[Tok]):
        self.toks = List[Tok]()
        self.i = 0
        for i in range(len(toks)):
            self.toks.append(toks[i])

    def eof(self) -> Bool:
        return self.i >= len(self.toks) or self.toks[self.i].kind == TK_EOF

    def tok_kind(self) -> Int:
        if self.eof():
            return TK_EOF
        return self.toks[self.i].kind

    def peek_text(self) -> String:
        if self.eof():
            return String()
        return self.toks[self.i].text

    def at_ident(self, text: String) -> Bool:
        return self.tok_kind() == TK_IDENT and self.peek_text() == text

    def at_sym(self, text: String) -> Bool:
        return self.tok_kind() == TK_SYM and self.peek_text() == text

    def bump(mut self):
        if self.i < len(self.toks):
            self.i += 1

    def expect_sym(mut self, text: String) raises:
        if not self.at_sym(text):
            raise Error("expected '" + text + "'")
        self.bump()

    def take_ident(mut self) raises -> String:
        if self.tok_kind() != TK_IDENT:
            raise Error("expected name")
        var text = self.peek_text()
        self.bump()
        return text

    def take_str(mut self) raises -> String:
        if self.tok_kind() != TK_STR:
            raise Error("expected string")
        var text = self.peek_text()
        self.bump()
        return text

    def take_num(mut self) raises -> String:
        if self.tok_kind() != TK_NUM:
            raise Error("expected number")
        var text = self.peek_text()
        self.bump()
        return text

    def take_dotted(mut self) raises -> String:
        var name = self.take_ident()
        while self.at_sym("."):
            self.bump()
            name += "."
            name += self.take_ident()
        return name


def _tokenize(text: String) raises -> List[Tok]:
    var out = List[Tok]()
    var raw = text.as_bytes()
    var i = 0
    var n = len(raw)
    while i < n:
        var c = Int(raw[i])
        if c == 32 or c == 9 or c == 10 or c == 13:
            i += 1
            continue
        if c == ord("/") and i + 1 < n and Int(raw[i + 1]) == ord("/"):
            i += 2
            while i < n and Int(raw[i]) != 10:
                i += 1
            continue
        if c == ord("/") and i + 1 < n and Int(raw[i + 1]) == ord("*"):
            i += 2
            while i + 1 < n and not (Int(raw[i]) == ord("*") and Int(raw[i + 1]) == ord("/")):
                i += 1
            i += 2
            continue
        if c == ord('"'):
            i += 1
            var buf = List[Byte]()
            while i < n and Int(raw[i]) != ord('"'):
                buf.append(raw[i])
                i += 1
            if i < n:
                i += 1
            out.append(Tok(TK_STR, String(from_utf8=Span(buf))))
            continue
        if _ident_start(c):
            var start = i
            i += 1
            while i < n and _ident_cont(Int(raw[i])):
                i += 1
            out.append(Tok(TK_IDENT, _slice(raw, start, i)))
            continue
        if c == ord("-") or (c >= ord("0") and c <= ord("9")):
            var start = i
            if c == ord("-"):
                i += 1
            if i + 1 < n and Int(raw[i]) == ord("0") and (Int(raw[i + 1]) == ord("x") or Int(raw[i + 1]) == ord("X")):
                i += 2
                while i < n and _hex(Int(raw[i])):
                    i += 1
            else:
                while i < n and Int(raw[i]) >= ord("0") and Int(raw[i]) <= ord("9"):
                    i += 1
                if i < n and Int(raw[i]) == ord("."):
                    i += 1
                    while i < n and Int(raw[i]) >= ord("0") and Int(raw[i]) <= ord("9"):
                        i += 1
            out.append(Tok(TK_NUM, _slice(raw, start, i)))
            continue
        out.append(Tok(TK_SYM, _slice(raw, i, i + 1)))
        i += 1
    out.append(Tok(TK_EOF, String()))
    return out^


def _ident_start(c: Int) -> Bool:
    if c >= ord("a") and c <= ord("z"):
        return True
    if c >= ord("A") and c <= ord("Z"):
        return True
    return c == ord("_")


def _ident_cont(c: Int) -> Bool:
    if _ident_start(c):
        return True
    return c >= ord("0") and c <= ord("9")


def _hex(c: Int) -> Bool:
    if c >= ord("0") and c <= ord("9"):
        return True
    if c >= ord("a") and c <= ord("f"):
        return True
    return c >= ord("A") and c <= ord("F")


def _slice[origin: ImmOrigin](raw: Span[Byte, origin], start: Int, end: Int) raises -> String:
    var buf = List[Byte]()
    for i in range(start, end):
        buf.append(raw[i])
    return String(from_utf8=Span(buf))


def _qualify(ns: String, name: String) -> String:
    if name.find(".") >= 0:
        return name
    if ns.byte_length() == 0:
        return name
    return ns + "." + name


def _dir_of(path: String) raises -> String:
    var last = -1
    var raw = path.as_bytes()
    for i in range(len(raw)):
        if raw[i] == Byte(ord("/")):
            last = i
    if last <= 0:
        return String(".")
    return _slice(raw, 0, last)


def _join(dir: String, rel: String) -> String:
    if rel.byte_length() > 0 and rel.as_bytes()[0] == Byte(ord("/")):
        return rel
    return dir + "/" + rel


def _is_real(raw: String) -> Bool:
    return raw.find(".") >= 0


def _parse_int(raw: String) -> Int64:
    var bytes = raw.as_bytes()
    var i = 0
    var neg = False
    if len(bytes) > 0 and bytes[0] == Byte(ord("-")):
        neg = True
        i = 1
    var hex = False
    if i + 1 < len(bytes) and bytes[i] == Byte(ord("0")) and (bytes[i + 1] == Byte(ord("x")) or bytes[i + 1] == Byte(ord("X"))):
        hex = True
        i += 2
    var value: Int64 = 0
    while i < len(bytes):
        var c = Int(bytes[i])
        var digit: Int64
        if c >= ord("0") and c <= ord("9"):
            digit = Int64(c - ord("0"))
        elif c >= ord("a") and c <= ord("f"):
            digit = Int64(c - ord("a") + 10)
        elif c >= ord("A") and c <= ord("F"):
            digit = Int64(c - ord("A") + 10)
        else:
            break
        if hex:
            value = value * 16 + digit
        else:
            value = value * 10 + digit
        i += 1
    if neg:
        return -value
    return value


def _parse_real(raw: String) -> Float64:
    # Schema defaults are short decimals. Accumulate the integer and fraction.
    var bytes = raw.as_bytes()
    var neg = False
    var i = 0
    if len(bytes) > 0 and bytes[0] == Byte(ord("-")):
        neg = True
        i = 1
    var whole: Int64 = 0
    while i < len(bytes) and Int(bytes[i]) >= ord("0") and Int(bytes[i]) <= ord("9"):
        whole = whole * 10 + Int64(Int(bytes[i]) - ord("0"))
        i += 1
    var frac = Float64(0)
    var scale = Float64(1)
    if i < len(bytes) and bytes[i] == Byte(ord(".")):
        i += 1
        while i < len(bytes) and Int(bytes[i]) >= ord("0") and Int(bytes[i]) <= ord("9"):
            scale *= 10
            frac = frac * 10 + Float64(Int(bytes[i]) - ord("0"))
            i += 1
    var value = Float64(whole) + frac / scale
    if neg:
        return -value
    return value
