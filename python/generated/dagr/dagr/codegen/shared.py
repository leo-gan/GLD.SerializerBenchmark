from __future__ import annotations
import re
from dagr.dsl import DataGraph, Node, Enum, EntryType, Field, UnionType
from dagr.dsl import (  # meta-record band, "spec/34-meta-records-and-stream-introspection.md"
    META_TYPE_ID_BASE, META_TYPE_ID_END, MAX_SINK_NODE_TYPES, is_meta_type_id,
)


# ── DataSink record enumeration (34 §2) ─────────────────────────────────────────

def sink_record_entries(sink) -> list:
    """`[(type_id, entry, is_meta), …]` for every record type of a DataSink, in
    typeId order — `node_types[i]` → `i`, `meta_types[i]` → `META_TYPE_ID_BASE + i`.

    Every sink generator MUST enumerate records through this (not
    `enumerate(sink.node_types)`), so all targets assign the meta band identically.
    Also runs the 34 §2.1 build guard so every target fails the same way."""
    check_sink_type_budget(sink)
    return sink.record_entries()


def check_sink_type_budget(sink) -> None:
    """34 §2.1 build guard: payload typeIds must stay below the meta band."""
    n = len(sink.node_types)
    if n > MAX_SINK_NODE_TYPES:
        raise ValueError(
            f"DataSink {sink.name!r}: {n} node_types exceed the payload typeId space "
            f"(max {MAX_SINK_NODE_TYPES}; {META_TYPE_ID_BASE}…{META_TYPE_ID_END} is the "
            f"reserved meta band, 34 §2.1)"
        )


# ── TypeScript import pruning ───────────────────────────────────────────────────

# ── SharedBuffer pure-API constants (§14) ───────────────────────────────────────
# A `constants=` entry becomes a compile-time constant in every target's overlay —
# no wire footprint, just a shared value the generated code (and its callers) can
# reference so a schema-level number/string is defined once, not duplicated per
# language. Mojo and Odin get untyped constants that adapt to their use site; Rust
# needs an explicit type; Swift / TypeScript infer.

def _sb_const_kind(value):
    # bool is a subclass of int — test it first.
    if isinstance(value, bool):  return "bool"
    if isinstance(value, int):   return "int"
    if isinstance(value, float): return "float"
    if isinstance(value, str):   return "str"
    raise ValueError(f"unsupported SharedBuffer constant value: {value!r}")


def _sb_str_literal(s: str) -> str:
    esc = (s.replace("\\", "\\\\").replace('"', '\\"')
             .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t"))
    return f'"{esc}"'


def sb_constant_decl(lang: str, name: str, value) -> str:
    """One compile-time-constant declaration line for `lang` (no trailing newline)."""
    kind = _sb_const_kind(value)
    # Per-language literal (bool casing differs: Mojo/Python use True/False).
    if kind == "bool":
        lit = ("True" if value else "False") if lang in ("mojo", "python") else ("true" if value else "false")
    elif kind == "int":
        lit = str(int(value))
    elif kind == "float":
        lit = repr(float(value))          # round-trippable, e.g. 1280.0, 0.74, 1e-05
    else:
        lit = _sb_str_literal(value)

    if lang == "mojo":
        return f"comptime {name} = {lit}"
    if lang == "odin":
        return f"{name} :: {lit}"
    if lang == "rust":
        ty = {"bool": "bool", "int": "i64", "float": "f64", "str": "&str"}[kind]
        return f"pub const {name}: {ty} = {lit};"
    if lang == "swift":
        return f"public let {name} = {lit}"        # type inferred
    if lang in ("typescript", "ts"):
        return f"export const {name} = {lit};"     # type inferred
    if lang == "python":
        return f"{name} = {lit}"                    # module-level constant
    raise ValueError(f"sb_constant_decl: unknown lang {lang!r}")


def sb_constants_block(lang: str, sb, comment_prefix: str) -> list[str]:
    """The full constants block for `sb` in `lang`, or [] when none are declared.
    `comment_prefix` is the language's line-comment token (e.g. '# ', '// ')."""
    consts = getattr(sb, "constants", None)
    if not consts:
        return []
    lines = [f"{comment_prefix}Schema constants (pure API — not stored in the buffer)."]
    lines += [sb_constant_decl(lang, n, v) for n, v in consts.items()]
    return lines


def ts_used_imports(body: str, candidates) -> list[str]:
    """Return the subset of `candidates` referenced as identifiers in `body`.

    Generated TS modules import a large fixed runtime surface but each file uses
    only a fraction of it; ESLint's `no-unused-vars` then flags the rest. Compute
    the actually-used subset by scanning the assembled module body for each name
    as a standalone identifier (not a member access like `b.storeF32`), so the
    emitted `import { … }` list carries only what the file references.
    """
    if isinstance(candidates, str):
        names = [c.strip() for c in candidates.split(",") if c.strip()]
    else:
        names = [c.strip() for c in candidates if c.strip()]
    used = []
    for n in names:
        # Word-boundary match, but reject member access (preceded by `.`) so that
        # e.g. Builder methods sharing a runtime helper's name don't count.
        if re.search(r"(?<![\w$.])" + re.escape(n) + r"(?![\w$])", body):
            used.append(n)
    return used


def ts_strip_unused_functions(body: str, keep=()) -> str:
    """Remove top-level `function` declarations not reachable from exports/other code.

    Generated serde/sink modules emit a full set of per-union / per-node store
    helper variants, but any single schema exercises only some; the rest trip
    ESLint's `no-unused-vars`. This drops top-level functions whose name never
    appears outside their own body, iterating to a fixpoint so helper chains that
    become dead collapse too. `export`ed functions and names in `keep` are roots
    and never removed.

    Span detection relies on the generated layout: every top-level function starts
    at column 0 with `function`/`export function` and its body is indented, so the
    first following column-0 `}` closes it (no brace counting, string-safe).
    """
    lines = body.split("\n")
    keep = set(keep)
    spans = []  # (name, start, end_exclusive, exported)
    i = 0
    while i < len(lines):
        m = re.match(r"(export\s+)?function\s+([A-Za-z0-9_$]+)", lines[i])
        if m:
            start = i
            j = i + 1
            while j < len(lines) and not re.match(r"^\}", lines[j]):
                j += 1
            spans.append([m.group(2), start, j + 1, bool(m.group(1))])
            i = j + 1
            continue
        # Single-line top-level `const NAME = …;` (e.g. a `_storePacked*` alias) is
        # removable too when nothing references it. Multi-line consts are left alone.
        c = re.match(r"(export\s+)?const\s+([A-Za-z0-9_$]+)\s*=.*;\s*$", lines[i])
        if c:
            spans.append([c.group(2), i, i + 1, bool(c.group(1))])
        i += 1
    removed: set[int] = set()  # indices into spans

    def rest_text(exclude_idx):
        excluded = set()
        for k in list(removed) + [exclude_idx]:
            s = spans[k]
            excluded.update(range(s[1], s[2]))
        return "\n".join(l for n, l in enumerate(lines) if n not in excluded)

    changed = True
    while changed:
        changed = False
        for idx, s in enumerate(spans):
            if idx in removed or s[3] or s[0] in keep:
                continue
            if re.search(r"(?<![\w$.])" + re.escape(s[0]) + r"(?![\w$])", rest_text(idx)) is None:
                removed.add(idx)
                changed = True
    if not removed:
        return body
    drop_lines = set()
    for k in removed:
        s = spans[k]
        drop_lines.update(range(s[1], s[2]))
    out = [l for n, l in enumerate(lines) if n not in drop_lines]
    # Collapse the blank-line runs left behind so output stays tidy.
    return re.sub(r"\n{3,}", "\n\n", "\n".join(out))


def ts_unions_needing_brand(unions, lookup) -> set:
    """Names of unions whose TS type must be generic over the arena brand `B`.

    A union needs `<B>` only if it can reach a node handle — directly (a node variant,
    scalar or array element) or transitively through a nested-union variant. A
    value-only union (scalars / enums / value arrays only) never does, so it can drop
    the phantom `<B>` type parameter and the unused `a`/`seen`/`b` arguments its
    resolve / materialize / store helpers would otherwise carry for uniformity."""
    def _elem(vt):
        return vt.inner if vt.kind in ("array", "arrayWithOptionals") else vt

    def has_node(u):
        for _lbl, vt in u.types:
            it = _elem(vt)
            if it is not None and it.kind == "ref" and isinstance(lookup.get(it.inner), Node):
                return True
        return False

    need = {u.name for u in unions if has_node(u)}
    changed = True
    while changed:
        changed = False
        for u in unions:
            if u.name in need:
                continue
            for _lbl, vt in u.types:
                it = _elem(vt)
                if (it is not None and it.kind == "ref"
                        and isinstance(lookup.get(it.inner), UnionType) and it.inner in need):
                    need.add(u.name)
                    changed = True
                    break
    return need


def ts_import_line(names, module: str, body: str, type_only=()) -> str:
    """Build `import { <used> } from "<module>";`, pruned to names used in body.

    Names listed in `type_only` that are used get their own `import type { … }` line
    (so `@typescript-eslint/consistent-type-imports` stays clean under type-checked
    lint configs). Returns an empty string if nothing is used (caller drops the line);
    when both value and type names are used, returns the two lines joined by a newline."""
    used = ts_used_imports(body, names)
    if not used:
        return ""
    type_set = set(type_only)
    value_used = [n for n in used if n not in type_set]
    type_used = [n for n in used if n in type_set]
    lines = []
    if value_used:
        lines.append(f'import {{ {", ".join(value_used)} }} from "{module}";')
    if type_used:
        lines.append(f'import type {{ {", ".join(type_used)} }} from "{module}";')
    return "\n".join(lines)


# ── Naming helpers ─────────────────────────────────────────────────────────────

def _cap(s: str) -> str:
    return s[0].upper() + s[1:] if s else s

def _low(s: str) -> str:
    return s[0].lower() + s[1:] if s else s

def _snake(s: str) -> str:
    """PascalCase / ALLCAPS → snake_case (e.g. UUID→uuid, PersonId→person_id)."""
    s = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', s)
    s = re.sub(r'([a-z\d])([A-Z])', r'\1_\2', s)
    return s.lower()


# ── Rust identifier mapping ─────────────────────────────────────────────────────
# A schema name is not guaranteed to be a valid/idiomatic identifier in the target
# language: it may need case conversion (enum cases → UpperCamelCase variants) or it
# may collide with a language keyword (a `type`/`match`/`move` field).  These map a
# schema name to a safe Rust identifier.  Both are no-ops for names that are already
# valid Rust (single-word/camelCase cases, non-keyword fields), so they don't churn
# existing output.  (This is Rust-specific; sibling languages will get their own.)

#: Rust keywords (2015 + 2018) — reserved words a field identifier must not equal.
_RUST_KEYWORDS = frozenset({
    "as", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern",
    "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move",
    "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super",
    "trait", "true", "type", "unsafe", "use", "where", "while", "async", "await",
    "abstract", "become", "box", "do", "final", "macro", "override", "priv",
    "typeof", "unsized", "virtual", "yield", "try", "union",
})
def _rust_variant(name: str) -> str:
    """Schema enum-case / union-variant label → an UpperCamelCase Rust variant.

    Splits on underscores/whitespace and capitalises each part (leaving already-
    camelCase parts intact), so `g_force`→`GForce`, `low_power`→`LowPower`, while
    `requiresGrad`→`RequiresGrad` and `ok`→`Ok` are unchanged. An ALL-CAPS part is
    a word, not an acronym run, so it is title-cased: `SPAN_KIND_SERVER`→
    `SpanKindServer` (it used to come out `SPANKINDSERVER`), `HTTP2`→`Http2`.
    `Self` is the only UpperCamelCase form that is a keyword, so it alone needs a
    guard. Distinct labels can map to one variant (`low_power` / `LowPower`);
    `rust_variant_collisions` rejects that at validation time."""
    parts = [p for p in re.split(r'[_\s]+', name) if p]
    out = "".join(p[0] + p[1:].lower() if len(p) > 1 and p.isupper() else _cap(p)
                  for p in parts) or name
    return out + "_" if out == "Self" else out


def _rust_enum_case_ref(enum_obj, case_name: str) -> str:
    """Rust identifier for referencing an enum case (the part after `Enum::`).

    Mirrors the enum emission in dagr_codegen_rust: a bitset enum is a newtype with UPPERCASE
    associated consts (`Mods::SHIFT`), a plain enum has UpperCamelCase variants (`Tool::Pen`).
    Using `_cap` for both was a bug — it produced `Mods::Shift`, which doesn't exist on the
    bitset newtype, so a bitset `ref_val` default broke write-side elision + read synthesis."""
    return case_name.upper() if enum_obj.as_bitset else _rust_variant(case_name)


#: Keywords that cannot be written as raw identifiers (`r#…`) — rename these.
_RUST_KEYWORDS_NO_RAW = frozenset({"crate", "self", "Self", "super"})


def _rust_ident(snake_name: str) -> str:
    """Escape an ALREADY-snake_case name so it is a legal Rust identifier at a BARE
    position (a getter/struct-field name, or a `self.field` access — anywhere the
    name stands alone).

    A keyword collision becomes a raw identifier `r#type` (idiomatic, preserves the
    name), falling back to a trailing-underscore rename for the four keywords that
    cannot be raw (`self`/`crate`/`super`/`Self`).  Non-keywords pass through.

    Use ONLY at bare positions: `r#type` is invalid spliced into a compound
    identifier (`set_r#type`, `r#type_root`).  Compound positions keep the plain
    snake name — `set_type`/`type_root`/`_type_val` are ordinary identifiers, not
    keywords, so they need no escaping (and would only invite double-underscore
    lints if escaped)."""
    if snake_name in _RUST_KEYWORDS_NO_RAW:
        return snake_name + "_"
    if snake_name in _RUST_KEYWORDS:
        return "r#" + snake_name
    return snake_name


def _rust_field(name: str) -> str:
    """Schema field name → a keyword-safe Rust identifier for a bare position
    (`_snake` + `_rust_ident`).  Use where the raw schema name is on hand; where the
    already-snaked `fname` is threaded through, call `_rust_ident(fname)` directly."""
    return _rust_ident(_snake(name))

# ── Swift identifier mapping ────────────────────────────────────────────────────
# Swift does not warn on snake_case cases (unlike Rust's non_camel_case), so the
# only compile-blocking issue is a keyword collision (a `default`/`where`/`type`
# field or enum case).  Swift's escape is a backtick wrapper, which — unlike Rust's
# `r#` — is valid at every BARE position (property name, enum case, union label,
# member access `x.`type``), so no bare/compound split is needed for the wrapper
# itself.  It is still applied only at bare positions: a compound token like
# `_type`/`typeS`/`setType` is not the keyword `type`, so it needs no escape (and
# `` _`type` `` would be a syntax error anyway).  It is case-preserving (Swift keeps
# the schema's camelCase field names); it does not snake_case.

#: Swift keywords reserved as identifiers (declaration + statement + expression +
#: type keywords).  Contextual keywords (convenience, mutating, …) are legal as
#: identifiers and are intentionally excluded.
_SWIFT_KEYWORDS = frozenset({
    "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func",
    "import", "init", "inout", "internal", "let", "open", "operator", "private",
    "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias",
    "var", "break", "case", "continue", "default", "defer", "do", "else",
    "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch", "where",
    "while", "as", "Any", "catch", "false", "is", "nil", "super", "self", "Self",
    "throw", "throws", "true", "try", "await", "async", "some",
})


def _swift_ident(name: str) -> str:
    """Escape a Swift keyword identifier with backticks (case-preserving).  Valid at
    any BARE position — property name, enum case, union label, `x.`name`` member
    access.  Non-keywords pass through unchanged.  Apply ONLY at bare positions;
    compound tokens (`_name`, `nameS`, `setName`) are ordinary identifiers."""
    return f"`{name}`" if name in _SWIFT_KEYWORDS else name


def _arena_name(graph_name: str) -> str:
    return f"{graph_name}Arena"

def _arena_of(node_name: str) -> str:
    return f"arenaOf{_cap(node_name)}"

def _arena_of_snake(node_name: str) -> str:
    return f"arena_of_{_snake(node_name)}"

def _new_node(node_name: str) -> str:
    return f"new{_cap(node_name)}"

def _new_node_snake(node_name: str) -> str:
    return f"new_{_snake(node_name)}"

def _free_slots_of_snake(node_name: str) -> str:
    return f"free_slots_of_{_snake(node_name)}"


# ── Deletion toggle (spec/09-deletion-of-nodes.md) ──────────────────────────────────
# Per-graph flag mirroring DataGraph.deletable. When False the generated arena is
# append-only — no delete()/is_valid(), no free-list reuse, no generation tracking;
# handles and stored refs collapse to a bare index. Serialized bytes are identical
# to the deletable form (the wire format never encoded generation). Set once by each
# language's top-level generate_* entry, read by the per-feature emitters. Codegen is
# single-threaded, so a module global is safe.
_DELETABLE = True

def set_deletable(flag: bool) -> None:
    global _DELETABLE
    _DELETABLE = bool(flag)

def is_deletable() -> bool:
    return _DELETABLE

# ── Rust struct-literal helpers (generation-aware) ─────────────────────────────
# A NodeRef / node handle carries a `generation` alongside `index` only when the
# graph is deletable. These helpers emit the struct literal with or without that
# field so call sites stay agnostic to the toggle.

def _rust_gen_field(gen_expr: str) -> str:
    """', generation: <expr>' fragment, or '' when the graph is non-deletable."""
    return f", generation: {gen_expr}" if _DELETABLE else ""

def _rust_node_ctor(node_name: str, index_expr: str, gen_expr: str, graph_expr: str) -> str:
    """A `{Node} { index, [generation,] graph }` handle literal."""
    return f"{node_name} {{ index: {index_expr}{_rust_gen_field(gen_expr)}, graph: {graph_expr} }}"

def _rust_noderef(index_expr: str, gen_expr: str) -> str:
    """A `NodeRef { index, [generation] }` stored-reference literal."""
    return f"NodeRef {{ index: {index_expr}{_rust_gen_field(gen_expr)} }}"


# ── Enum helpers ───────────────────────────────────────────────────────────────

def _enum_raw_width(enum: Enum) -> str:
    """Returns the backing integer kind (u8/u16/u32/u64) for an enum's raw storage."""
    if enum.as_bitset:
        if enum.capacity <= 8:  return "u8"
        if enum.capacity <= 16: return "u16"
        if enum.capacity <= 32: return "u32"
        return "u64"
    else:
        if enum.capacity <= 255: return "u8"
        return "u16"


def _enum_bits_per_elem(enum_obj: Enum) -> "int | None":
    """Returns 1, 2, or 4 bits per elem for sub-byte enum array packing, or None for full-byte.
    For as_bitset enums, capacity = number of bit flags; for regular enums, capacity = max case count.
    """
    cap = enum_obj.capacity
    if enum_obj.as_bitset:
        if cap <= 1:  return 1
        if cap <= 2:  return 2
        if cap <= 4:  return 4
        return None
    else:
        if cap <= 2:  return 1
        if cap <= 4:  return 2
        if cap <= 16: return 4
        return None


def _is_enum_ref(t: EntryType, lookup: dict) -> bool:
    """True if t is a direct ref to an Enum type."""
    return t.kind == "ref" and isinstance(lookup.get(t.inner), Enum)


def _is_array_of_enum_ref(t: EntryType, lookup: dict) -> bool:
    """True if t is an array (or arrayWithOptionals) of refs to Enum types."""
    return (t.kind in ("array", "arrayWithOptionals")
            and t.inner.kind == "ref"
            and isinstance(lookup.get(t.inner.inner), Enum))


# ── Field classification helpers ───────────────────────────────────────────────

def _is_ref(t: EntryType) -> bool:
    return t.kind == "ref"

def _is_array_of_ref(t: EntryType) -> bool:
    return t.kind in ("array", "arrayWithOptionals") and t.inner.kind == "ref"

def _is_array(t: EntryType) -> bool:
    return t.kind in ("array", "arrayWithOptionals")

def _has_cycle_risk(fields: list[Field]) -> bool:
    return any(_is_ref(f.type) or _is_array_of_ref(f.type) for f in fields)


def _node_can_cycle(node: Node, lookup: dict) -> bool:
    """True if a node of this type could appear in a reference/containment CYCLE —
    i.e. type ``node.name`` can reach itself through its fields (refs, arrays-of-ref,
    or union variants, expanding unions transitively). When this is False, the
    runtime cycle guard (``in_progress`` / ``packed_in_progress``) is provably never
    triggered for this type — a re-entrant store can't happen — so the serializer
    emits a lightweight dedup-only path (no cycle-set hashing). The byte output is
    identical either way; the only effect is speed.

    CONSERVATIVE by construction: any unresolved reference target on a reachable
    path forces a True result (keep the guard). A wrong False would not corrupt
    bytes — it would infinite-loop on genuinely cyclic data — and the cyclic
    round-trip specs gate exactly that, but we stay safe regardless."""
    def _ref_targets(t: EntryType) -> list:
        if t.kind == "ref":
            return [t.inner]
        if t.kind in ("array", "arrayWithOptionals"):
            return _ref_targets(t.inner)
        return []

    def _child_nodes(name: str):
        """Node-type names structurally referenced by `name` (unions expanded),
        or None if any target is unresolved (→ treat conservatively as cyclic)."""
        obj = lookup.get(name)
        if obj is None:
            return None
        stack: list = []
        if isinstance(obj, Node):
            for f in _node_fields(obj):
                stack.extend(_ref_targets(f.type))
        elif isinstance(obj, UnionType):
            for _lbl, et in obj.types:
                stack.extend(_ref_targets(et))
        else:  # Enum / scalar alias — a leaf, no outgoing node edges
            return set()
        out: set = set()
        seen: set = set()
        while stack:
            nm = stack.pop()
            if nm in seen:
                continue
            seen.add(nm)
            o = lookup.get(nm)
            if o is None:
                return None
            if isinstance(o, Node):
                out.add(nm)
            elif isinstance(o, UnionType):
                for _lbl, et in o.types:
                    stack.extend(_ref_targets(et))
            # Enum: leaf
        return out

    start = node.name
    firsts = _child_nodes(start)
    if firsts is None:
        return True
    stack = list(firsts)
    seen: set = set()
    while stack:
        nm = stack.pop()
        if nm == start:
            return True
        if nm in seen:
            continue
        seen.add(nm)
        nxt = _child_nodes(nm)
        if nxt is None:
            return True
        stack.extend(nxt)
    return False


def _field_all_node_refs(t: EntryType, lookup: dict) -> set:
    """All node-type names a field of type `t` can reach, expanding unions transitively
    (refs, arrays-of-ref, and every node reachable through a referenced UnionType)."""
    def _ref_targets(tt: EntryType) -> list:
        if tt.kind == "ref":
            return [tt.inner]
        if tt.kind in ("array", "arrayWithOptionals"):
            return _ref_targets(tt.inner)
        return []
    out: set = set()
    seen: set = set()
    stack: list = list(_ref_targets(t))
    while stack:
        nm = stack.pop()
        if nm in seen:
            continue
        seen.add(nm)
        o = lookup.get(nm)
        if isinstance(o, Node):
            out.add(nm)
        elif isinstance(o, UnionType):
            for _lbl, et in o.types:
                stack.extend(_ref_targets(et))
    return out


def packed_context_nodes(nodes, lookup: dict) -> set:
    """Names of the Node types stored in a PACKED context somewhere in the graph: every
    `packed=True` node, and — because packed propagates downward (`spec/07 §1`,
    `spec/16 §3`) — every node reachable from one through a node ref, a node array or a
    union variant (nested unions included), transitively. A node in this set that is not
    itself declared `packed` is PROMOTED: it is written by `store_packed`, read through its
    packed accessor / packed restore, and so is everything below it — not just its direct
    children. A `raw` node ref is the one boundary: the leaf keeps its own format
    (`spec/18`), so propagation does not cross it."""
    ctx = {n.name for n in nodes if isinstance(n, Node) and n.packed}
    work = list(ctx)
    while work:
        node = lookup.get(work.pop())
        if not isinstance(node, Node):
            continue
        for f in _node_fields(node):
            if f.is_raw_embedded_ref(lookup):
                continue
            for nm in _field_all_node_refs(f.type, lookup):
                if nm not in ctx:
                    ctx.add(nm)
                    work.append(nm)
    return ctx


def packed_root_view(graph):
    """`graph` as its generators should see it when the ROOT is packed: every node
    reachable from the root (not across a `raw` ref) declared `packed`, `frozen` kept.

    Packed propagates downward (`spec/07 §1`, `spec/16 §3`), so under a packed root those
    nodes are stored packed whatever they declare, and declaring it changes no byte. The
    view lets every generator treat a packed-rooted graph as the uniformly packed graph it
    is on the wire — one accessor per node, a direct builder (`direct_buildable` asks for
    declared-packed nodes), no dead regular variants — while a schema can leave shared
    nodes (an imported common graph) layout-free for whichever importer holds them.

    Returns `graph` itself when the root is not a packed node or nothing needs promoting
    (so no existing schema's output moves); otherwise a flattened copy
    (`flatten_graph_imports`) with the promoted nodes replaced."""
    import copy
    root = graph.root_type
    lookup = graph.lookup
    if root is None or root.kind != "ref" or not isinstance(lookup.get(root.inner), Node) \
            or not lookup[root.inner].packed:
        return graph
    reach, work = {root.inner}, [root.inner]
    while work:
        for f in _node_fields(lookup[work.pop()]):
            if f.is_raw_embedded_ref(lookup):
                continue
            for nm in _field_all_node_refs(f.type, lookup):
                if nm not in reach:
                    reach.add(nm)
                    work.append(nm)
    promote = {nm for nm in reach if not lookup[nm].packed}
    if not promote:
        return graph
    flat = flatten_graph_imports(graph)
    types = []
    for nt in flat.node_types:
        if isinstance(nt, Node) and nt.name in promote:
            nt = copy.copy(nt)
            nt.packed = True
        types.append(nt)
    return DataGraph(flat.name, node_types=types, root_type=flat.root_type,
                     header=getattr(flat, "header", None),
                     deletable=getattr(flat, "deletable", True))


def _node_drop_dedup_cache(node: Node, lookup: dict) -> bool:
    """True if this type's dedup-cache insert (``record_node_offset`` in its
    ``store_packed`` finish) is provably dead → safe to omit for extra speed.

    A packed child is serialized INLINE (``store_packed``) — never via the dedup
    ``.store`` path — *except* when routed through a union variant, a raw-embedded
    reference, or a non-packed parent, all of which use ``.store`` (and therefore
    read ``node_cache``). So we drop the insert only when, conservatively:
      * the type is pure-packed (``packed`` and not ``frozen``), AND
      * every reference to it anywhere in the schema is a PLAIN (non-union), non-raw
        single node-ref or array-of-node-ref whose owning node is also pure-packed.

    Any union-routed reference, ``raw`` reference, or non-pure-packed referrer keeps
    the cache. A wrong drop would double-store a SHARED node and diverge bytes from
    the other language backends — hence the conservative bar plus the full
    cross-language + packed/union-stress round-trip validation."""
    from dagr.dsl import raw as _RAW

    def _pure_packed(n) -> bool:
        return isinstance(n, Node) and getattr(n, "packed", False) and not getattr(n, "frozen", False)

    if not _pure_packed(node):
        return False
    target = node.name
    for P in lookup.values():
        if not isinstance(P, Node):
            continue
        for f in _node_fields(P):
            t = f.type
            plain_tgt = None
            if t.kind == "ref":
                plain_tgt = t.inner
            elif t.kind in ("array", "arrayWithOptionals") and t.inner.kind == "ref":
                plain_tgt = t.inner.inner
            if target not in _field_all_node_refs(t, lookup):
                continue  # this field doesn't reach the target at all
            # The field reaches the target. Safe (inline) only if it does so as a
            # plain direct ref/array (not via a union), non-raw, from a packed parent.
            if plain_tgt == target and (_RAW not in f.options) and _pure_packed(P):
                continue
            return False
    return True

def _node_fields(node: Node) -> list[Field]:
    """Return fields in index order."""
    return list(node.indexed_fields().values())


# ── Aligned array helpers ──────────────────────────────────────────────────────

_ELEM_BYTE_WIDTH = {
    "u8": 1, "i8": 1, "bool": 1,
    "u16": 2, "i16": 2, "f16": 2, "bf16": 2,
    "u32": 4, "i32": 4, "f32": 4,
    "u64": 8, "i64": 8, "f64": 8,
}

def _aligned_n(field: Field) -> "int | None":
    """Return the alignment value N if the field carries aligned(N), else None."""
    a = getattr(field, "alignment", None)
    return a.n if a is not None else None

def _elem_width(kind: str) -> int:
    """Return byte width of a fixed-width primitive kind."""
    return _ELEM_BYTE_WIDTH[kind]

def _node_max_alignment(node: Node) -> int:
    """Return the maximum alignment N across all aligned array fields in the node (1 if none)."""
    mx = 1
    for f in _node_fields(node):
        n = _aligned_n(f)
        if n:
            mx = max(mx, n)
    return mx


def _graph_max_alignment(root_node: Node, lookup: dict) -> int:
    """Max aligned-array N across every node reachable from root_node (1 if none).

    The serialized arena is one contiguous blob, so the leading alignment padding
    emitted in toData() must satisfy the strictest aligned array anywhere in the
    graph — not just the root node. A frozen child with align32 nested under an
    align16 parent still requires the whole buffer to be 32-aligned, otherwise its
    element base (and the UInt64 count header preceding it) lands misaligned.
    """
    def _refs_of_type(t: "EntryType") -> list:
        if t.kind == "ref":
            return [t.inner]
        if t.kind in ("array", "arrayWithOptionals") and t.inner.kind == "ref":
            return [t.inner.inner]
        return []

    seen: set[str] = set()
    stack: list[str] = [root_node.name]
    mx = 1
    while stack:
        name = stack.pop()
        if name in seen:
            continue
        seen.add(name)
        obj = lookup.get(name)
        if isinstance(obj, Node):
            mx = max(mx, _node_max_alignment(obj))
            for f in _node_fields(obj):
                stack.extend(_refs_of_type(f.type))
        elif isinstance(obj, UnionType):
            for _label, et in obj.types:
                stack.extend(_refs_of_type(et))
    return mx


# ── Enum node (prefab) associated values: codegen-time prefab → wire bytes ──────
#
# Phase B of "spec/03-enum-type.md": an enum case's associated value is a node prefab,
# returned as an immutable lazy view over a constant blob.  Targets without runtime
# blob providers (Odin/Mojo/Python) instead embed the prefab's wire bytes computed
# HERE via the pure-Python reflective serializer (byte-identical to Swift/Rust).

def _prefab_value_to_dagr(v, ftype, lookup):
    """Convert a schema `Value` (prefab/default) to the Python-native value the dagr/runtime
    `DagrNode` model expects (scalar→int/float/bool/str, data→bytes, enum→raw index,
    node-ref→nested `DagrNode`)."""
    from dagr.runtime.dagr_model import DagrNode
    k = v.kind
    if k in ("int", "float", "bool", "string"):
        return v.payload
    if k == "data":
        import base64
        return base64.b64decode(v.payload)
    if k == "ref":
        tgt = lookup.get(ftype.inner)
        if isinstance(tgt, Enum):
            for idx, name in tgt.cases.items():
                if name == v.payload:
                    return idx
            raise ValueError(f"enum case {v.payload!r} not in {ftype.inner}")
        if isinstance(tgt, Node):
            return _prefab_dagr_node(tgt, v.payload, lookup)   # nested prefab
    raise ValueError(f"enum node value: unsupported prefab field kind {k!r} "
                     f"(only scalar/enum/nested-node prefab fields are supported)")


def _prefab_dagr_node(node, prefab_name, lookup):
    from dagr.runtime.dagr_model import DagrNode
    prefab = node.prefabs[prefab_name]
    fields = {}
    for f in _node_fields(node):
        val = prefab.get(f.name, getattr(f, "default", None))
        if val is None:
            continue    # optional/absent
        fields[f.name] = _prefab_value_to_dagr(val, f.type, lookup)
    return DagrNode(node.name, fields)


def prefab_wire_bytes(graph, node_name: str, prefab_name: str) -> bytes:
    """Serialize a node's prefab to canonical framed wire bytes (for embedding as a
    const blob).  Uses a temp graph rooted at the prefab's node so the reflective
    serializer stores it as that type."""
    from dagr.runtime.dagr_serialize import serialize
    lookup = {t.name: t for t in graph.node_types}
    node = lookup[node_name]
    dn = _prefab_dagr_node(node, prefab_name, lookup)
    g2 = DataGraph(graph.name, root_type=EntryType("ref", node_name),
                   node_types=graph.node_types)
    return bytes(serialize(g2, dn))


# ── Cross-graph imports for targets without namespaces below the module ─────────

def flatten_graph_imports(graph):
    """`graph` with every (transitively) imported graph's types inlined into
    `node_types` and no `imports` — or `graph` itself when it imports nothing.

    For targets that do not model `ImportedGraph` as a namespace (Rust; Go has the
    SimpleNamespace twin in `dagr/codegen/go/graphs.py`): all data lives in one arena, so
    the importing graph's code must declare the imported types too. Imported types come
    first, in import order, then the graph's own; an own type shadows an imported one of
    the same name, as `DataGraph.lookup` does. The result is a real `DataGraph`, so every
    generator that takes one takes it unchanged."""
    if not getattr(graph, "imports", None):
        return graph
    merged: list = []
    index: dict = {}

    def add_types(g, seen):
        if id(g) in seen:
            return
        seen.add(id(g))
        for imp in getattr(g, "imports", None) or []:
            add_types(imp.graph, seen)
        for nt in g.node_types:
            if nt.name in index:
                merged[index[nt.name]] = nt          # nearer declaration shadows
            else:
                index[nt.name] = len(merged)
                merged.append(nt)

    add_types(graph, set())
    return DataGraph(graph.name, node_types=merged, root_type=graph.root_type,
                     header=getattr(graph, "header", None),
                     deletable=getattr(graph, "deletable", True))
