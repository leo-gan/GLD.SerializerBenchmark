# Compression is not a format

> After this page you can separate general-purpose compression from serialization choices—and know when each tool actually helps.

---

## Problem

A common escalation path when bandwidth or storage is expensive:

1. Payloads are large.  
2. Someone enables **gzip/brotli/zstd** on the HTTP connection or file.  
3. The team concludes serialization format “doesn’t matter” because compression “fixes size.”

Sometimes that is good enough. Often it hides **CPU cost**, **latency**, and **missed structure-aware savings**—or produces a false sense that an inefficient encode is free.

---

## Short answer

**Serialization** defines *which bytes* represent which values (types, field identity, layout). **Compression** is a mostly **semantics-agnostic** transform that finds redundancy in a byte stream. Compression can shrink verbose encodings (JSON with repeated keys) dramatically, but it costs CPU, can hurt latency on small messages, and does not give you schema evolution, type safety, or zero-copy access. Format-aware techniques (varints, dictionary encoding, columnar layouts, omitting field names) remove redundancy **using knowledge of the data model**. Prefer: choose a suitable format for the contract and access pattern; **then** apply compression when the link or storage tier still needs it and profiles say the trade is worth it.

---

## Mental model

```text
  Application values
        │
        ▼
  Serialization format  ──►  structured byte sequence
        │
        ▼
  Optional compression  ──►  opaque smaller blob
        │
        ▼
  Network / disk

  Compression does not know that bytes 12–15 “are user_id”.
  The format does (via schema, tags, or layout).
```

Layering is fine and common (`application/json` + `Content-Encoding: gzip`). Collapsing the two into one decision is the mistake.

---

## How it works

### General-purpose compressors

Algorithms like gzip, brotli, and zstd look for repeated substrings and statistical redundancy. They work on **any** bytes:

- Highly repetitive JSON (same keys every object) often compresses **very** well.
- Already-dense binary may shrink only modestly (less redundancy left).
- Tiny messages may **grow** slightly (headers/dictionaries) or not justify the CPU.

### Format-aware density

Examples of structure helping size **without** a second codec stage:

- Omit repeated field **names** (schema-dependent encodings).
- Use **varints** or small enums instead of wide text numbers.
- **Columnar** formats (Parquet, ORC) apply encodings and compression **per column**, which often beats row-oriented JSON+gzip for analytics scans—see [data science perspective](../data_science_perspective.md).
- Domain encoding (delta timestamps, dictionary-coded categories).

These remain **interpretable** under the format rules; a random gzip blob is not a schema.

### CPU and latency

Compression moves cost from **bandwidth** to **CPU** (both ends). On loopback or high-speed datacenter links, compressing small RPC messages can **increase** end-to-end latency. On mobile or cross-region links, the same trade may win. Measure the **whole path**: encode → compress → transfer → decompress → decode.

### Security and framing

Compressed untrusted data has a history of **decompression bombs**. Limits on decoded size matter whether the outer wrapper is HTTP or a custom stream. Compression also interacts with encryption (CRIME/BREACH-class lessons for secrets adjacent to attacker-controlled plaintext—know your threat model for TLS + compress).

---

## Costs & constraints

| Axis | Compression on a verbose format | Denser format (± light compress) |
|------|----------------------------------|-----------------------------------|
| Size | Often large wins on JSON-like data | Competitive; less “easy” redundancy |
| CPU | Extra cycles every message | More work in encode/decode; less in compress |
| Latency | Hurts small/hot messages; helps fat/slow links | Depends on codec; no blanket rule |
| Random access | Must decompress stream/block first | Some formats allow field/columnar access |
| Evolution / types | Unchanged by gzip | Still owned by the format/contract |
| Operability | Easy knob on proxies | Need format expertise |

---

## Real-world example

**A.** A public API keeps JSON for partners. Enabling gzip at the edge cuts transfer size enough that a format migration is deferred—correct **if** CPU headroom exists and payloads are large enough.

**B.** An internal hot path ships multi-megabyte JSON arrays between services on a 10 GbE network with gzip “because production HTTP defaults.” Profiles show cores busy in deflate while NICs idle. Switching to a dense binary schema **without** compression (or with a cheaper level/algorithm on larger batches only) improves tail latency more than another gzip tuning pass.

**C.** An analytics lake stores gzipped JSON lines for a year. Query engines scan far more data than a Parquet layout with columnar encodings would. Compression was applied; **the format was still wrong for the workload**.

---

## In this suite

The harness focuses on **serializer** behavior (encode/decode of logical fixtures), not a full matrix of compress-wrapped transports. Do not read **Results** as “gzip unnecessary” or “always use binary.” Use them to pick a codec family/implementation; evaluate compression on **your** deployment path separately (or as an explicit follow-on benchmark outside the core tables).

---

## Common mistakes

- Treating `gzip(JSON)` as architecturally equivalent to a schema-driven binary protocol.
- Compressing tiny chatty RPCs by default “for consistency.”
- Ignoring double duty: encrypt/compress/encode ordering and CPU budgets.
- Assuming already-compressed media (images, video) benefit from another gzip layer on the same bytes.
- Using compression success as permission to skip validation and evolution design.

---

## Key takeaways

- Serialization chooses **meaning-bearing layout**; compression finds **byte redundancy**.
- Both can shrink data; only the format defines types, evolution, and access patterns.
- JSON+gzip can be a valid edge strategy; it is not a universal architecture.
- Dense/schema-aware encodings remove redundancy the compressor would otherwise re-detect—often with better access properties.
- Always account for **CPU and latency**, not only compressed size.
- Columnar + format-aware encoding is a different (analytics) game than RPC message codecs.
- Suite **Results** inform codec choice; re-measure with compression on your wire if that is part of the design.

---

## Next

Return to the [Deep dives hub](index.md) or apply the decision sketch in [Serialization categories](../../analysis/serialization_categories.md). For service-oriented defaults, see [Engineering perspective](../engineer_perspective.md); for lakes and pipelines, [Data science perspective](../data_science_perspective.md).

**See also:** [Encode/decode cost](encode-decode-cost.md) · [Benchmarks hub](../../analysis/index.md)
