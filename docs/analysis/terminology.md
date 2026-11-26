# Terminology

This glossary is the single authoritative vocabulary for the documentation, Dashboard, and course. Other specification pages link here rather than repeating definitions; detailed procedures live on their owning protocol pages listed at the end. Legacy source-code identifiers (for example, a struct named `Fixture` in a runner) may remain in code without redefining prose terminology.

## Prohibited Prose Terms

| Avoid in prose | Preferred term | Reason |
|---|---|---|
| **Fixture**, fixture | **Data type** (or **instance** for one generated value) | Avoids conflating logical payload types (`message`, `table`) with unit-test setup scaffolding. |
| **Harness** | **Benchmark runner** (**runner** after first mention) | Precisely names the per-language executable that executes timed loops and writes CSV logs. |

<a id="fixture"></a><a id="harness"></a>

Legacy anchors `#fixture`, `#harness`, and `architecture.md#harness-contract-summary` remain active for backward compatibility; all new prose uses **data type** and **benchmark runner**.

## Core Experimental Entities

### Data set {#data-set}

A **data set** is the top-level workload family grouping related data types (`suite`, `columnar`, `graph`, `array`, `tensor`), defined under `data_sets` in [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml) and stamped on every catalog entry in [`schemas/data_catalog_v2.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/schemas/data_catalog_v2.yaml). Serializers are measured only on the sets mapped to them in `serializer_data_sets` (defaulting to `suite` when omitted). Note that the word *suite* refers either to the entire project (context: repository and protocol) or narrowly to the `suite` data set (`message`, `document`, `telemetry`, `strings`, `event`). Full matrix and schemas: [Data sets](test_data_configuration.md).

### Data type, instance, batch size, and cell

- **Data type (type id):** A named sample schema belonging to one data set (CSV column `TestDataName`; Dashboard control **Data type**), such as `message`, `table`, `graph`, `grid`, or `tensor`.
- **Instance:** One concrete generated object of a data type produced by `make_one(type_id, type_config, seed, instance_index)`.
- **Batch size ($N$):** Number of instances passed to a single serialize/deserialize call (`data_type_instance_count`, typically `1` or `100`, written `@n=1` or `@n=100`).
- **Type config:** Per-instance shape knobs (such as `field_count: 8` or `points: 32`), hashed canonically into `TypeConfigHash`.
- **Cell:** One measured workload point `(data_type, type_config, batch_size)` selected by a **run config** under `config/library/`.
- **Data model v2:** The current cross-language specification of the 17 logical data types.

### Benchmark runner, language, serializer, and row

- **Benchmark runner (runner):** The standalone program in one of the fourteen language directories (`c`, `csharp`, `cpp`, `fortran`, `go`, `java`, `javascript`, `kotlin`, `mojo`, `php`, `python`, `rust`, `swift`, `zig`) that executes timed trials and writes `logs/<lang>/*.csv`.
- **Serializer:** One registered codec configuration identified by a stable `SerializerName`. One library may register multiple rows for distinct wire layouts or compression settings (for example, `parquet` and `parquet-uncompressed`, or the four `dagr-*` layouts).
- **Row:** In raw CSVs, one timed repetition of one serializer; on the Dashboard, one published parent group summarizing all kept repetitions for a `(language, serializer, standard, data set, data type, batch size)` tuple.
- **Analysis:** The `analyze-benchmarks` package that ingests raw CSVs, applies warmup/outlier policies, and exports statistics for the Dashboard.

### Standard {#standard}

A **standard** is the wire-format specification a library implements, stored as a compliance format id in [`compliance/serializer-standards.json`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/compliance/serializer-standards.json) (e.g., `json`, `protobuf`, `avro`, `cbor`, `parquet`, `sbe`, `hdf5`). Libraries without a public specification receive the standard `custom` (Dashboard label **No public spec**) and remain unscored in compliance. A serializer implementing two specifications retains one timed row under its primary standard id (`config/dimensions.yaml`).

A **family** (`JSON`, `schemaless binary`, `schema-driven`, `language-native`, `columnar`) is a coarser pedagogical grouping ([Families](families.md)); formal rankings always slice by **standard**, not family.

## Measurement, Scheduling, and Modes

- **Prepare:** Untimed per-cell setup executed before the repetition loop (schema compilation, encoder initialization, domain-to-native conversion, buffer allocation).
- **Serialize / Deserialize:** The two timed operations executed on every repetition, emitting and parsing the encoded **payload** whose length in bytes is **size** (`median_size_bytes`).
- **Fidelity:** Untimed post-deserialize semantic equivalence check (`FidelityScore = 1.0` on pass). Failing round trips are written to `*.errors.csv` and excluded from speed tables.
- **I/O mode (`StringOrStream`) & stream honesty (`StreamMode`):** Distinguishes in-memory buffer calls (`bytes`) from streaming calls (`stream`), tagged `native`, `text_on_stream`, or `adapted`. Details and parent-row folding rules: [I/O & run modes](modes.md).
- **Run mode:** Repetition preset (`smoke`, `all-single`, `full`, `research`) defined in `config/benchmark_config.yaml` ([I/O & run modes](modes.md#part-2-run-modes-how-heavy-the-experiment-is)).
- **Repetition & warmup:** One timed serialize + deserialize cycle (`RepetitionIndex` starting at `0`). Runners always log repetition `0`; analysis drops it as warmup when `exclude_warmup` is enabled.
- **Seed & block shuffle:** Deterministic payload generation (`BENCHMARK_SEED`) paired with per-repetition Fisher–Yates reshuffling of serializer execution order ([Architecture](architecture.md#timed-trial-schedule)).
- **Compression:** Optional post-step outside `type_config`; format-internal compression overrides (e.g., `parquet-uncompressed`) are distinct serializer rows.

## Statistical and Evaluation Terms

| Term | Definition |
|---|---|
| **Latency** | Elapsed serialize, deserialize, or combined time (stored in nanoseconds; reported in µs or ns; lower is faster). |
| **Throughput (`ops/s`)** | Inverse of mean total latency, $10^9 / \bar{t}_{\text{ns}}$ (higher is faster). Because $1/\bar{t} \neq \overline{1/t}$, throughput and median-latency ranks can differ on close peers. |
| **Median / Mean / P95 / P99** | Central tendency (`total_median_ns` is the default rank; `total_mean_ns` drives `ops/s` and CIs) and upper tail quantiles. |
| **IQR & outlier** | Interquartile range $\text{IQR} = Q_3 - Q_1$; default Tukey fences ($k = 1.5$) drop a repetition all-or-nothing if any of its three timings lies outside bounds. |
| **Samples policy** | Dashboard selector choosing post-warmup trial cleaning: `iqr_1.5` (default), `all`, `iqr_3`, or `winsorize_5_95`. |
| **Confidence interval (CI)** | Percentile bootstrap 95% interval for the session mean total latency. |
| **Effect size** | Magnitude of difference versus the group's fastest reference: nonparametric Cliff's $\delta$ and standardized mean difference Hedges' $g$. Multi-way Dashboard ranks are exploratory; confirmatory comparisons use pairwise A/B (`--compare-a` / `--compare-b`). |
| **Pareto frontier** | Set of rows not simultaneously dominated in both speed and `median_size_bytes` within the active view. |
| **Baseline** | Reference serializer in a Dashboard comparison, or a saved `reports/baseline.json` snapshot used by the regression gate. |
| **Claim level (L1 / L2 / L3)** | Evidentiary scope: L1 = single session/host (default Dashboard); L2 = $\ge 3$ sessions on one `machine_id`; L3 = $\ge 2$ distinct `machine_id` hosts. |
| **Machine id** | Non-cryptographic fingerprint of CPU model, architecture, OS, core count, and host metadata stored in `*.configs.json` sidecars to separate hosts across multi-session merges. |

## Compliance and Experiments

### Adapter {#adapter}

An **adapter** is a specification-compliance binding that invokes one library's decoder (and optionally encoder) on a frozen **compliance corpus** under `compliance/data/`. Each **case** maps to a cited specification section with an expected accept/reject outcome, scored independently of speed and fidelity ([Language adapters](../compliance/adapters.md)).

An **experiment** is a targeted single-question study (such as payload scaling or FFI marshaling overhead) running a curated subset of libraries on one focused workload ([Experiments](../experiments/index.md)).

## CSV Column-to-Term Map

| CSV column | Canonical term |
|---|---|
| `Language` | Language id |
| `SerializerName` / `SerializerVersion` | Serializer / installed library version |
| `TestDataName` / `DataTypeInstanceCount` / `TypeConfigHash` | Data type id / batch size $N$ / canonical hash of resolved `type_config` |
| `StringOrStream` / `StreamMode` | I/O mode / stream honesty (`native`, `text_on_stream`, `adapted`) |
| `RepetitionIndex` / `Repetitions` | Trial index (`0` = warmup) / configured repetition count |
| `TimeSer`, `TimeDeser`, `TimeSerAndDeser` | Serialize, deserialize, and combined time (ns) |
| `Size` / `FidelityScore` | Encoded payload size (bytes) / semantic round-trip score (`1.0` = pass) |

## Owning Protocol Pages

- [Data sets](test_data_configuration.md) · [Architecture](architecture.md) · [Timing contract](TIMING_HONESTY.md) · [I/O & run modes](modes.md) · [Families](families.md) · [Methodology](ANALYSIS_METHODOLOGY.md) · [Metrics](METRICS.md) · [Claims and replication](CLAIMS_AND_REPLICATION.md)
