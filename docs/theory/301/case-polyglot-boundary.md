# Case study: cross-language service boundary

> Three languages must share one internal contract—how do you stop local optima from fragmenting the estate?

## Context & goals

**Setting:** Edge gateway (TypeScript), core API (Go), ML feature service (Python). Private network. Need shared request/response for feature fetch at moderate QPS. Human debug of failures required for on-call.

**Goals:** One portable contract, independent deploys, acceptable latency, no native codecs.

## Non-goals / hard constraints

- Not public third-party API (JSON may still be used at outer edge).  
- Not analytics lake.  
- Python cannot dictate native pickle to Go/TS.

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. Protobuf IDL + codegen** | Shared protos; per-language libs from Results |
| **B. JSON + JSON Schema** | Uniform text; validate each side |
| **C. MessagePack ad hoc** | Compact; org-owned schemas |
| **D. Each language picks favorite** | Local Results winners |

## Trade-off matrix

| Axis | A. Protobuf | B. JSON | C. MessagePack | D. Mixed |
|------|-------------|---------|----------------|----------|
| Polyglot maturity | Strong | Strong | Good if disciplined | Fail |
| Debug | Tooling | Easy | Medium | Chaos |
| Density | High | Lower | Medium–high | — |
| Evolution | Field numbers + CI | Process heavy | Process heavy | None |
| Risk | IDL ownership | Verbosity | Schema drift | Integration hell |

## Recommendation (under these constraints)

**Prefer A** if the org will own a proto monorepo and CI breaking checks ([two schema cultures](two-schema-cultures.md), [polyglot estates](polyglot-estates.md)). **Prefer B** if debug/simplicity outweigh density and QPS allows—still enforce schema ([public API contracts](public-api-contracts.md) pattern internally). **C** only with explicit schema docs and conformance tests. **Reject D**.

Pick **implementations per language** via suite Results within the chosen family ([implementation variance](implementation-variance.md)).



## Experiments

**Question:** One contract across three languages—does the **interop matrix** pass before we optimize?

### Setup
1. Three languages from the case; shared schema.  
2. Golden logical fixtures.  
3. CI job skeleton for encode/decode matrix.

### Procedure
1. Freeze schema; implement matrix ([polyglot estates](polyglot-estates.md), [401 fidelity](../401/protobuf-cross-language-fidelity.md)).  
2. Fix failures (defaults, field names, packing).  
3. Then per-language library pins via suite Results.  
4. Document version pins and CI gate.

### Decision rule
- Matrix green required before performance work.  
- No global “fastest language” ranking as the boundary decision.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| Matrix pass rate | **Primary** |
| Logical equality failures by pair | Debug signal |
| Per-lang `mean_fidelity` | Local health |
| Per-lang p99 / suite medians | Capacity after interop |
| Version pin drift | Drift risk |

## What would change the answer

- Browser on the same hop → JSON edge + binary internal via gateway.  
- Extreme QPS → lean harder to A + load tests ([latency tails](latency-tails-and-gc.md)).

## Key takeaways

- One boundary → one portable contract → N implementations.  
- Suite optimizes **library pins**, not politics of mixed formats.  
- Conformance tests are part of the recommendation.
