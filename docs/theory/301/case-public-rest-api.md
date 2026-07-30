# Case study: public REST API

> A multi-client HTTP API must stay inspectable and stable while latency and payload size start to hurt. What serialization approach fits?

This case study puts the earlier articles into one decision. You will practice recommending an approach under fixed constraints, naming suite evidence you would collect, and stating what still must be measured outside the benchmark runner.

---

## Context and goals

**Setting:** A business-to-business product exposes a versioned REST API over HTTPS. Clients include browser single-page applications, mobile apps, and third-party integrators. Payloads are mostly business documents (orders, accounts)—not multi-megabyte bulk extracts. On-call engineers debug production using logs and `curl`.

**REST** here means a conventional HTTP API with resources and JSON-style bodies, as integrators expect. **HTTPS** is HTTP over TLS, so transport encryption is already in place.

**Goals:**

- Human-readable request and response bodies at the edge.
- A stable contract for external integrators over years.
- Acceptable p95 latency under expected load.
- Validation of untrusted input.

---

## Non-goals and hard constraints

- This is not a private mesh-only RPC (see [internal RPC case](case-internal-rpc.md)).
- This is not an analytics lake ([row vs columnar](row-vs-columnar.md)).
- You cannot require all clients to run `protoc`.
- Language-native codecs are forbidden on this boundary ([trust boundaries](trust-boundaries.md)).

In other words, the public surface must remain approachable for partners who only speak HTTP and JSON tooling.

---

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. JSON only plus schema** | JSON bodies; OpenAPI or JSON Schema; pick strong JSON libraries per language |
| **B. Dual stack** | JSON as the default; optional Protobuf (or similar) on the same resources via content negotiation |
| **C. Binary-only public API** | Schema-driven binary or MessagePack as the only public encoding |

**Content negotiation** means the client and server agree on a content type (for example via `Accept` headers) so the same resource can be returned in more than one encoding.

---

## Trade-off matrix

| Axis | A. JSON + schema | B. Dual stack | C. Binary-only public |
|------|------------------|---------------|------------------------|
| Integrator friction | Lowest | Medium (two modes to support) | Highest |
| Debug and support | Excellent | Good if JSON remains the default | Weak without specialized tools |
| Evolution | Process plus schema docs | Two surfaces to version | IDL discipline |
| Performance headroom | Limited by the JSON implementation | Binary path available for heavy clients | Best potential size and CPU |
| Operations complexity | Low | Medium (transcoding and tests) | Medium to high |
| Trust | Portable; still validate | Same | Portable; still validate |

This matters because the “fastest” option on a suite chart is often the worst option for third-party integrators who need `curl` and clear docs.

---

## Recommendation (under these constraints)

**Prefer A (JSON plus a hard contract)** as the default public surface. Invest in OpenAPI or JSON Schema (or an equivalent), server-side validation, and **per-language JSON library** selection using suite Results ([implementation variance](implementation-variance.md)).

**Consider B** only when measured evidence shows JSON cannot meet service-level objectives **after** library and payload-shape work, *and* a non-trivial client set will adopt binary. Own content-type negotiation and conformance tests for both encodings.

**Reject C** for this public multi-integrator setting unless the product is explicitly a binary protocol API rather than classic REST for third parties.

---

## Experiments

**Question:** For this public REST API, do we ship **JSON plus a hard contract** only, or a **dual** binary and JSON contract?

### Setup

1. Restate the constraints from the case (public clients, versioning, team skills).
2. Draft OpenAPI or JSON Schema for the resource.
3. Optionally name a second content-type candidate (for example Protobuf) only if clients demand it.

### Procedure

1. Contract-test JSON samples against the schema (old clients and additive changes).
2. Load-test JSON library options on the server language ([implementation variance](implementation-variance.md)).
3. If a dual contract is proposed: build an interop matrix for the binary type and a versioning plan.
4. Compare operations cost of one versus two contracts against the non-goals.
5. Recommend under the case constraints.

### Decision rule

- Default to a single JSON contract with schema when public multi-language clients dominate.
- Offer dual encoding only with explicit client need and versioning budget.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| Schema and contract CI pass rate | **Primary** ship gate |
| Public client break rate on additive changes | Evolution safety |
| Server p99 on JSON encode and decode | Performance service-level objective |
| Suite JSON metrics (language of the server) | Library shortlist |
| Dual-contract engineering cost | Go or no-go for a second type |
| Payload leak checks on errors | Security |

**Conclusion style:** Match the case **Recommendation**; the metrics must support it.

---

## What would change the answer

- First-party-only clients under your control make B or internal binary easier.
- Huge bulk download endpoints want a separate export format (columnar files), not the CRUD API default.
- A regulatory need for non-JSON is a documented exception; still avoid native codecs.

---

## Key takeaways

- Public REST defaults to **JSON plus an explicit contract**, not the fastest binary on a chart.
- The suite helps choose **JSON libraries**, not whether to abandon HTTP JSON wholesale.
- A dual stack is earned by measurement and client willingness—not fashion.
