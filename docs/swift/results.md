# Swift — Benchmark Results

**Generated:** 2026-07-24T19:44:19.633987

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

> **Stream honesty:** all stream rows are **`adapted`** (in-memory encode/decode then dump to a stream, or equivalent). Do **not** treat stream columns as proof of incremental I/O. Labels: **adapted** 140. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| BinaryCodable:4.0.0 | 1,870 | 1,290 | 571 | 11.1K | 13.4K | 1783 | **1.00** |
| CapnProto:capnproto-1.0.2 | 1,010 | 796 | 218 | 17.9K | 18.3K | 1699 | **1.00** |
| FlatBuffers:24.3.25 | 700 | 607 | 92 | 44.8K | 17.4K | 1739 | **1.00** |
| Foundation.JSONEncoder:Foundation | 1,780 | 1,190 | 588 | 11.8K | 19.7K | 1744 | **1.00** |
| Foundation.PropertyListEncoder:Foundation | 2,810 | 1,370 | 1,440 | 7.4K | 16.3K | 1776 | **1.00** |
| IkigaJSON:2.5.3 | 1,780 | 1,120 | 661 | 12.3K | 19.7K | 1752 | **1.00** |
| SwiftAvroCore:2.3.0 | 2,640 | 2,040 | 596 | 7.08K | **9.02K** | 1782 | **1.00** |
| SwiftBSON:3.1.0 | 3,820 | 1,980 | 1,840 | 6.27K | 20.7K | 1772 | **1.00** |
| SwiftCbor:0.0.4 | 2,460 | 1,600 | 858 | 8.75K | 13.6K | 1778 | **1.00** |
| SwiftMsgpack:1.2.1 | 2,330 | 1,480 | 841 | 9.3K | 13.6K | 1782 | **1.00** |
| SwiftProtobuf:1.38.1 | **430** | **379** | **50.6** | **63.9K** | 10.1K | 1714 | **1.00** |
| TOML:2.0.0 | 5,340 | 4,120 | 1,220 | 4.76K | 22.4K | 1762 | **1.00** |
| XMLCoder:0.18.2 | 15,100 | 8,070 | 6,980 | 1.77K | 34K | 1798 | **1.00** |
| Yams:5.4.0 | 13,500 | 9,550 | 3,990 | 1.88K | 22.5K | 1821 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| BinaryCodable:4.0.0 | 25.6 | 25.9 | 39.1 | 39.2 |
| CapnProto:capnproto-1.0.2 | 14.2 | 14.4 | 25.2 | 25.4 |
| FlatBuffers:24.3.25 | 4.14 | 4.14 | 16.2 | 16.1 |
| Foundation.JSONEncoder:Foundation | 19.9 | 20.1 | 36.7 | 36.9 |
| Foundation.PropertyListEncoder:Foundation | 31.5 | 31.8 | 51.7 | 52.1 |
| IkigaJSON:2.5.3 | 19.3 | 19.5 | 35.8 | 36 |
| SwiftAvroCore:2.3.0 | 49.1 | 48.9 | 60.1 | 60.3 |
| SwiftBSON:3.1.0 | 35.2 | 35.6 | 51.8 | 51.9 |
| SwiftCbor:0.0.4 | 27.4 | 27.5 | 42 | 42.2 |
| SwiftMsgpack:1.2.1 | 25.3 | 25.4 | 39.1 | 39.1 |
| SwiftProtobuf:1.38.1 | **3.5** | **3.54** | **10.5** | **10.5** |
| TOML:2.0.0 | 62 | 62.3 | 82.9 | 82.8 |
| XMLCoder:0.18.2 | 141 | 142 | 173 | 173 |
| Yams:5.4.0 | 134 | 136 | 161 | 161 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| BinaryCodable:4.0.0 | 12K | 0.17K | 22K | 0.36K | 39K | 0.74K | 27K | 0.4K | 32K | 0.61K |
| CapnProto:capnproto-1.0.2 | 37K | 1.1K | 41K | 1.3K | 70K | 6.7K | 32K | 0.61K | 48K | 1.9K |
| FlatBuffers:24.3.25 | **120K** | **4K** | 110K | **4.7K** | 240K | 16K | 97K | 2K | 130K | 7.5K |
| Foundation.JSONEncoder:Foundation | 18K | 0.3K | 32K | 0.72K | 50K | 1.4K | 29K | 0.43K | 20K | 0.29K |
| Foundation.PropertyListEncoder:Foundation | 10K | 0.15K | 18K | 0.31K | 32K | 0.72K | 14K | 0.18K | 12K | 0.16K |
| IkigaJSON:2.5.3 | 18K | 0.29K | 33K | 0.66K | 52K | 1.3K | 31K | 0.46K | 21K | 0.3K |
| SwiftAvroCore:2.3.0 | 6.8K | 0.096K | 12K | 0.2K | 20K | 0.38K | 23K | 0.44K | 17K | 0.33K |
| SwiftBSON:3.1.0 | 9K | 0.13K | 15K | 0.24K | 28K | 0.52K | 11K | 0.13K | 8.4K | 0.1K |
| SwiftCbor:0.0.4 | 11K | 0.16K | 21K | 0.33K | 36K | 0.75K | 17K | 0.22K | 16K | 0.22K |
| SwiftMsgpack:1.2.1 | 12K | 0.18K | 22K | 0.36K | 40K | 0.84K | 19K | 0.23K | 16K | 0.21K |
| SwiftProtobuf:1.38.1 | 110K | 2.9K | **140K** | 4.4K | **290K** | **18K** | **200K** | **4.8K** | **230K** | **13K** |
| TOML:2.0.0 | 4.9K | 0.052K | 9.7K | 0.11K | 16K | 0.24K | 14K | 0.18K | 9.2K | 0.12K |
| XMLCoder:0.18.2 | 2.4K | 0.029K | 4.7K | 0.064K | 7.1K | 0.11K | 2.7K | 0.03K | 2K | 0.021K |
| Yams:5.4.0 | 2.3K | 0.029K | 4.4K | 0.06K | 7.4K | 0.1K | 3.4K | 0.039K | 2.1K | 0.024K |

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
    
    - **Source CSV:** `logs/swift/2026-07-24-194037.csv`
    - run=2026-07-24-194037
    - language=swift
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: python=3.14.0, node=24.15.0, dotnet=9.0.316
    - git=7431b57 dirty
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
