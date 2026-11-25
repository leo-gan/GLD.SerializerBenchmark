# Case 6: "We Need It Faster" Postmortem

> **Design brief:** Following a traffic increase, a Go service's $p_{99}$ latency degrades. Citing an unfiltered benchmark chart, an engineer proposes a multi-week wire-format rewrite from JSON to a binary standard. What diagnostic sequence should precede any format change?

---

## Scenario and Hard Constraints

- **Incident:** Production $p_{99}$ latency breaches its SLO after traffic doubles on an existing Go service speaking JSON to multiple consumers.
- **Proposed intervention:** Replace JSON with the top-ranked binary format seen on an unfiltered Dashboard chart.
- **Hard constraints:**
  - This is a live multi-consumer production service, not a greenfield system; wire-format changes impose coordinated client migrations and dual-read windows.
  - Diagnostic effort must follow **cost of learning**—falsifying cheap, localized hypotheses before paying high migration risk.

---

## Competing Hypotheses and Diagnostic Order

| Hypothesis | Diagnostic Check | Relative Cost & Risk |
|---|---|---|
| **H4. Not serialization** | Production CPU/wall-time flame graph and trace spans (DB, locks, downstream RTT, unrelated GC) | Fastest, zero risk |
| **H1. Slow library within the same standard** | Controlled Go Dashboard slice on Standard `JSON` ([3.9 Implementation variance](using-this-suite.md#implementation-variance)) | Fast, low risk (drop-in swap) |
| **H3. Payload bloat & allocation pressure** | Allocation profiler (`pprof -alloc_objects`), GC pause metrics, DTO depth/size audit ([3.10 Latency tails](latency-tails-and-gc.md)) | Fast–medium, low–medium risk |
| **H5. Network / compression misplacement** | Wire size vs. RTT, `gzip`/`zstd` CPU share on small frames ([3.10 System compression](latency-tails-and-gc.md#compression-as-system-choice)) | Fast, low risk |
| **H2. Wrong wire standard for the hop** | Re-evaluate trust, client base, and evolution constraints only after H1/H3/H4/H5 are exhausted | Slowest, highest migration risk |

---

## Recommended Diagnostic Protocol

Execute checks strictly in ascending order of operational risk:

1. **Attribute latency via profiling (H4):** Confirm that serialization/deserialization actually consumes a material fraction of critical-path $p_{99}$ latency before touching any codec.
2. **Audit the benchmark claim (H1):** Re-open the [Dashboard](../../dashboard/index.html) using a single controlled cell `(Go, JSON, Suite, matching data type)` ([3.9 Fair benchmarking](using-this-suite.md)). Test whether swapping to a faster, spec-compliant Go JSON library resolves the bottleneck without breaking any client contract.
3. **Profile allocations and DTO shape (H3):** Inspect temporary object allocations per request and GC pause correlation. Flattening deeply nested DTOs, trimming unused fields ([3.7 RPC and messaging](rpc-and-messaging.md)), or reusing buffers frequently recovers $p_{99}$ without altering the wire standard.
4. **Audit compression placement (H5):** Confirm that blanket HTTP/RPC gzip on small frames is not saturating CPU.
5. **Migrate wire formats last (H2):** Only when profiling proves the *standard itself* cannot satisfy the SLO after library and shape fixes—and only on hops where clients can adopt the new contract—plan a versioned migration ([3.4 Versioning](public-api-contracts.md#versioning-strategies)).

In the composite incident behind this postmortem, profiling revealed **unbounded allocations decoding a deeply nested JSON DTO with a reflection-heavy parser** (H1 + H3). Flattening the DTO and pinning a faster Go JSON library restored $p_{99}$ compliance in two days, avoiding an unnecessary multi-service Protobuf migration.

---

## Verification Plan and Suite Limits

- **Within this suite:** Restrict lookups to the same-language, same-standard cell (`Go`, `JSON`, matching payload shape) to quantify realistic intra-standard library gains.
- **Outside this suite:** Capture before/after production CPU and allocation profiles, concurrent $p_{99}$ latency under load, GC pause time, and error rate across the rollout.
- **What would change the answer:** If profiling proves that >50% of critical-path CPU on a stable internal service-to-service hop remains inside optimal JSON parsing even after DTO trimming, migrating that internal hop to Protocol Buffers ([Case 2](case-internal-rpc.md)) becomes well-justified.

---

## Discussion Prompts

1. An engineer runs a single-threaded Go microbenchmark showing that Format X decodes $4\times$ faster than JSON on a 200-byte struct, and estimates service $p_{99}$ will drop by 75%. What flaw invalidates that estimate?

??? note "Guidance"
    Two flaws: (1) **Amdahl's law**—unless JSON decoding currently accounts for nearly 100% of request latency (ignoring DB queries, network RTT, TLS, and queueing), a $4\times$ codec speedup yields a much smaller end-to-end gain; (2) **microbenchmark averages omit concurrency tails**—if $p_{99}$ spikes are driven by unrelated heap allocations or lock contention, swapping the codec may barely move $p_{99}$.

2. Why is switching from Go `encoding/json` to a faster compliant Go JSON library categorically safer than migrating from JSON to MessagePack?

??? note "Guidance"
    A same-standard library swap keeps the wire format and external contract unchanged, so zero downstream clients require updates and rollback is a single-service deploy. Switching to MessagePack requires dual-format negotiation, client library upgrades across every consumer, new incident-debugging tools, and a coordinated deprecation schedule.
