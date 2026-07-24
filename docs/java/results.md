# Java — Benchmark Results

**Generated:** 2026-07-24T15:54:09.755419

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
| avro:1.12.0 | 121 | 36.2 | 84.6 | 83K | **9.02K** | 1722 | **1.00** |
| bson:5.3.1 | 195 | 97.7 | 97.1 | 68.5K | 20.5K | 1741 | **1.00** |
| dsl-json:2.0.2 | 136 | 68.7 | 67.1 | 103K | 19.5K | 1728 | **1.00** |
| fastjson2:2.0.57 | 91.8 | 40.2 | 51.4 | 67.8K | 19.5K | 1682 | **1.00** |
| fory:1.3.0 | **44.2** | **21.1** | **22.8** | **110K** | 9.65K | 1569 | **1.00** |
| gson:2.12.1 | 369 | 214 | 154 | 43K | 19.5K | 1712 | **1.00** |
| hessian:4.0.66 | 92 | 37.1 | 54.1 | 89.5K | 9.75K | 1758 | **1.00** |
| ion:2.18.3 | 423 | 104 | 319 | 30.2K | 19K | 1715 | **1.00** |
| jackson:2.18.3 | 243 | 75.7 | 167 | 49.9K | 19.5K | 1756 | **1.00** |
| jackson-cbor:2.18.3 | 102 | 32 | 69.2 | 88.6K | 13.6K | 1706 | **1.00** |
| jackson-smile:2.18.3 | 79.8 | 30.1 | 49.5 | 105K | 11.3K | 1736 | **1.00** |
| java-serialization:21.0.11 | 187 | 76.7 | 110 | 30.8K | 13K | 1730 | **1.00** |
| jsoniter:0.9.23 | 77.4 | 31.6 | 45.8 | 99.3K | 16.7K | 1686 | **1.00** |
| kryo:5.6.2 | 92.7 | 52.1 | 40.4 | 66.6K | 9.25K | 1708 | **1.00** |
| moshi:1.15.2 | 270 | 101 | 168 | 78.5K | 19.5K | 1721 | **1.00** |
| msgpack:0.9.8 | 161 | 68.7 | 91.8 | 75.5K | 13.3K | 1675 | **1.00** |
| protobuf:4.28.3 | 97.9 | 32 | 64.1 | 69.7K | 10.1K | 1682 | **1.00** |
| protostuff:1.8.0 | 64.2 | 31.4 | 32.6 | 99.6K | 10.4K | 1672 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro:1.12.0 | 41.7 | 37.8 | 44.8 | 42.3 |
| bson:5.3.1 | 58.6 | 47.4 | 25.2 | 25.1 |
| dsl-json:2.0.2 | 84.5 | 89 | 47.2 | 53.3 |
| fastjson2:2.0.57 | 30.5 | 30.7 | 24.8 | 24 |
| fory:1.3.0 | 25.5 | 25.3 | 23.7 | 22.6 |
| gson:2.12.1 | 57.6 | 58.5 | 78.3 | 68.1 |
| hessian:4.0.66 | 21.2 | 20.6 | 17 | 13.8 |
| ion:2.18.3 | 157 | 133 | 75 | 70.6 |
| jackson:2.18.3 | 97.4 | 94.5 | 59 | 55.2 |
| jackson-cbor:2.18.3 | 34.9 | 35.3 | 16.2 | 15.3 |
| jackson-smile:2.18.3 | 27.9 | 28.2 | 13 | 12.4 |
| java-serialization:21.0.11 | 74.8 | 68 | 45.8 | 44.9 |
| jsoniter:0.9.23 | 14.4 | 13.1 | **7.45** | **6.98** |
| kryo:5.6.2 | 22.1 | 22.6 | 11.2 | 11 |
| moshi:1.15.2 | 83 | 67.3 | 52.3 | 43.5 |
| msgpack:0.9.8 | 53.4 | 54.5 | 25.6 | 23.9 |
| protobuf:4.28.3 | 7.88 | **7.23** | 10.7 | 10.2 |
| protostuff:1.8.0 | **7.77** | 7.8 | 8.33 | 7.97 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro:1.12.0 | 42K | 2.6K | 200K | 7.2K | 24K | 4.3K | 370K | 3.3K | 130K | 6.7K |
| bson:5.3.1 | 50K | 1.4K | 230K | 3.6K | 17K | 3.2K | 250K | 2.5K | 88K | 3K |
| dsl-json:2.0.2 | 76K | 2.9K | 320K | 6.1K | 12K | 3.9K | **590K** | 5.7K | 25K | 1.8K |
| fastjson2:2.0.57 | 63K | 6K | 150K | 9K | 33K | 5.5K | 260K | 4.8K | 38K | 3.1K |
| fory:1.3.0 | **130K** | **7.4K** | 240K | **19K** | 39K | **17K** | 230K | **6.9K** | **280K** | **32K** |
| gson:2.12.1 | 40K | 1.2K | 170K | 3.2K | 17K | 1.6K | 210K | 2.6K | 28K | 0.78K |
| hessian:4.0.66 | 78K | 2.4K | 320K | 13K | 47K | 4.2K | 260K | 4.1K | 120K | 7K |
| ion:2.18.3 | 30K | 0.96K | 120K | 2.2K | 6.4K | 1.3K | 140K | 2.2K | 18K | 0.62K |
| jackson:2.18.3 | 47K | 1.7K | 190K | 3.9K | 10K | 2.1K | 120K | 4K | 28K | 1.1K |
| jackson-cbor:2.18.3 | 40K | 3.5K | 250K | 7.7K | 29K | 3.7K | 360K | 5.1K | 79K | 7.4K |
| jackson-smile:2.18.3 | 55K | 4.6K | 270K | 9.9K | 36K | 4.9K | 430K | 5.6K | 100K | 8K |
| java-serialization:21.0.11 | 44K | 1.9K | 80K | 3.4K | 13K | 3.1K | 78K | 1.7K | 49K | 4.6K |
| jsoniter:0.9.23 | 120K | 5.9K | 290K | 11K | 70K | 5.9K | 280K | 5.5K | 82K | 4.9K |
| kryo:5.6.2 | 58K | 3.6K | 190K | 8.6K | 45K | 6.4K | 200K | 3.3K | 80K | 8.6K |
| moshi:1.15.2 | 76K | 2.2K | 280K | 5.3K | 12K | 2.8K | 350K | 3.7K | 35K | 0.72K |
| msgpack:0.9.8 | 66K | 2.2K | 250K | 4.6K | 19K | 2K | 320K | 3.5K | 38K | 3.7K |
| protobuf:4.28.3 | 52K | 5.4K | 210K | 7.8K | 130K | 13K | 160K | 3.3K | 99K | 4.9K |
| protostuff:1.8.0 | 64K | 5.3K | **500K** | 14K | **130K** | 8.8K | 140K | 5.5K | 120K | 9.3K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/java/2026-07-24-155350.csv`
    - run=2026-07-24-155350
    - language=java
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: java=openjdk version "1.8.0_492", python=3.14.0, node=24.15.0
    - git=04d09d1 dirty
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
