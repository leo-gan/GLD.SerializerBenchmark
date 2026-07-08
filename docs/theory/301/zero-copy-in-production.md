# Zero-copy in production

> After reading this page, one should be able to adopt FlatBuffers-class layouts only when ops, mutation, and verification costs fit the workload.

## Problem

Marketing claims “no deserialize” and microbenchmarks look excellent for large, mostly-read messages. Production then hits: missing verifiers, painful updates, language/tooling gaps, and debugging friction. The 201 mechanism is sound; the **operations** story decides whether zero-copy ships.

## Short answer

Use zero-copy layouts when messages are **large or partially read**, mostly **immutable** after build, and you will pay for **schema tooling + verification** on untrusted paths. Avoid them for tiny chatty RPCs, heavily mutated documents, or teams that require universal text debugging without investment. Always verify untrusted buffers. Measure with realistic access patterns—not only full materializing competitors on cold data.

Assumes 201 [zero-copy](../201/zero-copy.md).

## Constraints that matter

| Factor | Favors zero-copy | Argues against |
|--------|------------------|----------------|
| Message size / sparse reads | Large, partial field use | Tiny full reads |
| Mutation | Rare rebuilds | Frequent field edits |
| Languages | Strong codegen support | Missing or immature bindings |
| Trust | Verifier in path | “Skip verify for speed” |
| Debug | Invest in tools | Must `curl` everything as JSON |
| Team skill | Comfortable with offsets/builders | Only JSON experience |

## Decision frame

```text
  Mostly read-only large messages + polyglot codegen OK?
    yes → evaluate FlatBuffers/Cap’n Proto-class
    no  → classical schema-driven or JSON/schemaless binary
  Untrusted input? → verifier mandatory (non-negotiable)
```

## Failure modes

| Mistake | Outcome |
|---------|---------|
| Skip verifier | Memory safety / crash bugs |
| Hold views past buffer lifetime | Use-after-free / corruption |
| Benchmark without verification | Lied speed |
| Force zero-copy for CRUD APIs | Builder pain for no gain |
| Compare against unvalidated peers | Invalid ranking |

## Real-world sketch

A game state blob (100KB+) is read by many services for a few fields per request. FlatBuffers with verification cuts allocations vs full JSON trees. An admin API that mutates ten fields per call stays on Protobuf. Both coexist at different boundaries ([polyglot estates](polyglot-estates.md)).

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** | Whether FlatBuffers-class entries are registered |
| **Results** | Same-language compare; note validation settings if documented |
| [Using this suite](using-this-suite.md) | Fair paradigm-local reads |

Absence from a language harness means “not measured,” not “bad technology.”

## What this suite cannot tell you

- Builder ergonomics for *your* schema.  
- Cross-language binding maturity beyond registration.  
- Correct buffer ownership in *your* async runtime.

## Common mistakes

- Equating zero-copy with “no CPU.”  
- Using suite means without matching access pattern (full scan vs sparse).  
- Shipping without verifier because internal network.

## Key takeaways

- Zero-copy is a **layout + ops** choice, not a free lunch.  
- Verify untrusted data always.  
- Prefer it for large, immutable, sparse-read paths.  
- Mechanism lives in 201; production fit lives here.
