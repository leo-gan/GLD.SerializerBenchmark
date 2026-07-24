# Rust — Benchmark Results

**Generated:** 2026-07-24T16:20:17.681380

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
| bincode:2.0.1 | 25.5 | 5.43 | 20.1 | 1.45M | 9.42K | 1760 | **1.00** |
| bitcode:0.6.9 | 68.6 | 33.9 | 34.6 | 0.404M | 9.25K | 1792 | **1.00** |
| bson:2.15.0 | 107 | 31.4 | 75.6 | 0.276M | 21.4K | 1780 | **1.00** |
| ciborium:0.2.2 | 80.7 | 13.3 | 67.5 | 0.364M | 14.2K | 1792 | **1.00** |
| flexbuffers:2.0.0 | 123 | 61.4 | 61.2 | 0.222M | 19.6K | 1830 | **1.00** |
| minicbor:0.25.1 | 40.6 | 11.6 | 29.1 | 1.03M | 9.91K | 1718 | **1.00** |
| nanoserde:0.1.37 | 33 | 12.5 | 20.5 | 1.15M | 14.4K | 1756 | **1.00** |
| postcard:1.1.3 | 26.8 | 5.55 | 21.3 | 1.67M | 9.21K | 1752 | **1.00** |
| prost:0.13.5 | 49.4 | 17.5 | 31.8 | 0.948M | 10.2K | 1809 | **1.00** |
| rkyv:0.8.17 | 27.5 | 10.5 | 17 | 2.41M | **8.53K** | 1049 | **1.00** |
| rmp-serde:1.3.1 | 36.4 | 6.43 | 30 | 0.893M | 14.2K | 1738 | **1.00** |
| serde_avro_fast:2.1.0 | 49.6 | 14.8 | 34.8 | 0.694M | 9.21K | 1769 | **1.00** |
| serde_json:1.0.150 | 67 | 17.6 | 49.3 | 0.442M | 20.5K | 1740 | **1.00** |
| simd-json:0.14.3 | 72.1 | 17.6 | 54.5 | 0.38M | 20.5K | 1791 | **1.00** |
| sonic-rs:0.3.17 | 53.2 | 15 | 38.1 | 0.574M | 20.5K | 1749 | **1.00** |
| speedy:0.8.7 | **19.3** | **2.57** | **16.7** | **3.23M** | 11.9K | 1767 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| bincode:2.0.1 | 0.181 | 0.18 | 0.264 | 0.264 |
| bitcode:0.6.9 | 1.33 | 1.33 | 1.5 | 1.49 |
| bson:2.15.0 | 1.06 | 1.06 | 1.32 | 1.31 |
| ciborium:0.2.2 | 0.853 | 0.846 | 1.03 | 1.03 |
| flexbuffers:2.0.0 | 1.89 | 1.88 | 2.05 | 2.03 |
| minicbor:0.25.1 | 0.242 | 0.242 | 0.303 | 0.303 |
| nanoserde:0.1.37 | 0.277 | 0.277 | 0.265 | 0.263 |
| postcard:1.1.3 | 0.159 | 0.159 | 0.194 | 0.194 |
| prost:0.13.5 | 0.261 | 0.258 | 0.273 | 0.272 |
| rkyv:0.8.17 | 0.236 | 0.236 | 0.322 | 0.321 |
| rmp-serde:1.3.1 | 0.355 | 0.355 | 0.404 | 0.403 |
| serde_avro_fast:2.1.0 | 0.415 | 0.414 | 0.503 | 0.499 |
| serde_json:1.0.150 | 0.635 | 0.63 | 0.941 | 0.938 |
| simd-json:0.14.3 | 0.971 | 0.963 | 0.991 | 1.04 |
| sonic-rs:0.3.17 | 0.656 | 0.656 | 0.717 | 0.715 |
| speedy:0.8.7 | **0.0706** | **0.07** | **0.092** | **0.092** |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| bincode:2.0.1 | 2.6M | 19K | 2.9M | 21K | 5.5M | 110K | 1.4M | 8.1K | 4.9M | 44K |
| bitcode:0.6.9 | 0.68M | 5.4K | 0.75M | 6K | 0.75M | 12K | 1M | 6.4K | 1.1M | 11K |
| bson:2.15.0 | 0.41M | 3.8K | 0.73M | 6.3K | 0.94M | 15K | 0.37M | 2.9K | 0.43M | 4.3K |
| ciborium:0.2.2 | 0.51M | 4.6K | 0.84M | 7K | 1.2M | 18K | 0.49M | 3.6K | 1M | 9.5K |
| flexbuffers:2.0.0 | 0.28M | 2.6K | 0.5M | 4.3K | 0.53M | 8K | 0.41M | 3.3K | 0.57M | 5.7K |
| minicbor:0.25.1 | 1.7M | 12K | 2.6M | 17K | 4.1M | 65K | 1M | 5.3K | 1.8M | 17K |
| nanoserde:0.1.37 | 2.5M | 17K | 2.6M | 17K | 3.6M | 69K | 0.83M | 6.4K | 2.7M | 25K |
| postcard:1.1.3 | 2.7M | 20K | 3.3M | 22K | 6.3M | 96K | 1.4M | 7.1K | 4.9M | 44K |
| prost:0.13.5 | 1.2M | 9.6K | 1.7M | 12K | 3.8M | 64K | 0.67M | 4.1K | 2.8M | 24K |
| rkyv:0.8.17 | 2.6M | - | 2.9M | - | 4.2M | - | 1.2M | 6.1K | 5.4M | - |
| rmp-serde:1.3.1 | 1.2M | 10K | 1.9M | 14K | 2.8M | 44K | 1.3M | 7.2K | 2.7M | 27K |
| serde_avro_fast:2.1.0 | 1.1M | 9K | 1.7M | 13K | 2.4M | 44K | 0.87M | 4.8K | 1.3M | 13K |
| serde_json:1.0.150 | 0.75M | 6.6K | 1.3M | 9.8K | 1.6M | 25K | 0.9M | 4.7K | 0.66M | 6.2K |
| simd-json:0.14.3 | 0.64M | 6.1K | 0.98M | 8.3K | 1M | 17K | 0.63M | 5.3K | 0.6M | 5.5K |
| sonic-rs:0.3.17 | 0.99M | 8.9K | 1.8M | 14K | 1.5M | 32K | 1.2M | 7.4K | 0.67M | 5.6K |
| speedy:0.8.7 | **5.7M** | **32K** | **4.9M** | **29K** | **14M** | **150K** | **2M** | **9.2K** | **11M** | **74K** |

### Within-category ranking

Compare serializers **inside the same family** only (for example JSON with JSON, not JSON with a zero-copy schema codec). Each value is mean serialize+deserialize **operations per second** across data types, using **bytes mode** only (the in-memory buffer API — not “payload size in bytes”). Higher is better. Stream mode is left out of this ranking. Rows are sorted by serializer name; **bold** marks the highest ops/s in the column.

#### JSON

| serializer | mean ops/s (bytes mode) (K) |
|---|---:|
| serde_json:1.0.150 | 520K |
| simd-json:0.14.3 | 390K |
| sonic-rs:0.3.17 | **630K** |

#### Rust-centric binary

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| bincode:2.0.1 | 1.8M |
| bitcode:0.6.9 | 0.44M |
| nanoserde:0.1.37 | 1.2M |
| postcard:1.1.3 | 1.9M |
| speedy:0.8.7 | **3.8M** |

#### Schema / zero-copy family

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| flexbuffers:2.0.0 | 0.23M |
| prost:0.13.5 | 1M |
| rkyv:0.8.17 | **2.7M** |

#### Schemaless binary (interop)

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| bson:2.15.0 | 0.29M |
| ciborium:0.2.2 | 0.4M |
| minicbor:0.25.1 | **1.1M** |
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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/rust/2026-07-24-162009.csv`
    - run=2026-07-24-162009
    - language=rust
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: rustc=rustc 1.96.0 (ac68faa20 2026-05-25), python=3.14.0, node=24.15.0
    - git=78ae35f
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
