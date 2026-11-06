# Columnar

The **columnar** data set is four data types for table-shaped values. They run from `columnar.yaml` and `columnar-smoke.yaml`. They are not in the publication matrix.

## Why this set

The columnar set is wide tables and one aligned record. It exists because a five-field message does not show the difference between a row serializer and a column file. At one small record, a column file pays a header and then looks slow for a reason that has little to do with a scan. On a wide row, a one-column read, and a nested row, the column layout is doing the job it was built for. Typical uses are scans over many rows, reading one column out of a wide table, nested rows, and market-data messages. Only libraries that can carry these shapes are measured here.

This set is not the Columnar family. A family is a teaching group of standards. SBE’s family is schema-driven, its standard is SBE, and its data set is columnar. That distinction is on [Families](families.md). The production version of the same split is [Row vs columnar](../theory/301/row-vs-columnar.md).

The generator contract and the other sets are on [Data sets](test_data_configuration.md).

## table

A table row is a wide flat record: sixteen floats, four integers, and two strings. It exists so columnar files and row codecs can be timed on a scan-shaped row, not on a tiny message. One instance is one row, and `data_type_instance_count` is the table’s row count, so N=100 is one hundred rows. Strings are last so the same record is a legal SBE body. Typical uses are a feature row, a measurement row, or a warehouse record.

| Fields | Type |
|--------|------|
| `f_float_0` … `f_float_15` | float64 |
| `f_int_0` … `f_int_3` | int64 |
| `f_str_0`, `f_str_1` | utf8 string |

Default: `string_len: {min:3,max:16}`, `int_range: {min:0,max:1000000}`, `duplication: 0.5`.

`duplication` repeats string values **across rows**. The vocabulary is built from `(seed, type_id)` only. Each instance index then draws from that vocabulary. There are no nulls.

Fidelity is full-row equality after materializing domain rows.

## table_project

Table project writes the same wide row as `table`, and the read returns only the first float column. It exists because columnar formats are built to skip the columns a query does not need, and a full-row read hides that. The type config matches `table`, so `TypeConfigHash` matches: the write is the same cell, and the read is the new question. Serialize writes all 22 columns. Deserialize returns `f_float_0` as `float64[N]`, including when N is 1. A row codec may decode every column and then slice. That decode stays on the clock. Fidelity compares the returned vector. A full-row result fails fidelity. Typical uses are a query that needs one measure from a wide table.

Read `TimeDeser` for this type. `TimeSer` is still the full-table write, so `TimeSerAndDeser` is dominated by the write.

## nested_table

A nested table is one struct plus a list of structs. It exists because column formats shred that nesting into columns, which the flat `table` row does not exercise. This is the shredding case for Arrow, Parquet, and ORC. Typical uses are an order with line items, or an event with a repeated group, stored as a table.

```text
NestedRow {
  id: utf8
  status: int32
  meta: { region: string, version: int32 }
  items: [ { sku: string, qty: int32, price_minor: int64 }, ... ]  // length = children
}
```

Default: `children: 4`. SBE does not implement this type.

## signal

A signal is a fixed header, then short strings, then a repeating group. It exists as the aligned record Simple Binary Encoding was designed to pack, and as a check that other codecs can carry the same shape. Arrow, Parquet, and the row peers on the allow-list also encode it. Typical uses are a market-data tick or an order update.

```text
Signal {
  seq: int64
  ts: int64
  price_mantissa: int64
  qty: int32
  flags: int32
  symbol: utf8
  venue: utf8
  legs: [ { leg_id: int64, leg_qty: int32, leg_pad: int32 }, ... ]  // length = group_count
}
```

`leg_pad` is 0. It keeps each group body a fixed 16-byte block. Default: `group_count: 4`. Wire schemas are `schemas/v2/protobuf/benchmark_v2.proto`, `schemas/v2/avro/signal.avsc`, and `schemas/v2/sbe/signal.xml`. Protobuf and Avro keep the strings before `legs`. The SBE message puts the `legs` group before `symbol` and `venue`, because sbe-tool rejects a repeating group after variable-length data. Field ids are unchanged.
