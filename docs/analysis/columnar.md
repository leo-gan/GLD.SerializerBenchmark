# Columnar

The **columnar** data set is four data types for table-shaped values. They run from `columnar.yaml` and `columnar-smoke.yaml`. They are not in the publication matrix. `signal` is the aligned record that SBE can store.

This set is not the Columnar family. A family is a teaching group of standards. SBE’s family is schema-driven, its standard is SBE, and its data set is columnar. That distinction is on [Families](families.md).

The generator contract and the other sets are on [Data sets](test_data_configuration.md).

## table

A wide flat row of named scalars. One instance is one row. `data_type_instance_count` is the table’s row count. Strings are last so the same record is a legal SBE body.

| Fields | Type |
|--------|------|
| `f_float_0` … `f_float_15` | float64 |
| `f_int_0` … `f_int_3` | int64 |
| `f_str_0`, `f_str_1` | utf8 string |

Default: `string_len: {min:3,max:16}`, `int_range: {min:0,max:1000000}`, `duplication: 0.5`.

`duplication` repeats string values **across rows**. The vocabulary is built from `(seed, type_id)` only. Each instance index then draws from that vocabulary. There are no nulls.

Fidelity is full-row equality after materializing domain rows.

## table_project

The same fields and the same default `type_config` as `table`, so `TypeConfigHash` matches. Serialize writes all 22 columns. Deserialize returns `f_float_0` as `float64[N]`, including when N is 1. Fidelity compares that vector. A full-row result fails fidelity.

Read `TimeDeser` for this type. `TimeSer` is still the full-table write, so `TimeSerAndDeser` is dominated by the write.

## nested_table

A struct plus a list of structs. This is the shredding case for Arrow, Parquet, and ORC.

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

A fixed block, then variable strings, then one repeating group. This is the SBE record. Arrow, Parquet, and the row peers on the allow-list also encode it.

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
