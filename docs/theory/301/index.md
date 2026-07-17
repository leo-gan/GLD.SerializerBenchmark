# Serialization 301: Production Data Serialization

> Production serialization—trust, contracts, workloads, and honest measurement—for people who already know how formats work.

## Who this is for

Experienced students and developers who must **ship a choice** under conflicting constraints (trust, evolution, multi-language estates, performance claims). This is the **core** advanced course after [Serialization 201](../201/index.md).

If you need to **implement** a codec (wire encoding, runtime paths, a subset lab), that is [Serialization 401](../401/index.md) (implementer elective)—not this course.

## Prerequisites

| Type | Requirement |
|------|-------------|
| **Hard** | [Serialization 101](../101/index.md) — trade-off axes and at least one lens |
| **Hard** | [Serialization 201](../201/index.md) — especially schema identity, evolution, dynamic vs IDL, encode cost, zero-copy, compression vs format *(or equivalent experience)* |

This course does **not** re-teach 201 mechanisms. Open the 201 article when you need a model; return here for multi-constraint judgment.

## Learning outcomes

By the end of this course you should be able to:

1. **Analyze** trust boundaries and state when portable vs language-native formats are acceptable.
2. **Distinguish** operational schema cultures (e.g. Avro-style resolution vs Protobuf field-number discipline) without re-deriving wire rules.
3. **Evaluate** workload fit (row vs columnar at system scale; polyglot contracts; RPC vs messaging shape).
4. **Critique** benchmark claims using this suite’s paradigm-and-language rules.
5. **Recommend** a family or approach under stated constraints and **justify** it with categories and **Results**.
6. **Identify** what this harness cannot answer.

## How this course fits the program

| Course | Role |
|--------|------|
| [101](../101/index.md) | Foundations — what serialization is; axes and lenses |
| [201](../201/index.md) | Mechanisms — how formats work |
| **301 (this course)** | Production judgment — what to ship under constraints |
| [401](../401/index.md) | Implementer elective — wire + language paths + lab |

Default path: **101 → 201 → 301**. Suite lab: [Benchmarks](../../analysis/index.md) and language **Results**.

## Suggested paths

**Services track:** [trust boundaries](trust-boundaries.md) → [untrusted input](untrusted-input.md) → [using this suite](using-this-suite.md) → [two schema cultures](two-schema-cultures.md) / [public API contracts](public-api-contracts.md) → [rpc and messaging](rpc-and-messaging.md) → [implementation variance](implementation-variance.md) → cases [public REST](case-public-rest-api.md), [internal RPC](case-internal-rpc.md), [polyglot boundary](case-polyglot-boundary.md).

**Data / events track:** [using this suite](using-this-suite.md) → [row vs columnar](row-vs-columnar.md) → [two schema cultures](two-schema-cultures.md) → [schema registries](schema-registries.md) → [versioning](versioning-in-the-wild.md) → cases [event backbone](case-event-stream.md), [analytics lake](case-analytics-lake.md).

**Performance deep path:** [using this suite](using-this-suite.md) → [implementation variance](implementation-variance.md) → [latency tails and GC](latency-tails-and-gc.md) → [compression as system choice](compression-as-system-choice.md) → [zero-copy in production](zero-copy-in-production.md) → [faster postmortem](case-faster-postmortem.md).

## Modules

### Trust & boundaries

| Article | You should be able to… |
|---------|------------------------|
| [Trust boundaries: portable vs native](trust-boundaries.md) | Say when native formats are unacceptable as interchange |
| [Untrusted input and parser risk](untrusted-input.md) | Name failure modes and controls for hostile payloads |
| [Secrets, PII, and payload surfaces](payload-surfaces.md) | Spot leak surfaces in logs, traces, and secondary stores |

### Contracts that survive years

| Article | You should be able to… |
|---------|------------------------|
| [Two schema cultures: Avro vs Protobuf](two-schema-cultures.md) | Contrast resolution culture vs field-number discipline |
| [Schema registries and compatibility modes](schema-registries.md) | Choose and enforce BACKWARD / FORWARD / FULL-class policy |
| [Public API contracts](public-api-contracts.md) | Require a hard contract when the wire is JSON |
| [Versioning strategies in the wild](versioning-in-the-wild.md) | Plan dual-write, content-type, and kill criteria |

### Workload architecture

| Article | You should be able to… |
|---------|------------------------|
| [Row vs columnar at system scale](row-vs-columnar.md) | Keep RPC codecs out of lake design (and the reverse) |
| [Polyglot estates](polyglot-estates.md) | Defend one product contract across runtimes |
| [RPC and messaging payload design](rpc-and-messaging.md) | Shape messages for sync vs fan-out |
| [Zero-copy in production](zero-copy-in-production.md) | Adopt zero-copy only when ops fit |
| [Caching and queues](caching-and-queues.md) | Keep shared stores portable and versioned |

### Performance as engineering

| Article | You should be able to… |
|---------|------------------------|
| [Using this suite without fooling yourself](using-this-suite.md) | Read Results within paradigm and language |
| [Implementation variance within a family](implementation-variance.md) | Choose libraries without ranking formats globally |
| [Latency tails, allocations, and GC](latency-tails-and-gc.md) | Judge p99 and allocation pressure |
| [Compression as a system choice](compression-as-system-choice.md) | Place gzip/zstd without replacing format design |

### Capstones

| Case study | Focus |
|------------|--------|
| [Public REST API](case-public-rest-api.md) | JSON + validation vs dual contracts |
| [Internal high-QPS RPC](case-internal-rpc.md) | Schema-driven vs schemaless binary |
| [Event backbone](case-event-stream.md) | Avro/Protobuf + evolution under rolling deploy |
| [Analytics lake](case-analytics-lake.md) | Columnar lake vs row event dumps |
| [Cross-language service boundary](case-polyglot-boundary.md) | One contract, three languages |
| [“We need it faster” postmortem](case-faster-postmortem.md) | Wrong bench vs wrong paradigm vs wrong payload |

## Lab notebooks (Python / Colab)

Experiment notebooks implement selected article **Experiments** (decision labs, not full harness clones):

| Notebook | Article |
|----------|---------|
| [Trust boundaries](../notebooks/301/trust_boundaries.ipynb) | [Trust boundaries](trust-boundaries.md) |
| [Untrusted input](../notebooks/301/untrusted_input.ipynb) | [Untrusted input](untrusted-input.md) |
| [Two schema cultures](../notebooks/301/two_schema_cultures.ipynb) | [Two schema cultures](two-schema-cultures.md) |
| [Row vs columnar](../notebooks/301/row_vs_columnar.ipynb) | [Row vs columnar](row-vs-columnar.md) |

Notes: [notebooks README](../notebooks/README.md).

## Honesty rules

Same program rules as 101 / 201:

1. No universal winners — always under stated constraints.  
2. Implementation beats brand name.  
3. Payload shape matters.  
4. Compare within paradigm and within one language before cross-cutting claims.  
5. Security and trust are first-class.  
6. Prose numbers are illustrative; **Results** own suite truth for this harness.

**301-specific:** every article includes **Experiments** (setup, procedure, decision rule for the page’s problem) and **Metrics** (primary signals for that experiment’s conclusion), plus **what this suite cannot tell you**. Prefer failure modes and decision tables over mechanism encyclopedias.

## Assessment (self-check)

Treat the capstone case studies as the course exam: under fixed constraints, recommend an approach, name the evidence you would collect on this suite, and state what you would still need to measure outside the harness.

## Where to go next

- Finish or skim [Serialization 201](../201/index.md) if mechanisms are rusty.  
- [Serialization categories](../../analysis/serialization_categories.md) and language **Results** for suite evidence.  
- [Serialization 401](../401/index.md) if you build or deeply integrate codecs.
