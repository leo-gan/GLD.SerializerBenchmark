# Serialization 301: Production Data Serialization

> Production serialization—trust, contracts, workloads, and honest measurement—for people who already know how formats work.

## Who this is for

Experienced students and developers who must **ship a choice** under conflicting constraints (trust, evolution, multi-language estates, performance claims). This is the **core** advanced course after [Serialization 201](../deep-dives/index.md).

If you need to **implement** a codec (wire encoding, runtime paths, a subset lab), that is Serialization **401** (planned elective)—not this course.

## Prerequisites

| Type | Requirement |
|------|-------------|
| **Hard** | [Serialization 101](../index.md) — trade-off axes and at least one lens |
| **Hard** | [Serialization 201](../deep-dives/index.md) — especially schema identity, evolution, dynamic vs IDL, encode cost, zero-copy, compression vs format *(or equivalent experience)* |

This course does **not** re-teach 201 mechanisms. Open the 201 article when you need a model; return here for multi-constraint judgment.

## Learning outcomes

By the end of this course you should be able to:

1. **Analyze** trust boundaries and state when portable vs language-native formats are acceptable.
2. **Distinguish** operational schema cultures (e.g. Avro-style resolution vs Protobuf field-number discipline) without re-deriving wire rules.
3. **Evaluate** workload fit (row vs columnar at system scale; polyglot contracts).
4. **Critique** benchmark claims using this suite’s paradigm-and-language rules.
5. **Recommend** a family or approach under stated constraints and **justify** it with categories and **Results**.
6. **Identify** what this harness cannot answer.

## How this course fits the program

| Course | Role |
|--------|------|
| [101](../index.md) | Foundations — what serialization is; axes and lenses |
| [201](../deep-dives/index.md) | Mechanisms — how formats work |
| **301 (this course)** | Production judgment — what to ship under constraints |
| **401** (planned) | Implementer elective — wire + language paths + lab |

Default path: **101 → 201 → 301**. Suite lab: [Benchmarks](../../analysis/index.md) and language **Results**.

## Modules

Articles ship incrementally. The hub lists the full curriculum; missing pages are not linked until published.

### Trust & boundaries

| Article | You should be able to… | Status |
|---------|------------------------|--------|
| [Trust boundaries: portable vs native](trust-boundaries.md) | Say when native formats are unacceptable as interchange | **Published** |
| Untrusted input and parser risk | Name failure modes for hostile payloads | Planned (later) |
| Secrets, PII, and payload surfaces | Spot leak surfaces in logs and dumps | Planned (later) |

### Contracts that survive years

| Article | You should be able to… | Status |
|---------|------------------------|--------|
| [Two schema cultures: Avro vs Protobuf](two-schema-cultures.md) | Contrast resolution culture vs field-number discipline | **Published** |
| Schema registries and compatibility modes | Use BACKWARD / FORWARD / FULL appropriately | Planned (later) |
| Public API contracts | Require a hard contract when the wire is JSON | Planned (later) |

### Workload architecture

| Article | You should be able to… | Status |
|---------|------------------------|--------|
| Row vs columnar at system scale | Keep RPC codecs out of lake design (and the reverse) | Planned |
| Polyglot estates | Defend one product contract across runtimes | Planned |

### Performance as engineering

| Article | You should be able to… | Status |
|---------|------------------------|--------|
| [Using this suite without fooling yourself](using-this-suite.md) | Read Results within paradigm and language | **Published** |
| Implementation variance within a family | Choose among libraries without ranking formats globally | Planned |

### Capstones

| Case study | Focus | Status |
|------------|--------|--------|
| Public REST API | JSON + validation vs dual contracts | Planned |
| Internal high-QPS RPC | Schema-driven vs schemaless binary | Planned |
| Event backbone | Avro/Protobuf + evolution under rolling deploy | Planned |

## Honesty rules

Same program rules as 101 / 201:

1. No universal winners — always under stated constraints.  
2. Implementation beats brand name.  
3. Payload shape matters.  
4. Compare within paradigm and within one language before cross-cutting claims.  
5. Security and trust are first-class.  
6. Prose numbers are illustrative; **Results** own suite truth for this harness.

**301-specific:** every article should end with what to measure here and **what this suite cannot tell you**. Prefer failure modes and decision tables over mechanism encyclopedias.

## Assessment (self-check)

When articles and capstones are published, treat the three MVP case studies as the course exam: under fixed constraints, recommend an approach, name the evidence you would collect on this suite, and state what you would still need to measure outside the harness.

## Where to go next

- Finish or skim [Serialization 201](../deep-dives/index.md) if mechanisms are rusty.  
- [Serialization categories](../../analysis/serialization_categories.md) and language **Results** for suite evidence.  
- Serialization **401** (planned) if you build or deeply integrate codecs.
