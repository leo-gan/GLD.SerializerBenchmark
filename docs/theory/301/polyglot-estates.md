# Polyglot estates

## Problem

Real estates run **C#**, **Python**, **Go**, **Rust**, **JavaScript**, and more against shared data. Each language has a “fastest” library on some chart. Without a polyglot policy, every team picks a local optimum: one service speaks MessagePack with string keys, another speaks Protobuf, a third pickles to Redis. Integration cost appears later as translation layers, dual-write windows, and incidents that only reproduce at language boundaries.

## Short answer

For each **boundary** (public API, internal RPC, async event, cache, file), pick **one portable contract** and implement it in every language that crosses that boundary. Prefer formats with **mature multi-language implementations** and an explicit evolution story ([two schema cultures](two-schema-cultures.md)). Use this suite to compare **implementations within one language**, not to elect a global winner across languages. Dual contracts are allowed at **edges** (e.g. JSON public + Protobuf internal) when translation is owned and tested—not as accidental drift.

Assumes [trust boundaries](trust-boundaries.md) (no language-native interchange) and [using this suite](using-this-suite.md).

## Constraints that matter

| Constraint | Implication |
|------------|-------------|
| **Languages in the critical path** | Contract must have libraries (or codegen) in each |
| **Human debuggability** | Public/partner edges often keep JSON even if internal is binary |
| **Evolution ownership** | One IDL/registry/process—not N ad-hoc JSON dialects |
| **Team skill** | Exotic codecs with one expert do not survive staff changes |
| **Fidelity** | Types (decimals, timestamps, maps) must round-trip across languages |
| **Ops tooling** | Can on-call inspect payloads in incidents? |

## Decision frame

| Boundary | Common polyglot choice | Notes |
|----------|------------------------|-------|
| Public HTTP API | JSON + OpenAPI/JSON Schema | Dual Protobuf optional for selected clients |
| Internal sync RPC | Protobuf/IDL or schemaless binary with validation | One choice per platform, not per service |
| Async events | Avro/Protobuf + registry **or** JSON with strict schema process | Match [schema culture](two-schema-cultures.md) |
| Shared cache blob | Portable binary or JSON; document schema | Never pickle as cross-service default |
| Data lake | Columnar / Avro—not RPC fashion | See [row vs columnar](row-vs-columnar.md) |

```text
  List languages that must speak the boundary
        → eliminate codecs without multi-lang story
        → pick family (JSON / schemaless binary / schema-driven)
        → pick ONE evolution process
        → implement + conformance tests across languages
        → use per-language Results only to pick libraries
```

## Failure modes

| Mistake | Consequence |
|---------|-------------|
| **Local leaderboard** | Each team’s fastest lib; no shared bytes |
| **Native “just for us”** | Second language cannot join |
| **Undocumented JSON dialects** | Field renames break silently |
| **Number of contracts ∝ number of teams** | N² translators |
| **Cross-language rank from suite** | “Rust won, rewrite the company” |
| **Schema only in one repo** | Other languages reverse-engineer production |

## Real-world sketch

Platform engineering standardizes **internal RPC on Protobuf** and **public HTTP on JSON**. Python, Go, and TypeScript services generate stubs from the same protos; public gateways map JSON ↔ Protobuf at the edge with explicit field tests. A team proposes MessagePack everywhere because it looked strong on one language Results page. Review asks: do all six languages have maintained libs, a single evolution story, and debug story? Without that, MessagePack becomes another dialect. The suite still helps each language pick **which Protobuf or JSON library** to use.

## In this suite

| Resource | Role |
|----------|------|
| Multi-language Results | Evidence for **library choice per language** under one family |
| [Serialization categories](../../analysis/serialization_categories.md) | Shared family vocabulary |
| Shared `schemas/` (e.g. `.proto`) where present | Example of one contract, many harnesses |
| [Using this suite](using-this-suite.md) | Never crown cross-language winners |

A format that appears in **many** language overviews is a candidate for polyglot adoption; absence in one language is a **integration risk**, not a moral failing of that language.


## Experiments

**Question:** Can one **product contract** interoperate across the languages we ship—and where does fidelity break?

### Setup
1. List languages on the boundary and candidate contract (e.g. Protobuf + shared `.proto`).  
2. Shared golden fixtures (logical values).  
3. Encode/decode matrix plan ([401 cross-language fidelity](../401/protobuf-cross-language-fidelity.md) if Protobuf).

### Procedure
1. Freeze schema and fixture values.  
2. Encode in each language; decode in every other; assert **logical** equality.  
3. Optionally assert bit-identity (document if not required).  
4. Run per-language suite fidelity for harness round-trip (local only).  
5. Record footguns (defaults, packed repeated, renames).

### Decision rule
- Any required language pair failing logical interop ⇒ contract or implementation fix before performance tuning.  
- Product choice of family stays; suite multi-language speed ranks do **not** pick the estate contract.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Matrix pass rate** (encode A → decode B) | **Primary** |
| Logical field equality | Correctness definition |
| Bit-identical encode (optional) | Caching/signing only |
| Per-language `mean_fidelity` | Local harness health |
| Schema/version alignment | Drift detector |
| Per-language latency Results | Capacity planning **after** interop |

**Conclusion style:** “Pb contract green on Py/Go/Rust matrix; pin prost/protobuf versions.”

## What this suite cannot tell you

- Political cost of mandating one IDL monorepo.  
- Whether your gateway team can own JSON↔binary translation.  
- Full matrix of type fidelity for every field across all languages (design conformance tests).  
- Vendor lock-in and staffing for exotic codecs.

## Common mistakes

- “We’ll translate later” without an owner.  
- Different field names per language for the “same” event.  
- Using suite cross-language plots (if any) as architecture mandates.

## Key takeaways

- Polyglot estates need **one contract per boundary**, not one library for the company.  
- Portable + multi-language ecosystem + evolution process beat single-language speed.  
- Suite = pick implementations **inside** a language after the contract is fixed.  
- Dual stacks at edges are fine when **owned**; accidental dual stacks are debt.  
- Native codecs stop at the trust boundary ([trust boundaries](trust-boundaries.md)).
