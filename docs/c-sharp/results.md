# C# (.NET) — Benchmark Results

**Generated:** 2026-07-29T20:52:48.197302

This page is a **snapshot of measured numbers** for C# (.NET) on **one machine, one session** (claim level **L1**). Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little. Stronger multi-session / multi-machine claims need more evidence — see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [C# (.NET) overview](index.md) |
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

> **Stream honesty:** stream rows labeled as **native** 170, **text_on_stream** 150, **adapted** 56. Only **`native`** (and carefully **`text_on_stream`**) support stream-API performance claims. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) |
|---|---|---|---|---|---|
| Apache.Avro:1.12.1 | 321 | 163 | 156 | 29.5K | 10.5K |
| BinaryPack:1.0.3 | 74.5 | 33 | 41.1 | **105K** | 13.9K |
| Ceras:4.1.7 | 113 | 40.4 | 72.3 | 24.9K | 11.4K |
| CsvHelper:33.1.0 | 2,360 | 1,570 | 785 | 0.585K | **8.82K** |
| ExtendedXmlSerializer:3.10.0.0 | 132 | 67.2 | 64.8 | 12.1K | 19.9K |
| fastJson:2.4.0.4 | 393 | 136 | 254 | 20.7K | 22K |
| FlatSharp:7.5.1 | 76.3 | 34.6 | 41 | 53K | 20.3K |
| FsPickler:5.3.2 | 150 | 82.8 | 66.7 | 25.4K | 14.4K |
| FsPicklerJson:5.3.2 | 355 | 149 | 205 | 14.8K | 25.5K |
| Google.Protobuf:3.35.1 | 84.9 | 43 | 41.3 | 65.6K | 11.8K |
| GroBuf:1.9.2 | **54.7** | **18** | 36.3 | 91K | 27.2K |
| Hyperion:0.12.2 | 139 | 72.5 | 65.8 | 40.4K | 13.6K |
| Jil:2.17.0 | 259 | 126 | 131 | 29.9K | 19.5K |
| Json.Net:13.0.4 | 372 | 157 | 214 | 24.6K | 22.2K |
| Json.Net (Helper):13.0.4 | 373 | 155 | 217 | 24K | 21.6K |
| LightProto:1.3.4 | 89.3 | 44.3 | 43.8 | 63.1K | 12.2K |
| MemoryPack | 57.5 | 24.8 | **32.3** | 68.8K | 16.6K |
| Migrant:0.13.0.0 | 123 | 50.5 | 71.4 | 11.5K | 25.3K |
| MS Binary:.NET 8.0.28 | 436 | 208 | 226 | 12.4K | 21.9K |
| MS Bond Compact:.NET 8.0.28 | 68.2 | 31.4 | 36.5 | 71.1K | 11.4K |
| MS Bond Fast:.NET 8.0.28 | 70.4 | 32.1 | 38 | 72.6K | 13.6K |
| MS Bond Json:.NET 8.0.28 | 231 | 88.2 | 143 | 41.2K | 19.3K |
| MS DataContract:.NET 8.0.28 | 466 | 146 | 317 | 16.5K | 48.3K |
| MS DataContract Json:.NET 8.0.28 | 573 | 146 | 425 | 15.4K | 22.7K |
| MS XmlSerializer:.NET 8.0.28 | 515 | 195 | 319 | 14.4K | 51K |
| NetJSON:1.0.0 | 187 | 75.6 | 111 | 48.2K | 19.3K |
| NetSerializer:4.1.2 | 90.9 | 38.1 | 51.7 | 82.8K | 11.9K |
| ProtoBuf:2.4.9.1 | 104 | 32.9 | 70.4 | 52K | 12.2K |
| ServiceStack:6.11.0 | 315 | 142 | 170 | 30.7K | 17.2K |
| ServiceStack Json:6.11.0 | 363 | 155 | 207 | 25.7K | 19.5K |
| SharpSerializer | 2,230 | 518 | 1,700 | 6.92K | 107K |
| SharpYaml:3.13.0 | 1,100 | 252 | 851 | 3.72K | 26.2K |
| SpanJson:4.2.1 | 136 | 68.5 | 66.8 | 62.5K | 19.5K |
| System.Text.Json:8.0.0.0 | 230 | 97.7 | 130 | 27.4K | 22.7K |
| Utf8Json:1.3.7 | 169 | 66.9 | 101 | 39.4K | 19.5K |
| YamlDotNet:17.1.0 | 4,630 | 2,530 | 2,070 | 2.98K | 21.8K |
| YAXLib:4.4.0 | 1,560 | 737 | 806 | 2.01K | 50.8K |
| ZeroFormatter:1.6.4 | 61.1 | 26.1 | 34.5 | 82.2K | 13.6K |


### Total Time

| serializer | bytes mode/mean (µs) | bytes mode/median (µs) | stream mode/mean (µs) | stream mode/median (µs) |
|---|---|---|---|---|
| Apache.Avro:1.12.1 | 18.7 | 18.3 | 18.8 | 18.4 |
| BinaryPack:1.0.3 | **4.68** | **4.59** | **5.7** | **5.46** |
| Ceras:4.1.7 | 30.6 | 29.5 | 33.6 | 31.9 |
| CsvHelper:33.1.0 | 3,750 | 3,730 | 3,730 | 3,700 |
| ExtendedXmlSerializer:3.10.0.0 | 107 | 103 | 115 | 112 |
| fastJson:2.4.0.4 | 38.3 | 36.6 | 41.1 | 40.8 |
| FlatSharp:7.5.1 | 13.4 | 12.3 | 13.2 | 13.1 |
| FsPickler:5.3.2 | 29.7 | 28 | 28.7 | 27.2 |
| FsPicklerJson:5.3.2 | 59.8 | 60 | 58.6 | 56 |
| Google.Protobuf:3.35.1 | 9.89 | 9.85 | 9.82 | 9.65 |
| GroBuf:1.9.2 | 8.25 | 7.99 | 8.18 | 8.1 |
| Hyperion:0.12.2 | 14.6 | 13.9 | 14 | 13.5 |
| Jil:2.17.0 | 18.1 | 17.3 | 19 | 18.5 |
| Json.Net:13.0.4 | 36.4 | 34.8 | 35.9 | 35.6 |
| Json.Net (Helper):13.0.4 | 39.9 | 38.8 | 44.6 | 42.7 |
| LightProto:1.3.4 | 8.78 | 8.52 | 8.9 | 8.53 |
| MemoryPack | 10.4 | 9.85 | 10.5 | 10.6 |
| Migrant:0.13.0.0 | 107 | 103 | 110 | 107 |
| MS Binary:.NET 8.0.28 | 53.7 | 52.6 | 50.5 | 49.2 |
| MS Bond Compact:.NET 8.0.28 | 7.03 | 6.52 | 15.3 | 14.8 |
| MS Bond Fast:.NET 8.0.28 | 5.92 | 5.71 | 13.3 | 12.8 |
| MS Bond Json:.NET 8.0.28 | 17.5 | 17.3 | 19.4 | 18.9 |
| MS DataContract:.NET 8.0.28 | 50.8 | 50.2 | 48.1 | 46.2 |
| MS DataContract Json:.NET 8.0.28 | 55.7 | 54.7 | 54.7 | 53.6 |
| MS XmlSerializer:.NET 8.0.28 | 55.5 | 53.1 | 57.9 | 55.8 |
| NetJSON:1.0.0 | 14.6 | 14 | 17.6 | 17.1 |
| NetSerializer:4.1.2 | 7.27 | 7.06 | 6.19 | 5.94 |
| ProtoBuf:2.4.9.1 | 15.7 | 15.5 | 15 | 14.6 |
| ServiceStack:6.11.0 | 29.1 | 28.2 | 34.1 | 32.9 |
| ServiceStack Json:6.11.0 | 32.7 | 31.4 | 35.2 | 34.5 |
| SharpSerializer | 94.4 | 88.1 | 95.7 | 92.2 |
| SharpYaml:3.13.0 | 303 | 308 | 331 | 327 |
| SpanJson:4.2.1 | 9.72 | 9.3 | 11.4 | 10.7 |
| System.Text.Json:8.0.0.0 | 43.2 | 43 | 45.1 | 44.3 |
| Utf8Json:1.3.7 | 20.4 | 19.7 | 21.1 | 20.7 |
| YamlDotNet:17.1.0 | 276 | 269 | 289 | 286 |
| YAXLib:4.4.0 | 409 | 398 | 455 | 451 |
| ZeroFormatter:1.6.4 | 7.04 | 6.85 | 7.29 | 7.1 |


### Ops/Sec

| serializer | Average | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Apache.Avro:1.12.1 | 30K | 49K | 1.3K | 64K | 1.8K | 54K | 1.8K | 68K | 1.4K | 58K | 1.4K |
| BinaryPack:1.0.3 | **110K** | **190K** | 6.4K | **210K** | 6.8K | **210K** | **15K** | 140K | 2.7K | **280K** | 10K |
| Ceras:4.1.7 | 25K | 44K | 3.5K | 51K | 5K | 33K | 7.6K | 49K | 2.9K | 48K | 5.8K |
| CsvHelper:33.1.0 | 0.59K | - | - | 0.47K | 0.39K | 0.27K | 0.23K | 1.3K | 0.87K | - | - |
| ExtendedXmlSerializer:3.10.0.0 | 12K | 20K | 5K | 23K | 6.3K | 9.3K | 3.6K | 24K | 4.9K | 24K | 4K |
| fastJson:2.4.0.4 | 22K | 32K | 0.91K | 49K | 2K | 26K | 1.6K | 69K | 2.6K | 35K | 0.78K |
| FlatSharp:7.5.1 | 47K | 78K | 5.3K | 91K | 6.7K | 75K | 6.9K | 89K | 3.3K | 100K | 8.4K |
| FsPickler:5.3.2 | 26K | 47K | 2.9K | 56K | 4K | 34K | 6.6K | 55K | 2.4K | 52K | 4.2K |
| FsPicklerJson:5.3.2 | 15K | 28K | 1.3K | 34K | 2.1K | 17K | 1.8K | 36K | 1.8K | 24K | 0.68K |
| Google.Protobuf:3.35.1 | 59K | 90K | 5.1K | 130K | 6.2K | 100K | 7K | 130K | 2.7K | 110K | 7.9K |
| GroBuf:1.9.2 | 87K | 130K | 5.4K | 170K | 7.8K | 120K | 13K | 190K | 4.4K | 220K | 11K |
| Hyperion:0.12.2 | 38K | 69K | 3.2K | 80K | 4.6K | 69K | 5.9K | 76K | 2.2K | 70K | 2.8K |
| Jil:2.17.0 | 32K | 53K | 2.6K | 68K | 3.8K | 55K | 2.5K | 83K | 2.6K | 44K | 0.96K |
| Json.Net:13.0.4 | 25K | 41K | 1.1K | 59K | 2K | 27K | 1.2K | 79K | 2.2K | 41K | 0.79K |
| Json.Net (Helper):13.0.4 | 25K | 42K | 1.1K | 60K | 2K | 25K | 1.2K | 78K | 2.2K | 41K | 0.78K |
| LightProto:1.3.4 | 58K | 93K | 5.2K | 120K | 6.5K | 110K | 6.9K | 130K | 2.7K | 98K | 6.7K |
| MemoryPack | 64K | 120K | **8.5K** | 150K | **9.9K** | 96K | 11K | 110K | 3.6K | 120K | **11K** |
| Migrant:0.13.0.0 | 11K | 18K | 4.2K | 19K | 5.6K | 9.4K | 4.8K | 20K | 4.4K | 18K | 3.1K |
| MS Binary:.NET 8.0.28 | 12K | 19K | 0.69K | 23K | 1.1K | 19K | 1.6K | 27K | 1.1K | 25K | 1.6K |
| MS Bond Compact:.NET 8.0.28 | 95K | 160K | 6.6K | 200K | 8.3K | 140K | 11K | 190K | 3.7K | 220K | 9K |
| MS Bond Fast:.NET 8.0.28 | 97K | 160K | 5.7K | 190K | 7.8K | 170K | 11K | 190K | 3.7K | 220K | 8.7K |
| MS Bond Json:.NET 8.0.28 | 44K | 79K | 2.4K | 110K | 4.7K | 57K | 2.9K | 130K | 3.3K | 51K | 0.91K |
| MS DataContract:.NET 8.0.28 | 16K | 32K | 1.1K | 41K | 2K | 20K | 1.2K | 36K | 1K | 25K | 0.53K |
| MS DataContract Json:.NET 8.0.28 | 15K | 26K | 0.7K | 37K | 1.5K | 18K | 0.85K | 40K | 1K | 26K | 0.53K |
| MS XmlSerializer:.NET 8.0.28 | 14K | 28K | 0.89K | 36K | 1.7K | 18K | 1.4K | 31K | 0.89K | 26K | 0.62K |
| NetJSON:1.0.0 | 53K | 88K | 3.2K | 140K | 6K | 69K | 3.8K | 150K | 4K | 70K | 1.2K |
| NetSerializer:4.1.2 | 77K | 140K | 4.9K | 170K | 6.2K | 140K | 7.3K | 140K | 3.2K | 160K | 4.7K |
| ProtoBuf:2.4.9.1 | 50K | 84K | 4.5K | 100K | 5.5K | 64K | 6.5K | 92K | 2.4K | 130K | 5.7K |
| ServiceStack:6.11.0 | 34K | 55K | 1.5K | 77K | 2.9K | 34K | 1.4K | 120K | 3K | 39K | 0.89K |
| ServiceStack Json:6.11.0 | 28K | 46K | 1.3K | 65K | 2.3K | 31K | 1.2K | 92K | 2.1K | 37K | 0.85K |
| SharpSerializer | 6.8K | 11K | 0.13K | 16K | 0.28K | 11K | 0.23K | 17K | 0.26K | 13K | 0.18K |
| SharpYaml:3.13.0 | 3.8K | 4.6K | 0.35K | 6.4K | 0.69K | 3.3K | 0.29K | 14K | 0.61K | 7.6K | 0.35K |
| SpanJson:4.2.1 | 67K | 110K | 6.3K | 170K | 9.7K | 100K | 7.5K | **210K** | **5.2K** | 50K | 1.3K |
| System.Text.Json:8.0.0.0 | 29K | 51K | 2.1K | 68K | 3.5K | 23K | 2.5K | 88K | 2.7K | 43K | 1.2K |
| Utf8Json:1.3.7 | 39K | 76K | 5.2K | 97K | 7K | 49K | 2.6K | 96K | 3.7K | 50K | 1.3K |
| YamlDotNet:17.1.0 | 3K | 4.5K | 0.067K | 7.4K | 0.14K | 3.6K | 0.083K | 8.3K | 0.15K | 6.1K | 0.096K |
| YAXLib:4.4.0 | 2.2K | 3.2K | 0.24K | 4.2K | 0.43K | 2.4K | 0.35K | 6.4K | 0.44K | 3.9K | 0.28K |
| ZeroFormatter:1.6.4 | 75K | 120K | 7.8K | 140K | 9.7K | 140K | 10K | 180K | 3.8K | 130K | 8K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/csharp/2026-07-24-201328.csv`
    - run=2026-07-24-201328
    - language=csharp
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: dotnet=9.0.316, python=3.14.0, node=24.15.0
    - git=40f6a8e
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
