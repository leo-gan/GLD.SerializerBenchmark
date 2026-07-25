# C — Benchmark Results

**Generated:** 2026-07-24T19:43:49.999022

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

> **Stream honesty:** all stream rows are **`adapted`** (in-memory encode/decode then dump to a stream, or equivalent). Do **not** treat stream columns as proof of incremental I/O. Labels: **adapted** 190. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| avro-c:1.11.3 | 32.3 | 12.9 | 19.4 | 0.486M | 10.9K | 1768 | **1.00** |
| cbor-encode:0.11.0 | 356 | 103 | 253 | 0.0733M | 15.1K | 1837 | **1.00** |
| cJSON:1.7.18 | 513 | 347 | 165 | 0.0716M | 19.9K | 1833 | **1.00** |
| custom-binary:v2-1.0 | **19** | **6.02** | **13** | **1.51M** | 10.7K | 1725 | **1.00** |
| flatcc:0.6.1 | 26.1 | 13 | 13 | 0.744M | 12.2K | 1773 | **1.00** |
| jansson:2.14 | 647 | 298 | 349 | 0.0436M | 20.1K | 1849 | **1.00** |
| json-c:0.15 | 522 | 249 | 272 | 0.0547M | 20.1K | 1854 | **1.00** |
| libbson:1.27.5 | 316 | 96.7 | 219 | 0.114M | 21.1K | 1837 | **1.00** |
| mpack:1.1 | 56.4 | 14.7 | 41.6 | 0.3M | 13.7K | 1779 | **1.00** |
| msgpack-c:6.0.1 | 57.7 | 21 | 36.7 | 0.295M | 13.7K | 1792 | **1.00** |
| nanopb:0.4.9 | 27.9 | 11.7 | 16.2 | 0.905M | **10.5K** | 1767 | **1.00** |
| parson:1.5.3 | 749 | 561 | 188 | 0.0461M | 20.1K | 1824 | **1.00** |
| protobuf-c:1.5.0 | 27.9 | 11.9 | 16 | 0.894M | **10.5K** | 1758 | **1.00** |
| protobuf-wire:wire-v2 | 28 | 11.8 | 16.2 | 0.9M | **10.5K** | 1744 | **1.00** |
| qcbor:1.5.1 | 309 | 56.4 | 253 | 0.101M | 13.8K | 1770 | **1.00** |
| tinycbor:0.6.0 | 274 | 20.4 | 253 | 0.122M | 13.8K | 1819 | **1.00** |
| ubj:1.0-min | 21.3 | 7.63 | 13.7 | 1.08M | 12.6K | 1795 | **1.00** |
| yyjson:0.10.0 | 123 | 58.1 | 65 | 0.196M | 19.8K | 1823 | **1.00** |
| zcbor:0.9 | 326 | 35.3 | 291 | 0.102M | 14K | 1785 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro-c:1.11.3 | 0.636 | 0.621 | 1.02 | 1.02 |
| cbor-encode:0.11.0 | 3.17 | 3.16 | 3.49 | 3.51 |
| cJSON:1.7.18 | 3.46 | 3.43 | 3.82 | 3.83 |
| custom-binary:v2-1.0 | **0.125** | **0.125** | **0.509** | **0.504** |
| flatcc:0.6.1 | 0.344 | 0.34 | 0.739 | 0.733 |
| jansson:2.14 | 5.78 | 5.71 | 5.92 | 5.92 |
| json-c:0.15 | 5 | 4.96 | 5.06 | 5.05 |
| libbson:1.27.5 | 1.72 | 1.7 | 1.99 | 1.99 |
| mpack:1.1 | 0.996 | 0.971 | 1.17 | 1.17 |
| msgpack-c:6.0.1 | 0.979 | 0.956 | 1.16 | 1.16 |
| nanopb:0.4.9 | 0.212 | 0.21 | 0.604 | 0.594 |
| parson:1.5.3 | 6.16 | 6.17 | 6.29 | 6.32 |
| protobuf-c:1.5.0 | 0.209 | 0.211 | 0.592 | 0.586 |
| protobuf-wire:wire-v2 | 0.213 | 0.215 | 0.61 | 0.591 |
| qcbor:1.5.1 | 2.29 | 2.27 | 2.59 | 2.57 |
| tinycbor:0.6.0 | 1.83 | 1.82 | 2.13 | 2.13 |
| ubj:1.0-min | 0.199 | 0.196 | 0.609 | 0.594 |
| yyjson:0.10.0 | 1.28 | 1.28 | 1.63 | 1.65 |
| zcbor:0.9 | 2.06 | 2.06 | 2.37 | 2.37 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro-c:1.11.3 | 0.96M | 17K | 1M | 17K | 1.6M | 21K | 1.1M | 11K | 1.2M | 18K |
| cbor-encode:0.11.0 | 0.079M | 1.1K | 0.19M | 2.6K | 0.32M | 4.1K | 0.077M | 0.85K | 0.1M | 1.3K |
| cJSON:1.7.18 | 0.097M | 1.3K | 0.19M | 2.3K | 0.29M | 3.4K | 0.16M | 1.6K | 0.034M | 0.34K |
| custom-binary:v2-1.0 | **3.7M** | **30K** | **3M** | **30K** | **8M** | **40K** | **2.9M** | **16K** | **5M** | **36K** |
| flatcc:0.6.1 | 1.6M | 21K | 1.6M | 21K | 2.9M | 26K | 1.8M | 13K | 1.9M | 23K |
| jansson:2.14 | 0.052M | 0.65K | 0.1M | 1.3K | 0.17M | 2.1K | 0.083M | 0.89K | 0.038M | 0.41K |
| json-c:0.15 | 0.06M | 0.8K | 0.12M | 1.6K | 0.2M | 2.4K | 0.12M | 1.3K | 0.045M | 0.47K |
| libbson:1.27.5 | 0.14M | 2K | 0.29M | 3.6K | 0.58M | 7.2K | 0.079M | 0.82K | 0.093M | 1K |
| mpack:1.1 | 0.32M | 6.3K | 0.56M | 11K | 1M | 18K | 0.6M | 6.3K | 0.53M | 12K |
| msgpack-c:6.0.1 | 0.32M | 5.7K | 0.55M | 10K | 1M | 17K | 0.62M | 7.6K | 0.48M | 10K |
| nanopb:0.4.9 | 1.3M | 13K | 1.7M | 20K | 4.7M | 37K | 1.7M | 13K | 3.1M | 27K |
| parson:1.5.3 | 0.044M | 0.56K | 0.12M | 1.5K | 0.16M | 1.9K | 0.13M | 1.3K | 0.027M | 0.27K |
| protobuf-c:1.5.0 | 1.3M | 13K | 1.7M | 20K | 4.8M | 37K | 1.7M | 13K | 2.8M | 27K |
| protobuf-wire:wire-v2 | 1.2M | 13K | 1.8M | 20K | 4.7M | 37K | 1.7M | 13K | 2.9M | 27K |
| qcbor:1.5.1 | 0.11M | 1.3K | 0.29M | 3.5K | 0.44M | 4.8K | 0.092M | 0.96K | 0.12M | 1.3K |
| tinycbor:0.6.0 | 0.14M | 1.6K | 0.37M | 4.5K | 0.55M | 5.9K | 0.096M | 1K | 0.13M | 1.5K |
| ubj:1.0-min | 2.6M | 27K | 2.3M | 27K | 5M | 34K | 2.4M | 15K | 3.2M | 30K |
| yyjson:0.10.0 | 0.2M | 3.1K | 0.44M | 5K | 0.78M | 9.7K | 0.35M | 3.1K | 0.3M | 3.8K |
| zcbor:0.9 | 0.11M | 1.3K | 0.28M | 3.3K | 0.49M | 5.3K | 0.082M | 0.87K | 0.11M | 1.3K |

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
    
    - **Source CSV:** `logs/c/2026-07-24-193854.csv`
    - run=2026-07-24-193854
    - language=c
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: gcc=gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, python=3.14.0, node=24.15.0
    - git=7431b57 dirty
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
