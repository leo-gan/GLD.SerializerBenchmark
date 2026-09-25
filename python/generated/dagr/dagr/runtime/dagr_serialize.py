"""Dagr reflective serialize (Phase 2) — a plain Python object graph → bytes, by
walking a live ``dagr_dsl.DataGraph``. The byte-exact inverse of ``dagr_restore``.

A direct, type-directed schema walk mirroring the reference serializers (Swift
``DataArenaBuilder`` / the TS ``dagr_codegen_typescript_serde`` walk it was ported from):
the backward-growing :class:`~dagr.runtime.dagr_writer.Builder` stores the root node
(recursing into ref fields), then the arena finish-padding (§11) and the framing word.

Byte-exactness — not round-trip — is the gate (plan "27 …" §5/§6): ``serialize`` must
reproduce every encoder-side decision (vtable dedup, V62 pointer direction, cycle
late-binding, packing, alignment) so the output equals the Swift/Rust fixture
byte-for-byte.

**Coverage: the full corpus, byte-exact, 0 skipped** — all four node shapes (regular /
packed / frozen / frozen+packed) × every field kind: scalar / enum-ref / utf8 / data /
node-ref (incl. shared nodes + cycles via begin/finish late-binding, frozen children, and
``raw`` embedded graphs §17), all arrays (fixed / bool / enum-bit / pointer-table /
node-ref + arrayWithOptionals; packed int/byte/bool/enum/f16/float + opt variants; aligned
array/bytes/utf8 §11), and full unions (field slot, nested no-width slot, packed
``id<<3|code`` header, size-prefixed nested packed union, SoA union arrays, two-section
packed union arrays — every variant kind). Gated in ``tests/test_serialize_corpus.py``.
"""
from dagr.dsl import Enum, Node, UnionType
from .dagr_defaults import is_elided as _is_elided
from dagr.codegen.shared import (
    _enum_raw_width, _enum_bits_per_elem, _elem_width, _graph_max_alignment, _aligned_n)

from .dagr_writer import Builder, node_offset
from .dagr_model import RuntimeGraph, runtime_graph, indexed_items, field_can_elide, cached_plan
from .dagr_writer import (
    zigzag_encode, leb_length, f32_bits, f64_bits, f32_to_f16_bits, f32_to_bf16_bits)

_FIXED_STORE = {
    "u8": "store_u8", "u16": "store_u16", "u32": "store_u32", "u64": "store_u64",
    "i8": "store_i8", "i16": "store_i16", "i32": "store_i32", "i64": "store_i64",
    "f32": "store_f32", "f64": "store_f64", "f16": "store_f16", "bf16": "store_bf16",
}

# Widths for the packed "LEB-if-smaller-than-raw" choice; kinds that are choice/enc-var
# in packed & frozen+packed nodes (multi-byte scalars + non-u8 enums, which reduce to a
# multi-byte width via _eff_kind); and the signed wide ints (ZigZag before the LEB).
_WIDTH = {"u16": 2, "u32": 4, "u64": 8, "i16": 2, "i32": 4, "i64": 8,
          "f16": 2, "bf16": 2, "f32": 4, "f64": 8}
_CHOICE_KINDS = {"u16", "u32", "u64", "i16", "i32", "i64", "f32", "f64", "f16", "bf16"}
_SIGNED_WIDE = {"i16", "i32", "i64"}


def _is_enum_ref(t, lookup):
    return t.kind == "ref" and isinstance(lookup.get(t.inner), Enum)


def _eff_kind(field, lookup):
    """Effective inline scalar kind: an enum-ref reduces to its backing unsigned width."""
    if _is_enum_ref(field.type, lookup):
        return _enum_raw_width(lookup[field.type.inner])
    return field.type.kind


def serialize(graph, root, max_size=2 * 1024 * 1024, header_fn=None):
    """Serialize a restored graph (its root ``DagrNode``) → ``bytes``. ``max_size`` bounds the
    buffer and sets the back-reference placeholder width (2 MiB → 4 B, 1024 → 2 B); it must match
    across producers for byte-identity.

    ``header_fn`` attaches a customizable header ("spec/15-customizable-header.md" §7.1): it is
    called with ``(original_offset, body_bytes)`` and returns the header value (a ``dict``
    field→value, or a ``DagrNode`` of the graph's header type). The body is framed exactly as
    the header-less form; the header is packed and prepended, and the framing word's stored
    offset is bumped by the header span ``H`` (§4)."""
    if graph.root_type is None or graph.root_type.kind != "ref":
        raise NotImplementedError("only ref-root graphs supported so far")
    graph = runtime_graph(graph)
    b = Builder(max_size)
    off = node_offset(_store_node(graph, b, graph.root_type.inner, root))
    max_align = graph._max_align
    if max_align is None:
        root_node = graph.lookup.get(graph.root_type.inner)
        max_align = _graph_max_alignment(root_node, graph.lookup) if isinstance(root_node, Node) else 1
        graph._max_align = max_align
    if header_fn is None:
        if max_align > 1:
            b.store_finish_alignment_padding(off, max_align)
        b.store_leb((b.cursor - off) << 2)         # framing: rootDist<<2 | headerFlags(0)
        return b.make_data()

    # ── Customizable header (spec 15 §4/§7.1) ──────────────────────────────────
    from .dagr_reader import DagrError
    from .dagr_model import DagrNode
    if graph.header is None:
        raise DagrError("header_fn given but the graph declares no header")
    if max_align > 1:
        raise NotImplementedError("customizable header + aligned arrays not yet supported (Python)")
    original_offset = b.cursor - off               # distance from body start to root (relative)
    body = b.make_data()                           # body bytes only — the signed preimage input
    hv = header_fn(original_offset, body)
    header_node = hv if isinstance(hv, DagrNode) else DagrNode(graph.header.name, dict(hv))
    hb = Builder(max_size)
    _store_packed_block(graph, hb, graph.header, header_node)  # header is ALWAYS packed (§5)
    header_bytes = hb.make_data()                  # [LEB(Hcontent)][Hcontent]
    H = len(header_bytes)
    stored_offset = ((original_offset + H) << 2) | 0b01        # header_bit=1, kind=0 (§2)
    fb = Builder(max_size)
    fb.store_leb(stored_offset)
    return fb.make_data() + header_bytes + body


def _store_node(graph, b, type_name, node):
    """Store one node (dispatch by declared shape) → a NodeStoreRef (``{off}`` /
    ``{pending}``)."""
    decl = graph.lookup[type_name]
    if decl.frozen and decl.packed:
        return _store_frozen_packed_block(graph, b, decl, node)
    if decl.packed:
        return _store_packed_block(graph, b, decl, node)
    if decl.frozen:
        return _store_frozen_node(graph, b, decl, node)
    return _store_regular_node(graph, b, decl, node)


def _store_packed_inline(graph, b, type_name, node):
    """Store a child inlined inside a packed context. Its block form follows its
    DECLARED shape: a frozen / frozen+packed child → a frozen-packed block; a regular or
    packed child → a plain packed block (a packed tree, not a pointer). Mirrors
    _restore_packed_inline_node / _packed_child_store."""
    decl = graph.lookup[type_name]
    if decl.frozen:
        return _store_frozen_packed_block(graph, b, decl, node, inline=True)
    return _store_packed_block(graph, b, decl, node, inline=True)


def _store_frozen_node(graph, b, decl, node):
    """Frozen (positional, fixed-layout, no vtable) node. Pass 1 stores out-of-line ref
    content; pass 2 stores inline values / pointers in reverse index order; a leading
    presence bitset (one bit per optional field) follows. Mirrors _emit_frozen_store_fn."""
    ref = b.begin_storing(node)
    if ref is not None:
        return ref
    fields = list(indexed_items(graph, decl))
    opt_fields = [(i, f) for i, f in fields if not f.options.is_required]

    # Pass 1 (reverse): out-of-line content for ref fields.
    content = {}
    for idx, field in reversed(fields):
        cls = _field_class(field, graph.lookup)
        val = node.fields.get(field.name)
        if cls == "scalar":
            continue
        if not field.options.is_required and val is None:
            content[idx] = None
        else:
            content[idx] = _ref_content(graph, b, field, val)

    # Pass 2 (reverse): inline value (scalar) or pointer (varlen/array forward, node-ref bidir).
    for idx, field in reversed(fields):
        cls = _field_class(field, graph.lookup)
        val = node.fields.get(field.name)
        if not field.options.is_required and val is None:
            continue                           # absent optional: no bytes
        if cls == "scalar":
            _store_scalar(graph, b, field, val)
        else:
            _ref_pointer(b, field, cls, content[idx])

    # Presence bitset (one bit per optional field, optional-order), ceil(n_opt/8) bytes.
    if opt_fields:
        n_bytes = (len(opt_fields) + 7) // 8
        bs = 0
        for ob, (idx, field) in enumerate(opt_fields):
            if node.fields.get(field.name) is not None:
                bs |= 1 << ob
        b.store_bytes(bs.to_bytes(n_bytes, "little"))

    o = b.cursor
    b.finish_storing(node, o)
    return {"off": o}


def _store_regular_node(graph, b, decl, node):
    """Regular (vtable) node. Pass 1 stores out-of-line ref content (utf8/data content,
    referenced nodes); pass 2 stores each field's inline value or pointer (reverse index
    order); then the vtable takes the per-field offsets in forward index order."""
    ref = b.begin_storing(node)
    if ref is not None:                        # cached offset or in-flight ancestor (cycle)
        return ref
    fields = list(indexed_items(graph, decl))

    # Pass 1 (reverse): out-of-line content for ref fields → a per-index descriptor
    # (a content offset, or a NodeStoreRef for a node-ref). None = absent optional or a
    # write-elided required default (§8.5) — either way the slot is empty.
    content = {}
    for idx, field in reversed(fields):
        val = node.fields.get(field.name)
        if _field_absent(graph, field, decl, val):
            content[idx] = None
            continue
        if _field_class(field, graph.lookup) == "scalar":
            continue
        content[idx] = _ref_content(graph, b, field, val)

    # Pass 2 (reverse): store each field's inline scalar or its pointer; record offset.
    offsets = {}
    for idx, field in reversed(fields):
        val = node.fields.get(field.name)
        if _field_absent(graph, field, decl, val):
            offsets[idx] = None                # absent optional / elided default → empty vtable slot
        elif _field_class(field, graph.lookup) == "scalar":
            offsets[idx] = _store_scalar(graph, b, field, val)
        else:
            offsets[idx] = _ref_pointer(b, field, _field_class(field, graph.lookup), content[idx])

    entries = [offsets[idx] for idx, _ in fields]
    o = b.store_vtable(entries)
    b.finish_storing(node, o)
    return {"off": o}


def _field_absent(graph, field, decl, val):
    """True when a field contributes NO bytes: an absent optional (``val is None``), or a
    required field whose value equals its schema default and is write-elidable (§8.5)."""
    if val is None:
        return not field.options.is_required
    return field_can_elide(graph, field, decl) and _is_elided(field, decl, graph.lookup, val)


def _field_class(field, lookup):
    """Classify a field for the serialize walk: 'scalar' (inline value/enum), 'varlen'
    (utf8/data → forward pointer), 'node_ref' (→ bidirectional pointer), 'union',
    'array'."""
    t = field.type
    if _eff_kind(field, lookup) in _FIXED_STORE or t.kind == "bool":
        return "scalar"
    if t.kind in ("utf8", "data"):
        return "varlen"
    if t.kind == "ref":
        target = lookup.get(t.inner)
        if isinstance(target, Node):
            return "node_ref"
        if isinstance(target, UnionType):
            return "union"
    if t.kind in ("array", "arrayWithOptionals"):
        return "array"
    return "unknown"


def _store_varlen(b, field, value):
    """Store a utf8/data field's out-of-line content; returns the content offset."""
    if field.type.kind == "utf8":
        return b.store_utf8(value, dedup=True)
    return b.store_data(bytes(value))


def _elem_store(kind):
    """A `(builder, value)` callback storing one fixed-width array element (native-LE)."""
    m = _FIXED_STORE[kind]
    return lambda b, v: getattr(b, m)(v)


def _ref_content(graph, b, field, val):
    """Pass-1 for a regular/frozen ref field: store its out-of-line content, returning a
    content offset (varlen / array / aligned) or a NodeStoreRef (node-ref). Aligned
    fields (§11) store via the pre-padded aligned builders; the arena finish-padding is
    added once at the top level."""
    lookup = graph.lookup
    t = field.type
    n = _aligned_n(field)
    if n is not None:                              # aligned array / utf8 / data (§11)
        if t.kind == "utf8":
            return b.store_aligned_utf8(val, n)
        if t.kind == "data":
            return b.store_aligned_bytes(bytes(val), n)
        elem = t.inner.kind
        if elem not in _FIXED_STORE:
            raise NotImplementedError(f"aligned array of {elem!r} not yet supported")
        return b.store_aligned_array(val, _elem_width(elem), n, _elem_store(elem))
    cls = _field_class(field, lookup)
    if cls == "varlen":
        return _store_varlen(b, field, val)
    if cls == "node_ref":
        return _store_node(graph, b, t.inner, val)
    if cls == "array":
        return _store_array_content(graph, b, field, val)
    if cls == "union":                             # apply now; the slot is written in pass 2
        return _apply_union(graph, b, lookup[t.inner], val)
    raise NotImplementedError(f"{field.name}: {cls} ref content not yet supported")


def _ref_pointer(b, field, cls, content):
    """Pass-2 for a regular/frozen ref field: store its pointer/slot given the pass-1
    content. Node-refs get a bidirectional pointer; a union writes its slot; everything
    else a forward pointer."""
    if cls == "node_ref":
        return b.store_bidirectional_pointer(content)
    if cls == "union":
        return b.store_union_slot(content)
    return b.store_forward_pointer(content)


def _store_array_content(graph, b, field, val):
    return _store_array_content_t(graph, b, field.type, val)


def _store_array_content_t(graph, b, t, val):
    """Regular/frozen array block content (forward-pointer target): numeric/float/bool
    via fixed/bool arrays, enum-ref via sub-byte bitset or fixed-width backing int,
    utf8/data via an unsigned pointer table, node-ref via a signed node-ref array (with
    cycle late-binding), union element via the SoA union array. Mirrors _arr_content_expr
    / _enum_arr_content / _ptrtable_content."""
    lookup = graph.lookup
    awo = t.kind == "arrayWithOptionals"
    it = t.inner
    target = lookup.get(it.inner) if it.kind == "ref" else None
    if isinstance(target, UnionType):
        return _store_union_arr(graph, b, target, val, awo)
    if it.kind in ("utf8", "data"):
        elem_store = ((lambda bb, v: bb.store_utf8(v, dedup=True)) if it.kind == "utf8"
                      else (lambda bb, v: bb.store_data(bytes(v))))
        return b.store_ptr_table_array(val, elem_store, signed=False)
    if isinstance(target, Node):
        return b.store_node_ref_array(val, lambda bb, v: _store_node(graph, bb, it.inner, v))
    if isinstance(target, Enum):
        bits = _enum_bits_per_elem(target)
        if bits is not None:
            return b.store_opt_enum_bit_array(val, bits) if awo else b.store_enum_bit_array(val, bits)
        ew = _enum_raw_width(target)
        return (b.store_opt_fixed_array(val, _elem_width(ew), _elem_store(ew)) if awo
                else b.store_fixed_array(val, _elem_store(ew)))
    elem = it.kind
    if elem == "bool":
        return b.store_opt_bool_array(val) if awo else b.store_bool_array(val)
    if awo:
        return b.store_opt_fixed_array(val, _elem_width(elem), _elem_store(elem))
    return b.store_fixed_array(val, _elem_store(elem))


def _store_packed_array_content(graph, b, field, val):
    return _store_packed_array_content_t(graph, b, field.type, val,
                                         field.is_raw_floats or field.is_raw_ints)


def _store_packed_array_content_t(graph, b, t, val, raw):
    """Packed/frozen-packed array block `[blockLen][count-tag][elems]` (no field tag);
    stored inline. Mirrors _packed_arr_body_expr. `raw` (spec/39): f32/f64 → mode 1,
    u16..i64 → forced encoding tag 1; ignored for every other element kind."""
    lookup = graph.lookup
    awo = t.kind == "arrayWithOptionals"
    it = t.inner
    target = lookup.get(it.inner) if it.kind == "ref" else None
    if isinstance(target, UnionType):
        return _store_union_arr_packed(graph, b, target, val, awo)
    if isinstance(target, Node):
        sc = lambda bb, v: _store_packed_inline(graph, bb, it.inner, v)  # noqa: E731
        return b.store_packed_node_array(val, sc, awo)
    if it.kind in ("utf8", "data"):
        elem_store = ((lambda bb, v: bb.store_utf8(v, dedup=False)) if it.kind == "utf8"
                      else (lambda bb, v: bb.store_data(bytes(v))))
        return b.store_packed_complex_array(val, elem_store, awo)
    if isinstance(target, Enum):
        bits = _enum_bits_per_elem(target)
        if bits is not None:
            return (b.store_packed_enum_bit_opt_array(val, bits) if awo
                    else b.store_packed_enum_bit_array(val, bits))
        return (b.store_packed_enum_raw_opt_array(val) if awo
                else b.store_packed_enum_raw_array(val))
    elem = it.kind
    if elem == "bool":
        return b.store_packed_bool_opt_array(val) if awo else b.store_packed_bool_array(val)
    if elem in ("f16", "bf16"):
        bf = elem == "bf16"
        return b.store_packed_f16_opt_array(val, bf) if awo else b.store_packed_f16_array(val, bf)
    if elem in ("f32", "f64"):
        f64 = elem == "f64"
        return (b.store_packed_float_opt_array(val, f64, raw) if awo
                else b.store_packed_float_array(val, f64, raw))
    if _elem_width(elem) == 1:                      # u8/i8: plain count + raw bytes
        return (b.store_packed_byte_opt_array(val, _elem_store(elem)) if awo
                else b.store_packed_byte_array(val, _elem_store(elem)))
    to_leb = (lambda v: zigzag_encode(v)) if elem in _SIGNED_WIDE else (lambda v: v)
    if awo:
        return b.store_packed_int_opt_array(val, _elem_width(elem), to_leb, _elem_store(elem), raw)
    return b.store_packed_int_array(val, _elem_width(elem), to_leb, _elem_store(elem), raw)


def _store_scalar(graph, b, field, value):
    """Store one inline scalar/enum field of ``node``; returns its offset."""
    k = _eff_kind(field, graph.lookup)
    if k == "bool":
        return b.store_u8(1 if value else 0)
    if k in _FIXED_STORE:
        return getattr(b, _FIXED_STORE[k])(value)
    raise NotImplementedError(f"inline scalar kind {k!r} not yet supported")


# ── packed / frozen+packed node shapes ───────────────────────────────────────

def _packed_field_facts(graph, field):
    """The value-independent part of a packed field store: (embedded?, class, eff kind)."""
    lookup = graph.lookup
    emb = field.is_raw_embedded_ref(lookup)
    cls = None if emb else _field_class(field, lookup)
    k = _eff_kind(field, lookup) if cls == "scalar" else None
    return emb, cls, k


def _packed_plan(graph, decl):
    """Per packed node, fields in REVERSE index order with their static store facts."""
    return tuple((idx, field, *_packed_field_facts(graph, field))
                 for idx, field in reversed(indexed_items(graph, decl)))


def _store_packed_field(graph, b, i, field, value, facts=None):
    """Store one packed field: the value, then its ``(index<<1)|rawFlag`` tag. Choice
    ints/floats use LEB when it's strictly smaller than the raw width (tag bit 0 = 0),
    else raw native-LE (bit 0 = 1); u8/i8/bool, utf8/data, and node-refs are always raw.
    Mirrors ``_packed_field_expr``. ``facts`` = the cached ``_packed_field_facts``."""
    lookup = graph.lookup
    emb, cls, k = facts if facts is not None else _packed_field_facts(graph, field)
    if emb:                                        # embedded-graph blob (§17), variable-size → raw tag
        _store_raw_embedded(graph, b, field.type.inner, value)
        b.store_leb((i << 1) | 1)
        return
    if cls == "node_ref":                          # inline-nested child (packed tree), raw tag
        _store_packed_inline(graph, b, field.type.inner, value)
        b.store_leb((i << 1) | 1)
        return
    if cls == "varlen":                            # inline [LEB count][bytes], raw tag
        _store_varlen_inline(b, field, value)
        b.store_leb((i << 1) | 1)
        return
    if cls == "array":                             # inline packed array block, raw tag
        _store_packed_array_content(graph, b, field, value)
        b.store_leb((i << 1) | 1)
        return
    if cls == "union":                             # inline packed union header+payload, EVEN tag
        _store_union_packed(graph, b, lookup[field.type.inner], value)
        b.store_leb(i << 1)
        return
    if cls != "scalar":
        raise NotImplementedError(f"packed field {cls!r} not yet supported")
    if field.is_raw_scalar:                        # spec/39: never probe, always W native-LE + odd tag
        getattr(b, _FIXED_STORE[k])(value)
        b.store_leb((i << 1) | 1)
        return
    if k in ("f16", "bf16"):
        rf = b.store_packed_f16_scalar(value, k == "bf16")
        b.store_leb((i << 1) | (1 if rf else 0))
        return
    if k in ("f32", "f64"):
        rf = (b.store_packed_float64 if k == "f64" else b.store_packed_float32)(value, False)
        b.store_leb((i << 1) | (1 if rf else 0))
        return
    if k in ("u8", "i8", "bool"):                  # single-byte: always raw
        (b.store_u8(1 if value else 0) if k == "bool"
         else getattr(b, _FIXED_STORE[k])(value))
        b.store_leb((i << 1) | 1)
        return
    W = _WIDTH[k]                                   # wider int / enum: LEB-if-smaller, else raw
    lv = zigzag_encode(value) if k in _SIGNED_WIDE else value
    if leb_length(lv) < W:
        b.store_leb(lv)
        b.store_leb(i << 1)
    else:
        getattr(b, _FIXED_STORE[k])(value)
        b.store_leb((i << 1) | 1)


def _store_varlen_inline(b, field, value):
    """Inline (no dedup) utf8/data content [LEB count][bytes] for a packed node."""
    if field.type.kind == "utf8":
        return b.store_utf8(value, dedup=False)
    return b.store_data(bytes(value))


def _store_raw_embedded(graph, b, target_type, node):
    """Store a `raw` node-ref (spec 18 §4) as a standalone embedded-graph blob. The target
    is serialized into its OWN builder (own finish-padding + framing), then embedded as
    ``[LEB payloadLen][pad-count marker][pad-count LEADING pad bytes][blob]`` so the blob's
    first byte is N-aligned. The pad count aligns the blob's ABSOLUTE offset: a graph relies
    on the arena finish-pad (so the backward-computed count is 0), while a sink stream (no
    finish-pad) forces the count via ``b._forced_pd`` — set by the forward ``serialize_sink``
    two-pass, since only there is the blob's absolute position known."""
    lookup = graph.lookup
    lmn = _graph_max_alignment(lookup[target_type], lookup)
    lb = Builder()
    lr = node_offset(_store_node(graph, lb, target_type, node))
    if lmn > 1:
        lb.store_finish_alignment_padding(lr, lmn)
    lb.store_leb((lb.cursor - lr) << 2)            # blob framing
    blob = lb.make_data()
    bef = b.cursor
    if lmn > 1:
        forced = getattr(b, "_forced_pd", None)
        pd = forced if forced is not None else ((-(b.cursor + len(blob))) & (lmn - 1))
        b.store_bytes(blob)                        # backward: forward order → [marker][pad][blob]
        if pd:
            b.store_bytes(bytes(pd))
        b.store_u8(pd)
    else:
        b.store_bytes(blob)
    b.store_leb(b.cursor - bef)                     # payloadLen


def _store_packed_block(graph, b, decl, node, inline=False):
    """A packed (self-sizing) node: ``[LEB blockLen][ (value, tag)* ]`` (fields in reverse
    index order; absent optionals emit nothing). Packed nodes are trees, so a plain dedup
    cache suffices — no cycle in-progress tracking. Mirrors ``_emit_packed_store_fn``.

    ``inline`` = the node is being written INSIDE a packed parent, which has nowhere to put
    a pointer: it must emit the bytes again even if the node was already written. So it
    never READS the dedup cache — but it still populates it, and a later regular parent
    may point into the inlined copy. That is the Rust/Swift `store_packed` rule
    (``spec/07`` §5.1); reading the cache here wrote NOTHING for the second use of a
    shared node — a packed array ``[x, y, x]`` came out two elements long."""
    key = id(node)
    if not inline and key in b.struct_lookup:
        return {"off": b.struct_lookup[key]}
    before = b.cursor
    # `aligned` is silently ignored on packed nodes (spec 12 §3): the wire format is the
    # plain packed encoding, so aligned fields take the ordinary path below.
    fields = node.fields
    for idx, field, emb, cls, k in cached_plan(graph, "packed", decl, _packed_plan):
        val = fields.get(field.name)
        if _field_absent(graph, field, decl, val):
            continue                               # absent optional / elided default: no tag/value
        _store_packed_field(graph, b, idx, field, val, (emb, cls, k))
    b.store_leb(b.cursor - before)                 # blockLen (front of the record)
    o = b.cursor
    b.struct_lookup[key] = o
    return {"off": o}


def _store_frozen_packed_block(graph, b, decl, node, inline=False):
    """A frozen+packed node: ``[LEB blockLen][presence bitset?][encoding bitset?][values]``.
    Presence bitset (one bit per OPTIONAL field, 1 = present); encoding bitset (one bit per
    CHOICE/enc-var field, 1 = raw). Values reverse index order; single-path fields
    (u8/i8/bool/u8-enum/utf8/data/node-ref) are always raw and carry no enc bit. Mirrors
    ``_emit_frozen_packed_store_fn``."""
    key = id(node)
    if not inline and key in b.struct_lookup:   # see _store_packed_block
        return {"off": b.struct_lookup[key]}
    lookup = graph.lookup
    fields = list(indexed_items(graph, decl))
    choice_idx, opt_idx = {}, {}
    for idx, field in fields:
        if _eff_kind(field, lookup) in _CHOICE_KINDS:
            choice_idx[idx] = len(choice_idx)
        if not field.options.is_required:
            opt_idx[idx] = len(opt_idx)
    raw_flags = [False] * len(choice_idx)
    before = b.cursor

    for idx, field in reversed(fields):               # `aligned` ignored in packed shapes (spec 12 §3)
        val = node.fields.get(field.name)
        if not field.options.is_required and val is None:
            continue
        c = choice_idx.get(idx)
        if c is None:                              # single-path (always-raw), no enc bit
            if field.is_raw_embedded_ref(lookup):  # embedded-graph blob (§17), positional
                _store_raw_embedded(graph, b, field.type.inner, val)
                continue
            cls = _field_class(field, lookup)
            if cls == "node_ref":
                _store_packed_inline(graph, b, field.type.inner, val)
            elif cls == "varlen":
                _store_varlen_inline(b, field, val)
            elif cls == "array":
                _store_packed_array_content(graph, b, field, val)
            elif cls == "union":                   # inline packed union header+payload
                _store_union_packed(graph, b, lookup[field.type.inner], val)
            elif cls == "scalar":
                k = _eff_kind(field, lookup)
                b.store_u8(1 if val else 0) if k == "bool" else getattr(b, _FIXED_STORE[k])(val)
            else:
                raise NotImplementedError(f"frozen+packed field {cls!r} not yet supported")
            continue
        k = _eff_kind(field, lookup)
        if field.is_raw_scalar:                    # spec/39: keeps its enc bit (always 1), never probes
            getattr(b, _FIXED_STORE[k])(val)
            raw_flags[c] = True
        elif k in ("f16", "bf16"):
            if b.store_packed_f16_scalar(val, k == "bf16"):
                raw_flags[c] = True
        elif k in ("f32", "f64"):
            if (b.store_packed_float64 if k == "f64" else b.store_packed_float32)(val, False):
                raw_flags[c] = True
        else:
            W = _WIDTH[k]
            lv = zigzag_encode(val) if k in _SIGNED_WIDE else val
            if leb_length(lv) < W:
                b.store_leb(lv)
            else:
                getattr(b, _FIXED_STORE[k])(val)
                raw_flags[c] = True

    if choice_idx:                                 # encoding bitset (1 = raw), then...
        b.store_bytes(_pack_bits([1 if r else 0 for r in raw_flags]))
    if opt_idx:                                    # ...presence bitset (1 = present)
        present = [1 if node.fields.get(field.name) is not None else 0
                   for idx, field in fields if idx in opt_idx]
        b.store_bytes(_pack_bits(present))
    b.store_leb(b.cursor - before)                 # blockLen
    o = b.cursor
    b.struct_lookup[key] = o
    return {"off": o}


def _pack_bits(bits):
    """Pack a list of 0/1 into a little-endian byte string (bit i → byte i>>3, pos i&7)."""
    out = bytearray((len(bits) + 7) // 8)
    for i, v in enumerate(bits):
        if v:
            out[i >> 3] |= 1 << (i & 7)
    return bytes(out)


# ── unions ───────────────────────────────────────────────────────────────────
# DagrUnion carries `.tag` (variant label) + `.value` (payload). union.types is an
# ordered list of (label, EntryType); the variant index `vi` is its position.

_UNION_VALUE_STORE = {
    "u8": "store_u8", "u16": "store_u16", "u32": "store_u32", "u64": "store_u64",
    "i8": "store_i8", "i16": "store_i16", "i32": "store_i32", "i64": "store_i64",
    "f32": "store_f32", "f64": "store_f64", "f16": "store_f16", "bf16": "store_bf16",
}
# Packed union raw code per width (0=LEB, 1=1B, 2=2B, 3=4B, 4=8B, 5=packed float, 6=block).
_PACKED_RAW_CODE = {"u16": 2, "u32": 3, "u64": 4, "i16": 2, "i32": 3, "i64": 4}


def _union_variant(union, tag):
    for vi, (label, vt) in enumerate(union.types):
        if label == tag:
            return vi, vt
    raise ValueError(f"bad union tag {tag!r} for {union.name}")


def _union_bits_per(union):
    cap = union.capacity
    if cap <= 2:
        return 1
    if cap <= 4:
        return 2
    if cap <= 16:
        return 4
    if cap <= 255:
        return 8
    if cap <= 65535:
        return 16
    return 32


def _union_arr_val(k, val):
    """Raw bit-pattern a union-array VALUE slot stores for element kind `k`."""
    if k in ("u8", "u16", "u32", "u64"):
        return val
    if k == "i8":
        return val & 0xFF
    if k == "i16":
        return val & 0xFFFF
    if k == "i32":
        return val & 0xFFFFFFFF
    if k == "i64":
        return val & 0xFFFFFFFFFFFFFFFF
    if k == "f32":
        return f32_bits(val)
    if k == "f64":
        return f64_bits(val)
    if k == "f16":
        return f32_to_f16_bits(val)
    if k == "bf16":
        return f32_to_bf16_bits(val)
    if k == "bool":
        return 1 if val else 0
    raise NotImplementedError(f"union-array value kind {k!r}")


def _apply_union(graph, b, union, u):
    """Regular/frozen union field: store out-of-line content now, return an
    ``{'id','emit'}`` slot descriptor (``emit`` writes the inline value / pointer in the
    value pass). Mirrors ``_union_apply_case``."""
    lookup = graph.lookup
    vi, vt = _union_variant(union, u.tag)
    k = vt.kind
    val = u.value
    if k == "bool":
        return {"id": vi, "emit": lambda bb: bb.store_u8(1 if val else 0)}
    if k in _UNION_VALUE_STORE:                    # inline value variant
        m = _UNION_VALUE_STORE[k]
        return {"id": vi, "emit": lambda bb: getattr(bb, m)(val)}
    if k == "utf8":
        o = b.store_utf8(val, dedup=True)
        return {"id": vi, "emit": lambda bb: bb.store_forward_pointer(o)}
    if k == "data":
        o = b.store_data(bytes(val))
        return {"id": vi, "emit": lambda bb: bb.store_forward_pointer(o)}
    if k == "ref":
        inner = lookup.get(vt.inner)
        if isinstance(inner, Enum):
            return {"id": vi, "emit": lambda bb: bb.store_u8(int(val))}
        if isinstance(inner, Node):
            o = _store_node(graph, b, vt.inner, val)     # NodeStoreRef (bidir pointer)
            return {"id": vi, "emit": lambda bb: bb.store_bidirectional_pointer(o)}
        if isinstance(inner, UnionType):                 # nested union: fwd ptr to no-wc slot
            o = _store_union_nested(graph, b, inner, val)
            return {"id": vi, "emit": lambda bb: bb.store_forward_pointer(o)}
    if k in ("array", "arrayWithOptionals"):             # array variant: payload + fwd ptr
        o = _store_array_content_t(graph, b, vt, val)
        return {"id": vi, "emit": lambda bb: bb.store_forward_pointer(o)}
    raise NotImplementedError(f"union variant {u.tag}:{k}")


def _store_union_slot_field(graph, b, union, u):
    return b.store_union_slot(_apply_union(graph, b, union, u))


def _store_union_nested(graph, b, union, u):
    """Nested-union value form: same value/pointer as a field union, but the tag LEB is
    ``id<<2`` (no width code) so the byte matches Rust/Swift."""
    return b.store_nested_union_slot(_apply_union(graph, b, union, u))


def _apply_union_packed(graph, b, union, u):
    """Packed union: store the self-describing payload, return ``{'id','code'}`` (typeId +
    3-bit union code). Mirrors ``_apply_union_packed_case``."""
    lookup = graph.lookup
    vi, vt = _union_variant(union, u.tag)
    k = vt.kind
    val = u.value
    if k in ("u8", "i8"):
        getattr(b, _UNION_VALUE_STORE[k])(val)
        return {"id": vi, "code": 1}
    if k in ("u16", "u32", "u64"):
        if leb_length(val) < _WIDTH[k]:
            b.store_leb(val)
            return {"id": vi, "code": 0}
        getattr(b, _UNION_VALUE_STORE[k])(val)
        return {"id": vi, "code": _PACKED_RAW_CODE[k]}
    if k in ("i16", "i32", "i64"):
        zz = zigzag_encode(val)
        if leb_length(zz) < _WIDTH[k]:
            b.store_leb(zz)
            return {"id": vi, "code": 0}
        getattr(b, _UNION_VALUE_STORE[k])(val)
        return {"id": vi, "code": _PACKED_RAW_CODE[k]}
    if k in ("f16", "bf16"):
        bits = (f32_to_bf16_bits if k == "bf16" else f32_to_f16_bits)(val)
        if leb_length(bits) < 2:
            b.store_leb(bits)
            return {"id": vi, "code": 0}
        b.store_u16(bits)
        return {"id": vi, "code": 2}
    if k == "f32":
        return {"id": vi, "code": 3 if b.store_packed_float32(val, False) else 5}
    if k == "f64":
        return {"id": vi, "code": 4 if b.store_packed_float64(val, False) else 5}
    if k == "bool":
        b.store_u8(1 if val else 0)
        return {"id": vi, "code": 1}
    if k == "utf8":
        b.store_utf8(val, dedup=False)
        return {"id": vi, "code": 6}
    if k == "data":
        b.store_data(bytes(val))
        return {"id": vi, "code": 6}
    if k == "ref":
        inner = lookup.get(vt.inner)
        if isinstance(inner, Enum):
            b.store_u8(int(val))
            return {"id": vi, "code": 1}
        if isinstance(inner, Node):
            _store_packed_inline(graph, b, vt.inner, val)
            return {"id": vi, "code": 6}
        if isinstance(inner, UnionType):                 # size-prefixed nested packed union
            bf = b.cursor
            _store_union_packed(graph, b, inner, val)
            b.store_leb(b.cursor - bf)
            return {"id": vi, "code": 6}
    if k in ("array", "arrayWithOptionals"):
        _store_packed_array_content_t(graph, b, vt, val, False)
        return {"id": vi, "code": 6}
    raise NotImplementedError(f"packed union variant {u.tag}:{k}")


def _store_union_packed(graph, b, union, u):
    a = _apply_union_packed(graph, b, union, u)
    return b.store_leb((a["id"] << 3) | a["code"])


def _apply_union_arr_elem(graph, b, union, u):
    """One union-array element: store content (pointer/bidir), return the SoA slot
    descriptor ``{'kind','val','tid'}``. Mirrors ``_union_arr_elem_case``."""
    lookup = graph.lookup
    vi, vt = _union_variant(union, u.tag)
    k = vt.kind
    val = u.value
    if k in _UNION_VALUE_STORE or k == "bool":     # value variant → raw bits, nothing stored
        return {"kind": "v", "val": _union_arr_val(k, val), "tid": vi}
    if k == "utf8":
        return {"kind": "p", "val": b.store_utf8(val, dedup=True), "tid": vi}
    if k == "data":
        return {"kind": "p", "val": b.store_data(bytes(val)), "tid": vi}
    if k == "ref":
        inner = lookup.get(vt.inner)
        if isinstance(inner, Enum):
            return {"kind": "v", "val": int(val), "tid": vi}
        if isinstance(inner, Node):                # node variant → bidir slot
            return {"kind": "b", "val": node_offset(_store_node(graph, b, vt.inner, val)), "tid": vi}
        if isinstance(inner, UnionType):           # nested union element → no-wc slot
            return {"kind": "p", "val": _store_union_nested(graph, b, inner, val), "tid": vi}
    if k in ("array", "arrayWithOptionals"):       # nested array element → fwd-ptr payload
        return {"kind": "p", "val": _store_array_content_t(graph, b, vt, val), "tid": vi}
    raise NotImplementedError(f"union-array variant {u.tag}:{k}")


def _store_union_arr(graph, b, union, arr, opt):
    """Regular/frozen union array (SoA): apply each element (reverse), then store the
    slot table + typeId section via ``store_union_array``. Mirrors ``_emit_union_array_fns``."""
    applied = []
    for i in range(len(arr) - 1, -1, -1):
        u = arr[i]
        applied.append(None if u is None else _apply_union_arr_elem(graph, b, union, u))
    return b.store_union_array(len(arr), applied, _union_bits_per(union), opt)


def _store_union_arr_packed(graph, b, union, arr, opt):
    """Packed union array (two-section §4.9): [blockLen][count][nil bs?][LEB hss?]
    [headers][payloads]. Mirrors ``_storeUnionArr{U}Packed``."""
    before = b.cursor
    count = len(arr)
    hdrs = []
    for i in range(count - 1, -1, -1):
        u = arr[i]
        if opt and u is None:
            hdrs.append(None)
            continue
        hdrs.append(_apply_union_packed(graph, b, union, u))
    hdr_start = b.cursor
    for h in hdrs:
        if h is not None:
            b.store_leb((h["id"] << 3) | h["code"])
    if opt:
        b.store_leb(b.cursor - hdr_start)          # header-section size
        nil = bytearray((count + 7) // 8)
        for j in range(count):
            idx = count - 1 - j
            if hdrs[j] is None:
                nil[idx >> 3] |= 1 << (idx & 7)
        b.store_bytes(nil)
    b.store_leb(count)
    return b.store_leb(b.cursor - before)
