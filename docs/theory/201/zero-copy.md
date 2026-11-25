# 2.7 Zero-Copy Layouts

## Problem Statement

Classical deserialization parses a wire buffer and **allocates a parallel in-memory object graph** mirroring every field in the message. When payloads are large, frequently read, or only sparsely inspected (for example, checking two header fields inside a 50 KB catalog message), constructing heap objects for unread fields wastes CPU cycles and increases garbage-collection pressure.

Formats marketed as **zero-copy**—or described as requiring *"no deserialization"*—address this bottleneck by arranging the wire layout so fields can be read directly in place from the receive buffer. Evaluating them accurately requires separating what zero-copy actually eliminates from the costs it retains or shifts elsewhere.

---

## Mechanism: In-Place Access via Relative Offsets

!!! note "Definition: Zero-Copy Serialization Format"
    A **zero-copy serialization format** specifies an aligned, explicit-endianness binary layout in which variable-length fields and nested tables are addressed via **buffer-relative offsets** rather than raw process pointers. Generated accessors read fields directly from the receive buffer without allocating a mirror object graph.

![Classical deserialize path versus zero-copy accessors](../assets/diagrams/201-zero-copy.svg#only-light)
![Classical deserialize path versus zero-copy accessors](../assets/diagrams/201-zero-copy-dark.svg#only-dark)

Interpreting raw bytes as typed values is still deserialization in the information-theoretic sense; what zero-copy avoids is **eagerly materializing a full tree of language objects on the heap**.

### How an In-Place Read Works (FlatBuffers Model)

Unlike an uninterpreted C `struct` dump ([2.1 Memory layout](memory-layout.md)), a zero-copy layout is a portable, versioned contract:[^1]

1. Multi-byte scalars sit at agreed alignments and fixed byte order (typically little-endian).
2. Strings, vectors, and subtables are reached by adding a stored 32-bit relative offset to the current buffer position—never an absolute memory address from the sender.
3. Optional fields and schema evolution are supported through a compact **vtable** (a table of 16-bit field offsets; an offset of `0` indicates an absent/default field).

Reading one 32-bit field `price_cents` from a verified receive buffer executes only a few pointer-arithmetic steps:

```text
  1. base   = address of receive buffer
  2. root   = base + read_u32_le(base)              // locate root table
  3. vtable = root - read_i32_le(root)              // locate field-offset table
  4. off    = read_u16_le(vtable + FIELD_SLOT)      // 0 if absent -> return default
  5. return read_i32_le(root + off)                 // direct load, zero heap allocations
```

No `Message` object is allocated, and unread sibling fields are never touched.

### Where the Cost Moves

Zero-copy eliminates *eager read-time allocation*, not all computational work:

- **Encode / builder complexity:** Writers must lay out subtables depth-first (often back-to-front in FlatBuffers), align fields, deduplicate vtables, and patch relative offsets. Encode is therefore frequently more complex—and not always faster—than sequential varint or positional writers.
- **Mandatory verification on untrusted input:** Skipping eager parsing does *not* make untrusted bytes safe. A malicious buffer can encode out-of-bounds offsets, overlapping tables, or cyclic offset pointers. Any untrusted zero-copy buffer **must pass a structural verifier** (`VerifyBuffer`) before field access, which reintroduces an $O(n)$ validation scan.[^1][^2]
- **Buffer lifetime and immutability:** Views borrow directly from the backing byte buffer, so the buffer must outlive every accessor reference. Because variable-length fields cannot grow in place without invalidating surrounding offsets, zero-copy buffers are typically immutable; mutating a payload usually requires rebuilding it.
- **Alignment padding:** Direct aligned loads introduce padding bytes, so raw wire size is often slightly larger than varint-encoded Protocol Buffers (Cap'n Proto addresses zero-byte padding with an optional lightweight *packed* encoding layer).[^2]

### Related Concepts (Do Not Conflate)

| Technique | Relationship to Single-Record Zero-Copy |
|---|---|
| **Columnar memory mapping (Apache Arrow IPC)**[^3] | Zero-copy across *columnar arrays* for analytics rather than nested single-record RPC messages |
| **Borrowed string slices / `Span<T>` in classical codecs** | Avoids string heap copies during classical parsing without adopting an offset-table wire format |
| **Protocol Buffers arenas** | Speeds up allocation/deallocation via bump-pointer arenas while still materializing full message objects |

---

## Trade-Offs and Suitability

| Dimension | Zero-Copy (FlatBuffers, Cap'n Proto, `rkyv`) | Classical Materializing Codec (Protocol Buffers, JSON) |
|---|---|---|
| **Sparse read of large messages** | $O(1)$ per accessed field; zero heap allocations | $O(n)$ parse and allocation of entire message |
| **Full-message read** | Competitive; pays indirection per field access | Fast sequential field reads once materialized |
| **Encode ergonomics** | Builder API (often reverse-order construction) | Populate ordinary language struct, then encode |
| **Mutation** | Awkward; generally treat buffers as immutable | Natural mutation on ordinary in-memory objects |
| **Untrusted input safety** | Requires explicit verifier pass prior to access | Parser validates structure inherently during decode |
| **Best fit** | Large, read-heavy, mostly immutable payloads (game assets, mobile catalogs, `mmap` configs, ML metadata) | Small, frequently mutated RPC messages or environments requiring text observability |

---

## Connection to the Benchmark Suite

Row-oriented zero-copy codecs registered across languages in this suite include **FlatBuffers**, **Cap'n Proto**, **FlexBuffers** (FlatBuffers' self-describing schemaless variant), **Rust `rkyv`**, **C++ `cista`**, and **Bebop**.

Check timing semantics carefully on each language Overview before reading Dashboard rows: in particular, this suite times Rust **`rkyv`** as a full materialization into an owned `Document` (`from_bytes`) rather than zero-copy `access`—see [Rust: rkyv vs. Speedy](../401/rust-rkyv-vs-speedy.md) and [Timing honesty](../../analysis/TIMING_HONESTY.md). For zero-copy tensor buffer borrowing (`tensor_view`), see [Tensor](../../analysis/tensor.md) and the [Dashboard](../../dashboard/index.html).

---

## Exercises

1. **Sparse vs. full access:** A service receives 200 KB configuration snapshots over a trusted internal link and reads only 3 boolean flags per request. Why does FlatBuffers outperform Protocol Buffers on decode latency here, and what changes if the service must immediately transform and mutate all 500 nested records?

??? note "Solution"
    When reading only 3 flags from a 200 KB snapshot, FlatBuffers follows three vtable offsets in $O(1)$ time with zero allocations, whereas Protocol Buffers must parse and allocate objects for the entire 200 KB stream. If the service mutates all 500 nested records, the advantage largely vanishes: every field must be visited anyway, and mutating a FlatBuffers payload typically requires unpacking into mutable structs and re-running the FlatBuffers builder.

2. **Benchmarking trap:** An engineer benchmarks an *unverified* FlatBuffers read against a fully validating JSON parser on untrusted HTTP input and reports a 40× speedup. Identify the methodological flaw.

??? note "Solution"
    The comparison is asymmetric on safety: the JSON parser validates syntax, UTF-8, and structure on every byte, whereas unverified FlatBuffers trusts arbitrary caller-supplied offsets and is vulnerable to out-of-bounds crashes. A fair comparison for untrusted HTTP input must include FlatBuffers' `VerifyBuffer` pass inside the timed decode path.

3. **Lifetime hazard:** In C++ or Rust, a function reads a FlatBuffers buffer into a local stack `std::vector<uint8_t>`, returns a FlatBuffers table view pointing into it, and exits. What happens next?

??? note "Solution"
    The returned view holds a dangling pointer into freed stack/vector memory (**use-after-free**). Because zero-copy views borrow directly from the backing buffer, the caller must keep the owning buffer alive (or copy out the needed fields) for as long as any view remains in use.

---

## References

[^1]: Google. *FlatBuffers Internals and C++ Verification Guide*. <https://flatbuffers.dev/internals/>
[^2]: Varda, K. *Cap'n Proto Encoding Specification*. <https://capnproto.org/encoding.html>
[^3]: Apache Software Foundation. *Apache Arrow IPC Format*. <https://arrow.apache.org/docs/format/Columnar.html#serialization-and-interprocess-communication-ipc>
