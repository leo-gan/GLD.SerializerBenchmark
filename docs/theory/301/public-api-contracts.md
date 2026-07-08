# Public API contracts (JSON + schema layers)

## Problem

JSON’s flexibility is a gift for browsers and integrators and a curse for accidental breakage: fields appear, types drift (`"1"` vs `1`), and renames ship without a version bump. Saying “we use JSON” is not a contract. Public APIs need an **external schema and process** as strict as IDL cultures—just with different artifacts.

## Short answer

For public or cross-org HTTP APIs, pair JSON with a **published contract**: OpenAPI and/or JSON Schema (or equivalent), server-side validation, consumer-driven or contract tests, and a versioning policy ([versioning in the wild](versioning-in-the-wild.md)). Choose JSON libraries for performance and correctness ([implementation variance](implementation-variance.md)); do not skip the contract layer because the bytes are text. Binary dual-stack is optional and earned ([case: public REST](case-public-rest-api.md)).

## Constraints that matter

| Layer | Job |
|-------|-----|
| **Wire** | JSON (or dual content-types) |
| **Contract doc** | OpenAPI / JSON Schema / protobuf if dual |
| **Runtime validation** | Reject illegal bodies early |
| **Tests** | Provider + consumer checks |
| **Process** | Review, deprecation windows, changelog |

## Decision frame

| Need | Action |
|------|--------|
| Third-party integrators | Published OpenAPI; stable URLs; deprecation policy |
| Type-safe clients | Generate from OpenAPI; or offer dual Protobuf |
| Rapid internal-only iteration | Still validate; shorter deprecation OK |
| “Schemaless for agility” | Accept silent client breakage—or stop claiming stability |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| OpenAPI stale vs server | Docs lie; clients fail |
| Validate only in one gateway | Alternate entrypoints drift |
| Optional everything | No real contract |
| Breaking change without version | Integrator outages |
| PII in examples | Doc surface leak ([payload surfaces](payload-surfaces.md)) |

## Real-world sketch

A fintech publishes OpenAPI 3 and generates TypeScript and Kotlin clients. CI fails if the server’s request models drift from the spec. A “quick” field rename without version bump is blocked. Performance work swaps Python JSON libraries using suite Results without touching the public contract.

## In this suite

| Resource | Role |
|----------|------|
| JSON-family **Results** | Pick implementations per language |
| [Categories](../../analysis/serialization_categories.md) | JSON vs other families |
| [Using this suite](using-this-suite.md) | Fair comparisons |


## Experiments

**Question:** Is the public wire **contract** hard enough (schema/OpenAPI/JSON Schema), and what breaks if we only “use JSON”?

### Setup
1. Collect public endpoints and current docs (OpenAPI, ad hoc examples).  
2. List client languages and critical fields.  
3. One proposed additive change and one breaking change.

### Procedure
1. Validate production samples against the published schema (should pass).  
2. Ship additive change; confirm old clients still work.  
3. Attempt breaking change behind a new version or content-type; confirm old route unchanged.  
4. Check error bodies for accidental internal leakage ([payload surfaces](payload-surfaces.md)).  
5. Suite: optional JSON library compare for server language—**after** contract exists.

### Decision rule
- No machine-readable contract + multi-party clients ⇒ insufficient; add schema before optimizing codecs.  
- Performance experiments only among codecs that honor the published contract.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Schema coverage** (% endpoints with formal schema) | **Primary** |
| Contract-test pass rate in CI | Enforcement |
| Breaking-change escape rate | Process quality |
| Client SDK regenerate success | Contract usability |
| Suite JSON `deser_median_ns` / size | Secondary server cost |
| `mean_fidelity` | Implementation correctness |

**Conclusion style:** “OpenAPI + JSON Schema required; content-type versioning for breaks.”

## What this suite cannot tell you

- OpenAPI style guide politics.  
- Whether to use URL versioning vs header versioning.  
- Partner communication SLAs.

## Common mistakes

- Treating JSON Schema as optional documentation only.  
- Generating OpenAPI from code without review (noise and breaks).  
- Different field names in Android vs web “by accident.”

## Key takeaways

- Public JSON needs a **hard contract process**, not vibes.  
- Validation and tests enforce what prose promises.  
- Suite helps choose JSON **libraries**, not whether a contract exists.  
- Dual binary APIs are additive products—not a substitute for JSON governance.
