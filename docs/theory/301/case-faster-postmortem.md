# Case study: “we need it faster” postmortem

> Latency regressions trigger a codec swap—what should have been checked before the rewrite?

## Context & goals

**Setting:** After a traffic ramp, p99 of a Go service climbs. A popular post claims “switch to X binary format for 10×.” An engineer opens suite Results, picks the top name on a mixed chart, and plans a week-long rewrite.

**Goals of this postmortem:** Separate **wrong benchmark**, **wrong paradigm**, and **wrong payload** so the next fix is targeted.

## Non-goals / hard constraints

- Not a greenfield architecture.  
- Cannot ignore customer SLOs while rewriting.

## Options on the table (retrospective)

| Hypothesis | Investigation |
|------------|---------------|
| **H1. Wrong library in same family** | Compare JSON (or current family) libs only ([implementation variance](implementation-variance.md)) |
| **H2. Wrong paradigm for the hop** | Revisit public vs internal, trust, evolution ([capstones](case-public-rest-api.md)) |
| **H3. Payload shape / allocs** | Profile; deep graphs vs dense structs ([latency tails](latency-tails-and-gc.md), 201 encode cost) |
| **H4. Not serialization** | DB, lock, downstream RTT, GC from other code |
| **H5. Compression / network** | Size vs RTT ([compression as system choice](compression-as-system-choice.md)) |

## Trade-off matrix (response cost)

| Action | Speed of learning | Risk |
|--------|-------------------|------|
| Profile + fair Results slice | Fast | Low |
| Swap library same family | Medium | Low–medium |
| Change wire format | Slow | High (clients) |
| Rewrite business logic | Slow | High |

## Recommendation (under these constraints)

**Before any format rewrite:** (1) confirm serialization is on the critical path via profiling; (2) re-read Results with [using this suite](using-this-suite.md) discipline—same language, paradigm, fixture, mode, metric; (3) try best-in-family library and payload fixes; (4) only then consider paradigm change with an explicit contract migration.

In the composite postmortem, the root cause was **unbounded JSON allocations on a deep graph** plus a **slow library**, not “JSON is impossible.” Switching libraries and flattening the DTO restored SLO without a cross-stack Protobuf migration.

## How to validate

| Step | Where |
|------|--------|
| Profiler / tracing | Production or load test |
| Fair codec compare | Language **Results** |
| Load test after change | e2e |
| Contract impact | Client matrix if format changes |

## What would change the answer

- Profiling shows >50% time in encode of a stable internal hop → paradigm change may be justified (see [internal RPC](case-internal-rpc.md)).  
- Public API with integrators → cannot silently go binary ([public REST](case-public-rest-api.md)).

## Key takeaways

- “Need it faster” is a **diagnosis** problem first.  
- Wrong chart → wrong rewrite.  
- Prefer same-family library and shape fixes before multi-week format migrations.  
- Suite is evidence only inside a disciplined question.
