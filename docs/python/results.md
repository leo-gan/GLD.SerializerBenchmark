# Python — Benchmark Results

**Generated:** 2026-07-24T15:52:53.325032

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

## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| avro:1.12.2 | 419 | 227 | 191 | 65K | **9.03K** | 1846 | **1.00** |
| cbor2:6.1.3 | 272 | 180 | 92 | 89.4K | 13.6K | 1822 | **1.00** |
| cloudpickle:3.1.2 | 270 | 200 | 69.6 | 58.3K | 13.6K | 1827 | **1.00** |
| dill:0.4.1 | 2,050 | 1,970 | 79.7 | 8.67K | 13.6K | 1786 | **1.00** |
| flatbuffers:25.12.19 | 2,200 | 1,740 | 458 | 12K | 18.7K | 1851 | **1.00** |
| json:python-3.14.0 | 287 | 164 | 122 | 75.2K | 19.7K | 1825 | **1.00** |
| mashumaro:3.22 | 135 | 39.6 | 95.4 | 189K | 19.7K | 1769 | **1.00** |
| msgpack:1.2.1 | 90.5 | 45 | 45.2 | 250K | 13.6K | 1815 | **1.00** |
| msgspec:0.21.1 | 54.4 | 21.5 | 32.7 | 411K | 14.7K | 1790 | **1.00** |
| msgspec-msgpack:0.21.1 | 35.1 | 10.9 | 23.9 | 489K | 9.69K | 1805 | **1.00** |
| orjson:3.11.9 | 61.5 | 21.7 | 39.6 | 383K | 19.7K | 1802 | **1.00** |
| pickle:python-3.14.0 | 166 | 95.3 | 69.6 | 97.7K | 13.6K | 1819 | **1.00** |
| protobuf:7.35.1 | **26.1** | **10.5** | **15.3** | **505K** | 10.1K | 1773 | **1.00** |
| pydantic:2.13.4 | 465 | 239 | 225 | 70K | 21.4K | 1849 | **1.00** |
| rapidjson:1.23 | 264 | 140 | 124 | 124K | 19.7K | 1811 | **1.00** |
| serpyco-rs:1.21.0 | 107 | 39.4 | 66.7 | 228K | 19.7K | 1785 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro:1.12.2 | 3.76 | 3.76 | 3.86 | 3.86 |
| cbor2:6.1.3 | 3.16 | 3.16 | 3.39 | 3.38 |
| cloudpickle:3.1.2 | 6.15 | 6.15 | 6.11 | 6.13 |
| dill:0.4.1 | 36 | 36 | 37.1 | 36.7 |
| flatbuffers:25.12.19 | 21.6 | 21.6 | 22.4 | 22.4 |
| json:python-3.14.0 | 4.5 | 4.48 | 4.49 | 4.49 |
| mashumaro:3.22 | 1.63 | 1.61 | 1.91 | 1.88 |
| msgpack:1.2.1 | 1.36 | 1.35 | 1.59 | 1.58 |
| msgspec:0.21.1 | 0.596 | 0.6 | 0.856 | 0.854 |
| msgspec-msgpack:0.21.1 | **0.504** | **0.508** | 0.844 | 0.851 |
| orjson:3.11.9 | 0.756 | 0.744 | 0.906 | 0.892 |
| pickle:python-3.14.0 | 3.48 | 3.48 | 3.78 | 3.81 |
| protobuf:7.35.1 | 0.666 | 0.648 | **0.777** | **0.763** |
| pydantic:2.13.4 | 4.82 | 4.8 | 4.95 | 4.97 |
| rapidjson:1.23 | 2.7 | 2.71 | 2.82 | 2.82 |
| serpyco-rs:1.21.0 | 1.37 | 1.36 | 1.49 | 1.48 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro:1.12.2 | 66K | 0.77K | 0.11M | 1.3K | 0.27M | 2.9K | 91K | 1K | 0.11M | 1.3K |
| cbor2:6.1.3 | 78K | 0.92K | 0.16M | 2.1K | 0.32M | 4.7K | 190K | 2.3K | 0.16M | 2.1K |
| cloudpickle:3.1.2 | 45K | 0.77K | 0.073M | 1.6K | 0.16M | 6.3K | 140K | 2.8K | 0.14M | 4.3K |
| dill:0.4.1 | 7.6K | 0.12K | 0.012M | 0.23K | 0.028M | 0.74K | 19K | 0.29K | 0.018M | 0.35K |
| flatbuffers:25.12.19 | 10K | 0.13K | 0.02M | 0.25K | 0.046M | 0.54K | 16K | 0.18K | 0.026M | 0.35K |
| json:python-3.14.0 | 110K | 1.8K | 0.17M | 3.6K | 0.22M | 5.3K | 180K | 3.3K | 0.056M | 0.67K |
| mashumaro:3.22 | 180K | 1.9K | 0.34M | 4.5K | 0.61M | 9.8K | 520K | 4.4K | 0.31M | 3.9K |
| msgpack:1.2.1 | 240K | 2.8K | 0.48M | 6.3K | 0.74M | 11K | 630K | 6.8K | 0.56M | 7.5K |
| msgspec:0.21.1 | 670K | 9K | 0.93M | 17K | 1.7M | 46K | 740K | 6.9K | 0.47M | 4.8K |
| msgspec-msgpack:0.21.1 | **760K** | 10K | **1.1M** | 18K | **2M** | 58K | 810K | 8.3K | 0.93M | 18K |
| orjson:3.11.9 | 540K | 5.9K | 0.84M | 12K | 1.3M | 24K | 830K | 6.6K | 0.5M | 6.6K |
| pickle:python-3.14.0 | 88K | 1.4K | 0.14M | 2.8K | 0.29M | 9.9K | 240K | 3.4K | 0.23M | 6.1K |
| protobuf:7.35.1 | 660K | **13K** | 1M | **23K** | 1.5M | **64K** | **850K** | **10K** | **1.2M** | **54K** |
| pydantic:2.13.4 | 79K | 0.75K | 0.13M | 1.5K | 0.21M | 2.7K | 190K | 2K | 0.09M | 0.58K |
| rapidjson:1.23 | 170K | 2.2K | 0.3M | 4.8K | 0.37M | 6.2K | 350K | 4.4K | 0.059M | 0.65K |
| serpyco-rs:1.21.0 | 250K | 2.6K | 0.43M | 5.9K | 0.73M | 13K | 580K | 5K | 0.34M | 4.4K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/python/2026-07-24-155049.csv`
    - run=2026-07-24-155049
    - language=python
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: python=3.14.0, node=24.15.0, dotnet=9.0.316
    - git=04d09d1 dirty
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
