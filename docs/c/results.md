# C — Benchmark Results

**Generated:** 2026-07-20T12:51:22.232490

This page is a **snapshot of measured numbers** for C on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [C overview](index.md) |
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
| avro-c:1.11.3 | 28.4 | 10.9 | 17.5 | 0.849M | 10.9K | 1643 | **1.00** |
| cbor-encode:0.11.0 | 377 | 107 | 270 | 0.0914M | 15.1K | 1816 | **1.00** |
| cJSON:1.7.18 | 513 | 351 | 162 | 0.0794M | 19.9K | 1794 | **1.00** |
| custom-binary:v2-1.0 | **16.5** | **4.15** | 12.3 | **2.47M** | 10.7K | 1715 | **1.00** |
| flatcc:0.6.1 | 22.9 | 11 | **11.8** | 1.22M | 12.2K | 1695 | **1.00** |
| jansson:2.14 | 653 | 300 | 352 | 0.0497M | 20.1K | 1880 | **1.00** |
| json-c:0.15 | 545 | 266 | 278 | 0.0676M | 20.1K | 1827 | **1.00** |
| libbson:1.27.5 | 305 | 99.1 | 206 | 0.145M | 21.1K | 1792 | **1.00** |
| mpack:1.1 | 52.4 | 13.1 | 39.4 | 0.548M | 13.7K | 1716 | **1.00** |
| msgpack-c:6.0.1 | 54.8 | 20.7 | 34.2 | 0.506M | 13.7K | 1697 | **1.00** |
| nanopb:0.4.9 | 24.8 | 9.92 | 14.8 | 1.28M | **10.5K** | 1683 | **1.00** |
| parson:1.5.3 | 754 | 562 | 191 | 0.0573M | 20.1K | 1800 | **1.00** |
| protobuf-c:1.5.0 | 24.9 | 9.96 | 14.9 | 1.27M | **10.5K** | 1655 | **1.00** |
| protobuf-wire:wire-v2 | 24.7 | 9.99 | 14.7 | 1.28M | **10.5K** | 1729 | **1.00** |
| qcbor:1.5.1 | 326 | 59.5 | 267 | 0.11M | 13.8K | 1799 | **1.00** |
| tinycbor:0.6.0 | 295 | 21.5 | 273 | 0.14M | 13.8K | 1813 | **1.00** |
| ubj:1.0-min | 19.3 | 6.19 | 13 | 1.79M | 12.6K | 1744 | **1.00** |
| yyjson:0.10.0 | 115 | 54.3 | 61 | 0.232M | 19.8K | 1762 | **1.00** |
| zcbor:0.9 | 337 | 35.7 | 302 | 0.115M | 14K | 1777 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro-c:1.11.3 | 0.361 | 0.361 | 0.761 | 0.758 |
| cbor-encode:0.11.0 | 2.26 | 2.26 | 2.94 | 2.95 |
| cJSON:1.7.18 | 4.18 | 4.07 | 5.19 | 5.17 |
| custom-binary:v2-1.0 | **0.076** | **0.076** | **0.46** | **0.46** |
| flatcc:0.6.1 | 0.218 | 0.22 | 0.676 | 0.674 |
| jansson:2.14 | 4.81 | 4.79 | 5.35 | 5.33 |
| json-c:0.15 | 3.59 | 3.58 | 4 | 3.99 |
| libbson:1.27.5 | 1.21 | 1.21 | 1.62 | 1.61 |
| mpack:1.1 | 0.423 | 0.424 | 0.821 | 0.821 |
| msgpack-c:6.0.1 | 0.443 | 0.443 | 0.831 | 0.828 |
| nanopb:0.4.9 | 0.13 | 0.129 | 0.522 | 0.522 |
| parson:1.5.3 | 5.16 | 5.16 | 5.71 | 5.72 |
| protobuf-c:1.5.0 | 0.13 | 0.13 | 0.524 | 0.524 |
| protobuf-wire:wire-v2 | 0.13 | 0.13 | 0.524 | 0.524 |
| qcbor:1.5.1 | 1.93 | 1.93 | 2.38 | 2.38 |
| tinycbor:0.6.0 | 1.46 | 1.46 | 1.9 | 1.9 |
| ubj:1.0-min | 0.131 | 0.131 | 0.51 | 0.509 |
| yyjson:0.10.0 | 1.47 | 1.46 | 2.12 | 2.12 |
| zcbor:0.9 | 1.71 | 1.71 | 2.14 | 2.14 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro-c:1.11.3 | 2.2M | 18K | 2.3M | 19K | 2.8M | 21K | 1.6M | 14K | 2.4M | 20K |
| cbor-encode:0.11.0 | 0.1M | 0.99K | 0.26M | 2.6K | 0.44M | 4K | 0.079M | 0.79K | 0.12M | 1.2K |
| cJSON:1.7.18 | 0.13M | 1.3K | 0.26M | 2.4K | 0.24M | 3.5K | 0.2M | 1.6K | 0.034M | 0.33K |
| custom-binary:v2-1.0 | **7.6M** | **33K** | **7.1M** | **34K** | **13M** | **42K** | **3.6M** | **20K** | **9.2M** | **35K** |
| flatcc:0.6.1 | 3.4M | 23K | 3.6M | 24K | 4.6M | 27K | 2.3M | 17K | 3.8M | 25K |
| jansson:2.14 | 0.063M | 0.64K | 0.12M | 1.2K | 0.21M | 2.1K | 0.09M | 0.88K | 0.041M | 0.42K |
| json-c:0.15 | 0.07M | 0.74K | 0.16M | 1.5K | 0.28M | 2.4K | 0.14M | 1.3K | 0.047M | 0.46K |
| libbson:1.27.5 | 0.19M | 2K | 0.38M | 3.7K | 0.83M | 8.1K | 0.084M | 0.88K | 0.093M | 1K |
| mpack:1.1 | 0.75M | 6.6K | 1.3M | 11K | 2.4M | 18K | 1M | 6.9K | 1.4M | 12K |
| msgpack-c:6.0.1 | 0.6M | 5.8K | 1.2M | 11K | 2.3M | 18K | 1M | 8.1K | 1.1M | 10K |
| nanopb:0.4.9 | 1.7M | 14K | 3M | 23K | 7.7M | 39K | 2M | 15K | 4.4M | 27K |
| parson:1.5.3 | 0.055M | 0.55K | 0.16M | 1.5K | 0.19M | 1.8K | 0.17M | 1.4K | 0.028M | 0.28K |
| protobuf-c:1.5.0 | 1.7M | 14K | 3M | 23K | 7.7M | 39K | 2M | 15K | 4.3M | 29K |
| protobuf-wire:wire-v2 | 1.7M | 14K | 2.9M | 23K | 7.7M | 40K | 2.1M | 15K | 4.5M | 29K |
| qcbor:1.5.1 | 0.12M | 1.3K | 0.32M | 3.3K | 0.52M | 4.6K | 0.085M | 0.85K | 0.13M | 1.3K |
| tinycbor:0.6.0 | 0.16M | 1.6K | 0.43M | 4.2K | 0.69M | 6K | 0.089M | 0.86K | 0.15M | 1.4K |
| ubj:1.0-min | 5.6M | 29K | 5.8M | 30K | 7.6M | 32K | 2.9M | 18K | 5.9M | 28K |
| yyjson:0.10.0 | 0.34M | 3.1K | 0.62M | 5.5K | 0.68M | 10K | 0.47M | 3.3K | 0.48M | 4.3K |
| zcbor:0.9 | 0.12M | 1.2K | 0.32M | 3.1K | 0.59M | 5.4K | 0.081M | 0.82K | 0.13M | 1.3K |

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one **data type** (and batch size):

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that data type so the picture stays readable. Tables above still list everyone.
- Each image also prints the data type, source CSV, modes, and sample size.

### Document · 1 instance

![Document · 1 instance](../analysis/plots/violin/c_document@n=1.png){ width="80%" }

### Document · 100 instances

![Document · 100 instances](../analysis/plots/violin/c_document@n=100.png){ width="80%" }

### Event · 1 instance

![Event · 1 instance](../analysis/plots/violin/c_event@n=1.png){ width="80%" }

### Event · 100 instances

![Event · 100 instances](../analysis/plots/violin/c_event@n=100.png){ width="80%" }

### Message · 1 instance

![Message · 1 instance](../analysis/plots/violin/c_message@n=1.png){ width="80%" }

### Message · 100 instances

![Message · 100 instances](../analysis/plots/violin/c_message@n=100.png){ width="80%" }

### Strings · 1 instance

![Strings · 1 instance](../analysis/plots/violin/c_strings@n=1.png){ width="80%" }

### Strings · 100 instances

![Strings · 100 instances](../analysis/plots/violin/c_strings@n=100.png){ width="80%" }

### Telemetry · 1 instance

![Telemetry · 1 instance](../analysis/plots/violin/c_telemetry@n=1.png){ width="80%" }

### Telemetry · 100 instances

![Telemetry · 100 instances](../analysis/plots/violin/c_telemetry@n=100.png){ width="80%" }

## How to regenerate this page

Snapshots are produced on a developer machine. After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l c   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/c/2026-07-20-125059.csv`
    - run=2026-07-20-125059
    - language=c
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: gcc=gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, python=3.14.0, node=24.15.0
    - git=61a38cf dirty
    - seed=42
    - warmup_reps=1
    - serializers=19
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `avro-c` @ 1.11.3
      - `cJSON` @ 1.7.18
      - `cbor-encode` @ 0.11.0
      - `custom-binary` @ v2-1.0
      - `flatcc` @ 0.6.1
      - `jansson` @ 2.14
      - `json-c` @ 0.15
      - `libbson` @ 1.27.5
      - `mpack` @ 1.1
      - `msgpack-c` @ 6.0.1
      - `nanopb` @ 0.4.9
      - `parson` @ 1.5.3
      - `protobuf-c` @ 1.5.0
      - `protobuf-wire` @ wire-v2
      - `qcbor` @ 1.5.1
      - `tinycbor` @ 0.6.0
      - `ubj` @ 1.0-min
      - `yyjson` @ 0.10.0
      - `zcbor` @ 0.9
