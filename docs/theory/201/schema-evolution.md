# 2.5 Schema Evolution

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/schema_evolution.ipynb)

## Problem Statement

Production services and durable storage pipelines rarely upgrade atomically. During rolling deployments—and across multi-year archives or event logs—**older readers routinely decode payloads written by newer writers**, while **newer readers decode historical payloads written by older writers**.

**Schema evolution** is the discipline of modifying a data contract over time without breaking coexisting software versions. Compatibility is not a single library setting; it is the combination of a **directional compatibility policy** and wire-format rules capable of enforcing it.[^1]

---

## Directional Compatibility

!!! note "Definition: Backward, Forward, and Full Compatibility"
    - **Backward compatibility:** *Newer readers* can decode payloads emitted by *older writers* (e.g., fields missing from older bytes take documented defaults).
    - **Forward compatibility:** *Older readers* can decode payloads emitted by *newer writers* (e.g., unrecognized fields are skipped cleanly without corrupting subsequent reads).
    - **Full compatibility:** Both backward and forward compatibility hold simultaneously across a supported version window—required whenever deployments cannot guarantee strict reader-first or writer-first rollout order.

```text
  Writer v1  ──►  Reader v2   (backward compatible: v2 supplies defaults for new fields)
  Writer v2  ──►  Reader v1   (forward compatible: v1 skips unknown fields from v2)
```

For example, adding an optional field `currency_code` with default `"USD"` to `Order(order_id, total_cents)` is **fully compatible** when `v1` readers ignore unknown fields and `v2` readers substitute `"USD"` whenever `currency_code` is absent. By contrast, renaming `total_cents` to `amount_cents` without a dual-write transition window or alias breaks both directions silently.

---

## Evolution Mechanisms by Format Family

### 1. Stable Field Numbers (Protocol Buffers, Thrift)

Protocol Buffers identifies fields on the wire by small integer **field numbers** rather than source-code names.[^2] Safe evolution follows four strict invariants:

- Introduce new fields with fresh, unused numbers as optional fields.
- **Never reuse** a deleted field number for a different meaning or type; mark retired numbers and names `reserved` in the `.proto` file.
- Changing a field's wire type in place (for example, changing field `3` from `int64` to `string`) breaks mixed-version fleets; instead, add field `4` with the new type, dual-write during migration, then retire and reserve field `3`.
- Source-level field renames preserve binary wire compatibility, but break text/JSON mappings (`proto3` JSON uses field names).

### 2. Writer/Reader Schema Resolution (Apache Avro)

Unlike Protocol Buffers, raw Avro binary payloads contain neither field names nor field numbers—values appear tightly packed in writer-schema order.[^3] Evolution works through explicit **schema resolution** at decode time:

| Schema | Role at Decode Time |
|---|---|
| **Writer schema** | Exact schema used to encode the bytes (carried in container file headers or fetched by ID from a schema registry) |
| **Reader schema** | Schema expected by the consuming application |

At read time, Avro matches writer and reader fields by **name** (plus optional explicit **aliases** for safe renames):

- **Backward read (Writer v1 → Reader v2):** `v2` adds `string currency_code = "USD"`. Resolution decodes `order_id` and `total_cents` from `v1` bytes and fills `currency_code` from the reader schema's default.
- **Forward read (Writer v2 → Reader v1):** Resolution parses and discards `currency_code` using the writer schema so `v1` reads `order_id` and `total_cents` cleanly.
- **Alias rename:** Declaring `amount_cents` with alias `"total_cents"` in the reader schema allows renaming without wire breakage.

```text
  Producer: encode(record, writer_v2) ──► [schema_id=17 | raw bytes]
                                                │
  Consumer: fetch schema 17 from registry ──► resolve(writer_v2, reader_v3) ──► object
```

| Dimension | Protocol Buffers | Apache Avro |
|---|---|---|
| **Wire field identity** | Numeric field tags (`1`, `2`, `3`, …) | Positional under writer schema; resolved by field name |
| **Metadata required to decode** | Reader's compiled descriptors | Both **writer schema** (via header or registry ID) and **reader schema** |
| **Adding a field** | Fresh field number; unknown tags skipped by wire type | New field with default value; resolved by name |
| **Operational governance** | `.proto` review + `reserved` discipline + buf/CI checks | Schema registry enforcing BACKWARD / FORWARD / FULL modes |

### 3. Self-Describing Formats (JSON, MessagePack, CBOR)

Schemaless wire formats still require explicit compatibility policies:

- Additive keys are safe only if existing consumers are configured to **ignore unknown properties**.
- Renaming or changing the type of an existing key without a dual-field migration breaks consumers silently.
- Because the wire format does not distinguish "absent," "explicitly `null`," and "zero default" automatically, document presence semantics explicitly and enforce them via JSON Schema, OpenAPI, or contract tests against historical sample payloads (`old bytes × new reader` and `new bytes × old reader`).

---

## Trade-Offs and Common Pitfalls

| Change Pattern | Safe? | Failure Mode if Misapplied |
|---|---|---|
| Add optional field with explicit default | Usually safe (full) | Fails if older readers reject unknown fields strictly |
| Reuse a deleted field number or key name | **Breaking** | Silent data corruption or parse failures across mixed versions |
| Add a new *required* field before upgrading writers | **Breaking** | Newer readers reject payloads from older writers |
| Rename a field in place without dual-write or alias | **Breaking** | Old readers miss the new key; new readers miss the old key |
| Delete a field immediately on the day writers stop sending it | **Risky** | Breaks consumers replaying historical logs or queued messages |

---

## Connection to the Benchmark Suite

Benchmark data types in this suite use a fixed logical catalog (`schemas/data_catalog_v2.yaml`) so libraries are measured on identical shapes. The benchmark runner evaluates encode/decode throughput and fidelity—it does not simulate schema-registry governance or multi-version fleet rollouts. Operational registry policies and versioning strategies are developed further in [Part III: Production Systems](../301/index.md).

---

## Exercises

1. **Migration plan:** A billing event in Protocol Buffers stores `int64 amount_cents = 3`. Finance now requires arbitrary-precision decimal strings (`string amount_decimal`). Design a zero-downtime, multi-step migration across rolling deployments that preserves both backward and forward compatibility.

??? note "Solution"
    1. **Step 1 (Expand schema):** Add `string amount_decimal = 4;` as an optional field while keeping field `3` intact.
    2. **Step 2 (Upgrade readers):** Deploy consumers that read `amount_decimal` when present and fall back to `amount_cents` otherwise.
    3. **Step 3 (Dual-write):** Upgrade producers to populate *both* field `3` and field `4`.
    4. **Step 4 (Drain and retire):** Once all active consumers use field `4` and retention/replay windows for older consumers expire, stop writing field `3` and mark `reserved 3;` and `reserved "amount_cents";` in the `.proto` file.

2. **Avro missing default:** An Avro event stream enforces `BACKWARD` compatibility in its schema registry. A developer adds a new field `{"name": "region", "type": "string"}` *without* a `"default"` attribute. Why does the registry reject this schema?

??? note "Solution"
    Under `BACKWARD` compatibility, a reader compiled with the new schema must be able to decode historical events written with the old schema (which lacked `region`). Without a `"default"` value in the new reader schema, Avro schema resolution has no valid value to supply for `region` on older records.

3. **Zero vs. absent:** Why is encoding "unset optional discount" as `0` in a proto3 `int32` field ambiguous, and how do modern schemas avoid that ambiguity?

??? note "Solution"
    In standard proto3 singular scalar fields, `0` is the implicit default and is omitted on the wire, making "no discount specified" indistinguishable from "explicit 0% discount." Avoid this by using explicit presence (`optional int32` in proto3/editions, wrapper types, or nullable unions `["null", "int"]` in Avro and JSON).

---

## References

[^1]: Kleppmann, M. (2017). *Designing Data-Intensive Applications*, Chapter 4: "Encoding and Evolution." O'Reilly Media.
[^2]: Protocol Buffers Documentation. *Updating A Message Type*. <https://protobuf.dev/programming-guides/proto3/#updating>
[^3]: Apache Software Foundation. *Apache Avro Specification (§ Schema Resolution)*. <https://avro.apache.org/docs/>
