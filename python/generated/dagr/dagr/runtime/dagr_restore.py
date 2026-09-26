"""Dagr reflective restore (Phase 1) — bytes → a plain Python object graph, by walking
a live ``dagr_dsl.DataGraph``.

A direct, type-directed schema walk (plan "27 …" §4/§5): the root type is known, each
field's type is read off the live ``Field``/``EntryType`` DSL objects, and a node
reached twice (a shared node or a cycle) materialises exactly once via a
``pos → DagrNode`` dedup dict — create the shell, register it *before* filling its ref
fields, then fill (the same create-then-register-then-fill order as every target).

**Coverage so far (incremental matrix walk):** **all four node shapes** — regular
(vtable), packed (self-sizing, per-field ``(index<<1)|raw`` tags), frozen (positional +
presence bitset over optional fields), and frozen+packed (block-length + presence bitset
+ encoding bitset over encoding-variable fields). Field kinds: scalar / ``utf8`` /
``data`` (required + optional), **enums** (raw int of the backing width), **node-refs**
(ZigZag V62 pointer + shared/cycle dedup, across shapes), **integer arrays** (regular:
forward pointer → ``[count][native-LE]``), and **unions** across value-scalar / enum /
node-ref / utf8 / data / array / **nested-union** variants — including **regular/frozen
array-of-union (SoA)** (``_restore_union_array``). Still raising ``NotImplementedError``
(gated per step): **packed-shape** union arrays, packed float scalars, ``raw`` node-refs
(embedded graphs, spec 18), and aligned fields.
"""
from dagr.dsl import Enum, Node, UnionType
from dagr.codegen.shared import _enum_raw_width, _enum_bits_per_elem, _graph_max_alignment

from .dagr_reader import (
    DagrError, read_framing, restore_vtable, read_zigzag_v62, read_v62,
    read_leb, read_zigzag_leb,
    read_u8, read_u16, read_u32, read_u64,
    read_i8, read_i16, read_i32, read_i64,
    read_f16, read_bf16, read_f32, read_f64, read_bool,
    read_utf8, read_data,
    decode_packed_float32, decode_packed_float64, decode_packed_f16,
)
from .dagr_model import (DagrNode, DagrUnion, runtime_graph, indexed_items, indexed_map,
                         field_can_elide, new_node, new_union)
from .dagr_defaults import synth_default as _synth_default

import contextlib


# ── Optional NumPy zero-copy views over contiguous native-LE numeric arrays ────
# When enabled (via ``numpy_array_views()``), a numeric ``array`` field stored as a single
# contiguous native-LE block — regular/frozen arrays, packed all-raw int arrays, and packed
# raw-mode float arrays (all non-``arrayWithOptionals``) — is returned as a **zero-copy**
# ``numpy.ndarray`` view that shares memory with the input buffer, instead of a Python list.
# Same technique as the SharedBuffer reader's ``numpy_view`` (``np.frombuffer``). NumPy is
# optional: if it is unavailable (or the element type has no NumPy dtype, e.g. ``bf16``),
# the ordinary list path is used. Consumers: the Arrow/pandas bridge (``dagr_arrow``).
_NUMPY_VIEWS = False

_NPY_ARRAY_DTYPE = {
    "u8": "uint8", "i8": "int8", "u16": "uint16", "i16": "int16",
    "u32": "uint32", "i32": "int32", "u64": "uint64", "i64": "int64",
    "f16": "float16", "f32": "float32", "f64": "float64",   # bf16/bool: no view (list path)
}


@contextlib.contextmanager
def numpy_array_views():
    """Within this block, contiguous native-LE numeric arrays restore as zero-copy NumPy views."""
    global _NUMPY_VIEWS
    prev = _NUMPY_VIEWS
    _NUMPY_VIEWS = True
    try:
        yield
    finally:
        _NUMPY_VIEWS = prev


def _array_view(mv, k, offset, count):
    """A zero-copy ``np.frombuffer`` view over a ``count``-element native-LE numeric block at
    ``offset``, or ``None`` if views are off / NumPy is absent / ``k`` has no NumPy dtype."""
    if not _NUMPY_VIEWS or k not in _NPY_ARRAY_DTYPE:
        return None
    try:
        import numpy as np
    except ImportError:
        return None
    return np.frombuffer(mv, dtype=_NPY_ARRAY_DTYPE[k], count=count, offset=offset)

_INT_WIDTH = {"u8": 1, "i8": 1, "u16": 2, "i16": 2, "u32": 4, "i32": 4, "u64": 8, "i64": 8}
_UNSIGNED = {"u8", "u16", "u32", "u64"}
_SCALAR_WIDTH = {**_INT_WIDTH, "f16": 2, "bf16": 2, "f32": 4, "f64": 8, "bool": 1}

_SCALAR = {
    "u8": read_u8, "u16": read_u16, "u32": read_u32, "u64": read_u64,
    "i8": read_i8, "i16": read_i16, "i32": read_i32, "i64": read_i64,
    "f16": read_f16, "bf16": read_bf16, "f32": read_f32, "f64": read_f64,
    "bool": read_bool,
}


def restore(graph, data, header_gate=None):
    """Restore a DataGraph buffer → the root ``DagrNode`` (or ``None`` if root-less).

    ``header_gate`` handles a customizable header ("spec/15-customizable-header.md" §8): it runs
    *before* the body is decoded and receives ``(header_fields_dict, original_offset,
    body_bytes)``; it may raise to abort (verify-before-parse). The body decode is unchanged —
    all offsets are relative, so ``root_start`` already accounts for the header span."""
    mv = memoryview(data)
    framing, framing_len = read_leb(mv, 0)
    root_off = framing >> 2
    kind = (framing >> 1) & 1
    has_header = framing & 1
    root_start = framing_len + root_off
    if kind != 0:
        raise DagrError("not a DataGraph (framing kind != 0)")
    if graph.root_type is None or graph.root_type.kind != "ref":
        raise NotImplementedError("only ref-root graphs supported so far")
    graph = runtime_graph(graph)
    if has_header:
        if graph.header is None:
            raise DagrError("buffer carries a header but the graph declares none")
        # The header is a packed node at framing_len; decode it, reconstruct the pre-header
        # (original) root offset, and run the gate before touching the body.
        block_len, after = read_leb(mv, framing_len)
        header_span = (after - framing_len) + block_len            # H = lebLen + Hcontent
        header_node = _restore_packed_header(graph, mv, graph.header, framing_len)
        original_offset = root_off - header_span
        body = bytes(mv[framing_len + header_span:])
        if header_gate is not None:
            header_gate(dict(header_node.fields), original_offset, body)
    elif graph.header is not None and header_gate is not None:
        raise DagrError("graph declares a header but the buffer has none")
    return _restore_node(graph, mv, graph.root_type.inner, root_start, {})


def _restore_node(graph, mv, type_name, start, seen):
    if start in seen:                          # shared node / cycle → materialise once
        return seen[start]
    node = graph.lookup[type_name]
    if node.frozen and node.packed:
        return _restore_frozen_packed_node(graph, mv, node, type_name, start, seen)
    if node.frozen:
        return _restore_frozen_node(graph, mv, node, type_name, start, seen)
    if node.packed:
        return _restore_packed_node(graph, mv, node, type_name, start, seen)
    return _restore_regular_node(graph, mv, node, type_name, start, seen)


def _restore_regular_node(graph, mv, node, type_name, start, seen):
    shell = new_node(graph, type_name)
    seen[start] = shell                        # register BEFORE filling ref fields
    field_pos = restore_vtable(mv, start)
    for idx, field in indexed_items(graph, node):
        pos = field_pos[idx] if idx < len(field_pos) else None
        if pos is None:                        # absent: synthesize an elided required default (§8.5)
            shell.fields[field.name] = (_synth_default(field, node, graph.lookup)
                                        if field_can_elide(graph, field, node) else None)
        else:
            shell.fields[field.name] = _restore_value(graph, mv, field.type, pos, seen)
    return shell


def _restore_packed_node(graph, mv, node, type_name, start, seen):
    """A packed (self-sizing) node: ``[LEB block-length][ (tag, value)* ]``. The tag is
    ``(field_index << 1) | raw_flag`` (bit 0: 1 → the value is stored raw native-LE,
    0 → LEB / ZigZag-LEB). Absent optional fields emit no tag; they restore to ``None``.
    A node-ref field inlines its child as a nested packed block (see
    ``_restore_packed_inline_node``) — a packed tree, not pointers.
    """
    shell, _ = _restore_packed_inline_node(graph, mv, type_name, start, seen)
    return shell


def _restore_raw_embedded(graph, mv, target_type, pos):
    """A ``raw`` node-ref (spec 18) stored in a packed/frozen-packed parent → an opaque
    standalone-graph blob → ``(DagrNode, new_pos)``. Payload = ``[LEB payloadLen]
    [pad byte if the target graph is alignment-bearing][standalone .dagr blob][trailing
    pad]``. The blob is a self-contained graph opened with the target's OWN shape at its
    own framing root; ``payloadLen`` covers everything after the length LEB, so the parent
    scan resumes past the whole payload. (In a regular/frozen vtable parent, ``raw`` on a
    node-ref degrades to an ordinary node-ref and never reaches here.)"""
    payload_len, after_len = read_leb(mv, pos)
    has_pad = _graph_max_alignment(graph.lookup[target_type], graph.lookup) > 1
    # Alignment-bearing blob: a 1-byte pad-count marker, then that many LEADING pad bytes,
    # then the blob framing (whose first byte is N-aligned). In a graph the arena
    # finish-pad already aligns the blob so the count is 0 (marker byte skipped, nothing
    # more); a sink stream has no finish-pad, so the marker records a real leading pad.
    if has_pad:
        pd = mv[after_len]                             # pad-count marker
        bs = after_len + 1 + pd
    else:
        bs = after_len
    fr, after_fr = read_leb(mv, bs)
    root = after_fr + (fr >> 2)
    node = _restore_node(graph, mv, target_type, root, {})   # fresh seen — self-contained blob
    return node, after_len + payload_len


def _restore_packed_header(graph, mv, decl, pos):
    """Decode the customizable header (spec 15 §5) — a plain packed block ``[LEB blockLen]
    [(tag,value)*]`` — into a ``DagrNode``. Takes the header ``decl`` directly (the header
    is not in ``graph.lookup``); its flat scalar/utf8/data fields need no lookup."""
    shell = DagrNode(decl.name)
    block_len, p = read_leb(mv, pos)
    end = p + block_len
    idx_fields = decl.indexed_fields()
    while p < end:
        tag, p = read_leb(mv, p)
        if (tag >> 1) not in idx_fields:
            raise DagrError("header packed field tag out of range")
        field = idx_fields[tag >> 1]
        shell.fields[field.name], p = _restore_packed_value(graph, mv, field.type, tag & 1, p, {})
    for field in idx_fields.values():          # absent optionals → None
        shell.fields.setdefault(field.name, None)
    return shell


def _restore_packed_inline_node(graph, mv, type_name, pos, seen):
    """Restore a node encoded as a self-sizing block at ``pos`` → ``(DagrNode, new_pos)``.
    Used both for a top-level/ref-target packed node and for a node inlined inside a
    packed parent. The child's block form follows its **declared shape**: a regular or
    packed child is a plain packed block ``[blockLen][(tag,value)*]``; a **frozen** or
    **frozen+packed** child is a frozen-packed block ``[blockLen][presence][encoding]
    [values]`` (re-encoded self-sizing for inlining)."""
    if pos in seen:
        node_end = read_leb(mv, pos)                       # skip the block on a revisit
        return seen[pos], node_end[1] + node_end[0]
    node = graph.lookup[type_name]
    if node.frozen:                                        # frozen / frozen+packed child
        shell = _restore_frozen_packed_node(graph, mv, node, type_name, pos, seen)
        block_len, after = read_leb(mv, pos)
        return shell, after + block_len
    shell = new_node(graph, type_name)
    seen[pos] = shell
    block_len, p = read_leb(mv, pos)
    end = p + block_len
    idx_fields = indexed_map(graph, node)
    while p < end:
        tag, p = read_leb(mv, p)
        if (tag >> 1) not in idx_fields:
            raise NotImplementedError("packed field tag out of range")
        field = idx_fields[tag >> 1]
        if field.is_raw_embedded_ref(graph.lookup):     # embedded-graph blob (spec 18)
            shell.fields[field.name], p = _restore_raw_embedded(graph, mv, field.type.inner, p)
        else:
            shell.fields[field.name], p = _restore_packed_value(
                graph, mv, field.type, tag & 1, p, seen)
    fields = shell.fields
    for field in idx_fields.values():          # fields with no tag were absent → synth default (§8.5)
        if field.name not in fields:
            fields[field.name] = (_synth_default(field, node, graph.lookup)
                                  if field_can_elide(graph, field, node) else None)
    return shell, end


def _restore_frozen_node(graph, mv, node, type_name, start, seen):
    """A frozen (positional, fixed-layout) node: fields stored in index order, native-LE,
    contiguous, with **no vtable and no per-field tags**. If the node has any optional
    field, a **presence bitset** (LEB, one bit per field) precedes the fields; a clear
    bit → the field is absent (no bytes) and restores to ``None``.
    """
    shell = new_node(graph, type_name)
    seen[start] = shell
    idx_fields = indexed_map(graph, node)
    nfields = (max(idx_fields) + 1) if idx_fields else 0
    p = start
    if any(not f.options.is_required for f in idx_fields.values()):
        # Presence bitset: a RAW fixed-width little-endian bitset (ceil(n/8) bytes),
        # NOT a LEB — one bit per field, set = present.
        nbytes = (nfields + 7) // 8
        presence = int.from_bytes(bytes(mv[p:p + nbytes]), "little")
        p += nbytes
    else:
        presence = (1 << nfields) - 1
    for idx in sorted(idx_fields):
        field = idx_fields[idx]
        if (presence >> idx) & 1:
            shell.fields[field.name], p = _restore_frozen_value(graph, mv, field.type, p, seen)
        else:
            shell.fields[field.name] = None
    return shell


def _restore_frozen_value(graph, mv, t, pos, seen):
    """Decode one frozen (positional, native-LE) field value → ``(value, new_pos)``."""
    k = t.kind
    if k in _SCALAR_WIDTH:                          # int / float / bool, all native-LE fixed
        return _SCALAR[k](mv, pos), pos + _SCALAR_WIDTH[k]
    if k == "utf8":
        ptr, after = read_v62(mv, pos)         # forward pointer → [LEB len][bytes]
        return read_utf8(mv, after + ptr)[0], after
    if k == "data":
        ptr, after = read_v62(mv, pos)
        return read_data(mv, after + ptr)[0], after
    if k == "ref":
        target = graph.lookup[t.inner]
        if isinstance(target, Enum):
            w = _enum_raw_width(target)
            return _SCALAR[w](mv, pos), pos + _INT_WIDTH[w]
        if isinstance(target, Node):
            offset, after = read_zigzag_v62(mv, pos)
            return _restore_node(graph, mv, t.inner, after + offset, seen), after
        if isinstance(target, UnionType):
            # Frozen unions use the regular union encoding, positional in the layout.
            return _restore_union(graph, mv, target, pos, seen)
    if k in ("array", "arrayWithOptionals"):
        # Frozen array slot holds a FORWARD pointer to the same array block a regular
        # node uses; the next positional field follows the pointer.
        ptr, after = read_v62(mv, pos)
        return _restore_array(graph, mv, t, after + ptr, seen, k == "arrayWithOptionals"), after
    raise NotImplementedError(f"frozen value kind {k!r} not yet supported")


_ENC_VAR_SCALAR = {"f32", "f64", "f16", "bf16", "u16", "u32", "u64", "i16", "i32", "i64"}


def _is_enc_var(graph, t):
    """Does a field carry an encoding-bitset bit? Multi-byte scalars and non-`u8` enums
    have a raw/LEB choice; ``u8`` / ``i8`` / ``bool`` / ``u8``-enums do not."""
    if t.kind in _ENC_VAR_SCALAR:
        return True
    if t.kind == "ref":
        inner = graph.lookup.get(t.inner)
        return isinstance(inner, Enum) and _enum_raw_width(inner) != "u8"
    return False


def _restore_frozen_packed_node(graph, mv, node, type_name, start, seen):
    """Frozen + packed: ``[LEB block-length][presence bitset?][encoding bitset?][values]``.
    Positional (no per-field tags) like frozen, self-sizing like packed. The **presence
    bitset** covers only the *optional* fields (indexed in field order among them); the
    **encoding bitset** covers only the *encoding-variable* fields (``_is_enc_var``), each
    bit = raw(1)/LEB(0). Both are omitted when their field count is 0.
    """
    shell = new_node(graph, type_name)
    seen[start] = shell
    idx_fields = indexed_map(graph, node)
    fields = [idx_fields[i] for i in sorted(idx_fields)]
    n_nil = sum(1 for f in fields if not f.options.is_required)
    n_enc = sum(1 for f in fields if _is_enc_var(graph, f.type))
    _, p = read_leb(mv, start)                             # block length (bounds only)
    presence = -1
    if n_nil:
        bs = (n_nil + 7) // 8
        presence = int.from_bytes(bytes(mv[p:p + bs]), "little")
        p += bs
    encoding = 0
    if n_enc:
        bs = (n_enc + 7) // 8
        encoding = int.from_bytes(bytes(mv[p:p + bs]), "little")
        p += bs
    nil_bit = enc_bit = 0
    for f in fields:
        present = True
        if not f.options.is_required:
            present = (presence >> nil_bit) & 1
            nil_bit += 1
        # Non-encoding-variable fields (u8/i8/bool/u8-enum) are ALWAYS raw native-LE;
        # only encoding-variable fields consult the encoding bitset.
        if _is_enc_var(graph, f.type):
            raw_flag = (encoding >> enc_bit) & 1
            enc_bit += 1
        else:
            raw_flag = 1
        if present:
            if f.is_raw_embedded_ref(graph.lookup):     # embedded-graph blob (spec 18)
                shell.fields[f.name], p = _restore_raw_embedded(graph, mv, f.type.inner, p)
            else:
                shell.fields[f.name], p = _restore_packed_value(graph, mv, f.type, raw_flag, p, seen)
        else:
            shell.fields[f.name] = None
    return shell


def _restore_packed_value(graph, mv, t, raw_flag, pos, seen):
    """Decode one packed field value → ``(value, new_pos)``."""
    k = t.kind
    if k in _INT_WIDTH:
        if raw_flag:
            return _SCALAR[k](mv, pos), pos + _INT_WIDTH[k]
        return read_leb(mv, pos) if k in _UNSIGNED else read_zigzag_leb(mv, pos)
    if k in ("f32", "f64"):
        if raw_flag:
            return _SCALAR[k](mv, pos), pos + _SCALAR_WIDTH[k]
        dec = decode_packed_float32 if k == "f32" else decode_packed_float64
        v, nb = dec(mv, pos)
        return v, pos + nb
    if k in ("f16", "bf16"):
        # Packed f16/bf16: raw flag → native 2-byte; else a special-value sub-tag.
        if raw_flag:
            return _SCALAR[k](mv, pos), pos + 2
        v, nb = decode_packed_f16(mv, pos)
        return v, pos + nb
    if k == "bool":
        if raw_flag:
            return mv[pos] != 0, pos + 1
        v, p = read_leb(mv, pos)
        return v != 0, p
    if k == "utf8":
        return read_utf8(mv, pos)
    if k == "data":
        return read_data(mv, pos)
    if k == "ref":
        target = graph.lookup[t.inner]
        if isinstance(target, Enum):
            w = _enum_raw_width(target)
            if raw_flag:
                return _SCALAR[w](mv, pos), pos + _INT_WIDTH[w]
            return read_leb(mv, pos)           # enum backing is unsigned
        if isinstance(target, Node):
            # A node-ref child is inlined as a packed block regardless of its declared
            # shape — a frozen/regular child is re-encoded in packed form when nested in
            # a packed parent (the reference's alternate "{Name}PackedAccessor").
            return _restore_packed_inline_node(graph, mv, t.inner, pos, seen)
        if isinstance(target, UnionType):
            return _restore_packed_union(graph, mv, target, pos, seen)
    if k in ("array", "arrayWithOptionals"):
        return _restore_packed_array(graph, mv, t, pos, k == "arrayWithOptionals", seen)
    raise NotImplementedError(f"packed value kind {k!r} not yet supported")


def _restore_packed_union(graph, mv, union, pos, seen):
    """A union inside a packed node → ``(DagrUnion, new_pos)``. The tag is
    ``(type_id << 3) | code``; the 3-bit ``code`` records payload framing for
    schema-less skipping (0 → LEB/ZigZag, 1..4 → raw N bytes, 5 → packed float,
    6 → a self-sizing block: inline node / [size][nested union] / array)."""
    tag, after = read_leb(mv, pos)
    label, vtype = union.types[tag >> 3]
    value, new_pos = _restore_packed_union_payload(graph, mv, vtype, tag & 7, after, seen)
    return new_union(graph, union, label, value), new_pos


def _restore_packed_union_payload(graph, mv, vtype, code, ep, seen):
    """Decode a packed-union payload at ``ep`` given the 3-bit ``code`` (mirrors the
    reference ``read{Union}PackedElem``). The ``code`` — not a binary raw flag — selects
    float framing (5 → self-describing packed, else raw) and nested-union framing
    (6 → ``[size LEB][inner packed union]``); every other type maps ``raw = code != 0``."""
    k = vtype.kind
    if k in ("f32", "f64"):
        if code == 5:
            dec = decode_packed_float32 if k == "f32" else decode_packed_float64
            v, nb = dec(mv, ep)
            return v, ep + nb
        return _SCALAR[k](mv, ep), ep + _SCALAR_WIDTH[k]
    if k in ("f16", "bf16"):
        if code == 0:
            v, nb = decode_packed_f16(mv, ep)
            return v, ep + nb
        return _SCALAR[k](mv, ep), ep + 2
    if k == "ref" and isinstance(graph.lookup.get(vtype.inner), UnionType):
        # Nested union (code 6): payload = [size LEB][inner union's packed encoding].
        _, inner_ep = read_leb(mv, ep)
        val, new_pos = _restore_packed_union(graph, mv, graph.lookup[vtype.inner], inner_ep, seen)
        return val, new_pos
    return _restore_packed_value(graph, mv, vtype, 0 if code == 0 else 1, ep, seen)


def _restore_packed_array(graph, mv, t, pos, awo, seen):
    """A packed-shape array field: ``[LEB block-length][payload]``. The payload framing
    depends on the element type (mirrors the reference ``_packed_arr_read_expr``):
    width≥2 ints use a ``(count<<2)|enc-tag`` header; ``u8``/``i8`` a plain ``[count][raw]``;
    floats a ``(count<<2)|mode`` header (self-describing packed vs raw); ``f16``/``bf16`` a
    per-element enc-bitset; ``utf8``/``data`` self-delimiting length-prefixed elements;
    ``bool`` a value bitset; enum a sub-byte bitset or LEB-per-element; node/union refs
    inlined blocks. Returns ``(list, new_pos)`` where ``new_pos`` ends the self-sizing block."""
    block_len, p = read_leb(mv, pos)            # p = payload (count) position
    end = p + block_len
    inner = t.inner
    k = inner.kind
    target = graph.lookup.get(inner.inner) if k == "ref" else None

    if isinstance(target, UnionType):
        return _restore_packed_union_array(graph, mv, target, p, awo, seen), end
    if isinstance(target, Node):
        return _restore_packed_node_array(graph, mv, inner.inner, p, awo, seen), end
    if isinstance(target, Enum):
        return _restore_packed_enum_array(mv, target, p, awo), end
    if k in ("f32", "f64"):
        return _restore_packed_float_array(mv, k, p, awo), end
    if k in ("f16", "bf16"):
        return _restore_packed_f16_array(mv, k, p, awo), end
    if k in ("utf8", "data"):
        return _restore_packed_complex_array(mv, k, p, awo), end
    if k == "bool":
        return _restore_packed_bool_array(mv, p, awo), end
    if k in _INT_WIDTH:
        return _restore_packed_int_array(mv, k, p, awo), end
    raise NotImplementedError(
        f"packed array of {k}{' (with optionals)' if awo else ''}")


def _read_nil_bitset(mv, count, q):
    nb = (count + 7) // 8
    return int.from_bytes(bytes(mv[q:q + nb]), "little"), q + nb


def _restore_packed_int_array(mv, k, p, awo):
    """width≥2: ``(count<<2)|tag`` header (0=all-LEB, 1=all-raw, 2=per-elem enc-bitset).
    ``u8``/``i8``: plain ``[count][raw]`` (non-AWO) or ``[count][nil][present raw]`` (AWO)."""
    width, signed = _INT_WIDTH[k], k not in _UNSIGNED
    reader = _SCALAR[k]
    if width == 1:                              # u8/i8 — plain count, not count-tag
        count, q = read_leb(mv, p)
        nil = 0
        if not awo:                             # contiguous raw bytes → zero-copy view
            view = _array_view(mv, k, q, count)
            if view is not None:
                return view
        if awo:
            nil, q = _read_nil_bitset(mv, count, q)
        out = []
        for i in range(count):
            if awo and (nil >> i) & 1:
                out.append(None)
            else:
                out.append(reader(mv, q))
                q += 1
        return out
    count_raw, q = read_leb(mv, p)
    count, tag = count_raw >> 2, count_raw & 3
    if tag == 1 and not awo:                    # all-raw contiguous native-LE → zero-copy view
        view = _array_view(mv, k, q, count)
        if view is not None:
            return view
    nil = 0
    if awo:
        nil, q = _read_nil_bitset(mv, count, q)
    enc = 0
    if tag == 2:                                # per-element encoding bitset (set = raw)
        enc, q = _read_nil_bitset(mv, count, q)
    out = []
    for i in range(count):
        if awo and (nil >> i) & 1:
            out.append(None)
            continue
        if tag == 1 or (tag == 2 and (enc >> i) & 1):
            out.append(reader(mv, q))
            q += width
        else:
            v, q = read_leb(mv, q) if not signed else read_zigzag_leb(mv, q)
            out.append(v)
    return out


def _restore_packed_float_array(mv, k, p, awo):
    """``(count<<2)|mode``: mode 1 → raw native-LE, mode 0 → self-describing packed float."""
    width = _SCALAR_WIDTH[k]
    dec = decode_packed_float32 if k == "f32" else decode_packed_float64
    c, q = read_leb(mv, p)
    count, mode = c >> 2, c & 3
    if mode == 1 and not awo:                   # raw native-LE contiguous → zero-copy view
        view = _array_view(mv, k, q, count)
        if view is not None:
            return view
    nil = 0
    if awo:
        nil, q = _read_nil_bitset(mv, count, q)
    out = []
    for i in range(count):
        if awo and (nil >> i) & 1:
            out.append(None)
            continue
        if mode == 1:
            out.append(_SCALAR[k](mv, q))
            q += width
        else:
            v, nb = dec(mv, q)
            out.append(v)
            q += nb
    return out


def _restore_packed_f16_array(mv, k, p, awo):
    """``[count][enc bitset][elems]`` (non-AWO): bit set → raw 2-byte native, clear →
    special-value sub-tag (1 byte). AWO: ``[count][nil bitset][present raw 2-byte]``."""
    reader = _SCALAR[k]
    count, q = read_leb(mv, p)
    if awo:
        nil, q = _read_nil_bitset(mv, count, q)
        out = []
        for i in range(count):
            if (nil >> i) & 1:
                out.append(None)
            else:
                out.append(reader(mv, q))
                q += 2
        return out
    enc, q = _read_nil_bitset(mv, count, q)
    out = []
    for i in range(count):
        if (enc >> i) & 1:
            out.append(reader(mv, q))
            q += 2
        else:
            v, nb = decode_packed_f16(mv, q)
            out.append(v)
            q += nb
    return out


def _restore_packed_complex_array(mv, k, p, awo):
    """utf8/data: ``[count][ (LEB len + bytes) per element ]``; AWO omits nil elements
    (``[count][nil bitset][present elems]``)."""
    reader = read_utf8 if k == "utf8" else read_data
    count, q = read_leb(mv, p)
    nil = 0
    if awo:
        nil, q = _read_nil_bitset(mv, count, q)
    out = []
    for i in range(count):
        if awo and (nil >> i) & 1:
            out.append(None)
            continue
        v, q = reader(mv, q)
        out.append(v)
    return out


def _restore_packed_bool_array(mv, p, awo):
    """Non-AWO: ``[count][value bitset]``. AWO: ``[count][nil bitset][compacted value
    bitset]`` — the value bit index counts only present elements."""
    count, q = read_leb(mv, p)
    if not awo:
        vb = (count + 7) // 8
        value = int.from_bytes(bytes(mv[q:q + vb]), "little")
        return [bool((value >> i) & 1) for i in range(count)]
    nil, q = _read_nil_bitset(mv, count, q)
    value = int.from_bytes(bytes(mv[q:q + (count + 7) // 8]), "little")
    out, ci = [], 0
    for i in range(count):
        if (nil >> i) & 1:
            out.append(None)
        else:
            out.append(bool((value >> ci) & 1))
            ci += 1
    return out


def _restore_packed_enum_array(mv, enum, p, awo):
    """Sub-byte enums: ``[count][packed bits]`` (non-AWO, same as regular/frozen) or
    ``[count][nil][compacted value bitset]`` (AWO). Byte-aligned enums: LEB-per-element
    (``[count][LEB...]`` / ``[count][nil][present LEB...]``) — packed nodes LEB the raw
    value rather than storing it fixed-width."""
    bits = _enum_bits_per_elem(enum)
    count, q = read_leb(mv, p)
    if awo:
        nil, q = _read_nil_bitset(mv, count, q)
    if bits is not None:                        # sub-byte bit-packed
        if not awo:
            nb = (count * bits + 7) // 8
            packed = int.from_bytes(bytes(mv[q:q + nb]), "little")
            mask = (1 << bits) - 1
            return [(packed >> (i * bits)) & mask for i in range(count)]
        present = count - bin(nil & ((1 << count) - 1)).count("1")
        nb = (present * bits + 7) // 8          # AWO value bitset is COMPACTED
        packed = int.from_bytes(bytes(mv[q:q + nb]), "little")
        mask = (1 << bits) - 1
        out, ci = [], 0
        for i in range(count):
            if (nil >> i) & 1:
                out.append(None)
            else:
                out.append((packed >> (ci * bits)) & mask)
                ci += 1
        return out
    out = []                                    # byte-aligned: one unsigned LEB per element
    for i in range(count):
        if awo and (nil >> i) & 1:
            out.append(None)
            continue
        v, q = read_leb(mv, q)
        out.append(v)
    return out


def _restore_packed_node_array(graph, mv, type_name, p, awo, seen):
    """``[count][nil bitset if AWO][ inlined packed child block per non-nil element ]``.
    Each child is a packed ``[LEB blockLen][block]`` regardless of its declared shape."""
    count, q = read_leb(mv, p)
    nil = 0
    if awo:
        nil, q = _read_nil_bitset(mv, count, q)
    out = []
    for i in range(count):
        if awo and (nil >> i) & 1:
            out.append(None)
        else:
            node, q = _restore_packed_inline_node(graph, mv, type_name, q, seen)
            out.append(node)
    return out


def _restore_packed_union_array(graph, mv, union, at, awo, seen):
    """Packed union array. Non-AWO: ``[count][N header LEBs][N payloads]`` — headers and
    payloads occupy separate sections. AWO: ``[count][nil bitset][LEB headerSectionSize]
    [present headers][present payloads]``. Each header LEB is ``(type_id<<3)|code``; the
    payload is decoded (and its length skipped) from the payload cursor."""
    count, cB = read_leb(mv, at)
    if awo:
        nil_start = cB
        bs_end = nil_start + (count + 7) // 8
        nil = int.from_bytes(bytes(mv[nil_start:bs_end]), "little")
        hss, hp = read_leb(mv, bs_end)
        pp = hp + hss
    else:
        nil = 0
        hp = cB
        for _ in range(count):                  # header section = count LEBs
            _, hp = read_leb(mv, hp)
        pp = hp
        hp = cB
    out = []
    for i in range(count):
        if awo and (nil >> i) & 1:
            out.append(None)
            continue
        hdr, hp = read_leb(mv, hp)
        label, vtype = union.types[hdr >> 3]
        value, pp = _restore_packed_union_payload(graph, mv, vtype, hdr & 7, pp, seen)
        out.append(new_union(graph, union, label, value))
    return out


def _restore_value(graph, mv, t, pos, seen):
    k = t.kind
    reader = _SCALAR.get(k)
    if reader is not None:
        return reader(mv, pos)
    if k == "utf8":
        ptr, after = read_v62(mv, pos)         # forward pointer → [LEB len][bytes]
        return read_utf8(mv, after + ptr)[0]
    if k == "data":
        ptr, after = read_v62(mv, pos)
        return read_data(mv, after + ptr)[0]
    if k == "ref":
        target = graph.lookup[t.inner]
        if isinstance(target, Enum):
            # Enum → raw int of the enum's backing width (native LE). Bitset enums
            # store the same raw int (flag bits); a small EnumRef wrapper is a Phase-3
            # ergonomics upgrade (O-P7) — raw int is the safe default.
            return _SCALAR[_enum_raw_width(target)](mv, pos)
        if isinstance(target, Node):
            # Signed (ZigZag) V62 bidirectional pointer, relative to the pointer END.
            offset, after = read_zigzag_v62(mv, pos)
            return _restore_node(graph, mv, t.inner, after + offset, seen)
        if isinstance(target, UnionType):
            return _restore_union(graph, mv, target, pos, seen)[0]
        raise NotImplementedError(f"ref target kind: {type(target).__name__}")
    if k in ("array", "arrayWithOptionals"):
        # Regular node: the field slot holds a FORWARD (unsigned) V62 pointer to the
        # array block; the block is `[LEB count][elements]`.
        ptr, after = read_v62(mv, pos)
        return _restore_array(graph, mv, t, after + ptr, seen, k == "arrayWithOptionals")
    raise NotImplementedError(f"field kind not yet supported: {k!r}")


def _restore_union(graph, mv, union, pos, seen):
    """`[LEB tag][payload]`. The tag is self-describing: ``type_id = raw >> 2`` and the
    low 2 bits are a payload width code (so a reader can skip a union without the
    schema). The payload framing depends on the variant type:
      * value scalar / enum → stored **inline** (native-LE) right after the tag;
      * node-ref → a **bidirectional** (ZigZag) V62 pointer.
    `utf8` / `data` / array / nested-union variants (pointer-indirected / self-sizing)
    are later matrix steps and raise ``NotImplementedError``.
    """
    raw, after = read_leb(mv, pos)
    label, vtype = union.types[raw >> 2]
    vk = vtype.kind
    if vk in _SCALAR:                              # value scalar inline
        return new_union(graph, union, label, _SCALAR[vk](mv, after)), after + _SCALAR_WIDTH[vk]
    if vk == "ref":
        tt = graph.lookup[vtype.inner]
        if isinstance(tt, Enum):                   # enum inline
            w = _enum_raw_width(tt)
            return new_union(graph, union, label, _SCALAR[w](mv, after)), after + _INT_WIDTH[w]
        if isinstance(tt, Node):                   # node-ref: bidirectional pointer
            offset, ptr_end = read_zigzag_v62(mv, after)
            return (new_union(graph, union, label, _restore_node(graph, mv, vtype.inner, ptr_end + offset, seen)),
                    ptr_end)
        if isinstance(tt, UnionType):              # nested union: FORWARD pointer → union slot
            ptr, ap = read_v62(mv, after)
            return new_union(graph, union, label, _restore_union(graph, mv, tt, ap + ptr, seen)[0]), ap
    # Heap variants — a FORWARD pointer follows the tag (node-ref used a bidirectional
    # one): utf8 / data → [LEB len][bytes]; array → the array block.
    if vk == "utf8":
        ptr, ap = read_v62(mv, after)
        return new_union(graph, union, label, read_utf8(mv, ap + ptr)[0]), ap
    if vk == "data":
        ptr, ap = read_v62(mv, after)
        return new_union(graph, union, label, read_data(mv, ap + ptr)[0]), ap
    if vk in ("array", "arrayWithOptionals"):
        ptr, ap = read_v62(mv, after)
        return (new_union(graph, union, label, _restore_array(graph, mv, vtype, ap + ptr, seen,
                                                vk == "arrayWithOptionals")), ap)
    raise NotImplementedError(f"union variant {label!r} ({vk}) not yet supported")


def _restore_array(graph, mv, t, pos, seen, awo):
    inner = t.inner
    k = inner.kind

    def _nil_bitset(count, p):
        if not awo:
            return 0, p
        nb = (count + 7) // 8
        return int.from_bytes(bytes(mv[p:p + nb]), "little"), p + nb

    # ── fixed scalar array (int / float): [count][nil bitset?][native-LE elements].
    # Non-`raw` float arrays use the same plain layout as integers (wider elements). ──
    if k in _SCALAR_WIDTH and k != "bool":
        count, p = read_leb(mv, pos)
        nil, p = _nil_bitset(count, p)
        if not awo:                                          # contiguous native-LE → zero-copy view
            view = _array_view(mv, k, p, count)
            if view is not None:
                return view
        width, reader = _SCALAR_WIDTH[k], _SCALAR[k]
        out = []
        for i in range(count):
            out.append(None if (nil >> i) & 1 else reader(mv, p))
            p += width
        return out

    # ── bool array: [count][nil bitset?][value bitset] (1 bit/elem, set = true) ──
    if k == "bool":
        count, p = read_leb(mv, pos)
        nil, p = _nil_bitset(count, p)
        vb = (count + 7) // 8
        value = int.from_bytes(bytes(mv[p:p + vb]), "little")
        return [None if (nil >> i) & 1 else bool((value >> i) & 1) for i in range(count)]

    # ── enum array: [count][nil bitset?][packed]. Small enums are sub-byte bit-packed
    # (bits/elem from _enum_bits_per_elem, element 0 in the low bits); larger enums store
    # native-LE elements of the backing width. ──
    if k == "ref" and isinstance(graph.lookup.get(inner.inner), Enum):
        enum = graph.lookup[inner.inner]
        count, p = read_leb(mv, pos)
        nil, p = _nil_bitset(count, p)
        bits = _enum_bits_per_elem(enum)
        if bits is None:                               # full-byte(s) native-LE
            w, reader = _INT_WIDTH[_enum_raw_width(enum)], _SCALAR[_enum_raw_width(enum)]
            out = []
            for i in range(count):
                out.append(None if (nil >> i) & 1 else reader(mv, p))
                p += w
            return out
        nb = (count * bits + 7) // 8                   # sub-byte bit-packed
        packed = int.from_bytes(bytes(mv[p:p + nb]), "little")
        mask = (1 << bits) - 1
        return [None if (nil >> i) & 1 else (packed >> (i * bits)) & mask
                for i in range(count)]

    # ── array of unions (SoA), regular/frozen shape (see _restore_union_array). ──
    if k == "ref" and isinstance(graph.lookup.get(inner.inner), UnionType):
        return _restore_union_array(graph, mv, graph.lookup[inner.inner], pos, awo, seen)

    # ── heap-element array (utf8 / data / node-ref): a pointer table.
    # [ (count<<2)|sizeCode ][ count × sizeBytes offsets ][ elements ];
    # element_pos = table_end + offset - 1; offset 0 = nil. ──
    # Node-ref slots are SIGNED two's-complement distances (a shared/cyclic target may sit
    # at a lower makeData index → negative), matching Rust's read_node_ref_array; utf8/data
    # value-ref slots are plain UNSIGNED forward distances (§4.5).
    is_node_ref = k == "ref" and isinstance(graph.lookup.get(inner.inner), Node)
    if k in ("utf8", "data") or is_node_ref:
        header, p = read_leb(mv, pos)
        count = header >> 2
        size = (1, 2, 4, 8)[header & 3]
        table_start = p
        table_end = p + count * size
        out = []
        for i in range(count):
            off = int.from_bytes(
                bytes(mv[table_start + i * size:table_start + (i + 1) * size]),
                "little", signed=is_node_ref)
            if off == 0:
                out.append(None)
                continue
            target = table_end + off - 1
            if k == "utf8":
                out.append(read_utf8(mv, target)[0])
            elif k == "data":
                out.append(read_data(mv, target)[0])
            else:
                out.append(_restore_node(graph, mv, inner.inner, target, seen))
        return out

    raise NotImplementedError(
        f"array of {k}{' (with optionals)' if awo else ''} not yet supported")


def _union_tid_bits(union):
    """Bits per element in a union array's type-id section (from the union capacity;
    mirrors the reference ``_union_bits_per`` / ``_BW_BITS``). Unions are never bitsets."""
    cap = union.capacity
    if cap <= 2:     return 1
    if cap <= 4:     return 2
    if cap <= 16:    return 4
    if cap <= 255:   return 8
    if cap <= 65535: return 16
    return 32


def _restore_union_array(graph, mv, union, pos, awo, seen):
    """Regular/frozen array-of-union (SoA). Layout (mirrors the reference
    ``read{Union}ArrayAt``):

        [LEB (count<<2)|sizeCode][type-id section][nil bitset?][count×es slot table][payloads]

    ``sizeCode`` picks the slot width ``es`` (1/2/4/8 bytes). The **type-id section**
    packs one ``_union_tid_bits(union)``-bit id per element (element 0 in the low bits).
    Each element's ``es``-byte slot is either the value stored **inline** (leaf variants —
    read native-LE at the slot, low bytes hold the value) or an **offset** ``ro`` from the
    payload ``base = slotStart + count*es`` (reference/heap variants: node-ref at
    ``base + ro//2``; utf8/data/nested-union/nested-array at ``base + ro``)."""
    header, p = read_leb(mv, pos)
    count = header >> 2
    es = (1, 2, 4, 8)[header & 3]
    bits = _union_tid_bits(union)
    tid_start = p
    tid_len = (count * bits + 7) // 8              # sub-byte packed, elem 0 in low bits
    tids = int.from_bytes(bytes(mv[tid_start:tid_start + tid_len]), "little")
    p = tid_start + tid_len
    nil = 0
    if awo:
        nb = (count + 7) // 8
        nil = int.from_bytes(bytes(mv[p:p + nb]), "little")
        p += nb
    slot_start = p
    base = slot_start + count * es
    mask = (1 << bits) - 1
    out = []
    for i in range(count):
        if awo and (nil >> i) & 1:
            out.append(None)
            continue
        tid = (tids >> (i * bits)) & mask
        label, vtype = union.types[tid]
        sp = slot_start + i * es
        out.append(new_union(graph, union, label, _restore_union_elem(graph, mv, vtype, sp, es, base, seen)))
    return out


def _restore_union_elem(graph, mv, vtype, sp, es, base, seen):
    """Decode one union-array element's value from its ``es``-byte slot value ``ro``.

    ``es`` is the *minimal* width across all slots (a ``u64`` holding a small value can sit
    in a 1-byte slot), so a fixed-width read at ``sp`` would overrun — read exactly ``es``
    bytes and reinterpret. **Leaf** variants store the value inline (``ro`` holds the
    low-width bit pattern, zero-extended); **reference/heap** variants store ``ro`` as an
    unsigned offset from ``base`` (node-ref at ``base + ro//2``, others at ``base + ro``)."""
    ro = int.from_bytes(bytes(mv[sp:sp + es]), "little")
    k = vtype.kind
    if k in _UNSIGNED:
        return ro
    if k in ("i8", "i16", "i32", "i64"):            # sign-reinterpret at the TYPE width
        w = _INT_WIDTH[k] * 8
        return ro - (1 << w) if ro >= (1 << (w - 1)) else ro
    if k == "bool":
        return ro != 0
    if k in ("f16", "bf16", "f32", "f64"):          # low bytes = the float's bit pattern
        wb = _SCALAR_WIDTH[k]
        raw = (ro & ((1 << (8 * wb)) - 1)).to_bytes(wb, "little")
        return _SCALAR[k](memoryview(raw), 0)
    if k == "utf8":
        return read_utf8(mv, base + ro)[0]
    if k == "data":
        return read_data(mv, base + ro)[0]
    if k == "ref":
        target = graph.lookup[vtype.inner]
        if isinstance(target, Enum):                # raw backing int, inline (unsigned)
            return ro
        if isinstance(target, Node):                # node payload at base + ro//2
            return _restore_node(graph, mv, vtype.inner, base + ro // 2, seen)
        if isinstance(target, UnionType):           # nested union inline at base + ro
            return _restore_union(graph, mv, target, base + ro, seen)[0]
    if k in ("array", "arrayWithOptionals"):        # nested array payload at base + ro
        return _restore_array(graph, mv, vtype, base + ro, seen, k == "arrayWithOptionals")
    raise NotImplementedError(f"union-array variant kind {k!r} not yet supported")
