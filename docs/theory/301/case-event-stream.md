# Case study: event backbone

> A multi-producer, multi-consumer event log must evolve for years—what serialization and control plane fit?

## Context & goals

**Setting:** Commerce platform. Producers in Java/Go (conceptually: any of the suite languages), consumers for search index, analytics, fraud, and third-party webhooks (webhooks leave the backbone via a bridge). Events are business facts (`OrderPlaced`, `PaymentCaptured`) retained for months. Independent deploy cadence per service.

**Goals:**

- Rolling upgrades without stop-the-world schema freezes.  
- Independent producer/consumer versions.  
- Clear compatibility policy.  
- Analytics can export to a lake without using the event codec as the lake format ([row vs columnar](row-vs-columnar.md)).

## Non-goals / hard constraints

- Not per-request public REST ([public REST case](case-public-rest-api.md)).  
- Not single-binary native dumps ([trust boundaries](trust-boundaries.md)).  
- Consumers must not all deploy in lockstep with producers.

## Options on the table

| Option | Sketch |
|--------|--------|
| **A. Avro + schema registry** | Resolution culture; compatibility modes on subjects |
| **B. Protobuf + registry/process** | Field-number culture; file/registry of descriptors; CI breaks |
| **C. JSON events + conventions** | JSON bodies; org schema docs; optional JSON Schema |
| **D. Mixed per team** | Each producer picks its own encoding |

## Trade-off matrix

| Axis | A. Avro + registry | B. Protobuf + process | C. JSON events | D. Mixed |
|------|--------------------|-----------------------|----------------|----------|
| Independent versioning | Strong (resolution) | Strong if process holds | Weak unless strict | Chaos |
| Compatibility gates | First-class modes | Breaking-change CI + policy | Manual / schema store | None |
| Multi-language | Good in data ecosystems | Excellent codegen story | Excellent | Accidental |
| Debug | Tooling | Tooling | Easy | Varies |
| Ops cost | Registry HA + subjects | IDL ownership | Low tooling, high drift risk | Highest long-term |
| Lake story | Row events → compact to columnar | Same | Same | Painful |

## Recommendation (under these constraints)

**Prefer A or B with an explicit culture**—do not half-adopt both ([two schema cultures](two-schema-cultures.md)):

- Choose **A (Avro-class + registry)** when the org already centers on registry-enforced compatibility and data-platform tooling.  
- Choose **B (Protobuf-class)** when IDL monorepo + codegen already dominate and event schemas can live beside RPC protos with the same discipline.

**Use C** only for low-stakes or early-stage streams with a **written** schema process and size budget acceptance—plan a migration path before high fan-out.

**Reject D** immediately; it fails [polyglot estates](polyglot-estates.md).

Bridge **webhooks** to JSON at the edge; do not force external parties to speak the internal event codec.

Compact to **columnar** lake formats in batch; do not treat the event codec as the analytics store.



## Experiments

**Question:** Event backbone under rolling deploy—which **schema culture + registry mode + codec** keeps consumers live?

### Setup
1. Multi-service producers/consumers; registry available.  
2. Rolling deploy plan; sample additive and breaking schema events.  
3. Broker lag/DLQ metrics.

### Procedure
1. Choose culture ([two schema cultures](two-schema-cultures.md)) and compatibility mode.  
2. Dry-run schema register accept/reject.  
3. Canary producer with additive field; watch consumer errors/lag.  
4. Attempt break; confirm reject or controlled dual-run ([versioning](versioning-in-the-wild.md)).  
5. Suite size/speed only for capacity of chosen stack.

### Decision rule
- Prefer enforceable registry mode + culture that matches deploy order.  
- Speed cannot override failed compatibility experiment.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| Compatibility pass/fail | **Primary** |
| Consumer lag / error rate on canary | Production safety |
| DLQ rate | Poison/schema skew |
| Dual-run duration vs kill criteria | Migration health |
| Suite size / ser time | Capacity planning |
| Matrix interop if polyglot | Estate fit |

## What would change the answer

- Single producer team, lockstep deploys → simpler process; registry may be overkill but portable format still required.  
- Pure analytics firehose with no service consumers → prefer lake-oriented design earlier.  
- Extreme debug pressure and low volume → JSON events with strict schema may suffice temporarily.

## Key takeaways

- Event backbones need a **schema culture + enforcement**, not only a codec brand.  
- Avro-class and Protobuf-class both work; **mixing cultures without tooling** does not.  
- Suite timings choose implementations; **compatibility policy** chooses the system.  
- Keep lake columnar conversion as a **deliberate pipeline**, not the consumer’s problem alone.
