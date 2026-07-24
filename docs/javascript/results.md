# JavaScript (Node.js) — Benchmark Results

**Generated:** 2026-07-20T12:51:48.965047

This page is a **snapshot of measured numbers** for JavaScript (Node.js) on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [JavaScript (Node.js) overview](index.md) |
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
| @msgpack/msgpack:3.1.3 | 141 | 69.4 | 70.9 | 96.3K | 13.5K | 1717 | **1.00** |
| avsc:5.7.9 | 360 | 196 | 164 | 59.4K | **9.02K** | 1731 | **1.00** |
| bebop:3.2.3 | 142 | 52.4 | 89.7 | 108K | 19K | 1745 | **1.00** |
| bser:2.1.1 | 335 | 176 | 159 | 35.1K | 16.4K | 1723 | **1.00** |
| bson:6.10.4 | 200 | 95.5 | 104 | 68.1K | 20.3K | 1705 | **1.00** |
| cbor:9.0.2 | 1,230 | 520 | 705 | 13.6K | 13.6K | 1665 | **1.00** |
| cbor-x:1.6.4 | 79.7 | 47.2 | **32.2** | 120K | 10.3K | 1717 | **1.00** |
| devalue:5.8.1 | 464 | 345 | 119 | 34.9K | 25.6K | 1751 | **1.00** |
| fast-json-stringify:6.4.0 | 134 | 70.8 | 62.4 | 155K | 19.7K | 1685 | **1.00** |
| flatbuffers:24.12.23 | 379 | 260 | 117 | 48.4K | 18.7K | 1634 | **1.00** |
| flexbuffers:24.12.23 | 2,180 | 1,250 | 915 | 3.34K | 27.2K | 1669 | **1.00** |
| google-protobuf:3.21.4 | **73.4** | **0.222** | 73.1 | 152K | 10.2K | 1599 | **1.00** |
| json-pack-msgpack:18.28.0 | 94.8 | 49.7 | 44.8 | 186K | 14.1K | 1747 | **1.00** |
| JSON.stringify:node-24.15.0 | 130 | 67.8 | 61.8 | **194K** | 19.7K | 1726 | **1.00** |
| msgpackr:1.12.1 | 113 | 47.5 | 65 | 169K | 13.9K | 1744 | **1.00** |
| protobuf-es:2.12.1 | 678 | 480 | 197 | 31.5K | 10.1K | 1613 | **1.00** |
| protobufjs:7.6.5 | 163 | 77.7 | 84.9 | 67.8K | 10.2K | 1618 | **1.00** |
| sia:2.3.0 | 494 | 333 | 160 | 45.5K | 19K | 1660 | **1.00** |
| simdjson-parse+JSON.stringify:0.9.2 | 256 | 65.1 | 191 | 70.3K | 19.7K | 1722 | **1.00** |
| v8-serializer:v8-13.6.233.17-node.48 | 107 | 34.8 | 72.1 | 136K | 15.3K | 1762 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 11.6 | 10.7 | 5.23 | 5.22 |
| avsc:5.7.9 | 7.51 | 7.37 | 5.88 | 5.48 |
| bebop:3.2.3 | 7.25 | 7.34 | 7.08 | 7.02 |
| bser:2.1.1 | 25.6 | 24.8 | 19.1 | 19.1 |
| bson:6.10.4 | 11.8 | 9.88 | 8.71 | 8.69 |
| cbor:9.0.2 | 64.9 | 60.7 | 45.1 | 44.7 |
| cbor-x:1.6.4 | 11.3 | 10.9 | 5.94 | 5.02 |
| devalue:5.8.1 | 7.87 | 7.83 | 7.22 | 7.04 |
| fast-json-stringify:6.4.0 | 2.76 | 2.72 | 1.97 | 1.96 |
| flatbuffers:24.12.23 | 11.9 | 10.3 | 8.09 | 8.02 |
| flexbuffers:24.12.23 | 57.3 | 53.9 | 275 | 316 |
| google-protobuf:3.21.4 | 5.31 | 5.16 | 3.34 | 3.32 |
| json-pack-msgpack:18.28.0 | 8.4 | 8.28 | 5.05 | 5.04 |
| JSON.stringify:node-24.15.0 | **2.07** | **1.91** | **1.86** | **1.86** |
| msgpackr:1.12.1 | 10.3 | 9.92 | 5.25 | 5.23 |
| protobuf-es:2.12.1 | 15.1 | 13.6 | 8.8 | 8.33 |
| protobufjs:7.6.5 | 9.05 | 8.23 | 6.08 | 6.08 |
| sia:2.3.0 | 12.9 | 12.6 | 11.1 | 8.97 |
| simdjson-parse+JSON.stringify:0.9.2 | 4.99 | 4.63 | 4.44 | 4.42 |
| v8-serializer:v8-13.6.233.17-node.48 | 2.49 | 2.46 | 2.97 | 3.23 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 71K | 2.5K | 280K | 4K | 86K | 8.3K | 200K | 2.1K | 110K | 6.6K |
| avsc:5.7.9 | 91K | 1.3K | 120K | 1.9K | 130K | 4.7K | 130K | 1.1K | 72K | 0.87K |
| bebop:3.2.3 | 170K | 2.2K | 300K | 3.8K | 140K | 5.9K | 230K | 2.5K | 210K | 7.4K |
| bser:2.1.1 | 67K | 0.86K | 50K | 1.5K | 39K | 3.1K | 100K | 1.4K | 78K | 1.6K |
| bson:6.10.4 | 44K | 1.4K | 150K | 2.7K | 85K | 4.8K | 180K | 2.3K | 150K | 3.4K |
| cbor:9.0.2 | 16K | 0.21K | 34K | 0.48K | 15K | 0.94K | 33K | 0.45K | 31K | 0.46K |
| cbor-x:1.6.4 | 80K | 5K | 240K | 7K | 89K | **22K** | 71K | 3.6K | 420K | 8.3K |
| devalue:5.8.1 | 37K | 0.73K | 70K | 1.4K | 130K | 3K | 55K | 1.1K | 48K | 0.86K |
| fast-json-stringify:6.4.0 | 190K | 2.8K | 370K | 4.8K | 360K | 11K | 240K | 2.6K | 240K | 3.1K |
| flatbuffers:24.12.23 | 58K | 1.2K | 100K | 1.3K | 84K | 3.6K | 55K | 0.63K | 140K | 2.5K |
| flexbuffers:24.12.23 | 4.7K | 0.18K | 6K | 0.48K | 17K | 0.76K | 9.3K | 0.23K | 4.2K | 0.13K |
| google-protobuf:3.21.4 | 230K | **6K** | 400K | **8.6K** | 190K | 17K | 240K | 4.2K | 240K | 6.1K |
| json-pack-msgpack:18.28.0 | 71K | 3.6K | **530K** | 6.1K | 120K | 11K | 400K | 3.5K | **610K** | **8.4K** |
| JSON.stringify:node-24.15.0 | **280K** | 3.7K | 470K | 6.2K | **480K** | 13K | 450K | 3.3K | 220K | 2.1K |
| msgpackr:1.12.1 | 77K | 2.6K | 400K | 4.9K | 97K | 6.7K | **470K** | 3.7K | 520K | 7.4K |
| protobuf-es:2.12.1 | 22K | 0.6K | 85K | 0.89K | 66K | 2.5K | 51K | 0.48K | 53K | 0.7K |
| protobufjs:7.6.5 | 66K | 2.2K | 170K | 3.4K | 110K | 9.7K | 100K | 1.9K | 110K | 3.6K |
| sia:2.3.0 | 58K | 0.58K | 94K | 1K | 77K | 2.1K | 76K | 0.79K | 120K | 2.5K |
| simdjson-parse+JSON.stringify:0.9.2 | 100K | 1.5K | 170K | 2.7K | 200K | 5.3K | 67K | 2K | 99K | 1.2K |
| v8-serializer:v8-13.6.233.17-node.48 | 85K | 2.4K | 250K | 4.5K | 400K | 14K | 320K | **5.4K** | 300K | 6.6K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/javascript/2026-07-20-125122.csv`
    - run=2026-07-20-125122
    - language=javascript
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: node=24.15.0, python=3.14.0, dotnet=8.0.422
    - git=61a38cf dirty
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
