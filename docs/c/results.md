# C — Benchmark Results

**Generated:** 2026-07-24T18:57:57.700668

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
| avro-c:1.11.3 | 33.1 | 13.3 | 19.8 | 0.482M | 10.9K | 1782 | **1.00** |
| cbor-encode:0.11.0 | 361 | 104 | 257 | 0.0754M | 15.1K | 1814 | **1.00** |
| cJSON:1.7.18 | 512 | 350 | 162 | 0.0733M | 19.9K | 1847 | **1.00** |
| custom-binary:v2-1.0 | **19** | **6.05** | **13** | **1.57M** | 10.7K | 1718 | **1.00** |
| flatcc:0.6.1 | 26.4 | 13.3 | 13 | 0.733M | 12.2K | 1778 | **1.00** |
| jansson:2.14 | 652 | 301 | 351 | 0.0445M | 20.1K | 1851 | **1.00** |
| json-c:0.15 | 527 | 251 | 276 | 0.0563M | 20.1K | 1858 | **1.00** |
| libbson:1.27.5 | 313 | 96.9 | 216 | 0.115M | 21.1K | 1822 | **1.00** |
| mpack:1.1 | 56.9 | 15 | 41.9 | 0.311M | 13.7K | 1792 | **1.00** |
| msgpack-c:6.0.1 | 58 | 21 | 37 | 0.305M | 13.7K | 1775 | **1.00** |
| nanopb:0.4.9 | 28.1 | 11.9 | 16.2 | 0.926M | **10.5K** | 1757 | **1.00** |
| parson:1.5.3 | 752 | 563 | 189 | 0.0467M | 20.1K | 1837 | **1.00** |
| protobuf-c:1.5.0 | 28 | 12 | 16 | 0.911M | **10.5K** | 1772 | **1.00** |
| protobuf-wire:wire-v2 | 28.1 | 11.8 | 16.2 | 0.922M | **10.5K** | 1762 | **1.00** |
| qcbor:1.5.1 | 313 | 56.8 | 256 | 0.103M | 13.8K | 1811 | **1.00** |
| tinycbor:0.6.0 | 277 | 20.5 | 256 | 0.124M | 13.8K | 1792 | **1.00** |
| ubj:1.0-min | 21.5 | 7.72 | 13.8 | 1.1M | 12.6K | 1791 | **1.00** |
| yyjson:0.10.0 | 124 | 58.5 | 65.1 | 0.2M | 19.8K | 1804 | **1.00** |
| zcbor:0.9 | 331 | 35.2 | 295 | 0.106M | 14K | 1784 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro-c:1.11.3 | 0.6 | 0.601 | 1 | 0.986 |
| cbor-encode:0.11.0 | 2.92 | 2.91 | 3.29 | 3.28 |
| cJSON:1.7.18 | 3.22 | 3.2 | 3.66 | 3.64 |
| custom-binary:v2-1.0 | **0.118** | **0.118** | **0.492** | **0.487** |
| flatcc:0.6.1 | 0.351 | 0.349 | 0.747 | 0.738 |
| jansson:2.14 | 5.34 | 5.34 | 5.81 | 5.81 |
| json-c:0.15 | 4.58 | 4.55 | 4.84 | 4.82 |
| libbson:1.27.5 | 1.61 | 1.62 | 1.94 | 1.95 |
| mpack:1.1 | 0.883 | 0.881 | 1.12 | 1.13 |
| msgpack-c:6.0.1 | 0.833 | 0.848 | 1.13 | 1.12 |
| nanopb:0.4.9 | 0.199 | 0.2 | 0.565 | 0.564 |
| parson:1.5.3 | 5.66 | 5.67 | 6.15 | 6.18 |
| protobuf-c:1.5.0 | 0.209 | 0.211 | 0.577 | 0.572 |
| protobuf-wire:wire-v2 | 0.21 | 0.21 | 0.595 | 0.59 |
| qcbor:1.5.1 | 2.11 | 2.1 | 2.53 | 2.53 |
| tinycbor:0.6.0 | 1.69 | 1.69 | 2.07 | 2.06 |
| ubj:1.0-min | 0.191 | 0.191 | 0.583 | 0.563 |
| yyjson:0.10.0 | 1.2 | 1.21 | 1.61 | 1.6 |
| zcbor:0.9 | 1.88 | 1.88 | 2.28 | 2.28 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro-c:1.11.3 | 0.95M | 16K | 0.94M | 16K | 1.7M | 21K | 1.1M | 11K | 1.2M | 18K |
| cbor-encode:0.11.0 | 0.079M | 1K | 0.19M | 2.6K | 0.34M | 4.2K | 0.078M | 0.86K | 0.1M | 1.3K |
| cJSON:1.7.18 | 0.098M | 1.3K | 0.19M | 2.4K | 0.31M | 3.6K | 0.16M | 1.6K | 0.035M | 0.34K |
| custom-binary:v2-1.0 | **3.8M** | **29K** | **3M** | **29K** | **8.5M** | **42K** | **3M** | **16K** | **5.4M** | **36K** |
| flatcc:0.6.1 | 1.6M | 20K | 1.5M | 21K | 2.8M | 27K | 1.7M | 13K | 2M | 24K |
| jansson:2.14 | 0.051M | 0.63K | 0.1M | 1.3K | 0.19M | 2.1K | 0.084M | 0.89K | 0.039M | 0.41K |
| json-c:0.15 | 0.059M | 0.76K | 0.12M | 1.6K | 0.22M | 2.5K | 0.12M | 1.3K | 0.045M | 0.47K |
| libbson:1.27.5 | 0.14M | 1.9K | 0.28M | 3.6K | 0.62M | 7.4K | 0.08M | 0.85K | 0.094M | 1K |
| mpack:1.1 | 0.33M | 6.1K | 0.56M | 11K | 1.1M | 18K | 0.62M | 6.4K | 0.53M | 12K |
| msgpack-c:6.0.1 | 0.31M | 5.6K | 0.54M | 10K | 1.2M | 18K | 0.6M | 7.7K | 0.5M | 10K |
| nanopb:0.4.9 | 1.2M | 12K | 1.7M | 20K | 5M | 38K | 1.7M | 13K | 3M | 27K |
| parson:1.5.3 | 0.044M | 0.55K | 0.11M | 1.5K | 0.18M | 1.9K | 0.13M | 1.4K | 0.028M | 0.27K |
| protobuf-c:1.5.0 | 1.3M | 12K | 1.7M | 20K | 4.8M | 38K | 1.7M | 13K | 3M | 28K |
| protobuf-wire:wire-v2 | 1.3M | 12K | 1.8M | 20K | 4.8M | 38K | 1.7M | 13K | 3.1M | 27K |
| qcbor:1.5.1 | 0.11M | 1.3K | 0.28M | 3.4K | 0.47M | 4.9K | 0.093M | 0.96K | 0.12M | 1.3K |
| tinycbor:0.6.0 | 0.14M | 1.6K | 0.36M | 4.4K | 0.59M | 6.1K | 0.097M | 1K | 0.13M | 1.4K |
| ubj:1.0-min | 2.6M | 26K | 2.3M | 27K | 5.2M | 34K | 2.3M | 15K | 3.3M | 30K |
| yyjson:0.10.0 | 0.2M | 3K | 0.44M | 4.9K | 0.83M | 10K | 0.36M | 3.2K | 0.31M | 3.9K |
| zcbor:0.9 | 0.11M | 1.2K | 0.27M | 3.3K | 0.53M | 5.4K | 0.084M | 0.88K | 0.11M | 1.2K |

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
    
    - **Source CSV:** `logs/c/2026-07-24-183742.csv`
    - run=2026-07-24-183742
    - language=c
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: gcc=gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, python=3.14.0, node=24.15.0
    - git=85145fd dirty
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
