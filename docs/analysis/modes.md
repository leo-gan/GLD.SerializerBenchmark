# I/O and Run Modes

This project uses the word **mode** in two orthogonal senses: **I/O mode** selects which programming interface is called (`bytes` vs. `stream`), whereas **run mode** selects how many repetitions and which matrix preset an experiment executes (`smoke` through `research`). Batch size $N$ (1 vs. 100 instances per call) is a third independent axis specified under [Data sets](test_data_configuration.md).

```text
  Run mode        → repetition budget & matrix preset (smoke | all-single | full | research)
  I/O mode        → API surface (bytes in-memory buffer vs. stream reader/writer)
  Data type × N   → payload schema and batch cardinality (e.g., document @ n=1 or n=100)

  One raw CSV row = (Language, SerializerName, TestDataName, N, StringOrStream, RepetitionIndex)
```

---

## Part 1 — I/O Modes and Stream Honesty

Real applications serialize either into contiguous in-memory buffers (caches, small RPC frames) or through streaming readers and writers (files, network sockets). Note that **`bytes` and `stream` name the API surface, not payload size**—either interface can carry small or large records.

| Dashboard Label | CSV `StringOrStream` | Semantics |
|---|---|---|
| **Bytes mode** | `bytes` (legacy C# snapshots: `string`) | In-memory buffer serialize/deserialize. On legacy C# `string` logs, binary codecs timed Base64 strings (~4/3 raw wire length). |
| **Stream mode** | `stream` (legacy C#: `Stream`) | Stream/reader/writer API serialize/deserialize. |

### Three Levels of Stream Honesty {#three-levels-of-stream-honesty}

Not every library exposes an incremental streaming codec. Every newly emitted stream CSV row must populate `StreamMode` with one of three machine-readable labels (displayed as a chip on the Dashboard):

| `StreamMode` | Timed Implementation | Interpretation |
|---|---|---|
| `native` | Both timed serialize and timed deserialize invoke the library's native stream, reader, or writer API. | Valid evidence for streaming performance. |
| `text_on_stream` | The library writes/reads text through a writer or reader bound to a stream (e.g., `JsonTextWriter`, `std.Io.Writer`). | Real streaming text interface; distinct from binary incremental framing. |
| `adapted` | The runner encodes the full in-memory buffer first and writes it to a stream (or reads all bytes before decoding). | Times track `bytes` closely; **not** evidence of incremental I/O. |

Normative rules:
- `bytes` rows may leave `StreamMode` blank.
- Never tag a row `native` if either timed half still uses the `bytes` API.
- If a language runner has no distinct stream path (e.g., JavaScript, Mojo), emit `bytes` rows only.

### Dimension Contract and Parent-Row Folding

Published Dashboard rows are keyed by:

```text
(Language, SerializerName, Standard, DataSet, TestDataName, DataTypeInstanceCount)
```

Standard labels come from [`compliance/serializer-standards.json`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/compliance/serializer-standards.json) (with multi-standard primary resolution and optional I/O rules in [`config/dimensions.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/dimensions.yaml)); data-set membership comes from `data_sets` and `serializer_data_sets` in [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml).

**Optional I/O folding:** `StringOrStream` is not part of the published group key. The publication matrix times the in-memory `bytes` API by default; a second I/O level is retained in `optional[]` only for serializers on the contract's opt-in list meeting four criteria: `StreamMode` is `native` or `text_on_stream`, $N = 100$, the absolute pooled median difference exceeds $10\%$, and the 95% confidence interval excludes $0$. Adapted streams never create a second published level.

- **Equal-size pair (within 2%):** The published parent row reports the arithmetic mean of the two level medians, and the Dashboard **I/O** toggle expands both levels.
- **Legacy Base64 `string` vs. raw `bytes` (size ratio $\approx 3/4$):** Payloads are never averaged; the raw-byte measurement is the parent row and the Base64 `string` path is attached as a child.

---

## Part 2 — Run Modes {#part-2-run-modes-how-heavy-the-experiment-is}

Run modes are configured under `modes:` in `config/benchmark_config.yaml`. Runner scripts must query `bench_mode_reps` rather than hard-coding repetition counts.

| Run Mode | Repetitions | Statistical Role | Typical Use |
|---|---:|---|---|
| `smoke` | 2 | Minimal functional verification | Local sanity check and CI smoke jobs |
| `all-single` | 10 | Fast full-matrix sweep | Pre-publication spot check across all cells |
| `full` | 100 | Publication baseline (~99 post-warmup samples) | Generating Dashboard snapshots via `sync-data.py` |
| `research` | 500 | High-power estimation | Tight bootstrap CIs and formal statistical studies |

Example invocations:

```bash
./scripts/run-all-benchmarks.sh --mode smoke --lang python
./scripts/run-all-benchmarks.sh --mode full --lang rust
```

Run mode alters repetition count (and optionally which run config a script selects); it never changes serializer definitions, data-type schemas, warmup logging (`RepetitionIndex = 0` is always logged by runners and excluded by analysis), or the [timing contract](TIMING_HONESTY.md).

## Related Pages

- [Terminology](terminology.md) · [Benchmark architecture](architecture.md#timed-trial-schedule) · [Data sets](test_data_configuration.md) · [Analysis methodology](ANALYSIS_METHODOLOGY.md) · [Metrics catalog](METRICS.md)
