# C — Benchmark Results

**Generated:** 2026-07-29T20:52:48.226194

This page is a **snapshot of measured numbers** for C on **one machine, one session** (claim level **L1**). Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little. Stronger multi-session / multi-machine claims need more evidence — see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [C overview](index.md) |
| I/O modes and run modes | [Modes](../analysis/modes.md) |
| How CSVs become these tables | [Analysis methodology](../analysis/ANALYSIS_METHODOLOGY.md) |
| What each metric means | [Metrics catalog](../analysis/METRICS.md) |
| What you may claim (L1/L2/L3) | [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md) |
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

> **How these numbers were filtered (Dashboard “Samples”):** First the first timed repetition is dropped as warmup (`RepetitionIndex == 0`). Then outliers are removed with **paired Tukey IQR k=1.5** — the same rule as the Dashboard **Samples** menu item **“IQR k=1.5 (default)”** (`iqr_1.5`). A whole trial is dropped if serialize, deserialize, or total time falls outside the fences. Raw CSVs still store every trial. On the Dashboard you can switch among four **Samples** policies without re-running the benchmark; this Results page is the **default policy only**. Details: [Analysis methodology — outlier filtering](../analysis/ANALYSIS_METHODOLOGY.md#outlier-filtering) · [Dashboard filter policies](../analysis/ANALYSIS_METHODOLOGY.md#dashboard-filter-policies-multi-aggregation-export).

> **Exploratory ranks:** effect sizes vs the fastest codec are **descriptive**. When we attach Holm-adjusted tests, they only correct for many serializers **inside one** (data type × batch size × I/O mode) group — not for every comparison on this page. Prefer pairwise A/B (`analyze-benchmarks --compare-a … --compare-b …`) for confirmatory checks. See [Analysis methodology — ranks](../analysis/ANALYSIS_METHODOLOGY.md#exploratory-ranks).

> **Stream honesty:** all stream rows are **`adapted`** (in-memory encode/decode then dump to a stream, or equivalent). Do **not** treat stream columns as proof of incremental I/O. Labels: **adapted** 190. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) |
|---|---|---|---|---|---|
| avro-c:1.11.3 | 31.9 | 12.6 | 19.3 | 0.497M | 10.9K |
| cbor-encode:0.11.0 | 349 | 101 | 248 | 0.0757M | 15.1K |
| cJSON:1.7.18 | 503 | 340 | 162 | 0.0737M | 19.9K |
| custom-binary:v2-1.0 | **18.9** | **5.89** | **13** | **1.57M** | 10.7K |
| flatcc:0.6.1 | 25.8 | 12.7 | 13 | 0.771M | 12.2K |
| jansson:2.14 | 633 | 291 | 342 | 0.0446M | 20.1K |
| json-c:0.15 | 511 | 244 | 267 | 0.0575M | 20.1K |
| libbson:1.27.5 | 306 | 95.2 | 211 | 0.116M | 21.1K |
| mpack:1.1 | 55.3 | 14.4 | 40.8 | 0.312M | 13.7K |
| msgpack-c:6.0.1 | 56.6 | 20.5 | 36 | 0.306M | 13.7K |
| nanopb:0.4.9 | 27.6 | 11.5 | 16.1 | 0.941M | **10.5K** |
| parson:1.5.3 | 735 | 550 | 184 | 0.0469M | 20.1K |
| protobuf-c:1.5.0 | 27.6 | 11.6 | 16 | 0.926M | **10.5K** |
| protobuf-wire:wire-v2 | 27.7 | 11.5 | 16.1 | 0.93M | **10.5K** |
| qcbor:1.5.1 | 303 | 55.3 | 248 | 0.103M | 13.8K |
| tinycbor:0.6.0 | 268 | 20 | 248 | 0.126M | 13.8K |
| ubj:1.0-min | 21.2 | 7.51 | 13.7 | 1.1M | 12.6K |
| yyjson:0.10.0 | 121 | 56.8 | 63.7 | 0.201M | 19.8K |
| zcbor:0.9 | 320 | 34.5 | 285 | 0.105M | 14K |


### Total Time

| serializer | bytes mode/mean (µs) | bytes mode/median (µs) | stream mode/mean (µs) | stream mode/median (µs) |
|---|---|---|---|---|
| avro-c:1.11.3 | 0.611 | 0.61 | 1.05 | 1.05 |
| cbor-encode:0.11.0 | 2.91 | 2.9 | 3.51 | 3.51 |
| cJSON:1.7.18 | 3.21 | 3.2 | 3.85 | 3.85 |
| custom-binary:v2-1.0 | **0.113** | **0.116** | **0.522** | **0.519** |
| flatcc:0.6.1 | 0.332 | 0.339 | 0.764 | 0.757 |
| jansson:2.14 | 5.37 | 5.35 | 6 | 6 |
| json-c:0.15 | 4.54 | 4.53 | 4.97 | 5 |
| libbson:1.27.5 | 1.61 | 1.61 | 2.04 | 2.04 |
| mpack:1.1 | 0.881 | 0.87 | 1.19 | 1.19 |
| msgpack-c:6.0.1 | 0.848 | 0.872 | 1.18 | 1.18 |
| nanopb:0.4.9 | 0.197 | 0.197 | 0.606 | 0.6 |
| parson:1.5.3 | 5.71 | 5.66 | 6.4 | 6.46 |
| protobuf-c:1.5.0 | 0.2 | 0.2 | 0.615 | 0.604 |
| protobuf-wire:wire-v2 | 0.2 | 0.198 | 0.644 | 0.63 |
| qcbor:1.5.1 | 2.12 | 2.13 | 2.59 | 2.6 |
| tinycbor:0.6.0 | 1.67 | 1.66 | 2.12 | 2.11 |
| ubj:1.0-min | 0.198 | 0.2 | 0.626 | 0.62 |
| yyjson:0.10.0 | 1.19 | 1.19 | 1.69 | 1.71 |
| zcbor:0.9 | 1.92 | 1.91 | 2.37 | 2.36 |


### Ops/Sec

| serializer | Average | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|---|
| avro-c:1.11.3 | 0.61M | 1M | 17K | 1M | 17K | 1.6M | 21K | 1.1M | 11K | 1.2M | 19K |
| cbor-encode:0.11.0 | 0.081M | 0.082M | 1.1K | 0.19M | 2.7K | 0.34M | 4.2K | 0.078M | 0.87K | 0.11M | 1.3K |
| cJSON:1.7.18 | 0.081M | 0.1M | 1.3K | 0.19M | 2.4K | 0.31M | 3.5K | 0.16M | 1.7K | 0.035M | 0.34K |
| custom-binary:v2-1.0 | **2.4M** | **3.8M** | **29K** | **3.1M** | **30K** | **8.9M** | **41K** | **3M** | **16K** | **5.1M** | **35K** |
| flatcc:0.6.1 | 1M | 1.7M | 21K | 1.6M | 22K | 3M | 26K | 1.8M | 13K | 2.1M | 24K |
| jansson:2.14 | 0.047M | 0.054M | 0.66K | 0.1M | 1.3K | 0.19M | 2.1K | 0.083M | 0.91K | 0.039M | 0.41K |
| json-c:0.15 | 0.059M | 0.063M | 0.79K | 0.13M | 1.7K | 0.22M | 2.6K | 0.13M | 1.3K | 0.046M | 0.48K |
| libbson:1.27.5 | 0.13M | 0.15M | 2K | 0.29M | 3.6K | 0.62M | 7.4K | 0.081M | 0.86K | 0.096M | 1K |
| mpack:1.1 | 0.33M | 0.35M | 6.3K | 0.57M | 11K | 1.1M | 19K | 0.61M | 6.5K | 0.55M | 12K |
| msgpack-c:6.0.1 | 0.32M | 0.33M | 5.8K | 0.55M | 10K | 1.2M | 18K | 0.62M | 7.8K | 0.51M | 10K |
| nanopb:0.4.9 | 1.3M | 1.3M | 13K | 1.7M | 20K | 5.1M | 37K | 1.7M | 13K | 3.3M | 28K |
| parson:1.5.3 | 0.051M | 0.046M | 0.57K | 0.12M | 1.6K | 0.18M | 1.9K | 0.14M | 1.4K | 0.028M | 0.27K |
| protobuf-c:1.5.0 | 1.3M | 1.3M | 13K | 1.7M | 20K | 5M | 37K | 1.8M | 13K | 3.1M | 27K |
| protobuf-wire:wire-v2 | 1.3M | 1.3M | 13K | 1.8M | 20K | 5M | 37K | 1.8M | 13K | 3M | 28K |
| qcbor:1.5.1 | 0.11M | 0.12M | 1.3K | 0.29M | 3.5K | 0.47M | 4.9K | 0.092M | 0.98K | 0.12M | 1.4K |
| tinycbor:0.6.0 | 0.14M | 0.15M | 1.6K | 0.37M | 4.5K | 0.6M | 6K | 0.096M | 1K | 0.13M | 1.5K |
| ubj:1.0-min | 1.6M | 2.6M | 27K | 2.3M | 27K | 5.1M | 34K | 2.4M | 15K | 3.4M | 30K |
| yyjson:0.10.0 | 0.22M | 0.21M | 3.1K | 0.44M | 5K | 0.84M | 10K | 0.36M | 3.2K | 0.32M | 3.9K |
| zcbor:0.9 | 0.11M | 0.12M | 1.3K | 0.28M | 3.4K | 0.52M | 5.4K | 0.082M | 0.9K | 0.11M | 1.3K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/c/2026-07-24-201935.csv`
    - run=2026-07-24-201935
    - language=c
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: gcc=gcc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, python=3.14.0, node=24.15.0
    - git=40f6a8e dirty
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
