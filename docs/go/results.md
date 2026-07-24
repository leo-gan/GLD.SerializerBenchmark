# Go — Benchmark Results

**Generated:** 2026-07-24T15:53:49.992859

This page is a **snapshot of measured numbers** for Go on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [Go overview](index.md) |
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
| encoding/gob:go1.24.13 | 70.4 | 25 | 45.4 | 32.1K | 10.3K | 1761 | **1.00** |
| encoding/json:go1.24.13 | 286 | 53.2 | 233 | 89.2K | 19.7K | 1697 | **1.00** |
| fxamacker/cbor:2.9.2 | 112 | 22.6 | 89.5 | 174K | 13.6K | 1678 | **1.00** |
| goccy/go-json:0.10.6 | 117 | 43.1 | 73.1 | 300K | 19.7K | 1662 | **1.00** |
| goccy/go-yaml:1.19.2 | 5,170 | 2,320 | 2,820 | 6.13K | 22K | 1830 | **1.00** |
| hamba/avro:2.31.0 | **30.2** | **13.3** | **16.8** | **563K** | 9.11K | 1720 | **1.00** |
| jsoniter:1.1.12 | 151 | 49.5 | 101 | 246K | 19.7K | 1665 | **1.00** |
| kelindar/binary:1.0.19 | 62.3 | 26.1 | 36.1 | 289K | **8.97K** | 1661 | **1.00** |
| linkedin/goavro:2.15.0 | 93.7 | 22.5 | 70.2 | 334K | 9.02K | 1656 | **1.00** |
| mongo-bson:1.17.9 | 185 | 58.5 | 126 | 111K | 20.7K | 1620 | **1.00** |
| pelletier/go-toml:2.4.3 | 339 | 121 | 217 | 93.6K | 22.2K | 1603 | **1.00** |
| protobuf:1.36.11 | 60.8 | 19.7 | 41 | 533K | 10.1K | 1670 | **1.00** |
| segmentio/encoding/json:0.5.4 | 127 | 39.8 | 86.3 | 180K | 19.7K | 1667 | **1.00** |
| shamaton/msgpack:3.1.2 | 79.6 | 28.7 | 50.8 | 263K | 13.3K | 1721 | **1.00** |
| sonic:1.15.2 | 65.1 | 24.8 | 40.1 | 327K | 19.7K | 1679 | **1.00** |
| ugorji/cbor:1.3.1 | 64.9 | 20.2 | 44.5 | 184K | 13.6K | 1720 | **1.00** |
| ugorji/json:1.3.1 | 148 | 51.4 | 96.5 | 147K | 19.7K | 1654 | **1.00** |
| ugorji/msgpack:1.3.1 | 67.2 | 19.1 | 47.4 | 227K | 13.6K | 1676 | **1.00** |
| vmihailenco/msgpack:5.4.1 | 118 | 44 | 73.8 | 156K | 14.2K | 1650 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| encoding/gob:go1.24.13 | 18.6 | 20.4 | 12.1 | 12 |
| encoding/json:go1.24.13 | 4.34 | 4.3 | 3.81 | 4.56 |
| fxamacker/cbor:2.9.2 | 1.86 | 2.22 | 2.56 | 2.54 |
| goccy/go-json:0.10.6 | 2.05 | 2.03 | 0.87 | 0.869 |
| goccy/go-yaml:1.19.2 | 65.9 | 65.5 | 46.7 | 39.7 |
| hamba/avro:2.31.0 | **0.408** | **0.402** | 0.917 | 0.717 |
| jsoniter:1.1.12 | 1.2 | 1.19 | 1.28 | 1.25 |
| kelindar/binary:1.0.19 | 1.15 | 1.14 | 0.719 | 0.676 |
| linkedin/goavro:2.15.0 | 0.655 | 0.65 | 0.69 | 0.682 |
| mongo-bson:1.17.9 | 2.13 | 1.87 | 4.44 | 4.38 |
| pelletier/go-toml:2.4.3 | 2.85 | 2.67 | 2.66 | 2.66 |
| protobuf:1.36.11 | 0.419 | 0.416 | **0.46** | **0.456** |
| segmentio/encoding/json:0.5.4 | 1.07 | 1.07 | 4.04 | 4.24 |
| shamaton/msgpack:3.1.2 | 0.733 | 0.733 | 1.07 | 1.06 |
| sonic:1.15.2 | 1.11 | 0.685 | 2.42 | 2.39 |
| ugorji/cbor:1.3.1 | 1.93 | 1.9 | 5.24 | 5.15 |
| ugorji/json:1.3.1 | 1.27 | 1.27 | 3.23 | 3.14 |
| ugorji/msgpack:1.3.1 | 0.769 | 0.749 | 2.17 | 2.02 |
| vmihailenco/msgpack:5.4.1 | 2.45 | 2.4 | 1.25 | 1.23 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| encoding/gob:go1.24.13 | 0.036M | 5.3K | 0.042M | 7.4K | 0.054M | 17K | 50K | 6.5K | 0.077M | 7K |
| encoding/json:go1.24.13 | 0.14M | 1.5K | 0.26M | 2.9K | 0.23M | 3.9K | 170K | 1.7K | 0.097M | 1K |
| fxamacker/cbor:2.9.2 | 0.16M | 3.1K | 0.49M | 5.8K | 0.54M | 13K | 200K | 4.1K | 0.41M | 5.1K |
| goccy/go-json:0.10.6 | 0.58M | 5.8K | 1M | 13K | 0.49M | 20K | 530K | 4K | 0.18M | 1.8K |
| goccy/go-yaml:1.19.2 | 0.0051M | 0.055K | 0.015M | 0.12K | 0.015M | 0.21K | 14K | 0.11K | 0.011M | 0.088K |
| hamba/avro:2.31.0 | **1.1M** | **13K** | **1.4M** | **18K** | **2.5M** | **79K** | **940K** | **11K** | 0.7M | 13K |
| jsoniter:1.1.12 | 0.41M | 4.2K | 0.68M | 8.3K | 0.84M | 12K | 510K | 3.9K | 0.12M | 1K |
| kelindar/binary:1.0.19 | 0.39M | 7.8K | 0.57M | 15K | 0.87M | 44K | 280K | 5.5K | 0.73M | 6K |
| linkedin/goavro:2.15.0 | 0.22M | 3.4K | 0.6M | 5.6K | 1.5M | 21K | 360K | 3.5K | 0.7M | 7.4K |
| mongo-bson:1.17.9 | 0.075M | 1.7K | 0.26M | 2.7K | 0.47M | 8.3K | 210K | 2K | 0.19M | 2.4K |
| pelletier/go-toml:2.4.3 | 0.088M | 0.89K | 0.19M | 1.8K | 0.35M | 4.1K | 130K | 2.1K | 0.1M | 1.1K |
| protobuf:1.36.11 | 0.56M | 5.2K | 0.86M | 7.1K | 2.4M | 36K | 500K | 4.8K | **1.7M** | **18K** |
| segmentio/encoding/json:0.5.4 | 0.49M | 6.5K | 0.68M | 10K | 0.93M | 22K | 440K | 4.1K | 0.15M | 1.9K |
| shamaton/msgpack:3.1.2 | 0.38M | 4.5K | 0.34M | 8K | 1.4M | 17K | 480K | 6.8K | 0.45M | 13K |
| sonic:1.15.2 | 0.68M | 8.2K | 1.1M | 16K | 0.9M | 28K | 440K | 7.1K | 0.44M | 3.7K |
| ugorji/cbor:1.3.1 | 0.21M | 5.1K | 0.71M | 8.9K | 0.52M | 21K | 330K | 7.3K | 0.91M | 13K |
| ugorji/json:1.3.1 | 0.3M | 3.9K | 0.29M | 5.7K | 0.79M | 8.7K | 470K | 4.7K | 0.16M | 1.5K |
| ugorji/msgpack:1.3.1 | 0.43M | 5.4K | 0.33M | 9.3K | 1.3M | 23K | 650K | 7.3K | 0.43M | 6.9K |
| vmihailenco/msgpack:5.4.1 | 0.24M | 2.7K | 0.23M | 4.9K | 0.41M | 14K | 260K | 4.7K | 0.35M | 4.2K |

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one **data type** (and batch size):

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that data type so the picture stays readable. Tables above still list everyone.
- Each image also prints the data type, source CSV, modes, and sample size.

### Document · 1 instance

![Document · 1 instance](../analysis/plots/violin/go_document@n=1.png){ width="80%" }

### Document · 100 instances

![Document · 100 instances](../analysis/plots/violin/go_document@n=100.png){ width="80%" }

### Event · 1 instance

![Event · 1 instance](../analysis/plots/violin/go_event@n=1.png){ width="80%" }

### Event · 100 instances

![Event · 100 instances](../analysis/plots/violin/go_event@n=100.png){ width="80%" }

### Message · 1 instance

![Message · 1 instance](../analysis/plots/violin/go_message@n=1.png){ width="80%" }

### Message · 100 instances

![Message · 100 instances](../analysis/plots/violin/go_message@n=100.png){ width="80%" }

### Strings · 1 instance

![Strings · 1 instance](../analysis/plots/violin/go_strings@n=1.png){ width="80%" }

### Strings · 100 instances

![Strings · 100 instances](../analysis/plots/violin/go_strings@n=100.png){ width="80%" }

### Telemetry · 1 instance

![Telemetry · 1 instance](../analysis/plots/violin/go_telemetry@n=1.png){ width="80%" }

### Telemetry · 100 instances

![Telemetry · 100 instances](../analysis/plots/violin/go_telemetry@n=100.png){ width="80%" }

## How to regenerate this page

Snapshots are produced on a developer machine. After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l go   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/go/2026-07-20-125149.csv`
    - run=2026-07-20-125149
    - language=go
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: go=go version go1.23.6 linux/amd64, python=3.14.0, node=24.15.0
    - git=61a38cf dirty
    - seed=42
    - warmup_reps=1
    - serializers=19
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `encoding/gob` @ go1.24.13
      - `encoding/json` @ go1.24.13
      - `fxamacker/cbor` @ 2.9.2
      - `goccy/go-json` @ 0.10.6
      - `goccy/go-yaml` @ 1.19.2
      - `hamba/avro` @ 2.31.0
      - `jsoniter` @ 1.1.12
      - `kelindar/binary` @ 1.0.19
      - `linkedin/goavro` @ 2.15.0
      - `mongo-bson` @ 1.17.9
      - `pelletier/go-toml` @ 2.4.3
      - `protobuf` @ 1.36.11
      - `segmentio/encoding/json` @ 0.5.4
      - `shamaton/msgpack` @ 3.1.2
      - `sonic` @ 1.15.2
      - `ugorji/cbor` @ 1.3.1
      - `ugorji/json` @ 1.3.1
      - `ugorji/msgpack` @ 1.3.1
      - `vmihailenco/msgpack` @ 5.4.1
