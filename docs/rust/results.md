# Rust — Benchmark Results

**Generated:** 2026-07-24T19:43:43.562015

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

> **Stream honesty:** stream rows labeled as **native** 15, **adapted** 141. Only **`native`** (and carefully **`text_on_stream`**) support stream-API performance claims. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| bincode:2.0.1 | 35 | 6.43 | 28.5 | 0.934M | 9.42K | 1821 | **1.00** |
| bitcode:0.6.9 | 83.9 | 41.5 | 42.3 | 0.286M | 9.25K | 1841 | **1.00** |
| bson:2.15.0 | 128 | 36.1 | 91.2 | 0.245M | 21.4K | 1844 | **1.00** |
| ciborium:0.2.2 | 93.2 | 15.1 | 78.1 | 0.308M | 14.2K | 1866 | **1.00** |
| flexbuffers:2.0.0 | 140 | 72.6 | 67.1 | 0.193M | 19.6K | 1869 | **1.00** |
| minicbor:0.25.1 | 53.4 | 13.5 | 39.8 | 0.764M | 9.91K | 1808 | **1.00** |
| nanoserde:0.1.37 | 45.5 | 16.5 | 29.1 | 0.778M | 14.4K | 1813 | **1.00** |
| postcard:1.1.3 | 39.9 | 9.01 | 30.9 | 1.15M | 9.21K | 1796 | **1.00** |
| prost:0.13.5 | 60.7 | 21.3 | 39.4 | 0.691M | 10.2K | 1813 | **1.00** |
| rkyv:0.8.17 | 35.5 | 13.5 | **22.1** | 1.67M | **8.53K** | 1100 | **1.00** |
| rmp-serde:1.3.1 | 49.3 | 8.51 | 40.7 | 0.656M | 14.2K | 1825 | **1.00** |
| serde_avro_fast:2.1.0 | 61.9 | 16.6 | 45.3 | 0.553M | 9.21K | 1803 | **1.00** |
| serde_json:1.0.150 | 89.4 | 22 | 67.4 | 0.304M | 20.5K | 1809 | **1.00** |
| simd-json:0.14.3 | 93.4 | 22 | 71.3 | 0.298M | 20.5K | 1858 | **1.00** |
| sonic-rs:0.3.17 | 66.9 | 17.3 | 49.6 | 0.473M | 20.5K | 1848 | **1.00** |
| speedy:0.8.7 | **29.1** | **4.21** | 24.9 | **1.89M** | 11.9K | 1757 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| bincode:2.0.1 | 0.251 | 0.25 | 0.285 | 0.28 |
| bitcode:0.6.9 | 1.33 | 1.33 | 1.44 | 1.43 |
| bson:2.15.0 | 0.956 | 0.942 | 1.05 | 1.03 |
| ciborium:0.2.2 | 0.698 | 0.696 | 0.997 | 0.984 |
| flexbuffers:2.0.0 | 1.59 | 1.58 | 1.62 | 1.59 |
| minicbor:0.25.1 | 0.244 | 0.241 | 0.345 | 0.342 |
| nanoserde:0.1.37 | 0.299 | 0.291 | 0.432 | 0.425 |
| postcard:1.1.3 | 0.172 | 0.17 | 0.255 | 0.253 |
| prost:0.13.5 | 0.249 | 0.239 | 0.42 | 0.415 |
| rkyv:0.8.17 | 0.213 | 0.203 | 0.351 | 0.348 |
| rmp-serde:1.3.1 | 0.36 | 0.354 | 0.466 | 0.457 |
| serde_avro_fast:2.1.0 | 0.336 | 0.331 | 0.509 | 0.509 |
| serde_json:1.0.150 | 0.608 | 0.603 | 1.4 | 1.4 |
| simd-json:0.14.3 | 0.975 | 0.968 | 0.94 | 0.938 |
| sonic-rs:0.3.17 | 0.512 | 0.508 | 0.582 | 0.579 |
| speedy:0.8.7 | **0.0858** | **0.081** | **0.191** | **0.186** |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| bincode:2.0.1 | 1.3M | 13K | 1.5M | 15K | 4M | 59K | 0.74M | 6.7K | 2.3M | 30K |
| bitcode:0.6.9 | 0.42M | 4.5K | 0.53M | 5.1K | 0.75M | 9.8K | 0.59M | 5.3K | 0.69M | 8.2K |
| bson:2.15.0 | 0.29M | 3.2K | 0.56M | 5.1K | 1M | 12K | 0.26M | 2.6K | 0.35M | 3.6K |
| ciborium:0.2.2 | 0.38M | 3.9K | 0.64M | 6K | 1.4M | 15K | 0.34M | 3.2K | 0.73M | 8.1K |
| flexbuffers:2.0.0 | 0.22M | 2.3K | 0.39M | 3.8K | 0.63M | 7.1K | 0.28M | 2.9K | 0.41M | 4.8K |
| minicbor:0.25.1 | 0.98M | 8.7K | 1.7M | 12K | 4.1M | 39K | 0.59M | 4.5K | 1.3M | 12K |
| nanoserde:0.1.37 | 1.4M | 11K | 1.7M | 11K | 3.3M | 42K | 0.54M | 5.3K | 1.7M | 18K |
| postcard:1.1.3 | 1.6M | 12K | 2.3M | 13K | 5.8M | 55K | 0.77M | 5.6K | 2.8M | 28K |
| prost:0.13.5 | 0.79M | 7.7K | 1.2M | 9.2K | 4M | 39K | 0.42M | 3.6K | 1.7M | 17K |
| rkyv:0.8.17 | 1.6M | - | 1.8M | - | 4.7M | - | 0.71M | 4.8K | 3.3M | - |
| rmp-serde:1.3.1 | 0.83M | 7.8K | 1.5M | 10K | 2.8M | 28K | 0.71M | 6.1K | 1.4M | 17K |
| serde_avro_fast:2.1.0 | 0.7M | 6.9K | 1.3M | 10K | 3M | 32K | 0.52M | 4.1K | 0.95M | 10K |
| serde_json:1.0.150 | 0.53M | 4.9K | 0.94M | 7.2K | 1.6M | 16K | 0.55M | 3.7K | 0.52M | 4.8K |
| simd-json:0.14.3 | 0.41M | 4.6K | 0.64M | 6.1K | 1M | 11K | 0.42M | 4.2K | 0.44M | 4.6K |
| sonic-rs:0.3.17 | 0.66M | 7.2K | 1.2M | 11K | 2M | 22K | 0.67M | 6K | 0.55M | 4.5K |
| speedy:0.8.7 | **2.9M** | **18K** | **3.4M** | **17K** | **12M** | **81K** | **1M** | **7.4K** | **5.9M** | **42K** |

### Within-category ranking

Compare serializers **inside the same family** only (for example JSON with JSON, not JSON with a zero-copy schema codec). Each value is mean serialize+deserialize **operations per second** across data types, using **bytes mode** only (the in-memory buffer API — not “payload size in bytes”). Higher is better. Stream mode is left out of this ranking. Rows are sorted by serializer name; **bold** marks the highest ops/s in the column.

#### JSON

| serializer | mean ops/s (bytes mode) (K) |
|---|---:|
| serde_json:1.0.150 | 420K |
| simd-json:0.14.3 | 300K |
| sonic-rs:0.3.17 | **510K** |

#### Rust-centric binary

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| bincode:2.0.1 | 1M |
| bitcode:0.6.9 | 0.3M |
| nanoserde:0.1.37 | 0.88M |
| postcard:1.1.3 | 1.3M |
| speedy:0.8.7 | **2.5M** |

#### Schema / zero-copy family

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| flexbuffers:2.0.0 | 0.19M |
| prost:0.13.5 | 0.82M |
| rkyv:0.8.17 | **2M** |

#### Schemaless binary (interop)

| serializer | mean ops/s (bytes mode) (K) |
|---|---:|
| bson:2.15.0 | 250K |
| ciborium:0.2.2 | 360K |
| minicbor:0.25.1 | **870K** |
| rmp-serde:1.3.1 | 730K |

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
    
    - **Source CSV:** `logs/rust/2026-07-24-193839.csv`
    - run=2026-07-24-193839
    - language=rust
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: rustc=rustc 1.96.0 (ac68faa20 2026-05-25), python=3.14.0, node=24.15.0
    - git=7431b57 dirty
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
