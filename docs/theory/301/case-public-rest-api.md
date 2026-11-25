# Case 1: Public REST API

> **Design brief:** A B2B HTTPS API serves browser applications, mobile apps, and third-party partner integrators with business documents (orders, accounts). Latency and payload size are rising, yet external contracts must remain human-inspectable and stable for years.

---

## Scenario and Hard Constraints

- **Clients:** Browser SPAs, iOS/Android apps, and external partner integrations outside the company's release cadence.
- **Operations:** Support and on-call teams inspect traffic using `curl`, HTTP logs, and API documentation.
- **Hard constraints:**
  - External integrators cannot be required to install `protoc` or compile generated binary stubs.
  - All requests cross an untrusted public boundary: language-native codecs are forbidden ([3.1 Trust boundaries](trust-boundaries.md)), and strict size, depth, and error-redaction controls apply ([3.2 Untrusted input and payload surfaces](untrusted-input.md)).
  - Bulk historical exports are out of scope for transactional CRUD endpoints ([3.5 Row vs. columnar](row-vs-columnar.md)).

---

## Candidate Options and Trade-Offs

| Dimension | A. JSON + Hard Schema Contract | B. Dual Stack (JSON Default + Optional Binary via `Accept`) | C. Binary-Only Public API |
|---|---|---|---|
| **Integrator friction** | Lowest (universal tooling) | Medium (two encodings to document and test) | Highest (requires client SDKs/IDL) |
| **Debugging & support** | Direct (`curl`, readable logs) | Good if JSON stays default | Requires specialized decoder tooling |
| **Evolution governance** | OpenAPI / JSON Schema + CI diffing | Must version and verify *both* wire surfaces | IDL breaking-change CI |
| **Performance headroom** | Bounded by server JSON library & payload shape | Binary escape hatch for heavy clients | Best raw size and CPU |
| **Operational complexity** | Low | Medium (content negotiation, dual contract tests) | Medium–high (support burden) |

---

## Recommended Architecture

1. **Default to Option A (JSON + OpenAPI / JSON Schema):** Publish a versioned schema contract enforced in CI ([3.4 Public API contracts and versioning](public-api-contracts.md)), add strict server-side input validation, and compress large responses ($\ge 1$–$2\text{ KB}$) via HTTP `Content-Encoding` ([3.10 System compression](latency-tails-and-gc.md#compression-as-system-choice)).
2. **Optimize inside JSON first:** Audit DTO bloat and select the best-performing, spec-compliant JSON library for the server language using a controlled Dashboard cell ([3.9 Implementation variance](using-this-suite.md#implementation-variance)).
3. **Earn Option B via evidence only:** Add `Accept: application/x-protobuf` negotiation *only* if profiling proves JSON serialization still breaks SLOs after library and DTO optimization *and* high-volume clients commit to adopting binary.
4. **Reject Option C** for general third-party REST APIs.

---

## Verification Plan and Suite Limits

- **Within this suite:** Filter the [Dashboard](../../dashboard/index.html) to `(Server language, JSON, Suite, document/message)` and check [Compliance](../../dashboard/index.html#compliance) to shortlist server JSON libraries.
- **Outside this suite:** Run CI OpenAPI breaking-change diffs, verify error-response redaction, and load-test server $p_{99}$ latency with HTTP compression and realistic middleware enabled.
- **What would change the answer:** First-party-only clients under your control reduce friction for Option B; multi-megabyte data exports should move to an asynchronous Parquet/CSV download endpoint rather than replacing the REST default.

---

## Discussion Prompts

1. Suppose profiling shows JSON encoding accounts for 6% of server CPU while database queries account for 70%. Would adopting Option B (dual-stack Protobuf) be justified?

??? note "Guidance"
    No. By Amdahl's law, eliminating serialization entirely could improve total CPU by at most 6%, while adding permanent dual-contract testing, content-negotiation routing, and versioning overhead. Optimize database access first.

2. A high-volume partner asks for a single `GET /orders/export` endpoint returning 500,000 orders as JSON. Should you switch the REST API to binary, or isolate that endpoint?

??? note "Guidance"
    Isolate the bulk export into an asynchronous job that writes a compressed columnar (Parquet) or NDJSON file to object storage and returns a pre-signed URL. Do not complicate low-latency CRUD endpoints to accommodate batch analytics downloads.
