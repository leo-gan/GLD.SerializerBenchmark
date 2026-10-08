"""
Reserved identifier names per target language.

Two collision axes the identifier-*escaping* pass (keywords → backticks / `r#`)
cannot solve, because these are *semantic* clashes, not keyword clashes:

  1. A schema TYPE name (a Node/Enum/UnionType) equal to a fixed name the codegen
     already emits — e.g. the Swift path-query root `Query`, or a std type like Rust
     `Vec`.  Two declarations, one name, in one module → redeclaration.
  2. A schema FIELD name equal to a generated MEMBER — e.g. a field `description`
     vs the Swift `CustomStringConvertible.description` the codegen synthesises, or a
     field `store`/`restore` vs the serialiser methods.  The field accessor and the
     framework member fight for one slot; no escape resolves it.

Names the codegen *owns* are namespaced out of the way where possible (framework
types are `Dagr`-prefixed or graph/node-scoped; internal members are `__`-prefixed).
What remains — protocol requirements like `description`, public API methods, and a
handful of std types — is irreducible, so it is REJECTED at schema-validation time
with a clear, per-language message rather than emitted as broken code.

The check runs against ALL target languages by default, so a schema that validates
is portable: a field that is safe in Swift but clashes in TypeScript is still caught.
Keep these sets in sync with the generators; when a generator introduces a new fixed
public name, reserve it here.  This is intentionally curated (the actual generated
surface + the most dangerous std collisions), not an exhaustive stdlib dump.
"""

# Per language: names a schema TYPE (Node/Enum/UnionType) must not equal, names a
# schema FIELD must not equal, and TYPE-name prefixes reserved for framework types.
RESERVED = {
    "swift": {
        # Fixed framework types the codegen emits (graph/node-scoped or global).
        "types": frozenset({
            "Query", "DagrPath", "DagrNavPath", "DagrMultiPath", "ArenaBuilder",
            "PackedStoreResult", "BufferOffset", "NodeKey", "ArenaRestoreError",
            "Arena",
        }),
        # Generated members on a node handle / accessor that a field would shadow.
        "members": frozenset({
            "description",                       # CustomStringConvertible requirement
            "store", "storePacked", "restore", "delete",
            "hash", "hashValue",
        }),
        "type_prefixes": frozenset({"Dagr"}),
    },
    "rust": {
        "types": frozenset({
            "NodeRef", "DagrError", "DagrBuilder", "NodeStoreRef", "UnionArrSlot",
            # std / prelude types the generated code brings into scope.
            "Vec", "Option", "Result", "Box", "String", "Some", "None",
            # …plus the non-prelude std types the per-graph module imports
            # unqualified: `use std::cell::{Cell, RefCell}`, `use
            # std::collections::HashSet`, `use std::hash::Hash`.  A node/enum/union
            # named after one of these shadows the import and emits uncompilable
            # Rust (e.g. a `Cell` node made the generation counter `Cell<u32>`
            # resolve to the node instead of `std::cell::Cell`).
            "Cell", "RefCell", "HashSet", "Hash",
        }),
        # Rust node handles are method-based and largely shadow-tolerant; the arena
        # owns serialisation.  Reserve the few generated method names a field getter
        # could still clash with.
        "members": frozenset({
            "to_bytes", "from_bytes", "restore", "store",
        }),
        "type_prefixes": frozenset({"Dagr"}),
    },
    "typescript": {
        "types": frozenset({
            "Array", "Object", "String", "Number", "Boolean", "Map", "Set",
            "Uint8Array", "DataView", "ArrayBuffer",
        }),
        # Object.prototype members every generated class inherits.
        "members": frozenset({
            "toString", "valueOf", "constructor", "hasOwnProperty",
            "isPrototypeOf", "propertyIsEnumerable",
        }),
        "type_prefixes": frozenset(),
    },
    "go": {
        # Go (spec 37 §12): every schema name is PascalCased on export, so the clashes
        # are with the fixed generated surface. `Arena` is the per-graph arena type.
        "types": frozenset({"Arena"}),
        # Fixed methods on every arena handle (`String` = fmt.Stringer, the cycle-safe
        # `Equals`/`Hash`, generational `Delete`/`IsValid`/`Generation`/`Index`, and the
        # back-links `Arena`/`Handle`). A field spelled `string`, `is_valid` or `isValid`
        # would export to the same method name; Go has no way to escape that.
        "members": frozenset({
            "string", "hash", "equals", "delete",
            "is_valid", "isValid", "generation", "index", "arena", "handle",
            # every lazy accessor's node identity (spec/38 §2.6)
            "buffer_pos", "bufferPos", "buffer_bytes", "bufferBytes",
        }),
        "type_prefixes": frozenset(),
    },
    "cpp": {
        # C++ (spec/41 §12): the arena class of every graph. Every other generated type is
        # DERIVED from a schema name (`{N}Accessor`, `{U}View`, …) — `cpp_name_collisions`
        # checks those against each other.
        "types": frozenset({"Arena"}),
        # Members of every arena handle (`arena()`, `handle()`, the generational
        # `is_valid()` / `generation()` / `erase()`, the structural `equals` / `hash` /
        # `to_string` / `describe`, the private record `rec()`) and of every lazy accessor
        # (`buffer_pos()` / `buffer_bytes()`), as snake_case MEMBER names: a field maps to
        # its getter by `cpp_member`, so `toString` meets `to_string` too.
        "members": frozenset({
            "arena", "handle", "is_valid", "generation", "erase", "equals", "hash",
            "to_string", "describe", "rec", "buffer_pos", "buffer_bytes",
        }),
        "type_prefixes": frozenset(),
    },
    # Further per-language sets go here as targets grow their feature coverage.
}

#: Members of the generated union classes — the lazy `{U}View` / `{U}PackedView` (`tag()`,
#: the static `at()`), the arena's `{U}Value` (`tag()`, `origin()`) and `{U}View`
#: (`describe()`), the direct builder's union value (`visit()`). A union label maps to a
#: getter of its own name.
CPP_UNION_MEMBERS = frozenset({"tag", "at", "visit", "origin", "describe"})

#: Default set of languages a schema is checked against (portable-by-default).
ALL_TARGETS = tuple(RESERVED.keys())


def reserved_name_collisions(type_names, field_names, targets=ALL_TARGETS):
    """Return a list of human-readable collision messages.

    `type_names`  — iterable of schema Node/Enum/UnionType names.
    `field_names` — iterable of (owner_name, field_name) pairs.
    `targets`     — languages to check against (default: every supported language).

    Empty list means clean.  Each message names the language and the reserved slot
    so the author knows exactly what to rename and why.
    """
    msgs: list[str] = []
    tset = [t for t in targets if t in RESERVED]

    for lang in tset:
        R = RESERVED[lang]
        for tn in type_names:
            if tn in R["types"]:
                msgs.append(
                    f"[{lang}] type name {tn!r} collides with a generated "
                    f"framework type — rename the schema type")
            for pref in R["type_prefixes"]:
                if tn.startswith(pref):
                    msgs.append(
                        f"[{lang}] type name {tn!r} uses the reserved framework "
                        f"prefix {pref!r} — rename the schema type")
        for owner, fn in field_names:
            if fn in R["members"]:
                msgs.append(
                    f"[{lang}] field {owner}.{fn} collides with a generated member "
                    f"({fn!r}) — rename the field")
    return msgs


def rust_variant_collisions(node_types, record_types=()):
    """Messages for enum cases / union labels that map to the SAME Rust variant, or to one
    the codegen already emits.

    `_rust_variant` is a one-way transform (`low_power`, `LowPower` and `LOW_POWER` all
    become `LowPower`), so two distinct schema names can land on one Rust identifier —
    a duplicate variant, which does not compile. Every union also carries a generated
    `Unknown` variant, and a sink's `Record` enum an `Unknown` arm next to one variant per
    record type (`record_types`), so neither may produce `Unknown` itself. Bitset enums
    are constants, not variants, and are skipped.
    """
    from dagr.dsl import Enum, UnionType
    from dagr.codegen.shared import _rust_variant
    msgs: list[str] = []
    for nt in node_types:
        if isinstance(nt, Enum) and not nt.as_bitset:
            kind, names, reserved = "enum", list(nt.cases.values()), set()
        elif isinstance(nt, UnionType):
            kind, names, reserved = "union", [l for l, _ in nt.types], {"Unknown"}
        else:
            continue
        seen: dict[str, str] = {}
        for n in names:
            v = _rust_variant(n)
            if v in reserved:
                msgs.append(f"[rust] {kind} {nt.name}: {n!r} becomes the variant {v!r}, "
                            f"which the codegen already emits — rename it")
            elif v in seen:
                msgs.append(f"[rust] {kind} {nt.name}: {seen[v]!r} and {n!r} both become the "
                            f"variant {v!r} — rename one")
            seen.setdefault(v, n)
    for rt in record_types:
        if rt.name == "Unknown":
            msgs.append("[rust] record type 'Unknown' collides with the generated "
                        "`Record::Unknown` arm — rename it")
    return msgs


def cpp_name_collisions(node_types, header=None):
    """Messages for schema names that land on ONE C++ identifier where it matters.

    C++ maps names (`dagr/codegen/cpp/naming.py`): types keep PascalCase, fields become
    snake_case getters, enum cases and union labels PascalCase enumerators, a keyword or
    macro hazard gets a trailing `_`. So `fooBar` and `foo_bar`, or `class` and `class_`,
    are one member; and every node and union also DERIVES types (`{N}Accessor`,
    `{U}View`, …) that live beside the schema's own in code that names them unqualified —
    a node `PointAccessor` next to a node `Point` is two classes of one name. Rejected at
    validation time (spec/23 §6 — reject, never auto-rename), like Go's.

    Per node, the zero-argument members of the arena handle are checked: each field's
    getter, `clear_{f}` (optional fields), `{f}_view` (aligned numeric arrays) and the
    fixed members of `RESERVED["cpp"]`. A setter `set_{f}(v)` takes an argument and
    overloads a getter of the same name, so it is not a collision."""
    from dagr.dsl import Enum, Node, UnionType
    from dagr.codegen.cpp.naming import cpp_case, cpp_member, cpp_member_suffixed, cpp_part, cpp_type
    from dagr.codegen.shared import _aligned_n
    msgs: list[str] = []
    types: dict[str, str] = {"Arena": "the arena class"}

    def type_name(name: str, origin: str) -> None:
        prev = types.get(name)
        if prev is None:
            types[name] = origin
        elif prev != origin:
            msgs.append(f"[cpp] {prev} and {origin} both emit the type {name!r} — rename one")

    fixed = RESERVED["cpp"]["members"]
    # composed names (`new_{n}`, `{n}_store_`, `restore_{n}`, `sweep_{u}`, …) take the
    # unescaped stem of a name (`cpp_part`): `foo`, `_foo` and `foo_` share one
    stems: dict[tuple, str] = {}
    for nt in node_types:
        kind = "node" if isinstance(nt, Node) else "union" if isinstance(nt, UnionType) else None
        if kind is None:
            continue
        key = (kind, cpp_part(nt.name))
        if key in stems and stems[key] != nt.name:
            msgs.append(f"[cpp] {kind}s {stems[key]!r} and {nt.name!r} both compose names from {key[1]!r} — rename one")
        stems.setdefault(key, nt.name)
    nodes = [nt for nt in node_types if isinstance(nt, Node)]
    if header is not None:
        nodes.append(header)
    for nt in node_types:
        ty = cpp_type(nt.name)
        if isinstance(nt, Enum):
            type_name(ty, f"enum {nt.name}")
            seen: dict[str, str] = {}
            for case in nt.cases.values():
                c = cpp_case(case)
                if c in seen and seen[c] != case:
                    msgs.append(f"[cpp] enum {nt.name}: {seen[c]!r} and {case!r} both become {c!r} — rename one")
                seen.setdefault(c, case)
        elif isinstance(nt, UnionType):
            for suffix in ("", "Value", "View", "ArrayElem", "PackedView", "Tag"):
                type_name(ty + suffix, f"union {nt.name}")
            seen_case: dict[str, str] = {}
            seen_member: dict[str, str] = {}
            for label, _ in nt.types:
                c, m = cpp_case(label), cpp_member(label)
                if m in CPP_UNION_MEMBERS:
                    msgs.append(f"[cpp] union {nt.name}: label {label!r} becomes the member {m!r} the union "
                                f"classes already have — rename it")
                for seen, x, what in ((seen_case, c, "enumerator"), (seen_member, m, "member")):
                    if x in seen and seen[x] != label:
                        msgs.append(f"[cpp] union {nt.name}: {seen[x]!r} and {label!r} both become the {what} "
                                    f"{x!r} — rename one")
                    seen.setdefault(x, label)
    for nt in nodes:
        ty = cpp_type(nt.name)
        for suffix in ("", "Accessor") if nt is header else ("", "Accessor", "PackedAccessor"):
            type_name(ty + suffix, f"{'header' if nt is header else 'node'} {nt.name}")
    all_types = dict(types)
    for nt in nodes:
        ty = cpp_type(nt.name)
        members: dict[str, str] = {}

        def member(name: str, origin: str) -> None:
            if name in fixed:
                msgs.append(f"[cpp] {origin} of {nt.name} becomes {name!r}, a member every generated "
                            f"handle or accessor has — rename the field")
                return
            prev = members.get(name)
            if prev is None:
                members[name] = origin
            elif prev != origin:
                msgs.append(f"[cpp] node {nt.name}: {prev} and {origin} both emit the member {name!r} — rename one")

        field_stems: dict[str, str] = {}
        for f in nt.fields:
            m = cpp_member(f.name)
            origin = f"field {f.name!r}"
            member(m, origin)
            p = cpp_part(f.name)
            if p in field_stems and field_stems[p] != f.name:
                msgs.append(f"[cpp] node {nt.name}: fields {field_stems[p]!r} and {f.name!r} both get the setter "
                            f"'set_{p}' — rename one")
            field_stems.setdefault(p, f.name)
            if m in all_types:
                # inside the handle class the getter HIDES the type: `T T() const` and every
                # later use of `T` there name the function (only an all-lowercase type can
                # meet a snake_case member)
                msgs.append(f"[cpp] field {nt.name}.{f.name}: its getter {m!r} has the name of the "
                            f"type {all_types[m]} — rename one")
            if not f.options.is_required:
                member(f"clear_{p}", f"{origin} (its clear_)")
            if f.type.kind == "array" and _aligned_n(f) is not None:
                member(cpp_member_suffixed(f.name, "_view"), f"{origin} (its _view)")
    return msgs


def go_name_collisions(node_types):
    """Messages for two schema names that land on ONE top-level Go identifier.

    Go has no enum or union namespace, so a case or label is glued onto its type name
    (`ColorRed`, `ShapeCircle`), and every node and union also derives a fixed family of
    names (`{N}Accessor`, `{U}List`, …) in the same package. Two such names can coincide
    even when every schema name is distinct: a union `U` with a label `list` emits the
    constructor `UList` next to the union-array type `UList`; a label `a` next to a node
    `UA` emits `UA` twice. That is a redeclaration `go build` rejects, so it is rejected
    here, at validation time (spec/23 §6 — reject, never auto-rename).

    The table mirrors the generators (dagr/codegen/go): the names are the ones they emit
    and the conditions the ones they emit them under. Keep it in sync when a Go emitter
    gains a top-level name derived from a schema name. Only exported names are listed;
    the unexported ones (`store{N}`, `mat{U}`, …) are prefixed so they cannot meet a
    derived exported name.
    """
    from dagr.dsl import Enum, Node, UnionType
    from dagr.codegen.go.naming import go_enum_case, go_exported, go_label, go_type_name
    by_name = {nt.name: nt for nt in node_types}
    names: dict[str, str] = {}
    msgs: list[str] = []

    def emit(name: str, origin: str) -> None:
        prev = names.get(name)
        if prev is None:
            names[name] = origin
        elif prev != origin:
            msgs.append(f"[go] {prev} and {origin} both emit the identifier {name!r} — rename one")

    for nt in node_types:
        ty = go_type_name(nt.name)
        if isinstance(nt, Enum):
            emit(ty, f"enum {nt.name}")
            for case in nt.cases.values():
                emit(go_enum_case(nt.name, case), f"enum case {nt.name}.{case}")
        elif isinstance(nt, UnionType):
            for suffix in ("Tag", "List", "Value", "View", "PackedView", "PackedArrayView",
                           "PackedArrayIter", "ArrayElem", "ArrayView", "ArrayIter"):
                emit(ty + suffix, f"union {nt.name}")
            for view in ("View", "PackedView", "ArrayView", "PackedArrayView"):
                emit(f"New{ty}{view}", f"union {nt.name}")    # view constructors
            for label, vt in nt.types:
                L = go_label(label)
                origin = f"union label {nt.name}.{label}"
                emit(ty + L, origin)                         # constructor
                emit(f"{ty}Tag{L}", origin)                  # tag constant
                if vt.kind in ("array", "arrayWithOptionals"):
                    for view in ("View", "PackedView", "ArrayElem"):
                        emit(f"{ty}{view}{L}Iter", origin)   # variant-array cursors
                    # the bare `{U}{L}Iter` only for a plain array of nodes (core.py,
                    # `_pk_union_arr_variant`: `nra is not None and not awo`)
                    if (vt.kind == "array" and vt.inner.kind == "ref"
                            and isinstance(by_name.get(vt.inner.inner), Node)):
                        emit(f"{ty}{L}Iter", origin)
                elif vt.kind == "ref" and not isinstance(by_name.get(vt.inner), Enum):
                    emit(f"{ty}{L}Ref", origin)              # no-copy constructor
        elif isinstance(nt, Node):
            origin = f"node {nt.name}"
            for name in (ty, f"{ty}Accessor", f"New{ty}Accessor", f"Validate{ty}",
                         f"Restore{ty}", f"Put{ty}", f"{ty}Key"):
                emit(name, origin)
            for f in nt.fields:
                if f.type.kind in ("array", "arrayWithOptionals"):
                    emit(f"{ty}{go_exported(f.name)}Iter", f"field {nt.name}.{f.name}")
    return msgs


#: The fixed names each target's SharedBuffer overlay declares next to the schema's types
#: (the concurrency wrappers and the region helpers), found by generating every strategy.
#: A SharedBuffer type (node, enum or union) of one of these names does not compile there
#: — otlp-dagr's `MetricsRegion` named its root `Region` and broke the Rust crate.
SB_FIXED_TYPES = {
    "rust": frozenset({"Region", "Shared", "Snapshot", "Producer", "Consumer", "Ring"}),
    "swift": frozenset({"Region", "Shared", "Snapshot", "Producer", "Consumer", "Ring"}),
    "typescript": frozenset({"Shared", "Producer", "Consumer", "Ring"}),
    "mojo": frozenset({"Seqlock", "Ring", "Producer", "Consumer", "Claim"}),
    "odin": frozenset({"Seqlock", "Ring", "Producer", "Consumer", "Claim"}),
    "go": frozenset({"Seqlock", "Ring", "DoubleBuffer", "Producer", "Consumer", "Wrap",
                     "Allocate", "WriteDefaults", "SeqlockCreate", "SeqlockFromRaw",
                     "RingCreate", "RingFromRaw", "ProducerFromRaw", "ConsumerFromRaw"}),
}


#: Which SharedBuffer type kinds each target declares under their BARE name (probed by
#: generating the golden spike schema): only those can meet a fixed name. Go, for one,
#: emits a union as `{U}Tag` + accessors, so a union named `Wrap` is fine there.
SB_BARE_KINDS = {
    "rust": frozenset({"node", "enum", "union"}),
    "swift": frozenset({"node", "union"}),
    "typescript": frozenset({"node", "union"}),
    "mojo": frozenset({"node"}),
    "odin": frozenset({"node", "enum"}),
    "go": frozenset({"node", "enum"}),
}


def sb_type_collisions(node_types):
    """Messages for SharedBuffer types named like a fixed name some target's overlay
    emits (`SB_FIXED_TYPES`), where that target declares the type under its bare name
    (`SB_BARE_KINDS`) — rejected for every target, as the other name checks are, so a
    SharedBuffer that validates builds everywhere."""
    from dagr.dsl import Enum, UnionType
    msgs = []
    for nt in node_types:
        kind = "enum" if isinstance(nt, Enum) else "union" if isinstance(nt, UnionType) else "node"
        langs = sorted(lang for lang, names in SB_FIXED_TYPES.items()
                       if nt.name in names and kind in SB_BARE_KINDS[lang])
        if langs:
            msgs.append(f"[{', '.join(langs)}] SharedBuffer type {nt.name!r} collides with a "
                        f"name the overlay emits — rename it")
    return msgs
