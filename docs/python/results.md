# Python — Benchmark Results

**Generated:** 2026-07-24T18:57:57.688577

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
| avro:1.12.2 | 475 | 264 | 210 | 25.7K | **9.03K** | 1783 | **1.00** |
| cbor2:6.1.3 | 311 | 206 | 104 | 34.1K | 13.6K | 1814 | **1.00** |
| cloudpickle:3.1.2 | 320 | 239 | 81.3 | 23.7K | 13.6K | 1833 | **1.00** |
| dill:0.4.1 | 2,240 | 2,140 | 93.3 | 5.62K | 13.6K | 1835 | **1.00** |
| flatbuffers:25.12.19 | 2,330 | 1,840 | 486 | 8.39K | 18.7K | 1860 | **1.00** |
| json:python-3.14.0 | 329 | 191 | 137 | 29.6K | 19.7K | 1820 | **1.00** |
| mashumaro:3.22 | 156 | 45.8 | 110 | 78.9K | 19.7K | 1840 | **1.00** |
| msgpack:1.2.1 | 110 | 53.9 | 55.5 | 85.7K | 13.6K | 1786 | **1.00** |
| msgspec:0.21.1 | 70.2 | 30 | 40.2 | 122K | 14.7K | 1801 | **1.00** |
| msgspec-msgpack:0.21.1 | 47.2 | **17.3** | 29.8 | 164K | 9.69K | 1774 | **1.00** |
| orjson:3.11.9 | 79.8 | 30.1 | 49.2 | **167K** | 19.7K | 1864 | **1.00** |
| pickle:python-3.14.0 | 199 | 118 | 81 | 45.5K | 13.6K | 1867 | **1.00** |
| protobuf:7.35.1 | **39.4** | 17.9 | **21.4** | 114K | 10.1K | 1739 | **1.00** |
| pydantic:2.13.4 | 519 | 269 | 249 | 26.9K | 21.4K | 1794 | **1.00** |
| rapidjson:1.23 | 300 | 158 | 142 | 47.1K | 19.7K | 1821 | **1.00** |
| serpyco-rs:1.21.0 | 126 | 46.9 | 78.5 | 90.8K | 19.7K | 1834 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro:1.12.2 | 13.9 | 14.1 | 14.5 | 14.5 |
| cbor2:6.1.3 | 9.44 | 9.61 | 10.9 | 11 |
| cloudpickle:3.1.2 | 17.1 | 17 | 16.8 | 16.7 |
| dill:0.4.1 | 62.2 | 62 | 62.9 | 62.8 |
| flatbuffers:25.12.19 | 36.6 | 36.7 | 38 | 37.8 |
| json:python-3.14.0 | 12.3 | 12.5 | 13.5 | 13.6 |
| mashumaro:3.22 | 4.56 | 4.48 | 5.28 | 5.21 |
| msgpack:1.2.1 | 4.54 | 4.52 | 5.57 | 5.57 |
| msgspec:0.21.1 | 2.37 | 2.41 | 3.72 | 3.78 |
| msgspec-msgpack:0.21.1 | **1.72** | **1.73** | 2.99 | 3.01 |
| orjson:3.11.9 | 1.89 | 1.87 | **2.42** | **2.39** |
| pickle:python-3.14.0 | 7.84 | 7.84 | 9.01 | 9.06 |
| protobuf:7.35.1 | 3.61 | 3.65 | 4.12 | 4.22 |
| pydantic:2.13.4 | 14.9 | 14.8 | 15.6 | 15.6 |
| rapidjson:1.23 | 7.8 | 7.81 | 8.53 | 8.63 |
| serpyco-rs:1.21.0 | 4.32 | 4.24 | 4.76 | 4.75 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro:1.12.2 | 36K | 0.69K | 46K | 1.1K | 72K | 2.6K | 49K | 0.89K | 52K | 1.2K |
| cbor2:6.1.3 | 41K | 0.85K | 56K | 1.7K | 110K | 4K | 80K | 2K | 65K | 1.9K |
| cloudpickle:3.1.2 | 25K | 0.72K | 32K | 1.3K | 58K | 4.6K | 55K | 2.3K | 52K | 3.4K |
| dill:0.4.1 | 5.7K | 0.11K | 8.2K | 0.21K | 16K | 0.66K | 13K | 0.28K | 12K | 0.33K |
| flatbuffers:25.12.19 | 8.6K | 0.13K | 15K | 0.24K | 27K | 0.51K | 13K | 0.17K | 19K | 0.34K |
| json:python-3.14.0 | 47K | 1.6K | 59K | 2.8K | 81K | 4.3K | 73K | 2.7K | 34K | 0.62K |
| mashumaro:3.22 | 81K | 1.7K | 130K | 3.6K | 220K | 8.2K | 230K | 4.1K | 150K | 3.4K |
| msgpack:1.2.1 | 110K | 2.5K | 150K | 4.7K | 220K | 8.9K | 230K | 5.5K | 190K | 6.1K |
| msgspec:0.21.1 | 230K | 7K | 260K | 9.1K | 420K | 23K | 270K | 6K | 180K | 4.4K |
| msgspec-msgpack:0.21.1 | **280K** | 8K | **320K** | 11K | **580K** | **35K** | 330K | 7.1K | **340K** | 13K |
| orjson:3.11.9 | 230K | 4.9K | 310K | 6.7K | 530K | 18K | **420K** | 5.4K | 300K | 5.3K |
| pickle:python-3.14.0 | 50K | 1.3K | 65K | 2.2K | 130K | 7.5K | 110K | 2.9K | 100K | 4.9K |
| protobuf:7.35.1 | 180K | **10K** | 200K | **14K** | 280K | 32K | 220K | **7.4K** | 220K | **26K** |
| pydantic:2.13.4 | 38K | 0.68K | 46K | 1.2K | 67K | 2.3K | 73K | 1.8K | 44K | 0.54K |
| rapidjson:1.23 | 74K | 1.9K | 97K | 3.7K | 130K | 4.9K | 130K | 3.6K | 40K | 0.6K |
| serpyco-rs:1.21.0 | 120K | 2.3K | 160K | 4.5K | 230K | 10K | 250K | 4.6K | 180K | 3.9K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/python/2026-07-24-183742.csv`
    - run=2026-07-24-183742
    - language=python
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: python=3.14.0, node=24.15.0, dotnet=9.0.316
    - git=85145fd dirty
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
