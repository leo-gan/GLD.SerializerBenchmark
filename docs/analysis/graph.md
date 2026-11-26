# Graph Data Set

The **`graph`** data set contains a single data type, also named `graph`, executed via `config/library/graph.yaml` ($N \in \{1, 100\}$, `bytes` mode, no post-compression). Only graph-capable serializers mapped under `serializer_data_sets` are evaluated; tree-only codecs (JSON, Protocol Buffers, MessagePack, FlatBuffers, etc.) return unsupported and are omitted without recording a fidelity failure.

## Motivation

Standard tree-oriented wire formats cannot express object identity (DAG sharing) or reference cycles: duplicating shared children alters graph topology, and cyclic references trigger infinite recursion or stack overflow. The `graph` workload exercises both hazards simultaneously—multiple `Order` instances sharing references to the same `Region` objects, alongside `Person` nodes linked in a directed cycle.

## Schema and Deterministic Generation

```text
Region { code: utf8_string, note: utf8_string, version: int32 }   // note length = 64
Order  { sku: utf8_string, qty: int32, region: &Region }          // shared reference, not copy
Person { name: utf8_string, next: &Person }                       // cyclic reference
Book   { orders: Order[], people: Person[] }
```

**Default `type_config`:** `order_count: 32`, `region_count: 4`, `ring_size: 8`, `string_len: {min: 8, max: 16}`.

Generation proceeds deterministically after seeding with `(seed, type_id, instance_index)`:

1. Create `region_count` distinct `Region` objects (`code` from `string_len`, 64-character `note`, `version` $\in [1, 10]$).
2. Create `order_count` `Order` objects (`sku` from `string_len`, `qty` $\in [1, 100]$), referencing `regions[i % region_count]` by identity (each region shared by 8 orders under default knobs).
3. Create `ring_size` `Person` objects (`name` from `string_len`) and link `people[i].next` to `people[(i + 1) % ring_size]`, forming a closed cycle of length 8.

## Fidelity and Format Constraints

- **Topological identity check:** Fidelity verifies object identity inside each restored graph alongside field equality—all orders sharing a region must point to the **same** restored `Region` instance, and traversing `next` `ring_size` times must return to the starting `Person` object with `people[i].next is people[(i + 1) % ring_size]`. Duplicating shared regions or unrolling the ring into a flat list scores `0.0`. For $N > 1$, each graph instance is checked independently (no cross-batch sharing).
- **Dagr layout restriction:** `schemas/v2/dagr/schema.py` emits `Book` for `dagr-regular` and `dagr-frozen` only. Packed layouts (`dagr-packed`, `dagr-frozen-packed`) inline child nodes and therefore cannot legally represent the `Person.next` cycle.
