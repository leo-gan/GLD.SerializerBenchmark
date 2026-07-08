# Latency tails, allocations, and GC

## Problem

Mean serialize time looks fine while p99 collapses under load. Managed runtimes pay for **allocation rate** with garbage-collection pauses; native heaps pay with allocator contention and cache misses. Codecs that “win” microbenchmarks by allocating per field can lose the service-level objective. Charts that show only means hide the failure mode.

## Short answer

Treat **allocation and copy behavior** as first-class when choosing among implementations in a family ([implementation variance](implementation-variance.md)). Prefer APIs that reuse buffers, stream, or reduce temporary strings when p99 matters. Interpret suite **means** as a starting point; validate under concurrency with **your** runtime GC settings and payload shape (201 [encode/decode cost](../201/encode-decode-cost.md)). Format brand does not determine GC pressure—implementation and shape do.

## Constraints that matter

| Factor | Effect on tails |
|--------|-----------------|
| Allocations per message | GC or allocator work |
| Payload shape | Deep graphs → many objects |
| Concurrency | Parallel allocate → pause clustering |
| Buffer reuse | Lowers steady-state pressure |
| Native vs managed | Different pause mechanics, same “don’t thrash the allocator” lesson |

## Decision frame

```text
  SLO is p99/p999 under load?
    → inspect allocs / pooling / streaming options
    → load-test; do not stop at mean Results
  Mean-only batch job nightly?
    → means may suffice; still watch memory ceiling
```

| Signal | Action |
|--------|--------|
| High alloc/op in profiler | Try alternate lib or object reuse |
| GC pause correlates with traffic | Reduce chattiness of decode |
| Size fine, latency bad | CPU/alloc path—not network |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Optimizing mean only | p99 pages at peak |
| Ignoring shape | Microbench on tiny structs misleads |
| Cross-language GC comparison | Invalid |
| Disabling GC in bench | Fantasy numbers |
| Pooling without clear ownership | Use-after-free / data races |

## Real-world sketch

Two JSON libraries show similar mean decode on Python Results. Production p99 diverges: one builds full `dict` trees; another binds into typed objects with fewer temporary strings. A load test with production-shaped payloads and workers decides the pin—not the mean column alone.

## In this suite

| Resource | Role |
|----------|------|
| **Results** means / ops | Orientation within language |
| Methodology | Warmup, outliers—read before quoting |
| Optional memory metrics | If present for a language, use cautiously |
| [Using this suite](using-this-suite.md) | Fair slice checklist |

Many published tables emphasize central tendency; **you** still owe a concurrent validation.


## Experiments

**Question:** Under production-shaped load, is encode/decode **allocation pressure** (not mean time alone) driving p99 risk for candidate libraries in the same family?

### Setup
1. Fix **one language**, **one paradigm family**, and **one fixture** close to production shape (e.g. deep graph vs dense `Telemetry`)—see [using this suite](using-this-suite.md).  
2. Shortlist 2–3 implementations from language **Results** (same family); note versions.  
3. Confirm the harness reports or you can attach: wall times, optional `MemoryPeakBytes` / tracemalloc (Python), and a **process profiler** (alloc rate, GC pauses) outside pure means.  
4. Configure a load path that reuses your service concurrency model (workers, pool sizes)—not only single-threaded suite loops.

### Procedure
1. Run suite slice for candidates → record mean/median ser, deser, total; size; fidelity.  
2. If available, record `mean_memory_peak_bytes` / peak alloc columns.  
3. Load-test or profile each candidate on the same fixture at target concurrency; capture **p99/p999** latency and GC/alloc stats from the runtime.  
4. Optionally disable “fantasy” modes (e.g. GC off) only as a diagnostic—not as the decision number.  
5. Apply the decision rule below; pin library + version.

### Decision rule
- Prefer the candidate that meets **p99 SLO** with acceptable alloc/GC, even if mean is slightly worse.  
- Reject candidates that win mean Results but show high alloc/op or GC pause clustering under load.  
- Do **not** compare GC metrics across languages to choose a format brand.

## Metrics

Primary signals for this page’s decision (see also [Metrics catalog](../../analysis/METRICS.md)):

| Metric / signal | Where | Role |
|-----------------|-------|------|
| **p99 / p999 latency** (ser, deser, or end-to-end) | Load test / APM | **Primary**—tails are the SLO |
| `total_median_ns` / `ser_median_ns` / `deser_median_ns` | Suite analysis | Orientation within language; not sufficient alone |
| `total_mean_ns`, `avg_ops_per_sec` | Suite | Central tendency; easy to over-trust |
| `total_p95_ns` / `total_p99_ns` (if computed) | Suite / full metrics profile | Bridge from harness to tails when available |
| `total_std_ns` / CV / MAD | Suite | Dispersion hint; not production p99 |
| `mean_memory_peak_bytes` / `MemoryPeakBytes` | Suite (optional) | Alloc pressure proxy when present |
| **Allocations per op / alloc rate** | Profiler | Explains GC pressure |
| **GC pause time / frequency** | Runtime metrics | Direct tail mechanism on managed runtimes |
| `median_size_bytes` | Suite | Separates “big payload” from “alloc-heavy codec” |
| `mean_fidelity` | Suite | Reject broken codecs before performance debate |

**Conclusion style:** “Choose library L because p99 and alloc rate under load meet SLO; mean Results only shortlisted L.”  
**Not decision metrics here:** cross-language Results ranks; format brand alone.

## What this suite cannot tell you

- p99 under *your* framework and GC flags.  
- Interaction with other allocators on the host.  
- Whether pooling is safe in *your* concurrency model.

## Common mistakes

- “Binary always lower GC” without measuring.  
- Comparing C# and Python pause behavior for format choice.  
- Shipping the fastest mean lib that allocates unbounded on hostile input ([untrusted input](untrusted-input.md)).

## Key takeaways

- Tails track **allocations and shape**, not slogans.  
- Means are necessary, not sufficient, for latency SLOs.  
- Pick implementations with runtime behavior in mind.  
- Confirm under load outside the harness.
