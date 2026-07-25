# Go — Benchmark Results

**Generated:** 2026-07-24T19:44:00.492836

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

> **Stream honesty:** stream rows labeled as **native** 170, **adapted** 20. Only **`native`** (and carefully **`text_on_stream`**) support stream-API performance claims. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| encoding/gob:go1.24.13 | 73.6 | 26.1 | 46.7 | 32.7K | 10.3K | 1771 | **1.00** |
| encoding/json:go1.24.13 | 265 | 53.6 | 211 | 74.4K | 19.7K | 1751 | **1.00** |
| fxamacker/cbor:2.9.2 | 112 | 26.4 | 85 | 152K | 13.6K | 1747 | **1.00** |
| goccy/go-json:0.10.6 | 116 | 48.1 | 68.1 | 166K | 19.7K | 1748 | **1.00** |
| goccy/go-yaml:1.19.2 | 4,470 | 2,030 | 2,430 | 6.54K | 22K | 1827 | **1.00** |
| hamba/avro:2.31.0 | **34.1** | **16.7** | **17.2** | 277K | 9.11K | 1771 | **1.00** |
| jsoniter:1.1.12 | 147 | 51.5 | 95.7 | 138K | 19.7K | 1763 | **1.00** |
| kelindar/binary:1.0.19 | 55.2 | 21.8 | 33.1 | **280K** | **8.97K** | 1756 | **1.00** |
| linkedin/goavro:2.15.0 | 82.6 | 23.5 | 58.2 | 217K | 9.02K | 1770 | **1.00** |
| mongo-bson:1.17.9 | 181 | 59.2 | 121 | 83.4K | 20.7K | 1739 | **1.00** |
| pelletier/go-toml:2.4.3 | 333 | 122 | 208 | 67.2K | 22.2K | 1723 | **1.00** |
| protobuf:1.36.11 | 61.3 | 20.8 | 39.6 | 230K | 10.1K | 1793 | **1.00** |
| segmentio/encoding/json:0.5.4 | 131 | 45.3 | 85.5 | 134K | 19.7K | 1753 | **1.00** |
| shamaton/msgpack:3.1.2 | 78.5 | 28.9 | 49 | 188K | 13.3K | 1759 | **1.00** |
| sonic:1.15.2 | 74.2 | 32.9 | 40.5 | 178K | 19.7K | 1749 | **1.00** |
| ugorji/cbor:1.3.1 | 64.4 | 20.8 | 43.2 | 159K | 13.6K | 1783 | **1.00** |
| ugorji/json:1.3.1 | 145 | 50.4 | 93.9 | 102K | 19.7K | 1793 | **1.00** |
| ugorji/msgpack:1.3.1 | 61.5 | 19.9 | 41.2 | 166K | 13.6K | 1746 | **1.00** |
| vmihailenco/msgpack:5.4.1 | 110 | 41.1 | 68.7 | 140K | 14.2K | 1740 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| encoding/gob:go1.24.13 | 15 | 14.5 | 14 | 13.9 |
| encoding/json:go1.24.13 | 3.3 | 3.17 | 3.8 | 3.77 |
| fxamacker/cbor:2.9.2 | 1.71 | 1.68 | 2.01 | 1.91 |
| goccy/go-json:0.10.6 | 1.56 | 1.54 | 2.05 | 2.08 |
| goccy/go-yaml:1.19.2 | 44.4 | 42.7 | 42.3 | 41.4 |
| hamba/avro:2.31.0 | 0.949 | 0.893 | 1.34 | 1.29 |
| jsoniter:1.1.12 | 2 | 1.94 | 2.52 | 2.48 |
| kelindar/binary:1.0.19 | **0.805** | **0.781** | **1.25** | **1.25** |
| linkedin/goavro:2.15.0 | 1.13 | 1.08 | 1.31 | 1.27 |
| mongo-bson:1.17.9 | 3.09 | 2.86 | 3.29 | 3.16 |
| pelletier/go-toml:2.4.3 | 3.82 | 3.78 | 4.28 | 4.15 |
| protobuf:1.36.11 | 1.12 | 1.07 | 1.39 | 1.33 |
| segmentio/encoding/json:0.5.4 | 1.62 | 1.59 | 3.26 | 3.1 |
| shamaton/msgpack:3.1.2 | 1.34 | 1.32 | 1.98 | 1.89 |
| sonic:1.15.2 | 1.6 | 1.54 | 2.16 | 2.15 |
| ugorji/cbor:1.3.1 | 1.58 | 1.51 | 2.96 | 2.78 |
| ugorji/json:1.3.1 | 2.32 | 2.25 | 3.94 | 3.82 |
| ugorji/msgpack:1.3.1 | 1.45 | 1.4 | 2.86 | 2.72 |
| vmihailenco/msgpack:5.4.1 | 1.86 | 1.79 | 2.36 | 2.34 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| encoding/gob:go1.24.13 | 48K | 5.3K | 62K | 7.7K | 0.067M | 17K | 74K | 6.1K | 55K | 7.1K |
| encoding/json:go1.24.13 | 100K | 1.5K | 190K | 2.8K | 0.3M | 5K | 150K | 1.8K | 81K | 1.1K |
| fxamacker/cbor:2.9.2 | 190K | 3.1K | 350K | 5.3K | 0.59M | 13K | 310K | 4K | 270K | 5.1K |
| goccy/go-json:0.10.6 | 320K | 6K | 490K | 10K | 0.64M | 16K | 370K | 4.2K | 130K | 1.7K |
| goccy/go-yaml:1.19.2 | 7.3K | 0.062K | 14K | 0.13K | 0.023M | 0.25K | 14K | 0.13K | 10K | 0.1K |
| hamba/avro:2.31.0 | 450K | **11K** | 670K | **18K** | 1.1M | **46K** | **590K** | **9.8K** | **520K** | 15K |
| jsoniter:1.1.12 | 230K | 4.1K | 410K | 7.5K | 0.5M | 11K | 370K | 4.3K | 94K | 1.2K |
| kelindar/binary:1.0.19 | **500K** | 8.7K | **780K** | 12K | **1.2M** | 37K | 460K | 5.9K | 500K | 10K |
| linkedin/goavro:2.15.0 | 280K | 3.7K | 450K | 6.2K | 0.88M | 19K | 330K | 4K | 450K | 8.2K |
| mongo-bson:1.17.9 | 100K | 1.7K | 180K | 3K | 0.32M | 7.2K | 170K | 2.4K | 130K | 2.5K |
| pelletier/go-toml:2.4.3 | 72K | 0.89K | 140K | 1.8K | 0.26M | 3.6K | 190K | 2.1K | 80K | 1.1K |
| protobuf:1.36.11 | 300K | 5.8K | 490K | 8.9K | 0.9M | 26K | 400K | 4.6K | 520K | **18K** |
| segmentio/encoding/json:0.5.4 | 290K | 5.5K | 420K | 8.5K | 0.62M | 16K | 340K | 4.3K | 130K | 1.8K |
| shamaton/msgpack:3.1.2 | 260K | 4.6K | 410K | 7.2K | 0.75M | 21K | 480K | 7.6K | 420K | 13K |
| sonic:1.15.2 | 290K | 6.2K | 470K | 11K | 0.62M | 19K | 520K | 7.4K | 230K | 3.6K |
| ugorji/cbor:1.3.1 | 240K | 4.8K | 410K | 8.3K | 0.63M | 18K | 440K | 7.3K | 360K | 13K |
| ugorji/json:1.3.1 | 170K | 3.9K | 300K | 6.1K | 0.43M | 9.8K | 290K | 4.6K | 100K | 1.6K |
| ugorji/msgpack:1.3.1 | 260K | 5.3K | 420K | 8.6K | 0.69M | 20K | 420K | 7.1K | 400K | 15K |
| vmihailenco/msgpack:5.4.1 | 170K | 2.9K | 310K | 4.9K | 0.54M | 13K | 370K | 5.4K | 230K | 4.4K |

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
    
    - **Source CSV:** `logs/go/2026-07-24-193927.csv`
    - run=2026-07-24-193927
    - language=go
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: go=go version go1.22.10 linux/amd64, python=3.14.0, node=24.15.0
    - git=7431b57 dirty
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
