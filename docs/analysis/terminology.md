# Terminology

This page is the list of words this project uses. Other pages link here instead of writing a second definition.

This page defines the words. The procedures stay on the pages named at the end.

Source code in a language runner may still contain an older identifier. That identifier is not a new concept. The prohibited-words section says what to write in prose, on the Dashboard, and in the course.

---

## Prohibited words

| Do not write | Write | What the old word was standing in for |
| --- | --- | --- |
| **Fixture**, fixture | **Data type** | The kind of sample, such as `message` or `table`. |
| **Harness** | **Benchmark runner**, or **runner** after the first mention | The program for one language that times serializers and writes the CSV. |

### Fixture means data type {#fixture}

**Fixture** is prohibited in prose. The word is **data type**.

An older page that says “the document fixture” means the `document` data type. When that sentence is about one generated object, it means one instance of that data type.

Some runners still declare a source type called `Fixture`. That type holds one instance of the current data type. Leave the identifier in the source. A heading, a Dashboard label, or a new paragraph uses data type.

### Harness means benchmark runner {#harness}

**Harness** is prohibited in prose. The word is **benchmark runner**.

The architecture page keeps an old HTML anchor, `harness-contract-summary`, so links that already exist still open. New sentences use benchmark runner.

---

## Which word to write

| The sentence is about | Write |
| --- | --- |
| The kind of object (`message`, `table`, `graph`, `grid`) | **Data type** |
| The parent of that kind (`suite`, `columnar`, `graph`, `array`) | **Data set** |
| The program that times libraries and writes the CSV | **Benchmark runner** |
| How many objects go into one serialize call (`1` or `100`) | **Batch size** |
| How many times the timed loop runs | **Repetition**, or a **run mode** when you mean the preset |
| The in-memory API or the stream API | **I/O mode** |
| How heavy the run is (`smoke`, `all-single`, `full`, `research`) | **Run mode** |
| The encoded byte length | **Size**, or **payload size** |
| The compliance format id (`json`, `avro`, `protobuf`, …) | **Standard** |
| The binding that runs one library on the compliance cases | **Adapter** |
| A teaching group of formats | **Family** |
| Which trials remain after warmup | **Samples** |
| A page that lists the shapes and the size knobs | **Test data** (the page). In a sentence about one kind of object, write **data type**. |

---

## Data set

A **data set** is the parent of a data type. The Dashboard filter keeps the table inside one set. A serializer is measured on the sets its runner already supports. Membership is the `data_set` field on each type in [`schemas/data_catalog_v2.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/schemas/data_catalog_v2.yaml). The label contract is [`config/dimensions.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/dimensions.yaml).

| Data set | Data types | Where the cells are chosen |
| --- | --- | --- |
| `suite` | `message`, `document`, `telemetry`, `strings`, `event` | `config/library/default.yaml` and `config/library/smoke.yaml`. These five types are the publication matrix. |
| `columnar` | `table`, `table_project`, `nested_table`, `signal` | `config/library/columnar.yaml`, for the serializers named in that file. |
| `graph` | `graph` | `config/library/graph.yaml`, for the serializers named in that file. |
| `array` | `grid`, `grid_window` | `config/library/array.yaml`, for the serializers named in that file. |

Columnar, graph, and array do not appear in the default matrix. A runner measures them only from those configs.

This project is often called **the suite**. That is the repository and the measurement rules together. The data set id `suite` is narrower: it is only the five publication types. A sentence about sample data uses the data-set meaning. A sentence about the repository uses the project meaning.

`graph` is both a data set and the only data type inside that set. `array` is a data set. The data types inside it are `grid` and `grid_window`.

---

## Data type

A **data type** is the kind of sample object the runner serializes. It has one id, and it belongs to one data set. The CSV column is `TestDataName`. The Dashboard control is **Data type**.

The **type id** is that catalog key. `message` and `table` are type ids.

An **instance** is one concrete object of a data type.

**Batch size** is how many instances go into one serialize and deserialize call. The config key is `data_type_instance_count`. The usual values are `1` and `100`. Notes sometimes write `@n=1` and `@n=100`. On the Dashboard a batch cell can read **Data type · N instances**, for example Message · 100 instances.

A **type config** holds the size and shape knobs for one instance, such as `field_count: 8` or `points: 32`. Seed, type id, and batch size belong to other layers. The catalog lists the keys that must stay out of `type_config`.

A **cell** is one measured combination: a data type, its type config, and a batch size. `message` with N=100 is one cell.

The **type catalog** is `schemas/data_catalog_v2.yaml`. A **run config** is the file that chooses which cells a run measures, under `config/library/`.

**make_one** is the generator that builds a single instance from the type id, the resolved type config, the seed, and the instance index. The same inputs must produce the same instance inside one language. Payloads do not have to match across languages.

**Data model v2** is the version name of these public shapes.

| Data type | Data set | What one instance is |
| --- | --- | --- |
| `message` | `suite` | A flat record of mixed primitives, with no nested objects. |
| `document` | `suite` | A nested record: an id, a status, a small map, and a list of line items. |
| `telemetry` | `suite` | A numeric series with a source name, a timestamp, tags, and values. |
| `strings` | `suite` | A list of text values, used to show string cost. |
| `event` | `suite` | One event envelope. A batch is N envelopes in one call. |
| `table` | `columnar` | One wide row of named scalars. The batch size is the row count. |
| `table_project` | `columnar` | The same row as `table`. Deserialize returns one float column. |
| `nested_table` | `columnar` | A struct plus a list of structs. |
| `signal` | `columnar` | A fixed header, two strings, and one repeating group. SBE, Arrow, and Parquet share this record on this suite. |
| `graph` | `graph` | One graph with shared nodes and one reference cycle. |
| `grid` | `array` | One dense 512×512 array of 64-bit floats. |
| `grid_window` | `array` | The same array on write. The read is an interior window. |

Field lists, defaults, and fidelity rules for each type are on [Test data](test_data_configuration.md). Array libraries are on [Array bindings](array_bindings.md).

A tree codec that cannot store a shared node returns unsupported on `graph`. The runner skips that serializer for the cell, and fidelity stays unused.

---

## Benchmark runner

A **benchmark runner** is the program in one language directory. It builds the sample, calls each serializer, checks that the value came back, and writes `logs/<language>/*.csv`. **Runner** is the short name after the first mention.

A **language** is one of those fourteen programs: C, C#, C++, Fortran, Go, Java, JavaScript, Kotlin, Mojo, PHP, Python, Rust, Swift, and Zig. The CSV id is the short form, such as `csharp`, `cpp`, or `javascript`.

A **serializer** is one registered library in that language. `SerializerName` is the stable log key and the name on the Dashboard. One library can have more than one row when the runner times more than one layout, as the four Dagr rows do.

A **row**, on the Dashboard, is that serializer’s published numbers for the current language, standard, data set, data type, and batch size. In a CSV, a row is one repetition of one serializer.

The speed run calls one library through a wrapper that implements prepare, serialize, and deserialize. Compliance uses **adapter** for a different binding. See [Adapter](#adapter).

**Analysis** is the `analyze-benchmarks` program. It reads the CSV, drops warmup, may drop outliers, and writes the summaries the Dashboard packs. The runner writes every successful repetition, and the cleaning happens in analysis.

The **Dashboard** is the published interactive view of those summaries. An **Overview** is the language page under Languages. The Overview lists the roster and the caveats. The numbers live on the Dashboard.

---

## Standard

A **standard** is the compliance format id for a serializer. The ids live in [`compliance/serializer-standards.json`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/compliance/serializer-standards.json). They include `json`, `yaml`, `toml`, `avro`, `protobuf`, `parquet`, `orc`, `arrow`, `sbe`, `hdf5`, and the other ids in that file. The Dashboard **Standard** filter uses them. **All** lists every serializer for the selected languages.

An empty compliance list is the standard `custom`. The Dashboard label is **No public spec**. Those serializers stay on the speed table and stay unscored in compliance.

A serializer that lists two ids keeps one timed row. C# `MS Bond Json` lists `json` and `bond`. The timed row uses the primary id `json`, from the dimension contract.

A **family** is a teaching group: JSON, schemaless binary, schema-driven, language-native, or columnar. A family is coarser than a standard. `yaml` is its own standard. Rankings use the standard, together with the language, the data set, and the data type.

The categories page calls this grouping a **family**. Older sentences say **category** for the same grouping.

The family name Columnar and the data set `columnar` answer different questions. SBE sits in the schema-driven family, its data set is `columnar`, and its standard is `sbe`.

---

## I/O mode

An **I/O mode** is the API the runner called.

| Dashboard label | CSV `StringOrStream` | Meaning |
| --- | --- | --- |
| **Bytes mode** | `bytes`, `buffer`, or a similar in-memory name | The library’s in-memory buffer API, or that language’s equivalent. |
| **String mode** | `string`, used by C# | The in-memory path. Multi-language tables still show it as bytes mode. For many binary libraries that string is Base64 of the raw bytes. |
| **Stream mode** | `stream` or `Stream` | A stream-style write and a stream-style read. |

Bytes mode and stream mode name the programming interface. Either API can carry a short record or a long one. Payload size is the separate `Size` column.

**StreamMode** says how real a stream row is.

| CSV value | Meaning |
| --- | --- |
| `native` | Timed serialize and timed deserialize both use the library’s stream, reader, or writer API. |
| `text_on_stream` | The library writes or reads text through a writer or reader attached to a stream. |
| `adapted` | The runner builds the full in-memory result, then dumps it to a stream, or the reverse. |

Bytes and string rows may leave `StreamMode` empty. A second label on the same bytes API must not be emitted as a stream row. Do not mark a row `native` when either timed half is still the bytes API.

### Parent row

The published group is one language, one serializer, one standard, one data set, one data type, and one batch size. I/O mode is not part of that key. The **parent row** is the number that group shows. Rankings use the parent row.

The publication matrix times the in-memory API. A second level is kept only for the opt-in list in the dimension contract: honesty `native` or `text_on_stream`, batch size 100, an absolute pooled median gap over 10%, and a 95% confidence interval that excludes 0. An adapted stream is not a second level. Java, Kotlin, Swift, and Rust stay on the in-memory row until their runners measure a real second API.

When both stored levels have the same payload size, within 2%, the parent is the arithmetic mean of the two medians. When the string path is Base64 of the raw bytes, a size ratio of about 3/4, the parent is the raw-byte measurement and the string path is the child.

The Dashboard **I/O** control opens a stored second level.

---

## Run mode

A **run mode** is how heavy the experiment is. The counts live under `modes:` in [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml). Scripts read those counts through `bench_mode_reps`.

| Run mode | Repetitions | What it is for |
| --- | --- | --- |
| `smoke` | 2 | A minimal check, including a fast CI path. |
| `all-single` | 10 | A short pass over the matrix. |
| `full` | 100 | A publication-quality run, the usual source of packed Dashboard numbers. |
| `research` | 500 | A high sample count for a statistical study. |

A run mode changes how many repetitions are logged, and sometimes which run config the script selects. It leaves the meaning of stream mode unchanged.

A **repetition** is one timed serialize plus one timed deserialize. `RepetitionIndex` numbers them from 0.

**Warmup** is that first successful repetition. The runner writes index 0. Analysis drops it when warmup exclusion is on. The configured warmup length is 1, so a `full` run of 100 logged repetitions leaves about 99 samples in the summary.

---

## What the timer includes

**Prepare** runs once per cell, before the loop, and it is not timed. It may load a schema, build an encoder, bind a type-specific function, turn the suite value into the library’s in-memory message, and allocate a buffer the loop will reuse. Serialize is the step that writes the output bytes.

**Serialize** is timed. It walks that in-memory message and emits bytes, or the language’s in-memory equivalent.

**Deserialize** is timed. It reads those bytes and rebuilds the library’s message.

**Fidelity** runs after deserialize, and it is not timed. It asks whether the value still means the same thing. `FidelityScore` of `1.0` means the check passed. A failed round trip goes to the errors file and stays out of the speed table. `mean_fidelity` is this check. A match against a specification is compliance.

A **group**, in the published summaries, is one parent row: language, serializer, standard, data set, data type, and batch size. Raw CSV rows still carry `StringOrStream`, which analysis uses when it builds an optional I/O child.

**Payload** is the encoded bytes. **Size** is their length. The summary field is `median_size_bytes`.

**Compression**, when it is a post-step on those bytes, is outside `type_config`. A name such as `parquet-uncompressed` is a separate serializer row.

The **seed** (`reproducibility.random_seed`, or `BENCHMARK_SEED`) makes generation deterministic inside one language. **Block shuffle** is the default schedule: inside one cell and one I/O mode, the runner reshuffles serializer order on every repetition. The shuffle uses its own generator, separate from the generator that builds payloads.

The full timing contract is [Timing honesty](TIMING_HONESTY.md).

---

## Dashboard numbers

A **rank** orders parent rows inside one language, one standard, one data set, and one data type. The metrics catalog treats median total time as the default speed rank. The Dashboard opens on Ops/s, which divides one second by the mean total time, so the opening chart and the median rank can order two close rows differently. Absolute times across languages are orientation. The comparison this suite is built for stays inside one language.

| Word | Meaning here |
| --- | --- |
| **Latency** | Time to serialize, to deserialize, or both. The CSV stores nanoseconds. Published tables often show microseconds (nanoseconds ÷ 1000). The Dashboard **Latency (ns)** tab shows nanoseconds. Lower is faster. |
| **Ops/s** | Operations per second. The displayed throughput is `1e9 / total_mean_ns`. Higher is faster. Average operations per second is not the inverse of average latency, so the two views can order rows differently. |
| **Median** | The middle value after the kept trials are sorted. `total_median_ns` is the default speed rank. A median moves less than a mean when one trial stalls. |
| **Mean** | The arithmetic average. Throughput uses the mean total time. The confidence interval is on the mean. |
| **Percentile** | The value below which that share of trials falls. **P95** is the 95th percentile. **P99** is the 99th. They describe the slow trials. |
| **IQR** | The interquartile range: the spread of the middle half of the trials, from the 25th percentile to the 75th. |
| **Outlier** | A trial far from that middle half. The default rule builds fences at 1.5 times the IQR. If serialize, deserialize, or total time falls outside its fence, analysis drops the whole repetition so the three series stay paired. The runner does not apply this rule. |
| **Samples** | The Dashboard control for which trials feed the tables after warmup. `iqr_1.5` is the default. `all` keeps every post-warmup trial. `iqr_3` uses wider fences. `winsorize_5_95` clips the extremes and keeps the count. |
| **Confidence interval** | A 95% range for the mean total time, from resampling the trials in that session. It describes that session. |
| **Effect size** | How large a gap is. The suite reports Cliff’s delta against the fastest serializer in the group. Fuller profiles also report Hedges’ g. A multi-way rank is exploratory. A confirmatory check of two versions is a pairwise run, `--compare-a` and `--compare-b`. |
| **Pareto** | A row is on the frontier when no other row in the same view is at least as fast and at least as small, and strictly better on speed or on size. The ops view maximizes operations per second. The latency view minimizes mean total time. Both views minimize median size. |
| **Baseline** | On the roster, the serializer the other rows are compared with. In the regression gate, a saved run in `reports/baseline.json` that a later run is checked against. |
| **Claim level** | How far a sentence about the numbers may reach. **L1** is one session on one machine. The packed Dashboard is L1. **L2** is three or more sessions with the same machine id. **L3** is two or more machine ids. |
| **Machine id** | A short fingerprint of CPU model, architecture, OS, core count, and hostname material. It separates hosts when sessions are merged. It is not a security identifier. |

The column dictionary is [Metrics](METRICS.md). The cleaning rules are [Methodology](ANALYSIS_METHODOLOGY.md). What a sentence may claim is [Claims and replication](CLAIMS_AND_REPLICATION.md).

---

## Compliance and experiments

### Adapter

An **adapter** is the binding that runs one serializer against one standard in a compliance test. It decodes each catalog case with that library’s own API. Python stores the binding in `python/src/compliance/adapters.py` as a name, a format id, and a decode function. An encode function is present only when that library can also write the case. A language with no adapter for a standard has an empty cell. The rules for adding one are on [Language adapters](../compliance/adapters.md).

**Compliance** is a separate check from the speed run. A **case** is one input tied to one cited section of a specification, with an expected accept or reject. The result is pass or fail for that section. Speed and fidelity are separate results.

A **compliance corpus** is the frozen set of those inputs for one standard, under `compliance/data/`. A standard with no corpus stays unscored.

An **experiment** answers one everyday question. It keeps the libraries that could be the answer, and it times one record shape. The main Dashboard is the full set of registered rows. An experiment is the smaller set that fits the question.

---

## Names in the CSV

| CSV column | Term on this page |
| --- | --- |
| `Language` | Language id |
| `SerializerName` | Serializer |
| `SerializerVersion` | Installed version of that library |
| `TestDataName` | Data type id |
| `DataTypeInstanceCount` | Batch size |
| `TypeConfigHash` | Short hash of the resolved type config |
| `StringOrStream` | I/O mode |
| `StreamMode` | Stream honesty |
| `RepetitionIndex` | Repetition; `0` is warmup in the raw log |
| `Repetitions` | How many repetitions the run mode configured |
| `TimeSer`, `TimeDeser`, `TimeSerAndDeser` | Serialize, deserialize, and combined time, in nanoseconds |
| `Size` | Payload size in bytes |
| `FidelityScore` | Fidelity for that repetition |

---

## Related pages

| Topic | Page |
| --- | --- |
| Shapes, knobs, and generators | [Test data](test_data_configuration.md) |
| Bytes, stream, and run presets | [Modes](modes.md) |
| Folder layout and the runner contract | [Architecture](architecture.md) |
| Prepare versus the timed calls | [Timing honesty](TIMING_HONESTY.md) |
| Families | [Categories](serialization_categories.md) |
| Warmup, IQR, and effect sizes | [Methodology](ANALYSIS_METHODOLOGY.md) |
| Column names | [Metrics](METRICS.md) |
| L1, L2, and L3 | [Claims and replication](CLAIMS_AND_REPLICATION.md) |
| One-question tests | [Experiments](../experiments/index.md) |
| Specification cases | [Compliance](../dashboard/#compliance) |
| Live numbers | [Dashboard](../dashboard/) |
