# Go — Benchmark Results

**Generated:** 2026-07-29T20:52:48.238193

This page is a **snapshot of measured numbers** for Go on **one machine, one session** (claim level **L1**). Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little. Stronger multi-session / multi-machine claims need more evidence — see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [Go overview](index.md) |
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

> **Stream honesty:** stream rows labeled as **native** 170, **adapted** 20. Only **`native`** (and carefully **`text_on_stream`**) support stream-API performance claims. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) |
|---|---|---|---|---|---|
| encoding/gob:go1.24.13 | 71.2 | 25.3 | 45.5 | 33K | 10.3K |
| encoding/json:go1.24.13 | 260 | 52.8 | 206 | 71.1K | 19.7K |
| fxamacker/cbor:2.9.2 | 107 | 25.2 | 82 | 146K | 13.6K |
| goccy/go-json:0.10.6 | 112 | 46 | 65.8 | 162K | 19.7K |
| goccy/go-yaml:1.19.2 | 4,360 | 1,970 | 2,370 | 6.48K | 22K |
| hamba/avro:2.31.0 | **33.3** | **16.3** | **17** | 260K | 9.11K |
| jsoniter:1.1.12 | 144 | 49.5 | 93.2 | 131K | 19.7K |
| kelindar/binary:1.0.19 | 53.5 | 21.1 | 32.1 | **263K** | **8.97K** |
| linkedin/goavro:2.15.0 | 79.1 | 21.7 | 56.3 | 207K | 9.02K |
| mongo-bson:1.17.9 | 175 | 57 | 117 | 78.7K | 20.7K |
| pelletier/go-toml:2.4.3 | 324 | 119 | 203 | 65.6K | 22.2K |
| protobuf:1.36.11 | 59.4 | 20 | 38.9 | 217K | 10.1K |
| segmentio/encoding/json:0.5.4 | 128 | 43.9 | 83.6 | 124K | 19.7K |
| shamaton/msgpack:3.1.2 | 75.7 | 28.1 | 47.4 | 176K | 13.3K |
| sonic:1.15.2 | 71.2 | 31.4 | 38.6 | 172K | 19.7K |
| ugorji/cbor:1.3.1 | 62.1 | 20.1 | 41.8 | 149K | 13.6K |
| ugorji/json:1.3.1 | 140 | 48.9 | 91.5 | 97.4K | 19.7K |
| ugorji/msgpack:1.3.1 | 59.1 | 18.9 | 39.9 | 154K | 13.6K |
| vmihailenco/msgpack:5.4.1 | 107 | 39.9 | 66.4 | 133K | 14.2K |


### Total Time

| serializer | bytes mode/mean (µs) | bytes mode/median (µs) | stream mode/mean (µs) | stream mode/median (µs) |
|---|---|---|---|---|
| encoding/gob:go1.24.13 | 13.9 | 13.7 | 16.3 | 14.1 |
| encoding/json:go1.24.13 | 3.33 | 3.24 | 4.91 | 3.81 |
| fxamacker/cbor:2.9.2 | 1.66 | 1.63 | 2.63 | 2.09 |
| goccy/go-json:0.10.6 | 1.47 | 1.46 | 2.49 | 2.07 |
| goccy/go-yaml:1.19.2 | 44.8 | 43.8 | 49.7 | 43.6 |
| hamba/avro:2.31.0 | 0.997 | 0.997 | 1.79 | 1.52 |
| jsoniter:1.1.12 | 2.05 | 2.01 | 3.28 | 2.69 |
| kelindar/binary:1.0.19 | **0.744** | **0.73** | **1.67** | **1.32** |
| linkedin/goavro:2.15.0 | 1.11 | 1.1 | 1.7 | 1.4 |
| mongo-bson:1.17.9 | 3.1 | 2.88 | 4.42 | 3.59 |
| pelletier/go-toml:2.4.3 | 3.77 | 3.72 | 5.36 | 4.38 |
| protobuf:1.36.11 | 1.11 | 1.09 | 1.86 | 1.4 |
| segmentio/encoding/json:0.5.4 | 1.58 | 1.53 | 4 | 3.48 |
| shamaton/msgpack:3.1.2 | 1.31 | 1.31 | 2.4 | 2.01 |
| sonic:1.15.2 | 1.54 | 1.54 | 2.63 | 2.18 |
| ugorji/cbor:1.3.1 | 1.46 | 1.46 | 3.78 | 2.92 |
| ugorji/json:1.3.1 | 2.26 | 2.17 | 5.2 | 4.01 |
| ugorji/msgpack:1.3.1 | 1.43 | 1.4 | 3.62 | 2.86 |
| vmihailenco/msgpack:5.4.1 | 1.81 | 1.8 | 3.01 | 2.55 |


### Ops/Sec

| serializer | Average | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|---|
| encoding/gob:go1.24.13 | 33K | 48K | 5.6K | 45K | 8.8K | 0.072M | 17K | 64K | 5.8K | 52K | 7.5K |
| encoding/json:go1.24.13 | 74K | 100K | 1.6K | 130K | 3.2K | 0.3M | 5.3K | 130K | 1.8K | 72K | 1K |
| fxamacker/cbor:2.9.2 | 150K | 190K | 3.2K | 220K | 6K | 0.6M | 14K | 260K | 4.2K | 230K | 5.2K |
| goccy/go-json:0.10.6 | 180K | 310K | 5.8K | 300K | 11K | 0.68M | 18K | 310K | 4.7K | 120K | 1.8K |
| goccy/go-yaml:1.19.2 | 6.3K | 6.9K | 0.064K | 11K | 0.14K | 0.022M | 0.25K | 13K | 0.13K | 9.7K | 0.11K |
| hamba/avro:2.31.0 | 290K | 440K | **12K** | 410K | **20K** | 1M | **52K** | **490K** | **8.8K** | 420K | 14K |
| jsoniter:1.1.12 | 140K | 220K | 4.3K | 250K | 8.3K | 0.49M | 11K | 290K | 4.3K | 86K | 1.3K |
| kelindar/binary:1.0.19 | **310K** | **480K** | 8.9K | **440K** | 14K | **1.3M** | 40K | 380K | 5.6K | 400K | 10K |
| linkedin/goavro:2.15.0 | 220K | 270K | 4K | 310K | 7K | 0.9M | 20K | 280K | 3.8K | 390K | 8.5K |
| mongo-bson:1.17.9 | 80K | 100K | 1.8K | 110K | 3.5K | 0.32M | 7.5K | 140K | 2.3K | 110K | 2.5K |
| pelletier/go-toml:2.4.3 | 67K | 73K | 0.9K | 94K | 1.9K | 0.27M | 3.9K | 150K | 2K | 74K | 1.1K |
| protobuf:1.36.11 | 230K | 290K | 5.9K | 290K | 9.4K | 0.9M | 27K | 330K | 4.5K | **440K** | **18K** |
| segmentio/encoding/json:0.5.4 | 160K | 270K | 5.7K | 280K | 9.3K | 0.63M | 16K | 280K | 4.3K | 110K | 1.9K |
| shamaton/msgpack:3.1.2 | 200K | 230K | 4.7K | 250K | 8.3K | 0.76M | 22K | 410K | 7.6K | 330K | 12K |
| sonic:1.15.2 | 190K | 280K | 6.5K | 280K | 13K | 0.65M | 22K | 430K | 7.2K | 200K | 3.8K |
| ugorji/cbor:1.3.1 | 190K | 240K | 5.1K | 250K | 9.2K | 0.69M | 20K | 340K | 6.8K | 290K | 13K |
| ugorji/json:1.3.1 | 120K | 180K | 4K | 190K | 6.9K | 0.44M | 11K | 240K | 4.8K | 94K | 1.6K |
| ugorji/msgpack:1.3.1 | 190K | 240K | 5.5K | 250K | 9.4K | 0.7M | 22K | 340K | 7.3K | 320K | 14K |
| vmihailenco/msgpack:5.4.1 | 140K | 180K | 3K | 190K | 5.4K | 0.55M | 14K | 300K | 5.7K | 190K | 4.3K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/go/2026-07-24-202008.csv`
    - run=2026-07-24-202008
    - language=go
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: go=go version go1.22.10 linux/amd64, python=3.14.0, node=24.15.0
    - git=40f6a8e dirty
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
