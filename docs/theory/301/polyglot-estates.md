# 3.6 Multi-Language Systems

## Problem Statement

Production organizations rarely operate in a single programming language; a typical platform spans Go or Rust core services, Python data and machine-learning pipelines, Java or C# enterprise backends, and TypeScript clients. Without a boundary-level interoperability policy, each team selects the fastest serializer visible on its local language chart—one service emits MessagePack with string keys, another uses Protocol Buffers, and a third writes Python `pickle` into Redis.

The resulting fragmentation produces translation proxies, dual-write migrations, and type-conversion defects that manifest exclusively at language boundaries.

---

## One Portable Contract per Boundary

!!! note "Definition: Cross-Language Logical Equivalence"
    A serialization contract satisfies **cross-language logical equivalence** across languages $\{L_1, \dots, L_m\}$ if, for every valid schema instance $x$ and every ordered pair $(L_i, L_j)$, encoding $x$ in $L_i$ and decoding the resulting bytes in $L_j$ yields a value logically equal to $x$ under the contract's type semantics (including numeric precision, timestamps, nullability, empty collections, and Unicode normalization).

Architecture policy in a multi-language (**polyglot**) estate follows three rules:

1. **Standardize per boundary, not per team:** Every cross-process boundary—public HTTP API, internal RPC mesh, event backbone, shared cache, or data lake—has **one portable standard** and **one schema/evolution process**.
2. **Choose libraries locally after fixing the contract:** Once the boundary standard is fixed, each language team selects and pins the best-performing, well-maintained *implementation* of that standard using the per-language [Dashboard](../../dashboard/index.html) slice (see [3.9 Fair benchmarking and implementation variance](using-this-suite.md)).
3. **Permit owned edge translation, forbid accidental drift:** Using JSON on a public HTTP gateway and Protocol Buffers on the internal service mesh is sound when translation is explicit, versioned, and tested at the gateway. Ad hoc format dialects inside the same internal tier create $O(m^2)$ translation debt across $m$ languages.

| Boundary | Standard Polyglot Default | Governance Requirement |
|---|---|---|
| Public HTTP API | JSON + OpenAPI / JSON Schema | Automated contract checks; versioned error shapes |
| Internal synchronous RPC | Protocol Buffers (or gRPC) across compiled and dynamic services | Shared `.proto` repository + CI breaking-change gate |
| Asynchronous event bus | Avro or Protocol Buffers + Schema Registry | Enforced compatibility mode ([3.3 Schema cultures](two-schema-cultures.md)) |
| Shared cache or task queue | Portable binary or schema-documented JSON | Never language-native (`pickle`, Java serialization) |
| Analytical data lake | Parquet or ORC + table catalog | Compaction pipeline from operational events ([3.5 Row vs. columnar](row-vs-columnar.md)) |

---

## Constraints and Failure Modes

Evaluating a candidate contract across a multi-language estate requires checking five operational constraints before consulting speed benchmarks:

- **Ecosystem coverage:** Every language on the critical path (and foreseeable near-term consumers) must have an actively maintained, fuzzed implementation. A format with an exceptional Rust crate but an unmaintained Python binding is an integration hazard.
- **Type-system edge cases:** 64-bit integers in JavaScript (IEEE 754 `Number` loses precision above $2^{53} - 1$), arbitrary-precision decimals, timezone-aware timestamps, unsigned integers, map key types, and NaN/Infinity floats diverge subtly across languages unless specified in the contract.
- **Single source of schema truth:** Storing schemas inside one service's source repository forces other language teams to reverse-engineer production payloads.
- **Operational debuggability:** On-call engineers must be able to inspect wire payloads during incidents using standard CLI decoders or descriptor-aware tools.
- **Trust boundaries:** Language-native formats terminate at single-process, single-trust boundaries ([3.1 Trust boundaries](trust-boundaries.md)).

### Common Failure Modes

| Mistake | System Consequence |
|---|---|
| **Local leaderboard optimization** | Each service picks its fastest local library; no shared wire contract exists |
| **Cross-language benchmark crowning** | Comparing a Rust codec against a Python codec to argue for rewriting a language stack or changing the wire standard |
| **Single-language round-trip treated as interop** | Passing encode-then-decode inside one runtime hides cross-language defaults, packing, or signedness bugs |
| **Undocumented JSON dialects** | Services silently disagree on camelCase vs. snake_case, integer-as-string encoding, or missing vs. `null` fields |

---

## Interoperability Matrix Verification

This benchmark suite computes `mean_fidelity` by encoding and decoding a test payload **within one language runner**. That check confirms local round-trip correctness; it does **not** prove specification compliance (see [Compliance](../../dashboard/index.html#compliance)) and does **not** test interoperability between two different languages.

Before tuning performance on any multi-language boundary, implement an **$m \times m$ interoperability matrix** in CI (detailed for Protocol Buffers in [4.7 Cross-language fidelity](../401/protobuf-cross-language-fidelity.md)):

1. **Freeze canonical test vectors:** Author shared golden logical records covering boundary values (zero/empty defaults, large 64-bit integers, non-ASCII UTF-8 strings, optional/null fields, nested maps, and enums).
2. **Run the full $m \times m$ matrix:** Encode every vector in each language $L_i$ and decode the raw bytes in every language $L_j$ ($1 \le i, j \le m$). Assert **logical equality** on every cell.
3. **Specify bit-identity only when needed:** Assert byte-for-byte identity only when payloads are cryptographically signed or content-addressed (note that most formats—including Protocol Buffers and JSON—are not canonical without explicit deterministic rules).[^1]
4. **Pin concrete library versions:** Once the matrix passes, consult the per-language Dashboard under the fixed standard to shortlist and pin implementations in each language's lockfile.

**Limits of this benchmark suite:** Single-language benchmark runners do not measure organizational costs of maintaining a shared IDL repository, gateway translation ownership, or full cross-language type-edge compliance.

---

## Exercises

1. **Precision mismatch across runtimes:** A Go service serializes 64-bit snowflake order IDs (`int64`) as JSON numbers and sends them to a TypeScript browser client using `JSON.parse`. What failure occurs, and how should the cross-language contract prevent it?

??? note "Solution"
    JavaScript's IEEE 754 double-precision `Number` represents integers exactly only up to $2^{53} - 1$ (`9007199254740991`). Larger 64-bit IDs silently round to the nearest representable float, corrupting order lookups. The cross-language contract must encode 64-bit identifiers as **JSON strings** (following the Proto3 JSON mapping specification[^2]) and validate the pattern in the OpenAPI/JSON Schema and the Go $\leftrightarrow$ TypeScript interop matrix.

2. **Local round-trip vs. cross-language matrix:** Both a Python serializer and a Rust serializer achieve `mean_fidelity = 1.0` in this benchmark suite on MessagePack. Why is that insufficient to guarantee they interoperate in production?

??? note "Solution"
    `mean_fidelity = 1.0` verifies only that Python decodes Python's output and Rust decodes Rust's output. The two libraries may still disagree on wire conventions—for example, encoding structs as positional arrays vs. string-keyed maps, representing timestamps as extension types vs. epoch integers, or distinguishing `bin` from `str`—causing cross-language decode failures unless an explicit $2 \times 2$ interop matrix tests them together.

3. **Gateway boundary design:** An organization has external mobile/web clients plus internal Go, Rust, and Python services. Should it standardize on one format everywhere or run two formats? Justify the boundary placement.

??? note "Solution"
    Run **two deliberately owned contracts** separated at the API gateway: **JSON + OpenAPI** on the external edge (for browser/partner ergonomics and `curl` debuggability) and **Protocol Buffers + shared `.proto` repository** on the internal Go/Rust/Python mesh (for strict typing, density, and automated breaking-change checks). Because translation occurs in one tested gateway layer rather than ad hoc between internal services, complexity remains bounded at $O(1)$ edge translators instead of $O(m^2)$.

---

## References

[^1]: Kleppmann, M. (2017). *Designing Data-Intensive Applications*, Chapter 4 (*Encoding and Evolution*). O'Reilly Media.
[^2]: Protocol Buffers Documentation. *Proto3 JSON Mapping*. <https://protobuf.dev/programming-guides/json/>
