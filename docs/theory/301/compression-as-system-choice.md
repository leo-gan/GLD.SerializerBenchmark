# Compression as a system choice

## Problem

Bandwidth tickets often trigger “enable compression” as a global default. Small RPCs get slower; already-compressed media is double-compressed; teams stop improving message design because “gzip will fix size.”

**Compression** here means general-purpose algorithms such as gzip or zstd that shrink opaque byte sequences by finding redundancy. Serialization 201 explains the mechanism ([compression vs format](../201/compression-is-not-a-format.md)). Serialization 301 places compression in **budgets and tiers**: where it sits in the stack, when it pays, and when it hurts.

---

## Short answer

Choose a **format for meaning** first. Add **compression as a transport or storage tier** when payloads are large enough that trading CPU for bandwidth is a net win under measurement. Prefer dense schema-aware encodings when structure allows; use general-purpose compression for verbose text or cold storage. Do not treat suite encode times as including your link-level gzip unless the experiment says so.

In other words: compression is a layer you place deliberately, not a substitute for choosing the right serialization format.

---

## Constraints that matter

| Budget | Question |
|--------|----------|
| **CPU** | Does the path encode, compress, and decrypt on every request? |
| **Bandwidth and storage** | Do they dominate the cost model? |
| **Latency** | For small messages, compression can hurt |
| **Content** | Is the payload already compressed media? |
| **Layering** | Where do TLS, HTTP content-encoding, and application-level compression sit relative to each other? |

This matters because each extra CPU stage can dominate when messages are tiny and the network is already fast.

---

## Decision frame

```text
  Message tiny and network local?
        → often skip general-purpose compression
  Verbose JSON over a WAN or cold store?
        → compress after measuring
  Need field access and evolution?
        → choose format first; compress opaque bytes after
```

| Scenario | Lean |
|----------|------|
| Public HTTP with large JSON | HTTP content-encoding plus a good JSON library |
| High-QPS internal RPC around 200 bytes | Usually no application-level gzip |
| Lake files | Format-aware columnar compression |
| Encrypted tunnel plus gzip | Order of layers and stacked CPU cost matter |

A **WAN** is a wide-area network (for example, the public internet between regions). Latency and bandwidth costs there often justify compression more than on a local data-center hop.

---

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Compress everything | CPU-bound services |
| Skip format design | Permanent tax from verbose encodings |
| Double compress | Wasted work |
| Compare compressed size to the suite Size column naively | Category error |
| Forget mobile CPU cost | Battery and heat regressions |

For example, JPEG images and video are already compressed. Running gzip over them usually costs CPU and gains almost nothing.

---

## Real-world sketch

An API enables gzip globally. Median latency improves for 100KB responses; p99 for 1KB control RPCs worsens. Operations keeps gzip for large GET responses via content negotiation and disables it on chatty RPCs. Separately, internal events move from JSON to Protobuf, cutting size before compression—and compression becomes optional on the mesh.

---

## In this suite

| Resource | Role |
|----------|------|
| Size and time **Results** | Uncompressed codec behavior (typical) |
| 201 compression article | Mechanism explanation |
| [Using this suite](using-this-suite.md) | What is and is not measured |

---

## Experiments

**Question:** Where should **compression** sit (application codec versus transport versus storage), and does it beat a denser binary format for *this* link?

### Setup

1. Measure uncompressed payload sizes and link round-trip time and bandwidth.
2. List candidates: gzip/zstd levels; an alternative binary format without compression; compress-after-serialize.
3. Estimate CPU headroom on producer and consumer.

### Procedure

1. Baseline: suite `median_size_bytes` plus serialize/deserialize time without compression.
2. Apply candidate compression on the wire; measure **end-to-end** latency and CPU.
3. Compare to a denser format **without** compression on the same hop.
4. Check for double-compression waste (for example already-compressed fields).
5. Pick placement (client, reverse proxy, broker, or application).

### Decision rule

- Choose the option that minimizes **service-level latency or cost per bandwidth** under the CPU cap—not the smallest microbenchmark size alone.
- Compression is not a substitute for a wrong paradigm ([row vs columnar](row-vs-columnar.md)).

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **End-to-end latency with compression** | **Primary** when user-facing |
| Compressed size and compression ratio | Bandwidth economics |
| CPU percent for serialize+compress and deserialize+decompress | Capacity limit |
| Suite `median_size_bytes` (raw codec) | Pre-compress baseline |
| Suite serialize/deserialize times | Codec CPU before compression |
| Planned `size_gzip6` / `size_zstd3` (if present) | Suite compression proxies |
| Error rate under CPU saturation | Stability |

**Conclusion style:** “zstd on the broker beats switching format for this topic size; application-level gzip stays off.”

---

## What this suite cannot tell you

- The optimal zstd level for *your* corpus.
- CDN behavior.
- Interaction with specific TLS offload hardware.

---

## Common mistakes

- Claiming “we use binary so we don’t need gzip” without size data.
- Claiming “we use gzip so format doesn’t matter.”
- Benchmarking with compression off, then enabling it only in production.

---

## Key takeaways

- Compression is a **tier**, not a format.
- Measure CPU versus bandwidth; defaults are not universal.
- Improve encoding when structure allows; compress the remainder.
- Suite Size is not automatically post-gzip Size.
