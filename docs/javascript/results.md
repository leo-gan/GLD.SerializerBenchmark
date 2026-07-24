# JavaScript (Node.js) — Benchmark Results

**Generated:** 2026-07-24T15:53:43.527587

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
| @msgpack/msgpack:3.1.3 | 137 | 69 | 68 | 81.9K | 13.5K | 1701 | **1.00** |
| avsc:5.7.9 | 340 | 184 | 155 | 68.3K | **9.02K** | 1717 | **1.00** |
| bebop:3.2.3 | 141 | 50.7 | 90.2 | 119K | 19K | 1723 | **1.00** |
| bser:2.1.1 | 339 | 179 | 157 | 32.2K | 16.4K | 1743 | **1.00** |
| bson:6.10.4 | 193 | 92.9 | 99.1 | 78.7K | 20.3K | 1658 | **1.00** |
| cbor:9.0.2 | 1,210 | 513 | 693 | 13.8K | 13.6K | 1704 | **1.00** |
| cbor-x:1.6.4 | 78.4 | 46.8 | **31.3** | 141K | 10.3K | 1667 | **1.00** |
| devalue:5.8.1 | 434 | 323 | 110 | 36.1K | 25.6K | 1698 | **1.00** |
| fast-json-stringify:6.4.0 | 127 | 68 | 58.4 | 163K | 19.7K | 1645 | **1.00** |
| flatbuffers:24.12.23 | 373 | 255 | 114 | 44.5K | 18.7K | 1611 | **1.00** |
| flexbuffers:24.12.23 | 2,090 | 1,190 | 882 | 4.11K | 27.2K | 1655 | **1.00** |
| google-protobuf:3.21.4 | **71.8** | **0.211** | 71.6 | 154K | 10.2K | 1628 | **1.00** |
| json-pack-msgpack:18.28.0 | 94.3 | 50 | 44.1 | 195K | 14.1K | 1764 | **1.00** |
| JSON.stringify:node-24.15.0 | 123 | 63.8 | 59 | **196K** | 19.7K | 1691 | **1.00** |
| msgpackr:1.12.1 | 107 | 46.9 | 60 | 172K | 13.9K | 1670 | **1.00** |
| protobuf-es:2.12.1 | 645 | 453 | 190 | 36.9K | 10.1K | 1645 | **1.00** |
| protobufjs:7.6.5 | 158 | 74.7 | 82.1 | 69.9K | 10.2K | 1604 | **1.00** |
| sia:2.3.0 | 496 | 337 | 158 | 51.6K | 19K | 1638 | **1.00** |
| simdjson-parse+JSON.stringify:0.9.2 | 245 | 62.1 | 182 | 75.3K | 19.7K | 1721 | **1.00** |
| v8-serializer:v8-13.6.233.17-node.48 | 104 | 34.7 | 69.3 | 137K | 15.3K | 1736 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 10.3 | 9.78 | 4.94 | 4.92 |
| avsc:5.7.9 | 6.48 | 6.45 | 5.03 | 4.74 |
| bebop:3.2.3 | 5.14 | 4.82 | 4.39 | 4.51 |
| bser:2.1.1 | 23.8 | 22.8 | 17.8 | 17.7 |
| bson:6.10.4 | 9.46 | 8.49 | 6.34 | 5.65 |
| cbor:9.0.2 | 57.7 | 51.9 | 40.3 | 40.4 |
| cbor-x:1.6.4 | 9.8 | 9.76 | 4.18 | 4.38 |
| devalue:5.8.1 | 8.02 | 7.96 | 7.16 | 7.08 |
| fast-json-stringify:6.4.0 | 2.64 | 2.58 | **1.77** | **1.73** |
| flatbuffers:24.12.23 | 10 | 8.53 | 6.71 | 6.68 |
| flexbuffers:24.12.23 | 47.6 | 44.6 | 216 | 285 |
| google-protobuf:3.21.4 | 5.18 | 5.04 | 3.22 | 3.2 |
| json-pack-msgpack:18.28.0 | 6.61 | 6.02 | 4.01 | 3.91 |
| JSON.stringify:node-24.15.0 | **2.13** | **1.95** | 1.85 | 1.87 |
| msgpackr:1.12.1 | 9.7 | 9.06 | 4.03 | 4.13 |
| protobuf-es:2.12.1 | 13 | 12.6 | 7.74 | 7.74 |
| protobufjs:7.6.5 | 8.22 | 7.47 | 5.26 | 5.37 |
| sia:2.3.0 | 11.7 | 12.1 | 8.13 | 8.18 |
| simdjson-parse+JSON.stringify:0.9.2 | 4.1 | 4.08 | 4.12 | 4.08 |
| v8-serializer:v8-13.6.233.17-node.48 | 2.22 | 2.19 | 2.65 | 2.44 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| @msgpack/msgpack:3.1.3 | 71K | 2.5K | 290K | 4K | 97K | 8.1K | 72K | 2.3K | 100K | 6.6K |
| avsc:5.7.9 | 110K | 1.4K | 170K | 2K | 150K | 5.2K | 130K | 1.1K | 74K | 0.92K |
| bebop:3.2.3 | 160K | 2.3K | 330K | 4K | 190K | 5.9K | 220K | 2.4K | 210K | 7.3K |
| bser:2.1.1 | 77K | 0.92K | 51K | 1.5K | 42K | 3.3K | 110K | 1.2K | 25K | 1.6K |
| bson:6.10.4 | 47K | 1.5K | 220K | 2.7K | 110K | 5.5K | 190K | 2.3K | 130K | 3.5K |
| cbor:9.0.2 | 19K | 0.22K | 34K | 0.46K | 17K | 0.97K | 32K | 0.44K | 28K | 0.46K |
| cbor-x:1.6.4 | 70K | 5.2K | 240K | 6.8K | 100K | **23K** | 420K | 3.8K | 390K | 7.8K |
| devalue:5.8.1 | 37K | 0.75K | 83K | 1.5K | 120K | 3.4K | 54K | 1.1K | 46K | 0.9K |
| fast-json-stringify:6.4.0 | 210K | 3.2K | 360K | 5.2K | 380K | 12K | 240K | 2.8K | 220K | 3K |
| flatbuffers:24.12.23 | 67K | 1.2K | 14K | 1.4K | 100K | 3.9K | 62K | 0.63K | 130K | 2.6K |
| flexbuffers:24.12.23 | 5.4K | 0.2K | 14K | 0.5K | 21K | 0.8K | 6.6K | 0.25K | 3.8K | 0.13K |
| google-protobuf:3.21.4 | 200K | **5.5K** | 420K | **8.8K** | 190K | 19K | 220K | 4.3K | 260K | 6.6K |
| json-pack-msgpack:18.28.0 | 82K | 3.6K | **580K** | 6.4K | 150K | 12K | 380K | 3.3K | **610K** | **8.3K** |
| JSON.stringify:node-24.15.0 | **320K** | 3.6K | 460K | 6.3K | **470K** | 13K | 440K | 3.5K | 190K | 2.2K |
| msgpackr:1.12.1 | 86K | 2.7K | 410K | 4.9K | 100K | 10K | **450K** | 4K | 490K | 7.2K |
| protobuf-es:2.12.1 | 50K | 0.64K | 93K | 0.94K | 77K | 2.7K | 52K | 0.48K | 58K | 0.75K |
| protobufjs:7.6.5 | 75K | 2.4K | 150K | 3.4K | 120K | 9.7K | 100K | 2K | 100K | 3.2K |
| sia:2.3.0 | 60K | 0.59K | 110K | 1K | 85K | 2.2K | 77K | 0.8K | 120K | 2.6K |
| simdjson-parse+JSON.stringify:0.9.2 | 84K | 1.6K | 170K | 2.8K | 240K | 5.7K | 150K | 2.1K | 94K | 1.3K |
| v8-serializer:v8-13.6.233.17-node.48 | 180K | 2.4K | 240K | 5.1K | 450K | 15K | 320K | **5.5K** | 42K | 6.4K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/javascript/2026-07-24-155318.csv`
    - run=2026-07-24-155318
    - language=javascript
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: node=24.15.0, python=3.14.0, dotnet=9.0.316
    - git=04d09d1 dirty
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
