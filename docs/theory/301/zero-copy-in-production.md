# Zero-copy in production

## Problem

Marketing claims “no deserialize.” Microbenchmarks look excellent for large, mostly-read messages. **Zero-copy** is also called random-access layout. It means the reader can use fields by interpreting offsets inside a buffer. The reader does not build a full object tree first. Serialization 201 explains the mechanism. This page asks whether the **operations** story is strong enough to ship.

Production then hits real friction. Verifiers may be missing. Updates may be painful. Language and tooling may have gaps. Debugging may be hard. The 201 mechanism is sound. Operations decides whether zero-copy ships.

---

## Short answer

Use zero-copy layouts when messages are **large or partially read**. Prefer them when messages are mostly **immutable** after they are built. Prefer them when you are willing to pay for **schema tooling plus verification** on untrusted paths. Avoid them for tiny chatty RPCs. Avoid them for heavily mutated documents. Avoid them for teams that require universal text debugging without investment.

Always verify untrusted buffers. A **verifier** checks that offsets and sizes inside the buffer are safe. You must trust that check before you trust field access. Measure with realistic access patterns. Do not measure only competitors that build full language objects in memory on cold data.

This page assumes 201 [zero-copy](../201/zero-copy.md).

---

## Constraints that matter

| Factor | Favors zero-copy | Argues against |
|--------|------------------|----------------|
| Message size and sparse reads | Large messages with partial field use | Tiny messages that are fully read |
| Mutation | Rare rebuilds | Frequent field edits |
| Languages | Strong code-generation support | Missing or immature bindings |
| Trust | Verifier runs in the path | “Skip verify for speed” |
| Debug | Willingness to invest in tools | Must `curl` everything as JSON |
| Team skill | Comfortable with offsets and builders | Only JSON experience |

In other words, zero-copy is a layout plus a tooling commitment. It is not a free lunch that removes all CPU work.

---

## Decision frame

```text
  Mostly read-only large messages, and multi-language (polyglot) code generation is OK?
    yes → evaluate FlatBuffers/Cap’n Proto-class layouts
    no  → classical schema-driven or JSON/schemaless binary
  Untrusted input?
    → verifier is mandatory (non-negotiable)
```

This matters because skipping verification to “match the blog benchmark” is dangerous. It turns an untrusted buffer into a memory-safety risk.

---

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Skip the verifier | Memory-safety bugs and crashes |
| Hold views past buffer lifetime | Use-after-free and corruption |
| Benchmark without verification | Lied-about speed |
| Force zero-copy for CRUD APIs | Builder pain for no gain |
| Compare against unvalidated peers | Invalid ranking |

**CRUD** means create, read, update, delete. Those are typical business APIs that mutate fields often. Those paths often prefer ordinary schemas over offset builders.

---

## Real-world sketch

A game-state blob of 100KB or more is read by many services. Each request needs only a few fields. FlatBuffers with verification cuts allocations compared with full JSON trees. An admin API that mutates ten fields per call stays on Protobuf. Both coexist at different boundaries. See [multi-language systems (polyglot estates)](polyglot-estates.md).

---

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** | Whether FlatBuffers-class entries are registered |
| **Results** | Same-language comparison; note validation settings if documented |
| [Using this suite](using-this-suite.md) | Fair paradigm-local reads |

Absence from a language benchmark runner means “not measured.” It does not mean “bad technology.”

---

## Experiments

**Question:** Does a **zero-copy / random-access** layout pay off in *our* read path after verification cost? Can operations verify safely?

### Setup

1. Describe the workload. Mark building full language objects in memory versus field touches or memory-mapped reads.
2. List candidates. Include classic deserialize. Include FlatBuffers and Cap’n Proto-style layouts. See the language Overview.
3. Ensure you can run a verifier. Ensure you can fault-inject truncated or corrupt buffers.

### Procedure

1. Measure end-to-end time for the **actual access pattern**. Do not measure only full parse.
2. Include **verify** step cost on untrusted or untrusted-adjacent paths.
3. Compare relevant serializers in suite Results. Read caveats for fidelity and access patterns.
4. Chaos-test. Corrupt a buffer and ensure the verifier fails closed.
5. Decide whether to adopt zero-copy or stick with ordinary deserialize.

### Decision rule

- Adopt only if the access-pattern benchmark wins **including verification**. Operations must also be able to version the schema.
- Untrusted input without a verifier means do not adopt.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Time-to-first-field / access path latency** | **Primary** benefit metric |
| Full `deser_median_ns` (classic deserialize) | Baseline |
| Verify time and fail rate on corrupt input | Safety |
| `median_size_bytes` | Density tradeoff |
| Schema rollout complexity | Operations cost |
| Suite `mean_fidelity` | Correctness under the benchmark runner |
| Planned `time_access_ns` (if available) | Direct suite support when present |

**Conclusion style:** “The flat layout wins on field touches with verification OK; adopt it for the cache blob, not the public API.”

---

## What this suite cannot tell you

- Builder day-to-day ease of use for developers for *your* schema.
- Cross-language binding maturity beyond what is registered in the suite.
- Correct buffer ownership rules in *your* async runtime.

---

## Common mistakes

- Equating zero-copy with “no CPU work.”
- Using suite means without matching the access pattern. Full scan and sparse reads are different.
- Shipping without a verifier because the network is “internal.”

---

## Key takeaways

- Zero-copy is a **layout plus operations** choice. It is not a free lunch.
- Always verify untrusted data.
- Prefer zero-copy for large, immutable, sparse-read paths.
- The mechanism lives in Serialization 201. Production fit lives here.
