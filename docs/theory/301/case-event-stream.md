# Case study: event backbone

> A multi-producer, multi-consumer event log must evolve for years. What serialization and control plane fit?

An **event backbone** is a durable stream of business facts. One example is `OrderPlaced`. Many services publish to it and subscribe from it. Unlike a single RPC hop, producers and consumers deploy independently. Messages may be retained for months. This case study focuses on schema culture and enforcement while services are updated gradually so old and new versions run at the same time.

---

## Context and goals

**Setting:** Commerce platform. Producers run in Java and Go. Conceptually, any of the suite languages can appear. Consumers include search index, analytics, fraud, and third-party webhooks. Webhooks leave the backbone via a bridge. Events are business facts such as `OrderPlaced` and `PaymentCaptured`. They are retained for months. Each service deploys on its own cadence.

A **webhook** is an HTTP callback to an external system. External parties usually should not be forced to speak your internal event codec.

**Goals:**

- Gradual upgrades (old and new versions running together) without stop-the-world schema freezes.
- Independent producer and consumer versions.
- A clear compatibility policy.
- Analytics can export to a lake without using the event codec as the lake format. See [row vs columnar](row-vs-columnar.md).

---

## Non-goals and hard constraints

- This is not per-request public REST. See [public REST case](case-public-rest-api.md).
- This is not single-binary native dumps. See [trust boundaries](trust-boundaries.md).
- Consumers must not all deploy in lockstep with producers.

In other words, the control plane must make independent evolution safe. It must not hope that everyone deploys together.

---

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. Avro plus schema registry** | Resolution culture; compatibility modes on subjects |
| **B. Protobuf plus registry or process** | Field-number culture; file or registry of descriptors; continuous-integration breaks |
| **C. JSON events plus conventions** | JSON bodies; organization schema docs; optional JSON Schema |
| **D. Mixed per team** | Each producer picks its own encoding |

---

## Trade-off matrix

| Axis | A. Avro + registry | B. Protobuf + process | C. JSON events | D. Mixed |
|------|--------------------|-----------------------|----------------|----------|
| Independent versioning | Strong (resolution) | Strong if process holds | Weak unless strict | Chaos |
| Compatibility gates | First-class modes | Breaking-change CI plus policy | Manual process or schema store | None |
| Multi-language | Good in data ecosystems | Excellent code-generation story | Excellent | Accidental |
| Debug | Tooling required | Tooling required | Easy | Varies |
| Operations cost | Registry high availability plus subjects | IDL ownership | Low tooling, high drift risk | Highest long-term |
| Lake story | Row events compact to columnar | Same | Same | Painful |

This matters because picking a codec brand without an evolution culture is dangerous. That is how event platforms accumulate silent breaks.

---

## Recommendation (under these constraints)

**Prefer A or B with an explicit culture.** Do not half-adopt both. See [two schema cultures](two-schema-cultures.md):

- Choose **A (Avro-class plus registry)** when the organization already centers on registry-enforced compatibility and data-platform tooling.
- Choose **B (Protobuf-class)** when one shared IDL code repository for many projects and code generation already dominate. Event schemas can live beside RPC protos with the same discipline.

**Use C** only for low-stakes or early-stage streams with a **written** schema process. Accept JSON size costs. Plan a migration path before one message is delivered to many consumers (*high fan-out*).

**Reject D** immediately. It fails [multi-language systems (polyglot estates)](polyglot-estates.md).

Bridge **webhooks** to JSON at the edge. Do not force external parties to speak the internal event codec.

Compact to **columnar** lake formats in batch. Do not treat the event codec as the analytics store.

---

## Experiments

**Question:** Under gradual updates (old and new versions running together), which **schema culture, registry mode, and codec** keep consumers live on the event backbone?

### Setup

1. Multi-service producers and consumers. A registry is available.
2. A gradual update plan. Sample additive and breaking schema events.
3. Broker lag and dead-letter queue metrics.

### Procedure

1. Choose culture. See [two schema cultures](two-schema-cultures.md). Choose a compatibility mode.
2. Dry-run schema registration accept and reject cases.
3. Canary a producer with an additive field. Watch consumer errors and lag.
4. Attempt a break. Confirm reject or a controlled dual-run. See [versioning](versioning-in-the-wild.md).
5. Use suite size and speed only for capacity planning of the chosen stack.

### Decision rule

- Prefer an enforceable registry mode and a culture that matches deploy order.
- Speed cannot override a failed compatibility experiment.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| Compatibility pass or fail | **Primary** |
| Consumer lag and error rate on canary | Production safety |
| Dead-letter queue rate | Poison messages and schema skew |
| Dual-run duration versus kill criteria | Migration health |
| Suite size and serialize time | Capacity planning |
| Matrix interop if multi-language (polyglot) | Fit for the set of systems the organization runs |

---

## What would change the answer

- A single producer team with lockstep deploys can use a simpler process. A registry may be overkill. A portable format is still required.
- A pure analytics firehose with no service consumers prefers lake-oriented design earlier.
- Extreme debug pressure and low volume may allow JSON events with a strict schema temporarily.

---

## Key takeaways

- Event backbones need a **schema culture plus enforcement**. A codec brand alone is not enough.
- Avro-class and Protobuf-class both work. **Mixing cultures without tooling** does not.
- Suite timings choose implementations. **Compatibility policy** chooses the system.
- Keep lake columnar conversion as a **deliberate pipeline**. Do not leave it as the consumer’s problem alone.
