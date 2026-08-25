# Case study: cross-language service boundary

> Three languages must share one internal contract. How do you stop local optima from fragmenting the set of systems the organization runs?

A **multi-language (polyglot) boundary** is a place where more than one programming language must speak the same data contract. This case study applies [multi-language systems (polyglot estates)](polyglot-estates.md) to a concrete three-language path. It insists on interoperability evidence before performance tuning.

---

## Context and goals

**Setting:** An edge gateway in TypeScript. A core API in Go. A machine-learning feature service in Python. The network is private. The team needs a shared request and response for feature fetch at moderate requests per second (*QPS*). On-call engineers must be able to debug failures in human-readable ways when needed.

**Goals:** One portable contract. Independent deploys. Acceptable latency. No native codecs.

---

## Non-goals and hard constraints

- This is not a public third-party API. JSON may still be used at the outer edge.
- This is not an analytics lake.
- Python cannot dictate native pickle to Go or TypeScript.

In other words, local language convenience ends where the shared hop begins.

---

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. Protobuf IDL plus code generation** | Shared protos; per-language libraries chosen from the Dashboard |
| **B. JSON plus JSON Schema** | Uniform text; validate on each side |
| **C. MessagePack ad hoc** | Compact; organization-owned schemas |
| **D. Each language picks its favorite** | Local Dashboard winners only |

---

## Trade-off matrix

| Axis | A. Protobuf | B. JSON | C. MessagePack | D. Mixed |
|------|-------------|---------|----------------|----------|
| Multi-language (polyglot) maturity | Strong | Strong | Good if disciplined | Fail |
| Debug | Tooling required | Easy | Medium | Chaos |
| Density | High | Lower | Medium to high | Not meaningful |
| Evolution | Field numbers plus CI | Process-heavy | Process-heavy | None |
| Risk | IDL ownership | Verbosity | Schema drift | Integration hell |

This matters because option D maximizes local microbenchmark wins. It minimizes health of the shared multi-language systems.

---

## Recommendation (under these constraints)

**Prefer A** if the organization will own one shared proto code repository for many projects and continuous-integration breaking checks. See [two schema cultures](two-schema-cultures.md) and [multi-language systems (polyglot estates)](polyglot-estates.md). **Prefer B** if debug and simplicity outweigh density and requests per second allow. Still enforce a schema. Use the [public API contracts](public-api-contracts.md) pattern internally. **C** is acceptable only with explicit schema docs and tests that check every language implements the same contract. **Reject D**.

Pick **implementations per language** via the Dashboard within the chosen family. See [implementation variance](implementation-variance.md).

---

## Experiments

**Question:** With one contract across three languages, does the **interop matrix** pass before we optimize performance?

An **interop matrix** means this: encode a golden fixture in each language and decode it in every other language. Assert logical equality.

### Setup

1. The three languages from the case and a shared schema.
2. Golden logical fixtures.
3. A continuous-integration job skeleton for the encode and decode matrix.

### Procedure

1. Freeze the schema. Implement the matrix. See [multi-language systems (polyglot estates)](polyglot-estates.md) and [401 fidelity](../401/protobuf-cross-language-fidelity.md).
2. Fix failures. Cover defaults, field names, and packing.
3. Then pin per-language libraries via the Dashboard.
4. Document version pins and the CI gate.

### Decision rule

- A green matrix is required before performance work.
- Do not use a global “fastest language” ranking as the boundary decision.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| Matrix pass rate | **Primary** |
| Logical equality failures by language pair | Debug signal |
| Per-language `mean_fidelity` | Local health |
| Per-language 99th-percentile latency (*p99*: 99% of requests are faster than this) and suite medians | Capacity after interop |
| Version pin drift | Drift risk |

---

## What would change the answer

- A browser on the same hop suggests JSON at the edge and binary internally via a gateway.
- Extreme requests per second (QPS) lean harder toward A plus load tests. See [latency tails](latency-tails-and-gc.md).

---

## Key takeaways

- One boundary means one portable contract and N implementations.
- The suite optimizes **library pins**. It does not settle the politics of mixed formats.
- Tests that check every language implements the same contract are part of the recommendation.
