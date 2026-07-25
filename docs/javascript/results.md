# JavaScript (Node.js) — Benchmark Results

**Generated:** 2026-07-24T18:57:57.708272

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

## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 147 | 74.4 | 71.7 | 53.9K | 13.5K | 1660 | **1.00** |
| avsc:5.7.9 | 375 | 210 | 164 | 39.2K | **9.02K** | 1759 | **1.00** |
| bebop:3.2.3 | 140 | 54 | 85.8 | 78.7K | 19K | 1680 | **1.00** |
| bser:2.1.1 | 323 | 173 | 148 | 28.4K | 16.4K | 1706 | **1.00** |
| bson:6.10.4 | 206 | 101 | 104 | 43.8K | 20.3K | 1693 | **1.00** |
| cbor:9.0.2 | 1,210 | 517 | 692 | 9.5K | 13.6K | 1676 | **1.00** |
| cbor-x:1.6.4 | 101 | 51.6 | 48.7 | 52.2K | 10.3K | 1709 | **1.00** |
| devalue:5.8.1 | 530 | 394 | 132 | 27.6K | 25.6K | 1743 | **1.00** |
| fast-json-stringify:6.4.0 | 176 | 97.4 | 76.9 | 79.7K | 19.7K | 1767 | **1.00** |
| flatbuffers:24.12.23 | 372 | 260 | 110 | 32.9K | 18.7K | 1659 | **1.00** |
| flexbuffers:24.12.23 | 2,110 | 1,210 | 899 | 3.84K | 27.2K | 1622 | **1.00** |
| google-protobuf:3.21.4 | **73.3** | **0.723** | 72.5 | 104K | 10.2K | 1732 | **1.00** |
| json-pack-msgpack:18.28.0 | 99.7 | 51 | **48.2** | 85.9K | 14.1K | 1656 | **1.00** |
| JSON.stringify:node-24.15.0 | 143 | 67.7 | 74.9 | **117K** | 19.7K | 1799 | **1.00** |
| msgpackr:1.12.1 | 114 | 47.8 | 66 | 75.8K | 13.9K | 1728 | **1.00** |
| protobuf-es:2.12.1 | 665 | 462 | 202 | 20.4K | 10.1K | 1680 | **1.00** |
| protobufjs:7.6.5 | 199 | 96.9 | 101 | 38.4K | 10.2K | 1695 | **1.00** |
| sia:2.3.0 | 485 | 329 | 154 | 39.9K | 19K | 1707 | **1.00** |
| simdjson-parse+JSON.stringify:0.9.2 | 269 | 67.2 | 201 | 35.1K | 19.7K | 1746 | **1.00** |
| v8-serializer:v8-13.6.233.17-node.48 | 121 | 46.4 | 74.2 | 53.1K | 15.3K | 1655 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 20.4 | 18.4 | 13 | 13.1 |
| avsc:5.7.9 | 16.5 | 15.7 | 12.5 | 12.1 |
| bebop:3.2.3 | 10.1 | 9.78 | 6.46 | 6.51 |
| bser:2.1.1 | 32.3 | 31 | 18.3 | 18.2 |
| bson:6.10.4 | 18.9 | 18.3 | 10.3 | 9.91 |
| cbor:9.0.2 | 105 | 97.9 | 66.2 | 63.7 |
| cbor-x:1.6.4 | 16.4 | 15.1 | 10.5 | 10.4 |
| devalue:5.8.1 | 20.7 | 20.9 | 14.6 | 14.3 |
| fast-json-stringify:6.4.0 | 6.82 | 6.66 | 5.16 | 4.98 |
| flatbuffers:24.12.23 | 23.7 | 21.9 | 16 | 15.4 |
| flexbuffers:24.12.23 | 83.9 | 83.3 | 200 | 113 |
| google-protobuf:3.21.4 | 12.2 | 11 | 7.67 | 7.39 |
| json-pack-msgpack:18.28.0 | 13.9 | 13.6 | 9.17 | 8.72 |
| JSON.stringify:node-24.15.0 | **5.24** | **4.81** | **3.72** | **3.56** |
| msgpackr:1.12.1 | 14.6 | 13.2 | 8.43 | 8.53 |
| protobuf-es:2.12.1 | 38.2 | 37 | 23 | 22.8 |
| protobufjs:7.6.5 | 26.8 | 24.2 | 16.6 | 16.3 |
| sia:2.3.0 | 19.2 | 18.2 | 10.6 | 10.4 |
| simdjson-parse+JSON.stringify:0.9.2 | 16.2 | 14.5 | 12.9 | 12.1 |
| v8-serializer:v8-13.6.233.17-node.48 | 11 | 10.7 | 10.1 | 9.94 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 53K | 2.5K | 160K | 3.8K | 49K | 6.9K | 130K | 2.2K | 87K | 5.7K |
| avsc:5.7.9 | 54K | 1.2K | 99K | 1.8K | 61K | 3.9K | 91K | 1K | 53K | 0.88K |
| bebop:3.2.3 | 100K | 2.3K | 190K | 3.8K | 99K | 6.7K | 160K | 2.6K | 150K | 6.5K |
| bser:2.1.1 | 47K | 0.92K | 71K | 1.5K | 31K | 3.1K | 75K | 1.5K | 34K | 1.5K |
| bson:6.10.4 | 44K | 1.4K | 110K | 2.6K | 53K | 5K | 86K | 2.3K | 72K | 3.2K |
| cbor:9.0.2 | 11K | 0.22K | 24K | 0.48K | 9.6K | 0.85K | 24K | 0.47K | 19K | 0.46K |
| cbor-x:1.6.4 | 47K | 3.9K | 87K | 5.2K | 61K | 12K | 150K | 3.4K | 110K | 7K |
| devalue:5.8.1 | 31K | 0.61K | 80K | 1.3K | 48K | 2.6K | 75K | 0.91K | 37K | 0.74K |
| fast-json-stringify:6.4.0 | 99K | 2K | 190K | 3.8K | 150K | 7.6K | 160K | 2.3K | 130K | 2K |
| flatbuffers:24.12.23 | 45K | 1.1K | 74K | 1.3K | 42K | 3.4K | 50K | 0.66K | 82K | 2.5K |
| flexbuffers:24.12.23 | 6.9K | 0.18K | 12K | 0.46K | 12K | 0.7K | 5.3K | 0.23K | 4.1K | 0.14K |
| google-protobuf:3.21.4 | 150K | **5.5K** | 260K | **8.4K** | 82K | **15K** | 250K | 4.4K | 140K | 6.4K |
| json-pack-msgpack:18.28.0 | 68K | 3.4K | 230K | 5.7K | 72K | 10K | 190K | 3.5K | **190K** | **7.5K** |
| JSON.stringify:node-24.15.0 | **170K** | 2.9K | **310K** | 4.8K | **190K** | 11K | **280K** | 3.4K | 140K | 2K |
| msgpackr:1.12.1 | 75K | 2.6K | 180K | 4.6K | 68K | 8.1K | 190K | 3.9K | 160K | 7K |
| protobuf-es:2.12.1 | 27K | 0.58K | 57K | 0.86K | 26K | 2.3K | 41K | 0.5K | 32K | 0.73K |
| protobufjs:7.6.5 | 39K | 1.7K | 76K | 2.7K | 37K | 6.9K | 100K | 1.7K | 53K | 3.3K |
| sia:2.3.0 | 46K | 0.58K | 81K | 1K | 52K | 2.2K | 68K | 0.8K | 100K | 2.4K |
| simdjson-parse+JSON.stringify:0.9.2 | 54K | 1.4K | 89K | 2.4K | 62K | 4.5K | 86K | 2K | 46K | 1.3K |
| v8-serializer:v8-13.6.233.17-node.48 | 66K | 2.3K | 100K | 4.1K | 91K | 10K | 120K | **4.9K** | 100K | 5.8K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/javascript/2026-07-24-183742.csv`
    - run=2026-07-24-183742
    - language=javascript
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: node=24.15.0, python=3.14.0, dotnet=9.0.316
    - git=85145fd dirty
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
