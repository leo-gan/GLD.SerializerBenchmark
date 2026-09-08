from std.collections import List, Optional

from pb_descriptor.model import FileDesc, FileDescSet, MessageDesc


def _keywords() -> List[String]:
    return [
        String("alias"),
        String("as"),
        String("break"),
        String("comptime"),
        String("continue"),
        String("def"),
        String("elif"),
        String("else"),
        String("except"),
        String("False"),
        String("finally"),
        String("fn"),
        String("for"),
        String("from"),
        String("if"),
        String("import"),
        String("in"),
        String("mut"),
        String("None"),
        String("out"),
        String("owned"),
        String("raises"),
        String("read"),
        String("ref"),
        String("return"),
        String("struct"),
        String("trait"),
        String("True"),
        String("try"),
        String("var"),
        String("while"),
    ]


def _reserved() -> List[String]:
    return [
        String("ProtoMessage"),
        String("WireWriter"),
        String("WireReader"),
        String("WireType"),
        String("DecodeError"),
        String("UnknownFieldSet"),
        String("unknown"),
        String("encode"),
        String("decode"),
        String("encoded_len"),
        String("encode_to"),
        String("merge_from"),
        String("List"),
        String("String"),
        String("Optional"),
        String("Span"),
        String("Byte"),
        String("Dict"),
        String("Int"),
        String("Int32"),
        String("Int64"),
        String("UInt32"),
        String("UInt64"),
        String("Float32"),
        String("Float64"),
        String("Bool"),
    ]


def _in_list(items: List[String], name: String) -> Bool:
    for i in range(len(items)):
        if items[i] == name:
            return True
    return False


def is_keyword(name: String) -> Bool:
    return _in_list(_keywords(), name)


def byte_at(s: String, i: Int) -> Byte:
    return s.as_bytes()[i]


def flatten_nested(dotted: String) raises -> String:
    """`Outer.Inner` → `OuterInner`."""
    var buf = List[Byte]()
    var raw = dotted.as_bytes()
    for i in range(len(raw)):
        if raw[i] != Byte(ord(".")):
            buf.append(raw[i])
    return String(from_utf8=buf)


def mojo_type_name(proto_name: String) raises -> String:
    var flat = flatten_nested(proto_name)
    if _in_list(_reserved(), flat):
        return flat + "_"
    if is_keyword(flat):
        return "`" + flat + "`"
    return flat


def mojo_field_name(proto_name: String) -> String:
    if is_keyword(proto_name):
        return "`" + proto_name + "`"
    if _in_list(_reserved(), proto_name):
        return proto_name + "_"
    return proto_name


struct ResolvedType(Copyable, Movable, Defaultable, Deinitable):
    var mojo_name: String
    var import_pkg: String
    var ok: Bool
    var error: String

    def __init__(out self):
        self.mojo_name = String()
        self.import_pkg = String()
        self.ok = False
        self.error = String()


def _package_prefix_len(package: String, rest: String) -> Int:
    """If `rest` is `package` or `package.More`, return len(package); else -1."""
    if package.byte_length() == 0:
        return 0
    if rest == package:
        return package.byte_length()
    var prefix = package + "."
    if rest.byte_length() >= prefix.byte_length():
        var matched = True
        for i in range(prefix.byte_length()):
            if byte_at(rest, i) != byte_at(prefix, i):
                matched = False
                break
        if matched:
            return package.byte_length()
    return -1


def slice_bytes(s: String, start: Int, end: Int) raises -> String:
    var buf = List[Byte]()
    var i = start
    while i < end:
        buf.append(byte_at(s, i))
        i += 1
    if len(buf) == 0:
        return String()
    return String(from_utf8=buf)


def _remainder_after(rest: String, pkg_len: Int) raises -> String:
    if pkg_len == 0:
        return rest
    if rest.byte_length() == pkg_len:
        return String()
    return slice_bytes(rest, pkg_len + 1, rest.byte_length())


def safe_stem(path: String) raises -> String:
    var st = file_stem(path)
    if is_keyword(st) or _in_list(_reserved(), st):
        return st + "_"
    return st


def file_stem(path: String) raises -> String:
    var start = 0
    var end = path.byte_length()
    for i in range(path.byte_length()):
        if byte_at(path, i) == Byte(ord("/")):
            start = i + 1
    if end >= 6:
        var looks = True
        var suf = String(".proto")
        for i in range(6):
            if byte_at(path, end - 6 + i) != suf.as_bytes()[i]:
                looks = False
        if looks:
            end = end - 6
    return slice_bytes(path, start, end)


def _file_has_type(file: FileDesc, rem: String) raises -> Bool:
    if rem.byte_length() == 0:
        return False
    for i in range(len(file.enums)):
        if file.enums[i].name == rem:
            return True
    for i in range(len(file.messages)):
        if file.messages[i].dotted_name() == rem:
            return True
        if flatten_nested(file.messages[i].dotted_name()) == rem:
            return True
        for j in range(len(file.messages[i].enums)):
            var en = file.messages[i].dotted_name() + "." + file.messages[i].enums[j].name
            if en == rem or flatten_nested(en) == rem:
                return True
            if file.messages[i].enums[j].name == rem:
                return True
    return False


def resolve_type_name(
    set: FileDescSet, current_file: String, type_name: String
) raises -> ResolvedType:
    var result = ResolvedType()
    if type_name.byte_length() == 0:
        result.error = "empty type_name"
        return result^
    var rest = type_name
    if byte_at(type_name, 0) == Byte(ord(".")):
        rest = slice_bytes(type_name, 1, type_name.byte_length())
    var best_i = -1
    var best_len = -1
    for i in range(len(set.files)):
        var n = _package_prefix_len(set.files[i].package, rest)
        if n < 0:
            continue
        var rem = _remainder_after(rest, n)
        if not _file_has_type(set.files[i], rem):
            continue
        if n > best_len:
            best_len = n
            best_i = i
    if best_i < 0:
        result.error = "unresolved type_name: " + type_name
        return result^
    var rem = _remainder_after(rest, best_len)
    if rem.byte_length() == 0:
        result.error = "unresolved type_name (no message path): " + type_name
        return result^
    result.mojo_name = mojo_type_name(rem)
    var defining = set.files[best_i].name
    if defining != current_file:
        if set.files[best_i].package.byte_length() != 0:
            result.import_pkg = set.files[best_i].package
        else:
            result.import_pkg = file_stem(defining)
    result.ok = True
    return result^
