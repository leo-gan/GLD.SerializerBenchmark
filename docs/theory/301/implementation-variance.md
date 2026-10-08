# Implementation variance within a standard

## Problem

Architecture discussions often stop at the format name. People say “we use JSON,” “we switched to binary,” or “we standardized on Protobuf.” On any language Dashboard slice, several serializers share one standard. They still differ sharply in encode time, decode time, size, allocation behavior, and fidelity notes.

**Implementation variance** means that two libraries which claim the same format can behave very differently. Teams that pick the brand without picking the **implementation** leave performance and reliability to accident. Or they copy a blog post’s library pin from another runtime.

---

## Short answer

After the **standard** is fixed, choose a **concrete library** (and version) per language. See [categories](../../analysis/serialization_categories.md). Use Dashboard numbers for the same data set and the same data type. Read Overview caveats. The standard sets interoperability *possibility*. The implementation sets cost and engineering quality on that runtime. One language’s winning JSON library can behave differently from another language’s JSON library. See [multi-language systems (polyglot estates)](polyglot-estates.md).

In other words: first choose the product job. A family is a teaching cut that helps you reach a standard such as JSON or Protocol Buffers. Then choose the library, which is one implementation of that standard. Keep that order.

This page assumes [using this suite](using-this-suite.md) and 201 [encode/decode cost](../201/encode-decode-cost.md).

---

## Constraints that matter

| Source of variance | Example effect |
|--------------------|----------------|
| **Parser strategy** | DOM-style tree versus streaming or SIMD-oriented JSON |
| **Code generation versus reflection** | Schema-driven stacks: generated structs versus runtime field discovery |
| **Allocations** | Zero-copy views versus a new string per field |
| **Feature surface** | Full JSON numbers versus limited integer ranges; schema subsets |
| **Safety defaults** | Strict versus loose handling of duplicate keys; depth limits |
| **Maintenance** | Abandoned crate versus an actively fuzzed library |
| **Version** | Major upgrades change both speed and edge-case behavior |

A **DOM-style** parser builds a full in-memory tree of the document. A **streaming** parser processes tokens as they arrive. **Reflection** discovers fields at runtime. **Code generation** produces typed code from a schema ahead of time. Each strategy has different costs.

---

## Decision frame

```text
  1. Fix the boundary contract and the standard
       (other 301 policy articles; a family is a teaching cut, not a filter)
  2. For each language on that boundary:
       open the Dashboard on that language and standard
       same data set and data type
       apply fidelity caveats, and any stream-row note on the Overview
       pick the library and pin the version
  3. Add tests that check every language implements the same contract for shared fixtures
```

| Question | Where the answer is |
|----------|---------------------|
| JSON versus Protocol Buffers for a public API? | Product constraints, then the categories sketch. A mixed chart comes after the contract is chosen. |
| Which JSON library in Python? | Python Dashboard, Standard set to JSON |
| Is our Go JSON fast enough? | Go Dashboard, Standard JSON, plus your reliability target |
| Why is size different within MessagePack? | Key strategy, library options, fixture shape, on the MessagePack standard |

This matters because “we use JSON” is not an operations decision until you also name the library and version.

---

## Failure modes

| Mistake | Consequence |
|---------|-------------|
| **Brand-only architecture decision records** | Unpredictable 99th-percentile latency (*p99*) and surprising edge cases |
| **Copying pins across languages** | APIs diverge; bugs differ |
| **Ignoring fidelity notes** | The “winning” library does not round-trip your graph |
| **Chasing micro-wins weekly** | Churn without product gain |
| **One global ranking table** | Standards and languages mixed into one champion |

---

## Real-world sketch

An architecture decision record says “use JSON for the public API.” Three services pick three Python JSON libraries from habit. Latency and Unicode edge cases differ. Only one path appears in continuous-integration benchmarks. Unifying on a single Overview-listed library helps. Pin it in lockfiles. Track it on the Python Dashboard with Standard set to JSON. That reduces variance. A later move to an internal Protocol Buffers hop is a different standard. The public JSON choice stays as it is.

---

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** | Registered `SerializerName` values and categories |
| [Dashboard](../../dashboard/) | Within-language, within-fixture comparisons |
| [Categories](../../analysis/serialization_categories.md) | Family, then the standard inside that family |
| [Metrics](../../analysis/METRICS.md) / [methodology](../../analysis/ANALYSIS_METHODOLOGY.md) | What means and confidence intervals mean |
| [Using this suite](using-this-suite.md) | Anti-leaderboard checklist |

When several JSON libraries exist, **that spread is the lesson**. The same is true for several Protocol Buffers libraries. Implementation variance is first-class. The chart stays on one standard.

---

## Experiments

**Question:** Within a **fixed standard** (for example JSON, or Protocol Buffers), which **library and version** should we pin on this language?

### Setup

1. Freeze the boundary contract and the standard. Use other 301 articles for that decision. A family is only how you arrived there.
2. Choose one language, one data set, and one data type close to production.
3. Build a candidate list on the Dashboard with that standard selected.

### Procedure

1. Run or read the Dashboard for all candidates on that slice.
2. Filter out `mean_fidelity` failures and Overview caveats. Include stream mode and unsupported fixtures.
3. Rank by the reliability-target metric. That is often deserialize or total median. Sometimes it is size.
4. Spot-check version pins and maintenance posture.
5. Optionally run a short load test if 99th-percentile latency (*p99*) matters. See [latency tails](latency-tails-and-gc.md).
6. Pin the winner in the lockfile or manifest.

### Decision rule

- The winner is the best reliability-target metric among **faithful** candidates on that standard.
- Pick a library and a version. Re-run this experiment before you reuse another language’s winning library name.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| `total_median_ns` / `deser_median_ns` / `ser_median_ns` | **Primary** speed comparison within the standard |
| `avg_ops_per_sec` | Throughput-oriented display of the same idea |
| `median_size_bytes` | When density matters inside the standard |
| `mean_fidelity` | **Hard filter.** Fixture round trip, not specification compliance. |
| `mean_memory_peak_bytes` | Tie-break when allocations matter |
| `serializer_version` | What you pin |
| Effect sizes versus fastest (Cliff’s δ, if multi-way) | “Is the gap real?” |
| Overview caveats and error CSV | Disqualify unsafe paths |

**Conclusion style:** “Pin `orjson@x` for Python, standard JSON, Suite, `message` at n=1 — lowest deserialize median, fidelity 1.0.”

---

## What this suite cannot tell you

- Security audit status of a dependency.
- License or supply-chain policy.
- Behavior under **your** custom validators and middleware.
- Whether a 5% encode win matters against network round-trip time.

---

## Common mistakes

- Averaging ranks across standards “for fairness.”
- Treating the fastest library as the default for **untrusted** input without reading safety docs.
- Upgrading major versions without re-checking Dashboard numbers and fidelity.

---

## Key takeaways

- A standard is a contract. It is also a set of libraries with different costs.
- Pick **library and version** per language after the standard is fixed.
- Suite Dashboard numbers exist to expose **implementation variance** honestly.
- Multi-language (polyglot) contracts share **format or IDL**. They do not necessarily share identical library behavior.
- Pin and re-measure. Brands do not ship bytes. Implementations do.
