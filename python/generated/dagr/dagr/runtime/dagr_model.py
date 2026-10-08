"""Dagr reflective in-memory model (Phase 1) — a plain Python object graph.

Because CPython has a cyclic garbage collector (unlike Swift ARC / Rust `Rc`), the
arena that every other target needs to dodge reference-cycle leaks is unnecessary here
(plan "27 …" §4). So a restored node is just a lightweight object: a `type_name` plus a
`fields` dict, with node-refs held as **direct Python references** (a shared node is the
*same object* twice; a cycle is an ordinary back-reference — both leak-free under the
GC).

The three structural methods are **custom** (not `@dataclass`-generated) and
**visited-set-guarded**, so cycles and shared nodes terminate (plan §8.6). They are
brand/identity-free, so two graphs restored independently (e.g. from a Swift golden and
a Rust golden of the same spec) compare equal and hash equal — the property the
in-process differential oracle relies on.
"""


class DagrUnion:
    """A tagged-union value: the active variant label + its payload."""

    __slots__ = ("tag", "value")

    def __init__(self, tag, value):
        self.tag = tag
        self.value = value

    def __repr__(self):
        return f"{self.tag}({_repr(self.value, set())})"

    def __eq__(self, other):
        return _eq(self, other, set())

    def __hash__(self):
        return _hash(self, set())


class DagrNode:
    """A restored node: ``type_name`` + a ``fields`` dict (field name → value).

    Values are Python-native: scalars → int/float/bool, ``utf8`` → str, ``data`` →
    bytes, enum → int (raw), node-ref → a ``DagrNode`` (or None), union → ``DagrUnion``,
    array → list (``arrayWithOptionals`` → list with ``None`` holes).
    """

    __slots__ = ("type_name", "fields")

    def __init__(self, type_name, fields=None):
        self.type_name = type_name
        self.fields = fields if fields is not None else {}

    def __repr__(self):
        return _repr(self, set())

    def __eq__(self, other):
        return _eq(self, other, set())

    def __hash__(self):
        return _hash(self, set())


# ── cycle-aware structural helpers (visited-set guarded) ─────────────────────

def _repr(v, seen):
    if isinstance(v, DagrNode):
        if id(v) in seen:
            return f"{v.type_name}@…"            # back-reference (shared / cycle)
        seen = seen | {id(v)}
        inner = ", ".join(f"{k}={_repr(val, seen)}" for k, val in v.fields.items())
        return f"{v.type_name}({inner})"
    if isinstance(v, DagrUnion):
        return f"{v.tag}({_repr(v.value, seen)})"
    if isinstance(v, list):
        return "[" + ", ".join(_repr(x, seen) for x in v) + "]"
    return repr(v)


def _hash(v, seen):
    if isinstance(v, DagrNode):
        if id(v) in seen:
            return hash(("<cycle>", v.type_name))
        seen = seen | {id(v)}
        h = hash(v.type_name)
        for k, val in v.fields.items():
            h = (h * 1000003) ^ hash(k) ^ _hash(val, seen)
        return h & 0x7FFFFFFFFFFFFFFF
    if isinstance(v, DagrUnion):
        return (hash(v.tag) * 1000003) ^ _hash(v.value, seen)
    if isinstance(v, list):
        h = 0x345678
        for x in v:
            h = (h * 1000003) ^ _hash(x, seen)
        return h & 0x7FFFFFFFFFFFFFFF
    return hash(v)


def _eq(a, b, seen):
    if isinstance(a, DagrNode) and isinstance(b, DagrNode):
        if a.type_name != b.type_name:
            return False
        key = (id(a), id(b))
        if key in seen:
            return True                           # assume-equal on a repeated pair
        seen = seen | {key}
        if a.fields.keys() != b.fields.keys():
            return False
        return all(_eq(a.fields[k], b.fields[k], seen) for k in a.fields)
    if isinstance(a, DagrUnion) and isinstance(b, DagrUnion):
        return a.tag == b.tag and _eq(a.value, b.value, seen)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(_eq(x, y, seen) for x, y in zip(a, b))
    return a == b


# ── Per-call schema facts ─────────────────────────────────────────────────────

class RuntimeGraph:
    """A graph (``DataGraph`` / ``DataSink``) with the facts the serialize / restore walks ask
    for on every node computed ONCE: the merged ``lookup`` (``DataGraph.lookup`` rebuilds that
    dict on every access), each node's indexed fields, per-field elidability and field-by-name
    maps. Every other attribute is forwarded to the wrapped graph.

    The runtime entry points wrap the graph for the duration of one call (``runtime_graph``);
    a generated typed module wraps its schema once at import, since that schema never changes.
    Helpers below fall back to the plain computation when handed an unwrapped graph, so code
    that calls runtime internals directly keeps working."""
    __slots__ = ("_g", "lookup", "_indexed", "_by_name", "_elide", "_max_align", "_plans", "typed")

    def __init__(self, graph):
        self._g = graph
        self.lookup = graph.lookup
        self._indexed = {}     # id(decl) → (decl, ((idx, field), …), {idx: field})   decl kept alive: stable id
        self._by_name = {}     # id(decl) → (decl, {name: field})
        self._elide = {}       # (id(decl), id(field)) → (decl, field, bool)
        self._max_align = None
        self._plans = {}       # (kind, id(decl)) → (decl, plan)   see dagr_serialize._packed_plan
        # (node classes, union classes) of a generated typed module whose classes expose
        # `fields` (attr == wire name): restore then builds them directly (see new_node).
        self.typed = None

    def __getattr__(self, name):
        return getattr(self._g, name)

    def indexed_items(self, decl):
        return self._indexed_entry(decl)[1]

    def indexed_map(self, decl):
        return self._indexed_entry(decl)[2]

    def _indexed_entry(self, decl):
        hit = self._indexed.get(id(decl))
        if hit is None:
            m = decl.indexed_fields()
            hit = self._indexed[id(decl)] = (decl, tuple(m.items()), m)
        return hit

    def fields_by_name(self, decl):
        hit = self._by_name.get(id(decl))
        if hit is None:
            hit = self._by_name[id(decl)] = (decl, {f.name: f for f in decl.indexed_fields().values()})
        return hit[1]

    def can_elide(self, field, decl):
        key = (id(decl), id(field))
        hit = self._elide.get(key)
        if hit is None:
            from .dagr_defaults import can_elide
            hit = self._elide[key] = (decl, field, can_elide(field, decl, self.lookup))
        return hit[2]


def cached_plan(graph, kind, decl, build):
    """``build(graph, decl)``, memoized per (kind, decl) when ``graph`` is a RuntimeGraph."""
    if type(graph) is not RuntimeGraph:
        return build(graph, decl)
    key = (kind, id(decl))
    hit = graph._plans.get(key)
    if hit is None:
        hit = graph._plans[key] = (decl, build(graph, decl))
    return hit[1]


def new_node(graph, type_name):
    """A fresh node shell for restore: the generated typed class when ``graph`` carries typed
    registries (its instances expose ``fields`` as their ``__dict__``), else a ``DagrNode``."""
    if type(graph) is RuntimeGraph and graph.typed is not None:
        cls = graph.typed[0].get(type_name)
        if cls is not None:
            return cls.__new__(cls)
    return DagrNode(type_name)


def new_union(graph, union, label, value):
    """A restored union value: the generated typed union class when registered, else ``DagrUnion``."""
    if type(graph) is RuntimeGraph and graph.typed is not None:
        ucls = graph.typed[1].get(union.name)
        if ucls is not None:
            return ucls(label, value)
    return DagrUnion(label, value)


def runtime_graph(graph):
    """``graph`` wrapped as a :class:`RuntimeGraph` (idempotent)."""
    return graph if type(graph) is RuntimeGraph else RuntimeGraph(graph)


def indexed_items(graph, decl):
    """``tuple(decl.indexed_fields().items())``, cached when ``graph`` is a RuntimeGraph."""
    if type(graph) is RuntimeGraph:
        return graph.indexed_items(decl)
    return tuple(decl.indexed_fields().items())


def indexed_map(graph, decl):
    """``decl.indexed_fields()`` (``{idx: field}``), cached when ``graph`` is a RuntimeGraph.
    Callers must not mutate the returned dict."""
    if type(graph) is RuntimeGraph:
        return graph.indexed_map(decl)
    return decl.indexed_fields()


def fields_by_name(graph, decl):
    if type(graph) is RuntimeGraph:
        return graph.fields_by_name(decl)
    return {f.name: f for f in decl.indexed_fields().values()}


def field_can_elide(graph, field, decl):
    if type(graph) is RuntimeGraph:
        return graph.can_elide(field, decl)
    from .dagr_defaults import can_elide
    return can_elide(field, decl, graph.lookup)
