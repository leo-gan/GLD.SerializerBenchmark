# Compression as a system choice

## Problem

Bandwidth tickets trigger “enable compression” as a global default. Small RPCs get slower; already-compressed media is double-compressed; teams stop improving message design because “gzip will fix size.” 201 explains the mechanism ([compression vs format](../201/compression-is-not-a-format.md)); 301 places compression in **budgets and tiers**.

## Short answer

Choose a **format for meaning** first; add **compression as a transport or storage tier** when payloads are large enough that CPU trades for bandwidth positively under measurement. Prefer dense schema-aware encodings when structure allows; use general-purpose compression for verbose text or cold storage. Do not treat suite encode times as including your link-level gzip unless the experiment says so.

## Constraints that matter

| Budget | Question |
|--------|----------|
| **CPU** | Encode + compress + decrypt on path? |
| **Bandwidth / storage** | Dominates cost model? |
| **Latency** | Small messages: compression can hurt |
| **Content** | Already compressed media? |
| **Layering** | TLS, HTTP content-encoding, app-level |

## Decision frame

```text
  Message tiny + local network? → often skip general compression
  Verbose JSON over WAN / cold store? → compress after measuring
  Need field access / evolution? → format first; compress opaque bytes after
```

| Scenario | Lean |
|----------|------|
| Public HTTP large JSON | content-encoding + good JSON lib |
| High-QPS internal RPC 200 B | Usually no app gzip |
| Lake files | Format-aware columnar compression |
| Encrypted tunnel + gzip | Order and CPU stacking matter |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Compress everything | CPU-bound services |
| Skip format design | Permanent verbose tax |
| Double compress | Wasted work |
| Compare compressed size to suite Size column naively | Category error |
| Forget mobile CPU cost | Battery / heat regressions |

## Real-world sketch

An API enables gzip globally. p50 improves for 100KB responses; p99 for 1KB control RPCs worsens. Ops keeps gzip for large GETs via content negotiation and disables it on chatty RPCs. Separately, internal events move from JSON to Protobuf, cutting size before compression—and compression becomes optional on the mesh.

## In this suite

| Resource | Role |
|----------|------|
| Size / time **Results** | Uncompressed codec behavior (typical) |
| 201 compression article | Mechanism |
| [Using this suite](using-this-suite.md) | What is and is not measured |


## Experiments

**Question:** Where should **compression** sit (app codec vs transport vs storage), and does it beat a denser binary format for *this* link?

### Setup
1. Measure uncompressed payload sizes and link RTT/bandwidth.  
2. Candidates: gzip/zstd levels; alternative binary format without compress; compress-after-serialize.  
3. CPU headroom on producer/consumer.

### Procedure
1. Baseline: suite `median_size_bytes` + ser/deser time without compress.  
2. Apply candidate compression on the wire; measure **end-to-end** latency and CPU.  
3. Compare to denser format **without** compress on same hop.  
4. Check double-compression waste (e.g. already-compressed fields).  
5. Pick placement (client, reverse proxy, broker, app).

### Decision rule
- Choose the option minimizing **SLO latency or $/bandwidth** under CPU cap—not the smallest microbenchmark size alone.  
- Compression is not a substitute for a wrong paradigm ([row vs columnar](row-vs-columnar.md)).

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **End-to-end latency with compress** | **Primary** when user-facing |
| Compressed size / compression ratio | Bandwidth economics |
| CPU % ser+compress / deser+decompress | Capacity limit |
| Suite `median_size_bytes` (raw codec) | Pre-compress baseline |
| Suite ser/deser times | Codec CPU before compress |
| Planned `size_gzip6` / `size_zstd3` (if present) | Suite compression proxies |
| Error rate under CPU saturation | Stability |

**Conclusion style:** “zstd on broker beats switching format for this topic size; app-level gzip off.”

## What this suite cannot tell you

- Optimal zstd level for *your* corpus.  
- CDN behavior.  
- Interaction with specific TLS offload hardware.

## Common mistakes

- “Binary so we don’t need gzip” without size data.  
- “Gzip so format doesn’t matter.”  
- Benchmarking compress off then enabling it only in prod.

## Key takeaways

- Compression is a **tier**, not a format.  
- Measure CPU vs bandwidth; defaults are not universal.  
- Improve encoding when structure allows; compress the remainder.  
- Suite Size is not automatically post-gzip Size.
