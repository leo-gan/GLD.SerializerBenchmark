# Rust — Benchmark Results

**Generated:** 2026-07-24T18:57:57.694753

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
| bincode:2.0.1 | 35.9 | 6.52 | 29.2 | 0.831M | 9.42K | 1782 | **1.00** |
| bitcode:0.6.9 | 84.5 | 41.8 | 42.5 | 0.258M | 9.25K | 1780 | **1.00** |
| bson:2.15.0 | 130 | 36.4 | 93.4 | 0.205M | 21.4K | 1812 | **1.00** |
| ciborium:0.2.2 | 95.4 | 15.2 | 80.2 | 0.27M | 14.2K | 1841 | **1.00** |
| flexbuffers:2.0.0 | 142 | 73.8 | 68.5 | 0.168M | 19.6K | 1825 | **1.00** |
| minicbor:0.25.1 | 54 | 13.7 | 40.3 | 0.606M | 9.91K | 1780 | **1.00** |
| nanoserde:0.1.37 | 46.2 | 16.9 | 29.4 | 0.655M | 14.4K | 1768 | **1.00** |
| postcard:1.1.3 | 40.7 | 9.15 | 31.5 | 0.961M | 9.21K | 1765 | **1.00** |
| prost:0.13.5 | 62 | 21.2 | 40.8 | 0.565M | 10.2K | 1795 | **1.00** |
| rkyv:0.8.17 | 36.5 | 14.1 | **22.4** | 1.36M | **8.53K** | 1067 | **1.00** |
| rmp-serde:1.3.1 | 50.5 | 8.61 | 41.9 | 0.546M | 14.2K | 1788 | **1.00** |
| serde_avro_fast:2.1.0 | 63 | 17.1 | 45.9 | 0.466M | 9.21K | 1778 | **1.00** |
| serde_json:1.0.150 | 88.9 | 21.4 | 67.4 | 0.303M | 20.5K | 1818 | **1.00** |
| simd-json:0.14.3 | 94.3 | 21.4 | 72.7 | 0.263M | 20.5K | 1836 | **1.00** |
| sonic-rs:0.3.17 | 68.5 | 17.8 | 50.6 | 0.404M | 20.5K | 1829 | **1.00** |
| speedy:0.8.7 | **29.8** | **4.28** | 25.5 | **1.55M** | 11.9K | 1748 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| bincode:2.0.1 | 0.518 | 0.517 | 0.314 | 0.312 |
| bitcode:0.6.9 | 3.21 | 3.21 | 1.65 | 1.63 |
| bson:2.15.0 | 2.31 | 2.32 | 1.22 | 1.22 |
| ciborium:0.2.2 | 1.7 | 1.69 | 1.05 | 1.04 |
| flexbuffers:2.0.0 | 3.71 | 3.71 | 1.89 | 1.87 |
| minicbor:0.25.1 | 0.759 | 0.755 | 0.4 | 0.391 |
| nanoserde:0.1.37 | 0.68 | 0.675 | 0.509 | 0.497 |
| postcard:1.1.3 | 0.434 | 0.436 | 0.29 | 0.287 |
| prost:0.13.5 | 0.718 | 0.721 | 0.441 | 0.432 |
| rkyv:0.8.17 | 0.659 | 0.661 | 0.413 | 0.402 |
| rmp-serde:1.3.1 | 0.951 | 0.953 | 0.515 | 0.5 |
| serde_avro_fast:2.1.0 | 1.32 | 1.31 | 0.455 | 0.449 |
| serde_json:1.0.150 | 1.46 | 1.46 | 0.956 | 0.954 |
| simd-json:0.14.3 | 2.22 | 2.21 | 1.11 | 1.1 |
| sonic-rs:0.3.17 | 1.45 | 1.47 | 0.634 | 0.625 |
| speedy:0.8.7 | **0.235** | **0.229** | **0.205** | **0.197** |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| bincode:2.0.1 | 1.3M | 13K | 1.5M | 14K | 1.9M | 57K | 0.72M | 6.4K | 2.6M | 29K |
| bitcode:0.6.9 | 0.4M | 4.6K | 0.54M | 5K | 0.31M | 9.9K | 0.6M | 5.1K | 0.71M | 8.1K |
| bson:2.15.0 | 0.29M | 3.2K | 0.55M | 5K | 0.43M | 12K | 0.25M | 2.5K | 0.35M | 3.5K |
| ciborium:0.2.2 | 0.37M | 3.9K | 0.64M | 5.8K | 0.59M | 15K | 0.34M | 3.1K | 0.75M | 7.6K |
| flexbuffers:2.0.0 | 0.21M | 2.3K | 0.39M | 3.7K | 0.27M | 7K | 0.27M | 2.8K | 0.42M | 4.5K |
| minicbor:0.25.1 | 1M | 8.9K | 1.6M | 11K | 1.3M | 39K | 0.6M | 4.4K | 1.3M | 12K |
| nanoserde:0.1.37 | 1.4M | 11K | 1.7M | 11K | 1.5M | 42K | 0.5M | 5K | 1.7M | 17K |
| postcard:1.1.3 | 1.7M | 12K | 2.3M | 13K | 2.3M | 54K | 0.77M | 5.4K | 2.9M | 26K |
| prost:0.13.5 | 0.8M | 7.6K | 1.1M | 9K | 1.4M | 37K | 0.44M | 3.4K | 1.8M | 17K |
| rkyv:0.8.17 | 1.2M | - | 1.9M | - | 1.5M | - | 0.71M | 4.6K | 3.4M | - |
| rmp-serde:1.3.1 | 0.8M | 7.6K | 1.4M | 10K | 1.1M | 27K | 0.68M | 5.9K | 1.4M | 16K |
| serde_avro_fast:2.1.0 | 0.71M | 7.1K | 1.2M | 9.6K | 0.76M | 32K | 0.51M | 4K | 0.98M | 10K |
| serde_json:1.0.150 | 0.54M | 5.1K | 0.91M | 7.2K | 0.69M | 16K | 0.54M | 3.7K | 0.52M | 4.8K |
| simd-json:0.14.3 | 0.44M | 4.7K | 0.65M | 5.9K | 0.45M | 11K | 0.41M | 4.2K | 0.44M | 4.4K |
| sonic-rs:0.3.17 | 0.66M | 7.1K | 1.2M | 11K | 0.69M | 23K | 0.68M | 5.7K | 0.56M | 4.3K |
| speedy:0.8.7 | **2.8M** | **18K** | **3.4M** | **16K** | **4.3M** | **80K** | **1M** | **7K** | **6.6M** | **39K** |

### Within-category ranking

Compare serializers **inside the same family** only (for example JSON with JSON, not JSON with a zero-copy schema codec). Each value is mean serialize+deserialize **operations per second** across data types, using **bytes mode** only (the in-memory buffer API — not “payload size in bytes”). Higher is better. Stream mode is left out of this ranking. Rows are sorted by serializer name; **bold** marks the highest ops/s in the column.

#### JSON

| serializer | mean ops/s (bytes mode) (K) |
|---|---:|
| serde_json:1.0.150 | 320K |
| simd-json:0.14.3 | 240K |
| sonic-rs:0.3.17 | **390K** |

#### Rust-centric binary

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| bincode:2.0.1 | 0.81M |
| bitcode:0.6.9 | 0.26M |
| nanoserde:0.1.37 | 0.69M |
| postcard:1.1.3 | 1M |
| speedy:0.8.7 | **1.8M** |

#### Schema / zero-copy family

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| flexbuffers:2.0.0 | 0.16M |
| prost:0.13.5 | 0.57M |
| rkyv:0.8.17 | **1.5M** |

#### Schemaless binary (interop)

| serializer | mean ops/s (bytes mode) (K) |
|---|---:|
| bson:2.15.0 | 190K |
| ciborium:0.2.2 | 270K |
| minicbor:0.25.1 | **590K** |
| rmp-serde:1.3.1 | 540K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/rust/2026-07-24-183742.csv`
    - run=2026-07-24-183742
    - language=rust
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: rustc=rustc 1.96.0 (ac68faa20 2026-05-25), python=3.14.0, node=24.15.0
    - git=85145fd dirty
    - seed=42
    - warmup_reps=1
    - serializers=16
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
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
      - `serde_avro_fast` @ 2.1.0
      - `serde_json` @ 1.0.150
      - `simd-json` @ 0.14.3
      - `sonic-rs` @ 0.3.17
      - `speedy` @ 0.8.7
