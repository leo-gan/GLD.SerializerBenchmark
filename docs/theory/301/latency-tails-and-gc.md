# Latency tails, allocations, and GC

## Problem

Mean serialize time looks fine while **p99** collapses under load. **p99** is the 99th-percentile latency. It is the time below which 99% of requests finish. Managed runtimes pay for **allocation rate** with **garbage-collection (GC)** pauses. Native heaps pay with allocator contention and cache misses.

**Garbage collection** is automatic reclaiming of memory that a program no longer uses. When the collector runs, application threads may pause. That shows up as rare but large latency spikes. Those spikes are the **tail** of the distribution.

Codecs that “win” microbenchmarks by allocating per field can lose the reliability target (*service-level objective*; for example, 99% of requests finish within 200 ms). Charts that show only means hide the failure mode. This page teaches you to treat tails and allocations as first-class evidence.

---

## Short answer

Treat **allocation and copy behavior** as first-class when choosing among implementations in a family. See [implementation variance](implementation-variance.md). Prefer APIs that reuse buffers, stream, or reduce temporary strings when p99 matters. Interpret suite **means** as a starting point. Validate under concurrency with **your** runtime GC settings and payload shape. See 201 [encode/decode cost](../201/encode-decode-cost.md). Format brand does not determine GC pressure. Implementation and shape do.

In other words: a library that is slightly slower on the mean but allocates far less can win the production latency budget.

---

## Constraints that matter

| Factor | Effect on tails |
|--------|-----------------|
| Allocations per message | GC work or allocator work |
| Payload shape | Deep graphs create many objects |
| Concurrency | Parallel allocate can cluster pauses |
| Buffer reuse | Lowers steady-state pressure |
| Native versus managed | Different pause mechanics, same lesson: do not thrash the allocator |

This matters because two JSON libraries can look similar on mean decode. They can diverge sharply on p99 once worker threads allocate in parallel.

---

## Decision frame

```text
  Is the reliability target (SLO) p99 or p999 under load?
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

A **profiler** is a tool that shows where a program spends time and memory. Use one before you rewrite a format.

---

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Optimizing mean only | p99 pages at peak traffic |
| Ignoring payload shape | Microbenchmarks on tiny structs mislead |
| Cross-language GC comparison | Invalid basis for format choice |
| Disabling GC in the bench | Fantasy numbers |
| Pooling without clear ownership | Use-after-free and data races |

For example, turning GC off in a microbenchmark can make a library look impossibly fast. It teaches nothing about production.

---

## Real-world sketch

Two JSON libraries show similar mean decode on Python Results. Production p99 diverges. One builds full `dict` trees. Another binds into typed objects with fewer temporary strings. A load test with production-shaped payloads and workers decides the pin. The mean column alone does not.

---

## In this suite

| Resource | Role |
|----------|------|
| **Results** means and ops | Orientation within one language |
| Methodology | Warmup and outliers—read before quoting |
| Optional memory metrics | If present for a language, use them cautiously |
| [Using this suite](using-this-suite.md) | Fair slice checklist |

Many published tables emphasize central tendency. **You** still owe a concurrent validation.

---

## Experiments

**Question:** Under production-shaped load, is encode/decode **allocation pressure** (not mean time alone) driving p99 risk for candidate libraries in the same family?

### Setup

1. Fix **one language**, **one paradigm family**, and **one fixture** close to production shape. One example is a deep graph versus dense `Telemetry`. See [using this suite](using-this-suite.md).
2. Shortlist two or three implementations from language **Results**. Stay in the same family. Note versions.
3. Confirm the benchmark runner reports useful signals. Or attach wall times yourself. Optionally attach `MemoryPeakBytes` or tracemalloc (Python). Also attach a **process profiler** for allocation rate and GC pauses outside pure means.
4. Configure a load path that reuses your service concurrency model. Include workers and pool sizes. Do not rely only on single-threaded suite loops.

### Procedure

1. Run the suite slice for candidates. Record mean and median serialize, deserialize, and total time. Record size and fidelity.
2. If available, record `mean_memory_peak_bytes` or peak allocation columns.
3. Load-test or profile each candidate on the same fixture at target concurrency. Capture **p99/p999** latency and GC and allocation stats from the runtime.
4. Optionally disable “fantasy” modes only as a diagnostic. One example is GC off. Do not use that as the decision number.
5. Apply the decision rule below. Pin library and version.

### Decision rule

- Prefer the candidate that meets the **p99 reliability target** with acceptable allocation and GC behavior. That holds even if mean is slightly worse.
- Reject candidates that win mean Results but show high allocations per operation. Also reject GC pause clustering under load.
- Do **not** compare GC metrics across languages to choose a format brand.

---

## Metrics

Primary signals for this page’s decision. See also [Metrics catalog](../../analysis/METRICS.md):

| Metric / signal | Where | Role |
|-----------------|-------|------|
| **p99 / p999 latency** (serialize, deserialize, or end-to-end) | Load test or APM | **Primary.** Tails are the reliability target. |
| `total_median_ns` / `ser_median_ns` / `deser_median_ns` | Suite analysis | Orientation within language; not sufficient alone |
| `total_mean_ns`, `avg_ops_per_sec` | Suite | Central tendency; easy to over-trust |
| `total_p95_ns` / `total_p99_ns` (if computed) | Suite or full metrics profile | Bridge from benchmark runner to tails when available |
| `total_std_ns` / CV / MAD | Suite | Dispersion hint; not production p99 |
| `mean_memory_peak_bytes` / `MemoryPeakBytes` | Suite (optional) | Allocation-pressure proxy when present |
| **Allocations per op / alloc rate** | Profiler | Explains GC pressure |
| **GC pause time / frequency** | Runtime metrics | Direct tail mechanism on managed runtimes |
| `median_size_bytes` | Suite | Separates “big payload” from “allocation-heavy codec” |
| `mean_fidelity` | Suite | Reject broken codecs before the performance debate |

**Conclusion style:** “Choose library L because p99 and allocation rate under load meet the reliability target; mean Results only shortlisted L.”

**Not decision metrics here:** cross-language Results ranks; format brand alone.

---

## What this suite cannot tell you

- p99 under *your* framework and GC flags.
- Interaction with other allocators on the host.
- Whether pooling is safe in *your* concurrency model.

---

## Common mistakes

- Claiming “binary always means lower GC” without measuring.
- Comparing C# and Python pause behavior to choose a format brand.
- Shipping the fastest mean library that allocates unbounded on hostile input. See [untrusted input](untrusted-input.md).

---

## Key takeaways

- Tails track **allocations and shape**. They do not track slogans.
- Means are necessary for latency reliability targets. They are not sufficient.
- Pick implementations with runtime behavior in mind.
- Confirm under load outside the benchmark runner.
