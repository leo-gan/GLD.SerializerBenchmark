# Case study: event backbone

> A multi-producer, multi-consumer event log must evolve for years. What serialization and control plane fit?

## Context and goals

**Setting:** Commerce platform. Producers run in Java and Go (conceptually: any of the suite languages). Consumers include search index, analytics, fraud, and third-party webhooks (webhooks leave the backbone via a bridge). Events are business facts such as `OrderPlaced` and `PaymentCaptured`, retained for months. Each service deploys on its own cadence.

**Goals:**

- Rolling upgrades without stop-the-world schema freezes.
- Independent producer and consumer versions.
- A clear compatibility policy.
- Analytics can export to a lake without using the event codec as the lake format ([row vs columnar](row-vs-columnar.md)).

## Non-goals and hard constraints

- This is not per-request public REST ([public REST case](case-public-rest-api.md)).
- This is not single-binary native dumps ([trust boundaries](trust-boundaries.md)).
- Consumers must not all deploy in lockstep with producers.

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. Avro plus schema registry** | Resolution culture; compatibility modes on subjects |
| **B. Protobuf plus registry or process** | Field-number culture; file or registry of descriptors; continuous-integration breaks |
| **C. JSON events plus conventions** | JSON bodies; organization schema docs; optional JSON Schema |
| **D. Mixed per team** | Each producer picks its own encoding |

## Trade-off matrix

| Axis | A. Avro + registry | B. Protobuf + process | C. JSON events | D. Mixed |
|------|--------------------|-----------------------|----------------|----------|
| Independent versioning | Strong (resolution) | Strong if process holds | Weak unless strict | Chaos |
| Compatibility gates | First-class modes | Breaking-change CI plus policy | Manual process or schema store | None |
| Multi-language | Good in data ecosystems | Excellent code-generation story | Excellent | Accidental |
| Debug | Tooling required | Tooling required | Easy | Varies |
| Operations cost | Registry high availability plus subjects | IDL ownership | Low tooling, high drift risk | Highest long-term |
| Lake story | Row events compact to columnar | Same | Same | Painful |

## Recommendation (under these constraints)

**Prefer A or B with an explicit culture**—do not half-adopt both ([two schema cultures](two-schema-cultures.md)):

- Choose **A (Avro-class plus registry)** when the organization already centers on registry-enforced compatibility and data-platform tooling.
- Choose **B (Protobuf-class)** when an IDL monorepo and code generation already dominate and event schemas can live beside RPC protos with the same discipline.

**Use C** only for low-stakes or early-stage streams with a **written** schema process and acceptance of JSON size costs. Plan a migration path before high fan-out.

**Reject D** immediately; it fails [polyglot estates](polyglot-estates.md).

Bridge **webhooks** to JSON at the edge; do not force external parties to speak the internal event codec.

Compact to **columnar** lake formats in batch; do not treat the event codec as the analytics store.

## Experiments

**Question:** Under rolling deploy, which **schema culture, registry mode, and codec** keep consumers live on the event backbone?

### Setup

1. Multi-service producers and consumers; a registry is available.
2. A rolling deploy plan; sample additive and breaking schema events.
3. Broker lag and dead-letter queue metrics.

### Procedure

1. Choose culture ([two schema cultures](two-schema-cultures.md)) and compatibility mode.
2. Dry-run schema registration accept and reject cases.
3. Canary a producer with an additive field; watch consumer errors and lag.
4. Attempt a break; confirm reject or a controlled dual-run ([versioning](versioning-in-the-wild.md)).
5. Use suite size and speed only for capacity planning of the chosen stack.

### Decision rule

- Prefer an enforceable registry mode and a culture that matches deploy order.
- Speed cannot override a failed compatibility experiment.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| Compatibility pass or fail | **Primary** |
| Consumer lag and error rate on canary | Production safety |
| Dead-letter queue rate | Poison messages and schema skew |
| Dual-run duration versus kill criteria | Migration health |
| Suite size and serialize time | Capacity planning |
| Matrix interop if polyglot | Estate fit |

## What would change the answer

- A single producer team with lockstep deploys can use a simpler process; a registry may be overkill, but a portable format is still required.
- A pure analytics firehose with no service consumers prefers lake-oriented design earlier.
- Extreme debug pressure and low volume may allow JSON events with a strict schema temporarily.

## Key takeaways

- Event backbones need a **schema culture plus enforcement**, not only a codec brand.
- Avro-class and Protobuf-class both work; **mixing cultures without tooling** does not.
- Suite timings choose implementations; **compatibility policy** chooses the system.
- Keep lake columnar conversion as a **deliberate pipeline**, not the consumer’s problem alone.
