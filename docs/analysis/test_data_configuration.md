# Data sets

This page is the shared rules for the sample data every language benchmark runner serializes. The catalog is five **data sets**. Each set has its own page for its data types and their size knobs.

Think of it as the **shared homework assignment**. Each language implements the same types so comparisons stay fair.

<span id="the-five-default-types"></span>

| Data set | Data types | Run config |
| --- | --- | --- |
| [Suite](suite.md) | `message`, `document`, `telemetry`, `strings`, `event` | [`default.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/default.yaml), [`smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/smoke.yaml) |
| [Columnar](columnar.md) | `table`, `table_project`, `nested_table`, `signal` | [`columnar.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/columnar.yaml) |
| [Graph](graph.md) | `graph` | [`graph.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/graph.yaml) |
| [Array](array.md) | `grid`, `grid_window` | [`array.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/array.yaml). Who is measured is on that page. |
| [Tensor](tensor.md) | `tensor`, `tensor_view`, `prompt`, `shard`, `request` | [`tensor.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/tensor.yaml) |

Suite is the publication matrix. Columnar, graph, array, and tensor run only from their own configs, and `all@` does not include them. Which serializers are measured on each set is `serializer_data_sets` in [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml). A name that is absent is suite only. On a specialized run config, runners whose comma filter is exact fill an empty serializer filter from that map. A filter you pass still narrows the run. Python applies the same map inside the runner.

| Resource | Path |
|----------|------|
| Data set list | [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml) `data_sets` |
| Type catalog | [`schemas/data_catalog_v2.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/schemas/data_catalog_v2.yaml) |
| Run configs | [`config/library/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/config/library) |
| Wire schemas | [`schemas/v2/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/schemas/v2) |

How times are cleaned and summarized is separate: [Analysis methodology](ANALYSIS_METHODOLOGY.md).

---

## Learning goals

By the end of this page you should be able to:

1. Define **data set**, **data type**, **run config**, **cell**, and **make_one** in one sentence each.
2. Name the five data sets and open the page that explains the types in each.
3. Explain batching (`data_type_instance_count`) without confusing it with “how many repetitions.”

---

## Vocabulary

These are the words for sample data. The full list is [Terminology](terminology.md). That page is also where Fixture and harness are prohibited.

| Term | Meaning | Examples |
|------|---------|----------|
| **data set** | Parent of the data type. Configured under `data_sets` in `config/benchmark_config.yaml`. A serializer is measured on the sets it supports | `suite`, `columnar`, `graph`, `array`, `tensor` |
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

> Older pages and some runner source still say *fixture*. [Terminology](terminology.md#fixture) says to write **data type**.

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


## Suite

<a id="message"></a>
<a id="document"></a>
<a id="telemetry"></a>
<a id="strings"></a>
<a id="event"></a>

Five data types: `message`, `document`, `telemetry`, `strings`, and `event`. This is the publication matrix. Shapes and defaults are on [Suite](suite.md).

## Columnar

<a id="table"></a>
<a id="table_project"></a>
<a id="nested_table"></a>
<a id="signal"></a>

Four data types: `table`, `table_project`, `nested_table`, and `signal`. Shapes are on [Columnar](columnar.md). How this set differs from the Columnar family is on [Families](families.md).

## Graph

One data type, also named `graph`. The shape, the shared nodes, and the cycle check are on [Graph](graph.md).

## Array

<a id="grid-and-grid_window"></a>

Two data types: `grid` and `grid_window`. The shapes, and which languages are measured on this set, are on [Array](array.md).

## Tensor

<a id="tensor-tensor_view-prompt-shard-and-request"></a>

Five data types: `tensor`, `tensor_view`, `prompt`, `shard`, and `request`. Shapes are on [Tensor](tensor.md).

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
| [`config/library/default.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/default.yaml) | five suite types × `[1, 100]` |
| [`config/library/columnar-smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/columnar-smoke.yaml) | `table`, `table_project`, `nested_table`, `signal` × `[1]`, bytes, no post-compression |
| [`config/library/columnar.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/columnar.yaml) | `table` and `table_project` × `[1, 100, 10000]`; `nested_table` and `signal` × `[1, 100]`; bytes; no post-compression |
| [`config/library/graph.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/graph.yaml) | `graph` × `[1, 100]`; bytes; no post-compression |
| [`config/library/array-smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/array-smoke.yaml) | `grid` and `grid_window` × `[1]` |
| [`config/library/array.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/array.yaml) | `grid` and `grid_window` × `[1]`; no post-compression |
| [`config/library/tensor-smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/tensor-smoke.yaml) | `tensor`, `tensor_view`, `prompt`, `shard`, and `request` × `[1]` |
| [`config/library/tensor.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/tensor.yaml) | `tensor`, `tensor_view`, `prompt`, `shard`, and `request` × `[1]`; bytes; no post-compression |

`columnar.yaml` sets `compression.mode: none`. `Size` is the codec’s own byte length. Parquet’s default page codec is Snappy, so `parquet` is not a layout-only size. `parquet-uncompressed` turns page compression off. Arrow IPC stream bytes are uncompressed. Apache ORC’s C++ and Java writers default to Zlib. pyarrow’s `write_table` defaults to uncompressed, and the Python `orc` row follows that default. `orc-uncompressed` is the named override for languages whose default is Zlib; on pyarrow it is the same codec as `orc`.

Call the columnar, graph, array, and tensor configs with `BENCHMARK_RUN_CONFIG`. They are not `smoke_run_config` or `default_run_config`. Pass a serializer name filter, or leave it empty so the runner fills it from `serializer_data_sets`. The columnar type ids are not part of the global smoke matrix. Mojo generates them for `arrow-ipc`, `parquet`, and `parquet-uncompressed`. PHP, Zig, Swift, and C do not generate them.

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
soft_budget_seconds = soft_seconds_per_10_serializers * ceil(n_serializers / 10)
```

`soft_seconds_per_10_serializers` defaults to 60. Before each repetition the runner reads elapsed wall-clock time.

- Inside the soft budget, the run keeps its repetition count.
- Past the soft budget, the runner lowers the plan to `reps_fallback` (50). Repetitions already written stay in the CSV. Later cells use the lower count.
- Past `hard_cap_seconds` (**600** seconds), the runner stops at that repetition boundary.

Every library run config carries these three knobs, including `tensor.yaml` and `tensor-smoke.yaml`. Python and Mojo apply the check. A publication splice still requires the full repetition index range, so only a finished run is published.

---

## Schema sources

IDL and code generation: `schemas/v2/` and `scripts/schemas/generate-all.sh`.

Logical fields on this page must stay aligned with `.proto`, `.avsc`, and `schemas/v2/sbe/signal.xml`. `table_project` has no protobuf message of its own. Peers encode `Table` / `BatchTable` and project `f_float_0`.

---

## TypeConfigHash

SHA-256 of the canonical JSON (sorted keys, no whitespace variance) of the **resolved** `type_config`, then the first **12** hex characters, lowercase. This lets analysis detect when two runs used different knobs even if the type id is the same.
