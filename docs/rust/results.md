# Rust — Benchmark Results

**Generated:** 2026-07-20T12:50:58.939793

This page is a **snapshot of measured numbers** for Rust on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [Rust overview](index.md) |
| How CSVs become these tables | [Analysis methodology](../analysis/ANALYSIS_METHODOLOGY.md) |
| What each metric means | [Metrics catalog](../analysis/METRICS.md) |
| All languages’ result links | [Results summary](../analysis/BENCHMARK_SUMMARY.md) |

## How to read these tables

Compare serializers **inside this language**. Prefer the same [category](../analysis/serialization_categories.md) (for example JSON with JSON) so the comparison stays fair.

| Term | Meaning |
|------|---------|
| **data type** | Sample shape: `message`, `document`, `telemetry`, `strings`, or `event` (CSV `TestDataName`; older text may say “fixture”) |
| **bytes mode** | In-memory buffer API (encode to bytes / decode from a buffer) |
| **stream mode** | Stream-style API (write/read through a stream) |
| **µs** | Microseconds (one microsecond = 1000 nanoseconds). Tables show µs; raw CSVs store nanoseconds. |
| **Ops/s** | Operations per second from mean total time — higher is faster |
| **Bold** | Best value in that column (lowest time/size; highest ops/s). Ties are all bolded. |

Rows are sorted by **serializer name** (easy lookup), not by rank. Batch workloads appear as **Data type · N instances** (for example Message · 100 instances). Default multi-serializer tables show **high-importance** metrics only; pairwise / version A/B reports can show the full set ([Metrics](../analysis/METRICS.md)).

## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| bincode:2.0.1 | 29.1 | 5.49 | 23.5 | 1.44M | 9.42K | 1731 | **1.00** |
| bitcode:0.6.9 | 77.9 | 37.8 | 40 | 0.383M | 9.25K | 1815 | **1.00** |
| bson:2.15.0 | 121 | 35.6 | 84.8 | 0.293M | 21.4K | 1834 | **1.00** |
| ciborium:0.2.2 | 90.4 | 14.6 | 75.8 | 0.381M | 14.2K | 1728 | **1.00** |
| flexbuffers:2.0.0 | 142 | 72.4 | 69.2 | 0.216M | 19.6K | 1794 | **1.00** |
| minicbor:0.25.1 | 45.6 | 12.9 | 32.6 | 1.12M | 9.91K | 1744 | **1.00** |
| nanoserde:0.1.37 | 38.8 | 14.6 | 24.2 | 1.08M | 14.4K | 1772 | **1.00** |
| postcard:1.1.3 | 30.5 | 6.58 | 23.9 | 1.77M | 9.21K | 1741 | **1.00** |
| prost:0.13.5 | 55.1 | 17.7 | 37.4 | 1.1M | 10.2K | 1780 | **1.00** |
| rkyv:0.8.17 | 31 | 11.8 | **19.2** | 2.3M | **8.53K** | 1047 | **1.00** |
| rmp-serde:1.3.1 | 41.3 | 6.92 | 34.4 | 0.899M | 14.2K | 1749 | **1.00** |
| serde_json:1.0.150 | 79.7 | 21.7 | 58.1 | 0.416M | 20.5K | 1759 | **1.00** |
| simd-json:0.14.3 | 84 | 21.4 | 62.5 | 0.376M | 20.5K | 1829 | **1.00** |
| sonic-rs:0.3.17 | 59 | 18.5 | 40.4 | 0.64M | 20.5K | 1739 | **1.00** |
| speedy:0.8.7 | **23.8** | **2.93** | 20.8 | **3.17M** | 11.9K | 1734 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| bincode:2.0.1 | 0.133 | 0.133 | 0.199 | 0.197 |
| bitcode:0.6.9 | 0.888 | 0.887 | 1.05 | 1.03 |
| bson:2.15.0 | 0.733 | 0.73 | 0.805 | 0.8 |
| ciborium:0.2.2 | 0.532 | 0.531 | 0.713 | 0.71 |
| flexbuffers:2.0.0 | 1.29 | 1.29 | 1.4 | 1.39 |
| minicbor:0.25.1 | 0.16 | 0.16 | 0.198 | 0.192 |
| nanoserde:0.1.37 | 0.203 | 0.201 | 0.285 | 0.282 |
| postcard:1.1.3 | 0.127 | 0.128 | 0.141 | 0.141 |
| prost:0.13.5 | 0.157 | 0.157 | 0.185 | 0.182 |
| rkyv:0.8.17 | 0.164 | 0.164 | 0.238 | 0.236 |
| rmp-serde:1.3.1 | 0.285 | 0.285 | 0.313 | 0.314 |
| serde_json:1.0.150 | 0.493 | 0.493 | 0.754 | 0.755 |
| simd-json:0.14.3 | 0.742 | 0.726 | 0.739 | 0.735 |
| sonic-rs:0.3.17 | 0.36 | 0.356 | 0.385 | 0.383 |
| speedy:0.8.7 | **0.0604** | **0.06** | **0.0838** | **0.084** |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| bincode:2.0.1 | 2.1M | 18K | 2.1M | 20K | 7.5M | 86K | 1.2M | **7.1K** | 3.8M | 38K |
| bitcode:0.6.9 | 0.54M | 4.8K | 0.6M | 5.4K | 1.1M | 10K | 0.86M | 5.8K | 0.96M | 9.1K |
| bson:2.15.0 | 0.35M | 3.4K | 0.59M | 5.6K | 1.4M | 12K | 0.33M | 2.6K | 0.38M | 3.9K |
| ciborium:0.2.2 | 0.44M | 4.1K | 0.69M | 6.4K | 1.9M | 16K | 0.42M | 3.2K | 0.86M | 8.3K |
| flexbuffers:2.0.0 | 0.23M | 2.3K | 0.38M | 3.9K | 0.77M | 7K | 0.34M | 2.9K | 0.48M | 4.9K |
| minicbor:0.25.1 | 1.4M | 11K | 2M | 15K | 6.3M | 56K | 0.92M | 4.7K | 1.6M | 15K |
| nanoserde:0.1.37 | 2M | 15K | 2.1M | 16K | 4.9M | 57K | 0.78M | 5.2K | 2.3M | 22K |
| postcard:1.1.3 | 2.5M | 18K | 2.7M | 20K | 7.9M | 85K | 1.3M | 6.1K | 4.7M | 40K |
| prost:0.13.5 | 1.1M | 9.3K | 1.4M | 11K | 6.4M | 60K | 0.59M | 3.6K | 2.3M | 21K |
| rkyv:0.8.17 | 1.9M | - | 2.2M | - | 6.1M | - | 1.1M | 5.5K | 4.3M | - |
| rmp-serde:1.3.1 | 1.1M | 9K | 1.6M | 13K | 3.5M | 37K | 1.1M | 6.4K | 2.2M | 24K |
| serde_json:1.0.150 | 0.61M | 5.6K | 0.97M | 7.8K | 2M | 22K | 0.72M | 3.9K | 0.57M | 5.3K |
| simd-json:0.14.3 | 0.55M | 5.3K | 0.78M | 5.5K | 1.3M | 15K | 0.57M | 4.5K | 0.52M | 4.8K |
| sonic-rs:0.3.17 | 0.82M | 8.3K | 1.5M | 14K | 2.8M | 28K | 1.1M | 6.5K | 0.6M | 4.9K |
| speedy:0.8.7 | **4.6M** | **28K** | **4.1M** | **27K** | **17M** | **140K** | **1.7M** | 7K | **10M** | **63K** |

### Within-category ranking

Compare serializers **inside the same family** only (for example JSON with JSON, not JSON with a zero-copy schema codec). Each value is mean serialize+deserialize **operations per second** across data types, using **bytes mode** only (the in-memory buffer API — not “payload size in bytes”). Higher is better. Stream mode is left out of this ranking. Rows are sorted by serializer name; **bold** marks the highest ops/s in the column.

#### JSON

| serializer | mean ops/s (bytes mode) (K) |
|---|---:|
| serde_json:1.0.150 | 490K |
| simd-json:0.14.3 | 380K |
| sonic-rs:0.3.17 | **680K** |

#### Rust-centric binary

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| bincode:2.0.1 | 1.7M |
| bitcode:0.6.9 | 0.41M |
| nanoserde:0.1.37 | 1.2M |
| postcard:1.1.3 | 1.9M |
| speedy:0.8.7 | **3.7M** |

#### Schema / zero-copy family

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| flexbuffers:2.0.0 | 0.22M |
| prost:0.13.5 | 1.2M |
| rkyv:0.8.17 | **2.6M** |

#### Schemaless binary (interop)

| serializer | mean ops/s (bytes mode) (M) |
|---|---:|
| bson:2.15.0 | 0.3M |
| ciborium:0.2.2 | 0.43M |
| minicbor:0.25.1 | **1.2M** |
| rmp-serde:1.3.1 | 0.96M |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/rust/2026-07-20-125050.csv`
    - run=2026-07-20-125050
    - language=rust
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: rustc=rustc 1.96.0 (ac68faa20 2026-05-25), python=3.14.0, node=24.15.0
    - git=61a38cf dirty
    - seed=42
    - warmup_reps=1
    - serializers=15
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
      - `serde_json` @ 1.0.150
      - `simd-json` @ 0.14.3
      - `sonic-rs` @ 0.3.17
      - `speedy` @ 0.8.7
