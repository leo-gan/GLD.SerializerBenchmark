# C# (.NET) — Benchmark Results

**Generated:** 2026-07-24T10:11:41.742662

This page is a **snapshot of measured numbers** for C# (.NET) on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [C# (.NET) overview](index.md) |
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
| BinaryPack:1.0.3 | 73.1 | 32.5 | 40.5 | **106K** | 13.9K | 1739 | **1.00** |
| Ceras:4.1.7 | 114 | 40 | 73.7 | 23.3K | 11.4K | 1767 | **1.00** |
| CsvHelper:33.1.0 | 2,400 | 1,600 | 786 | 0.567K | **8.82K** | 1102 | **1.00** |
| ExtendedXmlSerializer:3.10.0.0 | 137 | 69.7 | 65.8 | 11.4K | 19.9K | 1746 | **1.00** |
| fastJson:2.4.0.4 | 377 | 133 | 243 | 20.5K | 22K | 1719 | **1.00** |
| FlatSharp:7.5.1 | 78.4 | 36.3 | 41.1 | 48K | 20.3K | 1726 | **1.00** |
| FsPickler:5.3.2 | 146 | 82.5 | 63.1 | 21K | 14.4K | 1793 | **1.00** |
| FsPicklerJson:5.3.2 | 333 | 137 | 194 | 20K | 25.5K | 1754 | **1.00** |
| Google.Protobuf:3.35.1 | 84.5 | 42.1 | 40.9 | 61.7K | 11.8K | 1776 | **1.00** |
| GroBuf:1.9.2 | **54.2** | **18.3** | 35.6 | 89.5K | 27.2K | 1729 | **1.00** |
| Hyperion:0.12.2 | 140 | 72.9 | 66 | 39K | 13.6K | 1780 | **1.00** |
| Jil:2.17.0 | 256 | 126 | 130 | 29.7K | 19.5K | 1746 | **1.00** |
| Json.Net:13.0.4 | 355 | 150 | 204 | 40.6K | 22.2K | 1765 | **1.00** |
| Json.Net (Helper):13.0.4 | 375 | 161 | 213 | 21.1K | 21.6K | 1760 | **1.00** |
| LightProto:1.3.4 | 88.4 | 44.1 | 43 | 63.9K | 12.2K | 1749 | **1.00** |
| MemoryPack | 58 | 25.2 | **32.4** | 61.9K | 16.6K | 1755 | **1.00** |
| Migrant:0.13.0.0 | 118 | 49.9 | 67.7 | 11.9K | 25.3K | 1784 | **1.00** |
| MS Binary:.NET 8.0.28 | 438 | 208 | 227 | 12.3K | 21.9K | 1757 | **1.00** |
| MS Bond Compact:.NET 8.0.28 | 67.8 | 31.2 | 36.3 | 69.4K | 11.4K | 1758 | **1.00** |
| MS Bond Fast:.NET 8.0.28 | 67.8 | 31.2 | 36.6 | 78K | 13.6K | 1751 | **1.00** |
| MS Bond Json:.NET 8.0.28 | 224 | 87.6 | 135 | 38.6K | 19.3K | 1770 | **1.00** |
| MS DataContract:.NET 8.0.28 | 475 | 152 | 322 | 15.1K | 48.3K | 1811 | **1.00** |
| MS DataContract Json:.NET 8.0.28 | 553 | 142 | 409 | 18K | 22.7K | 1813 | **1.00** |
| MS XmlSerializer:.NET 8.0.28 | 527 | 201 | 325 | 13.9K | 51K | 1772 | **1.00** |
| NetJSON:1.0.0 | 183 | 75.9 | 107 | 46.7K | 19.3K | 1771 | **1.00** |
| NetSerializer:4.1.2 | 89.6 | 37.2 | 51.8 | 80.8K | 11.9K | 1774 | **1.00** |
| ProtoBuf:2.4.9.1 | 105 | 33.5 | 69.9 | 49.5K | 12.2K | 1758 | **1.00** |
| ServiceStack:6.11.0 | 311 | 137 | 173 | 34.2K | 17.2K | 1803 | **1.00** |
| ServiceStack Json:6.11.0 | 362 | 154 | 208 | 24.7K | 19.5K | 1766 | **1.00** |
| SharpSerializer | 2,300 | 526 | 1,740 | 6.79K | 107K | 1718 | **1.00** |
| SharpYaml:3.13.0 | 1,100 | 249 | 850 | 3.69K | 26.2K | 1728 | **1.00** |
| SpanJson:4.2.1 | 134 | 68.3 | 64.7 | 61.5K | 19.5K | 1737 | **1.00** |
| System.Text.Json:8.0.0.0 | 227 | 96.8 | 127 | 26.2K | 22.7K | 1807 | **1.00** |
| Utf8Json:1.3.7 | 168 | 66.4 | 101 | 39K | 19.5K | 1784 | **1.00** |
| YamlDotNet:17.1.0 | 4,480 | 2,430 | 2,030 | 2.88K | 21.8K | 1759 | **1.00** |
| YAXLib:4.4.0 | 1,650 | 791 | 850 | 1.86K | 50.8K | 1599 | **1.00** |
| ZeroFormatter:1.6.4 | 61.8 | 26.5 | 34.9 | 73.7K | 13.6K | 1713 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| BinaryPack:1.0.3 | **4.43** | **4.32** | **4.46** | **4.45** |
| Ceras:4.1.7 | 28.9 | 29 | 31.5 | 30.1 |
| CsvHelper:33.1.0 | 3,660 | 3,660 | 3,730 | 3,690 |
| ExtendedXmlSerializer:3.10.0.0 | 108 | 107 | 103 | 100 |
| fastJson:2.4.0.4 | 36.7 | 36.9 | 40 | 38.9 |
| FlatSharp:7.5.1 | 16 | 15.5 | 15.1 | 14.1 |
| FsPickler:5.3.2 | 30.7 | 30.4 | 30.7 | 29.7 |
| FsPicklerJson:5.3.2 | 39.3 | 38.4 | 38.4 | 38.2 |
| Google.Protobuf:3.35.1 | 10.6 | 10.4 | 8.81 | 8.38 |
| GroBuf:1.9.2 | 7.94 | 7.75 | 7.62 | 7.61 |
| Hyperion:0.12.2 | 14.6 | 14.4 | 12.8 | 12.2 |
| Jil:2.17.0 | 16.2 | 15.9 | 16.5 | 16.4 |
| Json.Net:13.0.4 | 16.3 | 16.7 | 19.1 | 19.2 |
| Json.Net (Helper):13.0.4 | 39.7 | 39.6 | 43.2 | 42.7 |
| LightProto:1.3.4 | 8.07 | 7.98 | 8.13 | 7.99 |
| MemoryPack | 11.1 | 11 | 10.8 | 10.6 |
| Migrant:0.13.0.0 | 96.4 | 93.6 | 91.1 | 90.1 |
| MS Binary:.NET 8.0.28 | 48.1 | 46.9 | 46.3 | 45.5 |
| MS Bond Compact:.NET 8.0.28 | 7.12 | 7.12 | 13.7 | 13.5 |
| MS Bond Fast:.NET 8.0.28 | 4.8 | 4.78 | 11.2 | 11 |
| MS Bond Json:.NET 8.0.28 | 19.1 | 19.1 | 21.9 | 21.6 |
| MS DataContract:.NET 8.0.28 | 59.2 | 59.1 | 55.3 | 55.1 |
| MS DataContract Json:.NET 8.0.28 | 38.2 | 38.2 | 39.9 | 39.5 |
| MS XmlSerializer:.NET 8.0.28 | 53.3 | 52.2 | 53.9 | 52.5 |
| NetJSON:1.0.0 | 14.5 | 14.6 | 16.1 | 15.9 |
| NetSerializer:4.1.2 | 7.42 | 7.22 | 6.18 | 6.1 |
| ProtoBuf:2.4.9.1 | 15.9 | 15.6 | 14.1 | 13.8 |
| ServiceStack:6.11.0 | 20 | 19.8 | 23.4 | 23.4 |
| ServiceStack Json:6.11.0 | 33.7 | 34.2 | 38.7 | 38.5 |
| SharpSerializer | 86.5 | 85.9 | 86.9 | 85.8 |
| SharpYaml:3.13.0 | 266 | 260 | 312 | 311 |
| SpanJson:4.2.1 | 9.82 | 9.64 | 10.5 | 10 |
| System.Text.Json:8.0.0.0 | 43.2 | 42.4 | 43.5 | 43.6 |
| Utf8Json:1.3.7 | 18.6 | 18.6 | 19.4 | 19 |
| YamlDotNet:17.1.0 | 262 | 264 | 284 | 279 |
| YAXLib:4.4.0 | 422 | 420 | 448 | 444 |
| ZeroFormatter:1.6.4 | 8.2 | 8.08 | 7.82 | 7.78 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| BinaryPack:1.0.3 | **210K** | 6.5K | **230K** | 6.9K | **230K** | **15K** | 150K | 2.7K | **300K** | 10K |
| Ceras:4.1.7 | 43K | 3.6K | 49K | 5K | 35K | 7.4K | 49K | 2.8K | 49K | 5.8K |
| CsvHelper:33.1.0 | - | - | 0.48K | 0.4K | 0.27K | 0.24K | 1.3K | 0.84K | - | - |
| ExtendedXmlSerializer:3.10.0.0 | 20K | 4.9K | 23K | 6K | 9.2K | 3.6K | 24K | 4.7K | 25K | 4K |
| fastJson:2.4.0.4 | 33K | 0.95K | 50K | 2K | 27K | 1.7K | 73K | 2.6K | 37K | 0.8K |
| FlatSharp:7.5.1 | 79K | 4.5K | 90K | 6.7K | 62K | 7K | 90K | 3.4K | 120K | 8.6K |
| FsPickler:5.3.2 | 38K | 3K | 46K | 4.1K | 33K | 6.8K | 46K | 2.5K | 46K | 4.4K |
| FsPicklerJson:5.3.2 | 39K | 0.68K | 50K | 2.3K | 25K | 2.1K | 51K | 2K | 30K | 0.7K |
| Google.Protobuf:3.35.1 | 96K | 5.1K | 120K | 6.3K | 95K | 7.4K | 130K | 2.7K | 130K | 8.2K |
| GroBuf:1.9.2 | 140K | 1.3K | 180K | 8K | 130K | 13K | 200K | 4.4K | 260K | **11K** |
| Hyperion:0.12.2 | 68K | 3.1K | 77K | 4.5K | 69K | 6.4K | 79K | 2.2K | 73K | 2.8K |
| Jil:2.17.0 | 56K | 1K | 70K | 3.7K | 62K | 2.6K | 87K | 2.8K | 44K | 0.98K |
| Json.Net:13.0.4 | 66K | 1K | 110K | 2.1K | 61K | 1.4K | 140K | 2.2K | 58K | 0.81K |
| Json.Net (Helper):13.0.4 | 35K | 1K | 54K | 2K | 25K | 1.3K | 73K | 2.2K | 40K | 0.79K |
| LightProto:1.3.4 | 110K | 5.2K | 140K | 6.9K | 120K | 7.4K | 140K | 2.8K | 110K | 6.8K |
| MemoryPack | 110K | **8.7K** | 150K | 9.8K | 90K | 12K | 120K | 3.7K | 120K | 11K |
| Migrant:0.13.0.0 | 20K | 4.2K | 21K | 5.8K | 10K | 5.1K | 22K | 4.3K | 20K | 3.3K |
| MS Binary:.NET 8.0.28 | 20K | 0.47K | 24K | 1.1K | 21K | 1.7K | 30K | 1.1K | 26K | 1.6K |
| MS Bond Compact:.NET 8.0.28 | 150K | 6.7K | 200K | 8.5K | 140K | 12K | 180K | 3.7K | 220K | 9K |
| MS Bond Fast:.NET 8.0.28 | 180K | 5.8K | 220K | 8.4K | 210K | 12K | 200K | 3.8K | 230K | 8.9K |
| MS Bond Json:.NET 8.0.28 | 76K | 2.3K | 110K | 4.5K | 52K | 3.2K | 120K | 3.3K | 49K | 0.94K |
| MS DataContract:.NET 8.0.28 | 31K | 0.56K | 41K | 2K | 17K | 1.3K | 36K | 0.99K | 24K | 0.53K |
| MS DataContract Json:.NET 8.0.28 | 30K | 0.72K | 44K | 1.5K | 26K | 0.93K | 50K | 1K | 30K | 0.53K |
| MS XmlSerializer:.NET 8.0.28 | 27K | 0.89K | 37K | 1.7K | 19K | 1.4K | 33K | 0.86K | 26K | 0.6K |
| NetJSON:1.0.0 | 92K | 3.1K | 120K | 5.9K | 69K | 3.9K | 160K | 4K | 69K | 1.3K |
| NetSerializer:4.1.2 | 150K | 4.8K | 180K | 6.4K | 130K | 7.8K | 150K | 3.1K | 170K | 4.7K |
| ProtoBuf:2.4.9.1 | 87K | 4.5K | 110K | 5.5K | 63K | 6.7K | 93K | 2.3K | 130K | 5.7K |
| ServiceStack:6.11.0 | 61K | 1.5K | 88K | 2.9K | 50K | 1.5K | 140K | 2.8K | 46K | 0.88K |
| ServiceStack Json:6.11.0 | 47K | 1.3K | 65K | 2.4K | 30K | 1.2K | 100K | 2.1K | 37K | 0.85K |
| SharpSerializer | 10K | 0.1K | 15K | 0.28K | 12K | 0.24K | 17K | 0.25K | 13K | 0.17K |
| SharpYaml:3.13.0 | 4.8K | 0.34K | 6.5K | 0.7K | 3.8K | 0.28K | 14K | 0.62K | 7.6K | 0.36K |
| SpanJson:4.2.1 | 120K | 1.3K | 160K | 9.6K | 100K | 7.8K | **220K** | **5K** | 51K | 1.4K |
| System.Text.Json:8.0.0.0 | 52K | 2.1K | 68K | 3.5K | 23K | 2.6K | 91K | 2.7K | 42K | 1.2K |
| Utf8Json:1.3.7 | 79K | 5K | 96K | 7.1K | 54K | 2.7K | 110K | 3.6K | 54K | 1.3K |
| YamlDotNet:17.1.0 | 4.5K | 0.066K | 7.4K | 0.15K | 3.8K | 0.085K | 8.5K | 0.15K | 6.1K | 0.098K |
| YAXLib:4.4.0 | 3.2K | 0.23K | 4.1K | 0.42K | 2.4K | 0.34K | 6.4K | 0.41K | 3.9K | 0.26K |
| ZeroFormatter:1.6.4 | 120K | 7.5K | 140K | **9.9K** | 120K | 10K | 160K | 3.8K | 120K | 8.1K |

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one **data type** (and batch size):

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that data type so the picture stays readable. Tables above still list everyone.
- Each image also prints the data type, source CSV, modes, and sample size.

### Document · 1 instance

![Document · 1 instance](../analysis/plots/violin/csharp_document@n=1.png){ width="80%" }

### Document · 100 instances

![Document · 100 instances](../analysis/plots/violin/csharp_document@n=100.png){ width="80%" }

### Event · 1 instance

![Event · 1 instance](../analysis/plots/violin/csharp_event@n=1.png){ width="80%" }

### Event · 100 instances

![Event · 100 instances](../analysis/plots/violin/csharp_event@n=100.png){ width="80%" }

### Message · 1 instance

![Message · 1 instance](../analysis/plots/violin/csharp_message@n=1.png){ width="80%" }

### Message · 100 instances

![Message · 100 instances](../analysis/plots/violin/csharp_message@n=100.png){ width="80%" }

### Strings · 1 instance

![Strings · 1 instance](../analysis/plots/violin/csharp_strings@n=1.png){ width="80%" }

### Strings · 100 instances

![Strings · 100 instances](../analysis/plots/violin/csharp_strings@n=100.png){ width="80%" }

### Telemetry · 1 instance

![Telemetry · 1 instance](../analysis/plots/violin/csharp_telemetry@n=1.png){ width="80%" }

### Telemetry · 100 instances

![Telemetry · 100 instances](../analysis/plots/violin/csharp_telemetry@n=100.png){ width="80%" }

## How to regenerate this page

Snapshots are produced on a developer machine. After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l csharp   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/csharp/2026-07-24-100758.csv`
    - run=2026-07-24-100758
    - language=csharp
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: dotnet=9.0.316, python=3.14.0, node=24.15.0
    - git=0383351 dirty
    - seed=42
    - warmup_reps=1
    - serializers=37
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `BinaryPack` @ 1.0.3
      - `Ceras` @ 4.1.7
      - `CsvHelper` @ 33.1.0
      - `ExtendedXmlSerializer` @ 3.10.0.0
      - `FlatSharp` @ 7.5.1
      - `FsPickler` @ 5.3.2
      - `FsPicklerJson` @ 5.3.2
      - `Google.Protobuf` @ 3.35.1
      - `GroBuf` @ 1.9.2
      - `Hyperion` @ 0.12.2
      - `Jil` @ 2.17.0
      - `Json.Net` @ 13.0.4
      - `Json.Net (Helper)` @ 13.0.4
      - `LightProto` @ 1.3.4
      - `MS Binary` @ .NET 8.0.28
      - `MS Bond Compact` @ .NET 8.0.28
      - `MS Bond Fast` @ .NET 8.0.28
      - `MS Bond Json` @ .NET 8.0.28
      - `MS DataContract` @ .NET 8.0.28
      - `MS DataContract Json` @ .NET 8.0.28
      - `MS XmlSerializer` @ .NET 8.0.28
      - `MemoryPack`
      - `Migrant` @ 0.13.0.0
      - `NetJSON` @ 1.0.0
      - `NetSerializer` @ 4.1.2
      - `ProtoBuf` @ 2.4.9.1
      - `ServiceStack` @ 6.11.0
      - `ServiceStack Json` @ 6.11.0
      - `SharpSerializer`
      - `SharpYaml` @ 3.13.0
      - `SpanJson` @ 4.2.1
      - `System.Text.Json` @ 8.0.0.0
      - `Utf8Json` @ 1.3.7
      - `YAXLib` @ 4.4.0
      - `YamlDotNet` @ 17.1.0
      - `ZeroFormatter` @ 1.6.4
      - `fastJson` @ 2.4.0.4
