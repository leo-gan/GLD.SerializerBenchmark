"""
Dagr Schema DSL — Python port of Sources/DagrCodeGen/DSLTypes.swift

Usage example (mirrors the Swift DSL closely):

    from dagr.dsl import t, F, required, deprecated, key, nil
    from dagr.dsl import int_val, float_val, bool_val, string_val, ref_val, b64_val, array_val, union_ref_val
    from dagr.dsl import Node, Enum, UnionType, DataGraph, ImportedGraph

    g1 = DataGraph("G1", root_type=t.bool, node_types=[
        Node("N1", fields=[
            "a" >> t.u8,
            "b" >> t.u16,
            "c" >> t.u32,
            "d" >> t.u64,
        ]),
    ])

    # With defaults
    g1d = DataGraph("G1D", root_type=t.bool, node_types=[
        Node("N1", fields=[
            "a" >> t.u8  >> int_val(11),
            "b" >> t.u16 >> int_val(11),
        ]),
    ])

    # With required + default
    g2d = DataGraph("G2D", root_type=t.bool, node_types=[
        Node("N1", fields=[
            "a" >> t.u8 >> required >> int_val(11),
        ]),
    ])

    # Enums
    g9 = DataGraph("G9", root_type=t.bool, node_types=[
        Node("N1", fields=[
            "e1" >> t.ref("E1"),
            "e2" >> t.ref("E2") >> ref_val("b"),  # with default
        ]),
        Enum("E1", ["a", "b"]),
        Enum("E2", ["a", "b"], capacity=4),
        Enum("E3", ["a"], as_bitset=True),
    ])

    # UnionType
    g15 = DataGraph("G15", root_type=t.bool, node_types=[
        Node("N1", fields=[
            "a" >> t.ref("U1"),
            "b" >> t.ref("U1") >> union_ref_val("s", string_val("max")),
        ]),
        UnionType("U1", types=[("s", t.utf8), ("i", t.i64)]),
    ])

    # Frozen / packed nodes + prefabs
    g17d = DataGraph("G17D", root_type=t.bool, node_types=[
        Node("N1", fields=[
            "a" >> t.ref("F1") >> ref_val("zero"),
            "b" >> t.ref("F1"),
        ]),
        Node("F1", fields=[
            "i1" >> t.i16,
            "i2" >> t.i64,
        ], frozen=True) >> {"zero": {"i1": int_val(0), "i2": int_val(0)}},
    ])

    # Arrays
    g25 = DataGraph("G25", root_type=t.bool, node_types=[
        Node("N1", fields=[
            "a" >> t.u16.array,
            "b" >> t.u16.array >> required >> array_val([int_val(11), int_val(21)]),
            "c" >> t.u16.array_with_optionals >> array_val([int_val(1), nil, int_val(3)]),
        ]),
    ])
"""

from __future__ import annotations
from typing import Optional, Union as TypingUnion


# ── DSL API version ─────────────────────────────────────────────────────────────
#
# A plain integer bumped ONLY on a *breaking* change to the DSL / config surface —
# a removed or renamed public symbol, or a changed constructor signature.  Additive
# changes (a new optional parameter, a new node kind, a new scalar type) do NOT bump
# it.  The tool itself is versioned by date (CalVer, e.g. "dagr 2026.9.0"), so the
# version string no longer signals API breaks the way a semver major would — this
# integer is the machine-checkable signal instead.  A schema module calls
# `require_dsl(min=N)` at its top to fail loudly on a tool too old to understand it,
# rather than dying with an obscure AttributeError/TypeError deep inside a build.
DSL_API_VERSION = 2


class IncompatibleDslVersion(Exception):
    """Raised by require_dsl() when the installed DSL API is outside the range a
    schema module declares it needs."""


def require_dsl(min: int | None = None, max: int | None = None) -> None:
    """Assert the installed Dagr DSL API (`DSL_API_VERSION`) satisfies this schema.

    Put `require_dsl(min=1)` at the top of a schema.py.  `min` guards against a tool
    too *old* (missing a DSL feature the schema relies on); `max` against one too
    *new* (a future breaking bump the schema hasn't been updated for).  Raises
    IncompatibleDslVersion with an actionable message on a mismatch."""
    if min is not None and DSL_API_VERSION < min:
        raise IncompatibleDslVersion(
            f"this schema needs Dagr DSL API >= {min}, but the installed tool provides "
            f"{DSL_API_VERSION}; upgrade dagr (e.g. `pip install -U dagr`).")
    if max is not None and DSL_API_VERSION > max:
        raise IncompatibleDslVersion(
            f"this schema needs Dagr DSL API <= {max}, but the installed tool provides "
            f"{DSL_API_VERSION}; pin an older dagr or update the schema to the new DSL.")


# ── Errors ────────────────────────────────────────────────────────────────────

class NodeIndexError(Exception):
    """Raised when a Node's field index assignments are invalid."""


class ValidationError(Exception):
    """Raised by DataGraph.validate() when the schema is structurally invalid."""


class GraphNameIsNotSet(ValidationError):
    pass

class RootTypeIsNotValidReference(ValidationError):
    pass

class DuplicateNodes(ValidationError):
    def __init__(self, names: list[str]):
        super().__init__(f"Duplicate node type names: {names}")
        self.names = names

class UnresolvedReferences(ValidationError):
    def __init__(self, names: list[str]):
        super().__init__(f"Unresolved type references: {names}")
        self.names = names

class FieldsWithInvalidOptions(ValidationError):
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(f"Node '{node_name}' has fields with invalid options: {field_names}")
        self.node_name = node_name
        self.field_names = field_names

class FieldsWithInvalidDefaults(ValidationError):
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(f"Node '{node_name}' has fields with invalid defaults: {field_names}")
        self.node_name = node_name
        self.field_names = field_names

class KeyFieldCannotHaveDefaultValue(ValidationError):
    def __init__(self, node_name: str, field_name: str):
        super().__init__(f"Node '{node_name}': key field '{field_name}' cannot have a default value")
        self.node_name = node_name
        self.field_name = field_name

class MissingPrefabFields(ValidationError):
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(f"Node '{node_name}' has missing required prefab fields: {field_names}")
        self.node_name = node_name
        self.field_names = field_names

class InvalidPrefabFields(ValidationError):
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(f"Node '{node_name}' has invalid prefab fields: {field_names}")
        self.node_name = node_name
        self.field_names = field_names

class NodeValidationError(ValidationError):
    def __init__(self, node_name: str, error: NodeIndexError):
        super().__init__(f"Node '{node_name}': {error}")
        self.node_name = node_name
        self.error = error

class CollidingFieldNames(ValidationError):
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(f"Node '{node_name}' has colliding field names: {field_names}")
        self.node_name = node_name
        self.field_names = field_names

class ReservedNameCollision(ValidationError):
    """A schema type or field name collides with a name the codegen already emits in
    some target language (a framework type like the Swift path-query `Query`, or a
    generated member like `description`).  Unlike a keyword collision — which the
    generators escape mechanically (backticks / `r#`) — this is a semantic clash that
    can only be resolved by renaming, so it is rejected at validation time.  See
    "spec/23-identifier-mapping.md" §6 and dagr/reserved_names.py."""
    def __init__(self, messages: list[str]):
        super().__init__(
            "Schema names collide with generated identifiers:\n  "
            + "\n  ".join(messages))
        self.messages = messages


class EnumOvercapacity(ValidationError):
    def __init__(self, enum_name: str):
        super().__init__(f"Enum '{enum_name}' exceeds its capacity")
        self.enum_name = enum_name

class EnumCollidingCaseNames(ValidationError):
    def __init__(self, enum_name: str, case_names: list[str]):
        super().__init__(f"Enum '{enum_name}' has colliding case names: {case_names}")
        self.enum_name = enum_name
        self.case_names = case_names

class UnionTypeOvercapacity(ValidationError):
    def __init__(self, union_type_name: str):
        super().__init__(f"UnionType '{union_type_name}' exceeds its capacity")
        self.union_type_name = union_type_name

class UnionTypeCollidingNames(ValidationError):
    def __init__(self, union_type_name: str, type_names: list[str]):
        super().__init__(f"UnionType '{union_type_name}' has colliding type names: {type_names}")
        self.union_type_name = union_type_name
        self.type_names = type_names


class EnumAssociatedValueError(ValidationError):
    def __init__(self, enum_name: str, detail: str):
        super().__init__(f"Enum '{enum_name}' associated values: {detail}")
        self.enum_name = enum_name
        self.detail = detail


class CompatibilityError(Exception):
    """Raised by DataGraph.check_compatibility_with() when a breaking schema change is detected."""


class DifferentRootTypes(CompatibilityError):
    pass

class RemovedField(CompatibilityError):
    def __init__(self, node_name: str, field_name: str):
        super().__init__(f"Node '{node_name}': field '{field_name}' was removed")
        self.node_name = node_name
        self.field_name = field_name

class ChangedFieldType(CompatibilityError):
    def __init__(self, node_name: str, field_name: str):
        super().__init__(f"Node '{node_name}': field '{field_name}' changed type")
        self.node_name = node_name
        self.field_name = field_name

class TypeWasChanged(CompatibilityError):
    def __init__(self, type_name: str, prev_type: str, current_type: str):
        super().__init__(f"Type '{type_name}' changed from {prev_type} to {current_type}")
        self.type_name = type_name
        self.prev_type = prev_type
        self.current_type = current_type

class TypePropertyWasChanged(CompatibilityError):
    def __init__(self, type_name: str, from_: str, to: str):
        super().__init__(f"Type '{type_name}' property changed from '{from_}' to '{to}'")
        self.type_name = type_name
        self.from_ = from_
        self.to = to

class IncompatibleFieldOptions(CompatibilityError):
    def __init__(self, node_name: str, field_name: str):
        super().__init__(f"Node '{node_name}': field '{field_name}' has incompatible options change")
        self.node_name = node_name
        self.field_name = field_name

class ChangedBitsetProperty(CompatibilityError):
    def __init__(self, enum_name: str):
        super().__init__(f"Enum '{enum_name}': as_bitset property changed")
        self.enum_name = enum_name

class ChangedDoublyLinked(CompatibilityError):
    """`doubly_linked` flipped on a DataSink — breaking in BOTH directions.

    The flag adds a reverse-delimited LEB carrying each record's own length at the
    record's END ("spec/11-data-sink.md" §11), and both readers are total: neither
    can detect that it is looking at the other's stream, so each one mis-parses
    silently rather than failing.

      * a doubly-linked reader on a plain stream steps `end + LebLength(len)` past
        every record and lands inside the next one;
      * a plain reader on a doubly-linked stream stops at `end` and reads the
        trailing RLEB as the next record's typeId.

    There is no compatible direction and no probe that distinguishes them, so this
    is a hard break either way — a new stream, not a new version of one."""
    def __init__(self, sink_name: str, added: bool):
        action = "gained" if added else "lost"
        super().__init__(
            f"DataSink '{sink_name}': {action} `doubly_linked` — every record's "
            f"framing changes (a reverse-delimited span at its end), and neither "
            f"reader can detect the other's stream, so both mis-parse silently"
        )
        self.sink_name = sink_name
        self.added = added

class ChangedCapacity(CompatibilityError):
    def __init__(self, name: str):
        super().__init__(f"'{name}': capacity changed")
        self.name = name

class ChangedCaseName(CompatibilityError):
    def __init__(self, enum_name: str, index: int, prev_case_name: str, current_case_name: Optional[str]):
        super().__init__(
            f"Enum '{enum_name}': case at index {index} renamed from '{prev_case_name}' to {current_case_name!r}"
        )
        self.enum_name = enum_name
        self.index = index
        self.prev_case_name = prev_case_name
        self.current_case_name = current_case_name

class ChangedUnionType(CompatibilityError):
    def __init__(self, union_type_name: str, index: int):
        super().__init__(f"UnionType '{union_type_name}': variant at index {index} changed type")
        self.union_type_name = union_type_name
        self.index = index

class RemovedTypeCase(CompatibilityError):
    def __init__(self, union_type_name: str, prev_count: int, current_count: int):
        super().__init__(
            f"UnionType '{union_type_name}': variants reduced from {prev_count} to {current_count}"
        )
        self.union_type_name = union_type_name
        self.prev_count = prev_count
        self.current_count = current_count

class NewFieldShouldNotBeRequired(CompatibilityError):
    def __init__(self, struct_name: str, field_name: str):
        super().__init__(
            f"Node '{struct_name}': new field '{field_name}' is required but has no default value"
        )
        self.struct_name = struct_name
        self.field_name = field_name

class FieldsWithInvalidAlignment(ValidationError):
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(f"Node '{node_name}' has fields with invalid alignment: {field_names}")
        self.node_name = node_name
        self.field_names = field_names

class FieldsWithInvalidRaw(ValidationError):
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(
            f"Node '{node_name}' has fields with invalid `raw`: {field_names}. "
            f"`raw` is valid on u16..u64/i16..i64/f32/f64 scalars and arrays (always "
            f"native width, never probed — 'spec/39-raw-fixed-width-fields.md') and on "
            f"node-reference fields (embedded graph leaf, 'spec/18-raw-embedded-graphs.md'). "
            f"u8/i8/bool are always raw already; f16/bf16, utf8, data, enum and union "
            f"fields have no fixed-width alternative."
        )
        self.node_name = node_name
        self.field_names = field_names

class FieldsWithInvalidTimestamp(ValidationError):
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(
            f"Node '{node_name}' has fields with invalid `timestamp(...)`: {field_names}. "
            f"`timestamp` is an advisory display annotation valid only on an integer "
            f"(u8..u64/i8..i64) or f64 scalar field, or an array of such (epoch offset)."
        )
        self.node_name = node_name
        self.field_names = field_names

class FieldsWithInvalidKey(ValidationError):
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(
            f"Node '{node_name}' has fields with invalid `key`: {field_names}. "
            f"`key` marks an immutable field identity (it synthesizes a hashable "
            f"{{Node}}Key and, on a node-ref, drives weak-entity cascade delete); it is "
            f"not valid on an array / arrayWithOptionals field — a mutable, variable-length "
            f"collection is not an identity. Use a scalar / utf8 / data / enum / node-ref key."
        )
        self.node_name = node_name
        self.field_names = field_names

class ChangedAlignment(CompatibilityError):
    def __init__(self, node_name: str, field_name: str):
        super().__init__(f"Node '{node_name}': field '{field_name}' changed alignment")
        self.node_name = node_name
        self.field_name = field_name

class ChangedRawFlag(CompatibilityError):
    """The `raw` field modifier flipped on a NODE-REF, where it switches
    inlined-packed <-> embedded-blob framing in packed contexts
    ("spec/18-raw-embedded-graphs.md" §8) — breaking in BOTH directions.
    NOT raised for any fixed-width shape (f32/f64 arrays' §5.2 mode bit, the
    spec/39 int arrays and int/float scalars): there the flip only changes which
    of two self-describing encodings the writer emits, every reader in every
    target dispatches on the wire bits, and re-encoded bytes differ without any
    buffer becoming unreadable ("spec/39-raw-fixed-width-fields.md" §2.4)."""
    def __init__(self, node_name: str, field_name: str, added: bool):
        action = "gained" if added else "lost"
        super().__init__(
            f"Node '{node_name}': field '{field_name}' {action} the `raw` modifier on a "
            f"node-ref — the embedding framing changes (inlined-packed <-> embedded blob), "
            f"breaking readers in both directions"
        )
        self.node_name = node_name
        self.field_name = field_name
        self.added = added

class ChangedRequiredFieldDefault(CompatibilityError):
    """A required field's default value changed.  Because a required field is
    read-synthesized from its default when absent — and is *elided* on write when
    it equals the default ("spec/14-defaults-and-prefabs.md" §4) — an old buffer that
    omitted the field (by elision, or because it predates the field) would
    silently synthesize the *new* default on read.  Silent data corruption, so
    it is breaking."""
    def __init__(self, node_name: str, field_name: str, prev_default, current_default):
        super().__init__(
            f"Node '{node_name}': required field '{field_name}' changed its default "
            f"from {prev_default!r} to {current_default!r} — old buffers that elided "
            f"it (or predate it) would silently synthesize the new value on read"
        )
        self.node_name = node_name
        self.field_name = field_name
        self.prev_default = prev_default
        self.current_default = current_default

class RequiredToOptionalLosesElidedDefault(CompatibilityError):
    """A required field with a default was relaxed to optional.  Such a field is
    elided on write when it equals its default (absent on the wire), and an
    optional reader restores absent -> nil rather than synthesizing the default
    ("spec/14-defaults-and-prefabs.md" §4) — so any elided value is silently lost."""
    def __init__(self, node_name: str, field_name: str):
        super().__init__(
            f"Node '{node_name}': required field '{field_name}' was relaxed to "
            f"optional while carrying a default — old buffers that elided it "
            f"(value == default) would restore to nil, silently losing the value"
        )
        self.node_name = node_name
        self.field_name = field_name

class AddedFieldToFrozenNode(CompatibilityError):
    """A field was added to a frozen node.  Frozen layouts are positional with no
    self-description ("spec/06-regular-nodes.md" §13, "spec/07-packed-nodes.md" §13): field
    slot positions and the presence-bitset width are pure schema arithmetic, so
    ANY field-set change moves bytes for readers of the other schema version —
    breaking in BOTH directions ("spec/14-defaults-and-prefabs.md" §9 records this as
    the spec's data-breaking case).  Not raised where the node is emitted
    tagged-packed regardless of its flags (header, sink records)."""
    def __init__(self, node_name: str, field_name: str):
        super().__init__(
            f"Node '{node_name}': field '{field_name}' was added to a frozen node — "
            f"frozen layouts are positional, so any added field is data-breaking "
            f"in both directions"
        )
        self.node_name = node_name
        self.field_name = field_name

class RequiredToOptionalBreaksOldReaders(CompatibilityError):
    """FORWARD break: a required field with no default was relaxed to optional.
    A new writer may legitimately omit the field (nil), but an old reader still
    treats it as required-without-default — absent is fail-loud (nothing to
    synthesize), so old readers reject valid new buffers.  (The default-carrying
    variant of the same relaxation is the BACKWARD hazard
    RequiredToOptionalLosesElidedDefault.)"""
    def __init__(self, node_name: str, field_name: str):
        super().__init__(
            f"Node '{node_name}': required field '{field_name}' was relaxed to "
            f"optional — new writers may omit it, but old readers treat it as "
            f"required-without-default and fail on its absence (forward break)"
        )
        self.node_name = node_name
        self.field_name = field_name

class AddedDefaultBreaksOldReaders(CompatibilityError):
    """FORWARD break: an existing required field gained a default value on an
    elision-capable field shape.  New writers elide the field when its value
    equals the default ("spec/14-defaults-and-prefabs.md" §4), but old readers — whose
    schema carries no default — cannot synthesize the absent field and fail on
    legitimately-written new buffers."""
    def __init__(self, node_name: str, field_name: str, new_default):
        super().__init__(
            f"Node '{node_name}': required field '{field_name}' gained default "
            f"{new_default!r} — new writers elide the field when it equals the "
            f"default, which old (default-less) readers cannot synthesize "
            f"(forward break)"
        )
        self.node_name = node_name
        self.field_name = field_name
        self.new_default = new_default

class RemovedSinkType(CompatibilityError):
    def __init__(self, sink_name: str, type_id: int, type_name: str):
        super().__init__(
            f"DataSink '{sink_name}': type '{type_name}' at typeId {type_id} was removed"
        )
        self.sink_name = sink_name
        self.type_id = type_id
        self.type_name = type_name

class HeaderPresenceChanged(CompatibilityError):
    """The framing word's header_bit flipped — adding or removing a header is
    breaking by design (see "spec/15-customizable-header.md" §11)."""
    def __init__(self, container_name: str, added: bool):
        action = "added" if added else "removed"
        super().__init__(
            f"'{container_name}': header was {action} — the framing word's "
            f"header_bit flips, so old buffers/readers are incompatible"
        )
        self.container_name = container_name
        self.added = added


# ── SharedBuffer validation errors ("spec/20-shared-buffer.md" §7) ───────────────────

class InvalidConcurrencyStrategy(ValidationError):
    def __init__(self, sb_name: str, strategy: str, allowed: list[str]):
        super().__init__(
            f"SharedBuffer '{sb_name}': concurrency={strategy!r} is not one of {allowed}"
        )
        self.sb_name = sb_name
        self.strategy = strategy

class SharedBufferRootNotFixedNode(ValidationError):
    def __init__(self, sb_name: str, root: str):
        super().__init__(
            f"SharedBuffer '{sb_name}': root_type {root!r} must reference a member "
            f"Node(frozen=True)"
        )
        self.sb_name = sb_name
        self.root = root

class InvalidSharedBufferConstant(ValidationError):
    """A `constants=` entry is not a valid identifier, clashes with a reserved
    module name, or has an unsupported value type."""
    def __init__(self, sb_name: str, detail: str):
        super().__init__(f"SharedBuffer '{sb_name}': invalid constant — {detail}")
        self.sb_name = sb_name


# Module-level names the SharedBuffer overlays already emit — a user constant may
# not shadow any of these.
_SB_RESERVED_CONST_NAMES = frozenset({
    "BYTE_SIZE", "REGION_ALIGN", "ROOT_OFFSET", "NODE_SIZE", "PAYLOAD_START",
})


class NonFrozenNodeInSharedBuffer(ValidationError):
    """§7 rule 0 — every member Node must be frozen and not packed."""
    def __init__(self, sb_name: str, node_name: str):
        super().__init__(
            f"SharedBuffer '{sb_name}': node '{node_name}' must be frozen=True and "
            f"not packed — a SharedBuffer is a fixed-layout struct tree"
        )
        self.sb_name = sb_name
        self.node_name = node_name

class NonFixedFieldInSharedBuffer(ValidationError):
    """§7 rule 1 — every field must be fixed-width."""
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(
            f"Node '{node_name}' has non-fixed-width fields in a SharedBuffer: "
            f"{field_names} (variable-length types need cap(N); refs must target a "
            f"frozen member Node)"
        )
        self.node_name = node_name
        self.field_names = field_names

class MissingCapacityInSharedBuffer(ValidationError):
    """§7 rule 3 — collection/string fields must declare cap(N)."""
    def __init__(self, node_name: str, field_names: list[str]):
        super().__init__(
            f"Node '{node_name}' has collection/string fields without cap(N): {field_names}"
        )
        self.node_name = node_name
        self.field_names = field_names

class NonFixedUnionVariant(ValidationError):
    """§5.5 — every variant of a union used in a SharedBuffer must be fixed-width."""
    def __init__(self, union_name: str, variant_names: list[str]):
        super().__init__(
            f"UnionType '{union_name}' used in a SharedBuffer has non-fixed-width "
            f"variants: {variant_names}"
        )
        self.union_name = union_name
        self.variant_names = variant_names

class RecursiveSharedBufferNode(ValidationError):
    """§7 rule 2 — the inline-reference graph over member nodes AND unions
    (both inlined by value) must be acyclic."""
    def __init__(self, sb_name: str, cycle: list[str]):
        super().__init__(
            f"SharedBuffer '{sb_name}': inlined reference cycle "
            f"{' -> '.join(cycle)} — recursion is unbounded size"
        )
        self.sb_name = sb_name
        self.cycle = cycle


# ── EntryType ─────────────────────────────────────────────────────────────────

class EntryType:
    """Represents a Dagr field type (scalar, reference, or array wrapper)."""

    def __init__(self, kind: str, inner=None):
        self._kind = kind
        self._inner = inner  # str for "ref", EntryType for "array"/"arrayWithOptionals"

    @property
    def array(self) -> EntryType:
        """Wrap this type in an array: t.u16.array => [u16]"""
        return EntryType("array", self)

    @property
    def array_with_optionals(self) -> EntryType:
        """Wrap this type in an array that allows nil elements."""
        return EntryType("arrayWithOptionals", self)

    # ── Field DSL entry point ──────────────────────────────────────────────
    def __rrshift__(self, name) -> Field:
        """Enable  "fieldName" >> t.u8  to produce a Field."""
        if isinstance(name, str):
            return Field(name, self)
        return NotImplemented

    # ── Introspection ──────────────────────────────────────────────────────
    @property
    def kind(self) -> str:
        return self._kind

    @property
    def inner(self):
        return self._inner

    @property
    def is_int_representable(self) -> bool:
        return self._kind in ("u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64")

    @property
    def is_float_representable(self) -> bool:
        return self._kind in ("f32", "f64", "f16", "bf16")

    @property
    def is_array(self) -> bool:
        return self._kind in ("array", "arrayWithOptionals")

    _PRIMITIVES = frozenset(
        ("u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64", "f32", "f64", "f16", "bf16", "bool", "utf8", "data")
    )

    def is_valid_reference(self, known_names) -> bool:
        if self._kind in self._PRIMITIVES:
            return True
        if self._kind == "ref":
            return self._inner in known_names
        if self._kind in ("array", "arrayWithOptionals"):
            return self._inner.is_valid_reference(known_names)
        return False

    @property
    def type_name(self) -> str:
        """Human-readable name used in error messages (e.g. '[MyNode]', '[[X]?]')."""
        if self._kind == "ref":
            return self._inner
        if self._kind == "array":
            return f"[{self._inner.type_name}]"
        if self._kind == "arrayWithOptionals":
            return f"[{self._inner.type_name}?]"
        return self._kind

    def structurally_same(self, other: EntryType) -> bool:
        """True when both types have the same shape (ignores ref names)."""
        if self._kind != other._kind:
            return False
        if self._kind in ("array", "arrayWithOptionals"):
            return self._inner.structurally_same(other._inner)
        return True  # for primitives and ref: shape matches

    def validate(self, lookup: dict, visited: set) -> None:
        """Recursively validate this type against a name→NodeType lookup.

        Raises a ValidationError subclass on the first problem found.
        Uses *visited* to short-circuit already-checked types (cycle safety).
        """
        if self in visited:
            return
        visited.add(self)

        if self._kind in self._PRIMITIVES:
            return

        if self._kind == "ref":
            name = self._inner
            node_type = lookup.get(name)
            if node_type is None:
                raise UnresolvedReferences([name])

            if isinstance(node_type, Node):
                bad_opts = sorted(node_type.fields_with_invalid_options)
                if bad_opts:
                    raise FieldsWithInvalidOptions(name, bad_opts)

                colliding = sorted(node_type.colliding_field_names)
                if colliding:
                    raise CollidingFieldNames(name, colliding)

                bad_defaults = sorted(node_type.fields_with_invalid_defaults(lookup))
                if bad_defaults:
                    raise FieldsWithInvalidDefaults(name, bad_defaults)

                missing = sorted(node_type.missing_prefab_fields)
                if missing:
                    raise MissingPrefabFields(name, missing)

                invalid_pf = sorted(node_type.invalid_prefab_fields(lookup))
                if invalid_pf:
                    raise InvalidPrefabFields(name, invalid_pf)

                bad_key = node_type.key_field_with_default_value
                if bad_key is not None:
                    raise KeyFieldCannotHaveDefaultValue(name, bad_key)

                bad_key_shape = sorted(node_type.fields_with_invalid_key)
                if bad_key_shape:
                    raise FieldsWithInvalidKey(name, bad_key_shape)

                bad_align = sorted(node_type.fields_with_invalid_alignment)
                if bad_align:
                    raise FieldsWithInvalidAlignment(name, bad_align)

                bad_raw = sorted(node_type.fields_with_invalid_raw(lookup))
                if bad_raw:
                    raise FieldsWithInvalidRaw(name, bad_raw)

                bad_ts = sorted(node_type.fields_with_invalid_timestamp)
                if bad_ts:
                    raise FieldsWithInvalidTimestamp(name, bad_ts)

                try:
                    indexed = node_type.indexed_fields()
                except NodeIndexError as e:
                    raise NodeValidationError(name, e) from e

                for field in indexed.values():
                    field.type.validate(lookup, visited)

            elif isinstance(node_type, Enum):
                if node_type.is_over_capacity:
                    raise EnumOvercapacity(name)
                colliding = sorted(node_type.colliding_case_names)
                if colliding:
                    raise EnumCollidingCaseNames(name, colliding)
                node_type.validate_associated(lookup)

            elif isinstance(node_type, UnionType):
                if node_type.is_over_capacity:
                    raise UnionTypeOvercapacity(name)
                colliding = sorted(node_type.colliding_type_names)
                if colliding:
                    raise UnionTypeCollidingNames(name, colliding)
                for _, variant_type in node_type.types:
                    variant_type.validate(lookup, visited)

        elif self._kind in ("array", "arrayWithOptionals"):
            self._inner.validate(lookup, visited)

    def compatible(
        self,
        prev: EntryType,
        self_lookup: dict,
        other_lookup: dict,
        visited: set,
        packed_ctx: bool = False,
    ) -> bool:
        """Return True if *self* is backward-compatible with *prev*.

        *packed_ctx*: this type is stored under a packed ancestor, so a node it
        reaches is packed whatever it declares (see `Node.compatible`).

        Raises a CompatibilityError subclass for breaking changes.
        """
        if not self.structurally_same(prev):
            return False

        if self._kind in self._PRIMITIVES:
            return True

        if self._kind == "ref":
            name = self._inner
            prev_name = prev._inner

            self_type = self_lookup.get(name)
            prev_type = other_lookup.get(prev_name)
            if self_type is None or prev_type is None:
                return False

            if type(self_type) is not type(prev_type):
                raise TypeWasChanged(
                    self_type.name,
                    type(prev_type).__name__,
                    type(self_type).__name__,
                )

            if isinstance(self_type, Node):
                self_type.compatible(prev_type, self_lookup, other_lookup, visited,
                                     packed_ctx=packed_ctx)

            elif isinstance(self_type, Enum):
                self_type.compatible(prev_type)

            elif isinstance(self_type, UnionType):
                self_type.compatible(prev_type, self_lookup, other_lookup, visited,
                                     packed_ctx=packed_ctx)

            return True

        if self._kind in ("array", "arrayWithOptionals"):
            return self._inner.compatible(prev._inner, self_lookup, other_lookup, visited,
                                          packed_ctx=packed_ctx)

        return False  # unreachable

    def __eq__(self, other) -> bool:
        return isinstance(other, EntryType) and self._kind == other._kind and self._inner == other._inner

    def __hash__(self) -> int:
        return hash((self._kind, str(self._inner)))

    def __repr__(self) -> str:
        if self._inner is None:
            return f"t.{self._kind}"
        if self._kind == "ref":
            return f"t.ref({self._inner!r})"
        return f"EntryType({self._kind!r}, {self._inner!r})"


class _Types:
    """Namespace for all built-in EntryType singletons and factory methods."""
    u8   = EntryType("u8")
    u16  = EntryType("u16")
    u32  = EntryType("u32")
    u64  = EntryType("u64")
    i8   = EntryType("i8")
    i16  = EntryType("i16")
    i32  = EntryType("i32")
    i64  = EntryType("i64")
    f32  = EntryType("f32")
    f64  = EntryType("f64")
    f16  = EntryType("f16")
    bf16 = EntryType("bf16")
    bool = EntryType("bool")
    utf8 = EntryType("utf8")
    data = EntryType("data")

    @staticmethod
    def ref(name: str) -> EntryType:
        """Reference to a named Node, Enum, or UnionType."""
        return EntryType("ref", name)


#: The global type namespace — use as  t.u8,  t.ref("MyNode"),  t.i32.array, etc.
t = _Types()


# ── Value ─────────────────────────────────────────────────────────────────────

class Value:
    """A literal value used as a field default or prefab field value."""

    def __init__(self, kind: str, payload=None):
        self._kind = kind
        self._payload = payload

    @property
    def kind(self) -> str:
        return self._kind

    @property
    def payload(self):
        return self._payload

    def __eq__(self, other) -> bool:
        return isinstance(other, Value) and self._kind == other._kind and self._payload == other._payload

    def __hash__(self) -> int:
        return hash((self._kind, str(self._payload)))

    def conforms_to_field_type(self, type_: EntryType, lookup: dict, allow_nil: bool = False) -> bool:
        """Return True if this Value is a legal default/prefab value for *type_*."""
        k = self._kind
        if k == "string":
            return type_ == EntryType("utf8")
        if k == "bool":
            return type_ == EntryType("bool")
        if k == "int":
            return type_.is_int_representable
        if k == "float":
            return type_.is_float_representable
        if k == "ref":
            if type_.kind != "ref":
                return False
            node_type = lookup.get(type_.inner)
            if node_type is None:
                return False
            if isinstance(node_type, Enum):
                return self._payload in node_type.cases.values()
            if isinstance(node_type, Node):
                return self._payload in node_type.prefabs
            return False
        if k == "unionRef":
            type_name, inner_value = self._payload
            if type_.kind != "ref":
                return False
            union_type = lookup.get(type_.inner)
            if not isinstance(union_type, UnionType):
                return False
            pair = next((tp for tp in union_type.types if tp[0] == type_name), None)
            if pair is None:
                return False
            return inner_value.conforms_to_field_type(pair[1], lookup)
        if k == "array":
            if type_.kind == "array":
                return all(v.conforms_to_field_type(type_.inner, lookup) for v in self._payload)
            if type_.kind == "arrayWithOptionals":
                return all(v.conforms_to_field_type(type_.inner, lookup, allow_nil=True) for v in self._payload)
            return False
        if k == "b64Data":
            return type_ == EntryType("data")
        if k == "nil":
            return allow_nil
        return False

    def __repr__(self) -> str:
        if self._kind == "nil":
            return "nil"
        return f"{self._kind}_val({self._payload!r})"


def int_val(n: int) -> Value:
    """Integer literal value."""
    return Value("int", n)

def float_val(f: float) -> Value:
    """Float literal value."""
    return Value("float", f)

def bool_val(b: bool) -> Value:
    """Boolean literal value."""
    return Value("bool", b)

def string_val(s: str) -> Value:
    """String literal value."""
    return Value("string", s)

def ref_val(name: str) -> Value:
    """Reference to an enum case name or node prefab name."""
    return Value("ref", name)

def b64_val(data: str) -> Value:
    """Base-64 encoded binary data value."""
    return Value("b64Data", data)

def array_val(values: list[Value]) -> Value:
    """Array literal value."""
    return Value("array", values)

def union_ref_val(type_name: str, value: Value) -> Value:
    """Union variant default: union_ref_val("s", string_val("hello"))"""
    return Value("unionRef", (type_name, value))

#: The nil / absent value.
nil = Value("nil")


# ── FieldOptions ──────────────────────────────────────────────────────────────

class FieldOptions:
    """Bitmask of field modifiers.  Combine with  |:  required | key"""

    _REQUIRED     = 1 << 0
    _DEPRECATED   = 1 << 1
    _KEY          = 1 << 2
    _RAW          = 1 << 3   # fixed-width fields: always native-LE, never probe (spec/39); node-ref: embedded blob (spec/18)
    _RAW_FLOATS   = _RAW     # pre-spec-39 name, kept as an alias
    _ALWAYS_STORE = 1 << 4   # opt out of write-side default elision: the field is always physically stored

    def __init__(self, raw: int = 0):
        self._raw = raw

    @property
    def raw(self) -> int:
        return self._raw

    def __contains__(self, other: FieldOptions) -> bool:
        return (self._raw & other._raw) == other._raw

    def __or__(self, other: FieldOptions) -> FieldOptions:
        return FieldOptions(self._raw | other._raw)

    @property
    def is_required(self) -> bool:
        return required in self or key in self

    @property
    def invalid(self) -> bool:
        """required+deprecated is allowed when the field carries a default value (validated in Node)."""
        return False

    def compatible(self, prev: FieldOptions) -> bool:
        """Return True if the *options-bit* change from *prev* to *self* is
        backward-compatible.

        The required -> optional relaxation is legal at the options-bit level, but
        it carries a data hazard when the previous field had a default: the value
        may have been elided on write and would restore to nil, not the default.
        That depends on the field's default, not its option bits, so it is
        enforced in Node.compatible (RequiredToOptionalLosesElidedDefault), not
        here.
        """
        # optional -> required is always breaking: an old buffer may have the
        # field absent (nil), which a required reader would synthesize to the
        # default — silently turning nil into a value (spec/14-defaults-and-prefabs.md
        # §4, the proto3 footgun).
        if required in self and required not in prev:
            return False
        if key in self and key not in prev:
            return False
        if key in prev and key not in self:
            return False
        if deprecated in prev and deprecated not in self:
            return False
        return True

    def __eq__(self, other) -> bool:
        return isinstance(other, FieldOptions) and self._raw == other._raw

    def __hash__(self) -> int:
        return hash(self._raw)

    def __repr__(self) -> str:
        parts = []
        if required in self:     parts.append("required")
        if deprecated in self:   parts.append("deprecated")
        if key in self:          parts.append("key")
        if raw in self:          parts.append("raw")
        if always_store in self: parts.append("always_store")
        return " | ".join(parts) if parts else "FieldOptions()"


#: Built-in FieldOptions singletons.
required   = FieldOptions(FieldOptions._REQUIRED)
deprecated = FieldOptions(FieldOptions._DEPRECATED)
key        = FieldOptions(FieldOptions._KEY)
#: `raw` = "always the fixed-width representation; never probe" ("spec/39-raw-fixed-width-fields.md").
#: On an f32/f64 array the count header becomes LEB((count<<2)|mode), mode 1 = native-LE elements
#: ("spec/04-storing-arrays.md" §5.2). On a u16..u64/i16..i64 array the writer always emits the
#: all-raw encoding tag 1 (§5.1) — O(1) random access guaranteed. On a u16..u64/i16..i64/f32/f64
#: scalar in a packed context the writer skips the LEB-vs-width probe / float compression chain
#: and always emits the odd (raw) tag or ebs bit with W native-LE bytes ("spec/07-packed-nodes.md"
#: §3). On a node-ref it marks an embedded graph leaf ("spec/18-raw-embedded-graphs.md"). Wire
#: unchanged in every case: readers dispatch on the wire bits. Default (unflagged) probes.
raw        = FieldOptions(FieldOptions._RAW)
#: `always_store` opts a required+default field OUT of write-side elision ("13 Defaults
#: and Prefabs.md" §4): the field's value is always physically written even when it
#: equals its default, instead of being dropped and synthesized on read. Use it to keep a
#: field forward-compatible for readers that lack read-side synthesis (or predate the
#: default) — notably to deprecate a required field that had no default: add a default +
#: `always_store` and old readers still see the value. `deprecated` on a required field
#: implies this automatically (see `_field_is_elidable`).
always_store = FieldOptions(FieldOptions._ALWAYS_STORE)
_no_opts   = FieldOptions(0)


# ── FieldAlignment ────────────────────────────────────────────────────────────

_VALID_ALIGNMENTS = frozenset({8, 16, 32, 64, 128, 256})
_ALIGNABLE_INNER_KINDS = frozenset({
    "u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64", "f32", "f64", "f16", "bf16"
})

#: Element / scalar kinds a packed writer probes (LEB-vs-width) and that `raw` can
#: therefore pin to the fixed width ("spec/39-raw-fixed-width-fields.md" §1). u8/i8/
#: bool are always raw; f16/bf16 have their own enc-bitset scheme; enums are D2.
_RAW_INT_KINDS    = frozenset({"u16", "u32", "u64", "i16", "i32", "i64"})
_RAW_SCALAR_KINDS = _RAW_INT_KINDS | frozenset({"f32", "f64"})

class FieldAlignment:
    """Carries the N value for aligned(N) — valid on primitive array fields and on
    utf8/data fields (which are treated as byte arrays)."""

    def __init__(self, n: int):
        self.n = n

    def __eq__(self, other) -> bool:
        return isinstance(other, FieldAlignment) and self.n == other.n

    def __hash__(self) -> int:
        return hash(self.n)

    def __repr__(self) -> str:
        return f"aligned({self.n})"


def aligned(n: int) -> FieldAlignment:
    """Mark an array field as memory-aligned to N bytes.  N must be in {2,4,8,16,32,64,128,256}."""
    if n not in _VALID_ALIGNMENTS:
        raise ValueError(f"aligned(N): N={n} is not in the valid set {sorted(_VALID_ALIGNMENTS)}")
    return FieldAlignment(n)


# ── FieldCapacity ─────────────────────────────────────────────────────────────

class FieldCapacity:
    """Carries the N value for cap(N) — the fixed reserved capacity of an array,
    arrayWithOptionals, utf8, or data field inside a SharedBuffer
    ("spec/20-shared-buffer.md" §5.3).  Makes an otherwise variable-length collection
    fixed-size: N element slots (or N reserved bytes) plus a length field."""

    def __init__(self, n: int):
        self.n = n

    def __eq__(self, other) -> bool:
        return isinstance(other, FieldCapacity) and self.n == other.n

    def __hash__(self) -> int:
        return hash(("cap", self.n))

    def __repr__(self) -> str:
        return f"cap({self.n})"


def cap(n: int) -> FieldCapacity:
    """Fixed reserved capacity for a collection/string field in a SharedBuffer.
    N must be >= 1."""
    if n < 1:
        raise ValueError(f"cap(N): N={n} must be >= 1")
    return FieldCapacity(n)


# ── FieldTimestamp ────────────────────────────────────────────────────────────

_VALID_TS_UNITS = ("s", "ms", "us", "ns")
_TS_ELIGIBLE_KINDS = frozenset({
    "u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64", "f64",
})

class FieldTimestamp:
    """Carries the `unit`/`epoch` for `timestamp(unit=...)`.

    An **advisory display annotation** marking an integer (or f64) scalar field —
    or an array of such — as an epoch timestamp. It has **no wire-format effect**:
    the value is stored exactly as its declared scalar type. Tools that render a
    buffer (today: the DataSink explorer) use it to show the raw number as a
    calendar instant and to offer date-based filtering. `unit` is one of
    s/ms/us/ns (offset from `epoch`, default the Unix epoch)."""

    def __init__(self, unit: str = "ms", epoch: str = "unix"):
        if unit not in _VALID_TS_UNITS:
            raise ValueError(
                f"timestamp(unit=…): unit={unit!r} is not in {list(_VALID_TS_UNITS)}")
        self.unit = unit
        self.epoch = epoch

    def __eq__(self, other) -> bool:
        return (isinstance(other, FieldTimestamp)
                and self.unit == other.unit and self.epoch == other.epoch)

    def __hash__(self) -> int:
        return hash(("ts", self.unit, self.epoch))

    def __repr__(self) -> str:
        if self.epoch == "unix":
            return f"timestamp(unit={self.unit!r})"
        return f"timestamp(unit={self.unit!r}, epoch={self.epoch!r})"


def timestamp(unit: str = "ms", epoch: str = "unix") -> FieldTimestamp:
    """Annotate an integer/f64 scalar field (or an array of such) as an epoch
    timestamp with the given `unit` (s/ms/us/ns). Advisory only — it does not
    change the bytes; tools like the DataSink explorer use it to render and
    filter the value as a date/time instead of a bare number."""
    return FieldTimestamp(unit, epoch)


# ── Field ─────────────────────────────────────────────────────────────────────

class Field:
    """A typed, named field in a Node schema.

    Created via the  >>  DSL:
        "name" >> t.u8                          # basic field
        "name" >> t.u8 >> required              # required field
        "name" >> t.u8 >> int_val(5)            # with default
        "name" >> t.u8 >> required >> int_val(5)
        "name" >> t.u8 >> 3                     # explicit index
    """

    def __init__(
        self,
        name: str,
        type: EntryType,
        options: FieldOptions = _no_opts,
        index: Optional[int] = None,
        default: Optional[Value] = None,
        alignment: Optional[FieldAlignment] = None,
        capacity: Optional[FieldCapacity] = None,
        timestamp: Optional[FieldTimestamp] = None,
    ):
        self.name = name
        self.type = type
        self.options = options
        self.index = index
        self.default = default
        self.alignment = alignment
        self.capacity = capacity
        self.timestamp = timestamp

    def __rshift__(self, other) -> Field:
        """Chain a modifier onto a Field."""
        if isinstance(other, FieldOptions):
            return Field(self.name, self.type, self.options | other, self.index, self.default, self.alignment, self.capacity, self.timestamp)
        if isinstance(other, Value):
            return Field(self.name, self.type, self.options, self.index, other, self.alignment, self.capacity, self.timestamp)
        if isinstance(other, int):
            return Field(self.name, self.type, self.options, other, self.default, self.alignment, self.capacity, self.timestamp)
        if isinstance(other, FieldAlignment):
            return Field(self.name, self.type, self.options, self.index, self.default, other, self.capacity, self.timestamp)
        if isinstance(other, FieldCapacity):
            return Field(self.name, self.type, self.options, self.index, self.default, self.alignment, other, self.timestamp)
        if isinstance(other, FieldTimestamp):
            return Field(self.name, self.type, self.options, self.index, self.default, self.alignment, self.capacity, other)
        return NotImplemented

    @property
    def is_raw_floats(self) -> bool:
        """`raw` on an f32/f64 array / arrayWithOptionals field → native-LE
        elements, no per-element compression tag (see 'spec/07-packed-nodes.md' §12)."""
        return (
            raw in self.options
            and self.type.kind in ("array", "arrayWithOptionals")
            and self.type.inner is not None
            and self.type.inner.kind in ("f32", "f64")
        )

    @property
    def is_raw_ints(self) -> bool:
        """`raw` on a u16..u64 / i16..i64 array / arrayWithOptionals field → the
        writer always emits the all-raw encoding tag 1 ('spec/04-storing-arrays.md'
        §5.1, 'spec/39-raw-fixed-width-fields.md'): W native-LE bytes per element,
        no per-element probe, no enc bitset, O(1) random access guaranteed."""
        return (
            raw in self.options
            and self.type.kind in ("array", "arrayWithOptionals")
            and self.type.inner is not None
            and self.type.inner.kind in _RAW_INT_KINDS
        )

    @property
    def is_raw_scalar(self) -> bool:
        """`raw` on a u16..u64 / i16..i64 / f32 / f64 scalar field → in a packed
        context the writer skips the LEB-vs-width probe (ints) or the compression
        chain (floats) and always emits the odd tag / encoding-bitset bit with W
        native-LE bytes ('spec/07-packed-nodes.md' §3, 'spec/39' §2). A no-op in
        regular / frozen (non-packed) nodes, which are fixed-width inline already."""
        return raw in self.options and self.type.kind in _RAW_SCALAR_KINDS

    @property
    def is_raw_fixed(self) -> bool:
        """Any of the three fixed-width `raw` shapes (what packed emitters ask)."""
        return self.is_raw_floats or self.is_raw_ints or self.is_raw_scalar

    def is_raw_embedded_ref(self, lookup: dict) -> bool:
        """`raw` on a node-reference field → embedded graph leaf, stored as an
        opaque standalone blob whenever the field is serialized through the packed
        path (see 'spec/18-raw-embedded-graphs.md'). Requires the ref target to be a
        Node (enum / union refs are rejected in validation)."""
        if raw not in self.options or self.type.kind != "ref":
            return False
        return isinstance(lookup.get(self.type.inner), Node)

    def __repr__(self) -> str:
        parts = [repr(self.name), repr(self.type)]
        if self.options != _no_opts:    parts.append(repr(self.options))
        if self.index is not None:      parts.append(f"index={self.index}")
        if self.default is not None:    parts.append(f"default={self.default!r}")
        if self.alignment is not None:  parts.append(f"alignment={self.alignment!r}")
        if self.capacity is not None:   parts.append(f"capacity={self.capacity!r}")
        if self.timestamp is not None:  parts.append(f"timestamp={self.timestamp!r}")
        return f"Field({', '.join(parts)})"


# ── Node ──────────────────────────────────────────────────────────────────────

class Node:
    """A struct-like schema type.

    Basic usage:
        Node("Name", fields=[...])
        Node("Name", fields=[...], frozen=True)
        Node("Name", fields=[...], packed=True)
        Node("Name", fields=[...], frozen=True, packed=True)

    Add prefabs with  >>:
        Node("Name", fields=[...]) >> {"prefabName": {"fieldName": int_val(0)}}
    """

    def __init__(
        self,
        name: str,
        fields: list[Field],
        frozen: bool = False,
        packed: bool = False,
        prefabs: Optional[dict[str, dict[str, Value]]] = None,
    ):
        self.name = name
        self.frozen = frozen
        self.packed = packed
        self.fields = fields
        self.prefabs: dict[str, dict[str, Value]] = prefabs or {}

    @property
    def is_node(self) -> bool:
        return True

    # ── Validation helpers ────────────────────────────────────────────────

    def indexed_fields(self) -> dict[int, Field]:
        """Return {index: Field}, assigning positional indices to un-indexed fields.

        Raises NodeIndexError on duplicate indices or gaps (for non-packed nodes).
        """
        result: dict[int, Field] = {}
        for pos, f in enumerate(self.fields):
            idx = f.index if f.index is not None else pos
            if idx in result:
                raise NodeIndexError(
                    f"Index {idx} is taken by fields '{result[idx].name}' and '{f.name}'"
                )
            result[idx] = f

        if not self.packed:
            prev = -1
            for idx in sorted(result.keys()):
                if idx == 0:
                    prev = 0
                    continue
                if idx - prev != 1:
                    raise NodeIndexError(
                        f"Unexpected step from index {prev} to {idx} "
                        f"(field '{result[idx].name}')"
                    )
                prev = idx

        return result

    @property
    def colliding_field_names(self) -> set[str]:
        seen: set[str] = set()
        colliding: set[str] = set()
        for f in self.fields:
            if f.name in seen:
                colliding.add(f.name)
            seen.add(f.name)
        return colliding

    @property
    def fields_with_invalid_options(self) -> set[str]:
        result: set[str] = set()
        for f in self.fields:
            if f.options.invalid:
                result.add(f.name)
            elif self.frozen and deprecated in f.options:
                result.add(f.name)
            elif deprecated in f.options and f.options.is_required and f.default is None:
                result.add(f.name)  # required+deprecated must have a default value
        return result

    def fields_with_invalid_defaults(self, lookup: dict) -> set[str]:
        result: set[str] = set()
        for f in self.fields:
            if f.default is None:
                continue
            allow_nil = (not f.options.is_required) or f.type.is_array
            if not f.default.conforms_to_field_type(f.type, lookup, allow_nil=allow_nil):
                result.add(f.name)
        return result

    @property
    def missing_prefab_fields(self) -> set[str]:
        result: set[str] = set()
        for prefab_name, prefab in self.prefabs.items():
            for f in self.fields:
                if f.options.is_required and f.default is None:
                    if f.name not in prefab:
                        result.add(f"{prefab_name}.{f.name}")
        return result

    def invalid_prefab_fields(self, lookup: dict) -> set[str]:
        result: set[str] = set()
        for prefab_name, prefab in self.prefabs.items():
            for field_name, value in prefab.items():
                f = next((x for x in self.fields if x.name == field_name), None)
                if f is None:
                    result.add(f"{prefab_name}.{field_name}")
                    continue
                allow_nil = (not f.options.is_required) or f.type.is_array
                if not value.conforms_to_field_type(f.type, lookup, allow_nil=allow_nil):
                    result.add(f"{prefab_name}.{field_name}")
        return result

    @property
    def key_field_with_default_value(self) -> Optional[str]:
        for f in self.fields:
            if key in f.options and f.default is not None:
                return f.name
        return None

    @property
    def fields_with_invalid_key(self) -> set[str]:
        """`key` marks an immutable field identity: it synthesizes a hashable
        `{Node}Key` and, on a node-ref, declares an identifying relationship that
        drives weak-entity cascade delete ('spec/09-deletion-of-nodes.md'). An array /
        arrayWithOptionals field is not a valid identity — it is a mutable,
        variable-length collection, and neither the key struct nor the cascade
        logic models a collection — so `key` on an array field is rejected."""
        result: set[str] = set()
        for f in self.fields:
            if key not in f.options:
                continue
            if f.type.kind in ("array", "arrayWithOptionals"):
                result.add(f.name)
        return result

    @property
    def fields_with_invalid_alignment(self) -> set[str]:
        result: set[str] = set()
        for f in self.fields:
            if f.alignment is None:
                continue
            k = f.type.kind
            if k in ("utf8", "data"):
                continue  # string / byte buffers are byte arrays — alignable (W=1)
            if k != "array":
                result.add(f.name)
            elif f.type.inner.kind not in _ALIGNABLE_INNER_KINDS:
                result.add(f.name)
        return result

    def fields_with_invalid_raw(self, lookup: dict) -> set[str]:
        """`raw` is valid only on (a) f32/f64 array / arrayWithOptionals fields,
        (b) u16..u64 / i16..i64 array / arrayWithOptionals fields, (c) u16..u64 /
        i16..i64 / f32 / f64 scalar fields ('spec/39-raw-fixed-width-fields.md'),
        or (d) node-reference fields (embedded graph leaf, 'spec/18'). Anything
        else carrying `raw` — u8/i8/bool (always raw already), f16/bf16, utf8,
        data, enum/union refs and arrays of those — is invalid (spec/39 §12 D1)."""
        result: set[str] = set()
        for f in self.fields:
            if raw not in f.options:
                continue
            if f.is_raw_fixed:
                continue
            if f.type.kind == "ref":
                # ref → must resolve to a Node; enum / union refs are invalid.
                if not f.is_raw_embedded_ref(lookup):
                    result.add(f.name)
                continue
            result.add(f.name)
        return result

    @property
    def fields_with_invalid_timestamp(self) -> set[str]:
        """`timestamp(...)` is an advisory display annotation valid only on an
        integer/f64 scalar field, or an array (or arrayWithOptionals) whose
        element is such a scalar. Anything else — a string, bytes, bool, ref,
        or f16/bf16/f32 scalar — is invalid."""
        result: set[str] = set()
        for f in self.fields:
            if f.timestamp is None:
                continue
            k = f.type.kind
            if k in _TS_ELIGIBLE_KINDS:
                continue
            if (k in ("array", "arrayWithOptionals")
                    and f.type.inner is not None
                    and f.type.inner.kind in _TS_ELIGIBLE_KINDS):
                continue
            result.add(f.name)
        return result

    # ── Compatibility ─────────────────────────────────────────────────────

    def compatible(
        self,
        prev: "Node",
        self_lookup: dict,
        other_lookup: dict,
        visited: set,
        always_packed: bool = False,
        packed_ctx: bool = False,
    ) -> None:
        """Raise CompatibilityError if *self* is not wire-compatible with *prev*,
        in BOTH directions — backward (a *self* reader reads a *prev* buffer) and
        forward (a *prev* reader reads a *self* buffer).  The forward rules are
        format-aware, not an argument swap: vtable and tagged-packed layouts
        tolerate unknown fields (old readers skip them), while frozen layouts are
        positional and reject any field addition ("spec/17-generation-receipts.md" §2).

        Field identity is the field **index** (explicit or positional), not the
        name — renaming a field at the same index is wire-compatible.  Extracted
        from EntryType.compatible so headers and DataSink record types can reuse
        the same node-to-node comparison.

        *always_packed* marks contexts where the node is emitted with the
        tagged-packed serialiser regardless of its own frozen/packed flags — the
        header ("spec/15-customizable-header.md" §5) and DataSink records ("10 Data
        Sink.md" §2).  It skips the flag-equality check (flags are wire-irrelevant
        there) and the frozen positional rules (the wire is tagged, hence
        evolvable), and no write-side elision is generated in those contexts.

        *packed_ctx* marks a node reached under a packed ancestor. Packed
        propagates downward ("spec/16-choosing-a-node-layout.md" §3), so the
        layout compared is the EFFECTIVE one: a node declared regular there is
        stored packed, and flipping its own `packed` flag changes no byte. The
        context passes to the children, except across a `raw` ref, whose leaf
        keeps its own format ("spec/18-raw-embedded-graphs.md").
        """
        if not always_packed:
            if self.frozen != prev.frozen:
                raise TypePropertyWasChanged(
                    self.name,
                    "frozen" if prev.frozen else "notFrozen",
                    "frozen" if self.frozen else "notFrozen",
                )
            self_packed, prev_packed = self.packed or packed_ctx, prev.packed or packed_ctx
            if self_packed != prev_packed:
                raise TypePropertyWasChanged(
                    self.name,
                    "packed" if prev_packed else "notPacked",
                    "packed" if self_packed else "notPacked",
                )
        # Children of a node stored packed are packed too — header and sink records
        # (always_packed) included.
        child_ctx = always_packed or packed_ctx or self.packed

        prev_indexed = prev.indexed_fields()
        self_indexed = self.indexed_fields()

        for idx, prev_field in prev_indexed.items():
            cur_field = self_indexed.get(idx)
            if cur_field is None:
                raise RemovedField(self.name, prev_field.name)

            field_ctx = child_ctx and not cur_field.is_raw_embedded_ref(self_lookup)
            # A node can be reached both regularly and under a packed ancestor, and
            # the two are different layouts — so the context is part of the key.
            field_path = f"{self.name}::{cur_field.name}" + ("|packed" if field_ctx else "")
            if field_path in visited:
                continue
            visited.add(field_path)

            if not cur_field.type.compatible(
                prev_field.type, self_lookup, other_lookup, visited, packed_ctx=field_ctx
            ):
                raise ChangedFieldType(self.name, prev_field.name)

            if not cur_field.options.compatible(prev_field.options):
                raise IncompatibleFieldOptions(self.name, prev_field.name)

            # required -> optional silently loses elided values: a required field
            # with a default is elided on write when it equals the default (absent
            # on the wire), and an optional reader restores absent -> nil rather
            # than synthesizing the default (spec/14-defaults-and-prefabs.md §4).  The
            # hazard hinges on the *previous* field's default (it governed
            # elision); a required field that had no default was never elided, so
            # relaxing it to optional is safe.
            if (required in prev_field.options and required not in cur_field.options
                    and prev_field.default is not None):
                raise RequiredToOptionalLosesElidedDefault(self.name, cur_field.name)

            # FORWARD: the no-default variant of the same relaxation.  A new
            # writer may omit the now-optional field (nil), but an old reader
            # treats it as required-without-default — absent is fail-loud, so
            # old readers reject legitimately-written new buffers.  Together
            # with the rule above, required -> optional is breaking either way.
            if (required in prev_field.options and required not in cur_field.options
                    and prev_field.default is None):
                raise RequiredToOptionalBreaksOldReaders(self.name, cur_field.name)

            if cur_field.alignment != prev_field.alignment:
                raise ChangedAlignment(self.name, cur_field.name)

            # A `raw` flip changes the wire in both directions ONLY on node-refs
            # (inlined-packed <-> embedded-blob framing, "spec/18" §8) —
            # unconditional there: packed contexts (sink records, packed parents)
            # are exactly where the framing lives.  Every fixed-width shape (f32/
            # f64 arrays' §5.2 mode bit, and the spec/39 int arrays and int/float
            # scalars) is self-describing on the wire and every reader in every
            # target dispatches on it (Swift's eager float restore was the last
            # schema-driven one, fixed under spec/39 §12 D4), so a flip changes
            # re-encoded bytes but never readability (spec/39 §2.4).
            if (raw in cur_field.options) != (raw in prev_field.options):
                if cur_field.type.kind == "ref" or prev_field.type.kind == "ref":
                    raise ChangedRawFlag(
                        self.name, cur_field.name, added=raw in cur_field.options
                    )

            # Required fields synthesize their default on absence and are elided
            # when equal to it (spec/14-defaults-and-prefabs.md §4), so changing or
            # removing the default silently rewrites old, field-absent buffers.
            # The hazard requires that the *previous* version had a default (only
            # then could an old buffer have elided/omitted the field); adding a
            # default to a previously-defaultless required field is backward-safe
            # (those buffers always wrote it) but has its own FORWARD hazard,
            # checked below.  Optional fields restore absent → nil (default not
            # synthesized, §4 table), so this is required-only.
            if (cur_field.options.is_required and prev_field.options.is_required
                    and prev_field.default is not None
                    and cur_field.default != prev_field.default):
                raise ChangedRequiredFieldDefault(
                    self.name, cur_field.name, prev_field.default, cur_field.default
                )

            # FORWARD: ADDING a default to an existing required field.  New
            # writers elide the field when its value equals the default (§4),
            # but an old reader — whose schema carries no default — cannot
            # synthesize the absent field.  Scoped to the shapes writers
            # actually elide (value semantics only; node-refs never elided) and
            # to contexts that elide at all: frozen nodes write positionally
            # (no elision — _field_is_elidable is false there) and always_packed
            # contexts (header, sink records) generate no write-side elision.
            if (not always_packed
                    and cur_field.options.is_required and prev_field.options.is_required
                    and prev_field.default is None and cur_field.default is not None
                    and _field_is_elidable(cur_field, self, self_lookup)):
                raise AddedDefaultBreaksOldReaders(
                    self.name, cur_field.name, cur_field.default
                )

            # A node-ref default names a *prefab*; the comparison above only sees
            # the prefab name (the Value), so a same-named prefab whose CONTENT
            # changed slips through.  An absent required node-ref materializes its
            # prefab on read (spec/14-defaults-and-prefabs.md §4, Tier-2), so changed
            # prefab content is the same silent-synthesis hazard, one indirection
            # deeper.  (Left un-scoped by node kind: conservative — a plain-frozen
            # parent can't actually synthesize, but over-flagging is the safe
            # direction for a silent-corruption check.)
            if (cur_field.options.is_required and prev_field.options.is_required
                    and cur_field.default is not None
                    and cur_field.default.kind == "ref"
                    and cur_field.type.kind == "ref"
                    and cur_field.default == prev_field.default):  # same prefab name
                cur_target = self_lookup.get(cur_field.type.inner)
                prev_target = other_lookup.get(prev_field.type.inner)
                if isinstance(cur_target, Node) and isinstance(prev_target, Node):
                    pname = cur_field.default.payload
                    if cur_target.prefabs.get(pname) != prev_target.prefabs.get(pname):
                        raise ChangedRequiredFieldDefault(
                            self.name, cur_field.name,
                            f"prefab {pname!r}={prev_target.prefabs.get(pname)!r}",
                            f"prefab {pname!r}={cur_target.prefabs.get(pname)!r}",
                        )

        for idx, field in self_indexed.items():
            if idx not in prev_indexed:
                # Frozen layouts are positional (no vtable, no tags): slot
                # positions and the presence-bitset width are pure schema
                # arithmetic, so ANY added field moves bytes for readers of the
                # other schema version — breaking in BOTH directions ("13
                # Defaults and Prefabs.md" §9).  Skipped in always_packed
                # contexts, where the wire is tagged-packed and thus evolvable.
                if self.frozen and not always_packed:
                    raise AddedFieldToFrozenNode(self.name, field.name)
                if required in field.options and field.default is None:
                    raise NewFieldShouldNotBeRequired(self.name, field.name)

    def __rshift__(self, prefabs: dict[str, dict[str, Value]]) -> Node:
        """Attach prefabs:  node >> {"zero": {"x": int_val(0)}}"""
        return Node(self.name, self.fields, self.frozen, self.packed, prefabs)

    def __repr__(self) -> str:
        parts = [repr(self.name), f"fields={self.fields!r}"]
        if self.frozen:  parts.append("frozen=True")
        if self.packed:  parts.append("packed=True")
        if self.prefabs: parts.append(f"prefabs={self.prefabs!r}")
        return f"Node({', '.join(parts)})"


# ── Enum ──────────────────────────────────────────────────────────────────────

def _enum_auto_capacity(cases: dict[int, str], as_bitset: bool) -> int:
    n = len(cases)
    if as_bitset:
        if n <= 1:  return 1
        if n <= 2:  return 2
        if n <= 4:  return 4
        if n <= 8:  return 8
        if n <= 16: return 16
        if n <= 32: return 32
        return 64
    if n <= 2:   return 2
    if n <= 4:   return 4
    if n <= 16:  return 16
    if n <= 255: return 255
    return 65535


class Enum:
    """An enum schema type.

    Pass cases as a list (auto-indexed from 0) or as a dict {index: name}:
        Enum("Color", ["red", "green", "blue"])
        Enum("Color", {0: "red", 1: "green"}, capacity=16)
        Enum("Flags", ["read", "write", "exec"], as_bitset=True)

    Associated values ("spec/03-enum-type.md") attach a compile-time constant to each
    case, aligned to case order.  The value never touches the wire (the stored
    code is still the case index); it is projected through a read-only accessor:
        Enum("HttpStatus", ["ok", "notFound", "teapot"], values=[200, 404, 418])
    A node (prefab) value type is given with `value_type=t.ref("Node")`, and the
    `values` then name prefabs defined on that node (Phase B):
        Enum("Planet", ["mercury", "earth"], value_type=t.ref("PlanetInfo"),
             values=["mercuryInfo", "earthInfo"])
    """

    def __init__(
        self,
        name: str,
        cases: TypingUnion[list[str], dict[int, str]],
        capacity: Optional[int] = None,
        as_bitset: bool = False,
        values: Optional[list] = None,
        value_type=None,
    ):
        self.name = name
        self.as_bitset = as_bitset
        # Cases are kept in CODE order whatever order the author wrote them in: every
        # generator iterates `cases`, and a receipt stores them as a JSON object with
        # string keys, which reads back in string order ("10" before "2"). Unsorted, a
        # rebuild from the receipt emitted an enum of 11+ cases in a different order than
        # the schema build did — same meaning, different bytes, a false receipt drift
        # (`SeverityNumber`, 25 cases, spec/38 §2.5).
        self.cases: dict[int, str] = (
            {i: v for i, v in enumerate(cases)} if isinstance(cases, list)
            else dict(sorted(dict(cases).items()))
        )
        self.capacity: int = capacity if capacity is not None else _enum_auto_capacity(self.cases, as_bitset)
        # Associated values: one constant per case in case order, or None for a
        # plain enum.  Shape (uniform type, dense cases, not bitset) is checked at
        # graph-validate time via validate_associated().  `value_type` pins the
        # value type: None => scalar (inferred); t.ref("Node") => node (prefab)
        # values, where each `values` entry names a prefab on that node.
        self.values: Optional[list] = list(values) if values is not None else None
        self.value_type = value_type

    @property
    def is_node(self) -> bool:
        return False

    # ── Validation helpers ────────────────────────────────────────────────

    @property
    def colliding_case_names(self) -> set[str]:
        seen: set[str] = set()
        colliding: set[str] = set()
        for name in self.cases.values():
            if name in seen:
                colliding.add(name)
            seen.add(name)
        return colliding

    @property
    def is_over_capacity(self) -> bool:
        max_key = max(self.cases.keys()) if self.cases else 0
        return max_key >= self.capacity

    # ── Associated values ─────────────────────────────────────────────────
    @property
    def has_values(self) -> bool:
        return self.values is not None

    @property
    def is_node_valued(self) -> bool:
        """True when the associated value type is a node ref (Phase B) — the
        `values` name prefabs on that node, projected as an immutable lazy view."""
        return (self.values is not None and self.value_type is not None
                and getattr(self.value_type, "kind", None) == "ref")

    @property
    def has_scalar_values(self) -> bool:
        """Scalar/string associated values (Phase A) — excludes node-valued enums."""
        return self.values is not None and not self.is_node_valued

    @property
    def is_exhaustive(self) -> bool:
        """cases fill capacity → no `unknown` case → a total (non-throwing) `.value`."""
        return len(self.cases) == self.capacity

    @property
    def value_py_type(self) -> type:
        """Python type of the associated values (assumes validated uniform)."""
        v0 = self.values[0]
        if isinstance(v0, bool): return bool    # bool before int (bool ⊂ int)
        if isinstance(v0, int):  return int
        if isinstance(v0, float): return float
        if isinstance(v0, str):  return str
        return type(v0)

    def validate_associated(self, lookup=None) -> None:
        """Raise EnumAssociatedValueError if the associated-value declaration is
        malformed.  Called from DataGraph.validate for enums that carry values.
        *lookup* (name -> type) is required to validate node (prefab) values."""
        if self.values is None:
            return
        if self.as_bitset:
            raise EnumAssociatedValueError(
                self.name, "bitset enums cannot carry associated values")
        if len(self.values) != len(self.cases):
            raise EnumAssociatedValueError(
                self.name, f"{len(self.values)} values for {len(self.cases)} cases")
        if sorted(self.cases.keys()) != list(range(len(self.cases))):
            raise EnumAssociatedValueError(
                self.name, "associated-value enums require dense cases 0..n-1")
        if self.is_node_valued:
            # Node (prefab) values: every entry names a prefab defined on the
            # single target node (`value_type`).  Returned as an immutable lazy view.
            node_name = self.value_type.inner
            node = lookup.get(node_name) if lookup is not None else None
            if not isinstance(node, Node):
                raise EnumAssociatedValueError(
                    self.name, f"value_type ref {node_name!r} is not a Node")
            for v in self.values:
                if not isinstance(v, str):
                    raise EnumAssociatedValueError(
                        self.name, f"node value must be a prefab name (str), got {type(v).__name__}")
                if v not in getattr(node, "prefabs", {}):
                    raise EnumAssociatedValueError(
                        self.name, f"prefab {v!r} not defined on node {node_name!r}")
            return
        types = sorted({type(v).__name__ for v in self.values})
        if len(types) != 1:
            raise EnumAssociatedValueError(
                self.name, f"all values must share one type, got {types}")
        if self.value_py_type not in (bool, int, float, str):
            raise EnumAssociatedValueError(
                self.name, f"unsupported value type {self.value_py_type.__name__}")

    def compatible(self, prev: Enum) -> None:
        """Raise CompatibilityError if *self* is not backward-compatible with *prev*."""
        if self.as_bitset != prev.as_bitset:
            raise ChangedBitsetProperty(self.name)
        if self.capacity != prev.capacity:
            raise ChangedCapacity(self.name)
        for idx, prev_case in prev.cases.items():
            current_case = self.cases.get(idx)
            if current_case != prev_case:
                raise ChangedCaseName(self.name, idx, prev_case, current_case)

    def __repr__(self) -> str:
        parts = [repr(self.name), repr(list(self.cases.values()))]
        if self.capacity != _enum_auto_capacity(self.cases, self.as_bitset):
            parts.append(f"capacity={self.capacity}")
        if self.as_bitset:
            parts.append("as_bitset=True")
        if self.values is not None:
            parts.append(f"values={self.values!r}")
        return f"Enum({', '.join(parts)})"


# ── UnionType ─────────────────────────────────────────────────────────────────

def _union_auto_capacity(n: int) -> int:
    if n <= 2:   return 2
    if n <= 4:   return 4
    if n <= 16:  return 16
    if n <= 255: return 255
    return 65535


class UnionType:
    """A tagged-union schema type.

        UnionType("Result", types=[("ok", t.utf8), ("err", t.i32)])
        UnionType("Result", types=[("ok", t.utf8), ("err", t.i32)], capacity=4)
    """

    def __init__(
        self,
        name: str,
        types: list[tuple[str, EntryType]],
        capacity: Optional[int] = None,
    ):
        self.name = name
        self.types = types  # [(label, EntryType), ...]
        self.capacity: int = capacity if capacity is not None else _union_auto_capacity(len(types))

    @property
    def is_node(self) -> bool:
        return False

    # ── Validation helpers ────────────────────────────────────────────────

    @property
    def colliding_type_names(self) -> set[str]:
        seen: set[str] = set()
        colliding: set[str] = set()
        for name, _ in self.types:
            if name in seen:
                colliding.add(name)
            seen.add(name)
        return colliding

    @property
    def is_over_capacity(self) -> bool:
        return len(self.types) > self.capacity

    def compatible(
        self,
        prev: UnionType,
        self_lookup: dict,
        other_lookup: dict,
        visited: set,
        packed_ctx: bool = False,
    ) -> None:
        """Raise CompatibilityError if *self* is not backward-compatible with *prev*.
        *packed_ctx*: the union is stored under a packed ancestor, and so are the
        nodes its variants reach (`Node.compatible`)."""
        if self.capacity != prev.capacity:
            raise ChangedCapacity(self.name)
        if len(self.types) < len(prev.types):
            raise RemovedTypeCase(self.name, len(prev.types), len(self.types))
        for i, (prev_name, prev_type) in enumerate(prev.types):
            path = f"{self.name}:::{prev_name}" + ("|packed" if packed_ctx else "")
            if path in visited:
                continue
            visited.add(path)
            cur_type = self.types[i][1]
            if not cur_type.compatible(prev_type, self_lookup, other_lookup, visited,
                                       packed_ctx=packed_ctx):
                raise ChangedUnionType(self.name, i)

    def __repr__(self) -> str:
        return f"UnionType({self.name!r}, types={self.types!r}, capacity={self.capacity})"


# ── ImportedGraph ─────────────────────────────────────────────────────────────

class ImportedGraph:
    """Reference to another DataGraph, optionally from a different package."""

    def __init__(self, graph: DataGraph, package_name: Optional[str] = None):
        self.graph = graph
        self.package_name = package_name

    def __repr__(self) -> str:
        if self.package_name:
            return f"ImportedGraph({self.graph.name!r}, package_name={self.package_name!r})"
        return f"ImportedGraph({self.graph.name!r})"


# ── Write-side elision predicate (compat-check mirror of the generators') ──────

def _union_carries_node_refs(union: "UnionType", lookup: dict, _seen: Optional[set] = None) -> bool:
    """True if the union transitively carries a Node reference in any variant —
    directly, inside an array variant, or via a ref to another node-ref union.
    DSL-side mirror of the generators' `_union_has_node_refs` (duplicated here
    because codegen imports the DSL, not vice versa — keep in sync)."""
    if _seen is None:
        _seen = set()
    if union.name in _seen:
        return False
    _seen.add(union.name)
    for _, vt in union.types:
        inner_t = vt.inner if vt.is_array else vt
        if not isinstance(inner_t, EntryType) or inner_t.kind != "ref":
            continue
        obj = lookup.get(inner_t.inner)
        if isinstance(obj, Node):
            return True
        if isinstance(obj, UnionType) and _union_carries_node_refs(obj, lookup, _seen):
            return True
    return False


def _field_is_elidable(f: "Field", node: "Node", lookup: dict) -> bool:
    """Would writers omit this required+default field when its value equals the
    default ("spec/14-defaults-and-prefabs.md" §4, write-side elision)?  Mirror of the
    generators' `_swift_can_elide` / Rust twin — value-semantics shapes only
    (prim/utf8/data scalars, enums, value-unions, and arrays of those) on
    non-frozen nodes; node-refs are never elided (reference semantics: a fresh
    prefab on read would break shared/cyclic identity).  Keep in sync with the
    generators."""
    if node.frozen:
        return False
    if not f.options.is_required or f.default is None:
        return False
    # `always_store` opts out of elision explicitly; a `deprecated` (required) field
    # opts out implicitly — its default must be physically written so a reader compiled
    # before the field was deprecated (which treats it as plain required) still sees the
    # value ("spec/14-defaults-and-prefabs.md" §4). Because the forward-compat check
    # AddedDefaultBreaksOldReaders is gated on this predicate, both also make adding a
    # default to such a field forward-safe — restoring the "deprecate a required field"
    # contract that unconditional elision had broken.
    if always_store in f.options or deprecated in f.options:
        return False

    def _value_semantics(et: EntryType) -> bool:
        if et.kind in EntryType._PRIMITIVES:
            return True
        if et.kind == "ref":
            obj = lookup.get(et.inner)
            if isinstance(obj, Enum):
                return True
            if isinstance(obj, UnionType) and not _union_carries_node_refs(obj, lookup):
                return True
        return False

    if f.type.is_array:
        return _value_semantics(f.type.inner)
    return _value_semantics(f.type)


# ── Header compatibility (shared by DataGraph and DataSink) ────────────────────

def _check_header_compatibility(
    container_name: str,
    self_header: Optional["Node"],
    prev_header: Optional["Node"],
    self_lookup: dict,
    other_lookup: dict,
    visited: set,
) -> None:
    """Compat-check the optional header — the third wire entry point.

    Per "spec/15-customizable-header.md" §11: header presence is encoded in the
    framing word's header_bit, so adding or removing it is breaking by design.
    When present on both sides the header is compared as a packed node (it is
    always emitted packed regardless of its own packed/frozen flags, §5 — hence
    always_packed), so adding a non-required field is safe while removing or
    reordering fields is breaking.
    """
    if (self_header is None) != (prev_header is None):
        raise HeaderPresenceChanged(container_name, added=prev_header is None)
    if self_header is not None:
        self_header.compatible(
            prev_header, self_lookup, other_lookup, visited,
            always_packed=True,
        )


# ── API compatibility (source-surface, advisory) ───────────────────────────────
#
# Distinct from the wire-format check above.  Wire compat is fail-fast (raises on
# the first breaking change) and keys identity by *index*/typeId — so renames are
# wire-safe.  API compat is the mirror image: it *accumulates* every finding into
# a report, never raises, and keys identity by *name* — because the generated code
# surface (node handles, field accessors, enum cases, union variants, prefabs) is
# what consumer source code references.  A rename is wire-safe but source-breaking,
# and shows up here as removed-name + added-name.  The two checks are complementary
# and a caller combines them to decide a version bump.
#
# Severity → semver: a `major` finding means a major version bump is warranted,
# `minor` means additive, `patch` means surfaced-but-source-transparent.
#
# Modelling assumptions (validate against the generators if they drift):
#   • every entry in node_types is generated as a public type (not just the
#     root-reachable ones) — so API surface is the whole flat list.
#   • a field's accessor type is identified by EntryType.type_name; its presence
#     and requiredness drive the initializer/accessor signature.

class Severity:
    MAJOR = "major"
    MINOR = "minor"
    PATCH = "patch"


_SEVERITY_RANK = {"patch": 1, "minor": 2, "major": 3}


class ApiChange:
    """A single source-API difference between two schema versions."""

    def __init__(self, severity: str, kind: str, target: str, detail: str):
        self.severity = severity   # Severity.*
        self.kind = kind           # machine code, e.g. "removed_field"
        self.target = target       # dotted path, e.g. "Person.age"
        self.detail = detail       # human-readable explanation

    def __repr__(self) -> str:
        return f"[{self.severity}] {self.kind} {self.target}: {self.detail}"


class ApiCompatibilityReport:
    """Accumulated, severity-tagged source-API findings.  Never raises."""

    def __init__(self, changes: Optional[list[ApiChange]] = None):
        self.changes: list[ApiChange] = changes if changes is not None else []

    def add(self, severity: str, kind: str, target: str, detail: str) -> None:
        self.changes.append(ApiChange(severity, kind, target, detail))

    @property
    def required_bump(self) -> str:
        """The smallest semver bump that covers every finding: major|minor|patch|none."""
        if not self.changes:
            return "none"
        return max(self.changes, key=lambda c: _SEVERITY_RANK[c.severity]).severity

    def by_severity(self, severity: str) -> list[ApiChange]:
        return [c for c in self.changes if c.severity == severity]

    def __bool__(self) -> bool:
        return bool(self.changes)

    def __iter__(self):
        return iter(self.changes)

    def __repr__(self) -> str:
        return (
            f"ApiCompatibilityReport(required_bump={self.required_bump!r}, "
            f"changes={len(self.changes)})"
        )


def _api_compare_node(report: ApiCompatibilityReport, cur: "Node", prev: "Node") -> None:
    name = cur.name
    cur_fields = {f.name: f for f in cur.fields}
    prev_fields = {f.name: f for f in prev.fields}

    for fname, pf in prev_fields.items():
        cf = cur_fields.get(fname)
        if cf is None:
            report.add(Severity.MAJOR, "removed_field", f"{name}.{fname}",
                       "field removed — accessor disappears from the generated API")
            continue
        if cf.type.type_name != pf.type.type_name:
            report.add(Severity.MAJOR, "changed_field_type", f"{name}.{fname}",
                       f"accessor type changed from {pf.type.type_name} to {cf.type.type_name}")
        if cf.options.is_required != pf.options.is_required:
            report.add(Severity.MAJOR, "changed_field_requiredness", f"{name}.{fname}",
                       f"required {pf.options.is_required} -> {cf.options.is_required} "
                       f"(changes initializer/accessor signature)")
        if cf.default != pf.default:
            report.add(Severity.MINOR, "changed_field_default", f"{name}.{fname}",
                       "default value changed — alters the construct-time default; for a "
                       "required field this is also a wire/data break (see check_compatibility_with)")

    for fname, cf in cur_fields.items():
        if fname not in prev_fields:
            required_no_default = cf.options.is_required and cf.default is None
            report.add(
                Severity.MAJOR if required_no_default else Severity.MINOR,
                "added_field", f"{name}.{fname}",
                "new required field with no default — breaks existing initializer calls"
                if required_no_default else "new field — additive accessor",
            )

    for pname in set(prev.prefabs) - set(cur.prefabs):
        report.add(Severity.MAJOR, "removed_prefab", f"{name}.{pname}",
                   "prefab removed — generated factory/constant disappears")
    for pname in set(cur.prefabs) - set(prev.prefabs):
        report.add(Severity.MINOR, "added_prefab", f"{name}.{pname}",
                   "new prefab — additive factory/constant")
    for pname in set(cur.prefabs) & set(prev.prefabs):
        if cur.prefabs[pname] != prev.prefabs[pname]:
            report.add(Severity.MINOR, "changed_prefab", f"{name}.{pname}",
                       "prefab field values changed — the generated factory now produces "
                       "different values; for a required node-ref default this is also a "
                       "wire/data break (see check_compatibility_with)")

    if cur.frozen != prev.frozen or cur.packed != prev.packed:
        report.add(Severity.PATCH, "changed_node_kind", name,
                   f"layout changed (frozen={prev.frozen}/packed={prev.packed} -> "
                   f"frozen={cur.frozen}/packed={cur.packed}); wire-relevant, no source-name impact")


def _api_compare_enum(report: ApiCompatibilityReport, cur: "Enum", prev: "Enum") -> None:
    name = cur.name
    cur_cases = set(cur.cases.values())
    prev_cases = set(prev.cases.values())
    for c in sorted(prev_cases - cur_cases):
        report.add(Severity.MAJOR, "removed_enum_case", f"{name}.{c}",
                   "enum case removed — consumer switches/references break")
    for c in sorted(cur_cases - prev_cases):
        report.add(Severity.MINOR, "added_enum_case", f"{name}.{c}",
                   "new enum case — additive (exhaustive switches may warn)")
    if cur.as_bitset != prev.as_bitset:
        report.add(Severity.MAJOR, "changed_enum_bitset", name,
                   "as_bitset changed — generated type shape changes (OptionSet vs enum)")
    if cur.capacity != prev.capacity:
        report.add(Severity.PATCH, "changed_enum_capacity", name,
                   "capacity changed — may change underlying rawValue width; wire-relevant")
    # Extensible-form flip: a non-bitset enum with spare capacity carries a
    # synthesized `unknown(rawValue)` case (spec/03-enum-type.md §57); filling it to
    # capacity removes that case (§166).  Either direction reshapes the generated
    # type and breaks exhaustive switches.
    prev_ext = (not prev.as_bitset) and len(prev.cases) < prev.capacity
    cur_ext = (not cur.as_bitset) and len(cur.cases) < cur.capacity
    if prev_ext and not cur_ext:
        report.add(Severity.MAJOR, "removed_unknown_case", f"{name}.unknown",
                   "enum reached full capacity — synthesized `unknown` case removed; "
                   "consumer code matching `.unknown` no longer compiles")
    elif cur_ext and not prev_ext:
        report.add(Severity.MAJOR, "added_unknown_case", f"{name}.unknown",
                   "enum became extensible (spare capacity) — synthesized `unknown` case "
                   "appears; previously-exhaustive switches become non-exhaustive")


def _api_compare_union(report: ApiCompatibilityReport, cur: "UnionType", prev: "UnionType") -> None:
    name = cur.name
    cur_v = {n: ty for n, ty in cur.types}
    prev_v = {n: ty for n, ty in prev.types}
    for vn, pty in prev_v.items():
        cty = cur_v.get(vn)
        if cty is None:
            report.add(Severity.MAJOR, "removed_union_variant", f"{name}.{vn}",
                       "union variant removed")
        elif cty.type_name != pty.type_name:
            report.add(Severity.MAJOR, "changed_union_variant_type", f"{name}.{vn}",
                       f"variant payload type changed from {pty.type_name} to {cty.type_name}")
    for vn in cur_v:
        if vn not in prev_v:
            report.add(Severity.MINOR, "added_union_variant", f"{name}.{vn}",
                       "new union variant — additive")
    # Extensible-form flip: a union with spare capacity carries a synthesized
    # `unknown(typeId)` variant (spec/05-union-types.md §76); filling it to capacity
    # removes that variant (§112).  Either direction reshapes the generated type.
    prev_ext = len(prev.types) < prev.capacity
    cur_ext = len(cur.types) < cur.capacity
    if prev_ext and not cur_ext:
        report.add(Severity.MAJOR, "removed_unknown_variant", f"{name}.unknown",
                   "union reached full capacity — synthesized `unknown` variant removed; "
                   "consumer code matching `.unknown` no longer compiles")
    elif cur_ext and not prev_ext:
        report.add(Severity.MAJOR, "added_unknown_variant", f"{name}.unknown",
                   "union became extensible (spare capacity) — synthesized `unknown` variant "
                   "appears; previously-exhaustive switches become non-exhaustive")


def _api_compare_type_maps(
    report: ApiCompatibilityReport, cur_types: dict, prev_types: dict
) -> None:
    """Compare two name → (Node|Enum|UnionType) maps — the public type surface."""
    for tname, ptype in prev_types.items():
        ctype = cur_types.get(tname)
        if ctype is None:
            report.add(Severity.MAJOR, "removed_type", tname,
                       "type removed from the generated API")
            continue
        if type(ctype) is not type(ptype):
            report.add(Severity.MAJOR, "changed_type_kind", tname,
                       f"type kind changed from {type(ptype).__name__} to {type(ctype).__name__}")
            continue
        if isinstance(ctype, Node):
            _api_compare_node(report, ctype, ptype)
        elif isinstance(ctype, Enum):
            _api_compare_enum(report, ctype, ptype)
        elif isinstance(ctype, UnionType):
            _api_compare_union(report, ctype, ptype)
    for tname in cur_types:
        if tname not in prev_types:
            report.add(Severity.MINOR, "added_type", tname,
                       "new type added to the generated API")


def _api_compare_header(
    report: ApiCompatibilityReport, cur_header: Optional["Node"], prev_header: Optional["Node"]
) -> None:
    if (cur_header is None) != (prev_header is None):
        # Presence flip changes toData/restore (graph) or Reader/Writer (sink)
        # signatures — they gain/lose the required header closure (§7/§8) — so it
        # is a source-API break either way, not merely an added/removed type.
        report.add(Severity.MAJOR, "added_header" if prev_header is None else "removed_header",
                   "<header>",
                   "header added — read/write entry points now require a header closure"
                   if prev_header is None else
                   "header removed — header closure dropped from read/write entry points")
        return
    if cur_header is not None:
        if cur_header.name != prev_header.name:
            report.add(Severity.MAJOR, "renamed_header", cur_header.name,
                       f"header type renamed from {prev_header.name} to {cur_header.name}")
        _api_compare_node(report, cur_header, prev_header)


# ── Reserved-name check (shared by DataGraph / SharedBuffer) ────────────────────

def _check_reserved_names(node_types: list, header=None) -> None:
    """Reject schema type/field names that collide with names the codegen emits in
    any target language (framework types, generated members).  A semantic clash that
    escaping cannot fix — see dagr/reserved_names.py and "spec/23-identifier-mapping.md" §6.
    """
    from dagr.reserved_names import reserved_name_collisions, rust_variant_collisions
    type_names = [nt.name for nt in node_types]
    field_names = []
    for nt in node_types:
        if isinstance(nt, Node):
            field_names += [(nt.name, f.name) for f in nt.fields]
    if header is not None and isinstance(header, Node):
        field_names += [(header.name, f.name) for f in header.fields]
    msgs = reserved_name_collisions(type_names, field_names)
    msgs += rust_variant_collisions(node_types)
    if msgs:
        raise ReservedNameCollision(msgs)


# ── DataGraph ─────────────────────────────────────────────────────────────────

class DataGraph:
    """A named schema graph: a root type plus a collection of Node/Enum/UnionType definitions.

        DataGraph("MyGraph", root_type=t.ref("RootNode"), node_types=[
            Node("RootNode", fields=[
                "id"    >> t.u64 >> required,
                "name"  >> t.utf8,
                "score" >> t.f32 >> float_val(0.0),
            ]),
        ])
    """

    def __init__(
        self,
        name: str,
        node_types: list,  # Node | Enum | UnionType
        root_type: Optional[EntryType] = None,
        imports: Optional[list[ImportedGraph]] = None,
        header: Optional["Node"] = None,
        deletable: bool = True,
    ):
        self.name = name
        self.root_type = root_type
        self.node_types = node_types
        self.imports: list[ImportedGraph] = imports or []
        # Optional envelope node (see "spec/15-customizable-header.md").  It is emitted
        # in packed format ahead of the body, is NOT part of node_types, and gets
        # no typeId — it is the envelope, not the payload.
        self.header: Optional["Node"] = header
        # Deletion toggle (see "spec/09-deletion-of-nodes.md").  When False the generated
        # arena is append-only: no delete()/is_valid(), no free-list reuse, no
        # generation tracking — handles and stored refs collapse to a bare index.
        # This is a *runtime* choice only; serialized bytes are identical either way
        # (the wire format never encoded generation), so a buffer written by a
        # deletable arena reads back into a non-deletable one and vice versa.
        self.deletable: bool = deletable

    # ── Lookup helpers ────────────────────────────────────────────────────

    @property
    def _own_lookup(self) -> dict:
        """Name → NodeType for types defined directly in this graph."""
        return {nt.name: nt for nt in self.node_types}

    @property
    def _imported_lookup(self) -> dict:
        # Transitive: an imported graph brings its own imports along (the nearer
        # declaration shadows), exactly as the flattening targets emit them — Go's
        # `graphs.flatten`, Rust's `flatten_graph_imports`.  One level only would leave
        # a sink over a graph that imports a common graph unable to resolve the common
        # types (spec/38 §2.5).
        result = {}
        for imp in self.imports:
            result.update(imp.graph.lookup)
        return result

    @property
    def lookup(self) -> dict:
        """Merged lookup: imported types shadowed by own types."""
        merged = self._imported_lookup
        merged.update(self._own_lookup)
        return merged

    # ── Validation ────────────────────────────────────────────────────────

    def validate(self) -> None:
        """Validate the graph schema.  Raises a ValidationError subclass on failure."""
        if not self.name:
            raise GraphNameIsNotSet("Graph name must not be empty")

        lk = self.lookup

        if self.root_type is not None and not self.root_type.is_valid_reference(lk.keys()):
            raise RootTypeIsNotValidReference(
                f"Root type {self.root_type!r} is not a valid reference"
            )

        # Duplicate type names within this graph
        seen: dict[str, list] = {}
        for nt in self.node_types:
            seen.setdefault(nt.name, []).append(nt)
        dupes = sorted(k for k, v in seen.items() if len(v) > 1)
        if dupes:
            raise DuplicateNodes(dupes)

        # Unresolved references (top-level scan; deep scan is done in validate())
        unresolved: set[str] = set()
        for nt in self.node_types:
            if isinstance(nt, Node):
                for f in nt.fields:
                    if not f.type.is_valid_reference(lk.keys()):
                        unresolved.add(f.type.type_name)
            elif isinstance(nt, UnionType):
                for _, vt in nt.types:
                    if not vt.is_valid_reference(lk.keys()):
                        unresolved.add(vt.type_name)
        if unresolved:
            raise UnresolvedReferences(sorted(unresolved))

        visited: set = set()
        if self.root_type is not None:
            self.root_type.validate(lk, visited)
        else:
            for nt in self.node_types:
                EntryType("ref", nt.name).validate(lk, visited)

        # Header envelope: must be a Node; its field references resolve against the
        # graph lookup, but the header itself is not referenceable (not in node_types).
        if self.header is not None:
            if not isinstance(self.header, Node):
                raise TypeError(
                    f"header of graph {self.name!r} must be a Node, got {type(self.header).__name__}"
                )
            if self.header.name in lk:
                raise DuplicateNodes([self.header.name])
            for f in self.header.fields:
                if not f.type.is_valid_reference(lk.keys()):
                    raise UnresolvedReferences([f.type.type_name])

        _check_reserved_names(self.node_types, self.header)

    def check_compatibility_with(self, previous: DataGraph) -> None:
        """Check that *self* is wire-compatible with *previous* — in BOTH
        directions ("spec/17-generation-receipts.md" §2): backward (a *self* reader
        reads a buffer written under *previous*) and forward (a *previous*
        reader reads a buffer written under *self*).

        The forward rules are format-aware rather than an argument swap, because
        self-describing layouts tolerate unknown fields asymmetrically: vtable
        readers ignore unknown vtable entries and tagged-packed readers skip the
        unknown-field tail, so appending fields there is safe both ways — while
        frozen (positional) nodes reject any added field, required -> optional
        relaxation is rejected (old readers fail on the now-omittable field),
        and adding a default to an elidable required field is rejected (new
        writers elide it; old readers cannot synthesize it).

        Raises a CompatibilityError subclass on the first breaking change found.
        """
        self_lk = self.lookup
        prev_lk = previous.lookup
        visited: set[str] = set()

        if (self.root_type is None) != (previous.root_type is None):
            raise DifferentRootTypes("Root types are not compatible")
        if self.root_type is not None:
            if not self.root_type.compatible(
                previous.root_type, self_lk, prev_lk, visited
            ):
                raise DifferentRootTypes("Root types are not compatible")

        _check_header_compatibility(
            self.name, self.header, previous.header, self_lk, prev_lk, visited
        )

    def api_compatibility_check(self, previous: "DataGraph") -> ApiCompatibilityReport:
        """Collect *all* source-API differences vs *previous* into a severity-tagged
        report (advisory — never raises).  Complements check_compatibility_with:
        identity here is by **name** across the whole flat type list, so it surfaces
        renames and removals that are wire-safe but break consumer source.
        """
        report = ApiCompatibilityReport()

        # Root type — the generated entry-point type the consumer restores into.
        cur_root = self.root_type.type_name if self.root_type is not None else None
        prev_root = previous.root_type.type_name if previous.root_type is not None else None
        if cur_root != prev_root:
            report.add(Severity.MAJOR, "changed_root_type", "<root>",
                       f"root type changed from {prev_root} to {cur_root}")

        # Public type surface = every own node type (not just root-reachable ones).
        _api_compare_type_maps(report, self._own_lookup, previous._own_lookup)
        _api_compare_header(report, self.header, previous.header)
        return report

    def __repr__(self) -> str:
        return (
            f"DataGraph({self.name!r}, root_type={self.root_type!r}, "
            f"node_types={self.node_types!r})"
        )


# ── ImportedType ──────────────────────────────────────────────────────────────

class ImportedType:
    """A reference to a specific named type from an external DataGraph.

    Used in DataSink.node_types to assign a typeId to a type from another graph.

        ImportedType(user_graph, "User")          # Node from user_graph → gets a typeId
        ImportedType(user_graph, "Status")        # Enum from user_graph → gets a typeId
    """

    def __init__(
        self,
        graph: DataGraph,
        type_name: str,
        package_name: Optional[str] = None,
    ):
        self.graph = graph
        self.type_name = type_name
        self.package_name = package_name

    @property
    def name(self) -> str:
        return self.type_name

    @property
    def resolved(self):
        """Return the resolved Node/Enum/UnionType from the source graph, or None."""
        return self.graph.lookup.get(self.type_name)

    def __repr__(self) -> str:
        if self.package_name:
            return f"ImportedType({self.graph.name!r}, {self.type_name!r}, package_name={self.package_name!r})"
        return f"ImportedType({self.graph.name!r}, {self.type_name!r})"


# ── DataSink ──────────────────────────────────────────────────────────────────

#: Meta-record typeId band ("spec/34-meta-records-and-stream-introspection.md" §2.1).
#: `meta_types[i]` is addressed as `META_TYPE_ID_BASE + i`; 16384 = 2^14 is the
#: smallest value whose LEB128 encoding is three bytes, so the whole two-byte range
#: stays available to payload types.  `node_types` may therefore hold at most
#: MAX_SINK_NODE_TYPES entries (build guard, §2.1).
META_TYPE_ID_BASE = 16384
META_TYPE_ID_END = 32767            # inclusive
MAX_SINK_NODE_TYPES = META_TYPE_ID_BASE
MAX_SINK_META_TYPES = META_TYPE_ID_END - META_TYPE_ID_BASE + 1


def is_meta_type_id(type_id: int) -> bool:
    """True iff *type_id* lies in the reserved meta band (34 §4.2)."""
    return META_TYPE_ID_BASE <= type_id <= META_TYPE_ID_END


class DataSink:
    """An append-only, self-describing record stream schema.

        DataSink("EventStream",
            node_types=[
                Node("Click", fields=[            # typeId = 0, locally defined
                    "x"         >> t.i32 >> required,
                    "y"         >> t.i32 >> required,
                    "timestamp" >> t.u64 >> required,
                ]),
                Node("PageView", fields=[         # typeId = 1, locally defined
                    "url"      >> t.utf8 >> required,
                    "duration" >> t.u32,
                ]),
                ImportedType(user_graph, "User"), # typeId = 2, from external graph
            ],
            # imports only needed when local nodes reference types from another graph
            meta_types=[                          # typeId = 16384, 16385, … (34 §2)
                Node("Checkpoint", fields=[ … ]),
            ],
        )
    """

    def __init__(
        self,
        name: str,
        node_types: list,   # Node | Enum | UnionType | ImportedType
        imports: Optional[list[ImportedGraph]] = None,
        header: Optional["Node"] = None,
        doubly_linked: bool = False,
        meta_types: Optional[list] = None,   # Node | Enum | UnionType | ImportedType
    ):
        self.name = name
        self.node_types = node_types
        # Records *about* the stream rather than *in* it ("32 Meta Records and
        # Stream Introspection.md" §2).  Same entry kinds and same append-only
        # evolution rule as node_types; entry i is addressed by typeId
        # META_TYPE_ID_BASE + i.  Dagr allocates the typeIds and nothing else:
        # meta records are ordinary packed sink records with no semantics.
        self.meta_types: list = list(meta_types or [])
        if len(node_types) > MAX_SINK_NODE_TYPES:
            raise ValueError(
                f"DataSink {name!r}: {len(node_types)} node_types exceed the payload "
                f"typeId space (max {MAX_SINK_NODE_TYPES}; typeIds >= {META_TYPE_ID_BASE} "
                f"are the reserved meta band, 34 §2.1)"
            )
        if len(self.meta_types) > MAX_SINK_META_TYPES:
            raise ValueError(
                f"DataSink {name!r}: {len(self.meta_types)} meta_types exceed the meta "
                f"band ({META_TYPE_ID_BASE}…{META_TYPE_ID_END}, 34 §2.1)"
            )
        self.imports: list[ImportedGraph] = imports or []
        # When True, every record additionally stores its byte span as a
        # reverse-delimited LEB (RLEB) at its END, enabling O(window) reverse
        # iteration from EOF without a forward pass ("spec/11-data-sink.md" §11).
        # Whole-Sink property; changes the wire format (not byte-compatible
        # with a plain Sink).
        self.doubly_linked: bool = doubly_linked
        # Optional open-at-stream metadata node (see "spec/15-customizable-header.md" §9).
        # Metadata only — a sink header cannot sign the body (append-only).  Emitted
        # packed after the framing word, before record0; NOT in node_types, no typeId.
        self.header: Optional["Node"] = header
        self._validate_raw_fields()
        from dagr.reserved_names import rust_variant_collisions
        _rv = rust_variant_collisions(list(node_types) + self.meta_types,
                                      record_types=list(node_types) + self.meta_types)
        if _rv:
            raise ReservedNameCollision(_rv)

    def _validate_raw_fields(self) -> None:
        """Sink records never went through `EntryType.validate`, so an invalid `raw`
        on a record field was silently ignored (found in the spec/39 survey). Records
        are always tagged-packed, so every `raw` shape is live there — check them."""
        lk = self.lookup
        candidates = list(self.node_types) + list(self.meta_types)
        if self.header is not None:
            candidates.append(self.header)
        for nt in candidates:
            if isinstance(nt, Node):
                bad_raw = sorted(nt.fields_with_invalid_raw(lk))
                if bad_raw:
                    raise FieldsWithInvalidRaw(nt.name, bad_raw)

    @property
    def lookup(self) -> dict:
        """Name → type for field-type namespace resolution (imports + own types)."""
        merged: dict = {}
        for imp in self.imports:
            merged.update(imp.graph.lookup)       # transitive, as DataGraph._imported_lookup
        for nt in self.node_types + self.meta_types:
            if isinstance(nt, ImportedType):
                resolved = nt.resolved
                if resolved is not None:
                    merged[nt.type_name] = resolved
            else:
                merged[nt.name] = nt
        if self.header is not None:                 # the header node lives in the sink's namespace too
            merged.setdefault(self.header.name, self.header)
        return merged

    # ── typeId assignment ─────────────────────────────────────────────────

    def record_entries(self) -> list:
        """Every record type with its wire typeId, in typeId order:
        `[(type_id, entry, is_meta), …]`.

        `node_types[i]` → `i`; `meta_types[i]` → `META_TYPE_ID_BASE + i` (34 §2.2).
        This is THE positional map — generators must enumerate records through it
        rather than `enumerate(sink.node_types)`, so every target agrees on the band.
        Entries are returned unresolved (an ImportedType stays an ImportedType).
        """
        out = [(i, nt, False) for i, nt in enumerate(self.node_types)]
        out += [(META_TYPE_ID_BASE + i, nt, True) for i, nt in enumerate(self.meta_types)]
        return out

    # ── Compatibility ─────────────────────────────────────────────────────

    def _indexed_types(self) -> dict:
        """typeId → (name, resolved Node/Enum/UnionType), both bands.

        ImportedType entries are resolved to their underlying type; an
        unresolved import yields None (a validation concern, not a compat one).
        """
        result: dict = {}
        for type_id, nt, _is_meta in self.record_entries():
            if isinstance(nt, ImportedType):
                result[type_id] = (nt.name, nt.resolved)
            else:
                result[type_id] = (nt.name, nt)
        return result

    def check_compatibility_with(self, previous: "DataSink") -> None:
        """Check that *self* is wire-compatible with *previous* — in BOTH
        directions ("spec/17-generation-receipts.md" §2).  Forward compatibility is
        largely structural for a sink: records are length-prefixed, so an old
        reader skips unknown typeIds ("spec/11-data-sink.md" §2), and appending a
        typeId stays additive/safe.  The per-record forward rules (required ->
        optional relaxation) come from Node.compatible; since every record is
        stored tagged-packed regardless of its declared frozen/packed flags
        (§2), kind flags are not compared and the frozen positional rules do
        not apply here.  (Child nodes referenced from record fields are still
        compared with the stricter graph rules via EntryType.compatible — their
        flags are equally wire-irrelevant in a sink, so this can over-flag, but
        over-flagging is the safe direction for a silent-corruption check.)

        A DataSink has no root_type — every entry in node_types is an independent
        top-level record addressed by its **typeId** (its position).  So identity
        here is the typeId, mirroring how field identity inside a Node is the
        field index.  Appending a new typeId is additive/safe; removing or
        changing the type at an existing typeId is breaking.

        Raises a CompatibilityError subclass on the first breaking change found.
        """
        # Record framing first: if the two sides disagree about `doubly_linked`, no
        # per-record comparison below is meaningful, because a reader of one stream
        # cannot even find the records in the other.
        #
        # `_doubly_linked_known` mirrors SharedBuffer's `_pinned_manifest`: a receipt
        # written before the flag was recorded (dagr/ir.py) cannot say what it was, and
        # guessing False there would report a break on every sink that has always been
        # doubly linked. An unknown previous side is skipped; every receipt written from
        # now on carries the flag and is checked.
        if getattr(previous, "_doubly_linked_known", True):
            if self.doubly_linked != previous.doubly_linked:
                raise ChangedDoublyLinked(self.name, added=self.doubly_linked)

        self_lk = self.lookup
        prev_lk = previous.lookup
        visited: set[str] = set()

        _check_header_compatibility(
            self.name, self.header, previous.header, self_lk, prev_lk, visited
        )

        prev_types = previous._indexed_types()
        self_types = self._indexed_types()

        for type_id, (prev_name, prev_type) in prev_types.items():
            cur = self_types.get(type_id)
            if cur is None:
                raise RemovedSinkType(self.name, type_id, prev_name)
            cur_name, cur_type = cur

            # Unresolved imported types are caught by validation, not here.
            if prev_type is None or cur_type is None:
                continue

            if type(cur_type) is not type(prev_type):
                raise TypeWasChanged(
                    cur_name,
                    type(prev_type).__name__,
                    type(cur_type).__name__,
                )

            if isinstance(cur_type, Node):
                # Sink records are always stored with the tagged-packed
                # serialiser regardless of the node's declared frozen/packed
                # flags ("spec/11-data-sink.md" §2), so flag changes are
                # wire-irrelevant here and the frozen positional rules do not
                # apply — the record wire is tagged, hence evolvable.
                cur_type.compatible(prev_type, self_lk, prev_lk, visited,
                                    always_packed=True)
            elif isinstance(cur_type, Enum):
                cur_type.compatible(prev_type)
            elif isinstance(cur_type, UnionType):
                cur_type.compatible(prev_type, self_lk, prev_lk, visited)

    def _api_types(self) -> dict:
        """name → resolved (Node|Enum|UnionType) for the public type surface.

        Keyed by name (the generated struct/enum name) rather than typeId, since
        source-API identity is the name; typeId order is a wire concern handled by
        check_compatibility_with.  Unresolved imports are skipped.
        """
        result: dict = {}
        for nt in self.node_types + self.meta_types:
            if isinstance(nt, ImportedType):
                resolved = nt.resolved
                if resolved is not None:
                    result[nt.name] = resolved
            else:
                result[nt.name] = nt
        return result

    def api_compatibility_check(self, previous: "DataSink") -> ApiCompatibilityReport:
        """Collect *all* source-API differences vs *previous* (advisory — never
        raises).  Companion to check_compatibility_with; identity is by **name**,
        so reordered typeIds (a wire concern) are not flagged here, while renamed
        or removed record types (a source break) are."""
        report = ApiCompatibilityReport()
        # The wire axis already rejects a flip (check_compatibility_with), but it is a
        # source break in its own right and on its own terms: `doubly_linked` is what
        # emits `{S}ReverseReader` / `Prev`, so gaining it adds API and losing it deletes
        # code a caller is calling. Mirrors SharedBuffer reporting `changed_concurrency`.
        if getattr(previous, "_doubly_linked_known", True):
            if self.doubly_linked != previous.doubly_linked:
                report.add(Severity.MAJOR, "changed_doubly_linked", "<doubly_linked>",
                           f"doubly_linked changed from {previous.doubly_linked} to "
                           f"{self.doubly_linked}: the reverse reader "
                           f"({'appears' if self.doubly_linked else 'is removed'})")
        _api_compare_type_maps(report, self._api_types(), previous._api_types())
        _api_compare_header(report, self.header, previous.header)
        return report

    def __repr__(self) -> str:
        if self.meta_types:
            return f"DataSink({self.name!r}, node_types={self.node_types!r}, meta_types={self.meta_types!r})"
        return f"DataSink({self.name!r}, node_types={self.node_types!r})"


# ── SharedBuffer ("spec/20-shared-buffer.md") ────────────────────────────────────────

_SB_NUMERIC_KINDS = frozenset(
    ("u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64", "f16", "bf16", "f32", "f64")
)
#: Concurrency strategies whose layout is implemented (§9.4).  double_buffer / ring
#: are settled in design but land in later increments.
_SB_CONCURRENCY = ("none", "seqlock", "double_buffer", "ring")


def _sb_inline_edges_of_type(t: EntryType, lookup: dict) -> list[str]:
    """Node/union names inlined by value *directly* through this type — a ref to a
    Node or UnionType, or such a ref as an array element.  A union is an inline
    graph *vertex*, so we record the edge to it and do NOT recurse into its
    variants here (that union's own edges are followed when it is visited)."""
    out: list[str] = []
    if t.kind == "ref":
        if isinstance(lookup.get(t.inner), (Node, UnionType)):
            out.append(t.inner)
    elif t.kind in ("array", "arrayWithOptionals"):
        out.extend(_sb_inline_edges_of_type(t.inner, lookup))
    return out


def _sb_inline_targets(obj, lookup: dict) -> list[str]:
    """Node/union names that `obj` (a Node or UnionType) inlines by value."""
    out: list[str] = []
    if isinstance(obj, Node):
        for f in obj.indexed_fields().values():
            out.extend(_sb_inline_edges_of_type(f.type, lookup))
    elif isinstance(obj, UnionType):
        for _lbl, vt in obj.types:
            out.extend(_sb_inline_edges_of_type(vt, lookup))
    return out


def _sb_elem_is_fixed(t: EntryType, lookup: dict, _seen: set = None) -> bool:
    """Is *t* a fixed-width value usable as an array element / union variant?
    (utf8/data and nested arrays are variable and therefore excluded.)  A union
    cycle short-circuits to True here — it is *shape*-fixed; the unbounded-size
    problem is caught separately by the acyclicity check (§7 rule 2)."""
    seen = _seen if _seen is not None else set()
    k = t.kind
    if k == "bool" or k in _SB_NUMERIC_KINDS:
        return True
    if k == "ref":
        target = lookup.get(t.inner)
        if isinstance(target, Enum):
            return True
        if isinstance(target, Node):
            return target.frozen and not target.packed
        if isinstance(target, UnionType):
            if t.inner in seen:
                return True
            seen.add(t.inner)
            return all(_sb_elem_is_fixed(vt, lookup, seen) for _lbl, vt in target.types)
    return False


def _sb_field_is_fixed(f: Field, lookup: dict) -> bool:
    """Field-level fixed-width test (utf8/data/array are fixed only with cap)."""
    t = f.type
    k = t.kind
    if k == "bool" or k in _SB_NUMERIC_KINDS:
        return True
    if k in ("utf8", "data"):
        return f.capacity is not None
    if k == "ref":
        return _sb_elem_is_fixed(t, lookup)
    if k in ("array", "arrayWithOptionals"):
        return f.capacity is not None and _sb_elem_is_fixed(t.inner, lookup)
    return False


class SharedBuffer:
    """A fixed-layout, in-place-mutable struct tree ("spec/20-shared-buffer.md").

    A sibling container to DataGraph / DataSink.  Members are ordinary
    Node(frozen=True) types whose refs are *inlined by value*, so the whole
    region has a statically computable size and every field is read/write in
    place.  It is deliberately not a graph: no sharing, no cycles.

        SharedBuffer("TelemetryFrame", root_type="Frame",
            concurrency="seqlock",           # none | seqlock
            node_types=[
                Node("Frame", frozen=True, fields=[
                    "seq"    >> t.u64 >> required,
                    "sensor" >> t.ref("Sensor") >> required,   # inlined child
                    "label"  >> t.utf8 >> cap(32),             # fixed-capacity string
                ]),
                Node("Sensor", frozen=True, fields=[
                    "id"   >> t.u32 >> required,
                    "gain" >> t.f32 >> required,
                ]),
            ])
    """

    def __init__(
        self,
        name: str,
        node_types: list,               # Node(frozen) | Enum | UnionType
        root_type,                      # str (node name) or EntryType ref
        concurrency: str = "none",
        ring_capacity: int = None,      # number of record slots for concurrency="ring"
        constants: dict = None,         # name -> int/float/str/bool: pure-API compile-time
                                        # constants, emitted in every target, NOT stored in
                                        # the buffer (§14 — "SharedBuffer constants")
    ):
        self.name = name
        self.node_types = node_types
        if isinstance(root_type, str):
            root_type = EntryType("ref", root_type)
        self.root_type: EntryType = root_type
        self.concurrency = concurrency
        self.ring_capacity = ring_capacity
        # Insertion order is preserved (dict) so the emitted constants keep the
        # author's ordering across languages.
        self.constants: dict = dict(constants or {})
        # The offset table this schema shipped (§13), attached when reconstructed
        # from a receipt; a later version's wire check diffs against it. None for a
        # freshly-authored schema (its layout is recomputed on demand).
        self._pinned_manifest = None

    @property
    def _own_lookup(self) -> dict:
        return {nt.name: nt for nt in self.node_types}

    @property
    def lookup(self) -> dict:
        return self._own_lookup

    # ── Validation (§7) ───────────────────────────────────────────────────

    def validate(self) -> None:
        """Validate the SharedBuffer schema.  Raises a ValidationError subclass."""
        if not self.name:
            raise GraphNameIsNotSet("SharedBuffer name must not be empty")

        if self.concurrency not in _SB_CONCURRENCY:
            raise InvalidConcurrencyStrategy(self.name, self.concurrency, list(_SB_CONCURRENCY))
        if self.concurrency == "ring" and not (isinstance(self.ring_capacity, int)
                                               and self.ring_capacity >= 1):
            raise InvalidConcurrencyStrategy(
                self.name, "ring (needs ring_capacity >= 1)", list(_SB_CONCURRENCY))

        # Pure-API constants (§14): identifiers, no reserved-name clash, scalar values.
        for cname, cval in self.constants.items():
            if not (isinstance(cname, str) and cname.isidentifier()):
                raise InvalidSharedBufferConstant(self.name, f"name {cname!r} is not an identifier")
            if cname in _SB_RESERVED_CONST_NAMES:
                raise InvalidSharedBufferConstant(
                    self.name, f"name {cname!r} is reserved (emitted by the overlay itself)")
            # bool is a subclass of int — check it first so True/False stay bool.
            if not isinstance(cval, (bool, int, float, str)):
                raise InvalidSharedBufferConstant(
                    self.name, f"{cname!r} has unsupported value type {type(cval).__name__} "
                    f"(use int / float / str / bool)")

        lk = self.lookup

        # Duplicate type names.
        seen: dict[str, list] = {}
        for nt in self.node_types:
            seen.setdefault(nt.name, []).append(nt)
        dupes = sorted(k for k, v in seen.items() if len(v) > 1)
        if dupes:
            raise DuplicateNodes(dupes)

        # Root must reference a member frozen Node.
        if self.root_type.kind != "ref":
            raise SharedBufferRootNotFixedNode(self.name, self.root_type.type_name)
        root_target = lk.get(self.root_type.inner)
        if not (isinstance(root_target, Node) and root_target.frozen and not root_target.packed):
            raise SharedBufferRootNotFixedNode(self.name, self.root_type.inner)

        # Unresolved references (top-level scan).
        unresolved: set[str] = set()
        for nt in self.node_types:
            if isinstance(nt, Node):
                for f in nt.fields:
                    if not f.type.is_valid_reference(lk.keys()):
                        unresolved.add(f.type.type_name)
            elif isinstance(nt, UnionType):
                for _lbl, vt in nt.types:
                    if not vt.is_valid_reference(lk.keys()):
                        unresolved.add(vt.type_name)
        if unresolved:
            raise UnresolvedReferences(sorted(unresolved))

        # Per-node structural rules.
        for nt in self.node_types:
            if not isinstance(nt, Node):
                continue
            # Rule 0 — frozen, not packed.
            if not nt.frozen or nt.packed:
                raise NonFrozenNodeInSharedBuffer(self.name, nt.name)

            # Field names must be unique within the node — the layout maps each name
            # to one offset and the accessors are named per field, so a collision
            # silently drops a field and emits clashing getters/setters. (Same guard
            # DataGraph applies; SharedBuffer.validate() was missing it.)
            colliding = sorted(nt.colliding_field_names)
            if colliding:
                raise CollidingFieldNames(nt.name, colliding)

            fields = list(nt.indexed_fields().values())

            # Rule 3 — collection/string fields must carry cap(N).
            missing_cap = [
                f.name for f in fields
                if f.type.kind in ("utf8", "data", "array", "arrayWithOptionals")
                and f.capacity is None
            ]
            if missing_cap:
                raise MissingCapacityInSharedBuffer(nt.name, missing_cap)

            # §5.5 — union variants must be fixed-width (report per union).
            for f in fields:
                for uname, bad in self._bad_union_variants(f.type, lk):
                    raise NonFixedUnionVariant(uname, bad)

            # Rule 1 — every field fixed-width.
            non_fixed = [f.name for f in fields if not _sb_field_is_fixed(f, lk)]
            if non_fixed:
                raise NonFixedFieldInSharedBuffer(nt.name, non_fixed)

        # Rule 2 — no inline recursion over member nodes.
        self._check_acyclic(lk)

        _check_reserved_names(self.node_types)

    def _bad_union_variants(self, t: EntryType, lookup: dict):
        """Yield (union_name, [bad variant labels]) for any union reachable via *t*
        with a non-fixed-width variant."""
        if t.kind == "ref":
            target = lookup.get(t.inner)
            if isinstance(target, UnionType):
                bad = [lbl for lbl, vt in target.types if not _sb_elem_is_fixed(vt, lookup)]
                if bad:
                    yield (target.name, bad)
        elif t.kind in ("array", "arrayWithOptionals"):
            yield from self._bad_union_variants(t.inner, lookup)

    def _check_acyclic(self, lookup: dict) -> None:
        # The inline-reference graph spans both Nodes and UnionTypes (both are
        # inlined by value), so a cycle through *either* — including a pure
        # union→union cycle — is unbounded size and must be rejected. Unions are
        # vertices here, not recursed-through, so detection is finite.
        WHITE, GREY, BLACK = 0, 1, 2
        color: dict[str, int] = {}

        def visit(name: str, path: list[str]) -> None:
            obj = lookup.get(name)
            if not isinstance(obj, (Node, UnionType)):
                return
            color[name] = GREY
            path.append(name)
            for child in _sb_inline_targets(obj, lookup):
                c = color.get(child, WHITE)
                if c == GREY:
                    raise RecursiveSharedBufferNode(self.name, path[path.index(child):] + [child])
                if c == WHITE:
                    visit(child, path)
            path.pop()
            color[name] = BLACK

        for nt in self.node_types:
            if isinstance(nt, (Node, UnionType)) and color.get(nt.name, WHITE) == WHITE:
                visit(nt.name, [])

    # ── Compatibility (§13) ───────────────────────────────────────────────

    def check_compatibility_with(self, previous: "SharedBuffer") -> None:
        """Wire (data) axis: can regions written under *previous* still be read by
        *self*?  Raises the first `CompatibilityError` on any moved/resized field,
        a changed concurrency preamble, or a grown union slot.

        A fixed layout is rigid (§13): unlike a vtable graph node, it cannot
        tolerate a shifted offset, so this check is far stricter than the graph
        checker.  The old side is diffed against its **recorded** manifest (the
        pinned offsets `previous` shipped, attached when reconstructed from a
        receipt); if none is present (a live object, not from IR) its layout is
        recomputed — identical today, since offsets are still a pure function of
        the schema.
        """
        from dagr.layout import compute_layout, manifest_to_ir, check_layout_compatible
        cur = manifest_to_ir(compute_layout(self))
        pinned = getattr(previous, "_pinned_manifest", None)
        if pinned is None:
            pinned = manifest_to_ir(compute_layout(previous))
        check_layout_compatible(pinned, cur, self.name)

    def api_compatibility_check(self, previous: "SharedBuffer") -> ApiCompatibilityReport:
        """Source (API) axis: collect all consumer-visible differences vs
        *previous* into a severity-tagged report (advisory — never raises).
        Identity is by name across the flat type list, so renames/removals that
        are wire-safe but break generated source surface here."""
        report = ApiCompatibilityReport()

        if self.concurrency != previous.concurrency:
            report.add(Severity.MAJOR, "changed_concurrency", "<concurrency>",
                       f"concurrency strategy changed from {previous.concurrency} "
                       f"to {self.concurrency}")

        cur_root = self.root_type.type_name
        prev_root = previous.root_type.type_name
        if cur_root != prev_root:
            report.add(Severity.MAJOR, "changed_root_type", "<root>",
                       f"root type changed from {prev_root} to {cur_root}")

        _api_compare_type_maps(report, self._own_lookup, previous._own_lookup)
        return report

    def __repr__(self) -> str:
        return (
            f"SharedBuffer({self.name!r}, root_type={self.root_type!r}, "
            f"concurrency={self.concurrency!r}, node_types={self.node_types!r})"
        )
