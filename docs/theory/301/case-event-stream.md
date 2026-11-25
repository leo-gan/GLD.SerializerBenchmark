# Case 3: Event Backbone

> **Design brief:** A commerce platform runs a durable multi-producer, multi-consumer event log (`OrderPlaced`, `PaymentCaptured`) retained for months across Java, Go, and downstream search, fraud, analytics, and external webhook consumers deploying independently.

---

## Scenario and Hard Constraints

- **Topology:** Many independent producers and consumers on an asynchronous broker (Kafka-class); external partners receive HTTP webhooks via an edge bridge.
- **Retention and cadence:** Events remain readable for months (supporting consumer replay and backfill); lockstep producer/consumer deployments are impossible.
- **Hard constraints:**
  - Independent rolling upgrades require automated schema compatibility enforcement before deployment ([3.3 Schema cultures and registries](two-schema-cultures.md)).
  - External webhook recipients must receive a documented HTTP JSON contract rather than internal binary events.
  - Long-term analytical queries must not scan raw operational event logs ([3.5 Row vs. columnar](row-vs-columnar.md)).

---

## Candidate Options and Trade-Offs

| Dimension | A. Avro + Schema Registry | B. Protobuf + Registry / IDL CI | C. JSON Events + Schema Store | D. Team-Chosen Formats |
|---|---|---|---|---|
| **Independent evolution** | Strong (writer/reader schema resolution) | Strong if field-number rules hold strictly | Fragile unless strictly validated in CI | Unmanageable |
| **Automated compatibility gates** | Native `FULL_TRANSITIVE` / `BACKWARD_TRANSITIVE` | `buf breaking` + registry checks | Requires custom schema-diff tooling | None |
| **Multi-language tooling** | Mature in data/JVM/Go/Python platforms | Excellent static codegen everywhere | Universal | Fragmented |
| **Wire density & fan-out CPU** | High | High | Higher bandwidth and parse CPU at high fan-out | Inconsistent |
| **Operational dependency** | Registry HA & subject naming governance | Shared `.proto` repository ownership | Low tooling setup, high long-term drift risk | Severe integration debt |

---

## Recommended Architecture

1. **Commit to one schema culture—Option A or Option B—and enforce it:**
   - Choose **Option A (Avro + Schema Registry)** if the platform centers on data-engineering pipelines and registry-managed schema resolution.
   - Choose **Option B (Protobuf + shared `.proto` repo + registry/CI)** if service teams already standardize on Protobuf for internal RPC and want a single schema workflow.
2. **Enforce `FULL_TRANSITIVE` (or `BACKWARD_TRANSITIVE`) compatibility** on long-retained topics so rolling deployments and multi-month historical replays cannot break live consumers.
3. **Separate edge and lake boundaries:** Translate internal events to versioned JSON at the webhook gateway, and run a dedicated compaction pipeline into partitioned Parquet tables for analytics.
4. **Reject Option D** outright ([3.6 Multi-language systems](polyglot-estates.md)); restrict Option C to low-volume early-stage streams with a documented migration path.

---

## Verification Plan and Suite Limits

- **Within this suite:** After choosing Avro or Protobuf, compare concrete per-language libraries on the [Dashboard](../../dashboard/index.html) for capacity planning and broker batch sizing.
- **Outside this suite:** Test both valid additive changes (must pass) and intentional breaking edits (must be **rejected in CI**), canary a new producer version while tracking consumer lag and DLQ rates, and verify replay against historical messages.
- **What would change the answer:** A single producer/consumer pair deployed in lockstep needs a portable format and CI tests, not a high-availability registry cluster; a pure analytics ingestion stream with zero operational consumers can compact earlier into columnar storage.

---

## Discussion Prompts

1. Why does checking non-transitive `BACKWARD` compatibility fail on an event topic with 180-day retention?

??? note "Guidance"
    Non-transitive `BACKWARD` verifies only version $N$ against $N-1$. A sequence of pairwise-compatible edits ($v_1 \to v_2 \to v_3$) can make $v_3$ unable to read $v_1$ (for instance, deleting a field in $v_2$ and re-adding the same name with an incompatible type in $v_3$), breaking historical replays. `*_TRANSITIVE` modes validate against *all* prior versions.

2. How should an `OrderPlaced` event handle an optional 2 MB PDF invoice needed only by the billing archiver?

??? note "Guidance"
    Use the **Claim-Check pattern** ([3.7 RPC and messaging](rpc-and-messaging.md)): upload the PDF to object storage, include only its URI and SHA-256 digest in the small `OrderPlaced` event, and let the billing archiver fetch the blob asynchronously without inflating bandwidth for fraud, search, and analytics consumers.
