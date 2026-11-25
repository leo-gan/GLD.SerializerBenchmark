# 3.4 Public API Contracts and Versioning

## Problem Statement

Public HTTP APIs standardize on JSON because browsers, mobile SDKs, proxies, and external integrators can inspect and consume it with minimal friction. That wire flexibility creates an operational hazard: without a formal contract and versioning discipline, fields drift silently (`"1"` vs. `1`), breaking renames ship without notice, and external clients experience outages even while server unit tests remain green.

"Using JSON" specifies only syntax—not a product contract. External APIs require an **explicit machine-readable specification**, **runtime enforcement**, and a **versioned migration playbook** whenever non-additive changes become unavoidable.

---

## Hardening a Public JSON Contract

A durable public contract combines five independent layers:

| Layer | Responsibility | Failure Mode if Omitted |
|---|---|---|
| **Specification** | Machine-readable OpenAPI 3 / JSON Schema document[^1][^2] | Documentation drifts from reality; clients guess field types and nullability |
| **Runtime validation** | Validate incoming requests (and optionally contract-test responses) before business logic runs | Invalid shapes trigger downstream crashes or silent type coercion |
| **Contract tests in CI** | Automated provider/consumer tests and breaking-change linters (e.g., OpenAPI diff) | Accidental field removals or type changes merge undetected |
| **Client generation** | Generate typed SDKs or shared types directly from the specification | Per-client drift across web, iOS, Android, and partner integrations |
| **Lifecycle policy** | Published deprecation windows, changelogs, and explicit versioning surface | Surprise partner outages and permanent legacy maintenance debt |

Keep wire contract governance cleanly separated from library selection: once the JSON schema is enforced in CI, you can swap server-side JSON implementations (guided by the language's JSON [Dashboard](../../dashboard/index.html) slice) without breaking external clients. Offering a dual binary content type (such as optional Protocol Buffers via `Accept` negotiation) is an additive product commitment—never a substitute for JSON contract governance ([Case 1: Public REST API](case-public-rest-api.md)).

---

## Versioning Strategies in Production {#versioning-strategies}

Prefer **additive, backward-compatible evolution** (new optional fields with documented defaults; consumers ignoring unknown keys) for all routine changes. When a breaking change is unavoidable—such as altering a field's type (`amount` float → `amount_cents` integer) or changing domain semantics—apply an **expand/contract** migration rather than an atomic cutover.[^3]

!!! note "Definition: Expand/Contract and Kill Criteria"
    - **Expand/contract** executes a breaking change across three distinct releases: *(1)* **expand** the schema and server to support both old and new representations, *(2)* **migrate** clients/data via dual-read or dual-write, and *(3)* **contract** by retiring the old representation.
    - **Kill criteria** are measurable telemetry thresholds that authorize deleting the legacy path (for example, *"v1 traffic below 0.5% for 14 consecutive days with zero active enterprise callers"*).

### Choosing the Right Migration Tactic

| Change Class | Recommended Playbook | Key Operational Cost |
|---|---|---|
| **Field rename** | Dual-write both keys; readers prefer new key; remove old key after kill criteria pass | Temporary payload bloat and dual-write consistency logic |
| **Type change** (e.g., float → integer cents) | Introduce a new field name/number (`amount_cents`); never overload the existing key | Must ensure idempotent merge rules if both fields can be updated |
| **Semantic break across a resource** | Explicit version surface: **URL path** (`/v2/orders`) or **media-type header** (`Accept: application/vnd.example.v2+json`)[^4] | Maintaining parallel handlers and documentation during deprecation |
| **Event-stream breaking change** | Parallel topic/subject (`orders.v2`) with dual-publish bridge until consumer lag drains | Temporary storage and consumer cutover coordination |
| **Field removal** | Mark deprecated in OpenAPI/changelog, observe client telemetry, gate removal in CI | Breaking unmonitored long-tail mobile or partner versions |

### Common Operational Pitfalls

1. **Documentation theater:** Maintaining an OpenAPI file manually without validating server payloads or running CI diff checks against it.
2. **Dual-write without kill criteria:** Shipping a migration bridge with no usage telemetry or sunset date turns temporary compatibility code into permanent schema debt.
3. **Dropping `v1` while mobile binaries remain live:** Native mobile clients upgrade over months, not hours; deprecation windows must match real client upgrade curves.
4. **Inconsistent error surfaces:** Failing to keep error response schemas versioned and redacted ([3.2 Untrusted input and payload surfaces](untrusted-input.md#payload-surfaces)).

---

## Contract Audit Checklist and Benchmark Limits

Before shipping a public API change or swapping a server JSON library:

1. **Verify schema coverage:** Confirm every public endpoint and error body is defined in OpenAPI / JSON Schema and validated at ingress.
2. **Gate breaking changes in CI:** Run automated schema diffing on pull requests; verify that additive changes pass against archived `v1` client test payloads.
3. **Instrument legacy traffic before migrating:** For any breaking change, define explicit **version traffic metrics**, **rollback procedure**, and **kill criteria** before starting dual-write.
4. **Select JSON library within the contract:** Compare RFC 8259-compliant JSON libraries for your server language on the [Dashboard](../../dashboard/index.html) (`Standard: json`) and verify strict edge-case behavior in [Dashboard · Compliance](../../dashboard/index.html#compliance).

**Limits of this benchmark suite:** The benchmark runner measures codec throughput and size on fixed shapes—it cannot model your client upgrade curve, partner SLA negotiations, or OpenAPI governance workflow.

---

## Exercises

1. **Float-to-cents migration:** A public billing REST API currently returns `"amount": 19.99` (JSON number) and must migrate to exact integer minor units (`"amount_cents": 1999`, `"currency": "USD"`). Outline an expand/contract plan with concrete kill criteria that avoids breaking existing third-party integrators.

??? note "Solution"
    1. **Expand:** Add optional `"amount_cents"` and `"currency"` alongside `"amount"` in OpenAPI and server responses (dual-write); accept either form on requests (dual-read) with strict consistency validation if both are provided.
    2. **Migrate:** Publish deprecation headers (`Deprecation` / `Sunset`) and a changelog notifying integrators; instrument per-client metrics tracking requests still omitting `"amount_cents"` or pinning `v1`.
    3. **Contract:** Once kill criteria are met (e.g., 0% requests relying on float `"amount"` for 30 days after the announced sunset date, or cutover to `/v2/charges`), retire the legacy `"amount"` field.

2. **URL vs. media-type versioning:** Compare `/v2/orders` URL versioning against `Accept: application/vnd.api.v2+json` header versioning for a third-party developer API. What is one advantage and one drawback of each?

??? note "Solution"
    - **URL versioning (`/v2/orders`):** *Advantage:* Immediately visible in logs, browser address bars, caching proxies, and simple `curl` calls. *Drawback:* Breaks strict URI permanence when the same underlying resource changes URL across versions.
    - **Media-type versioning (`Accept` header):** *Advantage:* Preserves canonical resource URIs and supports per-representation negotiation (including optional binary formats). *Drawback:* Harder to inspect casually, easier for misconfigured CDNs/caches to ignore without proper `Vary: Accept` headers, and higher friction for basic clients.

3. **Contract vs. implementation separation:** A Python FastAPI service switches its JSON serializer from stdlib `json` to `orjson` while keeping its OpenAPI 3 schema unchanged. Does this require bumping the public API version? What edge cases should still be checked?

??? note "Solution"
    No API version bump is required because the external RFC 8259 JSON contract has not changed. However, verify subtle serializer differences before deployment—such as `NaN`/`Infinity` handling (`orjson` rejects non-standard `NaN` whereas Python `json` allows it by default), datetime/UUID formatting, and float precision—using contract tests and [Dashboard · Compliance](../../dashboard/index.html#compliance).

---

## References

[^1]: OpenAPI Initiative. *OpenAPI Specification (OAS 3.1)*. <https://spec.openapis.org/oas/latest.html>
[^2]: Wright, A., Andrews, H., Hutton, B., & Dennis, G. (2022). *JSON Schema: A Media Type for Describing JSON Documents*. <https://json-schema.org/specification>
[^3]: Kleppmann, M. (2017). *Designing Data-Intensive Applications*, Chapter 4. O'Reilly Media.
[^4]: Fielding, R., Nottingham, M., & Reschke, J. (2022). *HTTP Semantics (§12 Content Negotiation)*. IETF RFC 9110. <https://www.rfc-editor.org/rfc/rfc9110#section-12>
