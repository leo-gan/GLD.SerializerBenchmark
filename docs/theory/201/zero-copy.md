# Zero-copy

---

## Problem

In the classical serialization model, a byte sequence arrives, a parser **constructs a new object graph** in the language runtime, application code reads properties from those objects, and memory is later reclaimed (manually or by garbage collection). The model is straightforward to reason about and becomes expensive when messages are large, numerous, or only partly examined—because the implementation pays to materialize fields that are never read.

Some formats are described as **zero-copy**, or are said **not to deserialize**. Such phrasing is easily misread as “costless and invariably safer.” The underlying mechanism is precise: for a chosen endianness and alignment policy, **the on-the-wire layout is arranged so that fields can be read in place**, using offsets into the receive buffer, rather than by allocating a parallel tree of language objects.

---

## Short answer

In a **zero-copy** design (FlatBuffers, Cap’n Proto, and related systems), encoding produces a binary image whose fields are accessible through **generated accessors or equivalent offset arithmetic** applied directly to the receive buffer. There is no separate step that parses the entire message into ordinary language objects on the ordinary read path—hence “does not deserialize” in the *classical* sense of full materialization. Encoding still requires work to **construct** that layout; **validation** of untrusted buffers remains necessary (omitting it is a serious risk); partial mutation is often awkward; and operational tooling differs from text-oriented formats. Zero-copy is a layout and application-programming-interface philosophy, not a costless substitute for a schema or a trust model.

---

## Mental model

```text
  Classical path                      Zero-copy style path
  ──────────────                      ────────────────────
  network buffer                      network buffer
       │                                   │
       ▼                                   │ structural verification
  parse and allocate                       │ (required for untrusted data)
       │                                   ▼
       ▼                              accessors / views
  object graph  ←── application ──   (read fields at offsets
  (independent copy)     reads        into the same buffer)
```

**Information versus materialization.** Interpreting bytes as typed fields *is* deserialization in the information-theoretic sense. What zero-copy designs avoid is the classical step of **allocating a full data-transfer object graph** that mirrors the message.

---

## How it works

### Layout contract (building on memory layout)

Recall from [memory layout](memory-layout.md) that a process-local structure may contain padding and host pointers. A zero-copy **message format** instead defines a **portable layout**:

- multi-byte integers appear at agreed alignments and byte orders;  
- variable-length data (strings, vectors) are reached through **offsets** stored in the buffer;  
- optional fields may be indicated by a table of field offsets (often called a vtable in FlatBuffers documentation).

**Beginner sketch — reading one integer field.**

Suppose a verified buffer begins with a root table. Generated code might perform steps equivalent to:

```text
  1. Let base = address of the buffer in this process.
  2. Read a root offset (e.g. 32-bit little-endian) at a known position.
  3. From the table at base+root, read the offset of field "price_cents".
  4. Load a 32-bit little-endian integer at that location.
  5. Return that integer to the application — without constructing a "Message" object
     that owns a separate "price_cents" heap field.
```

No host pointer from the **writer’s** address space appears in the file. Offsets are relative to the buffer, so the image remains meaningful after the bytes are copied to another machine (given matching endianness rules as defined by the format).

### FlatBuffers as a concrete case study

| Stage | What happens |
|-------|----------------|
| Design | An IDL/schema declares tables and fields; tools generate readers and builders. |
| Encode | A builder API appends data (often depth-first) and patches offsets so the final buffer is self-consistent. |
| Verify | A verifier checks that offsets and lengths lie within the buffer (essential for untrusted input). |
| Read | Accessors traverse offsets; unread fields need not become heap objects. |

Thus “FlatBuffers does not deserialize” means “does not classically materialize the whole message as objects,” not “does no work and needs no schema.”

### The encode path is not free

Builders must produce a correct buffer (packing, offsets, padding). Workloads that **mutate** messages continuously may find the classical pattern—populate a structure, then serialize—simpler. Zero-copy layouts are most advantageous when messages are **constructed once and read many times**, or when only a few fields of a large message are examined.

### Validation

Avoiding object materialization must not mean avoiding **bounds and structural checks** on untrusted data. FlatBuffers-style stacks provide verifiers; using them on adversarial input is part of the security discussion in the [engineering perspective](../101/engineer_perspective.md). An unverified buffer is a collection of offsets that an attacker may craft to induce out-of-bounds access.

### Mutation and operability

In-place updates are constrained (sufficient space must already exist; changing lengths is difficult). Many deployments treat buffers as **immutable messages** and rebuild when state changes. Debugging requires format-aware tools; hexadecimal dumps are less informative than structured text logs.

### Related but distinct ideas

| Idea | Relation to message zero-copy |
|------|-------------------------------|
| Memory-mapped columnar formats (Arrow, Parquet access paths) | Zero-copy *columns* for analytical workloads—different problem domain ([data science perspective](../101/data_science_perspective.md)) |
| `span` / buffer views on ordinary codecs | Reduce copies without a full zero-copy message format |
| Protocol Buffers with arenas or pooling | Fast materialization or reduced allocation—not the same layout model |

---

## Costs and constraints

| Axis | Typical effect of zero-copy layouts | Remaining responsibilities |
|------|-------------------------------------|----------------------------|
| Processor time (read) | Often lower for sparse access to large messages | Verification cost; access patterns |
| Processor time (write) | Builder complexity; not always faster than packed classical encode | — |
| Memory / allocations | Fewer objects on the read path | Buffer lifetime must outlive views |
| Size / bandwidth | Competitive; alignment may introduce padding | Not a substitute for compression ([Compression vs format](compression-is-not-a-format.md)) |
| Evolution | Schema or IDL still required | Compatibility discipline remains |
| Security | Omitting verification can appear “fast” and is unsafe | Always verify untrusted buffers |
| Operability | Specialized inspectors | Weaker ad hoc log readability |

---

## Illustrative scenario

A mobile client downloads a large catalogue message. The user interface requires only a few fields per screen. Classical decoding may allocate thousands of objects at load time. A FlatBuffers-style buffer is retained (or memory-mapped) once, verified once, and read on demand. The same pattern appears in some remote-procedure-call or inter-process paths for large, immutable configuration snapshots. The approach fits poorly for small, frequently mutated documents when builder complexity exceeds any gain, and it fits poorly when a team will not adopt schema tooling.

---

## In this suite

Where FlatBuffers or similar codecs are **registered** for a language, treat them as **schema-driven / specialized layout** entries and compare them carefully with other schema-driven libraries on the **same language Results** page. Absence from a language harness means “not measured here,” not “irrelevant in industry.” Categories and overviews record what is wired today: [Serialization categories](../../analysis/serialization_categories.md).

---

## Common errors of reasoning

- Interpreting “no deserialization” as “no processor work and no schema.”  
- Using zero-copy buffers received from a network **without verification**.  
- Retaining views into a buffer that has been freed, recycled, or overwritten.  
- Selecting zero-copy for small, highly mutable messages because a benchmark used large static ones.  
- Comparing an unverified zero-copy path with a fully validating classical parser on speed alone.

---

## Key takeaways

- Zero-copy means **in-place field access** from a designed layout, not “no interpretation of bytes.”  
- “Does not deserialize” targets the classical **full object-graph materialization** step.  
- Construction and **verification** still cost time; security requires the latter for untrusted data.  
- Best fit: large or sparsely read, mostly immutable messages, with acceptance of schema tooling.  
- Poor fit: tiny mutable documents; environments that require text inspectability above all else.  
- Columnar and buffer-view techniques are related but not identical.  
- Interpret suite measurements in light of validation settings and access patterns.

---
