# JavaScript (Node.js) — Benchmark Results

**Generated:** 2026-07-24T20:24:02.082588

This page is a **snapshot of measured numbers** for JavaScript (Node.js) on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [JavaScript (Node.js) overview](index.md) |
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

> **Stream I/O:** not measured for this language snapshot (no stream-mode rows). See [Modes](../analysis/modes.md).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 146 | 74 | 71.4 | 47.1K | 13.5K | 827 | **1.00** |
| avsc:5.7.9 | 374 | 208 | 166 | 36.1K | **9.02K** | 870 | **1.00** |
| bebop:3.2.3 | 141 | 53.4 | 87.2 | 70.3K | 19K | 841 | **1.00** |
| bser:2.1.1 | 328 | 174 | 151 | 24.7K | 16.4K | 869 | **1.00** |
| bson:6.10.4 | 204 | 99.3 | 103 | 37.2K | 20.3K | 837 | **1.00** |
| cbor:9.0.2 | 1,220 | 516 | 702 | 8.49K | 13.6K | 836 | **1.00** |
| cbor-x:1.6.4 | 97.3 | 50.3 | **46.4** | 44.9K | 10.3K | 840 | **1.00** |
| devalue:5.8.1 | 490 | 357 | 130 | 25.3K | 25.6K | 884 | **1.00** |
| fast-json-stringify:6.4.0 | 167 | 91.2 | 74.9 | 73.5K | 19.7K | 886 | **1.00** |
| flatbuffers:24.12.23 | 391 | 274 | 114 | 24.4K | 18.7K | 847 | **1.00** |
| flexbuffers:24.12.23 | 2,090 | 1,190 | 884 | 3.37K | 27.2K | 856 | **1.00** |
| google-protobuf:3.21.4 | **73.4** | **0.684** | 72.6 | 90.8K | 10.2K | 870 | **1.00** |
| json-pack-msgpack:18.28.0 | 98 | 49.2 | 48.2 | 74.4K | 14.1K | 796 | **1.00** |
| JSON.stringify:node-24.15.0 | 142 | 66.9 | 74.3 | **111K** | 19.7K | 896 | **1.00** |
| msgpackr:1.12.1 | 113 | 47.5 | 65.5 | 65K | 13.9K | 844 | **1.00** |
| protobuf-es:2.12.1 | 662 | 457 | 203 | 17.5K | 10.1K | 839 | **1.00** |
| protobufjs:7.6.5 | 189 | 86 | 101 | 29.7K | 10.2K | 845 | **1.00** |
| sia:2.3.0 | 476 | 322 | 152 | 37.5K | 19K | 851 | **1.00** |
| simdjson-parse+JSON.stringify:0.9.2 | 262 | 66.2 | 195 | 35.8K | 19.7K | 882 | **1.00** |
| v8-serializer:v8-13.6.233.17-node.48 | 118 | 44.8 | 73 | 50.6K | 15.3K | 798 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 18 | 16 | - | - |
| avsc:5.7.9 | 15.1 | 15.1 | - | - |
| bebop:3.2.3 | 9.33 | 9.32 | - | - |
| bser:2.1.1 | 31.1 | 28.8 | - | - |
| bson:6.10.4 | 17.5 | 17.5 | - | - |
| cbor:9.0.2 | 97.2 | 94 | - | - |
| cbor-x:1.6.4 | 15.8 | 15 | - | - |
| devalue:5.8.1 | 19.1 | 19.5 | - | - |
| fast-json-stringify:6.4.0 | 6.53 | 6.15 | - | - |
| flatbuffers:24.12.23 | 22 | 20.1 | - | - |
| flexbuffers:24.12.23 | 79.3 | 76.1 | - | - |
| google-protobuf:3.21.4 | 10.6 | 10.3 | - | - |
| json-pack-msgpack:18.28.0 | 13.2 | 13.2 | - | - |
| JSON.stringify:node-24.15.0 | **4.85** | **4.54** | - | - |
| msgpackr:1.12.1 | 13.7 | 12.7 | - | - |
| protobuf-es:2.12.1 | 34.1 | 33.4 | - | - |
| protobufjs:7.6.5 | 23.1 | 22 | - | - |
| sia:2.3.0 | 18 | 16.3 | - | - |
| simdjson-parse+JSON.stringify:0.9.2 | 14.3 | 13.2 | - | - |
| v8-serializer:v8-13.6.233.17-node.48 | 10.5 | 10.4 | - | - |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 62K | 2.5K | 140K | 3.9K | 55K | 7.8K | 130K | 2.2K | 60K | 5.6K |
| avsc:5.7.9 | 56K | 1.2K | 93K | 1.9K | 66K | 4.2K | 90K | 1K | 46K | 0.88K |
| bebop:3.2.3 | 100K | 2.3K | 180K | 3.8K | 110K | 7.1K | 160K | 2.5K | 140K | 6.3K |
| bser:2.1.1 | 47K | 0.93K | 61K | 1.5K | 32K | 3.3K | 72K | 1.4K | 26K | 1.6K |
| bson:6.10.4 | 44K | 1.5K | 100K | 2.6K | 57K | 5.7K | 86K | 2.3K | 70K | 3.2K |
| cbor:9.0.2 | 12K | 0.22K | 21K | 0.48K | 10K | 0.94K | 23K | 0.46K | 16K | 0.45K |
| cbor-x:1.6.4 | 47K | 4K | 83K | 5.5K | 63K | 15K | 150K | 3.4K | 73K | 7K |
| devalue:5.8.1 | 31K | 0.68K | 55K | 1.3K | 52K | 3K | 75K | 0.93K | 32K | 0.81K |
| fast-json-stringify:6.4.0 | 110K | 2.2K | 170K | 4.2K | 150K | 9.7K | 160K | 2.3K | 120K | 2.2K |
| flatbuffers:24.12.23 | 46K | 1.2K | 55K | 1.4K | 45K | 3.6K | 50K | 0.65K | 40K | 2.3K |
| flexbuffers:24.12.23 | 4K | 0.18K | 5.7K | 0.47K | 13K | 0.76K | 5K | 0.24K | 4.6K | 0.14K |
| google-protobuf:3.21.4 | 160K | **5.6K** | 250K | **8.5K** | 94K | **19K** | 230K | 4.4K | 130K | 6.5K |
| json-pack-msgpack:18.28.0 | 81K | 3.6K | 210K | 5.9K | 76K | 12K | 190K | 3.5K | **150K** | **7.9K** |
| JSON.stringify:node-24.15.0 | **170K** | 3K | **290K** | 5K | **210K** | 12K | **280K** | 3.4K | 130K | 2K |
| msgpackr:1.12.1 | 78K | 2.6K | 170K | 4.7K | 73K | 9.1K | 180K | 3.9K | 120K | 7K |
| protobuf-es:2.12.1 | 29K | 0.59K | 50K | 0.9K | 29K | 2.5K | 40K | 0.49K | 21K | 0.74K |
| protobufjs:7.6.5 | 41K | 1.8K | 64K | 3.2K | 43K | 8K | 90K | 1.8K | 40K | 3.3K |
| sia:2.3.0 | 50K | 0.61K | 81K | 1K | 56K | 2.3K | 71K | 0.81K | 110K | 2.4K |
| simdjson-parse+JSON.stringify:0.9.2 | 57K | 1.4K | 85K | 2.6K | 70K | 4.9K | 88K | 2K | 46K | 1.3K |
| v8-serializer:v8-13.6.233.17-node.48 | 69K | 2.3K | 99K | 4.1K | 95K | 11K | 120K | **4.8K** | 91K | 5.8K |

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one **data type** (and batch size):

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that data type so the picture stays readable. Tables above still list everyone.
- Each image also prints the data type, source CSV, modes, and sample size.

### Document · 1 instance

![Document · 1 instance](../analysis/plots/violin/javascript_document@n=1.png){ width="80%" }

### Document · 100 instances

![Document · 100 instances](../analysis/plots/violin/javascript_document@n=100.png){ width="80%" }

### Event · 1 instance

![Event · 1 instance](../analysis/plots/violin/javascript_event@n=1.png){ width="80%" }

### Event · 100 instances

![Event · 100 instances](../analysis/plots/violin/javascript_event@n=100.png){ width="80%" }

### Message · 1 instance

![Message · 1 instance](../analysis/plots/violin/javascript_message@n=1.png){ width="80%" }

### Message · 100 instances

![Message · 100 instances](../analysis/plots/violin/javascript_message@n=100.png){ width="80%" }

### Strings · 1 instance

![Strings · 1 instance](../analysis/plots/violin/javascript_strings@n=1.png){ width="80%" }

### Strings · 100 instances

![Strings · 100 instances](../analysis/plots/violin/javascript_strings@n=100.png){ width="80%" }

### Telemetry · 1 instance

![Telemetry · 1 instance](../analysis/plots/violin/javascript_telemetry@n=1.png){ width="80%" }

### Telemetry · 100 instances

![Telemetry · 100 instances](../analysis/plots/violin/javascript_telemetry@n=100.png){ width="80%" }

## How to regenerate this page

Snapshots are produced on a developer machine. After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l javascript   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.
    
    - **Source CSV:** `logs/javascript/2026-07-24-201952.csv`
    - run=2026-07-24-201952
    - language=javascript
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: node=24.15.0, python=3.14.0, dotnet=9.0.316
    - git=40f6a8e dirty
    - seed=42
    - warmup_reps=1
    - serializers=20
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `@msgpack/msgpack` @ 3.1.3
      - `JSON.stringify` @ node-24.15.0
      - `avsc` @ 5.7.9
      - `bebop` @ 3.2.3
      - `bser` @ 2.1.1
      - `bson` @ 6.10.4
      - `cbor` @ 9.0.2
      - `cbor-x` @ 1.6.4
      - `devalue` @ 5.8.1
      - `fast-json-stringify` @ 6.4.0
      - `flatbuffers` @ 24.12.23
      - `flexbuffers` @ 24.12.23
      - `google-protobuf` @ 3.21.4
      - `json-pack-msgpack` @ 18.28.0
      - `msgpackr` @ 1.12.1
      - `protobuf-es` @ 2.12.1
      - `protobufjs` @ 7.6.5
      - `sia` @ 2.3.0
      - `simdjson-parse+JSON.stringify` @ 0.9.2
      - `v8-serializer` @ v8-13.6.233.17-node.48
