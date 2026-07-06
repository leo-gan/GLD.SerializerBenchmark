# Zero-copy layouts

> After this page you can explain what “no deserialize” means for FlatBuffers-class formats—and what costs and risks remain.

---

## Problem

Classic serialization: bytes arrive, a parser **builds a new object graph**, application code reads properties, then memory is freed or GCed. That path is simple to reason about and expensive when messages are large, numerous, or mostly untouched (you pay to build fields you never read).

Some formats advertise **zero-copy** or claim they **don’t deserialize**. Marketing shorthand is easy to misread as “free and always safer.” The mechanism is specific: **the wire layout is the in-memory layout** (for a chosen endianness/alignment), so readers use offsets into a buffer instead of allocating a mirror object tree.

---

## Short answer

In a **zero-copy** design (FlatBuffers, Cap’n Proto, and similar ideas), encoding produces a binary image whose fields can be read with **pointer arithmetic / generated accessors** directly on the receive buffer. There is no separate “parse entire message into language objects” step on the happy path—hence “don’t deserialize” in the *classic* sense. You still pay to **build** that layout on encode, to **validate** untrusted buffers (or accept serious risk), and often accept **awkward partial mutation** and different tooling. Zero-copy is a layout and API philosophy, not a free lunch and not a substitute for a schema or trust model.

---

## Mental model

```text
  Classic                         Zero-copy style
  ────────                        ───────────────
  network buffer                  network buffer
       │                               │
       ▼                               │ verify (please)
  parse + allocate                     │
       │                               ▼
       ▼                          accessors / views
  object graph  ←── app reads ──  (offsets into buffer)
  (independent copy)
```

**FlatBuffers as case study:** schema/IDL → generated code; builder APIs construct a depth-first buffer; readers take a root offset and traverse vtable-style field offsets. You can fetch one field without materializing siblings as heap objects. That *is* deserialization in the information sense (you interpret bytes as typed fields); it is **not** the classic “allocate full DTO” deserialization.

---

## How it works

### Layout contract

Fields sit at known alignments; strings/vectors use offsets; optional fields may use presence in a vtable. The format picks endianness (commonly little-endian) so matching hosts can load integers without per-field swaps. This is the advanced form of the lesson in [memory layout](memory-layout.md): a **portable, versioned mock** of a friendly memory image—not a raw `struct` dump with host pointers.

### Encode path is not free

Builders must produce a correct buffer (packing, offsets, padding). Workloads that constantly mutate messages may find classic “struct then serialize” simpler. Zero-copy shines when **messages are built once and read many times**, or when only a few fields are touched on huge messages.

### Validation

Skipping object materialization must not mean skipping **bounds and structure checks** on untrusted data. FlatBuffers-style stacks provide verifiers; using them on hostile input is part of the security story in [Engineering](../engineer_perspective.md). An unverified buffer is a bag of offsets an attacker can aim at your process.

### Mutation and ergonomics

In-place updates are constrained (space must already exist; length changes are painful). Many teams treat buffers as **immutable messages** and rebuild when state changes. Debugging requires format-aware tools; hex dumps are weaker than JSON logs.

### Related ideas (not identical)

- **mmap + columnar formats** (Arrow/Parquet paths) zero-copy *columns* for analytics—different problem domain ([data science](../data_science_perspective.md)).
- **`span`/buffer APIs** on ordinary codecs reduce copies without a full zero-copy message format.
- **Schema-driven Protobuf** still usually materializes objects (or uses arena/pooling variants)—fast, but not the same model.

---

## Costs & constraints

| Axis | Typical zero-copy effect | Still your problem |
|------|--------------------------|--------------------|
| CPU (read path) | Lower for sparse access / large messages | Verify cost; random access patterns |
| CPU (write path) | Builder complexity; not always faster than packed encode | — |
| Memory / allocations | Fewer objects on read | Buffer lifetime must outlive views |
| Size / bandwidth | Competitive; layout may pad for alignment | Not magic compression ([compression article](compression-is-not-a-format.md)) |
| Evolution | Schema/IDL still required | Compatibility discipline remains |
| Security | Great performance if you skip verify—**don’t** | Always verify untrusted buffers |
| Operability | Specialized inspectors | Weaker ad-hoc log readability |

---

## Real-world example

A game or mobile client downloads a large catalog message. UI needs a handful of fields per screen. A classic decode allocates thousands of objects at load; a FlatBuffers-style buffer maps (or holds) once, verifies once, and reads fields on demand. The same pattern appears in some RPC or IPC paths for large immutable configuration snapshots. It is a poor fit for tiny JSON-shaped CRUD payloads where builder friction exceeds any gain—and a worse fit if the team refuses schema tooling.

---

## In this suite

Where FlatBuffers or similar codecs are **registered** for a language, treat them as **schema-driven / specialized layout** entries and compare carefully against other schema-driven libraries on the **same language Results** page. Absence in a language harness means “not measured here,” not “irrelevant to the industry.” Categories and overviews are the source of truth for what is wired today: [Serialization categories](../../analysis/serialization_categories.md).

---

## Common mistakes

- Reading “no deserialize” as “no CPU and no schema.”
- Using zero-copy buffers from the network **without verification**.
- Holding views into a buffer that was freed, recycled, or overwritten.
- Choosing zero-copy for small, highly mutable messages because a benchmark used huge static ones.
- Comparing an unverified zero-copy path to a fully validating classic parser on speed alone.

---

## Key takeaways

- Zero-copy means **in-place field access** from a designed layout, not “no interpretation of bytes.”
- “Don’t deserialize” targets the classic **allocate full object graph** step.
- Encode/build and **verification** still cost; security requires the latter for untrusted data.
- Best fit: large or sparsely read, mostly immutable messages with schema tooling acceptance.
- Poor fit: tiny mutable documents, teams that need text debuggability above all.
- Related but distinct: columnar/Arrow zero-copy and ordinary buffer-oriented APIs.
- Always interpret suite numbers in light of validation settings and access patterns.

---

## Next

[Compression is not a format](compression-is-not-a-format.md) — why gzip on JSON is not a substitute for choosing an encoding.

**See also:** [Memory layout](memory-layout.md) · [Engineering perspective](../engineer_perspective.md)
