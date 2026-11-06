# Suite

The **suite** data set is the publication matrix. Its five data types run from `default.yaml` and `smoke.yaml`. A serializer name that is absent from `serializer_data_sets` is measured on this set only.

The generator contract, batching, and the other sets are on [Data sets](test_data_configuration.md).

## message

A flat record of mixed primitives. **No** nested objects; **no** arrays of objects. Good baseline for “simple struct” cost.

| Field (logical) | Type | Notes |
|-----------------|------|--------|
| Keys `f0`…`f{field_count-1}` | cycled from `primitive_types` | Deterministic key names |
| Values | bool / int32 / int64 / float64 / utf8_string | From the resolved primitive set |

Default `type_config`: `field_count: 8`, `primitive_types: all_available`, `string_len: {min:3,max:16}`, `int_range: {min:0,max:1000000}`.

## document

A nested structure (id, status, meta map, list of line items). Scale is controlled by `children`, `fields_per_child`, and `max_depth`.

```text
Document {
  id: utf8_string
  status: int32
  meta: { region: string, version: int32 }
  items: [ { sku: string, qty: int32, price_minor: int64 }, ... ]  // length = children
}
```

Default: `children: 8`, `fields_per_child: 3`, `max_depth: 2`.

## telemetry

Mostly numeric sensor-style data.

```text
Telemetry {
  source: utf8_string
  ts: int64          // epoch milliseconds
  tags: [string, ...]  // length = tag_count
  values: [float64 or int64, ...]  // length = points
}
```

Default: `points: 32`, `number_type: float64`, `tag_count: 2`.

## strings

Text bulk only—useful for string encoding cost.

```text
Strings {
  items: [utf8_string, ...]  // length = count
}
```

Default: `count: 32`, `string_len: {min:3,max:16}`, `duplication: 0.1`.

## event

A stream-style envelope (one event instance; batch via `data_type_instance_count`).

```text
Event {
  event_id: utf8_string
  event_type: utf8_string
  occurred_at: int64     // epoch milliseconds
  producer: utf8_string
  attrs: map or list of {key, value} string pairs  // length = attr_count
}
```

Default: `attr_count: 4`, `include_payload_bytes: 0`.
