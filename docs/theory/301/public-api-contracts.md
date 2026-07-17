# Public API contracts (JSON + schema layers)

## Problem

JSON’s flexibility is a gift for browsers and integrators and a curse for accidental breakage. Fields appear without notice, types drift (`"1"` versus `1`), and renames ship without a version bump. Saying “we use JSON” is not a contract.

Public APIs need an **external schema and process** as strict as IDL cultures—just with different artifacts.

## Short answer

For public or cross-organization HTTP APIs, pair JSON with a **published contract**: OpenAPI and/or JSON Schema (or an equivalent), server-side validation, consumer-driven or contract tests, and a versioning policy (see [versioning in the wild](versioning-in-the-wild.md)).

Choose JSON libraries for performance and correctness (see [implementation variance](implementation-variance.md)). Do not skip the contract layer because the bytes happen to be text. A binary dual stack is optional and must be earned (see [case: public REST](case-public-rest-api.md)).

## Constraints that matter

| Layer | Job |
|-------|-----|
| **Wire** | JSON bodies (or dual content types when a second encoding exists) |
| **Contract document** | OpenAPI, JSON Schema, or Protobuf if you offer a dual stack |
| **Runtime validation** | Reject illegal bodies early, before business logic runs |
| **Tests** | Provider checks and consumer-driven checks |
| **Process** | Review, deprecation windows, and a changelog |

## Decision frame

| Need | Action |
|------|--------|
| Third-party integrators | Publish OpenAPI; keep URLs stable; write a deprecation policy |
| Type-safe clients | Generate clients from OpenAPI, or offer dual Protobuf for selected clients |
| Rapid internal-only iteration | Still validate; shorter deprecation windows may be acceptable |
| “Schemaless for agility” | Accept silent client breakage—or stop claiming the API is stable |

## Failure modes

| Mistake | Outcome |
|---------|---------|
| OpenAPI goes stale relative to the server | Documentation lies; clients fail in surprising ways |
| Validation only in one gateway | Alternate entry points drift from the contract |
| Everything is optional | There is no real contract |
| Breaking change without a version | Integrator outages |
| PII in documentation examples | Documentation becomes a leak surface ([payload surfaces](payload-surfaces.md)) |

## Real-world sketch

A fintech publishes OpenAPI 3 and generates TypeScript and Kotlin clients. Continuous integration fails if the server’s request models drift from the specification. A “quick” field rename without a version bump is blocked. Later performance work swaps Python JSON libraries using suite Results without touching the public contract at all.

## In this suite

| Resource | Role |
|----------|------|
| JSON-family **Results** | Pick implementations per language |
| [Categories](../../analysis/serialization_categories.md) | JSON versus other families |
| [Using this suite](using-this-suite.md) | Fair comparisons inside a family |

## Experiments

**Question:** Is the public wire **contract** hard enough (schema, OpenAPI, or JSON Schema), and what breaks if we only “use JSON”?

### Setup

1. Collect public endpoints and current docs (OpenAPI or ad hoc examples).
2. List client languages and critical fields.
3. Prepare one proposed additive change and one breaking change.

### Procedure

1. Validate production samples against the published schema (they should pass).
2. Ship the additive change and confirm old clients still work.
3. Attempt the breaking change behind a new version or content type; confirm the old route is unchanged.
4. Check error bodies for accidental internal leakage ([payload surfaces](payload-surfaces.md)).
5. Optionally compare JSON libraries for the server language—**after** the contract exists.

### Decision rule

- No machine-readable contract plus multi-party clients is insufficient. Add a schema before optimizing codecs.
- Run performance experiments only among codecs that honor the published contract.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Schema coverage** (percentage of endpoints with a formal schema) | **Primary** |
| Contract-test pass rate in CI | Enforcement quality |
| Breaking-change escape rate | Process quality |
| Client SDK regenerate success | Contract usability |
| Suite JSON `deser_median_ns` and size | Secondary server cost |
| `mean_fidelity` | Implementation correctness |

**Conclusion style:** “OpenAPI and JSON Schema are required; breaking changes use content-type versioning.”

## What this suite cannot tell you

- OpenAPI style-guide politics inside your organization.
- Whether to use URL versioning versus header versioning.
- Partner communication service-level agreements.

## Common mistakes

- Treating JSON Schema as optional documentation only.
- Generating OpenAPI from code without review (noise and accidental breaks).
- Different field names in Android versus web clients “by accident.”

## Key takeaways

- Public JSON needs a **hard contract process**, not good intentions.
- Validation and tests enforce what prose promises.
- The suite helps you choose JSON **libraries**, not whether a contract exists.
- Dual binary APIs are additive products—not a substitute for JSON governance.
