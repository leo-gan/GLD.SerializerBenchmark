# Case study: public REST API

> A multi-client HTTP API must stay inspectable and stable while latency and payload size start to hurt—what serialization approach fits?

## Context & goals

**Setting:** A B2B product exposes a versioned REST API over HTTPS. Clients include browser SPAs, mobile apps, and third-party integrators. Payloads are mostly business documents (orders, accounts)—not multi-megabyte bulk extracts. On-call engineers debug production using logs and `curl`.

**Goals:**

- Human-readable request/response bodies at the edge.  
- Stable contract for external integrators (years).  
- Acceptable p95 latency under expected load.  
- Validation of untrusted input.

## Non-goals / hard constraints

- Not a private mesh-only RPC (see [internal RPC case](case-internal-rpc.md)).  
- Not an analytics lake ([row vs columnar](row-vs-columnar.md)).  
- Cannot require all clients to run `protoc`.  
- Language-native codecs forbidden on this boundary ([trust boundaries](trust-boundaries.md)).

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. JSON only + schema** | JSON bodies; OpenAPI/JSON Schema; pick strong JSON libs per language |
| **B. Dual stack** | JSON default; optional Protobuf (or similar) on same resources via content negotiation |
| **C. Binary-only public API** | Schema-driven or MessagePack as the only public encoding |

## Trade-off matrix

| Axis | A. JSON + schema | B. Dual stack | C. Binary-only public |
|------|------------------|---------------|------------------------|
| Integrator friction | Lowest | Medium (two modes) | Highest |
| Debug / support | Excellent | Good if JSON remains default | Weak without tools |
| Evolution | Process + schema docs | Two surfaces to version | IDL discipline |
| Performance headroom | Implementation-limited | Binary path for heavy clients | Best potential size/CPU |
| Ops complexity | Low | Medium (transcoding, tests) | Medium–high |
| Trust | Portable; still validate | Same | Portable; still validate |

## Recommendation (under these constraints)

**Prefer A (JSON + hard contract)** as the default public surface. Invest in: OpenAPI/JSON Schema (or equivalent), server-side validation, and **per-language JSON library** selection using suite Results ([implementation variance](implementation-variance.md)).

**Consider B** only when measured evidence shows JSON cannot meet SLOs **after** library and payload-shape work, *and* a non-trivial client set will adopt binary. Own content-type negotiation and conformance tests for both encodings.

**Reject C** for this public multi-integrator setting unless the product is explicitly a binary protocol API (not classic REST for third parties).



## Experiments

**Question:** For this public REST API, do we ship **JSON + hard contract** only, or a **dual** binary/JSON contract?

### Setup
1. Constraints from the case (public clients, versioning, team skills).  
2. Draft OpenAPI/JSON Schema for the resource.  
3. Optional second content-type candidate (e.g. Protobuf) only if clients demand it.

### Procedure
1. Contract-test JSON samples against schema (old + additive).  
2. Load-test JSON library options on the server language ([implementation variance](implementation-variance.md)).  
3. If dual contract proposed: interop matrix for the binary type + versioning plan.  
4. Compare ops cost of one vs two contracts against non-goals.  
5. Recommend under the case constraints.

### Decision rule
- Default: single JSON contract with schema if public multi-language clients dominate.  
- Dual only with explicit client need and versioning budget.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| Schema/contract CI pass rate | **Primary** ship gate |
| Public client break rate on additive changes | Evolution safety |
| Server p99 on JSON encode/decode | Performance SLO |
| Suite JSON metrics (language of server) | Library shortlist |
| Dual-contract engineering cost | Go/no-go for second type |
| Payload leak checks on errors | Security |

**Conclusion style:** Match the case **Recommendation**; metrics must support it.

## What would change the answer

- First-party-only clients under your control → B or internal binary becomes easier.  
- Huge bulk download endpoints → separate export format (columnar/files), not the CRUD API default.  
- Regulatory need for non-JSON → document exception; still avoid native codecs.

## Key takeaways

- Public REST defaults to **JSON + explicit contract**, not the fastest binary on a chart.  
- Suite helps choose **JSON libraries**, not whether to abandon HTTP JSON wholesale.  
- Dual stack is earned by measurement and client willingness—not fashion.
