# C# (.NET) — Benchmark Results

**Generated:** 2026-07-24T19:43:31.757872

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

> **Stream honesty:** stream rows labeled as **native** 170, **text_on_stream** 150, **adapted** 56. Only **`native`** (and carefully **`text_on_stream`**) support stream-API performance claims. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| Apache.Avro:1.12.1 | 345 | 179 | 165 | 25.7K | 10.5K | 1649 | **1.00** |
| BinaryPack:1.0.3 | 75.7 | 34.5 | 40.5 | **87.5K** | 13.9K | 1779 | **1.00** |
| Ceras:4.1.7 | 121 | 43.1 | 77.9 | 20.8K | 11.4K | 1737 | **1.00** |
| CsvHelper:33.1.0 | 2,650 | 1,760 | 864 | 0.539K | **8.82K** | 1107 | **1.00** |
| ExtendedXmlSerializer:3.10.0.0 | 147 | 73.7 | 71.7 | 9.89K | 19.9K | 1750 | **1.00** |
| fastJson:2.4.0.4 | 395 | 138 | 257 | 18.4K | 22K | 1711 | **1.00** |
| FlatSharp:7.5.1 | 81.1 | 37.7 | 42.6 | 44.7K | 20.3K | 1741 | **1.00** |
| FsPickler:5.3.2 | 157 | 88 | 68.2 | 20.6K | 14.4K | 1791 | **1.00** |
| FsPicklerJson:5.3.2 | 364 | 153 | 210 | 12.4K | 25.5K | 1773 | **1.00** |
| Google.Protobuf:3.35.1 | 88.9 | 44.8 | 43.1 | 54.1K | 11.8K | 1751 | **1.00** |
| GroBuf:1.9.2 | **58.7** | **20.2** | 37.9 | 73K | 27.2K | 1762 | **1.00** |
| Hyperion:0.12.2 | 148 | 76 | 70.5 | 34.7K | 13.6K | 1784 | **1.00** |
| Jil:2.17.0 | 269 | 132 | 135 | 24.7K | 19.5K | 1756 | **1.00** |
| Json.Net:13.0.4 | 379 | 161 | 218 | 22.6K | 22.2K | 1717 | **1.00** |
| Json.Net (Helper):13.0.4 | 380 | 158 | 220 | 21.2K | 21.6K | 1714 | **1.00** |
| LightProto:1.3.4 | 94.1 | 47.1 | 45.6 | 53.4K | 12.2K | 1754 | **1.00** |
| MemoryPack | 61 | 26.9 | **33.7** | 57.7K | 16.6K | 1756 | **1.00** |
| Migrant:0.13.0.0 | 137 | 54.5 | 80.6 | 9.84K | 25.3K | 1792 | **1.00** |
| MS Binary:.NET 8.0.28 | 455 | 216 | 238 | 10.6K | 21.9K | 1726 | **1.00** |
| MS Bond Compact:.NET 8.0.28 | 71.8 | 33.7 | 37.8 | 58.5K | 11.4K | 1765 | **1.00** |
| MS Bond Fast:.NET 8.0.28 | 74.2 | 34.3 | 39 | 61.4K | 13.6K | 1734 | **1.00** |
| MS Bond Json:.NET 8.0.28 | 234 | 89.1 | 143 | 36.9K | 19.3K | 1745 | **1.00** |
| MS DataContract:.NET 8.0.28 | 489 | 155 | 330 | 14.4K | 48.3K | 1802 | **1.00** |
| MS DataContract Json:.NET 8.0.28 | 573 | 146 | 426 | 13.7K | 22.7K | 1764 | **1.00** |
| MS XmlSerializer:.NET 8.0.28 | 518 | 202 | 315 | 12.8K | 51K | 1774 | **1.00** |
| NetJSON:1.0.0 | 189 | 76.8 | 112 | 41.4K | 19.3K | 1782 | **1.00** |
| NetSerializer:4.1.2 | 92.8 | 38.8 | 53.4 | 69.5K | 11.9K | 1776 | **1.00** |
| ProtoBuf:2.4.9.1 | 109 | 35.9 | 72.7 | 44.8K | 12.2K | 1752 | **1.00** |
| ServiceStack:6.11.0 | 309 | 146 | 163 | 26K | 17.2K | 1744 | **1.00** |
| ServiceStack Json:6.11.0 | 371 | 159 | 211 | 22.9K | 19.5K | 1783 | **1.00** |
| SharpSerializer | 2,380 | 544 | 1,820 | 6.08K | 107K | 1720 | **1.00** |
| SharpYaml:3.13.0 | 1,120 | 257 | 856 | 3.38K | 26.2K | 1688 | **1.00** |
| SpanJson:4.2.1 | 139 | 70.4 | 67.1 | 55.1K | 19.5K | 1784 | **1.00** |
| System.Text.Json:8.0.0.0 | 239 | 103 | 135 | 23.8K | 22.7K | 1807 | **1.00** |
| Utf8Json:1.3.7 | 170 | 69.9 | 99.4 | 35K | 19.5K | 1745 | **1.00** |
| YamlDotNet:17.1.0 | 4,490 | 2,430 | 2,020 | 2.69K | 21.8K | 1717 | **1.00** |
| YAXLib:4.4.0 | 1,670 | 793 | 855 | 1.77K | 50.8K | 1619 | **1.00** |
| ZeroFormatter:1.6.4 | 65.2 | 28 | 36.5 | 69.8K | 13.6K | 1756 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| Apache.Avro:1.12.1 | 24.4 | 22.6 | 28.2 | 25.2 |
| BinaryPack:1.0.3 | **6.39** | **6.03** | **8.14** | **7.33** |
| Ceras:4.1.7 | 40.3 | 37 | 45.5 | 42.1 |
| CsvHelper:33.1.0 | 4,640 | 4,680 | 5,130 | 5,130 |
| ExtendedXmlSerializer:3.10.0.0 | 128 | 121 | 161 | 143 |
| fastJson:2.4.0.4 | 49.8 | 47.7 | 54.2 | 51.9 |
| FlatSharp:7.5.1 | 17.6 | 17 | 21.7 | 18.7 |
| FsPickler:5.3.2 | 44.8 | 41.6 | 42.3 | 40.5 |
| FsPicklerJson:5.3.2 | 90.4 | 79.1 | 85.8 | 82.6 |
| Google.Protobuf:3.35.1 | 13.8 | 12.1 | 12.9 | 12.4 |
| GroBuf:1.9.2 | 10.7 | 10.3 | 11.5 | 10.6 |
| Hyperion:0.12.2 | 18.4 | 16.6 | 16.4 | 15.9 |
| Jil:2.17.0 | 25.1 | 24 | 30 | 27.6 |
| Json.Net:13.0.4 | 47.9 | 44.3 | 52 | 49.6 |
| Json.Net (Helper):13.0.4 | 53.4 | 50 | 64.7 | 61.8 |
| LightProto:1.3.4 | 12.7 | 10.8 | 13.1 | 11.6 |
| MemoryPack | 15.4 | 13.3 | 15.3 | 13.9 |
| Migrant:0.13.0.0 | 148 | 138 | 161 | 148 |
| MS Binary:.NET 8.0.28 | 68.7 | 65.3 | 77.3 | 70.1 |
| MS Bond Compact:.NET 8.0.28 | 10.6 | 9.58 | 17.9 | 17.5 |
| MS Bond Fast:.NET 8.0.28 | 8.69 | 8.32 | 15.4 | 14.9 |
| MS Bond Json:.NET 8.0.28 | 25.6 | 24.5 | 29.6 | 28.7 |
| MS DataContract:.NET 8.0.28 | 78.7 | 71 | 73 | 69.5 |
| MS DataContract Json:.NET 8.0.28 | 71.8 | 68.9 | 75.4 | 75.7 |
| MS XmlSerializer:.NET 8.0.28 | 73.2 | 68.3 | 77.3 | 71.3 |
| NetJSON:1.0.0 | 18.6 | 17.1 | 23.6 | 21.9 |
| NetSerializer:4.1.2 | 10.1 | 8.93 | 9.45 | 8.36 |
| ProtoBuf:2.4.9.1 | 21.9 | 20 | 19.5 | 18.5 |
| ServiceStack:6.11.0 | 40.2 | 35.7 | 47.3 | 44.8 |
| ServiceStack Json:6.11.0 | 43.5 | 40.3 | 51.1 | 48.7 |
| SharpSerializer | 123 | 115 | 132 | 123 |
| SharpYaml:3.13.0 | 366 | 375 | 464 | 460 |
| SpanJson:4.2.1 | 13.4 | 11.9 | 15.9 | 14.7 |
| System.Text.Json:8.0.0.0 | 57.5 | 54.3 | 70.2 | 63.6 |
| Utf8Json:1.3.7 | 24.2 | 23.6 | 26.5 | 25.7 |
| YamlDotNet:17.1.0 | 338 | 331 | 420 | 406 |
| YAXLib:4.4.0 | 551 | 538 | 668 | 614 |
| ZeroFormatter:1.6.4 | 9.7 | 8.86 | 9.58 | 9.21 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| Apache.Avro:1.12.1 | 40K | 1.2K | 65K | 1.8K | 41K | 1.6K | 54K | 1.3K | 41K | 1.3K |
| BinaryPack:1.0.3 | **140K** | 6.4K | **210K** | 6.8K | **160K** | **15K** | 130K | 2.6K | **180K** | 9.4K |
| Ceras:4.1.7 | 34K | 3.4K | 52K | 4.7K | 25K | 7.1K | 39K | 2.7K | 30K | 5.5K |
| CsvHelper:33.1.0 | - | - | 0.47K | 0.4K | 0.22K | 0.22K | 1.1K | 0.85K | - | - |
| ExtendedXmlSerializer:3.10.0.0 | 14K | 4.7K | 23K | 6.2K | 7.8K | 3.4K | 18K | 4.4K | 16K | 3.8K |
| fastJson:2.4.0.4 | 27K | 0.91K | 49K | 1.9K | 20K | 1.6K | 60K | 2.5K | 28K | 0.76K |
| FlatSharp:7.5.1 | 55K | 4.8K | 98K | 6.6K | 57K | 6.7K | 81K | 3.2K | 68K | 7.9K |
| FsPickler:5.3.2 | 34K | 2.8K | 59K | 4K | 22K | 6.4K | 42K | 2.4K | 32K | 3.8K |
| FsPicklerJson:5.3.2 | 22K | 1.3K | 34K | 2.1K | 11K | 2K | 28K | 1.8K | 17K | 0.66K |
| Google.Protobuf:3.35.1 | 71K | 4.9K | 130K | 6.1K | 73K | 6.7K | 100K | 2.7K | 67K | 7.4K |
| GroBuf:1.9.2 | 100K | 5.1K | 180K | 7.9K | 93K | 13K | 150K | 4.2K | 140K | 9.6K |
| Hyperion:0.12.2 | 50K | 2.9K | 81K | 4.3K | 54K | 5.8K | 65K | 2.1K | 53K | 2.6K |
| Jil:2.17.0 | 39K | 2.5K | 71K | 3.7K | 40K | 2.3K | 62K | 2.6K | 33K | 0.95K |
| Json.Net:13.0.4 | 33K | 1K | 61K | 2K | 21K | 1.3K | 76K | 2.2K | 38K | 0.77K |
| Json.Net (Helper):13.0.4 | 36K | 1K | 60K | 2K | 19K | 1.4K | 68K | 2.2K | 34K | 0.78K |
| LightProto:1.3.4 | 74K | 5K | 120K | 6.4K | 79K | 6.9K | 110K | 2.6K | 67K | 6.6K |
| MemoryPack | 78K | **8.2K** | 160K | **9.9K** | 65K | 11K | 86K | 3.6K | 77K | **10K** |
| Migrant:0.13.0.0 | 13K | 3.9K | 20K | 5.6K | 6.7K | 4.4K | 16K | 4.1K | 14K | 2.9K |
| MS Binary:.NET 8.0.28 | 17K | 0.66K | 24K | 1.1K | 15K | 1.6K | 23K | 1.1K | 17K | 1.5K |
| MS Bond Compact:.NET 8.0.28 | 110K | 6.4K | 190K | 8.2K | 94K | 11K | 160K | 3.6K | 170K | 8.4K |
| MS Bond Fast:.NET 8.0.28 | 120K | 5.4K | 190K | 7.8K | 120K | 10K | 170K | 3.5K | 160K | 8.4K |
| MS Bond Json:.NET 8.0.28 | 66K | 2.4K | 110K | 4.6K | 39K | 5K | 110K | 3.2K | 46K | 0.9K |
| MS DataContract:.NET 8.0.28 | 26K | 1K | 42K | 1.9K | 13K | 1.2K | 31K | 0.97K | 19K | 0.51K |
| MS DataContract Json:.NET 8.0.28 | 22K | 0.67K | 38K | 1.4K | 14K | 0.87K | 34K | 0.97K | 22K | 0.51K |
| MS XmlSerializer:.NET 8.0.28 | 23K | 0.88K | 37K | 1.8K | 14K | 1.4K | 28K | 0.86K | 21K | 0.61K |
| NetJSON:1.0.0 | 61K | 3K | 130K | 5.8K | 54K | 4K | 120K | 3.8K | 55K | 1.3K |
| NetSerializer:4.1.2 | 98K | 4.7K | 170K | 6K | 99K | 7.7K | 130K | 3K | 120K | 4.6K |
| ProtoBuf:2.4.9.1 | 61K | 4.2K | 110K | 5.5K | 46K | 6.5K | 84K | 2.3K | 92K | 5.4K |
| ServiceStack:6.11.0 | 37K | 1.5K | 79K | 2.8K | 25K | 1.4K | 95K | 2.9K | 33K | 0.89K |
| ServiceStack Json:6.11.0 | 39K | 1.3K | 68K | 2.3K | 23K | 1.2K | 78K | 2K | 30K | 0.85K |
| SharpSerializer | 8.9K | 0.12K | 15K | 0.27K | 8.1K | 0.22K | 15K | 0.24K | 10K | 0.16K |
| SharpYaml:3.13.0 | 4.2K | 0.34K | 6.4K | 0.69K | 2.7K | 0.67K | 12K | 0.6K | 6.7K | 0.34K |
| SpanJson:4.2.1 | 91K | 5.9K | 170K | 9.4K | 75K | 7.5K | **180K** | **4.8K** | 45K | 1.3K |
| System.Text.Json:8.0.0.0 | 36K | 2K | 77K | 3.4K | 17K | 2.6K | 71K | 2.6K | 29K | 1.2K |
| Utf8Json:1.3.7 | 57K | 4.9K | 100K | 6.8K | 41K | 2.7K | 82K | 3.5K | 37K | 1.3K |
| YamlDotNet:17.1.0 | 3.9K | 0.066K | 7.5K | 0.15K | 3K | 0.17K | 7.2K | 0.15K | 4.8K | 0.096K |
| YAXLib:4.4.0 | 2.6K | 0.22K | 4.2K | 0.43K | 1.8K | 0.37K | 5.5K | 0.39K | 3.1K | 0.26K |
| ZeroFormatter:1.6.4 | 89K | 7.2K | 140K | 9.2K | 100K | 10K | 160K | 3.6K | 83K | 8K |

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
    
    - **Source CSV:** `logs/csharp/2026-07-24-193224.csv`
    - run=2026-07-24-193224
    - language=csharp
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: dotnet=9.0.316, python=3.14.0, node=24.15.0
    - git=7431b57
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
