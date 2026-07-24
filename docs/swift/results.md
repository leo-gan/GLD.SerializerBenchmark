# Swift — Benchmark Results

**Generated:** 2026-07-20T12:56:43.377454

This page is a **snapshot of measured numbers** for Swift on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [Swift overview](index.md) |
| How CSVs become these tables | [Analysis methodology](../analysis/ANALYSIS_METHODOLOGY.md) |
| What each metric means | [Metrics catalog](../analysis/METRICS.md) |
| All languages’ result links | [Results summary](../analysis/BENCHMARK_SUMMARY.md) |

## How to read these tables

Compare serializers **inside this language**. Prefer the same [category](../analysis/serialization_categories.md) (for example JSON with JSON) so the comparison stays fair.

| Term | Meaning |
|------|---------|
| **bytes mode** | In-memory buffer API (encode to bytes / decode from a buffer) |
| **stream mode** | Stream-style API (write/read through a stream) |
| **µs** | Microseconds (one microsecond = 1000 nanoseconds). Tables show µs; raw CSVs store nanoseconds. |
| **Ops/s** | Operations per second from mean total time — higher is faster |
| **Bold** | Best value in that column (lowest time/size; highest ops/s). Ties are all bolded. |

Rows are sorted by **serializer name** (easy lookup), not by rank. Batch workloads appear as **Type · N instances** (for example Message · 100 instances). Default multi-serializer tables show **high-importance** metrics only; pairwise / version A/B reports can show the full set ([Metrics](../analysis/METRICS.md)).

## Summary tables

### Summary

One row per serializer (averaged across fixtures; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| BinaryCodable:4.0.0 | 1,880 | 1,300 | 586 | 17.5K | 13.4K | 1782 | **1.00** |
| CapnProto:capnproto-1.0.2 | 987 | 784 | 202 | 56.5K | 18.3K | 1831 | **1.00** |
| FlatBuffers:24.3.25 | 705 | 614 | 90.8 | 106K | 17.4K | 1829 | **1.00** |
| Foundation.JSONEncoder:Foundation | 1,820 | 1,220 | 597 | 20.6K | 19.7K | 1793 | **1.00** |
| Foundation.PropertyListEncoder:Foundation | 2,900 | 1,410 | 1,490 | 10.8K | 16.3K | 1793 | **1.00** |
| IkigaJSON:2.5.3 | 1,830 | 1,160 | 676 | 19.1K | 19.7K | 1850 | **1.00** |
| SwiftAvroCore:2.3.0 | 2,730 | 2,130 | 603 | 10.5K | **9.02K** | 1804 | **1.00** |
| SwiftBSON:3.1.0 | 3,970 | 2,050 | 1,920 | 8.86K | 20.7K | 1820 | **1.00** |
| SwiftCbor:0.0.4 | 2,490 | 1,640 | 850 | 13K | 13.6K | 1798 | **1.00** |
| SwiftMsgpack:1.2.1 | 2,360 | 1,510 | 846 | 14K | 13.6K | 1783 | **1.00** |
| SwiftProtobuf:1.38.1 | **426** | **378** | **47.7** | **210K** | 10.1K | 1780 | **1.00** |
| TOML:2.0.0 | 5,420 | 4,220 | 1,200 | 6.37K | 22.4K | 1773 | **1.00** |
| XMLCoder:0.18.2 | 15,400 | 8,340 | 7,080 | 1.97K | 34K | 1811 | **1.00** |
| Yams:5.4.0 | 14,000 | 9,870 | 4,090 | 2.09K | 22.5K | 1772 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| BinaryCodable:4.0.0 | 13.1 | 13.1 | 24.1 | 24 |
| CapnProto:capnproto-1.0.2 | 2.53 | 2.53 | 12 | 12 |
| FlatBuffers:24.3.25 | 1.21 | 1.21 | 12.3 | 12.3 |
| Foundation.JSONEncoder:Foundation | 8.04 | 8.03 | 21.7 | 21.7 |
| Foundation.PropertyListEncoder:Foundation | 16.3 | 16.3 | 34 | 34 |
| IkigaJSON:2.5.3 | 9.11 | 9.02 | 23.5 | 23.6 |
| SwiftAvroCore:2.3.0 | 31.5 | 31.5 | 37.6 | 37.6 |
| SwiftBSON:3.1.0 | 18.1 | 18.1 | 32.3 | 32.2 |
| SwiftCbor:0.0.4 | 13.7 | 13.7 | 25.7 | 25.7 |
| SwiftMsgpack:1.2.1 | 11.9 | 11.8 | 24.9 | 24.8 |
| SwiftProtobuf:1.38.1 | **0.734** | **0.732** | **6.43** | **6.41** |
| TOML:2.0.0 | 40.7 | 40.6 | 56.1 | 56.4 |
| XMLCoder:0.18.2 | 120 | 119 | 144 | 143 |
| Yams:5.4.0 | 114 | 114 | 133 | 133 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| BinaryCodable:4.0.0 | 15K | 0.17K | 37K | 0.36K | 0.076M | 0.73K | 39K | 0.39K | 0.062M | 0.63K |
| CapnProto:capnproto-1.0.2 | 110K | 1.3K | 120K | 1.4K | 0.4M | 10K | 57K | 0.64K | 0.24M | 2.7K |
| FlatBuffers:24.3.25 | **290K** | **4.1K** | 230K | **4.8K** | 0.82M | 20K | 160K | 1.9K | 0.39M | 8.7K |
| Foundation.JSONEncoder:Foundation | 29K | 0.29K | 69K | 0.72K | 0.12M | 1.4K | 41K | 0.4K | 0.028M | 0.3K |
| Foundation.PropertyListEncoder:Foundation | 13K | 0.15K | 30K | 0.32K | 0.061M | 0.7K | 17K | 0.17K | 0.016M | 0.16K |
| IkigaJSON:2.5.3 | 26K | 0.28K | 60K | 0.64K | 0.11M | 1.2K | 42K | 0.44K | 0.028M | 0.29K |
| SwiftAvroCore:2.3.0 | 8K | 0.093K | 17K | 0.2K | 0.032M | 0.36K | 38K | 0.44K | 0.029M | 0.32K |
| SwiftBSON:3.1.0 | 11K | 0.12K | 20K | 0.23K | 0.055M | 0.49K | 12K | 0.12K | 0.0099M | 0.1K |
| SwiftCbor:0.0.4 | 14K | 0.15K | 32K | 0.34K | 0.073M | 0.74K | 22K | 0.21K | 0.022M | 0.23K |
| SwiftMsgpack:1.2.1 | 15K | 0.18K | 35K | 0.36K | 0.084M | 0.81K | 24K | 0.22K | 0.021M | 0.21K |
| SwiftProtobuf:1.38.1 | 280K | 2.8K | **460K** | 4.7K | **1.4M** | **26K** | **500K** | **5.4K** | **1.2M** | **18K** |
| TOML:2.0.0 | 5.5K | 0.051K | 13K | 0.11K | 0.025M | 0.24K | 19K | 0.19K | 0.013M | 0.12K |
| XMLCoder:0.18.2 | 2.6K | 0.029K | 5.4K | 0.062K | 0.0084M | 0.1K | 2.7K | 0.029K | 0.002M | 0.021K |
| Yams:5.4.0 | 2.4K | 0.028K | 4.9K | 0.057K | 0.0088M | 0.1K | 3.5K | 0.038K | 0.0023M | 0.024K |

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one sample data type:

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that fixture so the picture stays readable. Tables above still list everyone.
- Each image also prints fixture name, source CSV, modes, and sample size.

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

Snapshots are produced on a developer machine. After a harness run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l swift   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the harness recorded them.
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/swift/2026-07-20-125335.csv`
    - run=2026-07-20-125335
    - language=swift
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: python=3.14.0, node=24.15.0, dotnet=8.0.422
    - git=61a38cf dirty
    - seed=42
    - warmup_reps=1
    - serializers=14
    - metrics_profile=multi_way
    - **Fixtures (config):** message, document, telemetry, strings, event
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
