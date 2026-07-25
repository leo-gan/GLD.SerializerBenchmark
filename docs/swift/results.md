# Swift — Benchmark Results

**Generated:** 2026-07-24T18:57:57.742477

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
| BinaryCodable:4.0.0 | 1,910 | 1,330 | 580 | 10.8K | 13.4K | 1809 | **1.00** |
| CapnProto:capnproto-1.0.2 | 1,060 | 833 | 229 | 17.6K | 18.3K | 1745 | **1.00** |
| FlatBuffers:24.3.25 | 724 | 629 | 95.9 | 45K | 17.4K | 1745 | **1.00** |
| Foundation.JSONEncoder:Foundation | 1,820 | 1,220 | 601 | 11.6K | 19.7K | 1770 | **1.00** |
| Foundation.PropertyListEncoder:Foundation | 2,880 | 1,410 | 1,480 | 7.24K | 16.3K | 1768 | **1.00** |
| IkigaJSON:2.5.3 | 1,830 | 1,150 | 675 | 12K | 19.7K | 1761 | **1.00** |
| SwiftAvroCore:2.3.0 | 2,720 | 2,120 | 600 | 6.99K | **9.02K** | 1834 | **1.00** |
| SwiftBSON:3.1.0 | 3,920 | 2,040 | 1,890 | 6.17K | 20.7K | 1794 | **1.00** |
| SwiftCbor:0.0.4 | 2,520 | 1,650 | 871 | 8.65K | 13.6K | 1803 | **1.00** |
| SwiftMsgpack:1.2.1 | 2,390 | 1,530 | 859 | 9.06K | 13.6K | 1795 | **1.00** |
| SwiftProtobuf:1.38.1 | **448** | **394** | **53.1** | **63.2K** | 10.1K | 1724 | **1.00** |
| TOML:2.0.0 | 5,470 | 4,220 | 1,250 | 4.7K | 22.4K | 1800 | **1.00** |
| XMLCoder:0.18.2 | 15,500 | 8,350 | 7,190 | 1.74K | 34K | 1820 | **1.00** |
| Yams:5.4.0 | 13,900 | 9,820 | 4,070 | 1.85K | 22.5K | 1803 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| BinaryCodable:4.0.0 | 25.6 | 25.8 | 37.2 | 37.3 |
| CapnProto:capnproto-1.0.2 | 14.2 | 14.4 | 23.9 | 24.1 |
| FlatBuffers:24.3.25 | 3.93 | 3.93 | 15.2 | 15.2 |
| Foundation.JSONEncoder:Foundation | 19.6 | 19.7 | 34.6 | 34.7 |
| Foundation.PropertyListEncoder:Foundation | 31.6 | 31.6 | 48.9 | 49.2 |
| IkigaJSON:2.5.3 | 19.2 | 19.4 | 33.7 | 33.7 |
| SwiftAvroCore:2.3.0 | 48.3 | 48.3 | 56.2 | 56.6 |
| SwiftBSON:3.1.0 | 34.8 | 34.8 | 49 | 49 |
| SwiftCbor:0.0.4 | 27.2 | 27.3 | 39.6 | 39.7 |
| SwiftMsgpack:1.2.1 | 25 | 25.2 | 37.2 | 37.3 |
| SwiftProtobuf:1.38.1 | **3.4** | **3.47** | **9.88** | **9.88** |
| TOML:2.0.0 | 60.5 | 60.7 | 77.8 | 78 |
| XMLCoder:0.18.2 | 137 | 138 | 163 | 164 |
| Yams:5.4.0 | 132 | 133 | 151 | 152 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| BinaryCodable:4.0.0 | 13K | 0.17K | 19K | 0.34K | 39K | 0.73K | 26K | 0.38K | 32K | 0.61K |
| CapnProto:capnproto-1.0.2 | 38K | 1.1K | 34K | 1.1K | 71K | 6.8K | 31K | 0.59K | 50K | 2.1K |
| FlatBuffers:24.3.25 | **130K** | **3.9K** | 83K | **4.4K** | 250K | 16K | 96K | 1.9K | 140K | 7.7K |
| Foundation.JSONEncoder:Foundation | 18K | 0.3K | 28K | 0.67K | 51K | 1.4K | 27K | 0.42K | 20K | 0.29K |
| Foundation.PropertyListEncoder:Foundation | 11K | 0.15K | 16K | 0.29K | 32K | 0.72K | 13K | 0.18K | 12K | 0.16K |
| IkigaJSON:2.5.3 | 19K | 0.29K | 28K | 0.61K | 52K | 1.2K | 30K | 0.45K | 21K | 0.3K |
| SwiftAvroCore:2.3.0 | 7K | 0.096K | 11K | 0.19K | 21K | 0.38K | 22K | 0.43K | 17K | 0.33K |
| SwiftBSON:3.1.0 | 9.1K | 0.13K | 14K | 0.22K | 29K | 0.51K | 11K | 0.13K | 8.5K | 0.1K |
| SwiftCbor:0.0.4 | 11K | 0.15K | 18K | 0.3K | 37K | 0.74K | 17K | 0.21K | 17K | 0.23K |
| SwiftMsgpack:1.2.1 | 12K | 0.17K | 18K | 0.33K | 40K | 0.83K | 18K | 0.23K | 16K | 0.21K |
| SwiftProtobuf:1.38.1 | 110K | 3K | **120K** | 4.1K | **290K** | **18K** | **190K** | **4.8K** | **240K** | **14K** |
| TOML:2.0.0 | 5.1K | 0.053K | 8.5K | 0.1K | 17K | 0.24K | 14K | 0.18K | 9.3K | 0.12K |
| XMLCoder:0.18.2 | 2.4K | 0.029K | 4.1K | 0.059K | 7.3K | 0.1K | 2.6K | 0.029K | 2K | 0.021K |
| Yams:5.4.0 | 2.4K | 0.029K | 3.8K | 0.055K | 7.6K | 0.1K | 3.2K | 0.038K | 2.1K | 0.025K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/swift/2026-07-24-183742.csv`
    - run=2026-07-24-183742
    - language=swift
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: python=3.14.0, node=24.15.0, dotnet=9.0.316
    - git=85145fd dirty
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
