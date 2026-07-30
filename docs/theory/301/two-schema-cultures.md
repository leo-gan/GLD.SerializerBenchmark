# Two schema cultures: Avro vs Protobuf

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/301/two_schema_cultures.ipynb)
**Lab notebook:** [Two schema cultures experiment](../notebooks/301/two_schema_cultures.ipynb)

## Problem

Both Apache Avro and Protocol Buffers are **schema-driven**. A **schema** is a shared description of what fields a message has. It also describes what types those fields use. Teams still fail migrations because they treat “we have a schema” as if that were one single practice.

In reality, two mature **cultures** dominate industry systems. A culture here means a set of habits, tools, and rules about how change is governed. It is not just a file format.

1. **Resolution culture** (classic Avro): the writer’s schema and the reader’s schema may differ. A **resolution** algorithm fills defaults. It projects fields. It defines what counts as compatible. In other words, at read time the system may reconcile two different schema versions.
2. **Field-number culture** (classic Protobuf): field **numbers** are the stable contract. Names are mostly local documentation. Evolution means “add optional fields, never reuse numbers.” Process enforces that rule. Runtime resolution of two full schemas on every read is not the main control.

Choosing the wrong culture for your operations model breaks consumers when you update services gradually so old and new versions run at the same time (*rolling deploy*). Mixing the habits of both cultures does the same.

---

## Short answer

Use **Avro-like resolution** when producers and consumers evolve independently. Use it when schemas are published to a **registry**. A registry is a service that stores versioned schemas. It can reject incompatible ones. Use resolution culture when you want compatibility rules such as BACKWARD, FORWARD, or FULL checked as policy artifacts. Those modes describe which old and new reader and writer combinations remain legal. The [schema registries](schema-registries.md) article expands them.

Use **Protobuf-like field-number discipline** when a shared `.proto` file is the product interface. An equivalent **IDL** works the same way. **IDL** means interface definition language. It is a formal description of messages and services. Use field-number culture when code generation is central. Change control then means “reserve numbers, add fields, and fail continuous integration (CI) on incompatible edits.”

Both families can serve RPC and events. The difference is **how change is governed**. It is not a universal speed ranking.

This page assumes 201 [schema evolution](../201/schema-evolution.md) for forward and backward vocabulary. It also assumes [self-describing vs schema](../201/self-describing-vs-schema-dependent.md) for why schemas exist. Here we own **culture and operations**.

---

## Constraints that matter

| Axis | Resolution culture (Avro-class) | Field-number culture (Protobuf-class) |
|------|----------------------------------|----------------------------------------|
| **Stable identity** | Often **names** (plus namespace) in the schema | **Field numbers** on the wire |
| **Who holds schemas at read time** | Writer schema plus reader schema (from a registry or file) | Shared IDL or descriptor set agreed out of band |
| **Compatibility** | Explicit modes; resolution applies defaults | Process and lint; unknown fields are typically retained or skipped per runtime rules |
| **Tooling center of gravity** | Schema registry and subject versioning | `protoc` or buf, code generation, breaking-change detectors |
| **Typical homes** | Event logs and data-platform rows | RPC APIs and multi-language service stubs |
| **Failure style** | Resolution errors; incompatible subject versions | Reused field numbers; silent semantic overwrite |

Neither column is “more schema-driven.” Both are schema-driven with different **control planes**. A control plane is the system that decides and enforces policy. It is separate from the data plane that carries the actual messages.

---

## Decision frame

| If you need… | Lean toward |
|--------------|-------------|
| Many producer versions, long-lived topics, and registry gates in CI/CD | Resolution culture (Avro-class or equivalent) |
| Strong multi-language stubs, one IDL repository, and an RPC-first design | Field-number culture (Protobuf-class) |
| Data lake or analytics row encoding with schema evolution | Often Avro-class (or columnar formats—see [row vs columnar](row-vs-columnar.md)) |
| Public HTTP with human-readable JSON | Neither culture alone—JSON plus an external contract such as OpenAPI or JSON Schema; a dual stack is possible |
| “We already standardized on protos for RPC” | Stay with field-number culture; do not invent ad-hoc resolution without tooling |
| “We already run a schema registry for Kafka” | Stay with resolution culture; do not ignore the compatibility mode |

```text
  Independent producer/consumer versions + a registry?
        yes → resolution culture
        no  → shared IDL + field-number discipline
              (you still need CI for breaking changes)
```

This matters because culture is an operations choice. Picking Avro “because Kafka” without a compatibility mode recreates outages. Picking Protobuf “because gRPC” while reusing field numbers does the same. Each culture evolved to prevent those outages.

---

## Failure modes

| Mistake | Consequence |
|---------|-------------|
| **Reusing Protobuf field numbers** | Old readers misinterpret the new meaning—this is the worst class of silent corruption |
| **Deleting Avro fields carelessly under the wrong compatibility mode** | Consumers fail or drop data depending on the mode |
| **Rename-as-replace without dual-write** | JSON and Avro name identity breaks; Protobuf renames are safer if numbers hold, but APIs and docs still lag |
| **Registry without enforcement** | You “have Avro,” but anyone can push incompatible schemas |
| **Protobuf without ownership** | `.proto` files fork per team; numbers collide when someone merges |
| **Culture mashup** | Expecting registry-style resolution from raw Protobuf bytes without descriptors |

For example, suppose field number `3` once meant “amount in cents.” Later it means “currency code.” Old readers will treat the new bytes as a wrong amount. That is silent corruption. There is no loud error. There is wrong business data.

---

## Real-world sketch

**Events.** An orders topic uses Avro with BACKWARD compatibility. Producers deploy a new optional field. Old consumers resolve defaults. The control plane is the registry subject. It is not a merge of stubs from one shared code repository for many projects.

**RPC.** A billing API uses Protobuf. Field `3` is `amount_cents` forever. A new `currency_code` becomes field `7`. Code generation updates services that care. Old binaries ignore unknown fields according to runtime rules. The control plane is IDL review plus breaking-change CI.

Swapping habits recreates classic outages. Treating Protobuf field names as the long-term identity is one example. Deploying Avro without a compatibility mode is another. Each culture evolved to prevent those failures.

---

## In this suite

| Resource | Role |
|----------|------|
| Language **Overview** and **Results** | Where Avro, Protobuf, or similar **implementations** are registered |
| [Serialization categories](../../analysis/serialization_categories.md) | Both sit in the **schema-driven** family—do not rank cultures with a mixed chart |
| [Using this suite](using-this-suite.md) | Same language and paradigm before comparing libraries |
| 201 [schema evolution](../201/schema-evolution.md) | Mechanism vocabulary |

Suite timings compare **libraries**. They do not compare “Avro culture versus Protobuf culture” as governance systems. Use Results to pick an implementation **after** the culture fits the operations model.

---

## Experiments

**Question:** Should this system’s evolution culture be **matching a writer’s schema to a reader’s schema by rules** (Avro-like resolution) or **field-number discipline** (Protobuf-like)? Are we operating that culture consistently?

### Setup

1. List producers and consumers. Note whether a **registry** exists. Note whether a shared `.proto` or IDL repository exists.
2. Note deploy topology. Mark independent services versus lockstep deploys from one shared code repository.
3. Sample one planned schema change. Examples include add a field, rename a field, or remove a field.

### Procedure

1. Classify the current stack. Is it resolution-at-read or tag and field-id binary?
2. Walk the planned change through **both** cultures’ rules. List breakages.
3. Check whether operations actually enforce the culture. That may be a registry compatibility mode. Or it may be proto review and reserved numbers.
4. Optionally encode the same logical fixture with Avro and Protobuf implementations. Use that for **size and speed orientation only**. Do not use it for culture choice.
5. Write the chosen culture and the enforcement owner into the architecture note.

### Decision rule

- Prefer the culture your **operations team can enforce**. That may be registry modes. Or it may be IDL governance.
- Do not mix cultures on one topic without an explicit dual-stack plan.

---

## Metrics

| Metric / signal | Role |
|-----------------|------|
| **Compatibility mode** (BACKWARD / FORWARD / FULL) or **proto breaking-change policy** | **Primary** operations metric |
| Schema-change lead time and failed deploys from skew | Health of the culture |
| Registry reject rate versus silent consumer errors | Enforcement quality |
| Count of consumer languages | Pressure toward explicit contracts |
| Suite `median_size_bytes` and speed | Secondary cost of a culture’s typical stack |
| Conformance across languages ([401 fidelity](../401/protobuf-cross-language-fidelity.md) for Protobuf) | Implementation discipline |

**Conclusion style:** “The event bus uses Avro with BACKWARD registry mode; RPC uses Protobuf field-id discipline.”

---

## What this suite cannot tell you

- Which **compatibility mode** your registry should enforce.
- Whether one shared code repository for many projects can own all `.proto` files.
- How long a multi-hop dual-write must last for a rename.
- Legal retention requirements for old writer schemas used in resolution.

---

## Common mistakes

- Picking Avro “because Kafka” without choosing and enforcing a compatibility mode.
- Picking Protobuf “because gRPC” and then reusing field numbers under pressure.
- Using suite speed to choose the culture.
- Assuming JSON needs no culture. Public JSON still needs a contract process. See [public API contracts](public-api-contracts.md).

---

## Key takeaways

- There are two schema-driven cultures: **resolution** and **field-number discipline**.
- Match culture to **how producers and consumers version**. Do not match it to a brand preference alone.
- Serialization 201 explains evolution *rules*. Serialization 301 chooses the *operating model*.
- Suite evidence is for implementations inside a family. Use it after culture is fixed.
- Mixing cultures without tooling reproduces classic migration failures.
