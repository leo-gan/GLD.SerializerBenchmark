# Python — Benchmark Results

**Generated:** 2026-07-29T20:52:48.213247

This page is a **snapshot of measured numbers** for Python on **one machine, one session** (claim level **L1**). Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little. Stronger multi-session / multi-machine claims need more evidence — see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [Python overview](index.md) |
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

> **Stream honesty:** stream rows labeled as **native** 60, **adapted** 100. Only **`native`** (and carefully **`text_on_stream`**) support stream-API performance claims. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) |
|---|---|---|---|---|---|
| avro:1.12.2 | 453 | 254 | 198 | 26.9K | **9.03K** |
| cbor2:6.1.3 | 300 | 201 | 99.1 | 35.7K | 13.6K |
| cloudpickle:3.1.2 | 302 | 226 | 75.8 | 24.5K | 13.6K |
| dill:0.4.1 | 2,110 | 2,020 | 85.7 | 5.86K | 13.6K |
| flatbuffers:25.12.19 | 2,240 | 1,770 | 474 | 8.71K | 18.7K |
| json:python-3.14.0 | 317 | 185 | 130 | 30.3K | 19.7K |
| mashumaro:3.22 | 150 | 44.2 | 104 | 81.7K | 19.7K |
| msgpack:1.2.1 | 106 | 52.7 | 52.1 | 89.6K | 13.6K |
| msgspec:0.21.1 | 68 | 29.3 | 38.2 | 131K | 14.7K |
| msgspec-msgpack:0.21.1 | 45.1 | **16.5** | 28.2 | 166K | 9.69K |
| orjson:3.11.9 | 76.5 | 28.3 | 46.6 | **176K** | 19.7K |
| pickle:python-3.14.0 | 190 | 113 | 76.3 | 46.7K | 13.6K |
| protobuf:7.35.1 | **37.3** | 16.8 | **20.1** | 120K | 10.1K |
| pydantic:2.13.4 | 504 | 262 | 242 | 27.2K | 21.4K |
| rapidjson:1.23 | 288 | 153 | 134 | 48.8K | 19.7K |
| serpyco-rs:1.21.0 | 121 | 44.8 | 74.5 | 95.1K | 19.7K |


### Total Time

| serializer | bytes mode/mean (µs) | bytes mode/median (µs) | stream mode/mean (µs) | stream mode/median (µs) |
|---|---|---|---|---|
| avro:1.12.2 | 13.5 | 13.7 | 14.2 | 14.3 |
| cbor2:6.1.3 | 9.35 | 9.47 | 10.8 | 10.8 |
| cloudpickle:3.1.2 | 17.1 | 16.9 | 16.1 | 16 |
| dill:0.4.1 | 60.5 | 60.5 | 61.4 | 61.2 |
| flatbuffers:25.12.19 | 35.6 | 35.4 | 37.1 | 36.8 |
| json:python-3.14.0 | 12.6 | 12.7 | 13.4 | 13.3 |
| mashumaro:3.22 | 4.51 | 4.47 | 5.14 | 5.07 |
| msgpack:1.2.1 | 4.49 | 4.53 | 5.46 | 5.46 |
| msgspec:0.21.1 | 2.33 | 2.34 | 3.42 | 3.45 |
| msgspec-msgpack:0.21.1 | **1.8** | **1.81** | 3.01 | 3.02 |
| orjson:3.11.9 | 1.9 | 1.92 | **2.34** | **2.27** |
| pickle:python-3.14.0 | 7.83 | 7.73 | 8.74 | 8.68 |
| protobuf:7.35.1 | 3.51 | 3.52 | 3.94 | 3.98 |
| pydantic:2.13.4 | 15.1 | 15.1 | 15.6 | 15.6 |
| rapidjson:1.23 | 7.86 | 7.86 | 8.36 | 8.4 |
| serpyco-rs:1.21.0 | 4.23 | 4.15 | 4.68 | 4.69 |


### Ops/Sec

| serializer | Average | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|---|
| avro:1.12.2 | 27K | 38K | 0.73K | 52K | 1.2K | 74K | 2.8K | 50K | 0.93K | 53K | 1.2K |
| cbor2:6.1.3 | 37K | 42K | 0.89K | 67K | 1.9K | 110K | 4.2K | 80K | 2.1K | 68K | 1.9K |
| cloudpickle:3.1.2 | 24K | 26K | 0.76K | 37K | 1.4K | 59K | 4.8K | 54K | 2.4K | 55K | 3.4K |
| dill:0.4.1 | 5.9K | 5.9K | 0.12K | 9.2K | 0.22K | 17K | 0.71K | 13K | 0.3K | 13K | 0.34K |
| flatbuffers:25.12.19 | 8.8K | 8.9K | 0.13K | 16K | 0.25K | 28K | 0.53K | 13K | 0.17K | 20K | 0.35K |
| json:python-3.14.0 | 31K | 48K | 1.7K | 65K | 3K | 80K | 4.6K | 71K | 2.9K | 34K | 0.64K |
| mashumaro:3.22 | 86K | 87K | 1.8K | 150K | 3.9K | 220K | 8.6K | 220K | 4.2K | 160K | 3.5K |
| msgpack:1.2.1 | 97K | 110K | 2.6K | 170K | 5.2K | 220K | 9.4K | 240K | 5.6K | 200K | 5.9K |
| msgspec:0.21.1 | 150K | 250K | 7.7K | 300K | 9.8K | 430K | 25K | 270K | 6.1K | 180K | 4.4K |
| msgspec-msgpack:0.21.1 | **190K** | **270K** | 8.4K | **360K** | 12K | **560K** | **38K** | 330K | 7.3K | **350K** | 12K |
| orjson:3.11.9 | 190K | 240K | 5.3K | 360K | 7.4K | 530K | 19K | **440K** | 5.7K | 320K | 5.3K |
| pickle:python-3.14.0 | 49K | 51K | 1.3K | 74K | 2.4K | 130K | 7.7K | 110K | 3K | 110K | 4.8K |
| protobuf:7.35.1 | 130K | 190K | **11K** | 230K | **14K** | 280K | 35K | 230K | **7.8K** | 230K | **23K** |
| pydantic:2.13.4 | 28K | 38K | 0.72K | 52K | 1.3K | 66K | 2.4K | 70K | 1.8K | 44K | 0.55K |
| rapidjson:1.23 | 50K | 75K | 2.1K | 110K | 4.2K | 130K | 5.3K | 130K | 3.7K | 41K | 0.61K |
| serpyco-rs:1.21.0 | 100K | 130K | 2.4K | 190K | 4.9K | 240K | 11K | 250K | 4.7K | 180K | 3.9K |

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one **data type** (and batch size):

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that data type so the picture stays readable. Tables above still list everyone.
- Each image also prints the data type, source CSV, modes, and sample size.

### Document · 1 instance

![Document · 1 instance](../analysis/plots/violin/python_document@n=1.png){ width="80%" }

### Document · 100 instances

![Document · 100 instances](../analysis/plots/violin/python_document@n=100.png){ width="80%" }

### Event · 1 instance

![Event · 1 instance](../analysis/plots/violin/python_event@n=1.png){ width="80%" }

### Event · 100 instances

![Event · 100 instances](../analysis/plots/violin/python_event@n=100.png){ width="80%" }

### Message · 1 instance

![Message · 1 instance](../analysis/plots/violin/python_message@n=1.png){ width="80%" }

### Message · 100 instances

![Message · 100 instances](../analysis/plots/violin/python_message@n=100.png){ width="80%" }

### Strings · 1 instance

![Strings · 1 instance](../analysis/plots/violin/python_strings@n=1.png){ width="80%" }

### Strings · 100 instances

![Strings · 100 instances](../analysis/plots/violin/python_strings@n=100.png){ width="80%" }

### Telemetry · 1 instance

![Telemetry · 1 instance](../analysis/plots/violin/python_telemetry@n=1.png){ width="80%" }

### Telemetry · 100 instances

![Telemetry · 100 instances](../analysis/plots/violin/python_telemetry@n=100.png){ width="80%" }

## How to regenerate this page

Snapshots are produced on a developer machine. After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l python   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/python/2026-07-24-201715.csv`
    - run=2026-07-24-201715
    - language=python
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: python=3.14.0, node=24.15.0, dotnet=9.0.316
    - git=40f6a8e dirty
    - seed=42
    - warmup_reps=1
    - serializers=16
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `avro` @ 1.12.2
      - `cbor2` @ 6.1.3
      - `cloudpickle` @ 3.1.2
      - `dill` @ 0.4.1
      - `flatbuffers` @ 25.12.19
      - `json` @ python-3.14.0
      - `mashumaro` @ 3.22
      - `msgpack` @ 1.2.1
      - `msgspec` @ 0.21.1
      - `msgspec-msgpack` @ 0.21.1
      - `orjson` @ 3.11.9
      - `pickle` @ python-3.14.0
      - `protobuf` @ 7.35.1
      - `pydantic` @ 2.13.4
      - `rapidjson` @ 1.23
      - `serpyco-rs` @ 1.21.0
