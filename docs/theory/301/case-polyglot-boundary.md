# Case study: cross-language service boundary

> Three languages must share one internal contract. How do you stop local optima from fragmenting the estate?

## Context and goals

**Setting:** An edge gateway in TypeScript, a core API in Go, and a machine-learning feature service in Python. The network is private. The team needs a shared request and response for feature fetch at moderate QPS. On-call engineers must be able to debug failures in human-readable ways when needed.

**Goals:** One portable contract, independent deploys, acceptable latency, and no native codecs.

## Non-goals and hard constraints

- This is not a public third-party API (JSON may still be used at the outer edge).
- This is not an analytics lake.
- Python cannot dictate native pickle to Go or TypeScript.

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. Protobuf IDL plus code generation** | Shared protos; per-language libraries chosen from Results |
| **B. JSON plus JSON Schema** | Uniform text; validate on each side |
| **C. MessagePack ad hoc** | Compact; organization-owned schemas |
| **D. Each language picks its favorite** | Local Results winners only |

## Trade-off matrix

| Axis | A. Protobuf | B. JSON | C. MessagePack | D. Mixed |
|------|-------------|---------|----------------|----------|
| Polyglot maturity | Strong | Strong | Good if disciplined | Fail |
| Debug | Tooling required | Easy | Medium | Chaos |
| Density | High | Lower | Medium to high | Not meaningful |
| Evolution | Field numbers plus CI | Process-heavy | Process-heavy | None |
| Risk | IDL ownership | Verbosity | Schema drift | Integration hell |

## Recommendation (under these constraints)

**Prefer A** if the organization will own a proto monorepo and continuous-integration breaking checks ([two schema cultures](two-schema-cultures.md), [polyglot estates](polyglot-estates.md)). **Prefer B** if debug and simplicity outweigh density and QPS allows—still enforce a schema ([public API contracts](public-api-contracts.md) pattern used internally). **C** is acceptable only with explicit schema docs and conformance tests. **Reject D**.

Pick **implementations per language** via suite Results within the chosen family ([implementation variance](implementation-variance.md)).

## Experiments

**Question:** With one contract across three languages, does the **interop matrix** pass before we optimize performance?

### Setup

1. The three languages from the case and a shared schema.
2. Golden logical fixtures.
3. A continuous-integration job skeleton for the encode/decode matrix.

### Procedure

1. Freeze the schema; implement the matrix ([polyglot estates](polyglot-estates.md), [401 fidelity](../401/protobuf-cross-language-fidelity.md)).
2. Fix failures (defaults, field names, packing).
3. Then pin per-language libraries via suite Results.
4. Document version pins and the CI gate.

### Decision rule

- A green matrix is required before performance work.
- Do not use a global “fastest language” ranking as the boundary decision.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| Matrix pass rate | **Primary** |
| Logical equality failures by language pair | Debug signal |
| Per-language `mean_fidelity` | Local health |
| Per-language p99 and suite medians | Capacity after interop |
| Version pin drift | Drift risk |

## What would change the answer

- A browser on the same hop suggests JSON at the edge and binary internally via a gateway.
- Extreme QPS leans harder toward A plus load tests ([latency tails](latency-tails-and-gc.md)).

## Key takeaways

- One boundary means one portable contract and N implementations.
- The suite optimizes **library pins**, not the politics of mixed formats.
- Conformance tests are part of the recommendation.
