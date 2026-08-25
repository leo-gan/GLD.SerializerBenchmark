# Implementation variance within a family

## Problem

Architecture discussions often stop at the format name. People say “we use JSON,” “we switched to binary,” or “we standardized on Protobuf.” On any language Dashboard slice, several serializers share a family label. They still differ sharply in encode time, decode time, size, allocation behavior, and fidelity notes.

**Implementation variance** means that two libraries which claim the same format can behave very differently. Teams that pick the brand without picking the **implementation** leave performance and reliability to accident. Or they copy a blog post’s library pin from another runtime.

---

## Short answer

After the **paradigm family** is fixed, choose a **concrete library** (and version) per language. See [categories](../../analysis/serialization_categories.md). Use same-fixture, same-mode Dashboard numbers. Read Overview caveats. Format brand sets interoperability *possibility*. Implementation sets cost and engineering quality on that runtime. Do not assume one language’s winning JSON library has a twin with identical behavior elsewhere. See [multi-language systems (polyglot estates)](polyglot-estates.md).

In other words: first choose the product job. That may be JSON versus schema-driven binary, and so on. Then choose the library. Do not reverse those steps.

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
  1. Fix boundary contract and family (other 301 policy articles)
  2. For each language on that boundary:
       open Overview → candidates in that family
       open Dashboard → same TestDataName and mode
       apply fidelity and stream caveats
       pick library and pin the version
  3. Add tests that check every language implements the same contract for shared fixtures
```

| Question | Wrong tool | Right tool |
|----------|------------|------------|
| JSON versus Protobuf for a public API? | Mixed Dashboard chart | Product constraints and paradigm families |
| Which JSON library in Python? | “JSON is slow” slogan | Python Dashboard, JSON-family rows |
| Is our Go JSON fast enough? | Rust Dashboard | Go Dashboard plus your reliability target |
| Why is size different within MessagePack? | Format myth | Key strategy, library options, fixture shape |

This matters because “we use JSON” is not an operations decision until you also name the library and version.

---

## Failure modes

| Mistake | Consequence |
|---------|-------------|
| **Brand-only architecture decision records** | Unpredictable 99th-percentile latency (*p99*) and surprising edge cases |
| **Copying pins across languages** | APIs diverge; bugs differ |
| **Ignoring fidelity notes** | The “winning” library does not round-trip your graph |
| **Chasing micro-wins weekly** | Churn without product gain |
| **One global ranking table** | Cross-paradigm and cross-language confusion |

---

## Real-world sketch

An architecture decision record says “use JSON for the public API.” Three services pick three Python JSON libraries from habit. Latency and Unicode edge cases differ. Only one path appears in continuous-integration benchmarks. Unifying on a single Overview-listed library helps. Pin it in lockfiles. Track it on the Python Dashboard for the public fixture. That reduces variance. A later move to schema-driven **internal** RPC is a separate family decision. It is not a reason to reopen the public JSON debate.

---

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** | Registered `SerializerName` values and categories |
| [Dashboard](../../dashboard/) | Within-language, within-fixture comparisons |
| [Categories](../../analysis/serialization_categories.md) | Family membership |
| [Metrics](../../analysis/METRICS.md) / [methodology](../../analysis/ANALYSIS_METHODOLOGY.md) | What means and confidence intervals mean |
| [Using this suite](using-this-suite.md) | Anti-leaderboard checklist |

When multiple JSON entries exist, **that spread is the lesson**. The same is true for multiple schema-driven entries. Implementation variance is first-class.

---

## Experiments

**Question:** Within a **fixed family** (for example JSON text or schema-driven Protobuf), which **library and version** should we pin on this language?

### Setup

1. Freeze the boundary contract and paradigm family. Use other 301 articles for that decision.
2. Choose one language, a production-like `TestDataName`, and the same string or stream mode.
3. Build a candidate list from Overview. Stay inside the same family only.

### Procedure

1. Run or read the Dashboard for all candidates on that slice.
2. Filter out `mean_fidelity` failures and Overview caveats. Include stream mode and unsupported fixtures.
3. Rank by the reliability-target metric. That is often deserialize or total median. Sometimes it is size.
4. Spot-check version pins and maintenance posture.
5. Optionally run a short load test if 99th-percentile latency (*p99*) matters. See [latency tails](latency-tails-and-gc.md).
6. Pin the winner in the lockfile or manifest.

### Decision rule

- The winner is the best reliability-target metric among **faithful** same-family candidates.
- Never pick by format name alone. Never import another language’s winning library name without re-running this experiment.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| `total_median_ns` / `deser_median_ns` / `ser_median_ns` | **Primary** speed comparison within the family |
| `avg_ops_per_sec` | Throughput-oriented display of the same idea |
| `median_size_bytes` | When density matters inside the family |
| `mean_fidelity` | **Hard filter** |
| `mean_memory_peak_bytes` | Tie-break when allocations matter |
| `serializer_version` | What you pin |
| Effect sizes versus fastest (Cliff’s δ, if multi-way) | “Is the gap real?” |
| Overview caveats and error CSV | Disqualify unsafe paths |

**Conclusion style:** “Pin `orjson@x` for the Python JSON **message** fixture in bytes mode—lowest deserialize median, fidelity 1.0.”

---

## What this suite cannot tell you

- Security audit status of a dependency.
- License or supply-chain policy.
- Behavior under **your** custom validators and middleware.
- Whether a 5% encode win matters against network round-trip time.

---

## Common mistakes

- Averaging ranks across families “for fairness.”
- Treating the fastest library as the default for **untrusted** input without reading safety docs.
- Upgrading major versions without re-checking Dashboard numbers and fidelity.

---

## Key takeaways

- A format family is not a single performance number.
- Pick **library and version** per language after the family is fixed.
- Suite Dashboard numbers exist to expose **implementation variance** honestly.
- Multi-language (polyglot) contracts share **format or IDL**. They do not necessarily share identical library behavior.
- Pin and re-measure. Brands do not ship bytes. Implementations do.
