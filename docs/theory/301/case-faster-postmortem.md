# Case study: “we need it faster” postmortem

> Latency regressions trigger a codec swap. What should have been checked before the rewrite?

A **postmortem** is a structured review after an incident or failed change: what happened, what was wrong in the diagnosis, and what process change prevents a repeat. This case study teaches diagnostic discipline when someone says “we need it faster” and points at a benchmark chart.

---

## Context and goals

**Setting:** After a traffic ramp, p99 of a Go service climbs. A popular post claims “switch to X binary format for 10×.” An engineer opens suite Results, picks the top name on a mixed chart, and plans a week-long rewrite.

**Goals of this postmortem:** Separate **wrong benchmark**, **wrong paradigm**, and **wrong payload** so the next fix is targeted.

In other words, the first job is diagnosis. Format rewrites are expensive; they should follow evidence, not slogans.

---

## Non-goals and hard constraints

- This is not a greenfield architecture.
- Customer service-level objectives cannot be ignored while rewriting.

---

## Options on the table (retrospective)

| Hypothesis | Investigation |
|------------|---------------|
| **H1. Wrong library in the same family** | Compare JSON (or current-family) libraries only ([implementation variance](implementation-variance.md)) |
| **H2. Wrong paradigm for the hop** | Revisit public versus internal, trust, and evolution ([capstones](case-public-rest-api.md)) |
| **H3. Payload shape and allocations** | Profile; deep graphs versus dense structs ([latency tails](latency-tails-and-gc.md), 201 encode cost) |
| **H4. Not serialization** | Database, lock, downstream round-trip time, GC from other code |
| **H5. Compression and network** | Size versus round-trip time ([compression as system choice](compression-as-system-choice.md)) |

A **hypothesis** here is a testable explanation. You should falsify cheap hypotheses before expensive rewrites.

---

## Trade-off matrix (response cost)

| Action | Speed of learning | Risk |
|--------|-------------------|------|
| Profile plus a fair Results slice | Fast | Low |
| Swap library within the same family | Medium | Low to medium |
| Change the wire format | Slow | High (clients) |
| Rewrite business logic | Slow | High |

This matters because the order of investigation should match cost: learn fast and cheap first.

---

## Recommendation (under these constraints)

**Before any format rewrite:** (1) confirm serialization is on the critical path via profiling; (2) re-read Results with [using this suite](using-this-suite.md) discipline—same language, paradigm, fixture, mode, and metric; (3) try the best-in-family library and payload fixes; (4) only then consider a paradigm change with an explicit contract migration.

In the composite postmortem, the root cause was **unbounded JSON allocations on a deep graph** plus a **slow library**, not “JSON is impossible.” Switching libraries and flattening the data-transfer object restored the service-level objective without a cross-stack Protobuf migration.

A **data-transfer object (DTO)** is a structure used to carry data across a boundary. Flattening it means reducing nested graphs that allocate many temporary objects during decode.

---

## Experiments

**Question:** What actually caused the latency regression—wrong library, wrong paradigm, wrong payload or allocations, or something that is not serialization?

### Setup

1. Production profile or a reproduction under load.
2. Current codec family and library pin.
3. Fair suite access for same-language slices.

### Procedure

1. Profile: confirm serialize/deserialize is on the critical path (H4).
2. Fair Results within the **same family** (H1) ([using this suite](using-this-suite.md)).
3. Inspect payload shape and allocations (H3) ([latency tails](latency-tails-and-gc.md)).
4. Only if the family cannot meet the service-level objective, revisit paradigm (H2).
5. Check compression and network (H5) before rewrite.
6. Write the postmortem with evidence for the winning hypothesis.

### Decision rule

- Act on the first hypothesis that both explains p99 and is cheap to validate.
- Format rewrite is last, not first.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **p99 before and after** | **Primary** success |
| Profile percent time in serialize/deserialize | Attribution |
| Allocation rate and GC pauses | H3 evidence |
| Suite same-family deserialize median | H1 evidence |
| Size, round-trip time, and compress CPU | H5 evidence |
| Error rate during change | Safety |

**Conclusion style:** Root cause tagged H1–H5 with metrics; the fix matches the tag.

---

## What would change the answer

- Profiling shows more than 50% time in encode of a stable internal hop → a paradigm change may be justified (see [internal RPC](case-internal-rpc.md)).
- A public API with integrators cannot silently go binary ([public REST](case-public-rest-api.md)).

---

## Key takeaways

- “Need it faster” is a **diagnosis** problem first.
- A wrong chart produces a wrong rewrite.
- Prefer same-family library and shape fixes before multi-week format migrations.
- The suite is evidence only inside a disciplined question.
