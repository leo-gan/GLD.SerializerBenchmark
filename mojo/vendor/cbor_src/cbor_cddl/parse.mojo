from std.collections import List, Span

from cbor_cddl.model import (
    CT_ANY,
    CT_ARRAY,
    CT_BOOL,
    CT_BSTR,
    CT_CHOICE,
    CT_CONTROL,
    CT_FLOAT,
    CT_GENERIC,
    CT_INT,
    CT_NAMED,
    CT_NULL,
    CT_OPTIONAL,
    CT_REGEXP,
    CT_SOCKET,
    CT_STRUCT,
    CT_TAG,
    CT_TSTR,
    CT_UINT,
    CT_UNWRAP,
    CT_VALUE,
    CddlDoc,
    CK_INT_KEY,
    CK_POS_KEY,
    CK_TEXT_KEY,
    CddlMember,
    CddlType,
)
from cbor_runtime.error import DecodeError


struct _Lex[origin: ImmOrigin](Movable):
    var data: Span[Byte, Self.origin]
    var pos: Int

    def __init__(out self, data: Span[Byte, Self.origin]):
        self.data = data
        self.pos = 0

    def peek(self) -> Int:
        if self.pos >= len(self.data):
            return -1
        return Int(self.data[self.pos])

    def skip(mut self):
        while self.pos < len(self.data):
            var c = Int(self.data[self.pos])
            if c == 32 or c == 9 or c == 10 or c == 13:
                self.pos += 1
                continue
            if c == 59:
                while self.pos < len(self.data) and Int(self.data[self.pos]) != 10:
                    self.pos += 1
                continue
            break


def _is_ident_start(c: Int) -> Bool:
    return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95


def _is_ident(c: Int) -> Bool:
    return _is_ident_start(c) or (c >= 48 and c <= 57) or c == 45


def _slice_str[origin: ImmOrigin](data: Span[Byte, origin], start: Int, end: Int) raises DecodeError -> String:
    try:
        return String(from_utf8=data[start:end])
    except _:
        raise DecodeError(DecodeError.KIND_CDDL, start)


def _ident[origin: ImmOrigin](mut p: _Lex[origin]) raises DecodeError -> String:
    p.skip()
    if not _is_ident_start(p.peek()):
        raise DecodeError(DecodeError.KIND_CDDL, p.pos)
    var start = p.pos
    p.pos += 1
    while _is_ident(p.peek()):
        p.pos += 1
    return _slice_str(p.data, start, p.pos)


def _parse_int64[origin: ImmOrigin](mut p: _Lex[origin]) raises DecodeError -> Int64:
    p.skip()
    var neg = False
    if p.peek() == 45:
        neg = True
        p.pos += 1
    if p.peek() < 48 or p.peek() > 57:
        raise DecodeError(DecodeError.KIND_CDDL, p.pos)
    var n: Int64 = 0
    while p.peek() >= 48 and p.peek() <= 57:
        n = n * Int64(10) + Int64(p.peek() - 48)
        p.pos += 1
    if neg:
        return -n
    return n


def _eat_colon_or_arrow[origin: ImmOrigin](mut p: _Lex[origin]) raises DecodeError:
    p.skip()
    if p.peek() == 58:
        p.pos += 1
        return
    if p.peek() == 61:
        p.pos += 1
        _eat(p, 62)
        return
    raise DecodeError(DecodeError.KIND_CDDL, p.pos)


def _int_field_name(n: Int64) -> String:
    if n >= Int64(0):
        return String("k") + String(n)
    return String("k_") + String(-n)


def _eat[origin: ImmOrigin](mut p: _Lex[origin], ch: Int) raises DecodeError:
    p.skip()
    if p.peek() != ch:
        raise DecodeError(DecodeError.KIND_CDDL, p.pos)
    p.pos += 1


def _prelude(name: String) -> Int:
    if name == "any":
        return CT_ANY
    if name == "bool":
        return CT_BOOL
    if name == "int" or name == "integer" or name == "bigint" or name == "nint":
        return CT_INT
    if name == "uint":
        return CT_UINT
    if name == "tstr" or name == "text":
        return CT_TSTR
    if name == "bstr" or name == "bytes":
        return CT_BSTR
    if (
        name == "float"
        or name == "float16"
        or name == "float32"
        or name == "float64"
        or name == "number"
    ):
        return CT_FLOAT
    if name == "null" or name == "nil":
        return CT_NULL
    return -1


def _parse_type[origin: ImmOrigin](mut p: _Lex[origin], mut doc: CddlDoc) raises DecodeError -> Int:
    var left = _parse_type1(p, doc)
    p.skip()
    if p.peek() != 47:
        return left
    # choice: left / right / ...
    var first = left
    while True:
        p.skip()
        if p.peek() != 47:
            break
        p.pos += 1
        # reject //
        if p.peek() == 47:
            raise DecodeError(DecodeError.KIND_CDDL, p.pos)
        var right = _parse_type1(p, doc)
        first = doc.add_type(CddlType(CT_CHOICE, inner=first, inner2=right))
    return first


def _parse_string[origin: ImmOrigin](mut p: _Lex[origin]) raises DecodeError -> String:
    p.skip()
    if p.peek() != 34:
        raise DecodeError(DecodeError.KIND_CDDL, p.pos)
    p.pos += 1
    var start = p.pos
    while p.peek() != 34 and p.peek() != -1:
        if p.peek() == 92:
            p.pos += 2
        else:
            p.pos += 1
    if p.peek() != 34:
        raise DecodeError(DecodeError.KIND_CDDL, p.pos)
    var s = _slice_str(p.data, start, p.pos)
    p.pos += 1
    return s


def _parse_type2[origin: ImmOrigin](mut p: _Lex[origin], mut doc: CddlDoc) raises DecodeError -> Int:
    p.skip()
    if p.peek() == 126:
        p.pos += 1
        var inner = _parse_type2(p, doc)
        return doc.add_type(CddlType(CT_UNWRAP, inner=inner))
    if p.peek() == 123:
        return _parse_struct(p, doc)
    if p.peek() == 40:
        return _parse_group(p, doc)
    if p.peek() == 91:
        return _parse_array(p, doc)
    if p.peek() == 35:
        return _parse_tag(p, doc)
    if p.peek() == 34:
        var lit = _parse_string(p)
        return doc.add_type(CddlType(CT_VALUE, name=lit))
    if p.peek() == 36:
        # $socket or $$group-socket
        p.pos += 1
        var group = False
        if p.peek() == 36:
            p.pos += 1
            group = True
        var sname = _ident(p)
        var sock = doc.find_socket(sname)
        if sock < 0:
            sock = doc.add_socket(sname, group)
        return doc.add_type(CddlType(CT_SOCKET, name=sname, inner=sock))
    if p.peek() >= 48 and p.peek() <= 57 or p.peek() == 45:
        var start = p.pos
        if p.peek() == 45:
            p.pos += 1
        while p.peek() >= 48 and p.peek() <= 57:
            p.pos += 1
        var num = _slice_str(p.data, start, p.pos)
        return doc.add_type(CddlType(CT_VALUE, name=num))
    var name = _ident(p)
    if name == "decimalfraction":
        return doc.add_type(CddlType(CT_TAG, name=name, tag=UInt64(4)))
    if name == "bigfloat":
        return doc.add_type(CddlType(CT_TAG, name=name, tag=UInt64(5)))
    p.skip()
    if p.peek() == 60:
        # generic application name<T, U>
        p.pos += 1
        var astart = len(doc.extras)
        var acount = 0
        p.skip()
        while p.peek() != 62 and p.peek() != -1:
            var arg = _parse_type(p, doc)
            doc.extras.append(arg)
            acount += 1
            p.skip()
            if p.peek() == 44:
                p.pos += 1
                p.skip()
        _eat(p, 62)
        return doc.add_type(
            CddlType(CT_GENERIC, name=name, members_start=astart, members_count=acount)
        )
    var pk = _prelude(name)
    if pk >= 0:
        return doc.add_type(CddlType(pk, name=name))
    return doc.add_type(CddlType(CT_NAMED, name=name))


def _parse_type1[origin: ImmOrigin](mut p: _Lex[origin], mut doc: CddlDoc) raises DecodeError -> Int:
    var t = _parse_type2(p, doc)
    p.skip()
    if p.peek() != 46:
        return t
    p.pos += 1
    var ctl = _ident(p)
    if ctl == "regexp" or ctl == "pcre":
        var pat = _parse_string(p)
        return doc.add_type(CddlType(CT_REGEXP, name=pat, inner=t))
    var arg = _parse_type2(p, doc)
    return doc.add_type(CddlType(CT_CONTROL, name=ctl, inner=t, inner2=arg))


def _parse_tag[origin: ImmOrigin](mut p: _Lex[origin], mut doc: CddlDoc) raises DecodeError -> Int:
    _eat(p, 35)
    if p.peek() != 54:
        raise DecodeError(DecodeError.KIND_CDDL, p.pos)
    p.pos += 1
    _eat(p, 46)
    var n: UInt64 = 0
    if p.peek() < 48 or p.peek() > 57:
        raise DecodeError(DecodeError.KIND_CDDL, p.pos)
    while p.peek() >= 48 and p.peek() <= 57:
        n = n * UInt64(10) + UInt64(p.peek() - 48)
        p.pos += 1
    p.skip()
    var inner = -1
    if p.peek() == 40:
        p.pos += 1
        inner = _parse_type(p, doc)
        _eat(p, 41)
    return doc.add_type(CddlType(CT_TAG, tag=n, inner=inner))


def _parse_struct[origin: ImmOrigin](mut p: _Lex[origin], mut doc: CddlDoc) raises DecodeError -> Int:
    _eat(p, 123)
    var start = len(doc.members)
    var count = 0
    p.skip()
    while p.peek() != 125 and p.peek() != -1:
        var optional = False
        if p.peek() == 63:
            optional = True
            p.pos += 1
            p.skip()
        if p.peek() == 42:
            # open map * tstr => T — treat as remaining catch-all, skip to }
            raise DecodeError(DecodeError.KIND_CDDL, p.pos)
        if p.peek() == 126:
            var uty = _parse_type(p, doc)
            doc.members.append(CddlMember(String(""), uty, False))
            count += 1
            p.skip()
            if p.peek() == 44:
                p.pos += 1
                p.skip()
            continue
        var ch = p.peek()
        if (ch >= 48 and ch <= 57) or ch == 45:
            var ik = _parse_int64(p)
            _eat_colon_or_arrow(p)
            var ity = _parse_type(p, doc)
            doc.members.append(
                CddlMember(_int_field_name(ik), ity, optional, CK_INT_KEY, ik)
            )
            count += 1
            p.skip()
            if p.peek() == 44:
                p.pos += 1
                p.skip()
            continue
        var name = _ident(p)
        p.skip()
        _eat_colon_or_arrow(p)
        var ty = _parse_type(p, doc)
        doc.members.append(CddlMember(name, ty, optional, CK_TEXT_KEY, Int64(0)))
        count += 1
        p.skip()
        if p.peek() == 44:
            p.pos += 1
            p.skip()
    _eat(p, 125)
    return doc.add_type(
        CddlType(CT_STRUCT, members_start=start, members_count=count)
    )


def _parse_array[origin: ImmOrigin](mut p: _Lex[origin], mut doc: CddlDoc) raises DecodeError -> Int:
    _eat(p, 91)
    p.skip()
    var omin = 1
    var omax = 1
    var star = p.peek() == 42 or p.peek() == 43
    if p.peek() == 42:
        omin = 0
        omax = -1
        p.pos += 1
        p.skip()
    elif p.peek() == 43:
        omin = 1
        omax = -1
        p.pos += 1
        p.skip()
    if star:
        var inner = _parse_type(p, doc)
        _eat(p, 93)
        return doc.add_type(
            CddlType(CT_ARRAY, inner=inner, occur_min=omin, occur_max=omax)
        )
    var start = len(doc.members)
    var count = 0
    var named = False
    while p.peek() != 93 and p.peek() != -1:
        var optional = False
        if p.peek() == 63:
            optional = True
            p.pos += 1
            p.skip()
            if count == 0 and p.peek() != -1 and not _is_ident_start(p.peek()):
                var inner2 = _parse_type(p, doc)
                _eat(p, 93)
                return doc.add_type(
                    CddlType(CT_ARRAY, inner=inner2, occur_min=0, occur_max=1)
                )
        if _is_ident_start(p.peek()):
            var save = p.pos
            var ident = _ident(p)
            p.skip()
            if p.peek() == 58:
                p.pos += 1
                var ty = _parse_type(p, doc)
                doc.members.append(
                    CddlMember(ident, ty, optional, CK_POS_KEY, Int64(count))
                )
                named = True
            else:
                p.pos = save
                var ty2 = _parse_type(p, doc)
                doc.members.append(
                    CddlMember(
                        String("e") + String(count), ty2, optional, CK_POS_KEY, Int64(count)
                    )
                )
        else:
            var ty3 = _parse_type(p, doc)
            doc.members.append(
                CddlMember(
                    String("e") + String(count), ty3, optional, CK_POS_KEY, Int64(count)
                )
            )
        count += 1
        p.skip()
        if p.peek() == 44:
            p.pos += 1
            p.skip()
            continue
        break
    _eat(p, 93)
    if count == 1 and not named:
        var only = doc.members[start]
        if only.optional:
            return doc.add_type(
                CddlType(CT_ARRAY, inner=only.type_idx, occur_min=0, occur_max=1)
            )
        return doc.add_type(
            CddlType(CT_ARRAY, inner=only.type_idx, occur_min=1, occur_max=1)
        )
    return doc.add_type(
        CddlType(CT_STRUCT, name=String("[]"), members_start=start, members_count=count)
    )


def _parse_group[origin: ImmOrigin](mut p: _Lex[origin], mut doc: CddlDoc) raises DecodeError -> Int:
    _eat(p, 40)
    var start = len(doc.members)
    var count = 0
    p.skip()
    while p.peek() != 41 and p.peek() != -1:
        var optional = False
        if p.peek() == 63:
            optional = True
            p.pos += 1
            p.skip()
        if p.peek() == 126:
            var uty = _parse_type(p, doc)
            doc.members.append(CddlMember(String(""), uty, False))
            count += 1
            p.skip()
            if p.peek() == 44:
                p.pos += 1
                p.skip()
            continue
        var name = _ident(p)
        p.skip()
        _eat(p, 58)
        var ty = _parse_type(p, doc)
        doc.members.append(CddlMember(name, ty, optional))
        count += 1
        p.skip()
        if p.peek() == 44:
            p.pos += 1
            p.skip()
    _eat(p, 41)
    return doc.add_type(
        CddlType(CT_STRUCT, members_start=start, members_count=count)
    )


def _parent_dir(path: String) -> String:
    var last = -1
    var b = path.as_bytes()
    for i in range(len(b)):
        if Int(b[i]) == 47:
            last = i
    if last <= 0:
        return String(".")
    try:
        return String(from_utf8=b[0:last])
    except _:
        return String(".")


def _join_path(base: String, rel: String) -> String:
    var rb = rel.as_bytes()
    if len(rb) > 0 and Int(rb[0]) == 47:
        return rel
    if base == "." or base.byte_length() == 0:
        return rel
    return base + "/" + rel


def _read_file(path: String) raises DecodeError -> String:
    try:
        var f = open(path, "r")
        var s = String(f.read())
        f.close()
        return s
    except _:
        raise DecodeError(DecodeError.KIND_CDDL, 0)


def parse_cddl(text: String) raises DecodeError -> CddlDoc:
    return parse_cddl_from(text, String("."), True)


def parse_cddl_file(path: String) raises DecodeError -> CddlDoc:
    return parse_cddl_from(_read_file(path), _parent_dir(path), True)


def _path_seen(visited: List[String], path: String) -> Bool:
    for i in range(len(visited)):
        if visited[i] == path:
            return True
    return False


def parse_cddl_from(
    text: String, base_dir: String, allow_include: Bool
) raises DecodeError -> CddlDoc:
    var doc = CddlDoc()
    var visited = List[String]()
    _parse_into(text, base_dir, doc, allow_include, visited)
    if len(doc.def_names) == 0 and len(doc.socket_names) == 0:
        raise DecodeError(DecodeError.KIND_CDDL, 0)
    return doc^


def _parse_name_list[
    origin: ImmOrigin
](mut p: _Lex[origin]) raises DecodeError -> List[String]:
    var names = List[String]()
    names.append(_ident(p))
    p.skip()
    while p.peek() == 44:
        p.pos += 1
        names.append(_ident(p))
        p.skip()
    return names^


def _parse_into(
    text: String,
    base_dir: String,
    mut doc: CddlDoc,
    allow_include: Bool,
    mut visited: List[String],
) raises DecodeError:
    var b = text.as_bytes()
    var p = _Lex(b)
    p.skip()
    while p.peek() != -1:
        var dollars = 0
        while p.peek() == 36:
            p.pos += 1
            dollars += 1
        var name = _ident(p)
        p.skip()
        if dollars == 0 and name == "include":
            if not allow_include:
                raise DecodeError(DecodeError.KIND_CDDL, p.pos)
            var rel = _parse_string(p)
            var child = _join_path(base_dir, rel)
            if _path_seen(visited, child):
                raise DecodeError(DecodeError.KIND_CDDL, p.pos)
            visited.append(child)
            _parse_into(_read_file(child), _parent_dir(child), doc, True, visited)
            p.skip()
            continue
        if dollars == 0 and name == "export":
            p.skip()
            if p.peek() == 42:
                p.pos += 1
                doc.export_all = True
            else:
                doc.export_all = False
                var exported = _parse_name_list(p)
                for i in range(len(exported)):
                    doc.export_names.append(exported[i])
            p.skip()
            continue
        if dollars == 0 and name == "import":
            if not allow_include:
                raise DecodeError(DecodeError.KIND_CDDL, p.pos)
            var want = _parse_name_list(p)
            p.skip()
            var from_kw = _ident(p)
            if from_kw != "from":
                raise DecodeError(DecodeError.KIND_CDDL, p.pos)
            var rel = _parse_string(p)
            var child = _join_path(base_dir, rel)
            if _path_seen(visited, child):
                raise DecodeError(DecodeError.KIND_CDDL, p.pos)
            var before = len(doc.def_names)
            var prev_all = doc.export_all
            var prev_n = len(doc.export_names)
            doc.export_all = True
            visited.append(child)
            _parse_into(_read_file(child), _parent_dir(child), doc, True, visited)
            var child_all = doc.export_all
            if not child_all:
                for i in range(len(want)):
                    var ok = False
                    for j in range(prev_n, len(doc.export_names)):
                        if doc.export_names[j] == want[i]:
                            ok = True
                    if not ok:
                        raise DecodeError(DecodeError.KIND_CDDL, p.pos)
            for i in range(len(want)):
                var found = False
                for j in range(before, len(doc.def_names)):
                    if doc.def_names[j] == want[i]:
                        found = True
                if not found:
                    raise DecodeError(DecodeError.KIND_CDDL, p.pos)
            doc.export_all = prev_all
            p.skip()
            continue
        p.skip()
        if p.peek() == 60:
            p.pos += 1
            p.skip()
            while p.peek() != 62 and p.peek() != -1:
                _ = _ident(p)
                p.skip()
                if p.peek() == 44:
                    p.pos += 1
                    p.skip()
            _eat(p, 62)
            p.skip()
        var extend = False
        if p.peek() == 47:
            p.pos += 1
            if p.peek() == 47:
                p.pos += 1
            _eat(p, 61)
            extend = True
        else:
            _eat(p, 61)
        if dollars >= 1:
            var sock = doc.find_socket(name)
            if sock < 0:
                sock = doc.add_socket(name, dollars >= 2)
            var plug: Int
            if dollars >= 2:
                plug = _parse_group(p, doc)
            else:
                plug = _parse_type(p, doc)
            doc.add_plug(sock, plug)
            if not extend:
                doc.def_names.append(name)
                doc.def_types.append(
                    doc.add_type(CddlType(CT_SOCKET, name=name, inner=sock))
                )
        else:
            var ty = _parse_type(p, doc)
            if extend:
                var found = -1
                for i in range(len(doc.def_names)):
                    if doc.def_names[i] == name:
                        found = i
                if found >= 0:
                    var choice = doc.add_type(
                        CddlType(CT_CHOICE, inner=doc.def_types[found], inner2=ty)
                    )
                    doc.def_types[found] = choice
                else:
                    doc.def_names.append(name)
                    doc.def_types.append(ty)
            else:
                doc.def_names.append(name)
                doc.def_types.append(ty)
        p.skip()
