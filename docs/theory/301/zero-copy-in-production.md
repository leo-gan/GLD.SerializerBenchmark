# 3.8 Zero-Copy in Production

## Problem Statement

Microbenchmarks frequently highlight zero-copy (random-access) formats such as FlatBuffers, Cap'n Proto, and `rkyv` with near-zero "deserialization" times because the reader interprets fields directly through byte offsets inside a buffer rather than allocating an object graph (see [2.7 Zero-copy layouts](../201/zero-copy.md)).

In production, however, the wire mechanism is rarely the deciding factor. Teams encounter mandatory buffer-verification costs on untrusted inputs, awkward bottom-up builder APIs for mutable documents, async buffer-lifetime hazards, and uneven multi-language tooling. Adopting zero-copy is therefore an **operational trade-off**, not a universal upgrade over classic parsing.

---

## When Zero-Copy Pays Off: A Cost Model

Let a payload contain $F$ total fields, of which a reader inspects only $k \le F$ fields. Compare classic deserialization against a verified zero-copy layout:

$$
T_{\text{classic}} \approx T_{\text{parse}}(F) + T_{\text{alloc}}(F)
\qquad\text{vs.}\qquad
T_{\text{zero-copy}} \approx T_{\text{verify}}(B) + k \cdot T_{\text{offset}}
$$

where $T_{\text{verify}}(B)$ is the cost of validating offsets, bounds, alignment, and recursion depth across a buffer of size $B$, and $T_{\text{offset}}$ is the per-field pointer/vtable lookup cost.

- **Sparse reads on large buffers ($k \ll F$, large $B$):** Zero-copy eliminates $T_{\text{alloc}}(F)$ and avoids decoding untouched fields. If the buffer originates inside a verified trust domain (e.g., an immutable memory-mapped asset built offline), $T_{\text{verify}}$ is paid once at load time rather than per read.
- **Dense reads on small messages ($k \approx F$, small $B$):** If every field is read and copied into application domain objects anyway, $T_{\text{verify}}(B)$ plus vtable indirections often equals or exceeds a fast classic binary decoder (such as `prost` or `speedy`) while sacrificing ergonomic structs and wire compactness.

| Operational Factor | Favors Zero-Copy | Argues for Classic Decode |
|---|---|---|
| **Message size & selectivity** | Large messages ($\ge$ tens of KB) with sparse field reads | Small RPC records where almost all fields are read |
| **Mutability** | Build once, read many times (config blobs, game state, mmap indexes) | Frequent field edits (CRUD APIs, stateful workflows) |
| **Trust posture** | Trusted offline artifacts, or budget explicitly includes verifier cost | Untrusted inputs where verifier overhead erases the speed gain |
| **Cross-language estate** | Mature bindings and verifiers in every participating language | Mixed runtimes with missing or immature bindings |
| **Buffer ownership** | Clear, synchronous buffer lifetime (mmap, arena, ref-counted slice) | Async handlers holding field references across `.await` or pool reuse |

---

## Non-Negotiable Production Safeguards

### 1. Mandatory Verification on Untrusted Boundaries

!!! warning "Security Invariant: Never Skip the Verifier"
    A zero-copy accessor interprets **untrusted integers as memory offsets**. Without a bounds, alignment, and traversal-limit verifier, a crafted payload can trigger out-of-bounds reads, infinite pointer cycles (aliasing attacks), or CPU amplification bombs.[^1][^2]

Benchmarking an unverified zero-copy reader against a validating classic parser produces a **category error**: the comparison drops safety from one side of the equation. On any network, queue, or shared-cache boundary, verification time $T_{\text{verify}}$ must be included in both latency budgets and load tests.

### 2. Buffer Lifetime and Aliasing Discipline

Zero-copy views borrow directly from the backing byte slice:

- **No dangling views:** In C/C++ (or unsafe bindings), returning a zero-copy view after a pooled network buffer is recycled causes use-after-free corruption. In Rust, borrow-checker lifetimes prevent dangling pointers statically, often requiring reference-counted buffers (`Bytes` / `Arc<[u8]>`) across async tasks.
- **Alignment guarantees:** Formats like `rkyv` and Cap'n Proto require aligned backing buffers (e.g., 8- or 16-byte alignment). Reading directly from an unaligned network socket buffer without alignment checks causes undefined behavior or hardware faults on strict-alignment architectures.[^3]

### 3. Operational Failure Modes

| Mistake | Operational Consequence |
|---|---|
| **Skipping verification on an "internal" network** | Memory-safety crashes or RCE upon lateral movement or corrupt producer bytes |
| **Forcing zero-copy onto CRUD APIs** | Complex bottom-up builders and full-buffer rebuilds on every minor field update |
| **Timing materialization instead of field access** | Copying the entire zero-copy buffer into native structs negates the zero-copy advantage (see [4.10 Rust rkyv vs. speedy](../401/rust-rkyv-vs-speedy.md)) |
| **Unbounded traversal of overlapping offsets** | DAG-shaped offset aliasing turns a 1 KB FlatBuffer or Cap'n Proto message into gigabytes of logical reads unless traversal limits are enforced[^2] |

---

## Evaluation Protocol and Benchmark Limits

Before adopting a zero-copy layout in production:

1. **Benchmark the real access pattern:** Measure time-to-first-field or sparse-read latency ($k$ fields read), *not* full object-tree materialization, against a classic decoder baseline.
2. **Include verification in every untrusted path:** Measure $T_{\text{verify}} + k \cdot T_{\text{offset}}$ with the library's verifier enabled (`FlatBuffers::Verifier`, `bytecheck` for `rkyv`, or Cap'n Proto traversal limits).
3. **Fault-inject hostile buffers:** Fuzz truncated buffers, out-of-range offsets, misaligned headers, and cyclic/aliased tables; confirm the verifier fails closed with bounded CPU and memory.
4. **Check suite caveats:** In this benchmark suite, standard decode benchmarks materialize the full payload to verify `mean_fidelity`. Read each language Overview and [4.10 Rust rkyv vs. speedy](../401/rust-rkyv-vs-speedy.md) carefully before interpreting zero-copy rows on the [Dashboard](../../dashboard/index.html).

**Limits of this benchmark suite:** Full round-trip timing penalizes zero-copy layouts that excel at sparse reads on memory-mapped buffers, while single-language runners do not measure builder ergonomics, async buffer-pooling complexity, or cross-language verifier parity.

---

## Exercises

1. **Selectivity break-even:** A 120 KB configuration blob contains 500 fields. Classic JSON parsing takes $480\ \mu\text{s}$ and allocates 1,200 heap objects. Verified FlatBuffers access takes $T_{\text{verify}} = 35\ \mu\text{s}$ plus $0.5\ \mu\text{s}$ per accessed field. If each request reads $k = 6$ fields, what is the latency reduction? Would zero-copy still win if the service cached the parsed JSON object once at startup and served 100,000 requests/second from RAM?

??? note "Solution"
    - **Per-request read:** Verified FlatBuffers takes $35 + 6 \times 0.5 = 38\ \mu\text{s}$ versus $480\ \mu\text{s}$ ($12.6\times$ faster, zero per-request heap churn).
    - **Cached once at startup:** If the configuration is parsed once into an immutable in-memory struct and reused for 100,000 req/s, the $480\ \mu\text{s}$ startup parse cost amortizes to zero—ordinary native structs in RAM are faster, simpler, and avoid vtable indirection altogether. Zero-copy wins when buffers arrive or change frequently relative to reads (e.g., per-request blobs or multi-gigabyte memory-mapped assets that exceed process RAM budgets).

2. **Aliasing (amplification) attack:** Explain how a 2 KB FlatBuffers or Cap'n Proto buffer can cause a reader that traverses all logical elements to visit gigabytes of data without exceeding buffer bounds, and name the defense.

??? note "Solution"
    Because offsets can point to the **same** subtable repeatedly, a short chain of tables where each table stores two offsets to the next table forms a directed acyclic graph (DAG) with $2^d$ logical paths in $O(d)$ bytes. Simple bounds checks pass because every offset lies inside the 2 KB buffer. The defense is a **traversal limit** (counting total visited bytes/tables during verification or reading, as built into Cap'n Proto's `ReaderOptions` and FlatBuffers' verifier table-count cap) that rejects messages exceeding a budget.

3. **Benchmark interpretation:** On the Rust Dashboard, a benchmark runner decodes `rkyv` by checking the buffer and calling `.deserialize()` into an owned `struct` to verify round-trip fidelity. Why does that timing misrepresent `rkyv`'s intended production advantage?

??? note "Solution"
    Calling `.deserialize()` forces full heap allocation and copying of every field—eliminating the zero-copy benefit while retaining `rkyv`'s alignment and byte-check overhead. Zero-copy layouts are meant to be read directly via archived references (`&ArchivedT`) without materializing owned copies.

---

## References

[^1]: FlatBuffers Documentation. *Use in C++ / Buffer Verification (`flatbuffers::Verifier`)*. <https://flatbuffers.dev/>
[^2]: Varda, K. *Cap'n Proto: Security & Amplification Attacks (Traversal Limit)*. <https://capnproto.org/encoding.html>
[^3]: Koloski, D. *rkyv Architecture and ByteCheck Validation*. <https://rkyv.org/>
