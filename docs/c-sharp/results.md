# C# (.NET) — Benchmark Results

**Generated:** 2026-07-24T18:57:57.673919

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
| Apache.Avro:1.12.1 | 321 | 165 | 156 | 27.3K | 10.5K | 1696 | **1.00** |
| BinaryPack:1.0.3 | 73.5 | 33.4 | 39.7 | **99.2K** | 13.9K | 1753 | **1.00** |
| Ceras:4.1.7 | 117 | 41.4 | 75.6 | 21.8K | 11.4K | 1760 | **1.00** |
| CsvHelper:33.1.0 | 2,460 | 1,640 | 815 | 0.567K | **8.82K** | 1084 | **1.00** |
| ExtendedXmlSerializer:3.10.0.0 | 142 | 71.6 | 69.1 | 10.5K | 19.9K | 1767 | **1.00** |
| fastJson:2.4.0.4 | 393 | 137 | 254 | 18.7K | 22K | 1741 | **1.00** |
| FlatSharp:7.5.1 | 80.3 | 36.3 | 43.3 | 47.3K | 20.3K | 1763 | **1.00** |
| FsPickler:5.3.2 | 153 | 84.7 | 66.9 | 22.4K | 14.4K | 1768 | **1.00** |
| FsPicklerJson:5.3.2 | 355 | 147 | 207 | 13.1K | 25.5K | 1753 | **1.00** |
| Google.Protobuf:3.35.1 | 87.7 | 43.9 | 43.1 | 56.9K | 11.8K | 1763 | **1.00** |
| GroBuf:1.9.2 | **56.3** | **18.7** | 36.8 | 83.1K | 27.2K | 1732 | **1.00** |
| Hyperion:0.12.2 | 142 | 73.9 | 67.7 | 37.4K | 13.6K | 1835 | **1.00** |
| Jil:2.17.0 | 262 | 129 | 133 | 26.9K | 19.5K | 1767 | **1.00** |
| Json.Net:13.0.4 | 378 | 159 | 218 | 22.8K | 22.2K | 1774 | **1.00** |
| Json.Net (Helper):13.0.4 | 383 | 160 | 221 | 22K | 21.6K | 1753 | **1.00** |
| LightProto:1.3.4 | 91.9 | 46.4 | 44.4 | 59.2K | 12.2K | 1763 | **1.00** |
| MemoryPack | 60.2 | 26.4 | **33.4** | 59.2K | 16.6K | 1769 | **1.00** |
| Migrant:0.13.0.0 | 131 | 52.6 | 76.7 | 10.4K | 25.3K | 1803 | **1.00** |
| MS Binary:.NET 8.0.28 | 444 | 209 | 233 | 11.4K | 21.9K | 1756 | **1.00** |
| MS Bond Compact:.NET 8.0.28 | 70.8 | 32.7 | 37.5 | 62.3K | 11.4K | 1764 | **1.00** |
| MS Bond Fast:.NET 8.0.28 | 72.1 | 33.3 | 38.5 | 64.9K | 13.6K | 1769 | **1.00** |
| MS Bond Json:.NET 8.0.28 | 231 | 88.8 | 142 | 37.5K | 19.3K | 1764 | **1.00** |
| MS DataContract:.NET 8.0.28 | 492 | 155 | 338 | 14.7K | 48.3K | 1799 | **1.00** |
| MS DataContract Json:.NET 8.0.28 | 603 | 151 | 449 | 14.1K | 22.7K | 1788 | **1.00** |
| MS XmlSerializer:.NET 8.0.28 | 524 | 198 | 325 | 13.3K | 51K | 1772 | **1.00** |
| NetJSON:1.0.0 | 190 | 76.7 | 112 | 43.1K | 19.3K | 1765 | **1.00** |
| NetSerializer:4.1.2 | 91.1 | 37.7 | 52.7 | 74.2K | 11.9K | 1763 | **1.00** |
| ProtoBuf:2.4.9.1 | 107 | 34.7 | 71.6 | 47.5K | 12.2K | 1758 | **1.00** |
| ServiceStack:6.11.0 | 313 | 142 | 170 | 27.5K | 17.2K | 1758 | **1.00** |
| ServiceStack Json:6.11.0 | 368 | 153 | 214 | 23.8K | 19.5K | 1805 | **1.00** |
| SharpSerializer | 2,320 | 541 | 1,780 | 6.49K | 107K | 1705 | **1.00** |
| SharpYaml:3.13.0 | 1,130 | 259 | 867 | 3.55K | 26.2K | 1750 | **1.00** |
| SpanJson:4.2.1 | 137 | 69.3 | 66.6 | 57.2K | 19.5K | 1771 | **1.00** |
| System.Text.Json:8.0.0.0 | 234 | 99.9 | 134 | 24.2K | 22.7K | 1810 | **1.00** |
| Utf8Json:1.3.7 | 173 | 69.4 | 103 | 35.2K | 19.5K | 1746 | **1.00** |
| YamlDotNet:17.1.0 | 4,480 | 2,440 | 2,010 | 2.77K | 21.8K | 1762 | **1.00** |
| YAXLib:4.4.0 | 1,650 | 792 | 834 | 1.85K | 50.8K | 1550 | **1.00** |
| ZeroFormatter:1.6.4 | 63.2 | 26.8 | 36.3 | 74K | 13.6K | 1763 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| Apache.Avro:1.12.1 | 17.6 | 17 | 17 | 17.1 |
| BinaryPack:1.0.3 | **4.41** | **4.09** | **5.04** | **5.1** |
| Ceras:4.1.7 | 28.7 | 27.5 | 30.7 | 29.9 |
| CsvHelper:33.1.0 | 3,770 | 3,750 | 3,780 | 3,780 |
| ExtendedXmlSerializer:3.10.0.0 | 101 | 104 | 102 | 104 |
| fastJson:2.4.0.4 | 37.8 | 38 | 41.5 | 41.7 |
| FlatSharp:7.5.1 | 12.6 | 12.1 | 12.5 | 12.7 |
| FsPickler:5.3.2 | 26.5 | 26.6 | 26.1 | 26.6 |
| FsPicklerJson:5.3.2 | 59 | 57.6 | 58.7 | 58.6 |
| Google.Protobuf:3.35.1 | 9.73 | 9.74 | 9.06 | 8.93 |
| GroBuf:1.9.2 | 7.47 | 7.29 | 7.22 | 7.51 |
| Hyperion:0.12.2 | 13 | 12.7 | 12.3 | 12.2 |
| Jil:2.17.0 | 17.6 | 17 | 19.2 | 18.9 |
| Json.Net:13.0.4 | 35.4 | 35.5 | 37.5 | 37.8 |
| Json.Net (Helper):13.0.4 | 39 | 39 | 43.9 | 43.3 |
| LightProto:1.3.4 | 8.33 | 8.09 | 8.11 | 8.08 |
| MemoryPack | 9.29 | 9.08 | 10.1 | 9.91 |
| Migrant:0.13.0.0 | 99.1 | 96.5 | 101 | 100 |
| MS Binary:.NET 8.0.28 | 49.7 | 48.5 | 48.6 | 48.8 |
| MS Bond Compact:.NET 8.0.28 | 7.02 | 6.54 | 14.1 | 13.8 |
| MS Bond Fast:.NET 8.0.28 | 5.77 | 5.66 | 12 | 11.9 |
| MS Bond Json:.NET 8.0.28 | 17.7 | 17.8 | 20.8 | 20.7 |
| MS DataContract:.NET 8.0.28 | 47.2 | 45.7 | 44.7 | 44.6 |
| MS DataContract Json:.NET 8.0.28 | 53.3 | 53.1 | 49.8 | 47.7 |
| MS XmlSerializer:.NET 8.0.28 | 51.5 | 49.6 | 52.4 | 51.2 |
| NetJSON:1.0.0 | 13.6 | 13.6 | 16.5 | 16.8 |
| NetSerializer:4.1.2 | 6.99 | 6.99 | 6.21 | 6.14 |
| ProtoBuf:2.4.9.1 | 15.2 | 14.8 | 13.7 | 13.6 |
| ServiceStack:6.11.0 | 27.7 | 27.3 | 32.3 | 32.2 |
| ServiceStack Json:6.11.0 | 30.7 | 30.5 | 35.5 | 34.5 |
| SharpSerializer | 85.7 | 82.9 | 88.2 | 86.4 |
| SharpYaml:3.13.0 | 304 | 307 | 317 | 317 |
| SpanJson:4.2.1 | 8.59 | 8.54 | 10.3 | 9.93 |
| System.Text.Json:8.0.0.0 | 41.8 | 41.4 | 42.9 | 45.2 |
| Utf8Json:1.3.7 | 18.4 | 18 | 19.3 | 19.8 |
| YamlDotNet:17.1.0 | 262 | 255 | 284 | 273 |
| YAXLib:4.4.0 | 415 | 414 | 441 | 437 |
| ZeroFormatter:1.6.4 | 6.57 | 6.48 | 6.7 | 6.72 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| Apache.Avro:1.12.1 | 41K | 1.3K | 41K | 1.8K | 57K | 2K | 68K | 1.4K | 57K | 1.4K |
| BinaryPack:1.0.3 | **160K** | 6.5K | **140K** | 7K | **230K** | **14K** | 140K | 2.7K | **260K** | 10K |
| Ceras:4.1.7 | 33K | 3.5K | 29K | 5K | 35K | 6.9K | 46K | 2.8K | 41K | 5.7K |
| CsvHelper:33.1.0 | - | - | 0.4K | 0.39K | 0.27K | 0.22K | 1.3K | 0.88K | - | - |
| ExtendedXmlSerializer:3.10.0.0 | 15K | 4.7K | 12K | 6K | 9.9K | 3.4K | 22K | 4.8K | 21K | 3.9K |
| fastJson:2.4.0.4 | 28K | 0.91K | 29K | 1.9K | 26K | 1.6K | 67K | 2.5K | 33K | 0.78K |
| FlatSharp:7.5.1 | 60K | 4.8K | 51K | 6.6K | 79K | 6.2K | 91K | 3.3K | 94K | 8.4K |
| FsPickler:5.3.2 | 34K | 2.8K | 34K | 4K | 38K | 6.5K | 51K | 2.4K | 46K | 4.2K |
| FsPicklerJson:5.3.2 | 22K | 1.3K | 20K | 2.2K | 17K | 2K | 34K | 1.9K | 22K | 0.68K |
| Google.Protobuf:3.35.1 | 70K | 4.9K | 72K | 6.2K | 100K | 6.4K | 120K | 2.7K | 89K | 8K |
| GroBuf:1.9.2 | 110K | 5.2K | 110K | 8.1K | 130K | 12K | 180K | 4.5K | 190K | **11K** |
| Hyperion:0.12.2 | 55K | 3.1K | 47K | 4.6K | 77K | 5.6K | 74K | 2.2K | 68K | 2.7K |
| Jil:2.17.0 | 43K | 2.6K | 42K | 3.7K | 57K | 2.4K | 81K | 2.6K | 40K | 0.95K |
| Json.Net:13.0.4 | 36K | 1K | 40K | 2K | 28K | 1.2K | 76K | 2.1K | 40K | 0.78K |
| Json.Net (Helper):13.0.4 | 37K | 1K | 42K | 2K | 26K | 1.2K | 76K | 2.2K | 41K | 0.78K |
| LightProto:1.3.4 | 81K | 4.7K | 75K | 6.7K | 120K | 6.7K | 130K | 2.7K | 90K | 6.8K |
| MemoryPack | 93K | **8K** | 86K | **9.8K** | 110K | 11K | 110K | 3.6K | 100K | 10K |
| Migrant:0.13.0.0 | 15K | 3.9K | 11K | 5.7K | 10K | 4.5K | 19K | 4.1K | 17K | 3.1K |
| MS Binary:.NET 8.0.28 | 17K | 0.67K | 15K | 1.1K | 20K | 1.6K | 27K | 1.1K | 23K | 1.6K |
| MS Bond Compact:.NET 8.0.28 | 140K | 6.3K | 130K | 8.5K | 140K | 11K | 180K | 3.6K | 190K | 8.8K |
| MS Bond Fast:.NET 8.0.28 | 130K | 5.6K | 110K | 7.9K | 170K | 10K | 180K | 3.6K | 210K | 8.6K |
| MS Bond Json:.NET 8.0.28 | 68K | 2.3K | 77K | 4.4K | 56K | 4.5K | 120K | 3.2K | 49K | 0.9K |
| MS DataContract:.NET 8.0.28 | 26K | 1K | 24K | 1.9K | 21K | 1.1K | 35K | 0.97K | 23K | 0.51K |
| MS DataContract Json:.NET 8.0.28 | 23K | 0.68K | 23K | 1.4K | 19K | 0.76K | 40K | 1K | 24K | 0.51K |
| MS XmlSerializer:.NET 8.0.28 | 25K | 0.87K | 24K | 1.7K | 19K | 1.4K | 31K | 0.88K | 25K | 0.59K |
| NetJSON:1.0.0 | 79K | 3K | 75K | 5.9K | 74K | 3.8K | 150K | 3.9K | 66K | 1.2K |
| NetSerializer:4.1.2 | 120K | 4.9K | 96K | 6.5K | 140K | 7.1K | 140K | 3.1K | 150K | 4.8K |
| ProtoBuf:2.4.9.1 | 73K | 4.4K | 65K | 5.5K | 66K | 6.3K | 90K | 2.4K | 110K | 5.6K |
| ServiceStack:6.11.0 | 44K | 1.6K | 39K | 2.9K | 36K | 1.4K | 120K | 3K | 38K | 0.88K |
| ServiceStack Json:6.11.0 | 38K | 1.3K | 37K | 2.3K | 33K | 1.2K | 96K | 2.1K | 35K | 0.83K |
| SharpSerializer | 9.4K | 0.12K | 11K | 0.27K | 12K | 0.24K | 17K | 0.25K | 12K | 0.17K |
| SharpYaml:3.13.0 | 4.3K | 0.33K | 5K | 0.67K | 3.3K | 0.29K | 13K | 0.6K | 7.4K | 0.35K |
| SpanJson:4.2.1 | 95K | 5.9K | 110K | 9.4K | 120K | 7.2K | **200K** | **4.9K** | 47K | 1.3K |
| System.Text.Json:8.0.0.0 | 42K | 2.1K | 39K | 3.5K | 24K | 2.5K | 85K | 2.6K | 38K | 1.2K |
| Utf8Json:1.3.7 | 59K | 5.1K | 53K | 7.1K | 54K | 2.4K | 93K | 3.6K | 46K | 1.3K |
| YamlDotNet:17.1.0 | 4.1K | 0.066K | 4.9K | 0.14K | 3.8K | 0.14K | 8.1K | 0.15K | 5.8K | 0.096K |
| YAXLib:4.4.0 | 2.9K | 0.21K | 2.9K | 0.43K | 2.4K | 0.34K | 6.2K | 0.42K | 3.7K | 0.27K |
| ZeroFormatter:1.6.4 | 93K | 7.5K | 85K | 9.6K | 150K | 9.6K | 170K | 3.8K | 120K | 8.1K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/csharp/2026-07-24-183742.csv`
    - run=2026-07-24-183742
    - language=csharp
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: dotnet=9.0.316, python=3.14.0, node=24.15.0
    - git=85145fd dirty
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
