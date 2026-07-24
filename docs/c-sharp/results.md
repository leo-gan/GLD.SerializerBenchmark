# C# (.NET) — Benchmark Results

**Generated:** 2026-07-20T13:00:18.394625

This page is a **snapshot of measured numbers** for C# (.NET) on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [C# (.NET) overview](index.md) |
| How CSVs become these tables | [Analysis methodology](../analysis/ANALYSIS_METHODOLOGY.md) |
| What each metric means | [Metrics catalog](../analysis/METRICS.md) |
| All languages’ result links | [Results summary](../analysis/BENCHMARK_SUMMARY.md) |

## How to read these tables

Compare serializers **inside this language**. Prefer the same [category](../analysis/serialization_categories.md) (for example JSON with JSON) so the comparison stays fair.

| Term | Meaning |
|------|---------|
| **data type** | Sample shape: `message`, `document`, `telemetry`, `strings`, or `event` (CSV `TestDataName`; older text may say “fixture”) |
| **bytes mode** | In-memory buffer API (encode to bytes / decode from a buffer) |
| **stream mode** | Stream-style API (write/read through a stream) |
| **µs** | Microseconds (one microsecond = 1000 nanoseconds). Tables show µs; raw CSVs store nanoseconds. |
| **Ops/s** | Operations per second from mean total time — higher is faster |
| **Bold** | Best value in that column (lowest time/size; highest ops/s). Ties are all bolded. |

Rows are sorted by **serializer name** (easy lookup), not by rank. Batch workloads appear as **Data type · N instances** (for example Message · 100 instances). Default multi-serializer tables show **high-importance** metrics only; pairwise / version A/B reports can show the full set ([Metrics](../analysis/METRICS.md)).

## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| BinaryPack:1.0.3 | 76.1 | 33.8 | 41.9 | **90.5K** | 13.9K | 1741 | **1.00** |
| Ceras:4.1.7 | 120 | 42.2 | 77.4 | 20.6K | 11.4K | 1803 | **1.00** |
| CsvHelper:33.1.0 | 2,490 | 1,670 | 807 | 0.558K | **8.82K** | 1053 | **1.00** |
| ExtendedXmlSerializer:3.10.0.0 | 145 | 72.2 | 71.2 | 10.4K | 19.9K | 1756 | **1.00** |
| fastJson:2.4.0.4 | 393 | 139 | 252 | 18.7K | 22K | 1748 | **1.00** |
| FlatSharp:7.5.1 | 81.4 | 36.8 | 44.1 | 42K | 20.3K | 1751 | **1.00** |
| FsPickler:5.3.2 | 152 | 85.2 | 66.5 | 18.2K | 14.4K | 1807 | **1.00** |
| FsPicklerJson:5.3.2 | 335 | 135 | 198 | 19.3K | 25.5K | 1784 | **1.00** |
| Google.Protobuf:3.35.1 | 85.7 | 43.3 | 42 | 55.4K | 11.8K | 1770 | **1.00** |
| GroBuf:1.9.2 | **56.9** | **19** | 37.3 | 77.9K | 27.2K | 1739 | **1.00** |
| Hyperion:0.12.2 | 142 | 73 | 67.6 | 34.4K | 13.6K | 1778 | **1.00** |
| Jil:2.17.0 | 260 | 125 | 134 | 28.2K | 19.5K | 1768 | **1.00** |
| Json.Net:13.0.4 | 362 | 153 | 208 | 40.9K | 22.2K | 1759 | **1.00** |
| Json.Net (Helper):13.0.4 | 384 | 165 | 218 | 20.5K | 21.6K | 1754 | **1.00** |
| MemoryPack | 59.8 | 26.5 | **33** | 57.8K | 16.6K | 1776 | **1.00** |
| Migrant:0.13.0.0 | 128 | 52.6 | 74.2 | 10.8K | 25.3K | 1794 | **1.00** |
| MS Binary:.NET 8.0.28 | 450 | 215 | 234 | 10.8K | 21.9K | 1768 | **1.00** |
| MS Bond Compact:.NET 8.0.28 | 70.7 | 32.5 | 37.7 | 61.3K | 11.4K | 1769 | **1.00** |
| MS Bond Fast:.NET 8.0.28 | 69.6 | 31.9 | 37.4 | 72.1K | 13.6K | 1764 | **1.00** |
| MS Bond Json:.NET 8.0.28 | 234 | 92 | 140 | 36.4K | 19.3K | 1761 | **1.00** |
| MS DataContract:.NET 8.0.28 | 484 | 152 | 328 | 13.9K | 48.3K | 1760 | **1.00** |
| MS DataContract Json:.NET 8.0.28 | 566 | 142 | 424 | 17.2K | 22.7K | 1778 | **1.00** |
| MS XmlSerializer:.NET 8.0.28 | 530 | 203 | 326 | 13.2K | 51K | 1724 | **1.00** |
| NetJSON:1.0.0 | 188 | 76 | 112 | 44.4K | 19.3K | 1770 | **1.00** |
| NetSerializer:4.1.2 | 90.6 | 38 | 52.2 | 70.8K | 11.9K | 1816 | **1.00** |
| ProtoBuf:2.4.9.1 | 109 | 35.2 | 72.5 | 44.5K | 12.2K | 1746 | **1.00** |
| ServiceStack:6.11.0 | 318 | 141 | 177 | 31.8K | 17.2K | 1789 | **1.00** |
| ServiceStack Json:6.11.0 | 370 | 158 | 211 | 23K | 19.5K | 1778 | **1.00** |
| SharpSerializer | 2,260 | 527 | 1,720 | 6.44K | 107K | 1677 | **1.00** |
| SharpYaml:3.12.0 | 1,100 | 246 | 849 | 3.8K | 26.2K | 1753 | **1.00** |
| SpanJson:4.2.1 | 137 | 70.4 | 66.1 | 58.4K | 19.5K | 1785 | **1.00** |
| System.Text.Json:8.0.0.0 | 234 | 101 | 131 | 23.7K | 22.7K | 1795 | **1.00** |
| Utf8Json:1.3.7 | 174 | 69.3 | 104 | 35.1K | 19.5K | 1770 | **1.00** |
| YamlDotNet:17.1.0 | 4,310 | 2,270 | 2,010 | 2.77K | 21.8K | 1772 | **1.00** |
| YAXLib:4.4.0 | 1,690 | 823 | 840 | 1.81K | 50.8K | 1652 | **1.00** |
| ZeroFormatter:1.6.4 | 64.1 | 27.5 | 36.3 | 64.4K | 13.6K | 1767 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| BinaryPack:1.0.3 | 5.82 | 5.57 | **6.02** | **5.83** |
| Ceras:4.1.7 | 34.4 | 34.4 | 36.4 | 35.3 |
| CsvHelper:33.1.0 | 4,010 | 3,980 | 4,020 | 4,020 |
| ExtendedXmlSerializer:3.10.0.0 | 132 | 124 | 116 | 115 |
| fastJson:2.4.0.4 | 40 | 39 | 47.5 | 45.6 |
| FlatSharp:7.5.1 | 19.4 | 18.4 | 18.2 | 17.5 |
| FsPickler:5.3.2 | 34.1 | 32.9 | 37.4 | 34.4 |
| FsPicklerJson:5.3.2 | 45.6 | 44.1 | 40 | 38.9 |
| Google.Protobuf:3.35.1 | 11.9 | 11.3 | 10.4 | 10 |
| GroBuf:1.9.2 | 9.43 | 9.17 | 8.52 | 8.57 |
| Hyperion:0.12.2 | 16.4 | 15.3 | 15.4 | 14.7 |
| Jil:2.17.0 | 18.8 | 18.3 | 18.9 | 18.4 |
| Json.Net:13.0.4 | 16.4 | 16.5 | 18.9 | 18.8 |
| Json.Net (Helper):13.0.4 | 44 | 43.3 | 48.8 | 46.9 |
| MemoryPack | 11.1 | 10.7 | 11.4 | 11.1 |
| Migrant:0.13.0.0 | 120 | 113 | 110 | 109 |
| MS Binary:.NET 8.0.28 | 59.1 | 56.6 | 52.9 | 51.7 |
| MS Bond Compact:.NET 8.0.28 | 8.57 | 8.39 | 15.4 | 15 |
| MS Bond Fast:.NET 8.0.28 | **5.58** | **5.4** | 12.7 | 12.2 |
| MS Bond Json:.NET 8.0.28 | 21.6 | 21.3 | 23.5 | 22.5 |
| MS DataContract:.NET 8.0.28 | 68.6 | 65.3 | 64.6 | 60.9 |
| MS DataContract Json:.NET 8.0.28 | 43 | 41.2 | 42.1 | 40.5 |
| MS XmlSerializer:.NET 8.0.28 | 58.7 | 57.6 | 58.4 | 55.7 |
| NetJSON:1.0.0 | 15.1 | 15 | 18.5 | 17.7 |
| NetSerializer:4.1.2 | 8.1 | 7.82 | 7.52 | 7.14 |
| ProtoBuf:2.4.9.1 | 17.6 | 17.4 | 16.5 | 15.8 |
| ServiceStack:6.11.0 | 22.7 | 22.5 | 26.6 | 26 |
| ServiceStack Json:6.11.0 | 36.3 | 35.9 | 41 | 39.8 |
| SharpSerializer | 95.1 | 92.5 | 91.5 | 88.2 |
| SharpYaml:3.12.0 | 300 | 305 | 346 | 348 |
| SpanJson:4.2.1 | 10.9 | 10.2 | 12 | 11.5 |
| System.Text.Json:8.0.0.0 | 60 | 55.5 | 54.9 | 54 |
| Utf8Json:1.3.7 | 21.5 | 20.1 | 22.7 | 21 |
| YamlDotNet:17.1.0 | 303 | 293 | 308 | 303 |
| YAXLib:4.4.0 | 466 | 464 | 488 | 482 |
| ZeroFormatter:1.6.4 | 10 | 9.21 | 9.12 | 8.91 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| BinaryPack:1.0.3 | **180K** | 6.1K | **220K** | 7.2K | 170K | **15K** | 140K | 2.7K | **250K** | 9.6K |
| Ceras:4.1.7 | 37K | 3.5K | 44K | 4.5K | 29K | 6.9K | 46K | 2.8K | 36K | 5.6K |
| CsvHelper:33.1.0 | - | - | 0.47K | 0.37K | 0.25K | 0.22K | 1.3K | 0.83K | - | - |
| ExtendedXmlSerializer:3.10.0.0 | 17K | 4.7K | 21K | 5.9K | 7.6K | 3.3K | 24K | 4.8K | 19K | 3.7K |
| fastJson:2.4.0.4 | 30K | 0.94K | 45K | 1.9K | 25K | 1.5K | 68K | 2.5K | 31K | 0.76K |
| FlatSharp:7.5.1 | 65K | 4.5K | 79K | 6.4K | 52K | 6.5K | 90K | 3.2K | 78K | 7.7K |
| FsPickler:5.3.2 | 31K | 2.8K | 40K | 3.8K | 29K | 6.3K | 42K | 2.5K | 32K | 4.2K |
| FsPicklerJson:5.3.2 | 38K | 1.3K | 50K | 2.3K | 22K | 1.9K | 51K | 2K | 27K | 0.69K |
| Google.Protobuf:3.35.1 | 77K | 5K | 120K | 6.2K | 84K | 7K | 130K | 2.7K | 86K | 7.8K |
| GroBuf:1.9.2 | 130K | 5.4K | 160K | 7.5K | 110K | 12K | 180K | 4.2K | 180K | **11K** |
| Hyperion:0.12.2 | 57K | 3.1K | 70K | 4.7K | 61K | 5.8K | 75K | 2.2K | 59K | 2.8K |
| Jil:2.17.0 | 50K | 2.5K | 70K | 3.6K | 53K | 2.4K | 86K | 2.7K | 38K | 0.97K |
| Json.Net:13.0.4 | 64K | 1K | 120K | 2K | 61K | 1.2K | 140K | 2.2K | 59K | 0.79K |
| Json.Net (Helper):13.0.4 | 34K | 0.99K | 52K | 1.9K | 23K | 1.2K | 75K | 2.2K | 35K | 0.78K |
| MemoryPack | 110K | **7.8K** | 140K | **10K** | 90K | 12K | 110K | 3.6K | 87K | 10K |
| Migrant:0.13.0.0 | 17K | 4K | 20K | 5.8K | 8.4K | 4.6K | 21K | 4.4K | 16K | 3.1K |
| MS Binary:.NET 8.0.28 | 17K | 0.65K | 22K | 1.1K | 17K | 1.6K | 27K | 1.1K | 20K | 1.5K |
| MS Bond Compact:.NET 8.0.28 | 140K | 6.1K | 170K | 8.5K | 120K | 11K | 180K | 3.7K | 170K | 8.4K |
| MS Bond Fast:.NET 8.0.28 | 160K | 5.6K | 190K | 8.2K | **180K** | 11K | 200K | 3.8K | 230K | 8.5K |
| MS Bond Json:.NET 8.0.28 | 67K | 2.2K | 99K | 4.3K | 46K | 2.7K | 120K | 3.3K | 48K | 0.89K |
| MS DataContract:.NET 8.0.28 | 26K | 1K | 37K | 1.9K | 15K | 1.2K | 34K | 0.99K | 21K | 0.51K |
| MS DataContract Json:.NET 8.0.28 | 28K | 0.69K | 43K | 1.5K | 23K | 0.86K | 48K | 1K | 28K | 0.52K |
| MS XmlSerializer:.NET 8.0.28 | 25K | 0.85K | 35K | 1.6K | 17K | 1.3K | 32K | 0.87K | 23K | 0.6K |
| NetJSON:1.0.0 | 86K | 3.1K | 120K | 5.7K | 66K | 3.7K | 160K | 4K | 63K | 1.2K |
| NetSerializer:4.1.2 | 130K | 4.8K | 160K | 6.4K | 120K | 7.2K | 140K | 3.2K | 140K | 4.6K |
| ProtoBuf:2.4.9.1 | 74K | 4.3K | 100K | 5.1K | 57K | 6.2K | 88K | 2.4K | 100K | 5.6K |
| ServiceStack:6.11.0 | 54K | 1.5K | 81K | 2.8K | 44K | 1.4K | 140K | 2.8K | 38K | 0.87K |
| ServiceStack Json:6.11.0 | 40K | 1.2K | 60K | 2.2K | 28K | 1.2K | 98K | 2.1K | 29K | 0.83K |
| SharpSerializer | 9.7K | 0.13K | 15K | 0.25K | 11K | 0.24K | 17K | 0.25K | 11K | 0.17K |
| SharpYaml:3.12.0 | 5K | 0.34K | 7.3K | 0.68K | 3.3K | 0.31K | 15K | 0.62K | 7.6K | 0.35K |
| SpanJson:4.2.1 | 100K | 5.9K | 170K | 8.9K | 92K | 7.2K | **210K** | **4.9K** | 47K | 1.3K |
| System.Text.Json:8.0.0.0 | 45K | 2K | 63K | 3.6K | 17K | 2.5K | 84K | 2.7K | 33K | 1.2K |
| Utf8Json:1.3.7 | 64K | 5K | 94K | 6.7K | 47K | 2.5K | 100K | 3.7K | 42K | 1.3K |
| YamlDotNet:17.1.0 | 4.3K | 0.07K | 7.4K | 0.16K | 3.3K | 0.088K | 8.3K | 0.16K | 5.4K | 0.099K |
| YAXLib:4.4.0 | 3.2K | 0.21K | 4.3K | 0.39K | 2.1K | 0.36K | 6.5K | 0.41K | 3.6K | 0.25K |
| ZeroFormatter:1.6.4 | 100K | 7K | 120K | 9.3K | 100K | 10K | 170K | 3.8K | 100K | 8K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/csharp/2026-07-20-125719.csv`
    - run=2026-07-20-125719
    - language=csharp
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: dotnet=8.0.422, python=3.14.0, node=24.15.0
    - git=61a38cf dirty
    - seed=42
    - warmup_reps=1
    - serializers=36
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
      - `SharpYaml` @ 3.12.0
      - `SpanJson` @ 4.2.1
      - `System.Text.Json` @ 8.0.0.0
      - `Utf8Json` @ 1.3.7
      - `YAXLib` @ 4.4.0
      - `YamlDotNet` @ 17.1.0
      - `ZeroFormatter` @ 1.6.4
      - `fastJson` @ 2.4.0.4
