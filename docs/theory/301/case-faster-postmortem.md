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



## Experiments

**Question:** What actually caused the latency regression—wrong library, wrong paradigm, wrong payload/allocs, or not serialization?

### Setup
1. Production profile or reproduction under load.  
2. Current codec family and library pin.  
3. Fair suite access for same-language slices.

### Procedure
1. Profile: confirm ser/deser on critical path (H4).  
2. Fair Results within **same family** (H1) ([using this suite](using-this-suite.md)).  
3. Inspect payload shape and allocs (H3) ([latency tails](latency-tails-and-gc.md)).  
4. Only if family cannot meet SLO, revisit paradigm (H2).  
5. Check compression/network (H5) before rewrite.  
6. Write postmortem with evidence for the winning hypothesis.

### Decision rule
- Act on the first hypothesis that both explains p99 and is cheap to validate.  
- Format rewrite last, not first.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **p99 before/after** | **Primary** success |
| Profile % time in ser/deser | Attribution |
| Alloc rate / GC pauses | H3 evidence |
| Suite same-family deser median | H1 evidence |
| Size / RTT / compress CPU | H5 evidence |
| Error rate during change | Safety |

**Conclusion style:** Root cause tagged H1–H5 with metrics; fix matched tag.

## What would change the answer

- Profiling shows >50% time in encode of a stable internal hop → paradigm change may be justified (see [internal RPC](case-internal-rpc.md)).  
- Public API with integrators → cannot silently go binary ([public REST](case-public-rest-api.md)).

## Key takeaways

- “Need it faster” is a **diagnosis** problem first.  
- Wrong chart → wrong rewrite.  
- Prefer same-family library and shape fixes before multi-week format migrations.  
- Suite is evidence only inside a disciplined question.
