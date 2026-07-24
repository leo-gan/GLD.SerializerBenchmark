# C# (.NET) — Benchmark Results

**Generated:** 2026-07-24T16:05:40.503936

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
| Apache.Avro:1.12.1 | 336 | 174 | 159 | 22.1K | 10.5K | 1753 | **1.00** |
| BinaryPack:1.0.3 | 73.2 | 33.4 | 39.6 | **100K** | 13.9K | 1772 | **1.00** |
| Ceras:4.1.7 | 117 | 41 | 75.9 | 22K | 11.4K | 1753 | **1.00** |
| CsvHelper:33.1.0 | 2,410 | 1,620 | 789 | 0.549K | **8.82K** | 1078 | **1.00** |
| ExtendedXmlSerializer:3.10.0.0 | 138 | 70 | 66.7 | 10.8K | 19.9K | 1732 | **1.00** |
| fastJson:2.4.0.4 | 389 | 137 | 251 | 18.5K | 22K | 1699 | **1.00** |
| FlatSharp:7.5.1 | 77.6 | 35.6 | 41.6 | 47.1K | 20.3K | 1737 | **1.00** |
| FsPickler:5.3.2 | 151 | 84.4 | 66 | 19.6K | 14.4K | 1776 | **1.00** |
| FsPicklerJson:5.3.2 | 334 | 137 | 197 | 19.5K | 25.5K | 1730 | **1.00** |
| Google.Protobuf:3.35.1 | 84.8 | 42.6 | 41.1 | 61.6K | 11.8K | 1766 | **1.00** |
| GroBuf:1.9.2 | **55.8** | **19.1** | 36.1 | 85.1K | 27.2K | 1709 | **1.00** |
| Hyperion:0.12.2 | 140 | 73.2 | 66.3 | 39.3K | 13.6K | 1765 | **1.00** |
| Jil:2.17.0 | 259 | 128 | 129 | 29.2K | 19.5K | 1752 | **1.00** |
| Json.Net:13.0.4 | 360 | 151 | 205 | 39.2K | 22.2K | 1755 | **1.00** |
| Json.Net (Helper):13.0.4 | 380 | 160 | 215 | 20.1K | 21.6K | 1757 | **1.00** |
| LightProto:1.3.4 | 91.1 | 45.5 | 44 | 60.3K | 12.2K | 1772 | **1.00** |
| MemoryPack | 58.8 | 25.5 | **32.9** | 59.2K | 16.6K | 1762 | **1.00** |
| Migrant:0.13.0.0 | 123 | 51.7 | 70.6 | 11.2K | 25.3K | 1764 | **1.00** |
| MS Binary:.NET 8.0.28 | 433 | 205 | 227 | 12.1K | 21.9K | 1736 | **1.00** |
| MS Bond Compact:.NET 8.0.28 | 69.4 | 32.1 | 36.8 | 65.3K | 11.4K | 1770 | **1.00** |
| MS Bond Fast:.NET 8.0.28 | 69.4 | 31.7 | 37.2 | 75.6K | 13.6K | 1760 | **1.00** |
| MS Bond Json:.NET 8.0.28 | 229 | 88.9 | 139 | 36.4K | 19.3K | 1731 | **1.00** |
| MS DataContract:.NET 8.0.28 | 478 | 150 | 326 | 14.7K | 48.3K | 1794 | **1.00** |
| MS DataContract Json:.NET 8.0.28 | 556 | 138 | 415 | 17.7K | 22.7K | 1771 | **1.00** |
| MS XmlSerializer:.NET 8.0.28 | 524 | 202 | 322 | 13.6K | 51K | 1774 | **1.00** |
| NetJSON:1.0.0 | 186 | 76.1 | 109 | 44.5K | 19.3K | 1762 | **1.00** |
| NetSerializer:4.1.2 | 89.7 | 37.9 | 50.6 | 78.4K | 11.9K | 1770 | **1.00** |
| ProtoBuf:2.4.9.1 | 105 | 34.3 | 70.1 | 47.8K | 12.2K | 1763 | **1.00** |
| ServiceStack:6.11.0 | 311 | 142 | 168 | 29.5K | 17.2K | 1778 | **1.00** |
| ServiceStack Json:6.11.0 | 371 | 157 | 213 | 21.9K | 19.5K | 1796 | **1.00** |
| SharpSerializer | 2,260 | 530 | 1,720 | 6.66K | 107K | 1719 | **1.00** |
| SharpYaml:3.13.0 | 1,110 | 247 | 861 | 3.54K | 26.2K | 1712 | **1.00** |
| SpanJson:4.2.1 | 134 | 67.6 | 66.1 | 57.7K | 19.5K | 1761 | **1.00** |
| System.Text.Json:8.0.0.0 | 228 | 98.6 | 129 | 24.7K | 22.7K | 1787 | **1.00** |
| Utf8Json:1.3.7 | 164 | 67.4 | 96.1 | 36.8K | 19.5K | 1765 | **1.00** |
| YamlDotNet:17.1.0 | 4,500 | 2,460 | 2,000 | 2.77K | 21.8K | 1738 | **1.00** |
| YAXLib:4.4.0 | 1,630 | 779 | 836 | 1.81K | 50.8K | 1619 | **1.00** |
| ZeroFormatter:1.6.4 | 62.8 | 27 | 35.7 | 68.6K | 13.6K | 1746 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| Apache.Avro:1.12.1 | 15.7 | 14.4 | 13.7 | 13.5 |
| BinaryPack:1.0.3 | **4.17** | **3.9** | **3.46** | **3.43** |
| Ceras:4.1.7 | 26 | 24.9 | 22.6 | 22.4 |
| CsvHelper:33.1.0 | 3,650 | 3,630 | 3,680 | 3,670 |
| ExtendedXmlSerializer:3.10.0.0 | 91.4 | 82.3 | 68.4 | 67.6 |
| fastJson:2.4.0.4 | 32 | 30.8 | 33.9 | 33.9 |
| FlatSharp:7.5.1 | 13.5 | 12 | 9.98 | 9.93 |
| FsPickler:5.3.2 | 27 | 26 | 21 | 20.7 |
| FsPicklerJson:5.3.2 | 38.2 | 36.7 | 32 | 31.9 |
| Google.Protobuf:3.35.1 | 8.66 | 7.96 | 6.16 | 6.11 |
| GroBuf:1.9.2 | 6.93 | 6.26 | 5.06 | 5.01 |
| Hyperion:0.12.2 | 12.2 | 11.4 | 9.06 | 8.88 |
| Jil:2.17.0 | 13.8 | 12.7 | 11.7 | 11.4 |
| Json.Net:13.0.4 | 17.3 | 17.1 | 18.7 | 18.6 |
| Json.Net (Helper):13.0.4 | 38.3 | 36.2 | 36.3 | 36.2 |
| LightProto:1.3.4 | 7.64 | 7.1 | 6.46 | 6.42 |
| MemoryPack | 9.2 | 8.49 | 7.46 | 7.46 |
| Migrant:0.13.0.0 | 86.2 | 80.5 | 72.1 | 71.7 |
| MS Binary:.NET 8.0.28 | 44.5 | 41.4 | 34.6 | 34.4 |
| MS Bond Compact:.NET 8.0.28 | 6.45 | 5.92 | 11 | 10.9 |
| MS Bond Fast:.NET 8.0.28 | 4.49 | 4.25 | 9.37 | 9.36 |
| MS Bond Json:.NET 8.0.28 | 17.8 | 17.4 | 17.2 | 17.1 |
| MS DataContract:.NET 8.0.28 | 51.5 | 49 | 36.7 | 36.1 |
| MS DataContract Json:.NET 8.0.28 | 34.2 | 32.6 | 26.5 | 26.1 |
| MS XmlSerializer:.NET 8.0.28 | 45.5 | 41.5 | 37.4 | 37 |
| NetJSON:1.0.0 | 12.4 | 11.8 | 12.7 | 12.7 |
| NetSerializer:4.1.2 | 6.36 | 5.91 | 4.39 | 4.35 |
| ProtoBuf:2.4.9.1 | 14.3 | 14 | 10.7 | 10.6 |
| ServiceStack:6.11.0 | 19.8 | 19 | 19 | 19.1 |
| ServiceStack Json:6.11.0 | 31.8 | 31 | 28.7 | 28.2 |
| SharpSerializer | 81.1 | 78.2 | 67.1 | 66.3 |
| SharpYaml:3.13.0 | 258 | 259 | 285 | 283 |
| SpanJson:4.2.1 | 8.63 | 7.93 | 7.35 | 7.26 |
| System.Text.Json:8.0.0.0 | 39.4 | 36.3 | 28.4 | 27.9 |
| Utf8Json:1.3.7 | 17.1 | 15.7 | 14.2 | 14 |
| YamlDotNet:17.1.0 | 257 | 248 | 239 | 238 |
| YAXLib:4.4.0 | 376 | 368 | 364 | 363 |
| ZeroFormatter:1.6.4 | 7.71 | 7.18 | 5.77 | 5.79 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| Apache.Avro:1.12.1 | 47K | 1.2K | 47K | 1.7K | 64K | 1.9K | 51K | 1.3K | 52K | 1.2K |
| BinaryPack:1.0.3 | **180K** | 6.5K | 160K | 6.8K | **240K** | **15K** | 120K | 2.8K | **270K** | 9.9K |
| Ceras:4.1.7 | 41K | 3.6K | 37K | 4.9K | 38K | 7.5K | 37K | 2.7K | 44K | 5.4K |
| CsvHelper:33.1.0 | - | - | 0.46K | 0.39K | 0.27K | 0.23K | 1.2K | 0.86K | - | - |
| ExtendedXmlSerializer:3.10.0.0 | 19K | 4.9K | 18K | 5.9K | 11K | 3.4K | 17K | 4.8K | 24K | 4.1K |
| fastJson:2.4.0.4 | 32K | 0.73K | 38K | 1.9K | 31K | 1.6K | 55K | 2.6K | 33K | 0.77K |
| FlatSharp:7.5.1 | 78K | 5.1K | 69K | 6.5K | 74K | 7K | 72K | 3.2K | 98K | 8.2K |
| FsPickler:5.3.2 | 37K | 2.9K | 33K | 3.9K | 37K | 6.5K | 34K | 2.4K | 37K | 4.2K |
| FsPicklerJson:5.3.2 | 40K | 1.3K | 44K | 2.2K | 26K | 1.9K | 46K | 1.9K | 29K | 0.69K |
| Google.Protobuf:3.35.1 | 91K | 5.1K | 100K | 6.2K | 120K | 7.7K | 110K | 2.8K | 100K | 7.8K |
| GroBuf:1.9.2 | 120K | 5.4K | 140K | 7.9K | 140K | 13K | 160K | 4.3K | 230K | **11K** |
| Hyperion:0.12.2 | 64K | 3.1K | 70K | 4.6K | 82K | 6.2K | 65K | 2.2K | 67K | 2.7K |
| Jil:2.17.0 | 56K | 2.6K | 55K | 3.7K | 72K | 2.4K | 68K | 2.6K | 40K | 0.97K |
| Json.Net:13.0.4 | 65K | 1K | 110K | 2K | 58K | 1.3K | 130K | 2.2K | 59K | 0.81K |
| Json.Net (Helper):13.0.4 | 37K | 1K | 45K | 2K | 26K | 1.2K | 62K | 2.1K | 39K | 0.79K |
| LightProto:1.3.4 | 98K | 1.4K | 97K | 6.6K | 130K | 7K | 100K | 2.7K | 88K | 6.6K |
| MemoryPack | 120K | **8.4K** | 110K | 9.4K | 110K | 12K | 80K | 3.7K | 110K | 10K |
| Migrant:0.13.0.0 | 19K | 4K | 17K | 5.7K | 12K | 4.6K | 17K | 4.4K | 18K | 3.2K |
| MS Binary:.NET 8.0.28 | 20K | 0.68K | 21K | 1.1K | 22K | 1.7K | 24K | 1.1K | 24K | 1.5K |
| MS Bond Compact:.NET 8.0.28 | 160K | 6.6K | 160K | 8.3K | 160K | 12K | 160K | 3.6K | 190K | 8.8K |
| MS Bond Fast:.NET 8.0.28 | 170K | 5.8K | **190K** | 8.1K | 220K | 12K | **180K** | 3.8K | 230K | 8.8K |
| MS Bond Json:.NET 8.0.28 | 77K | 2.3K | 91K | 4.4K | 56K | 2.8K | 110K | 3.2K | 49K | 0.93K |
| MS DataContract:.NET 8.0.28 | 31K | 0.65K | 33K | 1.9K | 19K | 1.2K | 30K | 1K | 23K | 0.51K |
| MS DataContract Json:.NET 8.0.28 | 29K | 0.72K | 39K | 1.5K | 29K | 0.9K | 42K | 1K | 28K | 0.51K |
| MS XmlSerializer:.NET 8.0.28 | 27K | 0.87K | 30K | 1.7K | 22K | 1.4K | 28K | 0.85K | 25K | 0.61K |
| NetJSON:1.0.0 | 92K | 3.2K | 100K | 5.9K | 81K | 3.7K | 130K | 4K | 68K | 1.2K |
| NetSerializer:4.1.2 | 130K | 4.8K | 140K | 6.3K | 160K | 7.7K | 120K | 3.2K | 170K | 4.7K |
| ProtoBuf:2.4.9.1 | 86K | 4.4K | 86K | 5.4K | 70K | 6.4K | 81K | 2.4K | 120K | 5.7K |
| ServiceStack:6.11.0 | 54K | 1.5K | 64K | 2.8K | 50K | 1.4K | 100K | 3K | 41K | 0.88K |
| ServiceStack Json:6.11.0 | 42K | 1.2K | 49K | 2.3K | 31K | 1.2K | 73K | 2K | 33K | 0.83K |
| SharpSerializer | 10K | 0.11K | 14K | 0.27K | 12K | 0.24K | 15K | 0.25K | 12K | 0.17K |
| SharpYaml:3.13.0 | 4.7K | 0.34K | 6K | 0.68K | 3.9K | 0.29K | 12K | 0.6K | 7.4K | 0.35K |
| SpanJson:4.2.1 | 100K | 6.1K | 140K | **9.7K** | 120K | 7.3K | 170K | **5K** | 48K | 1.4K |
| System.Text.Json:8.0.0.0 | 51K | 2.1K | 56K | 3.5K | 25K | 2.6K | 69K | 2.7K | 39K | 1.2K |
| Utf8Json:1.3.7 | 73K | 5.3K | 80K | 7.2K | 58K | 2.8K | 83K | 3.7K | 49K | 1.3K |
| YamlDotNet:17.1.0 | 4.4K | 0.067K | 6.5K | 0.14K | 3.9K | 0.09K | 7.2K | 0.15K | 6K | 0.095K |
| YAXLib:4.4.0 | 3.2K | 0.22K | 3.8K | 0.41K | 2.7K | 0.37K | 5.5K | 0.41K | 3.7K | 0.26K |
| ZeroFormatter:1.6.4 | 110K | 7.7K | 110K | 9.3K | 130K | 11K | 130K | 3.8K | 110K | 8.2K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/csharp/2026-07-24-160139.csv`
    - run=2026-07-24-160139
    - language=csharp
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: dotnet=9.0.316, python=3.14.0, node=24.15.0
    - git=591acb0 dirty
    - seed=42
    - warmup_reps=1
    - serializers=38
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `Apache.Avro` @ 1.12.1
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
