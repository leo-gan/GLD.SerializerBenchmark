# Suite

The **suite** data set is the publication matrix. Its five data types run from `default.yaml` and `smoke.yaml`. A serializer name that is absent from `serializer_data_sets` is measured on this set only.

## Why this set

The suite is the default set, and the one every language runs. It exists so every language can be compared on the same everyday payloads. The shapes stay small on purpose. Each one isolates a cost the others mix together: the library itself, nesting, numeric bulk, text, and a log envelope. The same shapes are measured at one record and at one hundred, so batching is a second question rather than a different kind of object. Typical uses of these shapes are APIs, documents, metrics, and logs.

The generator contract, batching, and the other sets are on [Data sets](test_data_configuration.md).

## message

A message is one flat record of mixed fields: booleans, integers, floats, and short strings, with no nested objects and no arrays of objects. It is in the suite as the cheapest structured payload, so the cost of the library itself is visible. A nested document would mix that cost with the cost of walking a tree. Typical uses are a status update, a user record, or a simple API body.

| Field (logical) | Type | Notes |
|-----------------|------|--------|
| Keys `f0`…`f{field_count-1}` | cycled from `primitive_types` | Deterministic key names |
| Values | bool / int32 / int64 / float64 / utf8_string | From the resolved primitive set |

Default `type_config`: `field_count: 8`, `primitive_types: all_available`, `string_len: {min:3,max:16}`, `int_range: {min:0,max:1000000}`.

## document

A document is a nested record: an id, a status, a small map, and a list of line items. It is in the suite because many real payloads are trees, and nesting costs more than a flat struct. The message type cannot show that cost. Scale is controlled by `children`, `fields_per_child`, and `max_depth`. Typical uses are an order, a stored document, or an API response with a list inside.

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

Telemetry is one reading made mostly of numbers: a source, a timestamp, a few tags, and a list of values. It is in the suite to show numeric bulk rather than nested structure. A document of a similar size would spend its time on objects and strings. Typical uses are a sensor sample, a metric point, or a monitoring row.

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

The strings type is a list of text and almost nothing else. It is in the suite to show the cost of encoding and copying text, without a complicated record around it. Typical uses are a batch of names, log lines, or search tokens.

```text
Strings {
  items: [utf8_string, ...]  // length = count
}
```

Default: `count: 32`, `string_len: {min:3,max:16}`, `duplication: 0.1`.

## event

An event is a small envelope: an id, a type, a time, a producer, and a few attributes. It is in the suite as the shape of a log line or a message-bus record. One hundred events in one call is a batch of those envelopes. That is a different question from making one envelope larger, which is what `attr_count` would do. Typical uses are an audit event, a click, or a trace span.

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
