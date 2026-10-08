"""Go identifier mapping — spec/37-go-codegen-plan.md §12, spec/23-identifier-mapping.md.

Go's export rule makes casing semantic: an identifier is exported iff its first letter is
upper-case. So every schema name that becomes public API (getters, setters, value-struct
fields, type names, enum cases, union labels) is mapped to PascalCase, and only the
unexported positions (storage fields, factory parameters) can ever collide with Go's
all-lower-case keywords — those get the `_` suffix (Go has no raw-identifier escape).
Byte-neutral: identifier spelling never affects the wire.
"""
from __future__ import annotations
import re

#: Go's 25 keywords.
GO_KEYWORDS = frozenset({
    "break", "case", "chan", "const", "continue", "default", "defer", "else",
    "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map",
    "package", "range", "return", "select", "struct", "switch", "type", "var",
})

#: Predeclared identifiers an unexported local/param should not shadow.
GO_PREDECLARED = frozenset({
    "any", "bool", "byte", "comparable", "complex64", "complex128", "error", "float32",
    "float64", "int", "int8", "int16", "int32", "int64", "rune", "string", "uint",
    "uint8", "uint16", "uint32", "uint64", "uintptr", "true", "false", "iota", "nil",
    "append", "cap", "clear", "close", "complex", "copy", "delete", "imag", "len",
    "make", "max", "min", "new", "panic", "print", "println", "real", "recover",
})


#: Go's initialism convention (plan 37 O-G8, the `staticcheck` ST1003 list): a name part
#: spelled like one of these is written all-caps — `id`→`ID`, `url_path`→`URLPath`,
#: `http_status`→`HTTPStatus`, `userId`→`UserID`. Curated, not exhaustive.
GO_INITIALISMS = frozenset({
    "acl", "api", "ascii", "cpu", "css", "dns", "eof", "gid", "guid", "html", "http",
    "https", "id", "ip", "json", "qps", "ram", "rpc", "sla", "smtp", "sql", "ssh", "tcp",
    "tls", "ttl", "udp", "ui", "uid", "uuid", "uri", "url", "utf8", "vm", "xml", "xmpp",
    "xsrf", "xss", "sip", "rtp", "amqp", "db",
})

_CAMEL_SPLIT = re.compile(r"(?<=[a-z0-9])(?=[A-Z])")


def _cap(s: str) -> str:
    return s[0].upper() + s[1:] if s else s


def _parts(name: str) -> list[str]:
    """Name parts: split on `_`/whitespace and on lower→Upper camelCase boundaries
    (`requiresGrad`→[requires, Grad]; an all-caps run such as `UUID` stays one part)."""
    out = []
    for p in re.split(r"[_\s]+", name):
        out += [q for q in _CAMEL_SPLIT.split(p) if q]
    return out


def _part_exported(p: str) -> str:
    return p.upper() if p.lower() in GO_INITIALISMS else _cap(p)


def _join(first: str, rest: list[str]) -> str:
    """Concatenate mapped parts, keeping a `_` where it separates two digits: `f_int32_2`
    → `FInt32_2`, not `FInt322` (which reads as "int 322" and collides with `f_int322`)."""
    out = first
    for p in rest:
        if out and out[-1].isdigit() and p[:1].isdigit():
            out += "_"
        out += p
    return out


def go_exported(name: str) -> str:
    """Schema name → exported PascalCase Go identifier.
    `name`→`Name`, `postal_address`→`PostalAddress`, `requiresGrad`→`RequiresGrad`,
    `value1`→`Value1`, `id`→`ID`, `http_status`→`HTTPStatus` (GO_INITIALISMS),
    `f_int32_2`→`FInt32_2` (a digit-digit `_` is kept)."""
    parts = [_part_exported(p) for p in _parts(name)]
    return _join(parts[0], parts[1:]) if parts else name


def go_unexported(name: str) -> str:
    """Schema name → unexported lowerCamel Go identifier (`url_path`→`urlPath`,
    `id`→`id`), `_`-suffixed on a keyword or predeclared-identifier collision
    (`type`→`type_`, `len`→`len_`)."""
    parts = _parts(name)
    if not parts:
        return name
    head = parts[0]
    head = head.lower() if head.lower() in GO_INITIALISMS else head[0].lower() + head[1:]
    u = _join(head, [_part_exported(p) for p in parts[1:]])
    if u in GO_KEYWORDS or u in GO_PREDECLARED:
        return u + "_"
    return u


def go_type_name(name: str) -> str:
    """Schema Node/Enum/Union name → Go type name (PascalCase)."""
    return go_exported(name)


def go_case_name(case: str) -> str:
    """Enum case → the PascalCase part of its constant. Like `go_exported`, except that an
    ALL-CAPS part is a word, not an acronym run, and is title-cased — the rule Rust's
    `_rust_variant` adopted (spec/23 §2): `SPAN_KIND_SERVER`→`SpanKindServer` (it used to
    come out `SPANKINDSERVER`), `HTTP2`→`Http2`. A part that IS an initialism keeps Go's
    convention (`HTTP_STATUS`→`HTTPStatus`, `id`→`ID`)."""
    parts = [p.upper() if p.lower() in GO_INITIALISMS
             else p[0] + p[1:].lower() if len(p) > 1 and p.isupper()
             else _cap(p)
             for p in _parts(case)]
    return _join(parts[0], parts[1:]) if parts else case


def go_enum_case(enum_name: str, case: str) -> str:
    """Enum case → type-prefixed constant: (`Color`, `red`) → `ColorRed`,
    (`SpanKind`, `SPAN_KIND_SERVER`) → `SpanKindSpanKindServer`."""
    return f"{go_type_name(enum_name)}{go_case_name(case)}"


def go_label(label: str) -> str:
    """Union label → the PascalCase part of every name derived from it — the constructor
    `{Union}{Label}`, the tag constant, the view getter. Same rule as enum cases
    (`go_case_name`), as in Rust, where one rule names both (spec/23 §2):
    `string_value`→`StringValue`, `SPAN_LINK`→`SpanLink`, `url`→`URL`."""
    return go_case_name(label)


def go_union_tag(union_name: str, label: str) -> str:
    """Union label → tag constant: (`Shape`, `circle`) → `ShapeTagCircle`."""
    return f"{go_type_name(union_name)}Tag{go_label(label)}"


def go_str_literal(s: str) -> str:
    """A Go interpreted string literal for `s`."""
    out = ['"']
    for ch in s:
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ch == "\r":
            out.append("\\r")
        elif ord(ch) < 0x20:
            out.append(f"\\x{ord(ch):02x}")
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)
