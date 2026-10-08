"""Dagr typed layer (Phase 3) — the bridge between per-schema ``@dataclass`` node types
and the generic reflective model, plus the cycle-aware structural methods those typed
classes share.

The reflective core (``dagr_restore`` / ``dagr_serialize``) walks a live ``DataGraph`` and
speaks the generic ``DagrNode`` object graph. The *typed* layer (emitted by
``dagr_codegen_python``) is an ergonomics skin over that: per-node ``@dataclass`` types
with attribute access, IDE completion, and construction, over the SAME runtime. This module
supplies the two things every generated typed module needs:

- **converters** — ``to_dagr`` (typed graph → ``DagrNode`` graph, for ``to_bytes``) and
  ``from_dagr`` (``DagrNode`` graph → typed graph, for ``restore``), both cycle-aware via an
  ``id()`` memo (create-then-register-then-fill, like every target);
- **structural methods** — ``struct_eq`` / ``struct_hash`` / ``struct_repr``, each
  visited-set-guarded so cycles and shared nodes terminate, generated into every typed node
  class (``@dataclass``'s auto ``__eq__``/``__hash__`` would infinite-loop on a cycle).

Representation choices (plan §8.4 / O-P7): a typed node is a ``@dataclass`` carrying
``_dagr_type`` (schema name) + ``_dagr_fields`` (ordered ``(attr, wire_name)`` pairs — the
attribute may differ from the schema name when a field name collides with a Python keyword
and gets a trailing underscore, §11). Enums flow as plain
``int`` (the emitted ``IntEnum``/``IntFlag`` members ARE ints, so construction reads
nicely and the wire value is exact).

**Typed unions (O-P7 upgrade).** Each ``UnionType`` emits a per-union :class:`DagrUnion`
*subclass* (with variant factories), so a value's runtime type names its union. A ``DagrNode``
still carries no union-type name, so :func:`from_dagr` is **type-directed** — it walks the live
schema alongside the value (from the root / record ``EntryType``), and at a union field it wraps
the generic :class:`DagrUnion` into ``unions[name]``. Serialization is unaffected:
:func:`to_dagr` sees any ``DagrUnion`` (subclass included) and lowers it back to the generic
form, so the wire bytes are identical.
"""
from enum import Enum as _Enum

from dagr.dsl import Node, UnionType

from .dagr_model import DagrNode, DagrUnion, runtime_graph, fields_by_name


def _is_typed_node(obj):
    return hasattr(obj, "_dagr_type") and hasattr(obj, "_dagr_fields")


def to_dagr(obj, memo=None):
    """Typed graph → generic ``DagrNode`` graph (cycle-aware). Enums → raw ``int``;
    unions pass through as ``DagrUnion``; lists recurse; scalars unchanged."""
    if memo is None:
        memo = {}
    if obj is None:
        return None
    if isinstance(obj, list):
        return [to_dagr(x, memo) for x in obj]
    if isinstance(obj, DagrUnion):
        return DagrUnion(obj.tag, to_dagr(obj.value, memo))
    if _is_typed_node(obj):
        oid = id(obj)
        if oid in memo:                            # shared node / cycle → materialise once
            return memo[oid]
        node = DagrNode(obj._dagr_type)
        memo[oid] = node                           # register BEFORE filling ref fields
        for attr, wire in obj._dagr_fields:
            node.fields[wire] = to_dagr(getattr(obj, attr), memo)
        return node
    if isinstance(obj, _Enum):
        return int(obj.value)
    return obj                                     # int / float / bool / str / bytes


def _variant_type(union, tag):
    for label, vt in union.types:
        if label == tag:
            return vt
    raise KeyError(f"union {union.name!r} has no variant {tag!r}")


def from_dagr(graph, etype, v, nodes, unions, memo=None):
    """Generic ``DagrNode`` graph → typed graph, **type-directed**: walk the schema (from the
    root / record ``EntryType`` ``etype``) alongside ``v``. ``nodes`` maps a schema node name →
    its typed class, ``unions`` a union name → its typed :class:`DagrUnion` subclass. A union
    field materialises ``unions[name]`` (recursing into the active variant by its declared type);
    a node materialises ``nodes[name]`` (cycle-aware via an ``id()`` memo); enums stay ``int``;
    arrays recurse."""
    if memo is None:                               # top-level call: facts computed once per call
        memo = {}
        graph = runtime_graph(graph)
    if v is None:
        return None
    k = etype.kind
    if k in ("array", "arrayWithOptionals"):
        return [from_dagr(graph, etype.inner, x, nodes, unions, memo) for x in v]
    if k == "ref":
        tgt = graph.lookup[etype.inner]
        if isinstance(tgt, UnionType):             # v is a DagrUnion
            inner = from_dagr(graph, _variant_type(tgt, v.tag), v.value, nodes, unions, memo)
            ucls = unions.get(tgt.name)
            return ucls(v.tag, inner) if ucls is not None else DagrUnion(v.tag, inner)
        if isinstance(tgt, Node):                  # v is a DagrNode
            vid = id(v)
            if vid in memo:
                return memo[vid]
            cls = nodes[tgt.name]
            obj = cls.__new__(cls)                 # bypass __init__; fill by attribute
            memo[vid] = obj                        # register BEFORE filling ref fields
            fields = fields_by_name(graph, tgt)
            for attr, wire in cls._dagr_fields:
                setattr(obj, attr, from_dagr(graph, fields[wire].type,
                                             v.fields.get(wire), nodes, unions, memo))
            return obj
        return v                                   # Enum ref → raw int
    return v                                       # scalar (int / float / bool / str / bytes)


def from_dagr_record(graph, tid, v, nodes, unions):
    """Type-directed conversion of one DataSink record (node / union / enum) by its ``typeId`` —
    node → typed node, union → typed union, enum → raw ``int`` (see :func:`from_dagr`)."""
    from dagr.dsl import EntryType
    return from_dagr(graph, EntryType("ref", graph.node_types[tid].name), v, nodes, unions)


# ── cycle-aware structural methods (shared by every generated typed node class) ──

def struct_eq(a, b, seen):
    at, bt = getattr(a, "_dagr_type", None), getattr(b, "_dagr_type", None)
    if at is not None and bt is not None:
        if at != bt:
            return False
        key = (id(a), id(b))
        if key in seen:
            return True                            # assume-equal on a repeated pair
        seen = seen | {key}
        return all(struct_eq(getattr(a, attr), getattr(b, attr), seen)
                   for attr, _ in a._dagr_fields)
    if isinstance(a, DagrUnion) and isinstance(b, DagrUnion):
        return a.tag == b.tag and struct_eq(a.value, b.value, seen)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(struct_eq(x, y, seen) for x, y in zip(a, b))
    return a == b


def struct_hash(v, seen):
    if _is_typed_node(v):
        if id(v) in seen:
            return hash(("<cycle>", v._dagr_type))
        seen = seen | {id(v)}
        h = hash(v._dagr_type)
        for attr, _ in v._dagr_fields:
            h = (h * 1000003) ^ hash(attr) ^ struct_hash(getattr(v, attr), seen)
        return h & 0x7FFFFFFFFFFFFFFF
    if isinstance(v, DagrUnion):
        return (hash(v.tag) * 1000003) ^ struct_hash(v.value, seen)
    if isinstance(v, list):
        h = 0x345678
        for x in v:
            h = (h * 1000003) ^ struct_hash(x, seen)
        return h & 0x7FFFFFFFFFFFFFFF
    return hash(v)


def struct_repr(v, seen):
    if _is_typed_node(v):
        if id(v) in seen:
            return f"{v._dagr_type}@…"             # back-reference (shared / cycle)
        seen = seen | {id(v)}
        inner = ", ".join(f"{attr}={struct_repr(getattr(v, attr), seen)}"
                          for attr, _ in v._dagr_fields)
        return f"{v._dagr_type}({inner})"
    if isinstance(v, DagrUnion):
        return f"{v.tag}({struct_repr(v.value, seen)})"
    if isinstance(v, list):
        return "[" + ", ".join(struct_repr(x, seen) for x in v) + "]"
    return repr(v)
