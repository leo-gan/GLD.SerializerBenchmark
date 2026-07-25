# Go — Benchmark Results

**Generated:** 2026-07-24T18:57:57.715953

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
| encoding/gob:go1.24.13 | 83.1 | 30 | 52 | 32.4K | 10.3K | 1776 | **1.00** |
| encoding/json:go1.24.13 | 270 | 55.5 | 214 | 73.4K | 19.7K | 1709 | **1.00** |
| fxamacker/cbor:2.9.2 | 114 | 27.8 | 85.9 | 148K | 13.6K | 1722 | **1.00** |
| goccy/go-json:0.10.6 | 121 | 50.3 | 70.4 | 165K | 19.7K | 1732 | **1.00** |
| goccy/go-yaml:1.19.2 | 4,770 | 2,160 | 2,570 | 6.48K | 22K | 1826 | **1.00** |
| hamba/avro:2.31.0 | **38.2** | **18.8** | **18.7** | 261K | 9.11K | 1741 | **1.00** |
| jsoniter:1.1.12 | 153 | 54.7 | 98 | 131K | 19.7K | 1748 | **1.00** |
| kelindar/binary:1.0.19 | 56.4 | 22.2 | 33.9 | **276K** | **8.97K** | 1703 | **1.00** |
| linkedin/goavro:2.15.0 | 93.1 | 28.2 | 62.1 | 209K | 9.02K | 1747 | **1.00** |
| mongo-bson:1.17.9 | 188 | 62.7 | 125 | 79.5K | 20.7K | 1718 | **1.00** |
| pelletier/go-toml:2.4.3 | 338 | 124 | 214 | 68.1K | 22.2K | 1693 | **1.00** |
| protobuf:1.36.11 | 66 | 23.1 | 42.1 | 225K | 10.1K | 1762 | **1.00** |
| segmentio/encoding/json:0.5.4 | 136 | 47.2 | 89 | 124K | 19.7K | 1719 | **1.00** |
| shamaton/msgpack:3.1.2 | 80.7 | 30.3 | 50.1 | 188K | 13.3K | 1737 | **1.00** |
| sonic:1.15.2 | 78.5 | 35.3 | 43.1 | 176K | 19.7K | 1709 | **1.00** |
| ugorji/cbor:1.3.1 | 67.3 | 22.3 | 44.9 | 153K | 13.6K | 1760 | **1.00** |
| ugorji/json:1.3.1 | 148 | 51.6 | 96.2 | 98.4K | 19.7K | 1740 | **1.00** |
| ugorji/msgpack:1.3.1 | 63.7 | 20.9 | 42.5 | 158K | 13.6K | 1733 | **1.00** |
| vmihailenco/msgpack:5.4.1 | 113 | 42.2 | 70.6 | 140K | 14.2K | 1735 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| encoding/gob:go1.24.13 | 15 | 14 | 16.3 | 15.7 |
| encoding/json:go1.24.13 | 3.32 | 3.13 | 4.57 | 4.24 |
| fxamacker/cbor:2.9.2 | 1.73 | 1.65 | 2.62 | 2.4 |
| goccy/go-json:0.10.6 | 1.51 | 1.47 | 2.25 | 2.24 |
| goccy/go-yaml:1.19.2 | 45.5 | 45.2 | 50.6 | 48.6 |
| hamba/avro:2.31.0 | 0.994 | 0.976 | 1.79 | 1.62 |
| jsoniter:1.1.12 | 2.12 | 2.11 | 3.08 | 3.01 |
| kelindar/binary:1.0.19 | **0.791** | **0.766** | **1.47** | **1.37** |
| linkedin/goavro:2.15.0 | 1.14 | 1.1 | 1.7 | 1.51 |
| mongo-bson:1.17.9 | 3.18 | 3.04 | 4.31 | 3.94 |
| pelletier/go-toml:2.4.3 | 3.94 | 3.69 | 4.8 | 4.7 |
| protobuf:1.36.11 | 1.07 | 1.06 | 1.77 | 1.56 |
| segmentio/encoding/json:0.5.4 | 1.6 | 1.5 | 5.2 | 4.67 |
| shamaton/msgpack:3.1.2 | 1.38 | 1.31 | 2.2 | 2.02 |
| sonic:1.15.2 | 1.52 | 1.46 | 2.57 | 2.31 |
| ugorji/cbor:1.3.1 | 1.58 | 1.54 | 4.29 | 3.86 |
| ugorji/json:1.3.1 | 2.37 | 2.23 | 5.75 | 5.02 |
| ugorji/msgpack:1.3.1 | 1.54 | 1.49 | 3.92 | 3.52 |
| vmihailenco/msgpack:5.4.1 | 1.85 | 1.8 | 2.92 | 2.54 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| encoding/gob:go1.24.13 | 47K | 5K | 44K | 6.4K | 0.067M | 13K | 81K | 4.9K | 58K | 6.6K |
| encoding/json:go1.24.13 | 100K | 1.6K | 140K | 2.8K | 0.3M | 4.7K | 160K | 1.7K | 88K | 1.1K |
| fxamacker/cbor:2.9.2 | 190K | 3.1K | 220K | 5.3K | 0.58M | 12K | 340K | 3.6K | 290K | 5.1K |
| goccy/go-json:0.10.6 | 280K | 5.7K | 290K | 8.8K | 0.66M | 14K | 430K | 4.1K | 140K | 1.7K |
| goccy/go-yaml:1.19.2 | 6.5K | 0.058K | 11K | 0.13K | 0.022M | 0.22K | 15K | 0.12K | 11K | 0.098K |
| hamba/avro:2.31.0 | 410K | **11K** | 410K | **15K** | 1M | **39K** | **640K** | **8.4K** | 520K | 14K |
| jsoniter:1.1.12 | 210K | 4.3K | 240K | 6.7K | 0.47M | 9.6K | 390K | 3.8K | 100K | 1.3K |
| kelindar/binary:1.0.19 | **450K** | 8.7K | **510K** | 12K | **1.3M** | 34K | 510K | 5.1K | 550K | 10K |
| linkedin/goavro:2.15.0 | 250K | 3.6K | 310K | 5.4K | 0.88M | 17K | 370K | 3.5K | 470K | 7.6K |
| mongo-bson:1.17.9 | 94K | 1.8K | 120K | 2.8K | 0.31M | 6.9K | 190K | 2.2K | 140K | 2.4K |
| pelletier/go-toml:2.4.3 | 67K | 0.91K | 98K | 1.7K | 0.25M | 3.5K | 200K | 2K | 89K | 1.1K |
| protobuf:1.36.11 | 270K | 5.4K | 320K | 8.1K | 0.93M | 22K | 430K | 4.1K | **560K** | **17K** |
| segmentio/encoding/json:0.5.4 | 260K | 5.5K | 300K | 7.6K | 0.62M | 13K | 370K | 3.7K | 140K | 1.8K |
| shamaton/msgpack:3.1.2 | 230K | 4.6K | 270K | 6.8K | 0.73M | 17K | 550K | 6.7K | 440K | 11K |
| sonic:1.15.2 | 230K | 6.1K | 300K | 8.9K | 0.66M | 18K | 590K | 6.3K | 240K | 3.5K |
| ugorji/cbor:1.3.1 | 220K | 4.9K | 270K | 7.8K | 0.63M | 16K | 480K | 6.2K | 390K | 12K |
| ugorji/json:1.3.1 | 180K | 3.9K | 190K | 6.1K | 0.42M | 9.1K | 340K | 4K | 110K | 1.6K |
| ugorji/msgpack:1.3.1 | 220K | 5.3K | 260K | 8.2K | 0.65M | 18K | 470K | 6.5K | 440K | 13K |
| vmihailenco/msgpack:5.4.1 | 160K | 3K | 210K | 4.6K | 0.54M | 12K | 410K | 4.6K | 230K | 4.1K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/go/2026-07-24-185531.csv`
    - run=2026-07-24-185531
    - language=go
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: go=go version go1.22.10 linux/amd64, python=3.14.0, node=24.15.0
    - git=85145fd dirty
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
