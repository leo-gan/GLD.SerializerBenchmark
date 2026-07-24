# Zero-copy in production

## Problem

Marketing claims “no deserialize,” and microbenchmarks look excellent for large, mostly-read messages. Production then hits missing verifiers, painful updates, language and tooling gaps, and debugging friction. The 201 mechanism is sound; the **operations** story decides whether zero-copy ships.

## Short answer

Use zero-copy layouts when messages are **large or partially read**, mostly **immutable** after they are built, and you are willing to pay for **schema tooling plus verification** on untrusted paths. Avoid them for tiny chatty RPCs, heavily mutated documents, or teams that require universal text debugging without investment.

Always verify untrusted buffers. Measure with realistic access patterns—not only full materializing competitors on cold data.

This page assumes 201 [zero-copy](../201/zero-copy.md).

## Constraints that matter

| Factor | Favors zero-copy | Argues against |
|--------|------------------|----------------|
| Message size and sparse reads | Large messages with partial field use | Tiny messages that are fully read |
| Mutation | Rare rebuilds | Frequent field edits |
| Languages | Strong code-generation support | Missing or immature bindings |
| Trust | Verifier runs in the path | “Skip verify for speed” |
| Debug | Willingness to invest in tools | Must `curl` everything as JSON |
| Team skill | Comfortable with offsets and builders | Only JSON experience |

## Decision frame

```text
  Mostly read-only large messages, and polyglot codegen is OK?
    yes → evaluate FlatBuffers/Cap’n Proto-class layouts
    no  → classical schema-driven or JSON/schemaless binary
  Untrusted input?
    → verifier is mandatory (non-negotiable)
```

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Skip the verifier | Memory-safety bugs and crashes |
| Hold views past buffer lifetime | Use-after-free and corruption |
| Benchmark without verification | Lied-about speed |
| Force zero-copy for CRUD APIs | Builder pain for no gain |
| Compare against unvalidated peers | Invalid ranking |

## Real-world sketch

A game-state blob of 100KB or more is read by many services for a few fields per request. FlatBuffers with verification cuts allocations compared with full JSON trees. An admin API that mutates ten fields per call stays on Protobuf. Both coexist at different boundaries ([polyglot estates](polyglot-estates.md)).

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** | Whether FlatBuffers-class entries are registered |
| **Results** | Same-language comparison; note validation settings if documented |
| [Using this suite](using-this-suite.md) | Fair paradigm-local reads |

Absence from a language benchmark runner means “not measured,” not “bad technology.”

## Experiments

**Question:** Does a **zero-copy / random-access** layout pay off in *our* read path after verification cost—and can operations verify safely?

### Setup

1. Describe the workload: full materialization versus field touches or memory-mapped reads.
2. List candidates: classic deserialize versus FlatBuffers/Cap’n Proto-style layouts (see the language Overview).
3. Ensure you can run a verifier and fault-inject truncated or corrupt buffers.

### Procedure

1. Measure end-to-end time for the **actual access pattern**, not only full parse.
2. Include **verify** step cost on untrusted or untrusted-adjacent paths.
3. Compare relevant serializers in suite Results; read caveats for fidelity and access patterns.
4. Chaos-test: corrupt a buffer and ensure the verifier fails closed.
5. Decide whether to adopt zero-copy or stick with ordinary deserialize.

### Decision rule

- Adopt only if the access-pattern benchmark wins **including verification** and operations can version the schema.
- Untrusted input without a verifier means do not adopt.

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

## What this suite cannot tell you

- Builder ergonomics for *your* schema.
- Cross-language binding maturity beyond what is registered in the suite.
- Correct buffer ownership rules in *your* async runtime.

## Common mistakes

- Equating zero-copy with “no CPU work.”
- Using suite means without matching the access pattern (full scan versus sparse reads).
- Shipping without a verifier because the network is “internal.”

## Key takeaways

- Zero-copy is a **layout plus operations** choice, not a free lunch.
- Always verify untrusted data.
- Prefer zero-copy for large, immutable, sparse-read paths.
- The mechanism lives in Serialization 201; production fit lives here.
