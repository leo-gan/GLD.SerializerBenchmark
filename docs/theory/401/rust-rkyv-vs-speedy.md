# 4.10 Case Study: Zero-Copy Layouts Under Materialization (Rust)

## Problem Statement

**`rkyv`** is designed for zero-copy deserialization: a reader validates an aligned byte buffer and accesses `&ArchivedT` directly through relative offsets without allocating an owned object tree (see [2.7 Zero-copy layouts](../201/zero-copy.md) and [3.8 Zero-copy in production](../301/zero-copy-in-production.md)). Yet on this suite's `document` payload ($n = 1$, `bytes` mode), **`Speedy`** outperforms `rkyv` on both encode and decode while emitting a smaller buffer (214 B vs. 272 B).

Inspecting the Rust runner reveals why: **zero-copy is a calling pattern (`rkyv::access`), not a property automatically conferred by importing a crate.** When a benchmark runner calls `rkyv::from_bytes` to materialize an owned `Document` for full field-by-field fidelity checking, `rkyv` pays archive construction, alignment padding, validation, *and* full heap allocation.

> **Illustrative L1 snapshot (`document`, $n = 1$, `bytes` mode):** Live authoritative numbers belong to the [Rust Dashboard comparison](../../dashboard/index.html?lang=rust&standard=custom&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=speedy&ser=rkyv&ser=speedy#compare) ([Claims L1](../../analysis/CLAIMS_AND_REPLICATION.md) · [Rust Overview](../../rust/index.md)).

| Metric (Quoted L1 Snapshot) | `Speedy` 0.8.7 | `rkyv` 0.8.17 (Materialized) |
|---|---:|---:|
| Throughput (encode + decode) | **2.84M ops/s** | 1.64M ops/s |
| Encode latency | **88 ns** | 314 ns |
| Decode latency | **264 ns** | 296 ns |
| Encoded wire size | **214 B** | 272 B |

---

## Source-Level Call Sites

Both adapters live in `rust/src/serializers/direct.rs`:

```rust
// Speedy: direct fixed-width pack/unpack
fn speedy_ser_document(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Document(v) = fx else { bail!("speedy: expected Document"); };
    v.write_to_stream(&mut *out)?;
    Ok(())
}
// decode: Document::read_from_buffer(d)
```

```rust
// rkyv: archive build + copy on encode; validate + owned materialization on decode
fn rkyv_ser_document(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Document(v) = fx else { bail!("rkyv: expected Document"); };
    let bytes = rkyv::to_bytes::<rkyv::rancor::Error>(v)?;
    out.extend_from_slice(bytes.as_ref());
    Ok(())
}
fn rkyv_de_document(data: &[u8]) -> Result<Document> {
    rkyv::from_bytes::<Document, rkyv::rancor::Error>(data)
}
```

---

## Mechanistic Analysis

### Why `rkyv` Encode Is Slower and Larger (314 ns / 272 B vs. 88 ns / 214 B)

`rkyv` serializes values into a **relocatable memory image** (an archive) rather than a packed byte stream:[^1]

1. Every string and `Vec` requires writing child payloads first, computing **relative pointers** (`RelPtr`) back to those locations, and inserting **alignment padding** (4- and 8-byte boundaries) so archived references satisfy Rust's hardware alignment invariants.
2. In the runner above, `rkyv::to_bytes` allocates an `AlignedVec` internally, and `out.extend_from_slice` copies those 272 bytes into the runner's output `Vec<u8>`.

The 58 extra bytes relative to `Speedy` are not field names—they are relative-pointer metadata and alignment padding required to make zero-copy field access legal later.

### Why `rkyv` Decode Loses Under `from_bytes` (296 ns vs. 264 ns)

In `rkyv` 0.8, `rkyv::from_bytes::<Document, _>(data)` executes **two** phases:

1. **ByteCheck validation (`rkyv::access`):** Verifies buffer alignment, UTF-8 validity, enum discriminants, and relative-pointer bounds to obtain `&ArchivedDocument`.
2. **Owned deserialization (`rkyv::deserialize`):** Walks `&ArchivedDocument`, allocating owned `String` and `Vec` buffers on the heap to construct a brand-new `Document`.

Because the suite's round-trip fidelity check compares owned `Document` values, the runner calls `from_bytes` instead of stopping at `rkyv::access(data)`. That keeps `rkyv` on an identical owned-value boundary as `Speedy` ([Timing honesty](../../analysis/TIMING_HONESTY.md)), while illustrating that **materializing a zero-copy archive discards its primary architectural advantage**:

| Pipeline Stage | `Speedy` (Timed) | `rkyv::from_bytes` (Timed) | `rkyv::access` (Not Timed) |
|---|---|---|---|
| **Encode** | Packed fixed-width write into `out` | Build aligned archive + copy to `out` | Same aligned archive |
| **Decode** | Read packed bytes $\to$ owned `Document` | Validate archive + allocate owned `Document` | Validate archive $\to$ `&ArchivedDocument` (zero heap alloc) |
| **Read `doc.status`** | Field load from owned struct | Field load from owned struct | Direct 4-byte offset load from buffer |

*(The same materialization principle applies to FlatBuffers wrappers that copy every field into native objects; see [Swift: FlatBuffers vs. SwiftProtobuf](../../analysis/call-sites/swift-flatbuffers-vs-protobuf.md).)*

---

## Exercises

1. **Identifying the zero-copy entry point:** In `rust/src/serializers/direct.rs`, which function does the runner call on decode, and what API would a zero-copy production reader call instead?

??? note "Solution"
    The runner calls **`rkyv::from_bytes::<Document, _>(data)`**, which validates *and* allocates an owned `Document`. A zero-copy reader calls **`rkyv::access::<ArchivedDocument, _>(data)`** (or `access_unchecked` only on already-verified trusted memory) to borrow `&ArchivedDocument` directly from the aligned byte buffer with zero heap allocations.

2. **When `rkyv` wins despite higher encode cost:** Explain why a read-heavy lookup table (written once offline and memory-mapped by 1,000 worker processes reading 2 fields per query) benefits strongly from `rkyv` even though `rkyv` is slower and larger than `Speedy` on `document` ($n = 1$).

??? note "Solution"
    Offline encoding amortizes `rkyv`'s 314 ns build cost to zero at serving time. Via `mmap` + `rkyv::access`, workers read the 2 required fields directly from page-cached memory without allocating a single object or touching the remaining untouched fields—whereas `Speedy` would have to parse and allocate the entire catalog into RAM.

3. **Alignment pitfall:** If a network socket hands your Rust service an unaligned `&[u8]` slice (`addr % 8 != 0`), what happens when calling `rkyv::access::<ArchivedDocument, _>(slice)`?

??? note "Solution"
    `ByteCheck` rejects the unaligned slice with an alignment error (preventing undefined behavior from misaligned Rust references). Callers reading from unaligned network buffers must first copy into an aligned buffer such as `rkyv::util::AlignedVec`—re-introducing a copy that must be counted in latency budgets ([3.8 Zero-copy in production](../301/zero-copy-in-production.md)).

---

## References

[^1]: Koloski, D. *`rkyv` 0.8 Documentation: Architecture, `access`, and `from_bytes`*. <https://rkyv.org/>
