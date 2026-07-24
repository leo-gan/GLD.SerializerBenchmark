# C — Benchmark Results

**Generated:** 2026-07-24T15:53:18.449705

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
| avro-c:1.11.3 | 26.8 | 10.3 | 16.5 | 0.946M | 10.9K | 1714 | **1.00** |
| cbor-encode:0.11.0 | 340 | 97.1 | 243 | 0.0829M | 15.1K | 1820 | **1.00** |
| cJSON:1.7.18 | 481 | 330 | 150 | 0.0863M | 19.9K | 1788 | **1.00** |
| custom-binary:v2-1.0 | **15.2** | **3.96** | 11.2 | **2.2M** | 10.7K | 1674 | **1.00** |
| flatcc:0.6.1 | 20.9 | 10.3 | **10.7** | 1.35M | 12.2K | 1675 | **1.00** |
| jansson:2.14 | 614 | 288 | 326 | 0.0473M | 20.1K | 1819 | **1.00** |
| json-c:0.15 | 502 | 248 | 254 | 0.0617M | 20.1K | 1812 | **1.00** |
| libbson:1.27.5 | 291 | 91.3 | 199 | 0.126M | 21.1K | 1751 | **1.00** |
| mpack:1.1 | 48.9 | 12.2 | 36.7 | 0.516M | 13.7K | 1717 | **1.00** |
| msgpack-c:6.0.1 | 52.6 | 19.9 | 32.7 | 0.471M | 13.7K | 1738 | **1.00** |
| nanopb:0.4.9 | 23 | 9.48 | 13.5 | 1.11M | **10.5K** | 1647 | **1.00** |
| parson:1.5.3 | 714 | 536 | 177 | 0.0575M | 20.1K | 1738 | **1.00** |
| protobuf-c:1.5.0 | 22.7 | 9.27 | 13.4 | 1.42M | **10.5K** | 1658 | **1.00** |
| protobuf-wire:wire-v2 | 22.7 | 9.41 | 13.3 | 1.4M | **10.5K** | 1659 | **1.00** |
| qcbor:1.5.1 | 297 | 54.6 | 242 | 0.101M | 13.8K | 1799 | **1.00** |
| tinycbor:0.6.0 | 263 | 19.3 | 244 | 0.126M | 13.8K | 1777 | **1.00** |
| ubj:1.0-min | 17.5 | 5.8 | 11.7 | 1.63M | 12.6K | 1711 | **1.00** |
| yyjson:0.10.0 | 107 | 50.6 | 56.7 | 0.255M | 19.8K | 1729 | **1.00** |
| zcbor:0.9 | 312 | 33.3 | 279 | 0.127M | 14K | 1819 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro-c:1.11.3 | 0.305 | 0.303 | 0.65 | 0.649 |
| cbor-encode:0.11.0 | 3.21 | 3.21 | 4.07 | 4.07 |
| cJSON:1.7.18 | 3.75 | 3.74 | 4.54 | 4.53 |
| custom-binary:v2-1.0 | 0.203 | 0.203 | 0.689 | 0.689 |
| flatcc:0.6.1 | 0.189 | 0.188 | 0.571 | 0.57 |
| jansson:2.14 | 6.41 | 6.38 | 6.98 | 6.94 |
| json-c:0.15 | 5.15 | 5.12 | 6.03 | 6.03 |
| libbson:1.27.5 | 1.78 | 1.78 | 2.4 | 2.4 |
| mpack:1.1 | 0.637 | 0.637 | 1.15 | 1.15 |
| msgpack-c:6.0.1 | 0.683 | 0.683 | 1.19 | 1.19 |
| nanopb:0.4.9 | 0.276 | 0.276 | 0.765 | 0.766 |
| parson:1.5.3 | 6.07 | 6.07 | 6.9 | 6.89 |
| protobuf-c:1.5.0 | **0.111** | **0.111** | **0.456** | **0.454** |
| protobuf-wire:wire-v2 | 0.113 | 0.112 | 0.519 | 0.518 |
| qcbor:1.5.1 | 2.73 | 2.73 | 3.27 | 3.27 |
| tinycbor:0.6.0 | 2.17 | 2.17 | 2.67 | 2.67 |
| ubj:1.0-min | 0.298 | 0.294 | 0.791 | 0.79 |
| yyjson:0.10.0 | 1.28 | 1.27 | 1.84 | 1.84 |
| zcbor:0.9 | 1.49 | 1.46 | 1.85 | 1.84 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro-c:1.11.3 | 2.4M | 20K | 2.4M | 19K | 3.3M | 23K | 1.9M | 14K | 2.6M | 22K |
| cbor-encode:0.11.0 | 0.11M | 1.1K | 0.27M | 2.8K | 0.31M | 4.2K | 0.085M | 0.88K | 0.13M | 1.4K |
| cJSON:1.7.18 | 0.14M | 1.4K | 0.27M | 2.5K | 0.27M | 3.9K | 0.22M | 1.8K | 0.037M | 0.35K |
| custom-binary:v2-1.0 | **8.1M** | **36K** | **8.1M** | **36K** | 4.9M | 45K | **4M** | **22K** | **10M** | **40K** |
| flatcc:0.6.1 | 3.8M | 26K | 3.7M | 26K | 5.3M | 31K | 2.5M | 17K | 4.1M | 28K |
| jansson:2.14 | 0.068M | 0.69K | 0.13M | 1.3K | 0.16M | 2.1K | 0.097M | 0.93K | 0.044M | 0.43K |
| json-c:0.15 | 0.077M | 0.81K | 0.16M | 1.6K | 0.19M | 2.7K | 0.15M | 1.4K | 0.051M | 0.49K |
| libbson:1.27.5 | 0.2M | 2.2K | 0.4M | 3.9K | 0.56M | 8.2K | 0.089M | 0.88K | 0.11M | 1.1K |
| mpack:1.1 | 0.79M | 7.1K | 1.4M | 13K | 1.6M | 20K | 1.1M | 7.5K | 1.5M | 13K |
| msgpack-c:6.0.1 | 0.64M | 6K | 1.2M | 11K | 1.5M | 19K | 1.1M | 8.5K | 1.2M | 11K |
| nanopb:0.4.9 | 1.8M | 15K | 3.2M | 25K | 3.6M | 44K | 2.2M | 15K | 4.8M | 33K |
| parson:1.5.3 | 0.06M | 0.59K | 0.18M | 1.6K | 0.16M | 2K | 0.18M | 1.5K | 0.031M | 0.28K |
| protobuf-c:1.5.0 | 1.8M | 15K | 3.2M | 25K | **9M** | **45K** | 2.2M | 15K | 4.8M | 35K |
| protobuf-wire:wire-v2 | 1.8M | 16K | 3M | 25K | 8.9M | 45K | 2.3M | 15K | 4.9M | 34K |
| qcbor:1.5.1 | 0.13M | 1.4K | 0.33M | 3.6K | 0.37M | 5K | 0.092M | 0.97K | 0.14M | 1.4K |
| tinycbor:0.6.0 | 0.17M | 1.7K | 0.46M | 4.6K | 0.46M | 6.1K | 0.096M | 1K | 0.17M | 1.6K |
| ubj:1.0-min | 5.8M | 31K | 6M | 32K | 3.4M | 35K | 3.2M | 20K | 6.3M | 32K |
| yyjson:0.10.0 | 0.37M | 3.4K | 0.66M | 5.9K | 0.78M | 11K | 0.5M | 3.5K | 0.53M | 4.5K |
| zcbor:0.9 | 0.13M | 1.3K | 0.33M | 3.4K | 0.67M | 5.6K | 0.087M | 0.9K | 0.14M | 1.4K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/c/2026-07-24-155302.csv`
    - run=2026-07-24-155302
    - language=c
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: gcc=gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, python=3.14.0, node=24.15.0
    - git=04d09d1 dirty
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
