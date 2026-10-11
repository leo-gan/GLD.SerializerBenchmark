# Test data

This page describes the **sample data** every language benchmark runner serializes: logical shapes, configuration knobs, run matrices, and generator rules.

Think of it as the **shared homework assignment**. Each language implements the same types so comparisons stay fair.

| Resource | Path |
|----------|------|
| Type catalog | [`schemas/data_catalog_v2.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/schemas/data_catalog_v2.yaml) |
| Run configs | [`config/library/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/config/library) |
| Wire schemas | [`schemas/v2/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/schemas/v2) |
| Default matrix | [`config/library/default.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/default.yaml) |
| Smoke matrix | [`config/library/smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/smoke.yaml) |

**Type ids:** `message` · `document` · `telemetry` · `strings` · `event` · `table` · `table_project` · `nested_table` · `signal` · `graph` · `grid` · `grid_window`

The first five are the publication matrix (`default.yaml`, `smoke.yaml`). The next four run only from `columnar.yaml` / `columnar-smoke.yaml`, and only for an explicit serializer allow-list: the columnar and SBE rows registered in that language, plus one JSON peer, the primary Protobuf row, one FlatBuffers or Cap’n Proto row when the tree already has one, and the Avro row when the tree already has one. `graph` runs only from `graph.yaml`, and only for serializers whose official API round-trips shared nodes and a reference cycle. `grid` and `grid_window` run only from `array.yaml` / `array-smoke.yaml`. Fortran times them on HDF5, NetCDF, and ADIOS2.

How times are cleaned and summarized is separate: [Analysis methodology](ANALYSIS_METHODOLOGY.md).

---

## Learning goals

By the end of this page you should be able to:

1. Define **data type**, **run config**, **cell**, and **make_one** in one sentence each.
2. Sketch the five publication data types, the four columnar / aligned types, the graph type, and the two array types, and what each stresses.
3. Explain batching (`data_type_instance_count`) without confusing it with “how many repetitions.”

---

## Vocabulary

This suite uses a few fixed words. Prefer these over informal synonyms such as “fixture.”

| Term | Meaning | Examples |
|------|---------|----------|
| **data set** | Parent of the data type. A serializer is measured on the sets it supports | `suite`, `columnar`, `graph`, `array` |
| **data type** (also **type id**) | Which *kind* of sample object we serialize. It belongs to one data set | `message` (suite), `table` (columnar), `graph` (graph), `grid` (array) |
| **type config** | Size and shape knobs for **one** instance of that type | `field_count: 8`, `points: 32` |
| **instance** | One concrete object of a data type | one `message` record |
| **batch size** (`data_type_instance_count`) | How many instances go into **one** serialize/deserialize call | `1` or `100` |
| **cell** | One measured combination: data type + type config + batch size | `message` with N=100 |
| **type catalog** | File of type ids and default type configs | `schemas/data_catalog_v2.yaml` |
| **run config** | Which cells to measure in a run | `config/library/default.yaml` |
| **make_one** | Generator that builds a **single** instance | language-specific |

**CSV names (for readers of raw logs):**

| CSV column | Everyday name |
|------------|---------------|
| `TestDataName` | data type id |
| `DataTypeInstanceCount` | batch size `N` |
| `TypeConfigHash` | short hash of the resolved type config |

> **Note:** Older docs and some benchmark-runner code still say *fixture*. That almost always means **data type** (or one generated instance of it), not a separate concept.

Batch cells may appear on the Dashboard as **Data type · N instances** (for example Message · 100 instances), from `type_id` and `data_type_instance_count`.

---

## Two axes (shape × batch size)

```text
W = [ { type_id, type_config }, ... ]     # which shapes
C = [ n1, n2, ... ]                       # how many instances per call
cells = W × C                             # cartesian product
```

| Axis | Owns |
|------|------|
| `type_id` + `type_config` | Shape of **one** instance |
| `data_type_instance_count` | How many instances in **one** serialize/deserialize call (`1` = single object, `N` = batch). A type row in a run config may set its own list and override the file-level list. |
| `seed` | Within-language deterministic generation (master `reproducibility.random_seed`) |
| compression | Runner post-steps on encoded bytes (**not** part of `type_config`) |

**Do not put these keys inside `type_config`:**  
`seed`, `type_id`, `data_type_instance_count`, `instance_count`, `batch_size`, `n`, `return_array_even_for_1_instance`.

---

## Generator contract

```text
make_one(type_id, type_config_resolved, seed, instance_index) -> Instance
```

Benchmark runner pattern:

```text
instances = [make_one(..., i) for i in range(N)]
payload = instances[0] if N == 1 and adapter prefers a scalar else instances
```

### Determinism

- **Required:** same `(seed, type_id, type_config, instance_index)` → same instance **within one language** across runs.
- **Not required:** identical payloads or identical random streams **across** languages.
- Within-language comparisons are the suite default; cross-language absolute times are orientation only.

---

## The five default types

These five are the publication matrix. Columnar and aligned-record types follow them.

### message

A flat record of mixed primitives. **No** nested objects; **no** arrays of objects. Good baseline for “simple struct” cost.

| Field (logical) | Type | Notes |
|-----------------|------|--------|
| Keys `f0`…`f{field_count-1}` | cycled from `primitive_types` | Deterministic key names |
| Values | bool / int32 / int64 / float64 / utf8_string | From the resolved primitive set |

Default `type_config`: `field_count: 8`, `primitive_types: all_available`, `string_len: {min:3,max:16}`, `int_range: {min:0,max:1000000}`.

### document

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

### telemetry

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

### strings

Text bulk only—useful for string encoding cost.

```text
Strings {
  items: [utf8_string, ...]  // length = count
}
```

Default: `count: 32`, `string_len: {min:3,max:16}`, `duplication: 0.1`.

### event

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

### table

A wide flat row of named scalars. One instance is one row. `data_type_instance_count` is the table’s row count. Strings are last so the same record is a legal SBE body.

| Fields | Type |
|--------|------|
| `f_float_0` … `f_float_15` | float64 |
| `f_int_0` … `f_int_3` | int64 |
| `f_str_0`, `f_str_1` | utf8 string |

Default: `string_len: {min:3,max:16}`, `int_range: {min:0,max:1000000}`, `duplication: 0.5`.

`duplication` repeats string values **across rows**. The vocabulary is built from `(seed, type_id)` only. Each instance index then draws from that vocabulary. There are no nulls.

Fidelity is full-row equality after materializing domain rows.

### table_project

The same fields and the same default `type_config` as `table`, so `TypeConfigHash` matches. Serialize writes all 22 columns. Deserialize returns `f_float_0` as `float64[N]`, including when N is 1. Fidelity compares that vector. A full-row result fails fidelity.

Read `TimeDeser` for this type. `TimeSer` is still the full-table write, so `TimeSerAndDeser` is dominated by the write.

### nested_table

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

### signal

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

### graph

One instance is one graph. It belongs to the `graph` data set. `all@` does not include it. The run config is `config/library/graph.yaml` (N=1 and N=100, bytes, no compression), with an explicit serializer allow-list.

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

### grid and grid_window

One dense float64 array. Both types belong to the `array` data set. `all@` does not include them. The run config is `config/library/array.yaml` (N=1, no compression), with an explicit serializer allow-list. Fortran times `hdf5-fortran`, `netcdf-fortran`, and `adios2`. Other languages do not receive these type ids from `default.yaml` or `smoke.yaml`.

```text
grid {
  values: float64[y][x]    // nx = 512, ny = 512
}
grid_window {
  same write
  read: values[y0 : y0+wy][x0 : x0+wx]
  // x0 = 128, y0 = 64, wx = 256, wy = 128
}
```

Coordinates are 0-based. Fill order is `y` outer, `x` inner, one unscaled unit-interval float64 per element. Fortran stores `values(nx, ny)`, and the file dimensions follow that array: `x` then `y`. `grid_window` writes the whole array and reads the window with a hyperslab, a NetCDF `start`/`count`, or an ADIOS selection. Fidelity is bit-identical float64. The size column is the full file. N stays 1. The array is one value.

---

## Primitives

Portable set (`all_available`):

```text
bool, int32, int64, float64, utf8_string
```

**Datetime:** logical model uses `int64` epoch milliseconds UTC (not ISO strings). Schema IDLs must use the same convention.

---

## Batch wire shape (schema codecs)

When `data_type_instance_count = N > 1` (and adapters need a sequence type):

```text
Batch_<Type> {
  repeated <Type> items = 1;   // length == N
}
```

Example: `Batch_message { repeated Message items = 1; }`.

Prefer this wrapper over a package-level stream of top-level `repeated` messages, so **one encode call** maps to **one** message. For `N = 1`, adapters may use a bare `Message` (optimal single path) or a batch of length one.

---

## Run configs

| File | Matrix |
|------|--------|
| [`config/library/smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/smoke.yaml) | `message`, `telemetry` × `[1]` |
| [`config/library/default.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/default.yaml) | five publication types × `[1, 100]` |
| [`config/library/columnar-smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/columnar-smoke.yaml) | `table`, `table_project`, `nested_table`, `signal` × `[1]`, bytes, no post-compression |
| [`config/library/columnar.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/columnar.yaml) | `table` and `table_project` × `[1, 100, 10000]`; `nested_table` and `signal` × `[1, 100]`; bytes; no post-compression |

`columnar.yaml` sets `compression.mode: none`. `Size` is the codec’s own byte length. Parquet’s default page codec is Snappy, so `parquet` is not a layout-only size. `parquet-uncompressed` turns page compression off. Arrow IPC stream bytes are uncompressed. Apache ORC’s C++ and Java writers default to Zlib. pyarrow’s `write_table` defaults to uncompressed, and the Python `orc` row follows that default. `orc-uncompressed` is the named override for languages whose default is Zlib; on pyarrow it is the same codec as `orc`.

Call the columnar configs with `BENCHMARK_RUN_CONFIG`. They are not `smoke_run_config` or `default_run_config`. Pass a serializer name filter. The new type ids are not part of the global smoke matrix. Mojo generates them for `arrow-ipc`, `parquet`, and `parquet-uncompressed`. PHP, Zig, Swift, and C do not generate them.

Resolve a config to see the expanded cell list:

```bash
./scripts/resolve_run_config.py config/library/default.yaml --pretty
./scripts/resolve_run_config.py config/library/smoke.yaml --seed 42
```

---

## Compression

Compression is a **runner** concern, not part of `type_config`.

Modes: `none` | `size_only` | `timed` (timed path is post-MVP).

**size_only:** compute gzip/zstd sizes **once per cell** (not every timed repetition).

---

## Wall-clock budget

```text
soft_budget_seconds = 60 * ceil(n_serializers / 10)
```

If a run overruns, reduce repetitions from 100 to 50. Hard cap: **600 seconds** per language run.

---

## Schema sources

IDL and code generation: `schemas/v2/` and `scripts/schemas/generate-all.sh`.

Logical fields on this page must stay aligned with `.proto`, `.avsc`, and `schemas/v2/sbe/signal.xml`. `table_project` has no protobuf message of its own. Peers encode `Table` / `BatchTable` and project `f_float_0`.

---

## TypeConfigHash

SHA-256 of the canonical JSON (sorted keys, no whitespace variance) of the **resolved** `type_config`, then the first **12** hex characters, lowercase. This lets analysis detect when two runs used different knobs even if the type id is the same.
