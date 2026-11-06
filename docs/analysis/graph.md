# Graph

The **graph** data set has one data type, and that type is also named `graph`: one graph with shared nodes and one reference cycle. `all@` does not include it. The run config is `config/library/graph.yaml` (N=1 and N=100, bytes, no compression). An empty serializer filter selects the serializers mapped to this set. Tree codecs are not in that map.

The generator contract and the other sets are on [Data sets](test_data_configuration.md).

```text
Region { code: utf8, note: utf8, version: int32 }   // note is 64 characters
Order  { sku: utf8, qty: int32, region: Region }    // reference, not a copy
Person { name: utf8, next: Person }                 // reference
Book   { orders: Order[], people: Person[] }
```

Default: `order_count: 32`, `region_count: 4`, `ring_size: 8`, `string_len: {min:8,max:16}`.

Generator order, after the usual `(seed, type_id, instance_index)` mix:

1. For each region: `code` from `string_len`, then `note` of length 64, then `version` in 1…10.
2. For each order: `sku` from `string_len`, then `qty` in 1…100. Order `i` references region `i % region_count` (the same object, eight times when the defaults divide evenly).
3. For each person: `name` from `string_len`. Then `people[i].next` is `people[(i+1) % ring_size]`.

`region` and `next` are references. An inlined copy is a different graph. Tree codecs (JSON, Protocol Buffers, MessagePack, and the rest of the suite types) return unsupported and are skipped. They are not fidelity failures.

Fidelity is identity inside the restored graph, not `asdict` and not a walk that copies each child. The eight orders that name one region must point at one region object. Walking `next` eight times returns to the start, and `people[i].next` is the same object as `people[(i+1) % 8]`. A duplicated region or an unrolled ring scores 0. Field values still have to match. N>1 compares each graph on its own; nodes are not shared across the batch.

Dagr emits this shape as `Book` from `schemas/v2/dagr/schema.py` for the regular and frozen layouts only. Packed and frozen+packed inline a node reference, so a `Person.next` cycle is not a legal packed graph. `dagr-packed` and `dagr-frozen-packed` do not support this data type. The timed path is still full materialize (`to_bytes` / `restore`).
