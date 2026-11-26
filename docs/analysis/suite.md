# Suite Data Set

The **`suite`** data set is the default publication matrix executed by all fourteen language runners via `config/library/default.yaml` ($N \in \{1, 100\}$) and `config/library/smoke.yaml` ($N = 1$). Any serializer omitted from `serializer_data_sets` in `config/benchmark_config.yaml` is evaluated on `suite` only. Generator rules and batching semantics live on [Data sets](test_data_configuration.md).

## Motivation and Workload Design

Each of the five types in `suite` isolates one distinct cost center that real application payloads typically mix together—fixed per-call library overhead (`message`), tree traversal and object allocation (`document`), contiguous numeric conversion (`telemetry`), UTF-8 scanning and string allocation (`strings`), and key–value log framing (`event`). Measuring every shape at both $N = 1$ and $N = 100$ separates fixed per-call framing overhead from per-record scaling without altering the record schema.

## Data Types

### `message`

A flat record of mixed primitives with no nested objects or child lists, isolating baseline per-call encoder/decoder overhead (representative of status updates or compact RPC parameters).

| Logical Field | Type | Notes |
|---|---|---|
| `f0` … `f{field_count - 1}` | Cycled from `primitive_types` (`bool`, `int32`, `int64`, `float64`, `utf8_string`) | Deterministic field names |

**Default `type_config`:** `field_count: 8`, `primitive_types: all_available`, `string_len: {min: 3, max: 16}`, `int_range: {min: 0, max: 1000000}`.

### `document`

A nested order-like tree combining top-level fields, a nested metadata struct, and a repeated list of line items, isolating tree traversal, repeated field-name overhead, and per-object allocation.

```text
Document {
  id:     utf8_string
  status: int32
  meta:   { region: utf8_string, version: int32 }
  items:  [ { sku: utf8_string, qty: int32, price_minor: int64 }, ... ]   // length = children
}
```

**Default `type_config`:** `children: 8`, `fields_per_child: 3`, `max_depth: 2`.

### `telemetry`

A numeric-dominant sensor reading carrying a source identifier, epoch-millisecond timestamp, short string tags, and a contiguous numeric series, isolating radix conversion (decimal–binary float parsing/formatting) and dense numeric packing.

```text
Telemetry {
  source: utf8_string
  ts:     int64                            // epoch ms UTC
  tags:   [ utf8_string, ... ]             // length = tag_count
  values: [ float64 | int64, ... ]         // length = points
}
```

**Default `type_config`:** `points: 32`, `number_type: float64`, `tag_count: 2`.

### `strings`

A flat collection of UTF-8 text items without enclosing metadata, isolating string validation, escape scanning, and heap string allocation.

```text
Strings {
  items: [ utf8_string, ... ]              // length = count
}
```

**Default `type_config`:** `count: 32`, `string_len: {min: 3, max: 16}`, `duplication: 0.1`.

### `event`

A compact structured log or message-bus envelope containing routing metadata and a short attribute map; $N = 100$ models batching envelopes on an event stream independently of per-event attribute width (`attr_count`).

```text
Event {
  event_id:    utf8_string
  event_type:  utf8_string
  occurred_at: int64                       // epoch ms UTC
  producer:    utf8_string
  attrs:       map or list of { key: utf8_string, value: utf8_string }    // length = attr_count
}
```

**Default `type_config`:** `attr_count: 4`, `include_payload_bytes: 0`.
