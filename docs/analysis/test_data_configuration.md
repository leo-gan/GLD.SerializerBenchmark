# Data Sets

Every benchmark runner serializes controlled sample workloads defined by **Data Model v2**, ensuring that all libraries within a language are evaluated on identical logical shapes and cardinalities. The catalog comprises **five data sets** containing **17 data types** in total; vocabulary definitions live in [Terminology](terminology.md) and statistical post-processing lives in [Analysis methodology](ANALYSIS_METHODOLOGY.md).

## Catalog Summary {#the-five-default-types}

<a id="message"></a><a id="document"></a><a id="telemetry"></a><a id="strings"></a><a id="event"></a><a id="table"></a><a id="table_project"></a><a id="nested_table"></a><a id="signal"></a><a id="grid-and-grid_window"></a><a id="tensor-tensor_view-prompt-shard-and-request"></a>

| Data Set | Data Types | Run Config(s) | Scope |
|---|---|---|---|
| **[Suite](suite.md)** | `message`, `document`, `telemetry`, `strings`, `event` | [`default.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/default.yaml), [`smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/smoke.yaml) | Default publication matrix across all 14 languages |
| **[Columnar](columnar.md)** | `table`, `table_project`, `nested_table`, `signal` | [`columnar.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/columnar.yaml), [`columnar-smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/columnar-smoke.yaml) | Wide analytical tables, column projection, shredding, and SBE flyweights |
| **[Graph](graph.md)** | `graph` | [`graph.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/graph.yaml) | Shared node references and cyclic object graphs |
| **[Array](array.md)** | `grid`, `grid_window` | [`array.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/array.yaml), [`array-smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/array-smoke.yaml) | Dense $512 \times 512$ `float64` rasters and interior hyperslab reads |
| **[Tensor](tensor.md)** | `tensor`, `tensor_view`, `prompt`, `shard`, `request` | [`tensor.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/tensor.yaml), [`tensor-smoke.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/library/tensor-smoke.yaml) | Dense `float32`/`int64` ML tensors, zero-copy views, and inference requests |

`suite` is the default publication matrix; specialized sets (`columnar`, `graph`, `array`, `tensor`) execute only when explicitly invoked via `BENCHMARK_RUN_CONFIG` and are excluded from `all@`. Serializer membership per set is controlled by `serializer_data_sets` in [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml) (an unlisted serializer belongs to `suite` only).

| Authoritative Artifact | Repository Path |
|---|---|
| Data-set membership & runner map | [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml) (`data_sets`, `serializer_data_sets`) |
| Logical type catalog & default knobs | [`schemas/data_catalog_v2.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/schemas/data_catalog_v2.yaml) |
| Run-config matrices | [`config/library/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/config/library) |
| Wire IDL definitions | [`schemas/v2/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/schemas/v2) (generated via `scripts/schemas/generate-all.sh`) |

## Experimental Grid and Generator Contract

Each run configuration expands the Cartesian product of shape configurations $W = \{(\text{type\_id}, \text{type\_config})\}$ and batch cardinalities $C = \{n_1, n_2, \dots\}$:

$$
\text{cells} = W \times C
$$

| Layer | Responsibility |
|---|---|
| `type_id` + `type_config` | Logical shape and size parameters of a single instance (`field_count`, `children`, `points`, etc.). |
| `data_type_instance_count` ($N$) | Number of instances encoded in one timed call (`1` for scalar record, $N > 1$ for batch; per-row lists override file defaults). |
| `seed` | Deterministic within-language payload PRNG (`reproducibility.random_seed` / `BENCHMARK_SEED`). |
| `compression` | Runner-level post-step (`none`, `size_only`, `timed`), kept strictly outside `type_config`. |

Reserved meta-keys (`seed`, `type_id`, `data_type_instance_count`, `instance_count`, `batch_size`, `n`, `return_array_even_for_1_instance`) must never appear inside `type_config`.

### `make_one` and Determinism

```text
make_one(type_id, type_config_resolved, seed, instance_index) -> Instance
instances = [make_one(type_id, cfg, seed, i) for i in range(N)]
payload   = instances[0] if (N == 1 and adapter prefers scalar) else instances
```

- **Within-language determinism (required):** Identical `(seed, type_id, type_config, instance_index)` inputs must generate identical instances across runs of a given language runner.
- **Cross-language identity (not required):** Different language PRNG implementations need not emit byte-identical random strings or numbers, because formal rankings are always within-language.

### Portable Primitives and Batch Wire Shape

The portable primitive set (`all_available`) consists of `bool`, `int32`, `int64`, `float64`, and `utf8_string`. Timestamps are represented uniformly as `int64` epoch milliseconds UTC across both domain models and wire IDLs (`.proto`, `.avsc`, `signal.xml`).

When $N > 1$ and a schema-driven adapter requires an explicit container message, IDLs wrap items in a single top-level batch record so one timed encode call emits one framed message:

```text
Batch_<Type> {
  repeated <Type> items = 1;   // length == N
}
```

## Run Configurations and Compression Defaults

| Run Config | Expanded Cells | Notes |
|---|---|---|
| `smoke.yaml` | `message`, `telemetry` × `[1]` | Fast CI verification |
| `default.yaml` | Five `suite` types × `[1, 100]` | Standard publication matrix |
| `columnar-smoke.yaml` / `columnar.yaml` | `table`, `table_project` × `[1, 100, 10000]`; `nested_table`, `signal` × `[1, 100]` | `bytes`, `compression.mode: none` |
| `graph.yaml` | `graph` × `[1, 100]` | `bytes`, graph-capable serializers only |
| `array-smoke.yaml` / `array.yaml` | `grid`, `grid_window` × `[1]` | `compression.mode: none` |
| `tensor-smoke.yaml` / `tensor.yaml` | `tensor`, `tensor_view`, `prompt`, `shard`, `request` × `[1]` | `bytes`, `compression.mode: none` |

On `columnar.yaml`, `compression.mode: none` disables runner post-compression so `Size` reflects each format's native payload: `parquet` uses Snappy page compression (whereas `parquet-uncompressed` disables it), Arrow IPC streams are uncompressed, and ORC defaults to Zlib/ZSTD on C++/Java (`orc-uncompressed` disables it; `pyarrow` defaults to uncompressed, making Python `orc` and `orc-uncompressed` identical).

Inspect resolved cells locally with:

```bash
./scripts/resolve_run_config.py config/library/default.yaml --pretty
```

## Wall-Clock Budget and `TypeConfigHash`

Run configs specify a soft wall-clock budget proportional to registered serializer count $N_{\text{serializers}}$:

$$
T_{\text{soft}} = s_{10} \cdot \left\lceil \frac{N_{\text{serializers}}}{10} \right\rceil
$$

where $s_{10}$ (`soft_seconds_per_10_serializers`) defaults to 60 s. Exceeding $T_{\text{soft}}$ lowers subsequent cells to `reps_fallback` (50); exceeding `hard_cap_seconds` (600 s) halts cleanly at a repetition boundary (enforced in Python and Mojo; published Dashboard snapshots always require complete repetition ranges).

**`TypeConfigHash`** is the lowercase first 12 hex characters of the SHA-256 digest of canonical JSON (sorted keys, minimal separators) for the resolved `type_config`, allowing analysis to separate runs whose per-instance knobs differ under the same `TestDataName`.
