# Implementation variance within a family

## Problem

Architecture discussions often stop at the format name: “we use JSON,” “we switched to binary,” “we standardized on Protobuf.” On any language **Results** page, several serializers share a family label and differ sharply in encode time, decode time, size, allocation behavior, and fidelity notes. Teams that pick the brand without picking the **implementation** leave performance and reliability to accident—or copy a blog post’s library pin from another runtime.

## Short answer

After the **paradigm family** is fixed ([categories](../../analysis/serialization_categories.md)), choose a **concrete library** (and version) per language using same-fixture, same-mode Results—and read Overview caveats. Format brand sets interoperability *possibility*; implementation sets cost and engineering quality on that runtime. Do not assume one language’s winning JSON library has a twin with identical behavior elsewhere ([polyglot estates](polyglot-estates.md)).

Assumes [using this suite](using-this-suite.md) and 201 [encode/decode cost](../201/encode-decode-cost.md).

## Constraints that matter

| Source of variance | Example effect |
|--------------------|----------------|
| **Parser strategy** | DOM-style tree vs streaming/SIMD-oriented JSON |
| **Codegen vs reflection** | Schema-driven stacks: generated structs vs runtime field discovery |
| **Allocations** | Zero-copy views vs new string per field |
| **Feature surface** | Full JSON numbers vs limited int ranges; schema subsets |
| **Safety defaults** | Strict vs loose duplicate keys; depth limits |
| **Maintenance** | Abandoned crate vs actively fuzzed library |
| **Version** | Major upgrades change both speed and edge-case behavior |

## Decision frame

```text
  1. Fix boundary contract + family (301 policy articles)
  2. For each language on that boundary:
       open Overview → candidates in that family
       open Results → same TestDataName + mode
       apply fidelity / stream caveats
       pick library + pin version
  3. Add conformance tests for shared fixtures across languages
```

| Question | Wrong tool | Right tool |
|----------|------------|------------|
| JSON vs Protobuf for public API? | Mixed Results chart | Product constraints + families |
| Which JSON lib in Python? | “JSON is slow” slogan | Python Results, JSON-family rows |
| Is our Go JSON fast enough? | Rust Results | Go Results + your SLO |
| Why is size different within MessagePack? | Format myth | Key strategy, lib options, fixture shape |

## Failure modes

| Mistake | Consequence |
|---------|-------------|
| **Brand-only ADRs** | Unpredictable p99 and surprising edge cases |
| **Copying pins across languages** | APIs diverge; bugs differ |
| **Ignoring fidelity notes** | “Winning” lib does not round-trip your graph |
| **Chasing micro-wins weekly** | Churn without product gain |
| **One global ranking table** | Cross-paradigm and cross-language confusion |

## Real-world sketch

An ADR says “use JSON for the public API.” Three services pick three Python JSON libraries from habit. Latency and Unicode edge cases differ; only one path appears in CI benchmarks. Unifying on a single Overview-listed library, pinned in lockfiles, and tracked on Python Results for the public fixture reduces variance. A later move to schema-driven **internal** RPC is a separate family decision—not a reason to renumber the public JSON debate.

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** | Registered `SerializerName` values and categories |
| Language **Results** | Within-language, within-fixture comparisons |
| [Categories](../../analysis/serialization_categories.md) | Family membership |
| [Metrics](../../analysis/METRICS.md) / [methodology](../../analysis/ANALYSIS_METHODOLOGY.md) | What means and CIs mean |
| [Using this suite](using-this-suite.md) | Anti-leaderboard checklist |

When multiple JSON (or multiple schema-driven) entries exist, **that spread is the lesson**: implementation variance is first-class.


## Experiments

**Question:** Within a **fixed family** (e.g. JSON text or schema-driven Protobuf), which **library + version** should we pin on this language?

### Setup
1. Freeze boundary contract and paradigm family (other 301 articles).  
2. One language, production-like `TestDataName`, same string/stream mode.  
3. Candidate list from Overview (same family only).

### Procedure
1. Run or read suite Results for all candidates on that slice.  
2. Filter `mean_fidelity` failures and Overview caveats (stream, unsupported fixtures).  
3. Rank by the SLO metric (often deser or total median; sometimes size).  
4. Spot-check version pins and maintenance posture.  
5. Optional: short load test if p99 matters ([latency tails](latency-tails-and-gc.md)).  
6. Pin winner in lockfile/manifest.

### Decision rule
- Winner = best SLO metric among **faithful** same-family candidates.  
- Never pick by format name alone; never import another language’s winning library name without re-running this experiment.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| `total_median_ns` / `deser_median_ns` / `ser_median_ns` | **Primary** speed compare within family |
| `avg_ops_per_sec` | Throughput-oriented display of the same idea |
| `median_size_bytes` | When density matters inside the family |
| `mean_fidelity` | **Hard filter** |
| `mean_memory_peak_bytes` | Tie-break when allocs matter |
| `serializer_version` | What you pin |
| Effect sizes vs fastest (Cliff’s δ, if multi-way) | “Is the gap real?” |
| Overview caveats / error CSV | Disqualify unsafe paths |

**Conclusion style:** “Pin `orjson@x` for Python JSON **message** fixture, bytes mode—lowest deser median, fidelity 1.0.”

## What this suite cannot tell you

- Security audit status of a dependency.  
- License or supply-chain policy.  
- Behavior under **your** custom validators and middleware.  
- Whether a 5% encode win matters against network RTT.

## Common mistakes

- Averaging ranks across families “for fairness.”  
- Treating the fastest lib as default for **untrusted** input without reading safety docs.  
- Upgrading major versions without re-checking Results and fidelity.

## Key takeaways

- Format family ≠ single performance number.  
- Pick **library + version** per language after family is fixed.  
- Suite Results exist to expose **implementation variance** honestly.  
- Polyglot contracts share **format/IDL**, not necessarily identical library behavior.  
- Pin and re-measure; brands do not ship bytes—implementations do.
