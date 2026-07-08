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

## How to validate

| Step | Where |
|------|--------|
| Encode/decode cost of candidate libs **per producer language** | Language **Results**, schema-driven or JSON family |
| Compatibility matrix old×new payloads | Outside suite (registry test tooling / golden corpora) |
| Consumer lag under schema rollout | Integration environment |
| Dual-write period metrics | Product metrics, not suite |
| Fair reading of charts | [Using this suite](using-this-suite.md) |

## What would change the answer

- Single producer team, lockstep deploys → simpler process; registry may be overkill but portable format still required.  
- Pure analytics firehose with no service consumers → prefer lake-oriented design earlier.  
- Extreme debug pressure and low volume → JSON events with strict schema may suffice temporarily.

## Key takeaways

- Event backbones need a **schema culture + enforcement**, not only a codec brand.  
- Avro-class and Protobuf-class both work; **mixing cultures without tooling** does not.  
- Suite timings choose implementations; **compatibility policy** chooses the system.  
- Keep lake columnar conversion as a **deliberate pipeline**, not the consumer’s problem alone.
