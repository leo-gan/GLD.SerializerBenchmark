# 3.3 Schema Cultures and Registries

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/two_schema_cultures.ipynb)

## Problem Statement

Both Apache Avro and Protocol Buffers are schema-driven binary formats, yet teams routinely suffer migration outages because they treat "having a schema" as a single operational practice. In production, schema-driven systems divide into **two distinct governance cultures**[^4]—and neither succeeds without an automated **control plane** (a schema registry or CI breaking-change gate) that rejects incompatible updates before deployment.

Building on the wire-level evolution rules in [2.5 Schema evolution](../201/schema-evolution.md), this chapter compares the operational control planes of both cultures and formalizes compatibility-mode selection.

---

## Two Schema Cultures: Resolution vs. Field-Number Discipline

| Dimension | Resolution Culture (Avro-Class)[^1] | Field-Number Culture (Protobuf-Class)[^2] |
|---|---|---|
| **Canonical field identity** | Field **name** (plus namespace and explicit aliases) | Small integer **field number** on the wire |
| **Schemas present at decode** | Both exact **writer schema** (header or registry ID) and **reader schema** | Reader's compiled descriptors; unknown tags skipped by wire type |
| **Compatibility mechanism** | Runtime schema resolution fills defaults, projects fields, and applies aliases | Static IDL discipline: add optional fields, never reuse deleted numbers (`reserved`) |
| **Tooling center of gravity** | Schema Registry enforcing subject compatibility modes | Shared `.proto` repository + `protoc` / `buf breaking` CI gates |
| **Primary production home** | Multi-year event streams (Kafka), data-platform pipelines | Synchronous multi-language RPC (gRPC), shared internal APIs |
| **Worst failure mode** | Unenforced registry mode causing consumer resolution exceptions | Reusing a retired field number, causing **silent semantic corruption** |

Both architectures can carry RPC and event traffic; the decisive criterion is **which control plane the organization can enforce reliably**:

- **Choose resolution culture (Avro + registry)** when many producers and consumers evolve independently over long-retained topics and an operational schema registry governs every subject.
- **Choose field-number culture (Protobuf + IDL CI)** when a central IDL repository and cross-language code generation already anchor service interfaces, with automated breaking-change checks blocking reused numbers or incompatible type edits in CI.

Do not mix habits across cultures: deploying Avro without an enforced compatibility mode, or treating Protobuf source field names as stable identifiers while reusing numbers, reproduces outages that each culture was explicitly designed to prevent.

---

## Schema Registries and Compatibility Modes {#schema-registries}

!!! note "Definition: Schema Registry"
    A **schema registry** is a versioned control-plane service (or equivalent CI enforcement pipeline over a canonical schema repository) that stores schemas under named subjects, assigns immutable schema IDs, and **rejects** candidate revisions that violate the subject's declared compatibility policy.

Compatibility modes encode **who may upgrade first** and **how far back historical payloads must remain readable**:[^3]

| Compatibility Mode | Protects | Upgrade Order Implied | Typical Safe Operations |
|---|---|---|---|
| **BACKWARD** | Newer readers reading data from version $N-1$ | Upgrade **consumers first**, then producers | Delete fields; add optional fields with defaults |
| **FORWARD** | Older readers (version $N-1$) reading data from newer writers | Upgrade **producers first**, then consumers | Add fields (ignored by old readers); delete optional fields |
| **FULL** | Both directions between $N$ and $N-1$ | Producers and consumers upgrade in **any order** | Intersection of BACKWARD and FORWARD (add/remove optional fields with defaults only) |
| **`*_TRANSITIVE`** | Compatibility across **all** prior registered versions ($1 \dots N-1$), not just $N-1$ | Required for long-retained event logs and full topic replay | Same rules enforced transitively against every historical version |

### Selecting a Mode from Deployment Topology

```text
  Must new consumers replay older historical data (lag, multi-month retention)?
        yes → BACKWARD_TRANSITIVE (or FULL_TRANSITIVE if old consumers remain live)
  Must old consumers survive new producers before consumers upgrade?
        yes → FORWARD (or FULL / FULL_TRANSITIVE for rolling deploys)
  Strict lockstep deploy of a single producer/consumer pair?
        → still version schemas in CI; non-transitive BACKWARD is typically sufficient
```

A registry that merely documents schemas without blocking incompatible builds in CI/CD—or lacks write ACLs so engineers can bypass checks manually—provides documentation rather than safety. Checking only $N$ against $N-1$ on a six-month Kafka topic leaves consumers exposed whenever replay hits version $N-5$.

---

## Governance Verification and Benchmark Limits

Before deploying a schema-driven topic or RPC interface, verify the control plane:

1. **Declare one culture and owner:** Document whether each boundary uses registry resolution or IDL breaking-change CI, and who may approve subject updates.
2. **Test negative cases in CI:** Register one valid additive change (must pass) and one intentional breaking change—such as reusing a Protobuf field number or adding a required Avro field without a default (must be **rejected automatically**).
3. **Validate canary rollout:** Deploy a canary producer or consumer under the chosen mode and monitor deserialization error rates, consumer lag, and dead-letter queue volume.
4. **Select libraries second:** Only after the culture and standard are fixed, use the [Dashboard](../../dashboard/index.html) (filtering to that exact language, standard, data set, and data type) to select and pin concrete Avro or Protobuf implementations.

**Limits of this benchmark suite:** Dashboard timings compare concrete library implementations (`fastavro`, `hamba/avro`, `prost`, `protobuf-java`, etc.), not governance control planes. Registry HA topology, subject naming conventions (topic-name vs. record-name strategy), and multi-month historical schema retention lie outside single-node codec benchmarks.

---

## Exercises

1. **Mode selection under replay:** A Kafka payments topic retains events for 180 days, and analytics consumers regularly reset offsets to replay the full 180-day history while new producer deployments roll out independently of live fraud consumers. Which compatibility mode is required, and why is non-transitive `BACKWARD` insufficient?

??? note "Solution"
    **`FULL_TRANSITIVE`** is required. Independent rolling deploys require *both* backward compatibility (new consumers reading old messages) and forward compatibility (live old fraud consumers reading new producer messages). Because analytics replays 180 days of history containing many historical schema versions ($N-2, N-3, \dots$), non-transitive `BACKWARD` (which checks only $N$ vs. $N-1$ and omits forward checks) leaves both live old consumers and deep historical replays vulnerable to failure.

2. **Silent vs. loud failure:** Contrast what happens in production when an engineer *(a)* reuses deleted Protobuf field number `3` with a new `int64` meaning versus *(b)* attempts to register an incompatible Avro field deletion against a `FULL_TRANSITIVE` registry in CI.

??? note "Solution"
    - *(a)* Old Protobuf readers parse the new field `3` bytes under the old semantic meaning with **no parse error** (silent business-data corruption if wire types match).
    - *(b)* The schema registry **fails the CI check loudly before deployment**, preventing broken bytes from ever reaching the topic.

3. **Benchmark misinterpretation:** Suppose Avro encodes 15% slower than Protocol Buffers in one language's Dashboard slice on `suite/document`. Should an organization running a Kafka + Avro registry platform migrate its entire event backbone to Protocol Buffers based on that chart?

??? note "Solution"
    No. A 15% single-node encode gap is minor compared with the operational cost of migrating governance tooling, schemas, and dozens of consumer pipelines across schema cultures. If encode CPU genuinely threatens an SLO, profile first and check whether a faster Avro implementation or payload simplification resolves the bottleneck within the existing culture.

---

## References

[^1]: Apache Software Foundation. *Apache Avro Specification (§ Schema Resolution)*. <https://avro.apache.org/docs/>
[^2]: Protocol Buffers Documentation. *Style Guide and Updating Message Types*; Buf Breaking Change Detector (<https://buf.build/docs/breaking/overview/>).
[^3]: Confluent Documentation. *Schema Evolution and Compatibility*. <https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html>
[^4]: Kleppmann, M. (2017). *Designing Data-Intensive Applications*, Chapter 4. O'Reilly Media.
