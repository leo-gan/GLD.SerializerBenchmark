# Java — Benchmark Results

**Generated:** 2026-07-24T19:44:06.361847

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
| avro:1.12.0 | 113 | 38.6 | 74.4 | 41.5K | **9.02K** | 1759 | **1.00** |
| bson:5.3.1 | 209 | 110 | 100 | 36.2K | 20.5K | 1767 | **1.00** |
| dsl-json:2.0.2 | 149 | 79.1 | 70 | 41.9K | 19.5K | 1789 | **1.00** |
| fastjson2:2.0.57 | 110 | 50.6 | 59 | 30.2K | 19.5K | 1766 | **1.00** |
| fory:1.3.0 | **51.7** | **25.9** | **25.1** | 42.4K | 9.65K | 1779 | **1.00** |
| gson:2.12.1 | 357 | 202 | 155 | 27.3K | 19.5K | 1778 | **1.00** |
| hessian:4.0.66 | 86.3 | 39.8 | 46 | 43.6K | 9.75K | 1775 | **1.00** |
| ion:2.18.3 | 444 | 121 | 321 | 14.9K | 19K | 1792 | **1.00** |
| jackson:2.18.3 | 198 | 66.2 | 131 | 32.7K | 19.5K | 1746 | **1.00** |
| jackson-cbor:2.18.3 | 107 | 39.3 | 67 | 40.4K | 13.6K | 1775 | **1.00** |
| jackson-smile:2.18.3 | 93.9 | 37.9 | 55.4 | 42.1K | 11.3K | 1775 | **1.00** |
| java-serialization:21.0.11 | 221 | 88.7 | 131 | 14K | 13K | 1810 | **1.00** |
| jsoniter:0.9.23 | 81.1 | 35.3 | 45.1 | 47.5K | 16.7K | 1789 | **1.00** |
| kryo:5.6.2 | 91.7 | 52.8 | 38.2 | 50.5K | 9.25K | 1776 | **1.00** |
| moshi:1.15.2 | 285 | 108 | 177 | 37K | 19.5K | 1798 | **1.00** |
| msgpack:0.9.8 | 166 | 72.3 | 93.1 | 33.3K | 13.3K | 1784 | **1.00** |
| protobuf:4.28.3 | 76.5 | 28.1 | 47.8 | 36.9K | 10.1K | 1753 | **1.00** |
| protostuff:1.8.0 | 63.7 | 30.5 | 32.6 | **74.8K** | 10.4K | 1762 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| avro:1.12.0 | 73 | 67.6 | 53.1 | 48.5 |
| bson:5.3.1 | 90.6 | 82.5 | 61.5 | 58.5 |
| dsl-json:2.0.2 | 75.8 | 71.4 | 59.2 | 55.7 |
| fastjson2:2.0.57 | 50.8 | 48.5 | 45.3 | 43.6 |
| fory:1.3.0 | 33.8 | 32.3 | 30 | 28.2 |
| gson:2.12.1 | 73.3 | 76 | 71 | 68 |
| hessian:4.0.66 | 43.8 | 40.6 | 34.4 | 31.7 |
| ion:2.18.3 | 245 | 251 | 146 | 141 |
| jackson:2.18.3 | 92.2 | 94.3 | 50.6 | 50.3 |
| jackson-cbor:2.18.3 | 76.7 | 76.8 | 42.8 | 41 |
| jackson-smile:2.18.3 | 71.3 | 75.6 | 45.2 | 41.1 |
| java-serialization:21.0.11 | 121 | 114 | 99.8 | 90.8 |
| jsoniter:0.9.23 | 31.7 | 31.2 | 26.7 | 25.1 |
| kryo:5.6.2 | 41.9 | 40.5 | 29.3 | 28 |
| moshi:1.15.2 | 84.9 | 83.9 | 53.7 | 49.3 |
| msgpack:0.9.8 | 92.7 | 90 | 53.6 | 49.4 |
| protobuf:4.28.3 | **23.7** | **22.9** | 26.5 | 24.3 |
| protostuff:1.8.0 | 24 | 23.2 | **25.3** | **23.3** |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| avro:1.12.0 | 27K | 3K | 120K | 5.8K | 14K | 4.8K | 160K | 3.2K | 55K | 7.1K |
| bson:5.3.1 | 23K | 1.6K | 91K | 2.9K | 11K | 2.3K | 120K | 2.3K | **74K** | 3K |
| dsl-json:2.0.2 | 29K | 3.3K | 110K | 6K | 13K | 3K | **210K** | 4.9K | 32K | 1.7K |
| fastjson2:2.0.57 | 23K | 5K | 54K | 7.9K | 20K | 4K | 110K | 4.7K | 34K | 2.9K |
| fory:1.3.0 | 35K | **8.8K** | 89K | **13K** | 30K | 8.6K | 100K | **6.7K** | 59K | **18K** |
| gson:2.12.1 | 25K | 1.4K | 94K | 2.8K | 14K | 2.1K | 130K | 2.4K | 24K | 0.74K |
| hessian:4.0.66 | 32K | 4.5K | 130K | 8.2K | 23K | 5.4K | 140K | 4K | 49K | 8.2K |
| ion:2.18.3 | 12K | 0.97K | 47K | 2K | 4.1K | 1.3K | 65K | 2K | 17K | 0.65K |
| jackson:2.18.3 | 22K | 2.7K | 83K | 5.6K | 11K | 3.5K | 140K | 4.5K | 26K | 1.1K |
| jackson-cbor:2.18.3 | 24K | 2.9K | 97K | 5.6K | 13K | 4.6K | 150K | 4.7K | 51K | 8.6K |
| jackson-smile:2.18.3 | 28K | 3.6K | 100K | 6.8K | 14K | 5.3K | 170K | 5K | 45K | 8.2K |
| java-serialization:21.0.11 | 14K | 1.8K | 34K | 2.5K | 8.2K | 2.7K | 40K | 1.6K | 21K | 4.7K |
| jsoniter:0.9.23 | 41K | 5.9K | 110K | 8.4K | 32K | 5.8K | 160K | 4.8K | 63K | 5.8K |
| kryo:5.6.2 | **42K** | 4.6K | 160K | 6.5K | 24K | 6.3K | 170K | 3.1K | 43K | 11K |
| moshi:1.15.2 | 35K | 2.1K | 110K | 4.1K | 12K | 2.6K | 160K | 3.2K | 23K | 0.7K |
| msgpack:0.9.8 | 27K | 2K | 88K | 3.7K | 11K | 3K | 130K | 3.1K | 38K | 4.5K |
| protobuf:4.28.3 | 29K | 5.3K | 84K | 6.7K | **42K** | 7.8K | 98K | 4.2K | 43K | 6.2K |
| protostuff:1.8.0 | 41K | 7.1K | **270K** | 9.8K | 42K | **8.6K** | 200K | 5K | 69K | 10K |

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
    
    - **Source CSV:** `logs/java/2026-07-24-193950.csv`
    - run=2026-07-24-193950
    - language=java
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: java=openjdk version "21.0.11" 2026-04-21 LTS, python=3.14.0, node=24.15.0
    - git=7431b57 dirty
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
