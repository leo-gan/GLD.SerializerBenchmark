# Python — Benchmark Results

**Generated:** 2026-07-24T19:44:42.720613

This page is a **snapshot of measured numbers** for Python on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [Python overview](index.md) |
| I/O modes and run modes | [Modes](../analysis/modes.md) |
| How CSVs become these tables | [Analysis methodology](../analysis/ANALYSIS_METHODOLOGY.md) |
| What each metric means | [Metrics catalog](../analysis/METRICS.md) |
| All languages’ result links | [Results summary](../analysis/BENCHMARK_SUMMARY.md) |

## How to read these tables

Compare serializers **inside this language**. Prefer the same [category](../analysis/serialization_categories.md) (for example JSON with JSON) and the same [I/O mode](../analysis/modes.md) so the comparison stays fair.

| Term | Meaning |
|------|---------|
| **data type** | Sample shape: `message`, `document`, `telemetry`, `strings`, or `event` (CSV `TestDataName`; older text may say “fixture”) |
| **bytes mode** | In-memory buffer API (encode to bytes / decode from a buffer). On C# this is often the **string** path — see [Modes](../analysis/modes.md). |
| **stream mode** | Stream-style API (write/read through a stream). May be native or adapted — see [Modes](../analysis/modes.md). |
| **µs** | Microseconds (one microsecond = 1000 nanoseconds). Tables show µs; raw CSVs store nanoseconds. |
| **Ops/s** | Operations per second from mean total time — higher is faster |
| **Bold** | Best value in that column (lowest time/size; highest ops/s). Ties are all bolded. |

Rows are sorted by **serializer name** (easy lookup), not by rank. Batch workloads appear as **Data type · N instances** (for example Message · 100 instances). Default multi-serializer tables show **high-importance** metrics only; pairwise / version A/B reports can show the full set ([Metrics](../analysis/METRICS.md)).

> **Stream honesty:** stream rows labeled as **native** 60, **adapted** 100. Only **`native`** (and carefully **`text_on_stream`**) support stream-API performance claims. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| avro:1.12.2 | 468 | 264 | 204 | 25.9K | **9.03K** | 1804 | **1.00** |
| cbor2:6.1.3 | 306 | 203 | 102 | 34.7K | 13.6K | 1794 | **1.00** |
| cloudpickle:3.1.2 | 311 | 233 | 78.3 | 23.6K | 13.6K | 1846 | **1.00** |
| dill:0.4.1 | 2,170 | 2,080 | 88.4 | 5.66K | 13.6K | 1819 | **1.00** |
| flatbuffers:25.12.19 | 2,290 | 1,820 | 477 | 8.37K | 18.7K | 1858 | **1.00** |
| json:python-3.14.0 | 327 | 191 | 136 | 29.3K | 19.7K | 1830 | **1.00** |
| mashumaro:3.22 | 154 | 45 | 108 | 79.7K | 19.7K | 1857 | **1.00** |
| msgpack:1.2.1 | 109 | 53.8 | 53.9 | 86.6K | 13.6K | 1778 | **1.00** |
| msgspec:0.21.1 | 69.9 | 30 | 39.3 | 123K | 14.7K | 1828 | **1.00** |
| msgspec-msgpack:0.21.1 | 47.1 | **17.4** | 29.1 | 158K | 9.69K | 1801 | **1.00** |
| orjson:3.11.9 | 79 | 29.6 | 48.1 | **171K** | 19.7K | 1873 | **1.00** |
| pickle:python-3.14.0 | 196 | 118 | 78.6 | 45.2K | 13.6K | 1888 | **1.00** |
| protobuf:7.35.1 | **39.1** | 18.2 | **20.5** | 120K | 10.1K | 1753 | **1.00** |
| pydantic:2.13.4 | 513 | 267 | 246 | 26.9K | 21.4K | 1787 | **1.00** |
| rapidjson:1.23 | 296 | 157 | 138 | 48.1K | 19.7K | 1817 | **1.00** |
| serpyco-rs:1.21.0 | 124 | 46.4 | 76.5 | 92.8K | 19.7K | 1860 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro:1.12.2 | 13.8 | 13.8 | 14.3 | 14.3 |
| cbor2:6.1.3 | 9.69 | 9.72 | 11 | 11.2 |
| cloudpickle:3.1.2 | 17.2 | 17 | 16.8 | 16.9 |
| dill:0.4.1 | 62.1 | 62 | 62.3 | 62.1 |
| flatbuffers:25.12.19 | 36.9 | 36.9 | 38.1 | 37.6 |
| json:python-3.14.0 | 12.8 | 12.7 | 13.6 | 13.6 |
| mashumaro:3.22 | 4.49 | 4.43 | 5.15 | 5.12 |
| msgpack:1.2.1 | 4.42 | 4.5 | 5.56 | 5.62 |
| msgspec:0.21.1 | 2.44 | 2.5 | 3.71 | 3.73 |
| msgspec-msgpack:0.21.1 | **1.78** | **1.8** | 3.02 | 3.01 |
| orjson:3.11.9 | 1.84 | 1.86 | **2.35** | **2.37** |
| pickle:python-3.14.0 | 7.85 | 7.88 | 8.95 | 8.8 |
| protobuf:7.35.1 | 3.5 | 3.55 | 3.9 | 3.99 |
| pydantic:2.13.4 | 14.7 | 14.6 | 15.1 | 15 |
| rapidjson:1.23 | 7.79 | 7.83 | 8.44 | 8.5 |
| serpyco-rs:1.21.0 | 4.24 | 4.22 | 4.75 | 4.71 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro:1.12.2 | 35K | 0.71K | 49K | 1.2K | 72K | 2.6K | 50K | 0.91K | 49K | 1.2K |
| cbor2:6.1.3 | 40K | 0.87K | 65K | 1.9K | 100K | 4.1K | 80K | 2.1K | 62K | 1.8K |
| cloudpickle:3.1.2 | 24K | 0.74K | 35K | 1.4K | 58K | 4.7K | 54K | 2.3K | 49K | 3.3K |
| dill:0.4.1 | 5.6K | 0.11K | 8.8K | 0.22K | 16K | 0.68K | 13K | 0.29K | 12K | 0.33K |
| flatbuffers:25.12.19 | 8.4K | 0.13K | 16K | 0.25K | 27K | 0.51K | 13K | 0.17K | 19K | 0.34K |
| json:python-3.14.0 | 45K | 1.6K | 63K | 2.9K | 78K | 4.4K | 70K | 2.7K | 32K | 0.62K |
| mashumaro:3.22 | 81K | 1.8K | 140K | 3.9K | 220K | 8.3K | 220K | 4K | 140K | 3.4K |
| msgpack:1.2.1 | 110K | 2.6K | 170K | 5.1K | 230K | 9.1K | 230K | 5.3K | 190K | 5.9K |
| msgspec:0.21.1 | 210K | 7.4K | 280K | 9.4K | 410K | 23K | 270K | 5.9K | 180K | 4.3K |
| msgspec-msgpack:0.21.1 | **260K** | 8.3K | **340K** | 12K | **560K** | **35K** | 300K | 6.9K | **320K** | 13K |
| orjson:3.11.9 | 230K | 5.1K | 340K | 7.4K | 540K | 18K | **430K** | 5.3K | 290K | 5.2K |
| pickle:python-3.14.0 | 48K | 1.3K | 71K | 2.3K | 130K | 7.3K | 110K | 2.9K | 100K | 4.5K |
| protobuf:7.35.1 | 180K | **11K** | 230K | **14K** | 290K | 32K | 230K | **7.3K** | 240K | **24K** |
| pydantic:2.13.4 | 36K | 0.71K | 50K | 1.3K | 68K | 2.3K | 71K | 1.8K | 41K | 0.53K |
| rapidjson:1.23 | 72K | 2K | 110K | 4.1K | 130K | 5K | 130K | 3.6K | 39K | 0.6K |
| serpyco-rs:1.21.0 | 120K | 2.4K | 180K | 4.9K | 240K | 10K | 250K | 4.5K | 170K | 3.8K |

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one **data type** (and batch size):

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that data type so the picture stays readable. Tables above still list everyone.
- Each image also prints the data type, source CSV, modes, and sample size.

### Document · 1 instance

![Document · 1 instance](../analysis/plots/violin/python_document@n=1.png){ width="80%" }

### Document · 100 instances

![Document · 100 instances](../analysis/plots/violin/python_document@n=100.png){ width="80%" }

### Event · 1 instance

![Event · 1 instance](../analysis/plots/violin/python_event@n=1.png){ width="80%" }

### Event · 100 instances

![Event · 100 instances](../analysis/plots/violin/python_event@n=100.png){ width="80%" }

### Message · 1 instance

![Message · 1 instance](../analysis/plots/violin/python_message@n=1.png){ width="80%" }

### Message · 100 instances

![Message · 100 instances](../analysis/plots/violin/python_message@n=100.png){ width="80%" }

### Strings · 1 instance

![Strings · 1 instance](../analysis/plots/violin/python_strings@n=1.png){ width="80%" }

### Strings · 100 instances

![Strings · 100 instances](../analysis/plots/violin/python_strings@n=100.png){ width="80%" }

### Telemetry · 1 instance

![Telemetry · 1 instance](../analysis/plots/violin/python_telemetry@n=1.png){ width="80%" }

### Telemetry · 100 instances

![Telemetry · 100 instances](../analysis/plots/violin/python_telemetry@n=100.png){ width="80%" }

## How to regenerate this page

Snapshots are produced on a developer machine. After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l python   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.
    
    - **Source CSV:** `logs/python/2026-07-24-193629.csv`
    - run=2026-07-24-193629
    - language=python
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: python=3.14.0, node=24.15.0, dotnet=9.0.316
    - git=7431b57 dirty
    - seed=42
    - warmup_reps=1
    - serializers=16
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `avro` @ 1.12.2
      - `cbor2` @ 6.1.3
      - `cloudpickle` @ 3.1.2
      - `dill` @ 0.4.1
      - `flatbuffers` @ 25.12.19
      - `json` @ python-3.14.0
      - `mashumaro` @ 3.22
      - `msgpack` @ 1.2.1
      - `msgspec` @ 0.21.1
      - `msgspec-msgpack` @ 0.21.1
      - `orjson` @ 3.11.9
      - `pickle` @ python-3.14.0
      - `protobuf` @ 7.35.1
      - `pydantic` @ 2.13.4
      - `rapidjson` @ 1.23
      - `serpyco-rs` @ 1.21.0
