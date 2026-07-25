# Java — Benchmark Results

**Generated:** 2026-07-24T18:57:57.724061

This page is a **snapshot of measured numbers** for Java on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [Java overview](index.md) |
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
| avro:1.12.0 | 107 | 36.1 | 70 | 43.1K | **9.02K** | 1742 | **1.00** |
| bson:5.3.1 | 200 | 103 | 95.5 | 38.5K | 20.5K | 1776 | **1.00** |
| dsl-json:2.0.2 | 143 | 76.5 | 66.2 | 43.7K | 19.5K | 1742 | **1.00** |
| fastjson2:2.0.57 | 106 | 49 | 56.6 | 30.3K | 19.5K | 1761 | **1.00** |
| fory:1.3.0 | **48.2** | **24.4** | **23.7** | 44.8K | 9.65K | 1760 | **1.00** |
| gson:2.12.1 | 348 | 197 | 150 | 29K | 19.5K | 1770 | **1.00** |
| hessian:4.0.66 | 83 | 38.5 | 44.2 | 44.5K | 9.75K | 1764 | **1.00** |
| ion:2.18.3 | 418 | 115 | 302 | 15.6K | 19K | 1764 | **1.00** |
| jackson:2.18.3 | 190 | 64 | 125 | 33.1K | 19.5K | 1758 | **1.00** |
| jackson-cbor:2.18.3 | 101 | 36.8 | 63.8 | 40.6K | 13.6K | 1767 | **1.00** |
| jackson-smile:2.18.3 | 86.7 | 35 | 51.6 | 43.1K | 11.3K | 1757 | **1.00** |
| java-serialization:21.0.11 | 210 | 84.6 | 125 | 14.7K | 13K | 1775 | **1.00** |
| jsoniter:0.9.23 | 76.2 | 33.7 | 42 | 50.5K | 16.7K | 1750 | **1.00** |
| kryo:5.6.2 | 88.6 | 51.5 | 37.1 | 51.3K | 9.25K | 1776 | **1.00** |
| moshi:1.15.2 | 277 | 106 | 170 | 38.1K | 19.5K | 1773 | **1.00** |
| msgpack:0.9.8 | 156 | 67.9 | 87.3 | 34.3K | 13.3K | 1768 | **1.00** |
| protobuf:4.28.3 | 72.7 | 26.4 | 45.6 | 38.6K | 10.1K | 1676 | **1.00** |
| protostuff:1.8.0 | 60.4 | 29 | 31.3 | **77.4K** | 10.4K | 1730 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro:1.12.0 | 67.8 | 64.2 | 47.6 | 45.6 |
| bson:5.3.1 | 87.8 | 77.1 | 55.1 | 54.3 |
| dsl-json:2.0.2 | 72.4 | 68.9 | 57.6 | 57 |
| fastjson2:2.0.57 | 50.8 | 49.6 | 39.4 | 38.7 |
| fory:1.3.0 | 33.6 | 32.3 | 24.8 | 23.7 |
| gson:2.12.1 | 68.5 | 65.2 | 63.4 | 62.1 |
| hessian:4.0.66 | 41.2 | 39.5 | 31.2 | 30.5 |
| ion:2.18.3 | 226 | 195 | 125 | 121 |
| jackson:2.18.3 | 89.6 | 88.4 | 47.4 | 46.9 |
| jackson-cbor:2.18.3 | 69.7 | 67.1 | 39.5 | 39.4 |
| jackson-smile:2.18.3 | 68 | 65.6 | 38.8 | 38.3 |
| java-serialization:21.0.11 | 116 | 110 | 81.3 | 80.3 |
| jsoniter:0.9.23 | 30.3 | 28.9 | 21.8 | 21.5 |
| kryo:5.6.2 | 41.2 | 39.5 | 27.3 | 27.1 |
| moshi:1.15.2 | 74.9 | 69.8 | 44.8 | 42.3 |
| msgpack:0.9.8 | 78.8 | 71.1 | 44.3 | 42.4 |
| protobuf:4.28.3 | 24.3 | 23.7 | 23.3 | 22.6 |
| protostuff:1.8.0 | **23.4** | **23** | **21.4** | **20.3** |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro:1.12.0 | 26K | 3.8K | 120K | 6.1K | 15K | 6.3K | 160K | 3.3K | 56K | 7.1K |
| bson:5.3.1 | 21K | 1.8K | 110K | 3.2K | 11K | 3K | 130K | 2.4K | **72K** | 3K |
| dsl-json:2.0.2 | 24K | 4.1K | 110K | 6.6K | 14K | 4.3K | 210K | 5K | 35K | 1.7K |
| fastjson2:2.0.57 | 24K | 6.1K | 61K | 8.1K | 20K | 5.2K | 92K | 4.6K | 35K | 3K |
| fory:1.3.0 | 32K | **11K** | 93K | **15K** | 30K | 11K | 100K | **6.8K** | 61K | **19K** |
| gson:2.12.1 | 25K | 1.5K | 99K | 2.9K | 15K | 3K | 130K | 2.4K | 26K | 0.75K |
| hessian:4.0.66 | 26K | 5.1K | 140K | 8.7K | 24K | 7.2K | 130K | 4K | 55K | 7.9K |
| ion:2.18.3 | 11K | 1K | 50K | 2.1K | 4.4K | 2K | 65K | 2.1K | 18K | 0.67K |
| jackson:2.18.3 | 18K | 3.5K | 84K | 6K | 11K | 5.2K | 130K | 4.6K | 27K | 1.1K |
| jackson-cbor:2.18.3 | 20K | 3.4K | 93K | 5.9K | 14K | 7.3K | 140K | 4.7K | 52K | 8.2K |
| jackson-smile:2.18.3 | 24K | 4.5K | 100K | 7.4K | 15K | 8.2K | 160K | 5.1K | 46K | 8.5K |
| java-serialization:21.0.11 | 11K | 2K | 37K | 2.7K | 8.6K | 3.7K | 38K | 1.6K | 23K | 4.6K |
| jsoniter:0.9.23 | 43K | 7K | 110K | 8.9K | 33K | 8.1K | 160K | 4.9K | 64K | 5.6K |
| kryo:5.6.2 | 39K | 5.1K | 160K | 6.7K | 24K | 9K | 160K | 3.1K | 43K | 9.8K |
| moshi:1.15.2 | 29K | 2.3K | 110K | 4.2K | 13K | 3.8K | 160K | 3.2K | 26K | 0.72K |
| msgpack:0.9.8 | 22K | 2.1K | 92K | 3.9K | 13K | 4.5K | 130K | 3.2K | 40K | 4.4K |
| protobuf:4.28.3 | 26K | 6.4K | 85K | 7.4K | 41K | 11K | 98K | 4.2K | 42K | 5.6K |
| protostuff:1.8.0 | **52K** | 7.8K | **230K** | 10K | **43K** | **12K** | **220K** | 5.1K | 70K | 9.9K |

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one **data type** (and batch size):

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that data type so the picture stays readable. Tables above still list everyone.
- Each image also prints the data type, source CSV, modes, and sample size.

### Document · 1 instance

![Document · 1 instance](../analysis/plots/violin/java_document@n=1.png){ width="80%" }

### Document · 100 instances

![Document · 100 instances](../analysis/plots/violin/java_document@n=100.png){ width="80%" }

### Event · 1 instance

![Event · 1 instance](../analysis/plots/violin/java_event@n=1.png){ width="80%" }

### Event · 100 instances

![Event · 100 instances](../analysis/plots/violin/java_event@n=100.png){ width="80%" }

### Message · 1 instance

![Message · 1 instance](../analysis/plots/violin/java_message@n=1.png){ width="80%" }

### Message · 100 instances

![Message · 100 instances](../analysis/plots/violin/java_message@n=100.png){ width="80%" }

### Strings · 1 instance

![Strings · 1 instance](../analysis/plots/violin/java_strings@n=1.png){ width="80%" }

### Strings · 100 instances

![Strings · 100 instances](../analysis/plots/violin/java_strings@n=100.png){ width="80%" }

### Telemetry · 1 instance

![Telemetry · 1 instance](../analysis/plots/violin/java_telemetry@n=1.png){ width="80%" }

### Telemetry · 100 instances

![Telemetry · 100 instances](../analysis/plots/violin/java_telemetry@n=100.png){ width="80%" }

## How to regenerate this page

Snapshots are produced on a developer machine. After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l java   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/java/2026-07-24-183742.csv`
    - run=2026-07-24-183742
    - language=java
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: java=openjdk version "1.8.0_492", python=3.14.0, node=24.15.0
    - git=85145fd dirty
    - seed=42
    - warmup_reps=1
    - serializers=18
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `avro` @ 1.12.0
      - `bson` @ 5.3.1
      - `dsl-json` @ 2.0.2
      - `fastjson2` @ 2.0.57
      - `fory` @ 1.3.0
      - `gson` @ 2.12.1
      - `hessian` @ 4.0.66
      - `ion` @ 2.18.3
      - `jackson` @ 2.18.3
      - `jackson-cbor` @ 2.18.3
      - `jackson-smile` @ 2.18.3
      - `java-serialization` @ 21.0.11
      - `jsoniter` @ 0.9.23
      - `kryo` @ 5.6.2
      - `moshi` @ 1.15.2
      - `msgpack` @ 0.9.8
      - `protobuf` @ 4.28.3
      - `protostuff` @ 1.8.0
