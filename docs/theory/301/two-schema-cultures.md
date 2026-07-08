# Two schema cultures: Avro vs Protobuf

## Problem

Both Apache Avro and Protocol Buffers are **schema-driven**. Teams still fail migrations because they treat “we have a schema” as one practice. In reality, two mature cultures dominate industry systems:

1. **Resolution culture** (classic Avro): writer and reader schemas may differ; a **resolution** algorithm fills defaults, projects fields, and defines compatibility.  
2. **Field-number culture** (classic Protobuf): field **numbers** are the stable contract; names are local; evolution is “add optional fields, never reuse numbers,” enforced by process more than by runtime resolution of two full schemas on every read.

Choosing the wrong culture for the ops model—or mixing habits—breaks consumers under rolling deploy.

## Short answer

Use **Avro-like resolution** when producers and consumers evolve independently, schemas are published to a **registry**, and you want compatibility rules (BACKWARD / FORWARD / FULL) checked as policy artifacts. Use **Protobuf-like field-number discipline** when a shared `.proto` (or equivalent IDL) is the product interface, codegen is central, and change control is “reserve numbers, additive fields, CI breaks on incompatible edits.” Both can serve RPC and events; the difference is **how change is governed**, not a universal speed ranking.

Assumes 201: [schema evolution](../201/schema-evolution.md) for forward/backward vocabulary; [self-describing vs schema](../201/self-describing-vs-schema-dependent.md) for why schemas exist. This page owns **culture and operations**.

## Constraints that matter

| Axis | Resolution culture (Avro-class) | Field-number culture (Protobuf-class) |
|------|----------------------------------|----------------------------------------|
| **Stable identity** | Often **names** (+ namespace) in schema | **Field numbers** on the wire |
| **Who holds schemas at read** | Writer schema + reader schema (registry/file) | Shared IDL / descriptor set agreed out of band |
| **Compatibility** | Explicit modes; resolution applies defaults | Process + lint; unknown fields typically retained/skipped per rules |
| **Tooling center of gravity** | Schema registry, subject versioning | `protoc`/buf, codegen, breaking-change detectors |
| **Typical homes** | Event logs, data platform rows | RPC APIs, multi-language service stubs |
| **Failure style** | Resolution errors; incompatible subject versions | Reused field numbers; silent semantic overwrite |

Neither column is “more schema-driven.” Both are schema-driven with different **control planes**.

## Decision frame

| If you need… | Lean toward |
|--------------|-------------|
| Many producer versions, long-lived topics, registry gates in CI/CD | Resolution culture (Avro-class or equivalent) |
| Strong multi-language stubs, one IDL repo, RPC-first | Field-number culture (Protobuf-class) |
| Data lake / analytics row encoding with schema evolution | Often Avro-class (or columnar formats—see row vs columnar) |
| Public HTTP with human JSON | Neither alone—JSON + external contract (OpenAPI/JSON Schema); dual stack possible |
| “We already standardized on protos for RPC” | Stay field-number; do not invent ad-hoc resolution without tooling |
| “We already run a schema registry for Kafka” | Stay resolution; do not ignore compatibility mode |

```text
  Independent producer/consumer versions + registry?
        yes → resolution culture
        no  → shared IDL + field-number discipline
              (still need CI for breaks)
```

## Failure modes

| Mistake | Consequence |
|---------|-------------|
| **Reuse Protobuf field numbers** | Old readers misinterpret new meaning; worst class of silent corruption |
| **Delete Avro fields carelessly under wrong compatibility mode** | Consumers fail or drop data depending on mode |
| **Rename-as-replace without dual-write** | JSON/Avro name identity breaks; Protobuf renames are safer if numbers hold—but APIs and docs lag |
| **Registry without enforcement** | “We have Avro” but anyone can push incompatible schemas |
| **Protobuf without ownership** | `.proto` forks per team; numbers collide when merged |
| **Culture mashup** | Expecting registry-style resolution from raw Protobuf bytes without descriptors |

## Real-world sketch

**Events:** an orders topic uses Avro with BACKWARD compatibility. Producers deploy a new optional field; old consumers resolve defaults. The control plane is the registry subject, not a monorepo merge of stubs.

**RPC:** a billing API uses Protobuf. Field `3` is `amount_cents` forever. A new `currency_code` becomes field `7`. Codegen updates services that care; old binaries ignore unknown fields per runtime rules. The control plane is the IDL review + breaking-change CI.

Swapping habits—treating Protobuf field names as the long-term identity, or deploying Avro without a compatibility mode—recreates the outages each culture evolved to prevent.

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** / **Results** | Where Avro, Protobuf, or similar **implementations** are registered |
| [Serialization categories](../../analysis/serialization_categories.md) | Both sit in **schema-driven** family—do not rank cultures by a mixed chart |
| [Using this suite](using-this-suite.md) | Same language + paradigm before comparing libraries |
| 201 [schema evolution](../201/schema-evolution.md) | Mechanism vocabulary |

Suite timings compare **libraries**, not “Avro culture vs Protobuf culture” as governance systems. Use Results to pick an implementation **after** the culture fits the ops model.


## Experiments

**Question:** Should this system’s evolution culture be **writer-schema resolution** (Avro-like) or **field-number discipline** (Protobuf-like)—and are we operating it consistently?

### Setup
1. List producers, consumers, and whether a **registry** or shared `.proto`/IDL repo exists.  
2. Note deploy topology: independent services vs monorepo lockstep.  
3. Sample one planned schema change (add field, rename, remove).

### Procedure
1. Classify current stack: resolution-at-read vs tag/field-id binary.  
2. Walk the planned change through **both** cultures’ rules; list breakages.  
3. Check whether ops actually enforce the culture (registry compatibility mode vs proto review + reserved).  
4. Suite optional: same logical fixture encoded by Avro vs Protobuf implementations for **size/speed orientation only**—not culture choice.  
5. Write the chosen culture + enforcement owner into the architecture note.

### Decision rule
- Prefer the culture your **ops can enforce** (registry modes vs IDL governance).  
- Do not mix cultures on one topic without an explicit dual-stack plan.

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Compatibility mode** (BACKWARD/FORWARD/FULL) or **proto breaking-change policy** | **Primary** ops metric |
| Schema-change lead time / failed deploys from skew | Health of the culture |
| Registry reject rate vs silent consumer errors | Enforcement quality |
| Consumer languages count | Pressure toward explicit contracts |
| Suite `median_size_bytes` / speed | Secondary cost of a culture’s typical stack |
| Conformance across languages ([401 fidelity](../401/protobuf-cross-language-fidelity.md) for Pb) | Implementation discipline |

**Conclusion style:** “Event bus uses Avro + BACKWARD registry; RPC uses Protobuf field-id discipline.”

## What this suite cannot tell you

- Which **compatibility mode** your registry should enforce.  
- Whether your monorepo can own all `.proto` files.  
- Multi-hop dual-write duration for a rename.  
- Legal retention of old writer schemas for resolution.

## Common mistakes

- Picking Avro “because Kafka” without choosing and enforcing a compatibility mode.  
- Picking Protobuf “because gRPC” then reusing field numbers under pressure.  
- Using suite speed to choose the culture.  
- Assuming JSON needs no culture—public JSON still needs a contract process (later 301 article).

## Key takeaways

- Two schema-driven cultures: **resolution** vs **field-number discipline**.  
- Match culture to **how producers and consumers version**, not to a brand preference alone.  
- 201 explains evolution *rules*; 301 chooses the *operating model*.  
- Suite evidence is for implementations inside a family—after culture is fixed.  
- Mixing cultures without tooling reproduces classic migration failures.
