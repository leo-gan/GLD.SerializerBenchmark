# Polyglot estates

## Problem

Real software estates run **C#**, **Python**, **Go**, **Rust**, **JavaScript**, and more against shared data. A **polyglot estate** is an organization that ships more than one programming language in production and expects those languages to interoperate.

Each language has a “fastest” library on some chart. Without a polyglot policy, every team picks a local optimum: one service speaks MessagePack with string keys, another speaks Protobuf, and a third pickles values into Redis.

Integration cost appears later as translation layers, dual-write windows, and incidents that only reproduce at language boundaries. This page teaches the policy that prevents that drift.

---

## Short answer

For each **boundary**—public API, internal RPC, async event, cache, or file—pick **one portable contract** and implement it in every language that crosses that boundary. Prefer formats with **mature multi-language implementations** and an explicit evolution story ([two schema cultures](two-schema-cultures.md)).

A **contract** here means the shared rules for field identity, types, and allowed evolution—not merely “we both somehow use JSON.”

Use this suite to compare **implementations within one language**, not to elect a global winner across languages. Dual contracts are allowed at **edges** (for example JSON on the public surface and Protobuf internally) when translation is owned and tested—not as accidental drift.

This page assumes [trust boundaries](trust-boundaries.md) (no language-native interchange) and [using this suite](using-this-suite.md).

---

## Constraints that matter

| Constraint | Implication |
|------------|-------------|
| **Languages in the critical path** | The contract must have libraries or code generation in each of them |
| **Human debuggability** | Public and partner edges often keep JSON even when internal traffic is binary |
| **Evolution ownership** | One IDL, registry, or process—not N ad hoc JSON dialects |
| **Team skill** | Exotic codecs that only one expert understands do not survive staff changes |
| **Fidelity** | Types such as decimals, timestamps, and maps must round-trip across languages |
| **Operations tooling** | Can on-call engineers inspect payloads during incidents? |

**Fidelity** means that after encode in language A and decode in language B, the logical values still match. Without fidelity, “we all speak Protobuf” is a slogan rather than a fact.

---

## Decision frame

| Boundary | Common polyglot choice | Notes |
|----------|------------------------|-------|
| Public HTTP API | JSON plus OpenAPI or JSON Schema | Dual Protobuf is optional for selected clients |
| Internal synchronous RPC | Protobuf/IDL or schemaless binary with validation | One choice per platform, not a different choice per service |
| Async events | Avro or Protobuf plus a registry, **or** JSON with a strict schema process | Match your [schema culture](two-schema-cultures.md) |
| Shared cache blob | Portable binary or JSON with a documented schema | Never use pickle as the cross-service default |
| Data lake | Columnar formats or Avro—not whatever is fashionable for RPC | See [row vs columnar](row-vs-columnar.md) |

```text
  List languages that must speak the boundary
        → eliminate codecs without a multi-language story
        → pick a family (JSON / schemaless binary / schema-driven)
        → pick ONE evolution process
        → implement and run conformance tests across languages
        → use per-language Results only to pick libraries
```

This matters because a library that is excellent in one runtime is useless if another required language has no maintained implementation.

---

## Failure modes

| Mistake | Consequence |
|---------|-------------|
| **Local leaderboard** | Each team’s fastest library; no shared byte format |
| **Native “just for us”** | A second language cannot join the path |
| **Undocumented JSON dialects** | Field renames break silently |
| **Number of contracts grows with the number of teams** | A quadratic mess of translators |
| **Cross-language rank from the suite** | “Rust won, rewrite the company” |
| **Schema lives in only one repository** | Other languages reverse-engineer production traffic |

For example, if every team invents its own JSON field names for the “same” event, you no longer have one estate—you have several products that only look related.

---

## Real-world sketch

Platform engineering standardizes **internal RPC on Protobuf** and **public HTTP on JSON**. Python, Go, and TypeScript services generate stubs from the same protos. Public gateways map JSON to Protobuf at the edge with explicit field tests.

A team proposes MessagePack everywhere because it looked strong on one language Results page. Review asks: do all six languages have maintained libraries, a single evolution story, and a debug story? Without that, MessagePack becomes another dialect. The suite still helps each language pick **which Protobuf or JSON library** to use.

---

## In this suite

| Resource | Role |
|----------|------|
| Multi-language Results | Evidence for **library choice per language** under one family |
| [Serialization categories](../../analysis/serialization_categories.md) | Shared family vocabulary |
| Shared `schemas/` (for example `.proto` files) where present | Example of one contract, many benchmark runners |
| [Using this suite](using-this-suite.md) | Never crown cross-language winners |

A format that appears in **many** language overviews is a candidate for polyglot adoption. Absence in one language is an **integration risk**, not a moral failing of that language.

---

## Experiments

**Question:** Can one **product contract** interoperate across the languages we ship—and where does fidelity break?

### Setup

1. List languages on the boundary and the candidate contract (for example Protobuf plus a shared `.proto`).
2. Prepare shared golden fixtures with logical values.
3. Plan an encode/decode matrix ([401 cross-language fidelity](../401/protobuf-cross-language-fidelity.md) if you use Protobuf).

### Procedure

1. Freeze the schema and fixture values.
2. Encode in each language; decode in every other; assert **logical** equality.
3. Optionally assert bit-identity, and document whether you require it.
4. Run per-language suite fidelity for benchmark runner round-trip (local only).
5. Record footguns such as defaults, packed repeated fields, and renames.

### Decision rule

- Any required language pair that fails logical interoperability needs a contract or implementation fix before performance tuning.
- The product choice of family stays fixed; suite multi-language speed ranks do **not** pick the estate contract.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Matrix pass rate** (encode in A, decode in B) | **Primary** |
| Logical field equality | Correctness definition |
| Bit-identical encode (optional) | Relevant only for caching or signing |
| Per-language `mean_fidelity` | Local benchmark runner health |
| Schema and version alignment | Drift detector |
| Per-language latency Results | Capacity planning **after** interop works |

**Conclusion style:** “Protobuf contract is green on the Python/Go/Rust matrix; pin `prost` and `protobuf` versions.”

---

## What this suite cannot tell you

- The political cost of mandating one IDL monorepo.
- Whether your gateway team can own JSON-to-binary translation.
- The full matrix of type fidelity for every field across all languages (you must design conformance tests).
- Vendor lock-in and staffing cost for exotic codecs.

---

## Common mistakes

- Saying “we’ll translate later” without an owner.
- Using different field names per language for the “same” event.
- Treating suite cross-language plots (if any) as architecture mandates.

---

## Key takeaways

- Polyglot estates need **one contract per boundary**, not one library for the whole company.
- Portable formats, a multi-language ecosystem, and an evolution process beat single-language speed.
- The suite picks implementations **inside** a language after the contract is fixed.
- Dual stacks at edges are fine when **owned**; accidental dual stacks are debt.
- Native codecs stop at the trust boundary ([trust boundaries](trust-boundaries.md)).
