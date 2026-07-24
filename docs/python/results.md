# Python — Benchmark Results

**Generated:** 2026-07-20T12:50:49.488594

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
| avro:1.12.2 | 454 | 248 | 206 | 59.7K | **9.03K** | 1816 | **1.00** |
| cbor2:6.1.3 | 287 | 190 | 97.6 | 82.4K | 13.6K | 1826 | **1.00** |
| cloudpickle:3.1.2 | 290 | 216 | 75 | 54.3K | 13.6K | 1837 | **1.00** |
| dill:0.4.1 | 2,160 | 2,080 | 87 | 8.31K | 13.6K | 1803 | **1.00** |
| flatbuffers:25.12.19 | 2,360 | 1,870 | 487 | 11.4K | 18.7K | 1827 | **1.00** |
| json:python-3.14.0 | 311 | 179 | 132 | 71.8K | 19.7K | 1851 | **1.00** |
| mashumaro:3.22 | 76.3 | 30.9 | 45 | 175K | 19.7K | 1833 | **1.00** |
| msgpack:1.2.1 | 97.1 | 48.5 | 48.5 | 231K | 13.6K | 1844 | **1.00** |
| msgspec:0.21.1 | 56.9 | 23.3 | 33.5 | 390K | 14.7K | 1847 | **1.00** |
| msgspec-msgpack:0.21.1 | 36.2 | 12.2 | 24 | 463K | 9.69K | 1824 | **1.00** |
| orjson:3.11.9 | 67.9 | 25.3 | 42.6 | 350K | 19.7K | 1805 | **1.00** |
| pickle:python-3.14.0 | 176 | 102 | 74.2 | 91.4K | 13.6K | 1828 | **1.00** |
| protobuf:7.35.1 | **28.2** | **11.7** | **16.5** | **480K** | 10.1K | 1818 | **1.00** |
| pydantic:2.13.4 | 495 | 255 | 240 | 65K | 21.4K | 1846 | **1.00** |
| rapidjson:1.23 | 287 | 153 | 134 | 115K | 19.7K | 1854 | **1.00** |
| serpyco-rs:1.20.0 | 75.8 | 31.8 | 43.8 | 200K | 19.7K | 1807 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro:1.12.2 | 4.43 | 4.4 | 4.49 | 4.48 |
| cbor2:6.1.3 | 3.49 | 3.46 | 3.74 | 3.73 |
| cloudpickle:3.1.2 | 6.92 | 6.93 | 6.97 | 6.95 |
| dill:0.4.1 | 39.7 | 39.6 | 38.9 | 38.8 |
| flatbuffers:25.12.19 | 24.7 | 24.6 | 25.2 | 25.2 |
| json:python-3.14.0 | 4.79 | 4.78 | 4.89 | 4.88 |
| mashumaro:3.22 | 1.78 | 1.76 | 1.99 | 1.99 |
| msgpack:1.2.1 | 1.44 | 1.44 | 1.68 | 1.68 |
| msgspec:0.21.1 | 0.585 | 0.581 | 0.951 | 0.944 |
| msgspec-msgpack:0.21.1 | **0.521** | **0.54** | 0.879 | 0.883 |
| orjson:3.11.9 | 0.873 | 0.871 | 1.05 | 1.03 |
| pickle:python-3.14.0 | 3.91 | 3.9 | 4.27 | 4.26 |
| protobuf:7.35.1 | 0.755 | 0.734 | **0.845** | **0.84** |
| pydantic:2.13.4 | 5.47 | 5.41 | 5.72 | 5.69 |
| rapidjson:1.23 | 3.03 | 3.03 | 3.14 | 3.17 |
| serpyco-rs:1.20.0 | 1.63 | 1.61 | 1.74 | 1.74 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro:1.12.2 | 64K | 0.71K | 0.11M | 1.2K | 0.23M | 2.9K | 82K | 0.92K | 0.11M | 1.2K |
| cbor2:6.1.3 | 73K | 0.88K | 0.15M | 1.9K | 0.29M | 4.5K | 160K | 2.2K | 0.16M | 2K |
| cloudpickle:3.1.2 | 44K | 0.73K | 0.068M | 1.4K | 0.14M | 5.7K | 130K | 2.5K | 0.14M | 4.2K |
| dill:0.4.1 | 7.2K | 0.11K | 0.012M | 0.22K | 0.025M | 0.7K | 18K | 0.29K | 0.018M | 0.33K |
| flatbuffers:25.12.19 | 11K | 0.13K | 0.02M | 0.24K | 0.041M | 0.49K | 15K | 0.16K | 0.028M | 0.34K |
| json:python-3.14.0 | 110K | 1.6K | 0.17M | 3.4K | 0.21M | 5K | 170K | 2.9K | 0.049M | 0.63K |
| mashumaro:3.22 | 180K | 3.7K | 0.32M | 9.2K | 0.56M | 21K | 440K | 6.1K | 0.29M | 5.8K |
| msgpack:1.2.1 | 220K | 2.6K | 0.45M | 5.9K | 0.69M | 10K | 520K | 6.5K | 0.55M | 7K |
| msgspec:0.21.1 | 670K | 8.2K | 0.93M | 15K | 1.7M | 40K | 720K | 7.1K | 0.39M | 4.8K |
| msgspec-msgpack:0.21.1 | **750K** | 8.6K | 0.98M | 18K | **1.9M** | **63K** | 660K | 8.8K | 0.96M | 15K |
| orjson:3.11.9 | 550K | 5.2K | 0.8M | 10K | 1.1M | 22K | **780K** | 6K | 0.43M | 6.1K |
| pickle:python-3.14.0 | 87K | 1.3K | 0.14M | 2.6K | 0.26M | 9.3K | 210K | 3.2K | 0.24M | 5.8K |
| protobuf:7.35.1 | 640K | **13K** | **1M** | **21K** | 1.3M | 59K | 720K | **9.4K** | **1.3M** | **43K** |
| pydantic:2.13.4 | 78K | 0.69K | 0.13M | 1.4K | 0.18M | 2.5K | 180K | 1.9K | 0.081M | 0.55K |
| rapidjson:1.23 | 160K | 2K | 0.3M | 4.4K | 0.33M | 5.4K | 320K | 4K | 0.052M | 0.6K |
| serpyco-rs:1.20.0 | 240K | 4.2K | 0.38M | 9.6K | 0.62M | 20K | 470K | 6K | 0.33M | 6K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/python/2026-07-20-124836.csv`
    - run=2026-07-20-124836
    - language=python
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: python=3.14.0, node=24.15.0, dotnet=8.0.422
    - git=61a38cf dirty
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
      - `serpyco-rs` @ 1.20.0
