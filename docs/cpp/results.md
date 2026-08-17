# C++ — Benchmark Results

**Generated:** 2026-08-17T13:15:01.138875

This page is a **snapshot of measured numbers** for C++ on **one machine, one session** (claim level **L1**). Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little. Stronger multi-session / multi-machine claims need more evidence — see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [C++ overview](index.md) |
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

> **Stream honesty:** stream rows labeled as **native** 140, **adapted** 150. Only **`native`** (and carefully **`text_on_stream`**) support stream-API performance claims. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) |
|---|---|---|---|---|---|
| arduinojson:7.2.1 | 2,360 | 110 | 2,250 | 38K | 17.6K |
| avro:binary-1.11 | 30.7 | 13.8 | 16.8 | 346K | **9.01K** |
| avro_c:avro-c | 140 | 62.4 | 77.8 | 95.1K | **9.01K** |
| bitsery:5.2.4 | **19.2** | 7.17 | 12 | **515K** | 9.75K |
| capnproto:1.0.x | 33.4 | 11.6 | 21.8 | 256K | 18.3K |
| cereal:1.3.2 | 38.3 | 17.5 | 20.6 | 236K | 14.2K |
| cista:0.15 | 35.3 | 6.3 | 28.9 | 374K | 15.5K |
| custom_binary:harness | 40.3 | 24.7 | 15.5 | 338K | 11.7K |
| flatbuffers:flatbuffers | 27.1 | **2.04** | 25 | 425K | 10.4K |
| flexbuffers:flatbuffers-flex | 184 | 62 | 122 | 72.3K | 17.3K |
| glaze:2.9.5 | 61.8 | 25.2 | 36.5 | 238K | 19.7K |
| jsoncons_bson:0.177.0 | 333 | 143 | 190 | 46.8K | 20.3K |
| jsoncons_cbor:0.177.0 | 298 | 106 | 192 | 49.8K | 13.6K |
| jsoncons_msgpack:0.177.0 | 281 | 101 | 179 | 51.3K | 13.5K |
| msgpack:msgpack-cxx | 48 | 21.2 | 26.8 | 197K | 13.5K |
| nlohmann_bson:3.11.3 | 372 | 95.4 | 275 | 64.9K | 20.3K |
| nlohmann_cbor:3.11.3 | 244 | 51.4 | 192 | 72.2K | 13.6K |
| nlohmann_json:3.11.3 | 327 | 95.7 | 230 | 57K | 19.7K |
| nlohmann_msgpack:3.11.3 | 250 | 52.4 | 197 | 71.4K | 13.5K |
| nlohmann_ubjson:3.11.3 | 271 | 49.5 | 221 | 67.4K | 15.6K |
| protobuf:3.12.4 | 43.3 | 19.8 | 23.6 | 363K | 10.1K |
| protobuf-wire:wire-v2 | 62.9 | 38.7 | 24.2 | 272K | 10.4K |
| rapidjson:1.1.0 | 542 | 102 | 439 | 38.5K | 19.7K |
| simdjson:3.10.1 | 277 | 4.11 | 273 | 56.2K | 19.7K |
| thrift:TBinaryProtocol | 29.9 | 15.2 | 14.5 | 304K | 13.6K |
| yaml-cpp:0.8.0 | 5,790 | 2,430 | 3,350 | 4.79K | 24.2K |
| yas:7.x | 19.9 | 8.44 | **11.4** | 447K | 14.2K |
| yyjson:0.10.0 | 296 | 23.9 | 272 | 60.1K | 19.7K |
| zpp_bits:4.4.25 | 24.6 | 13.1 | 11.4 | 403K | 11.7K |


### Total Time

| serializer | bytes mode/mean (µs) | bytes mode/median (µs) | stream mode/mean (µs) | stream mode/median (µs) |
|---|---|---|---|---|
| arduinojson:7.2.1 | 8.22 | 8.22 | 9.97 | 9.9 |
| avro:binary-1.11 | 0.835 | 0.84 | 1.07 | 1.07 |
| avro_c:avro-c | 3.1 | 3.05 | 3.67 | 3.65 |
| bitsery:5.2.4 | **0.469** | **0.469** | **0.619** | **0.62** |
| capnproto:1.0.x | 0.967 | 0.97 | 1.69 | 1.73 |
| cereal:1.3.2 | 2 | 2.01 | 1.39 | 1.39 |
| cista:0.15 | 0.623 | 0.629 | 0.779 | 0.751 |
| custom_binary:harness | 0.835 | 0.838 | 0.952 | 0.951 |
| flatbuffers:flatbuffers | 0.769 | 0.763 | 0.858 | 0.865 |
| flexbuffers:flatbuffers-flex | 5.36 | 5.37 | 5.72 | 5.78 |
| glaze:2.9.5 | 1.22 | 1.23 | 1.51 | 1.52 |
| jsoncons_bson:0.177.0 | 6.47 | 6.38 | 8.25 | 8.21 |
| jsoncons_cbor:0.177.0 | 6.76 | 6.65 | 8.19 | 8.15 |
| jsoncons_msgpack:0.177.0 | 6.5 | 6.43 | 7.97 | 7.94 |
| msgpack:msgpack-cxx | 1.94 | 1.95 | 2.45 | 2.46 |
| nlohmann_bson:3.11.3 | 4.45 | 4.46 | 4.96 | 4.89 |
| nlohmann_cbor:3.11.3 | 4.42 | 4.36 | 4.98 | 4.92 |
| nlohmann_json:3.11.3 | 5.54 | 5.53 | 6.51 | 6.49 |
| nlohmann_msgpack:3.11.3 | 4.67 | 4.62 | 4.86 | 4.85 |
| nlohmann_ubjson:3.11.3 | 4.72 | 4.7 | 5.37 | 5.36 |
| protobuf:3.12.4 | 0.73 | 0.732 | 0.941 | 0.974 |
| protobuf-wire:wire-v2 | 1 | 1.01 | 1.14 | 1.16 |
| rapidjson:1.1.0 | 6.6 | 6.58 | 11.6 | 11.5 |
| simdjson:3.10.1 | 6.18 | 6.13 | 6.69 | 6.69 |
| thrift:TBinaryProtocol | 1.01 | 1.01 | 1.21 | 1.24 |
| yaml-cpp:0.8.0 | 60.3 | 60.6 | 62.1 | 61.9 |
| yas:7.x | 0.772 | 0.776 | 0.937 | 0.932 |
| yyjson:0.10.0 | 5.38 | 5.42 | 5.7 | 5.67 |
| zpp_bits:4.4.25 | 0.841 | 0.843 | 0.937 | 0.951 |


### Ops/Sec

| serializer | Average | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|---|
| arduinojson:7.2.1 | 42K | 0.057M | 0.17K | 93K | 0.28K | 0.12M | 1.8K | 77K | 0.088K | 69K | 0.85K |
| avro:binary-1.11 | 360K | 0.58M | 17K | 690K | 21K | 1.2M | 74K | 490K | 8.7K | 530K | 15K |
| avro_c:avro-c | 99K | 0.14M | 3K | 180K | 4.3K | 0.32M | 11K | 130K | 2K | 200K | 4.5K |
| bitsery:5.2.4 | **550K** | **1.1M** | **31K** | 720K | 30K | **2.1M** | **120K** | 540K | 12K | 750K | **40K** |
| capnproto:1.0.x | 300K | 0.45M | 15K | 470K | 17K | 1M | 96K | 390K | 8.5K | 460K | 19K |
| cereal:1.3.2 | 190K | 0.3M | 11K | 340K | 14K | 0.5M | 36K | 260K | 5.8K | 380K | 20K |
| cista:0.15 | 390K | 0.6M | 13K | 710K | 18K | 1.6M | 54K | 380K | 7.2K | 530K | 18K |
| custom_binary:harness | 350K | 0.56M | 12K | 670K | 17K | 1.2M | 40K | 440K | 7.8K | 520K | 10K |
| flatbuffers:flatbuffers | 440K | 0.67M | 15K | 770K | 21K | 1.3M | 69K | **720K** | **12K** | 770K | 19K |
| flexbuffers:flatbuffers-flex | 73K | 0.069M | 1.6K | 130K | 2.8K | 0.19M | 5.2K | 170K | 2.8K | 160K | 3.9K |
| glaze:2.9.5 | 250K | 0.38M | 9.5K | 530K | 14K | 0.82M | 21K | 420K | 6.7K | 280K | 4.4K |
| jsoncons_bson:0.177.0 | 50K | 0.058M | 1K | 92K | 1.7K | 0.15M | 3.1K | 76K | 1.1K | 110K | 2.2K |
| jsoncons_cbor:0.177.0 | 52K | 0.057M | 0.99K | 95K | 1.8K | 0.15M | 3.4K | 91K | 1.4K | 120K | 2.8K |
| jsoncons_msgpack:0.177.0 | 54K | 0.06M | 1.1K | 98K | 1.9K | 0.15M | 3.6K | 94K | 1.4K | 120K | 2.8K |
| msgpack:msgpack-cxx | 210K | 0.29M | 7.4K | 400K | 12K | 0.52M | 21K | 430K | 8.5K | 410K | 12K |
| nlohmann_bson:3.11.3 | 67K | 0.079M | 0.92K | 130K | 1.7K | 0.22M | 3.5K | 110K | 1.1K | 130K | 1.5K |
| nlohmann_cbor:3.11.3 | 75K | 0.079M | 1.3K | 140K | 2.2K | 0.23M | 4.5K | 130K | 1.9K | 160K | 2.8K |
| nlohmann_json:3.11.3 | 61K | 0.083M | 1.4K | 140K | 2.2K | 0.18M | 3.9K | 130K | 1.8K | 78K | 1.1K |
| nlohmann_msgpack:3.11.3 | 72K | 0.079M | 1.3K | 130K | 2.1K | 0.21M | 4.2K | 120K | 1.7K | 160K | 2.7K |
| nlohmann_ubjson:3.11.3 | 70K | 0.079M | 1.2K | 130K | 2.1K | 0.21M | 4.1K | 110K | 1.6K | 160K | 2.8K |
| protobuf:3.12.4 | 380K | 0.49M | 11K | 570K | 12K | 1.4M | 45K | 370K | 5K | **910K** | 33K |
| protobuf-wire:wire-v2 | 280K | 0.33M | 6.1K | 470K | 8.9K | 1M | 26K | 500K | 6.4K | 440K | 6.8K |
| rapidjson:1.1.0 | 48K | 0.064M | 1.1K | 110K | 1.9K | 0.15M | 3K | 96K | 1.5K | 55K | 0.79K |
| simdjson:3.10.1 | 57K | 0.078M | 1.4K | 130K | 2.7K | 0.16M | 4K | 120K | 2.1K | 67K | 1.1K |
| thrift:TBinaryProtocol | 310K | 0.47M | 17K | 510K | 19K | 0.99M | 50K | 470K | 9.5K | 560K | 18K |
| yaml-cpp:0.8.0 | 4.8K | 0.0062M | 0.069K | 12K | 0.14K | 0.017M | 0.22K | 8.2K | 0.089K | 5K | 0.051K |
| yas:7.x | 460K | 0.83M | 29K | **830K** | **30K** | 1.3M | 110K | 570K | 11K | 850K | 39K |
| yyjson:0.10.0 | 61K | 0.078M | 1.4K | 140K | 2.4K | 0.19M | 3.8K | 120K | 1.9K | 73K | 1K |
| zpp_bits:4.4.25 | 410K | 0.66M | 17K | 720K | 23K | 1.2M | 84K | 520K | 11K | 890K | 34K |

## Latency distributions

Each figure is a picture of **how long** serialize and deserialize took across many trials for one **data type** (and batch size):

- **Left — mean bars:** average serialize time and average deserialize time in microseconds (scale starts at 0).
- **Right — split violins:** the full distribution of sample times (thickness shows where trials cluster).
- **Top 5 only:** charts show the five fastest serializers by mean total time for that data type so the picture stays readable. Tables above still list everyone.
- Each image also prints the data type, source CSV, modes, and sample size.

### Document · 1 instance

![Document · 1 instance](../analysis/plots/violin/cpp_document@n=1.png){ width="80%" }

### Document · 100 instances

![Document · 100 instances](../analysis/plots/violin/cpp_document@n=100.png){ width="80%" }

### Event · 1 instance

![Event · 1 instance](../analysis/plots/violin/cpp_event@n=1.png){ width="80%" }

### Event · 100 instances

![Event · 100 instances](../analysis/plots/violin/cpp_event@n=100.png){ width="80%" }

### Message · 1 instance

![Message · 1 instance](../analysis/plots/violin/cpp_message@n=1.png){ width="80%" }

### Message · 100 instances

![Message · 100 instances](../analysis/plots/violin/cpp_message@n=100.png){ width="80%" }

### Strings · 1 instance

![Strings · 1 instance](../analysis/plots/violin/cpp_strings@n=1.png){ width="80%" }

### Strings · 100 instances

![Strings · 100 instances](../analysis/plots/violin/cpp_strings@n=100.png){ width="80%" }

### Telemetry · 1 instance

![Telemetry · 1 instance](../analysis/plots/violin/cpp_telemetry@n=1.png){ width="80%" }

### Telemetry · 100 instances

![Telemetry · 100 instances](../analysis/plots/violin/cpp_telemetry@n=100.png){ width="80%" }

## How to regenerate this page

Snapshots are produced on a developer machine. After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):

```bash
analyze-benchmarks              # all languages
analyze-benchmarks -l cpp   # this language only
```

That refreshes this language’s tables and the latency images under `docs/analysis/plots/violin/`. The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** link index and is not rewritten by the CLI. Commit updated `results.md` and plot files when you want them on the site.


## Run configuration (important)

??? note "Show host, seed, serializers, and source CSV"

    These fields come from the run sidecar next to the CSV (`*.configs.json`, or older `*.environment.json` files). They describe the machine and the run setup, not the timing formulas. For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/cpp/2026-08-17-131333.csv`
    - run=2026-08-17-131333
    - language=cpp
    - os=Linux 6.8.0-136-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: g++=g++ (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, python=3.14.0, node=24.15.0
    - git=312b040 dirty
    - seed=42
    - warmup_reps=1
    - serializers=29
    - metrics_profile=multi_way
    - **Data types (config):** message, document, telemetry, strings, event
    - **Serializers (from CSV):**
      - `arduinojson` @ 7.2.1
      - `avro` @ binary-1.11
      - `avro_c` @ avro-c
      - `bitsery` @ 5.2.4
      - `capnproto` @ 1.0.x
      - `cereal` @ 1.3.2
      - `cista` @ 0.15
      - `custom_binary` @ harness
      - `flatbuffers` @ flatbuffers
      - `flexbuffers` @ flatbuffers-flex
      - `glaze` @ 2.9.5
      - `jsoncons_bson` @ 0.177.0
      - `jsoncons_cbor` @ 0.177.0
      - `jsoncons_msgpack` @ 0.177.0
      - `msgpack` @ msgpack-cxx
      - `nlohmann_bson` @ 3.11.3
      - `nlohmann_cbor` @ 3.11.3
      - `nlohmann_json` @ 3.11.3
      - `nlohmann_msgpack` @ 3.11.3
      - `nlohmann_ubjson` @ 3.11.3
      - `protobuf` @ 3.12.4
      - `protobuf-wire` @ wire-v2
      - `rapidjson` @ 1.1.0
      - `simdjson` @ 3.10.1
      - `thrift` @ TBinaryProtocol
      - `yaml-cpp` @ 0.8.0
      - `yas` @ 7.x
      - `yyjson` @ 0.10.0
      - `zpp_bits` @ 4.4.25
