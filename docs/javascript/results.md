# JavaScript (Node.js) — Benchmark Results

**Generated:** 2026-07-24T19:44:47.912778

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
| @msgpack/msgpack:3.1.3 | 146 | 73.7 | 71.4 | 48.2K | 13.5K | 809 | **1.00** |
| avsc:5.7.9 | 370 | 204 | 165 | 36.9K | **9.02K** | 864 | **1.00** |
| bebop:3.2.3 | 140 | 53.6 | 85.6 | 71.3K | 19K | 822 | **1.00** |
| bser:2.1.1 | 329 | 176 | 152 | 26K | 16.4K | 845 | **1.00** |
| bson:6.10.4 | 203 | 100 | 102 | 38.9K | 20.3K | 847 | **1.00** |
| cbor:9.0.2 | 1,190 | 502 | 683 | 8.83K | 13.6K | 807 | **1.00** |
| cbor-x:1.6.4 | 98.4 | 50.5 | **47.2** | 44.5K | 10.3K | 830 | **1.00** |
| devalue:5.8.1 | 497 | 369 | 127 | 28.3K | 25.6K | 888 | **1.00** |
| fast-json-stringify:6.4.0 | 166 | 89.6 | 74.3 | 76.1K | 19.7K | 869 | **1.00** |
| flatbuffers:24.12.23 | 385 | 265 | 118 | 30.3K | 18.7K | 830 | **1.00** |
| flexbuffers:24.12.23 | 2,060 | 1,170 | 889 | 3.84K | 27.2K | 809 | **1.00** |
| google-protobuf:3.21.4 | **74** | **0.695** | 73.3 | 94.9K | 10.2K | 852 | **1.00** |
| json-pack-msgpack:18.28.0 | 97.8 | 49.4 | 48.2 | 75.1K | 14.1K | 789 | **1.00** |
| JSON.stringify:node-24.15.0 | 141 | 66.2 | 74.2 | **114K** | 19.7K | 905 | **1.00** |
| msgpackr:1.12.1 | 114 | 47.1 | 66 | 66.9K | 13.9K | 857 | **1.00** |
| protobuf-es:2.12.1 | 655 | 453 | 199 | 19K | 10.1K | 822 | **1.00** |
| protobufjs:7.6.5 | 189 | 88.1 | 99.6 | 33.4K | 10.2K | 845 | **1.00** |
| sia:2.3.0 | 479 | 326 | 153 | 37.3K | 19K | 834 | **1.00** |
| simdjson-parse+JSON.stringify:0.9.2 | 260 | 65.8 | 193 | 36.7K | 19.7K | 868 | **1.00** |
| v8-serializer:v8-13.6.233.17-node.48 | 118 | 45.1 | 73.1 | 50.3K | 15.3K | 839 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 18 | 16.2 | - | - |
| avsc:5.7.9 | 14.8 | 14.8 | - | - |
| bebop:3.2.3 | 9.14 | 9.28 | - | - |
| bser:2.1.1 | 30.5 | 27 | - | - |
| bson:6.10.4 | 17.1 | 18 | - | - |
| cbor:9.0.2 | 97.8 | 93 | - | - |
| cbor-x:1.6.4 | 14.9 | 14.4 | - | - |
| devalue:5.8.1 | 19 | 18.3 | - | - |
| fast-json-stringify:6.4.0 | 6.07 | 5.94 | - | - |
| flatbuffers:24.12.23 | 20.9 | 19.2 | - | - |
| flexbuffers:24.12.23 | 79.6 | 77.3 | - | - |
| google-protobuf:3.21.4 | 10.6 | 9.93 | - | - |
| json-pack-msgpack:18.28.0 | 13 | 13 | - | - |
| JSON.stringify:node-24.15.0 | **4.69** | **4.59** | - | - |
| msgpackr:1.12.1 | 13.5 | 12.4 | - | - |
| protobuf-es:2.12.1 | 33.8 | 33.2 | - | - |
| protobufjs:7.6.5 | 23 | 21.8 | - | - |
| sia:2.3.0 | 18.1 | 16.7 | - | - |
| simdjson-parse+JSON.stringify:0.9.2 | 13.7 | 12.7 | - | - |
| v8-serializer:v8-13.6.233.17-node.48 | 10.5 | 10.4 | - | - |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 65K | 2.6K | 150K | 3.8K | 56K | 7.7K | 130K | 2.2K | 65K | 5.9K |
| avsc:5.7.9 | 55K | 1.3K | 98K | 1.8K | 68K | 4.2K | 92K | 1K | 47K | 0.89K |
| bebop:3.2.3 | 100K | 2.4K | 180K | 3.9K | 110K | 7.1K | 160K | 2.5K | 140K | 6.5K |
| bser:2.1.1 | 48K | 0.92K | 67K | 1.5K | 33K | 3.3K | 74K | 1.4K | 29K | 1.6K |
| bson:6.10.4 | 48K | 1.5K | 100K | 2.6K | 58K | 5.5K | 89K | 2.3K | 74K | 3.3K |
| cbor:9.0.2 | 12K | 0.24K | 23K | 0.48K | 10K | 0.95K | 24K | 0.47K | 17K | 0.47K |
| cbor-x:1.6.4 | 46K | 4.1K | 79K | 5.5K | 67K | 15K | 140K | 3.4K | 75K | 7.4K |
| devalue:5.8.1 | 31K | 0.7K | 77K | 1.3K | 53K | 3K | 74K | 0.9K | 42K | 0.78K |
| fast-json-stringify:6.4.0 | 110K | 2.4K | 180K | 4.1K | 160K | 9.5K | 160K | 2.3K | 130K | 2.2K |
| flatbuffers:24.12.23 | 46K | 1.2K | 71K | 1.4K | 48K | 3.6K | 49K | 0.64K | 79K | 2.5K |
| flexbuffers:24.12.23 | 4.3K | 0.19K | 10K | 0.47K | 13K | 0.76K | 4.5K | 0.23K | 4.7K | 0.14K |
| google-protobuf:3.21.4 | 170K | **5.7K** | 260K | **8.8K** | 94K | **19K** | 240K | 4.3K | 140K | 6.6K |
| json-pack-msgpack:18.28.0 | 86K | 3.6K | 210K | 5.7K | 77K | 12K | 190K | 3.5K | **160K** | **8.1K** |
| JSON.stringify:node-24.15.0 | **180K** | 3.1K | **310K** | 5.1K | **210K** | 12K | **280K** | 3.1K | 130K | 2.1K |
| msgpackr:1.12.1 | 80K | 2.7K | 180K | 4.6K | 74K | 9.1K | 190K | 3.9K | 120K | 7.1K |
| protobuf-es:2.12.1 | 31K | 0.62K | 53K | 0.91K | 30K | 2.6K | 41K | 0.5K | 30K | 0.75K |
| protobufjs:7.6.5 | 43K | 1.9K | 73K | 3.3K | 43K | 7.8K | 110K | 1.8K | 50K | 3.4K |
| sia:2.3.0 | 50K | 0.61K | 83K | 1K | 55K | 2.3K | 67K | 0.78K | 110K | 2.5K |
| simdjson-parse+JSON.stringify:0.9.2 | 59K | 1.5K | 89K | 2.6K | 73K | 4.9K | 87K | 2K | 47K | 1.3K |
| v8-serializer:v8-13.6.233.17-node.48 | 69K | 2.4K | 100K | 4.1K | 95K | 11K | 120K | **4.8K** | 89K | 5.8K |

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
    
    - **Source CSV:** `logs/javascript/2026-07-24-193911.csv`
    - run=2026-07-24-193911
    - language=javascript
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: node=24.15.0, python=3.14.0, dotnet=9.0.316
    - git=7431b57 dirty
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
