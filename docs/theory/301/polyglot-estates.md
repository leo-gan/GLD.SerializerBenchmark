# Multi-language systems (polyglot estates)

## Problem

Real organizations run many systems and clients in **C#**, **Python**, **Go**, **Rust**, **JavaScript**, and more against shared data. A **polyglot estate** is that set of systems: more than one programming language in production, expected to interoperate. *Polyglot* means multi-language.

Each language has a “fastest” library on some chart. Without a multi-language (*polyglot*) policy, every team picks a local optimum. One service speaks MessagePack with string keys. Another speaks Protobuf. A third pickles values into Redis.

Integration cost appears later. It shows up as translation layers, dual-write windows, and incidents that only reproduce at language boundaries. This page teaches the policy that prevents that drift.

---

## Short answer

For each **boundary**, pick **one portable contract**. Boundaries include public API, internal RPC, async event, cache, and file. Implement that contract in every language that crosses the boundary. Prefer formats with **mature multi-language implementations**. Prefer formats with an explicit evolution story. See [two schema cultures](two-schema-cultures.md).

A **contract** here means the shared rules for field identity, types, and allowed evolution. It is not merely “we both somehow use JSON.”

Use this suite to compare **implementations within one language**. Do not use it to elect a global winner across languages. Dual contracts are allowed at **edges**. One example is JSON on the public surface and Protobuf internally. That is fine when translation is owned and tested. It is not fine as accidental drift.

This page assumes [trust boundaries](trust-boundaries.md). Language-native interchange is not allowed. It also assumes [using this suite](using-this-suite.md).

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

| Boundary | Common multi-language (polyglot) choice | Notes |
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
        → implement and run tests that check every language implements the same contract
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

For example, suppose every team invents its own JSON field names for the “same” event. You no longer have one shared set of systems. You have several products that only look related.

---

## Real-world sketch

Platform engineering standardizes **internal RPC on Protobuf**. It standardizes **public HTTP on JSON**. Python, Go, and TypeScript services generate stubs from the same protos. Public gateways map JSON to Protobuf at the edge with explicit field tests.

A team proposes MessagePack everywhere because it looked strong on one language Results page. Review asks hard questions. Do all six languages have maintained libraries? Is there a single evolution story? Is there a debug story? Without that, MessagePack becomes another dialect. The suite still helps each language pick **which Protobuf or JSON library** to use.

---

## In this suite

| Resource | Role |
|----------|------|
| Multi-language Results | Evidence for **library choice per language** under one family |
| [Serialization categories](../../analysis/serialization_categories.md) | Shared family vocabulary |
| Shared `schemas/` (for example `.proto` files) where present | Example of one contract, many benchmark runners |
| [Using this suite](using-this-suite.md) | Never crown cross-language winners |

A format that appears in **many** language overviews is a candidate for multi-language (polyglot) adoption. Absence in one language is an **integration risk**. It is not a moral failing of that language.

---

## Experiments

**Question:** Can one **product contract** interoperate across the languages we ship? Where does fidelity break?

### Setup

1. List languages on the boundary. List the candidate contract. One example is Protobuf plus a shared `.proto`.
2. Prepare shared golden fixtures with logical values.
3. Plan an encode and decode matrix. See [401 cross-language fidelity](../401/protobuf-cross-language-fidelity.md) if you use Protobuf.

### Procedure

1. Freeze the schema and fixture values.
2. Encode in each language. Decode in every other. Assert **logical** equality.
3. Optionally assert bit-identity. Document whether you require it.
4. Run per-language suite fidelity for benchmark runner round-trip. That check is local only.
5. Record footguns. Examples include defaults, packed repeated fields, and renames.

### Decision rule

- Any required language pair that fails logical interoperability needs a fix. Fix the contract or the implementation before performance tuning.
- The product choice of family stays fixed. Suite multi-language speed ranks do **not** pick the contract for the set of systems the organization runs.

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

- The political cost of mandating one shared IDL code repository for many projects.
- Whether your gateway team can own JSON-to-binary translation.
- The full matrix of type fidelity for every field across all languages. You must design tests that check every language implements the same contract.
- Vendor lock-in and staffing cost for exotic codecs.

---

## Common mistakes

- Saying “we’ll translate later” without an owner.
- Using different field names per language for the “same” event.
- Treating suite cross-language plots as architecture mandates. Those plots may not exist, and they still would not be mandates.

---

## Key takeaways

- Multi-language (polyglot) systems need **one contract per boundary**. They do not need one library for the whole company.
- Portable formats, a multi-language ecosystem, and an evolution process beat single-language speed.
- The suite picks implementations **inside** a language after the contract is fixed.
- Dual stacks at edges are fine when **owned**. Accidental dual stacks are debt.
- Native codecs stop at the trust boundary. See [trust boundaries](trust-boundaries.md).
