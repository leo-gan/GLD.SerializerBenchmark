# Case 5: Cross-Language Service Boundary

> **Design brief:** A TypeScript edge gateway, a Go core API, and a Python ML feature service must share an internal feature-fetch request/response contract over a private network at moderate QPS without fragmenting into per-language dialects.

---

## Scenario and Hard Constraints

- **Participating runtimes:** TypeScript (Node.js gateway), Go (core API), Python (ML feature service).
- **Operational requirements:** Independent service deployments, human-inspectable failure diagnostics during incidents, acceptable latency at moderate QPS.
- **Hard constraints:**
  - Single-language formats (such as Python `pickle` or Go `gob`) are disqualified on any multi-language boundary ([3.1 Trust boundaries](trust-boundaries.md)).
  - External browser traffic stops at the TypeScript edge gateway; this design governs the internal three-language hop ([3.6 Multi-language systems](polyglot-estates.md)).

---

## Candidate Options and Trade-Offs

| Dimension | A. Protobuf IDL + Codegen | B. JSON + JSON Schema | C. Ad Hoc MessagePack | D. Per-Language Favorites |
|---|---|---|---|---|
| **Polyglot ecosystem** | Strong in TS, Go, Python | Universal | Good if conventions are codified | Fails interoperability |
| **Type safety & evolution** | Field numbers + `buf breaking` CI | Process-dependent; schema validation in CI | Convention-only; easy schema drift | None |
| **Wire density** | High | Lower (verbose text keys) | Medium–high | Not meaningful |
| **Incident debugging** | Requires descriptor CLI | Direct human inspection | Requires decoder CLI | Opaque |
| **Main operational risk** | Shared `.proto` repository ownership | Payload verbosity and 64-bit int edge cases | Undocumented array-vs-map dialects | Quadratic translation debt |

---

## Recommended Architecture

1. **Choose Option A (Protobuf + shared `.proto` repo)** if the organization will maintain a central IDL repository with CI breaking-change gates across TypeScript, Go, and Python ([3.3 Schema cultures](two-schema-cultures.md)).
2. **Choose Option B (JSON + strict JSON Schema)** if moderate QPS leaves ample CPU/bandwidth headroom and incident debuggability outweighs wire compactness—enforcing explicit rules for 64-bit integers (as strings for TypeScript safety), timestamps, and nullability ([3.4 Public API contracts](public-api-contracts.md)).
3. **Allow Option C** only with written key/type conventions and automated cross-language contract tests; **reject Option D** immediately.
4. **Pin libraries locally per language** using the Dashboard *after* the shared contract and interoperability matrix pass ([3.9 Implementation variance](using-this-suite.md#implementation-variance)).

---

## Verification Plan and Suite Limits

- **Within this suite:** Once the standard (Protobuf or JSON) is fixed, inspect separate TypeScript/JavaScript, Go, and Python Dashboard cells to shortlist concrete libraries—never use cross-language speed rankings to dictate the wire format.
- **Outside this suite:** Build a $3 \times 3$ CI **interoperability matrix** (encode canonical edge-case records in each language, decode in all three, assert logical equality; see [4.7 Cross-language fidelity](../401/protobuf-cross-language-fidelity.md)), verify `serializer_version` lockfiles, and load-test per-language $p_{99}$ latency.
- **What would change the answer:** Extreme QPS or tight $p_{99}$ budgets favor Option A plus concurrent load testing ([3.10 Latency tails](latency-tails-and-gc.md)); exposing the hop directly to external third-party integrators favors Option B.

---

## Discussion Prompts

1. Why is `mean_fidelity = 1.0` for TypeScript, Go, and Python individually on the Dashboard insufficient to approve this boundary for production?

??? note "Guidance"
    Per-language `mean_fidelity` tests only the diagonal of the $3 \times 3$ matrix (TS $\to$ TS, Go $\to$ Go, Python $\to$ Python). Cross-language defects—such as JavaScript `Number` truncation of Go `int64` IDs, Protobuf default-value omission, or map vs. array encoding in MessagePack—appear only on off-diagonal cells ($L_i \to L_j,\ i \ne j$).

2. If the Python ML team complains that Protobuf parsing in pure Python is slow on a 5,000-element feature vector, what should they investigate before proposing a separate format for Python?

??? note "Guidance"
    Check **implementation variance within Protocol Buffers** on the Python Dashboard first (e.g., C/upb-backed `protobuf` vs. `betterproto` vs. `pb-upb`) and inspect whether the feature payload shape itself (e.g., packed repeated floats vs. nested map entries) is creating avoidable allocation overhead.
