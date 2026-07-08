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

## How to validate

| Step | Where |
|------|--------|
| Within-language family compare | Go / Python / JS **Results** |
| Cross-language golden payloads | CI conformance **outside** suite rank tables |
| Never crown cross-language winner from mixed charts | [Using this suite](using-this-suite.md) |

## What would change the answer

- Browser on the same hop → JSON edge + binary internal via gateway.  
- Extreme QPS → lean harder to A + load tests ([latency tails](latency-tails-and-gc.md)).

## Key takeaways

- One boundary → one portable contract → N implementations.  
- Suite optimizes **library pins**, not politics of mixed formats.  
- Conformance tests are part of the recommendation.
