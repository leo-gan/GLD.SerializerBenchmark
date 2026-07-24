# Swift — Benchmark Results

**Generated:** 2026-07-24T15:57:19.435741

This page is a **snapshot of measured numbers** for Swift on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [Swift overview](index.md) |
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
| BinaryCodable:4.0.0 | 1,800 | 1,240 | 557 | 19K | 13.4K | 1822 | **1.00** |
| CapnProto:capnproto-1.0.2 | 955 | 751 | 203 | 59.4K | 18.3K | 1797 | **1.00** |
| FlatBuffers:24.3.25 | 679 | 591 | 87.1 | 116K | 17.4K | 1838 | **1.00** |
| Foundation.JSONEncoder:Foundation | 1,740 | 1,170 | 568 | 22K | 19.7K | 1788 | **1.00** |
| Foundation.PropertyListEncoder:Foundation | 2,770 | 1,330 | 1,430 | 11.5K | 16.3K | 1820 | **1.00** |
| IkigaJSON:2.5.3 | 1,760 | 1,110 | 653 | 19.9K | 19.7K | 1813 | **1.00** |
| SwiftAvroCore:2.3.0 | 2,630 | 2,040 | 592 | 11.3K | **9.02K** | 1824 | **1.00** |
| SwiftBSON:3.1.0 | 3,770 | 1,940 | 1,830 | 9.39K | 20.7K | 1828 | **1.00** |
| SwiftCbor:0.0.4 | 2,370 | 1,560 | 811 | 14K | 13.6K | 1830 | **1.00** |
| SwiftMsgpack:1.2.1 | 2,240 | 1,440 | 801 | 15.2K | 13.6K | 1810 | **1.00** |
| SwiftProtobuf:1.38.1 | **411** | **366** | **45.2** | **230K** | 10.1K | 1863 | **1.00** |
| TOML:2.0.0 | 5,240 | 4,080 | 1,160 | 6.77K | 22.4K | 1800 | **1.00** |
| XMLCoder:0.18.2 | 14,900 | 7,990 | 6,880 | 2.11K | 34K | 1732 | **1.00** |
| Yams:5.4.0 | 13,400 | 9,530 | 3,920 | 2.27K | 22.5K | 1814 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| BinaryCodable:4.0.0 | 11.3 | 11.1 | 20.9 | 20.6 |
| CapnProto:capnproto-1.0.2 | 2.37 | 2.37 | 11 | 11.1 |
| FlatBuffers:24.3.25 | 1.05 | 1.04 | 12.5 | 12.6 |
| Foundation.JSONEncoder:Foundation | 7 | 6.82 | 19.5 | 19.5 |
| Foundation.PropertyListEncoder:Foundation | 15.5 | 15.4 | 28.3 | 28.3 |
| IkigaJSON:2.5.3 | 9.12 | 9.12 | 21.4 | 20.8 |
| SwiftAvroCore:2.3.0 | 29.4 | 29.4 | 35.2 | 35.3 |
| SwiftBSON:3.1.0 | 17 | 16.8 | 30.6 | 30.6 |
| SwiftCbor:0.0.4 | 11.9 | 11.9 | 23.7 | 23.8 |
| SwiftMsgpack:1.2.1 | 10.2 | 10.2 | 22.7 | 21.4 |
| SwiftProtobuf:1.38.1 | **0.629** | **0.644** | **5.47** | **5.46** |
| TOML:2.0.0 | 38.5 | 38 | 52.6 | 52 |
| XMLCoder:0.18.2 | 109 | 109 | 131 | 131 |
| Yams:5.4.0 | 100 | 101 | 120 | 120 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| BinaryCodable:4.0.0 | 17K | 0.18K | 37K | 0.37K | 0.088M | 0.77K | 40K | 0.42K | 0.066M | 0.64K |
| CapnProto:capnproto-1.0.2 | 110K | 1.2K | 130K | 1.4K | 0.42M | 10K | 63K | 0.65K | 0.23M | 2.8K |
| FlatBuffers:24.3.25 | 310K | **4.2K** | 230K | 5K | 0.95M | 21K | 170K | 2K | 0.4M | 8.8K |
| Foundation.JSONEncoder:Foundation | 30K | 0.31K | 66K | 0.71K | 0.14M | 1.5K | 41K | 0.43K | 0.03M | 0.3K |
| Foundation.PropertyListEncoder:Foundation | 15K | 0.16K | 30K | 0.32K | 0.065M | 0.77K | 17K | 0.18K | 0.016M | 0.17K |
| IkigaJSON:2.5.3 | 28K | 0.29K | 61K | 0.66K | 0.11M | 1.3K | 43K | 0.45K | 0.03M | 0.31K |
| SwiftAvroCore:2.3.0 | 9.2K | 0.096K | 18K | 0.2K | 0.034M | 0.38K | 42K | 0.44K | 0.03M | 0.34K |
| SwiftBSON:3.1.0 | 12K | 0.13K | 22K | 0.24K | 0.059M | 0.54K | 13K | 0.13K | 0.01M | 0.11K |
| SwiftCbor:0.0.4 | 14K | 0.16K | 33K | 0.34K | 0.084M | 0.77K | 22K | 0.22K | 0.023M | 0.23K |
| SwiftMsgpack:1.2.1 | 16K | 0.18K | 36K | 0.38K | 0.098M | 0.89K | 24K | 0.24K | 0.021M | 0.22K |
| SwiftProtobuf:1.38.1 | **320K** | 3.1K | **480K** | **5.1K** | **1.6M** | **27K** | **540K** | **5.6K** | **1.2M** | **19K** |
| TOML:2.0.0 | 6.2K | 0.052K | 14K | 0.11K | 0.026M | 0.25K | 21K | 0.19K | 0.013M | 0.13K |
| XMLCoder:0.18.2 | 2.7K | 0.031K | 5.8K | 0.065K | 0.0092M | 0.11K | 2.8K | 0.03K | 0.0021M | 0.022K |
| Yams:5.4.0 | 2.7K | 0.03K | 5.3K | 0.06K | 0.01M | 0.11K | 3.7K | 0.039K | 0.0023M | 0.025K |

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one **data type** (and batch size):

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that data type so the picture stays readable. Tables above still list everyone.
- Each image also prints the data type, source CSV, modes, and sample size.

### Document · 1 instance

![Document · 1 instance](../analysis/plots/violin/swift_document@n=1.png){ width="80%" }

### Document · 100 instances

![Document · 100 instances](../analysis/plots/violin/swift_document@n=100.png){ width="80%" }

### Event · 1 instance

![Event · 1 instance](../analysis/plots/violin/swift_event@n=1.png){ width="80%" }

### Event · 100 instances

![Event · 100 instances](../analysis/plots/violin/swift_event@n=100.png){ width="80%" }

### Message · 1 instance

![Message · 1 instance](../analysis/plots/violin/swift_message@n=1.png){ width="80%" }

### Message · 100 instances

![Message · 100 instances](../analysis/plots/violin/swift_message@n=100.png){ width="80%" }

### Strings · 1 instance

![Strings · 1 instance](../analysis/plots/violin/swift_strings@n=1.png){ width="80%" }

### Strings · 100 instances

![Strings · 100 instances](../analysis/plots/violin/swift_strings@n=100.png){ width="80%" }

### Telemetry · 1 instance

![Telemetry · 1 instance](../analysis/plots/violin/swift_telemetry@n=1.png){ width="80%" }

### Telemetry · 100 instances

![Telemetry · 100 instances](../analysis/plots/violin/swift_telemetry@n=100.png){ width="80%" }

## How to regenerate this page

Snapshots are produced on a developer machine. After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l swift   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/swift/2026-07-24-155452.csv`
    - run=2026-07-24-155452
    - language=swift
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: python=3.14.0, node=24.15.0, dotnet=9.0.316
    - git=04d09d1 dirty
    - seed=42
    - warmup_reps=1
    - serializers=14
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `BinaryCodable` @ 4.0.0
      - `CapnProto` @ capnproto-1.0.2
      - `FlatBuffers` @ 24.3.25
      - `Foundation.JSONEncoder` @ Foundation
      - `Foundation.PropertyListEncoder` @ Foundation
      - `IkigaJSON` @ 2.5.3
      - `SwiftAvroCore` @ 2.3.0
      - `SwiftBSON` @ 3.1.0
      - `SwiftCbor` @ 0.0.4
      - `SwiftMsgpack` @ 1.2.1
      - `SwiftProtobuf` @ 1.38.1
      - `TOML` @ 2.0.0
      - `XMLCoder` @ 0.18.2
      - `Yams` @ 5.4.0
