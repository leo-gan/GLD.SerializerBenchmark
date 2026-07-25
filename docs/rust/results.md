# Rust — Benchmark Results

**Generated:** 2026-07-24T20:23:51.658221

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
| bincode:2.0.1 | 34 | 6.21 | 27.7 | 0.962M | 9.42K | 1790 | **1.00** |
| bitcode:0.6.9 | 81 | 40.1 | 40.8 | 0.296M | 9.25K | 1798 | **1.00** |
| bson:2.15.0 | 124 | 35.2 | 88.4 | 0.25M | 21.4K | 1835 | **1.00** |
| ciborium:0.2.2 | 91 | 14.6 | 76.4 | 0.314M | 14.2K | 1817 | **1.00** |
| flexbuffers:2.0.0 | 135 | 70.4 | 65 | 0.198M | 19.6K | 1817 | **1.00** |
| minicbor:0.25.1 | 51.9 | 13.1 | 38.8 | 0.784M | 9.91K | 1773 | **1.00** |
| nanoserde:0.1.37 | 44.2 | 16.1 | 28 | 0.788M | 14.4K | 1774 | **1.00** |
| postcard:1.1.3 | 38.7 | 8.74 | 29.9 | 1.21M | 9.21K | 1743 | **1.00** |
| prost:0.13.5 | 59.1 | 20.5 | 38.6 | 0.702M | 10.2K | 1786 | **1.00** |
| rkyv:0.8.17 | 34.7 | 13.4 | **21.3** | 1.64M | **8.53K** | 1057 | **1.00** |
| rmp-serde:1.3.1 | 47.8 | 8.21 | 39.6 | 0.675M | 14.2K | 1786 | **1.00** |
| serde_avro_fast:2.1.0 | 59.9 | 16.1 | 43.8 | 0.567M | 9.21K | 1779 | **1.00** |
| serde_json:1.0.150 | 86.4 | 21.3 | 65.1 | 0.309M | 20.5K | 1810 | **1.00** |
| simd-json:0.14.3 | 91.1 | 21.2 | 69.7 | 0.301M | 20.5K | 1823 | **1.00** |
| sonic-rs:0.3.17 | 64.4 | 16.6 | 47.8 | 0.485M | 20.5K | 1816 | **1.00** |
| speedy:0.8.7 | **28.3** | **4.09** | 24.2 | **1.96M** | 11.9K | 1738 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| bincode:2.0.1 | 0.253 | 0.252 | 0.275 | 0.27 |
| bitcode:0.6.9 | 1.31 | 1.3 | 1.38 | 1.38 |
| bson:2.15.0 | 0.959 | 0.933 | 1.02 | 1.01 |
| ciborium:0.2.2 | 0.691 | 0.688 | 0.965 | 0.966 |
| flexbuffers:2.0.0 | 1.6 | 1.59 | 1.57 | 1.55 |
| minicbor:0.25.1 | 0.241 | 0.239 | 0.331 | 0.331 |
| nanoserde:0.1.37 | 0.298 | 0.284 | 0.426 | 0.426 |
| postcard:1.1.3 | 0.165 | 0.164 | 0.237 | 0.235 |
| prost:0.13.5 | 0.248 | 0.238 | 0.405 | 0.402 |
| rkyv:0.8.17 | 0.236 | 0.232 | 0.344 | 0.338 |
| rmp-serde:1.3.1 | 0.354 | 0.347 | 0.44 | 0.437 |
| serde_avro_fast:2.1.0 | 0.325 | 0.321 | 0.504 | 0.5 |
| serde_json:1.0.150 | 0.601 | 0.594 | 1.38 | 1.34 |
| simd-json:0.14.3 | 1.01 | 0.978 | 0.937 | 0.942 |
| sonic-rs:0.3.17 | 0.506 | 0.502 | 0.563 | 0.56 |
| speedy:0.8.7 | **0.0796** | **0.08** | **0.188** | **0.186** |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| bincode:2.0.1 | 1.3M | 13K | 1.6M | 15K | 4M | 64K | 0.78M | 6.9K | 2.4M | 31K |
| bitcode:0.6.9 | 0.43M | 4.7K | 0.54M | 5.3K | 0.76M | 11K | 0.64M | 5.4K | 0.71M | 8.6K |
| bson:2.15.0 | 0.3M | 3.3K | 0.56M | 5.2K | 1M | 13K | 0.28M | 2.6K | 0.36M | 3.7K |
| ciborium:0.2.2 | 0.38M | 4K | 0.65M | 6.2K | 1.4M | 16K | 0.35M | 3.3K | 0.75M | 8.3K |
| flexbuffers:2.0.0 | 0.22M | 2.4K | 0.4M | 3.9K | 0.63M | 7.7K | 0.3M | 3K | 0.42M | 4.9K |
| minicbor:0.25.1 | 1M | 9K | 1.6M | 12K | 4.2M | 42K | 0.6M | 4.6K | 1.3M | 13K |
| nanoserde:0.1.37 | 1.4M | 12K | 1.7M | 12K | 3.4M | 45K | 0.58M | 5.4K | 1.7M | 18K |
| postcard:1.1.3 | 1.7M | 12K | 2.3M | 14K | 6M | 60K | 0.83M | 5.7K | 3M | 29K |
| prost:0.13.5 | 0.84M | 8K | 1.2M | 9.5K | 4M | 42K | 0.46M | 3.7K | 1.7M | 18K |
| rkyv:0.8.17 | 1.6M | - | 1.9M | - | 4.2M | - | 0.74M | 4.9K | 3M | - |
| rmp-serde:1.3.1 | 0.88M | 8.1K | 1.4M | 11K | 2.8M | 30K | 0.74M | 6.2K | 1.4M | 17K |
| serde_avro_fast:2.1.0 | 0.74M | 7.3K | 1.2M | 10K | 3.1M | 35K | 0.54M | 4.3K | 0.99M | 11K |
| serde_json:1.0.150 | 0.56M | 5.1K | 0.93M | 7.5K | 1.7M | 17K | 0.56M | 3.8K | 0.53M | 5K |
| simd-json:0.14.3 | 0.44M | 4.7K | 0.62M | 6.2K | 0.99M | 12K | 0.45M | 4.4K | 0.45M | 4.7K |
| sonic-rs:0.3.17 | 0.68M | 7.5K | 1.2M | 11K | 2M | 24K | 0.71M | 6.2K | 0.56M | 4.7K |
| speedy:0.8.7 | **2.8M** | **19K** | **3.5M** | **18K** | **13M** | **88K** | **1M** | **7.7K** | **5.9M** | **42K** |

### Within-category ranking

Compare serializers **inside the same family** only (for example JSON with JSON, not JSON with a zero-copy schema codec). Each value is mean serialize+deserialize **operations per second** across data types, using **bytes mode** only (the in-memory buffer API — not “payload size in bytes”). Higher is better. Stream mode is left out of this ranking. Rows are sorted by serializer name; **bold** marks the highest ops/s in the column.

#### JSON

| serializer | mean ops/s (bytes mode) (K) |
|---|---:|
| serde_json:1.0.150 | 430K |
| simd-json:0.14.3 | 300K |
| sonic-rs:0.3.17 | **520K** |

#### Rust-centric binary

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| bincode:2.0.1 | 1M |
| bitcode:0.6.9 | 0.31M |
| nanoserde:0.1.37 | 0.89M |
| postcard:1.1.3 | 1.4M |
| speedy:0.8.7 | **2.6M** |

#### Schema / zero-copy family

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| flexbuffers:2.0.0 | 0.2M |
| prost:0.13.5 | 0.83M |
| rkyv:0.8.17 | **1.9M** |

#### Schemaless binary (interop)

| serializer | mean ops/s (bytes mode) (K) |
|---|---:|
| bson:2.15.0 | 260K |
| ciborium:0.2.2 | 360K |
| minicbor:0.25.1 | **880K** |
| rmp-serde:1.3.1 | 740K |

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
    
    - **Source CSV:** `logs/rust/2026-07-24-201921.csv`
    - run=2026-07-24-201921
    - language=rust
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: rustc=rustc 1.96.0 (ac68faa20 2026-05-25), python=3.14.0, node=24.15.0
    - git=40f6a8e dirty
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
