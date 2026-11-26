# Columnar Data Set

The **`columnar`** data set evaluates analytical table storage (`Arrow IPC`, `Parquet`, `ORC`), word-aligned fixed-wire messaging (`SBE`), and selected row-oriented peers (`JSON`, `Protobuf`, `FlatBuffers`, `Avro`) on wide rows, single-column projection, nested record shredding, and financial tick messages. It runs exclusively via `config/library/columnar.yaml` and `columnar-smoke.yaml` (not part of the default `suite` matrix). For the distinction between the *columnar data set* and the *columnar format family*, see [Families](families.md) and [3.5 Row vs. columnar](../theory/301/row-vs-columnar.md).

## Motivation and Timing Rules

Small single-record benchmarks penalize columnar formats for per-file footer and alignment metadata while hiding their core advantage: skipping unneeded columns during wide-table scans and applying per-column encoding across large batches ($N = 100, 10\,000$). Under [Timing contract rule 8](TIMING_HONESTY.md), row-to-column conversion and SBE flyweight filling execute inside timed `serialize` (schema setup stays in untimed `prepare`).

## Data Types

### `table`

A wide flat record of 22 non-null scalar columns where batch cardinality $N$ represents table row count ($N \in \{1, 100, 10\,000\}$). Placing variable-length strings last keeps the layout directly representable as a valid SBE message body.

| Fields | Type |
|---|---|
| `f_float_0` … `f_float_15` | `float64` (16 columns) |
| `f_int_0` … `f_int_3` | `int64` (4 columns) |
| `f_str_0`, `f_str_1` | `utf8_string` (2 columns) |

**Default `type_config`:** `string_len: {min: 3, max: 16}`, `int_range: {min: 0, max: 1000000}`, `duplication: 0.5` (vocabulary generated from `(seed, type_id)` and shared across rows).  
**Fidelity:** Full-row equality across all 22 columns after materializing domain rows.

### `table_project`

Identical write workload and `TypeConfigHash` to `table` (serializing all 22 columns), paired with a **single-column projection read** returning only `f_float_0` as `float64[N]` (including at $N = 1$). Columnar readers project only the requested column, whereas row-oriented codecs must decode full records before slicing inside timed `deserialize`.

**Measurement note:** Inspect `TimeDeser` specifically for projection efficiency; `TimeSer` still measures the full 22-column write and therefore dominates `TimeSerAndDeser`. Returning full rows fails fidelity.

### `nested_table`

A nested struct-plus-list schema exercising Dremel-style columnar shredding (repetition/definition levels) in Arrow, Parquet, and ORC; SBE does not implement this type.

```text
NestedRow {
  id:     utf8_string
  status: int32
  meta:   { region: utf8_string, version: int32 }
  items:  [ { sku: utf8_string, qty: int32, price_minor: int64 }, ... ]   // length = children
}
```

**Default `type_config`:** `children: 4` ($N \in \{1, 100\}$).

### `signal`

A low-latency market-data / order-update message consisting of a fixed-width header, two short strings, and a fixed-size repeating group designed for Simple Binary Encoding and shared with Arrow, Parquet, and row peers.

```text
Signal {
  seq:            int64
  ts:             int64
  price_mantissa: int64
  qty:            int32
  flags:          int32
  symbol:         utf8_string
  venue:          utf8_string
  legs:           [ { leg_id: int64, leg_qty: int32, leg_pad: int32 }, ... ]  // length = group_count
}
```

**Default `type_config`:** `group_count: 4`; `leg_pad = 0` preserves a 16-byte aligned repeating-group body. Wire schemas live in `schemas/v2/protobuf/benchmark_v2.proto`, `schemas/v2/avro/signal.avsc`, and `schemas/v2/sbe/signal.xml` (where SBE orders the `legs` group ahead of variable-length `symbol` and `venue` while keeping identical field IDs).
