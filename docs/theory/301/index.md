# Serialization 301: Production Data Serialization

> This course is about **production serialization**. You will learn how teams choose formats and libraries when several real pressures act at the same time. Those pressures include trust, contracts, real workloads, and honest measurement. The course is written for people who already know how formats work. Now they need to decide what to ship.

| Jump | |
|------|--|
| **Prereqs** | [101](../101/index.md) · [201](../201/index.md) |
| **Implementers** | [401 elective](../401/index.md) |
| **Measure** | [Dashboard](../../dashboard/) · [using this suite](using-this-suite.md) · [Benchmarks](../../analysis/index.md) |

In this course you will not re-learn wire encoding from scratch. Instead you will practice **judgment under constraints**. A first-year computer science student who has finished [Serialization 101](../101/index.md) and [Serialization 201](../201/index.md) should be able to follow every article. The technical depth stays. The language aims to teach rather than to impress.

---

## Who this is for

Serialization 301 is for students and developers who must **ship a choice** when constraints conflict. In production those constraints usually include:

- **Trust and security** — who is allowed to create or read the bytes.
- **Schema evolution** — how messages change while old and new software still run.
- **Multi-language systems** — more than one programming language sharing the same data across the systems the organization runs.
- **Performance claims** — numbers that do not all point the same way.

This is the **core** advanced course after Serialization 201. In other words, 201 explains *how formats work*. Course 301 asks *what you should ship when several good answers conflict*.

If your goal is to **implement** a codec, that work belongs in [Serialization 401](../401/index.md). Serialization 401 is the implementer elective. It covers wire encoding, runtime paths, and a hands-on subset lab. Those topics are not the focus of this course.

---

## Prerequisites

| Type | Requirement |
|------|-------------|
| **Hard** | [Serialization 101](../101/index.md) — trade-off axes and at least one of the three lenses |
| **Hard** | [Serialization 201](../201/index.md) — especially schema identity, evolution, dynamic versus IDL (interface definition language) binary formats, encode cost, zero-copy, and compression versus format *(or equivalent experience)* |

This course does **not** re-teach the mechanisms from 201. When you need a mechanism model, open the matching 201 article. Then return here for multi-constraint judgment.

---

## Learning outcomes

By the end of this course you should be able to:

1. **Analyze** trust boundaries. State when portable formats are required. State when language-native formats might still be acceptable. A **trust boundary** is a place where data leaves one controlled world. That world might be a process, a team, or a network. Beyond the boundary, someone else may see or produce the data.
2. **Distinguish** operational schema cultures without re-deriving wire rules from scratch. One example is Avro-style writer and reader resolution. Another is Protobuf field-number discipline.
3. **Evaluate** workload fit. That includes row versus columnar storage at system scale. It includes multi-language (*polyglot*) contracts across languages. It also includes the different shapes of **RPC** versus messaging payloads. **RPC** means remote procedure call. It is a synchronous request and response between services.
4. **Critique** benchmark claims. Use this suite’s rules about paradigm families and single-language comparisons.
5. **Recommend** a format family or approach under stated constraints. **Justify** the recommendation with serialization categories and the Dashboard.
6. **Identify** what this benchmark runner cannot answer. That skill stops you from over-claiming.

---

## How this course fits the program

| Course | Role |
|--------|------|
| [101](../101/index.md) | Foundations — what serialization is; trade-off axes and lenses |
| [201](../201/index.md) | Mechanisms — how formats work under the hood |
| **301 (this course)** | Production judgment — what to ship under real constraints |
| [401](../401/index.md) | Implementer elective — wire formats, language paths, and a hands-on lab |

The default path through the program is **101, then 201, then 301**. For measured evidence on this project’s benchmark runner, use the [Dashboard](../../dashboard/). For how the suite measures, see [Benchmarks](../../analysis/index.md).

---

## Suggested paths

You do not need to read every article in order. Pick a track that matches the problem you are solving.

**Services track.** Start with [trust boundaries](trust-boundaries.md) and [untrusted input](untrusted-input.md). Then read [using this suite](using-this-suite.md) so you do not misread numbers. Continue with [two schema cultures](two-schema-cultures.md) and [public API contracts](public-api-contracts.md). Next read [rpc and messaging](rpc-and-messaging.md) and [implementation variance](implementation-variance.md). Finish with the service case studies: [public REST](case-public-rest-api.md), [internal RPC](case-internal-rpc.md), and [multi-language (polyglot) boundary](case-polyglot-boundary.md).

**Data and events track.** Start with [using this suite](using-this-suite.md) and [row vs columnar](row-vs-columnar.md). Then study [two schema cultures](two-schema-cultures.md), [schema registries](schema-registries.md), and [versioning](versioning-in-the-wild.md). Finish with [event backbone](case-event-stream.md) and [analytics lake](case-analytics-lake.md).

**Performance deep path.** Start with [using this suite](using-this-suite.md) and [implementation variance](implementation-variance.md). Then read [latency tails and GC](latency-tails-and-gc.md). **GC** means garbage collection. That is the automatic reclaiming of unused memory on managed runtimes. Next read [compression as system choice](compression-as-system-choice.md) and [zero-copy in production](zero-copy-in-production.md). Close with the [faster postmortem](case-faster-postmortem.md) case study.

---

## Modules

### Trust and boundaries

| Article | You should be able to… |
|---------|------------------------|
| [Trust boundaries: portable vs native](trust-boundaries.md) | Explain when language-native formats are unacceptable as interchange |
| [Untrusted input and parser risk](untrusted-input.md) | Name failure modes and controls for hostile payloads |
| [Secrets, PII, and payload surfaces](payload-surfaces.md) | Spot leak surfaces in logs, traces, and secondary stores. **PII** means personally identifiable information. That is data that can identify a person. |

### Contracts that survive years

| Article | You should be able to… |
|---------|------------------------|
| [Two schema cultures: Avro vs Protobuf](two-schema-cultures.md) | Contrast resolution culture with field-number discipline |
| [Schema registries and compatibility modes](schema-registries.md) | Choose and enforce BACKWARD, FORWARD, or FULL-class compatibility policy |
| [Public API contracts](public-api-contracts.md) | Require a hard contract even when the wire format is JSON |
| [Versioning strategies in the wild](versioning-in-the-wild.md) | Plan dual-write periods, content-type versioning, and kill criteria for old paths |

### Workload architecture

| Article | You should be able to… |
|---------|------------------------|
| [Row vs columnar at system scale](row-vs-columnar.md) | Keep RPC message codecs out of lake design. Keep lake formats off the hot RPC path. |
| [Multi-language systems (polyglot estates)](polyglot-estates.md) | Defend one product contract across several language runtimes |
| [RPC and messaging payload design](rpc-and-messaging.md) | Shape messages differently for synchronous calls versus one-to-many (fan-out) events |
| [Zero-copy in production](zero-copy-in-production.md) | Adopt zero-copy layouts only when operations and tooling fit |
| [Caching and queues](caching-and-queues.md) | Keep shared caches and queues portable and versioned |

### Performance as engineering

| Article | You should be able to… |
|---------|------------------------|
| [Using this suite without fooling yourself](using-this-suite.md) | Read Dashboard numbers within one paradigm family and one language |
| [Implementation variance within a family](implementation-variance.md) | Choose libraries without ranking formats globally |
| [Latency tails, allocations, and GC](latency-tails-and-gc.md) | Judge 99th-percentile latency (*p99*: 99% of requests are faster than this) and allocation pressure. |
| [Compression as a system choice](compression-as-system-choice.md) | Place gzip or zstd in the stack without treating compression as a format |

### Capstones

| Case study | Focus |
|------------|--------|
| [Public REST API](case-public-rest-api.md) | JSON plus validation versus dual contracts |
| [Internal high-QPS RPC](case-internal-rpc.md) | Schema-driven binary versus schemaless binary. **QPS** means queries or requests per second. |
| [Event backbone](case-event-stream.md) | Avro or Protobuf plus evolution under gradual updates (old and new versions together) |
| [Analytics lake](case-analytics-lake.md) | Columnar lake storage versus dumping row events forever |
| [Cross-language service boundary](case-polyglot-boundary.md) | One contract shared by three languages |
| [“We need it faster” postmortem](case-faster-postmortem.md) | Wrong benchmark versus wrong paradigm versus wrong payload |

---

## Lab notebooks (Python / Colab)

Experiment notebooks implement selected article **Experiments**. They are decision labs. They are not full clones of the suite benchmark runner:

| Notebook | Article |
|----------|---------|
| [Trust boundaries](../notebooks/301/trust_boundaries.ipynb) | [Trust boundaries](trust-boundaries.md) |
| [Untrusted input](../notebooks/301/untrusted_input.ipynb) | [Untrusted input](untrusted-input.md) |
| [Two schema cultures](../notebooks/301/two_schema_cultures.ipynb) | [Two schema cultures](two-schema-cultures.md) |
| [Row vs columnar](../notebooks/301/row_vs_columnar.ipynb) | [Row vs columnar](row-vs-columnar.md) |

Install and run notes live in the [notebooks README](../notebooks/README.md).

---

## Honesty rules

The same program rules apply as in 101 and 201:

1. There are no universal winners. Every recommendation is under stated constraints.
2. How well a library is written often matters more than the name of the format. Two libraries can share a format label and still differ sharply.
3. Payload shape matters. Dense records and deep graphs are different jobs.
4. Compare within one paradigm family and within one language before making cross-cutting claims.
5. Security and trust are first-class concerns. They are not afterthoughts.
6. Numbers in prose are illustrative. The **Dashboard** owns measured numbers for this benchmark runner.

**301-specific guidance:** every article includes **Experiments**. Those sections cover setup, procedure, and a decision rule for that page’s problem. Every article also includes **Metrics**. Those are the primary signals for that experiment’s conclusion. Every article also includes a section on **what this suite cannot tell you**. Prefer failure modes and decision tables over encyclopedias of wire formats.

---

## Assessment (self-check)

Treat the capstone case studies as the course exam. Under fixed constraints, recommend an approach. Name the evidence you would collect on this suite. State what you would still need to measure outside the benchmark runner.

---

## Where to go next

- Finish or skim [Serialization 201](../201/index.md) if the mechanisms feel rusty.
- Use [Serialization categories](../../analysis/serialization_categories.md) and the [Dashboard](../../dashboard/) for suite evidence.
- Move to [Serialization 401](../401/index.md) if you build or deeply integrate codecs.
