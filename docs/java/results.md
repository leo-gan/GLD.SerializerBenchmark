# Java — Benchmark Results

**Generated:** 2026-07-24T20:24:13.575637

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

> **Stream honesty:** stream rows labeled as **native** 140, **adapted** 40. Only **`native`** (and carefully **`text_on_stream`**) support stream-API performance claims. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| avro:1.12.0 | 111 | 36.6 | 73.5 | 41.3K | **9.02K** | 1731 | **1.00** |
| bson:5.3.1 | 205 | 106 | 98.4 | 36.7K | 20.5K | 1773 | **1.00** |
| dsl-json:2.0.2 | 147 | 77.2 | 69.5 | 41.7K | 19.5K | 1754 | **1.00** |
| fastjson2:2.0.57 | 112 | 50.8 | 60.2 | 28.4K | 19.5K | 1782 | **1.00** |
| fory:1.3.0 | **49.9** | **25.2** | **24.3** | 43.3K | 9.65K | 1745 | **1.00** |
| gson:2.12.1 | 358 | 205 | 151 | 26.8K | 19.5K | 1779 | **1.00** |
| hessian:4.0.66 | 85.3 | 38.8 | 46.1 | 43.6K | 9.75K | 1770 | **1.00** |
| ion:2.18.3 | 440 | 121 | 318 | 14.5K | 19K | 1781 | **1.00** |
| jackson:2.18.3 | 194 | 65.9 | 128 | 31.9K | 19.5K | 1785 | **1.00** |
| jackson-cbor:2.18.3 | 103 | 38 | 64.7 | 39.3K | 13.6K | 1782 | **1.00** |
| jackson-smile:2.18.3 | 89.3 | 36.2 | 52.9 | 41.4K | 11.3K | 1771 | **1.00** |
| java-serialization:21.0.11 | 217 | 88.6 | 128 | 13.8K | 13K | 1835 | **1.00** |
| jsoniter:0.9.23 | 79.6 | 34.5 | 44.5 | 47.1K | 16.7K | 1771 | **1.00** |
| kryo:5.6.2 | 90.7 | 52.7 | 37.6 | 46K | 9.25K | 1745 | **1.00** |
| moshi:1.15.2 | 282 | 107 | 175 | 37.4K | 19.5K | 1764 | **1.00** |
| msgpack:0.9.8 | 160 | 70.5 | 89.3 | 33.1K | 13.3K | 1770 | **1.00** |
| protobuf:4.28.3 | 74 | 27.1 | 46.2 | 38.2K | 10.1K | 1702 | **1.00** |
| protostuff:1.8.0 | 63.1 | 30.5 | 32.3 | **62.3K** | 10.4K | 1723 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro:1.12.0 | 67.8 | 62.3 | 50 | 48.9 |
| bson:5.3.1 | 91.8 | 77.3 | 59 | 57.3 |
| dsl-json:2.0.2 | 71.2 | 65.7 | 53.6 | 52.8 |
| fastjson2:2.0.57 | 49.5 | 47.7 | 42 | 40.4 |
| fory:1.3.0 | 31.4 | 29.9 | 27.7 | 26.6 |
| gson:2.12.1 | 69.2 | 60.3 | 67.1 | 65.8 |
| hessian:4.0.66 | 42.5 | 39 | 32.5 | 32 |
| ion:2.18.3 | 238 | 191 | 129 | 126 |
| jackson:2.18.3 | 91.1 | 88.8 | 49.8 | 48.9 |
| jackson-cbor:2.18.3 | 72.6 | 64.6 | 41.8 | 40.9 |
| jackson-smile:2.18.3 | 68.8 | 65.7 | 40.2 | 40.5 |
| java-serialization:21.0.11 | 116 | 108 | 86 | 84.6 |
| jsoniter:0.9.23 | 29.9 | 28 | 23.6 | 23.3 |
| kryo:5.6.2 | 41.1 | 39.4 | 28.6 | 28.7 |
| moshi:1.15.2 | 75.9 | 64.7 | 49.6 | 45.8 |
| msgpack:0.9.8 | 85.2 | 72.3 | 47.2 | 46.2 |
| protobuf:4.28.3 | **22.5** | **21.6** | 24.5 | 23 |
| protostuff:1.8.0 | 22.9 | 21.9 | **22.6** | **22** |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro:1.12.0 | 32K | 3.4K | 120K | 6K | 15K | 5.6K | 150K | 3.2K | 55K | 6K |
| bson:5.3.1 | 27K | 1.7K | 100K | 3.2K | 11K | 2.5K | 110K | 2.4K | **81K** | 3K |
| dsl-json:2.0.2 | 34K | 3.3K | 110K | 6.3K | 14K | 3.7K | **200K** | 5K | 30K | 1.7K |
| fastjson2:2.0.57 | 28K | 4.7K | 56K | 8.3K | 20K | 4.6K | 90K | 4.7K | 33K | 2.7K |
| fory:1.3.0 | 46K | **8.8K** | 92K | **14K** | 32K | **11K** | 98K | **6.8K** | 60K | **19K** |
| gson:2.12.1 | 28K | 1.4K | 93K | 2.8K | 14K | 2.6K | 120K | 2.4K | 25K | 0.72K |
| hessian:4.0.66 | 37K | 4.9K | 140K | 8.7K | 24K | 5.7K | 130K | 4K | 53K | 7.5K |
| ion:2.18.3 | 14K | 0.94K | 48K | 2.1K | 4.2K | 1.6K | 59K | 2K | 17K | 0.64K |
| jackson:2.18.3 | 26K | 3K | 84K | 6K | 11K | 4.4K | 120K | 4.6K | 27K | 1.1K |
| jackson-cbor:2.18.3 | 29K | 2.9K | 99K | 5.9K | 14K | 6.6K | 140K | 4.6K | 50K | 7.5K |
| jackson-smile:2.18.3 | 31K | 3.8K | 97K | 7.3K | 15K | 7.6K | 160K | 5.1K | 49K | 7K |
| java-serialization:21.0.11 | 16K | 1.8K | 34K | 2.6K | 8.7K | 3.3K | 34K | 1.6K | 22K | 4.1K |
| jsoniter:0.9.23 | 49K | 6.2K | 110K | 8.9K | 33K | 7.3K | 150K | 4.9K | 63K | 5.2K |
| kryo:5.6.2 | 47K | 4.9K | 160K | 6.8K | 24K | 7.1K | 62K | 3.2K | 46K | 9.5K |
| moshi:1.15.2 | 41K | 2.1K | 110K | 4.2K | 13K | 3.3K | 160K | 3.3K | 23K | 0.68K |
| msgpack:0.9.8 | 30K | 1.9K | 90K | 3.9K | 12K | 4.1K | 120K | 3.2K | 40K | 4.2K |
| protobuf:4.28.3 | 36K | 5.4K | 86K | 7.2K | **44K** | 9.6K | 90K | 4.2K | 48K | 9.5K |
| protostuff:1.8.0 | **59K** | 7.6K | **170K** | 10K | 44K | 9.8K | 120K | 5.1K | 73K | 9.1K |

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
    
    - **Source CSV:** `logs/java/2026-07-24-202031.csv`
    - run=2026-07-24-202031
    - language=java
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: java=openjdk version "21.0.11" 2026-04-21 LTS, python=3.14.0, node=24.15.0
    - git=40f6a8e dirty
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
