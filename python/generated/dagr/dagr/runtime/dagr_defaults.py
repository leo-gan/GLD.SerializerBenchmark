"""Write-side default elision + read-side default synthesis (``spec/14-defaults-and-prefabs.md``
§4 / plan "27 …" §8.5) — the FlatBuffers-style optimization shared by the reflective
serializer and restorer, for graph nodes and DataSink records alike.

A **required** field carrying a schema default, on a **non-frozen** node, may be omitted from
the buffer when its value equals the default; the reader synthesizes it back. This *changes the
bytes* (a stored slot/tag disappears), so both halves must agree exactly — and match the
Swift/Rust wire, since Python's serializer is a canonical writer.

Elision is sound only for **value-semantic** fields: a re-synthesized value is observationally
identical to a stored one. Covered: primitive scalars, ``utf8``, ``data``, ``enum`` (plain or
bitset), **value unions** (no node-ref variant), and **arrays** of all of those. Node-refs are
**never** elided (a freshly synthesized prefab would lose the identity of a shared/cyclic target
— spec 14 §4 "Why node-refs are never elided"). ``always_store`` / ``deprecated`` opt a field out,
and ``elision_disabled()`` switches elision off for building prototype blobs (every field
materialized).
"""
import base64
import contextlib

from dagr.dsl import Enum, Node, UnionType, always_store, deprecated

from .dagr_model import DagrUnion

_ELIDABLE_SCALARS = frozenset((
    "u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64",
    "f16", "bf16", "f32", "f64", "bool", "utf8", "data"))

_ELISION = {"on": True}


@contextlib.contextmanager
def elision_disabled():
    """Serialize with every field materialized — a prototype / prefab blob must never elide a
    field inside its own default (14 §4 "The prototype-blob hazard")."""
    prev = _ELISION["on"]
    _ELISION["on"] = False
    try:
        yield
    finally:
        _ELISION["on"] = prev


def _union_is_value(union, lookup, seen=frozenset()):
    """A union with no node-ref variant (directly or through a nested union) — value-comparable."""
    if union.name in seen:
        return True
    for _, vt in union.types:
        if vt.kind == "ref":
            inner = lookup.get(vt.inner)
            if isinstance(inner, Node):
                return False
            if isinstance(inner, UnionType) and not _union_is_value(inner, lookup, seen | {union.name}):
                return False
        elif vt.kind in ("array", "arrayWithOptionals"):
            return False
    return True


def _elidable_type(t, lookup):
    k = t.kind
    if k in _ELIDABLE_SCALARS:
        return True
    if k == "ref":
        inner = lookup.get(t.inner)
        return isinstance(inner, Enum) or (isinstance(inner, UnionType) and _union_is_value(inner, lookup))
    if k in ("array", "arrayWithOptionals"):
        return _elidable_type(t.inner, lookup)
    return False


def can_elide(field, node, lookup):
    """True if ``field`` on ``node`` is write-side elidable (spec 14 §4)."""
    if getattr(node, "frozen", False):                 # frozen layouts are positional — no absence
        return False
    if not field.options.is_required or getattr(field, "default", None) is None:
        return False
    if always_store in field.options or deprecated in field.options:
        return False                                   # explicit / implicit opt-out
    return _elidable_type(field.type, lookup)


def _value_of(v, t, lookup):
    """A schema default literal ``v`` for type ``t`` as the value ``restore`` produces, or None."""
    k = v.kind
    if k in ("int", "float", "bool", "string"):
        return v.payload
    if k == "b64Data":
        return base64.b64decode(v.payload)
    if k == "ref" and t.kind == "ref":
        inner = lookup.get(t.inner)
        if isinstance(inner, Enum):
            for raw, name in inner.cases.items():
                if name == v.payload:
                    return (1 << raw) if inner.as_bitset else raw
        return None
    if k == "unionRef" and t.kind == "ref":
        union = lookup.get(t.inner)
        label, inner_v = v.payload
        vt = next((vty for n, vty in union.types if n == label), None) if isinstance(union, UnionType) else None
        if vt is None:
            return None
        inner = _value_of(inner_v, vt, lookup)
        return None if inner is None else DagrUnion(label, inner)
    if k == "array" and t.kind in ("array", "arrayWithOptionals"):
        out = []
        for e in v.payload:
            if e.kind == "nil":
                out.append(None)
                continue
            ev = _value_of(e, t.inner, lookup)
            if ev is None:
                return None
            out.append(ev)
        return out
    return None


def default_value(field, lookup):
    """The Python value a field's default synthesizes to (the same shape ``restore`` produces):
    ``int`` / ``float`` / ``bool`` / ``str`` / ``bytes`` for scalars, the raw ``int`` for an enum
    (bitset → the flag bit), a ``DagrUnion`` for a union, a ``list`` for an array. ``None`` if the
    default kind is outside the supported set."""
    v = getattr(field, "default", None)
    if v is None:
        return None
    return _value_of(v, field.type, lookup)


def is_elided(field, node, lookup, value):
    """True when ``value`` equals ``field``'s default and the field is elidable → omit on write."""
    if not _ELISION["on"] or value is None or not can_elide(field, node, lookup):
        return False
    d = default_value(field, lookup)
    return d is not None and value == d                # exact equality (NaN never elides — correct)


def synth_default(field, node, lookup):
    """Value to synthesize for an ABSENT field on read — its default if elidable, else ``None``
    (the prior behavior for a genuinely absent optional field)."""
    if not can_elide(field, node, lookup):
        return None
    return default_value(field, lookup)
