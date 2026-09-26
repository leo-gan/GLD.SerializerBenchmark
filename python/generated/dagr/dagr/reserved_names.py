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
    # Further per-language sets go here as targets grow their feature coverage.
}

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
