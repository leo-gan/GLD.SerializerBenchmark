# Rust — Benchmark Results

**Generated:** 2026-07-24T15:53:02.163925

This page is a **snapshot of measured numbers** for Rust on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [Rust overview](index.md) |
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
| apache-avro:0.21.0 | 140 | 36.5 | 104 | 0.263M | 9.21K | 1823 | **1.00** |
| bincode:2.0.1 | 27.2 | 5.44 | 21.7 | 1.61M | 9.42K | 1754 | **1.00** |
| bitcode:0.6.9 | 72.9 | 35.8 | 37.1 | 0.417M | 9.25K | 1799 | **1.00** |
| bson:2.15.0 | 113 | 32.3 | 80.4 | 0.314M | 21.4K | 1848 | **1.00** |
| ciborium:0.2.2 | 84.6 | 13.7 | 70.9 | 0.404M | 14.2K | 1739 | **1.00** |
| flexbuffers:2.0.0 | 130 | 65.6 | 64.2 | 0.244M | 19.6K | 1737 | **1.00** |
| minicbor:0.25.1 | 43.2 | 12.2 | 31 | 1.18M | 9.91K | 1741 | **1.00** |
| nanoserde:0.1.37 | 35.2 | 13.3 | 21.9 | 1.13M | 14.4K | 1820 | **1.00** |
| postcard:1.1.3 | 28.4 | 5.8 | 22.6 | 1.86M | 9.21K | 1797 | **1.00** |
| prost:0.13.5 | 52.1 | 17.9 | 34 | 1.07M | 10.2K | 1772 | **1.00** |
| rkyv:0.8.17 | 29.2 | 11 | 18.2 | 2.51M | **8.53K** | 1030 | **1.00** |
| rmp-serde:1.3.1 | 38.4 | 6.58 | 31.8 | 0.97M | 14.2K | 1761 | **1.00** |
| serde_json:1.0.150 | 72.9 | 18.9 | 54 | 0.481M | 20.5K | 1807 | **1.00** |
| simd-json:0.14.3 | 76.9 | 18.7 | 58.2 | 0.41M | 20.5K | 1757 | **1.00** |
| sonic-rs:0.3.17 | 55.3 | 15.5 | 39.8 | 0.681M | 20.5K | 1776 | **1.00** |
| speedy:0.8.7 | **20.3** | **2.66** | **17.7** | **3.1M** | 11.9K | 1774 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| apache-avro:0.21.0 | 0.883 | 0.882 | 0.913 | 0.902 |
| bincode:2.0.1 | 0.124 | 0.124 | 0.188 | 0.188 |
| bitcode:0.6.9 | 0.871 | 0.869 | 1.01 | 1.01 |
| bson:2.15.0 | 0.698 | 0.697 | 0.794 | 0.792 |
| ciborium:0.2.2 | 0.531 | 0.529 | 0.705 | 0.704 |
| flexbuffers:2.0.0 | 1.21 | 1.2 | 1.31 | 1.31 |
| minicbor:0.25.1 | 0.164 | 0.164 | 0.188 | 0.188 |
| nanoserde:0.1.37 | 0.217 | 0.216 | 0.293 | 0.291 |
| postcard:1.1.3 | 0.124 | 0.123 | 0.139 | 0.139 |
| prost:0.13.5 | 0.178 | 0.18 | 0.216 | 0.213 |
| rkyv:0.8.17 | 0.152 | 0.152 | 0.228 | 0.228 |
| rmp-serde:1.3.1 | 0.272 | 0.274 | 0.297 | 0.299 |
| serde_json:1.0.150 | 0.434 | 0.434 | 0.669 | 0.667 |
| simd-json:0.14.3 | 0.651 | 0.657 | 0.698 | 0.727 |
| sonic-rs:0.3.17 | 0.354 | 0.352 | 0.377 | 0.376 |
| speedy:0.8.7 | **0.0646** | **0.061** | **0.0979** | **0.0975** |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| apache-avro:0.21.0 | 0.29M | 2.7K | 0.55M | 4.7K | 1.1M | 11K | 0.25M | 2.2K | 0.41M | 3.6K |
| bincode:2.0.1 | 2.3M | 19K | 2.7M | 21K | 8.1M | 90K | 1.3M | 7.4K | 4.5M | 42K |
| bitcode:0.6.9 | 0.58M | 5.3K | 0.75M | 5.8K | 1.1M | 11K | 0.93M | 6K | 1M | 9.7K |
| bson:2.15.0 | 0.34M | 3.7K | 0.69M | 6K | 1.4M | 14K | 0.36M | 2.8K | 0.41M | 4.1K |
| ciborium:0.2.2 | 0.46M | 4.4K | 0.81M | 6.6K | 1.9M | 17K | 0.45M | 3.4K | 0.94M | 8.8K |
| flexbuffers:2.0.0 | 0.25M | 2.5K | 0.47M | 4K | 0.83M | 7.8K | 0.4M | 3.2K | 0.54M | 5.2K |
| minicbor:0.25.1 | 1.4M | 11K | 2.4M | 16K | 6.1M | 61K | 0.99M | 5.1K | 1.7M | 16K |
| nanoserde:0.1.37 | 2.1M | 15K | 2.5M | 16K | 4.6M | 61K | 0.83M | 6.1K | 2.5M | 23K |
| postcard:1.1.3 | 2.6M | 20K | 3.3M | 20K | 8.1M | 86K | 1.4M | 6.7K | 4.8M | 42K |
| prost:0.13.5 | 1.1M | 8.8K | 1.5M | 11K | 5.6M | 56K | 0.64M | 3.9K | 2.8M | 25K |
| rkyv:0.8.17 | 2.2M | - | 2.5M | - | 6.6M | - | 1.1M | 5.7K | 4.8M | - |
| rmp-serde:1.3.1 | 1.1M | 10K | 1.9M | 13K | 3.7M | 41K | 1.2M | 6.7K | 2.5M | 26K |
| serde_json:1.0.150 | 0.69M | 5.9K | 1.3M | 9.2K | 2.3M | 23K | 0.85M | 4.2K | 0.63M | 5.8K |
| simd-json:0.14.3 | 0.55M | 5.8K | 0.91M | 7.8K | 1.5M | 15K | 0.65M | 5K | 0.52M | 5.1K |
| sonic-rs:0.3.17 | 0.87M | 8.7K | 1.7M | 15K | 2.8M | 29K | 1.2M | 7.1K | 0.63M | 5.2K |
| speedy:0.8.7 | **4.6M** | **30K** | **4.9M** | **28K** | **15M** | **140K** | **1.7M** | **8.9K** | **10M** | **70K** |

### Within-category ranking

Compare serializers **inside the same family** only (for example JSON with JSON, not JSON with a zero-copy schema codec). Each value is mean serialize+deserialize **operations per second** across data types, using **bytes mode** only (the in-memory buffer API — not “payload size in bytes”). Higher is better. Stream mode is left out of this ranking. Rows are sorted by serializer name; **bold** marks the highest ops/s in the column.

#### JSON

| serializer | mean ops/s (bytes mode) (K) |
|---|---:|
| serde_json:1.0.150 | 580K |
| simd-json:0.14.3 | 420K |
| sonic-rs:0.3.17 | **730K** |

#### Rust-centric binary

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| bincode:2.0.1 | 1.9M |
| bitcode:0.6.9 | 0.45M |
| nanoserde:0.1.37 | 1.3M |
| postcard:1.1.3 | 2M |
| speedy:0.8.7 | **3.7M** |

#### Schema / zero-copy family

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| flexbuffers:2.0.0 | 0.25M |
| prost:0.13.5 | 1.2M |
| rkyv:0.8.17 | **2.9M** |

#### Schemaless binary (interop)

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| bson:2.15.0 | 0.33M |
| ciborium:0.2.2 | 0.46M |
| minicbor:0.25.1 | **1.3M** |
| rmp-serde:1.3.1 | 1M |

### Fidelity notes (Rust)

These notes explain odd-looking correctness or speed edges on Rust only:

- **prost** maps ISO timestamps through millisecond integers; the benchmark runner allows date-string drift on types that carry timestamps (message, event, document, telemetry).
- **rkyv** timed deserialize **builds owned values** for comparison; a pure zero-copy `access` path would be faster and is documented on the overview.
- **simd-json** serialize still goes through `serde_json` (the crate focuses on parse speed).

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one **data type** (and batch size):

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that data type so the picture stays readable. Tables above still list everyone.
- Each image also prints the data type, source CSV, modes, and sample size.

### Document · 1 instance

![Document · 1 instance](../analysis/plots/violin/rust_document@n=1.png){ width="80%" }

### Document · 100 instances

![Document · 100 instances](../analysis/plots/violin/rust_document@n=100.png){ width="80%" }

### Event · 1 instance

![Event · 1 instance](../analysis/plots/violin/rust_event@n=1.png){ width="80%" }

### Event · 100 instances

![Event · 100 instances](../analysis/plots/violin/rust_event@n=100.png){ width="80%" }

### Message · 1 instance

![Message · 1 instance](../analysis/plots/violin/rust_message@n=1.png){ width="80%" }

### Message · 100 instances

![Message · 100 instances](../analysis/plots/violin/rust_message@n=100.png){ width="80%" }

### Strings · 1 instance

![Strings · 1 instance](../analysis/plots/violin/rust_strings@n=1.png){ width="80%" }

### Strings · 100 instances

![Strings · 100 instances](../analysis/plots/violin/rust_strings@n=100.png){ width="80%" }

### Telemetry · 1 instance

![Telemetry · 1 instance](../analysis/plots/violin/rust_telemetry@n=1.png){ width="80%" }

### Telemetry · 100 instances

![Telemetry · 100 instances](../analysis/plots/violin/rust_telemetry@n=100.png){ width="80%" }

## How to regenerate this page

Snapshots are produced on a developer machine. After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l rust   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/rust/2026-07-24-155253.csv`
    - run=2026-07-24-155253
    - language=rust
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: rustc=rustc 1.96.0 (ac68faa20 2026-05-25), python=3.14.0, node=24.15.0
    - git=04d09d1 dirty
    - seed=42
    - warmup_reps=1
    - serializers=16
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `apache-avro` @ 0.21.0
      - `bincode` @ 2.0.1
      - `bitcode` @ 0.6.9
      - `bson` @ 2.15.0
      - `ciborium` @ 0.2.2
      - `flexbuffers` @ 2.0.0
      - `minicbor` @ 0.25.1
      - `nanoserde` @ 0.1.37
      - `postcard` @ 1.1.3
      - `prost` @ 0.13.5
      - `rkyv` @ 0.8.17
      - `rmp-serde` @ 1.3.1
      - `serde_json` @ 1.0.150
      - `simd-json` @ 0.14.3
      - `sonic-rs` @ 0.3.17
      - `speedy` @ 0.8.7
