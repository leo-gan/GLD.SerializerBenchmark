# Using this suite without fooling yourself

## Problem

Benchmark tables are easy to misuse. A single chart—“library A is 3× faster than library B”—often becomes a policy decision without asking whether A and B implement the **same job**, on the **same payload shape**, in the **same language**, under the **same timing rules**. Organizations then switch codecs, observe little improvement, and conclude that “benchmarks lie,” when the real issue was **misaligned comparison**.

This multi-language suite is built to support **fair, local** comparisons. It is not built to crown a global winner across paradigms or languages.

## Short answer

Treat every published number as the answer to a **narrow question**: for a given **language**, **fixture** (`TestDataName`), and **string versus stream mode**, how do registered serializers compare on encode time, decode time, size, and related metrics **after** the analysis pipeline’s warmup and optional outlier rules?

Prefer comparisons **within one paradigm family** (JSON text, schemaless binary, schema-driven, language-native). Do not promote cross-language or cross-paradigm “champions” into architecture policy without re-stating the workload. When the decision is about trust, evolution, or multi-hop design, suite timings are **inputs**, not the whole argument—see the rest of Serialization 301.

## Constraints that matter

| Constraint | Why it breaks naive rankings |
|------------|------------------------------|
| **Language and runtime** | Different virtual machines, garbage collectors, and standard libraries; “Protobuf in Python” is not “Protobuf in C.” |
| **Paradigm family** | JSON and schema-driven binary solve different product problems; speed alone is not interchangeability. |
| **Payload shape** | Dense structs versus deep graphs change cost centers (see [Encode/decode cost](../201/encode-decode-cost.md)). |
| **Implementation** | Several libraries can share a format label and differ by an order of magnitude. |
| **What is timed** | Harness paths measure serialize and deserialize of prepared fixtures—not network round-trip time, disk I/O, or your production validation layer. |
| **Analysis policy** | Warmup exclusion and outlier filters change means; raw CSV is not the published table unless you re-run analysis with the same config. |

## Decision frame

Use this checklist **before** quoting a Result:

1. **Same language?** If no, stop. Use the numbers only as rough orientation, not as a pick.
2. **Same paradigm?** Prefer [Serialization categories](../../analysis/serialization_categories.md) families. Cross family only when the product decision is “which family,” and then treat speed as one axis among many.
3. **Same fixture?** `message` versus `telemetry` (and other type identifiers) are different jobs.
4. **Same mode?** String versus stream (and any stream-mode caveats on the language Overview) must match.
5. **Which metric?** Mean encode, mean decode, size, operations per second, or tails—pick the one your service-level objective cares about, and do not swap them mid-argument.
6. **Still missing?** Compression on the wire, authentication, schema registry behavior, multi-hop fan-out—these sit outside the core tables unless you design a separate experiment.

```text
  Question: “Is X better than Y for us?”
        │
        ▼
  Fix language + paradigm + fixture + mode + metric
        │
        ▼
  Read Results or the dashboard for that slice only
        │
        ▼
  Re-check product constraints (trust, evolution, operations)
        │
        ▼
  Decide — or design a measurement this suite cannot do
```

## Failure modes

| Mistake | What goes wrong |
|---------|-----------------|
| **Global leaderboard thinking** | Picking the top row of a mixed chart as “the company format.” |
| **Cross-language crowning** | Mandating a library because it looked fast in another runtime. |
| **Format brand equals one speed** | “We moved to binary” without naming the implementation. |
| **Ignoring warmup and cold path** | Production cold starts differ from steady-state tables (analysis drops `RepetitionIndex == 0` by default). |
| **Confusing size with latency** | The smallest payload on a local network may not win p99 if CPU or allocations dominate. |
| **Treating fidelity notes as optional** | Some codecs are registered with documented shape limits; Overview caveats bound the claim. |
| **Policy from means only** | Garbage-collection pauses and tail latency may not appear as a single mean encode time. |

## Real-world sketch

A team sees that a schema-driven library is fastest on **Rust** Results for a dense fixture and mandates it for a **public multi-language HTTP API**. Clients are browser and mobile; operators need human-readable debug logs; the public contract is already JSON.

The suite result answered “fastest schema path in Rust for this fixture,” not “best public API contract.” A better use of the suite is to compare **JSON implementations within each language** that must speak the public contract, and to measure schema-driven codecs only on internal hops that already accept an IDL.

## In this suite

| Resource | Use it for |
|----------|------------|
| [Serialization categories](../../analysis/serialization_categories.md) | Paradigm families and the within-paradigm rule |
| Language **Overview** | Registered names, categories, fidelity caveats (inventory source of truth) |
| Language **Results** | Published timings and sizes for that language |
| [Analysis methodology](../../analysis/ANALYSIS_METHODOLOGY.md) | Warmup, outliers, grouping keys, units |
| [Metrics catalog](../../analysis/METRICS.md) | What each field means |
| [Test Data](../../analysis/test_data_configuration.md) | Fixture meanings and size knobs |
| [Benchmark architecture](../../analysis/architecture.md) | What the harness times |
| Dashboard (Benchmarks navigation) | Interactive slices of the same analysis story |

**Grouping key for fair peers (conceptually):**  
`(Language, paradigm, TestDataName, StringOrStream)` — then compare `SerializerName` rows inside that cell.

**Illustrative only:** prose in theory pages must not invent winners. When you need a number, open **Results** for the language you will actually run.

## Experiments

**Question:** Am I about to quote a **fair** suite comparison for a real decision—or a misaligned chart?

### Setup

1. Write the decision question in one sentence (for example “Which JSON library in Python for message-shaped RPC?”).
2. Open [categories](../../analysis/serialization_categories.md) and the language **Results** / Overview for the runtime you will ship.
3. Note analysis configuration (warmup, outlier policy) from [methodology](../../analysis/ANALYSIS_METHODOLOGY.md) if you will re-derive tables.

### Procedure

1. Apply the checklist in **Decision frame** (language, then paradigm, then fixture, then mode, then metric).
2. Pull only the matching rows from Results or the dashboard; discard cross-family and cross-language ranks for the policy claim.
3. Record which metric column you will use (encode versus decode versus size versus operations per second).
4. List product constraints the suite does **not** measure (trust, registry, network RTT).
5. Either decide from that slice or design an out-of-suite experiment for the missing constraints.

### Decision rule

- If any checklist box fails, **do not** use the number as architecture policy.
- If the slice is fair but the product question is not about performance, treat suite data as **supporting**, not decisive.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Comparison validity** (same language, paradigm, fixture, mode) | **Primary gate**—binary pass/fail before any number |
| Chosen SLO metric (for example decode median or size) | The one number allowed in the argument |
| `total_median_ns` / `ser_median_ns` / `deser_median_ns` | Default speed ranks on Results |
| `median_size_bytes` | Density and bandwidth axis |
| `mean_fidelity` | Eligibility filter: non-faithful rows are out |
| `serializer_version` | Reproducibility of the claim |
| `runs`, warmup, outliers removed | Trust in the statistic |
| Dashboard or CSV **filter state** | Document what you hid |

**Conclusion style:** “Under Python, JSON family, message fixture, and bytes mode, A beats B on deserialize median; size is similar; fidelity is 1.0.”

**Not decision metrics:** mixed-paradigm leaderboards; cross-language “champions.”

## What this suite cannot tell you

- End-to-end **service** latency (queueing, network, TLS, framework overhead).
- **Correctness of your schema evolution policy** under rolling deploys (see 201 [schema evolution](../201/schema-evolution.md) and later 301 contract articles).
- **Security** of deserializing untrusted bytes (native formats, hostile inputs).
- Whether **gzip or zstd** on the wire wins for your message size mix (compression is orthogonal; see 201 [compression vs format](../201/compression-is-not-a-format.md)).
- Cross-language byte identity for every registered pair (harnesses are per-language unless you design a fidelity experiment).
- Business constraints: compliance, team skill, vendor lock-in, existing public contracts.

## Common mistakes

- Screenshotting one latency distribution into an architecture decision record without stating language, fixture, and paradigm.
- Averaging ranks across languages “to be fair.”
- Changing fixture generation parameters and comparing to old published snapshots without regenerating both sides.
- Using language-native serializers’ speed as an argument for **network** interchange.

## Key takeaways

- Suite numbers answer **narrow, local** questions—not “what format should the industry use.”
- Fix **language, paradigm, fixture, mode, and metric** before comparing serializers.
- Implementation quality and payload shape often dominate format brand.
- Analysis policies (warmup, outliers) are part of the claim—know them.
- Use Results as evidence inside a larger 301 decision about trust, contracts, and workload.
- Explicitly list what you still must measure outside this harness.
