# Latency tails, allocations, and GC

## Problem

Mean serialize time looks fine while p99 (the 99th-percentile latency) collapses under load. Managed runtimes pay for **allocation rate** with garbage-collection (GC) pauses; native heaps pay with allocator contention and cache misses. Codecs that “win” microbenchmarks by allocating per field can lose the service-level objective. Charts that show only means hide the failure mode.

## Short answer

Treat **allocation and copy behavior** as first-class when choosing among implementations in a family ([implementation variance](implementation-variance.md)). Prefer APIs that reuse buffers, stream, or reduce temporary strings when p99 matters. Interpret suite **means** as a starting point; validate under concurrency with **your** runtime GC settings and payload shape (201 [encode/decode cost](../201/encode-decode-cost.md)). Format brand does not determine GC pressure—implementation and shape do.

## Constraints that matter

| Factor | Effect on tails |
|--------|-----------------|
| Allocations per message | GC work or allocator work |
| Payload shape | Deep graphs create many objects |
| Concurrency | Parallel allocate can cluster pauses |
| Buffer reuse | Lowers steady-state pressure |
| Native versus managed | Different pause mechanics, same lesson: do not thrash the allocator |

## Decision frame

```text
  Is the SLO p99 or p999 under load?
    → inspect allocations, pooling, and streaming options
    → load-test; do not stop at mean Results
  Is this a mean-only nightly batch job?
    → means may suffice; still watch the memory ceiling
```

| Signal | Action |
|--------|--------|
| High allocations per operation in the profiler | Try an alternate library or object reuse |
| GC pause correlates with traffic | Reduce how chatty decode is |
| Size looks fine, latency looks bad | Suspect the CPU or allocation path, not the network |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Optimizing mean only | p99 pages at peak traffic |
| Ignoring payload shape | Microbenchmarks on tiny structs mislead |
| Cross-language GC comparison | Invalid basis for format choice |
| Disabling GC in the bench | Fantasy numbers |
| Pooling without clear ownership | Use-after-free and data races |

## Real-world sketch

Two JSON libraries show similar mean decode on Python Results. Production p99 diverges: one builds full `dict` trees; another binds into typed objects with fewer temporary strings. A load test with production-shaped payloads and workers decides the pin—not the mean column alone.

## In this suite

| Resource | Role |
|----------|------|
| **Results** means and ops | Orientation within one language |
| Methodology | Warmup and outliers—read before quoting |
| Optional memory metrics | If present for a language, use them cautiously |
| [Using this suite](using-this-suite.md) | Fair slice checklist |

Many published tables emphasize central tendency; **you** still owe a concurrent validation.

## Experiments

**Question:** Under production-shaped load, is encode/decode **allocation pressure** (not mean time alone) driving p99 risk for candidate libraries in the same family?

### Setup

1. Fix **one language**, **one paradigm family**, and **one fixture** close to production shape (for example a deep graph versus dense `Telemetry`)—see [using this suite](using-this-suite.md).
2. Shortlist two or three implementations from language **Results** (same family); note versions.
3. Confirm the benchmark runner reports, or that you can attach: wall times, optional `MemoryPeakBytes` or tracemalloc (Python), and a **process profiler** for allocation rate and GC pauses outside pure means.
4. Configure a load path that reuses your service concurrency model (workers, pool sizes)—not only single-threaded suite loops.

### Procedure

1. Run the suite slice for candidates and record mean/median serialize, deserialize, and total time; size; and fidelity.
2. If available, record `mean_memory_peak_bytes` or peak allocation columns.
3. Load-test or profile each candidate on the same fixture at target concurrency; capture **p99/p999** latency and GC/allocation stats from the runtime.
4. Optionally disable “fantasy” modes (for example GC off) only as a diagnostic—not as the decision number.
5. Apply the decision rule below; pin library and version.

### Decision rule

- Prefer the candidate that meets the **p99 service-level objective** with acceptable allocation and GC behavior, even if mean is slightly worse.
- Reject candidates that win mean Results but show high allocations per operation or GC pause clustering under load.
- Do **not** compare GC metrics across languages to choose a format brand.

## Metrics

Primary signals for this page’s decision (see also [Metrics catalog](../../analysis/METRICS.md)):

| Metric / signal | Where | Role |
|-----------------|-------|------|
| **p99 / p999 latency** (serialize, deserialize, or end-to-end) | Load test or APM | **Primary**—tails are the service-level objective |
| `total_median_ns` / `ser_median_ns` / `deser_median_ns` | Suite analysis | Orientation within language; not sufficient alone |
| `total_mean_ns`, `avg_ops_per_sec` | Suite | Central tendency; easy to over-trust |
| `total_p95_ns` / `total_p99_ns` (if computed) | Suite or full metrics profile | Bridge from benchmark runner to tails when available |
| `total_std_ns` / CV / MAD | Suite | Dispersion hint; not production p99 |
| `mean_memory_peak_bytes` / `MemoryPeakBytes` | Suite (optional) | Allocation-pressure proxy when present |
| **Allocations per op / alloc rate** | Profiler | Explains GC pressure |
| **GC pause time / frequency** | Runtime metrics | Direct tail mechanism on managed runtimes |
| `median_size_bytes` | Suite | Separates “big payload” from “allocation-heavy codec” |
| `mean_fidelity` | Suite | Reject broken codecs before the performance debate |

**Conclusion style:** “Choose library L because p99 and allocation rate under load meet the service-level objective; mean Results only shortlisted L.”

**Not decision metrics here:** cross-language Results ranks; format brand alone.

## What this suite cannot tell you

- p99 under *your* framework and GC flags.
- Interaction with other allocators on the host.
- Whether pooling is safe in *your* concurrency model.

## Common mistakes

- Claiming “binary always means lower GC” without measuring.
- Comparing C# and Python pause behavior to choose a format brand.
- Shipping the fastest mean library that allocates unbounded on hostile input ([untrusted input](untrusted-input.md)).

## Key takeaways

- Tails track **allocations and shape**, not slogans.
- Means are necessary, not sufficient, for latency service-level objectives.
- Pick implementations with runtime behavior in mind.
- Confirm under load outside the benchmark runner.
