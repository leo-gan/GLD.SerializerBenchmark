# C++ — Benchmark Results

**Generated:** 2026-07-24T20:24:20.311355

This page is a **snapshot of measured numbers** for C++ on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [C++ overview](index.md) |
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

> **Stream honesty:** stream rows labeled as **native** 130, **adapted** 130. Only **`native`** (and carefully **`text_on_stream`**) support stream-API performance claims. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).


## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| arduinojson:7.2.1 | 2,190 | 112 | 2,070 | 49.6K | 17.6K | 1823 | **1.00** |
| avro:binary-1.11 | 29.7 | 13.5 | 15.9 | 579K | **9.01K** | 1813 | **1.00** |
| avro_c:avro-c | 136 | 61.2 | 74.1 | 150K | **9.01K** | 1810 | **1.00** |
| bitsery:5.2.4 | **18.1** | 6.8 | 11 | **897K** | 9.75K | 1801 | **1.00** |
| capnproto:1.0.x | 30.7 | 10.8 | 19.3 | 391K | 18.3K | 1821 | **1.00** |
| cereal:1.3.2 | 37.4 | 15.5 | 21.4 | 335K | 14.2K | 1805 | **1.00** |
| cista:0.15 | 35.1 | 5.9 | 28.7 | 563K | 15.5K | 1822 | **1.00** |
| custom_binary:harness | 39.4 | 24.2 | 14.9 | 531K | 11.7K | 1857 | **1.00** |
| flatbuffers:flatbuffers | 27.3 | **3.24** | 23.7 | 503K | 10.4K | 1867 | **1.00** |
| flexbuffers:flatbuffers-flex | 180 | 60.2 | 119 | 111K | 17.3K | 1834 | **1.00** |
| jsoncons_bson:0.177.0 | 528 | 98.2 | 428 | 41K | 20.3K | 1855 | **1.00** |
| jsoncons_cbor:0.177.0 | 499 | 65.8 | 432 | 42.9K | 13.6K | 1889 | **1.00** |
| jsoncons_msgpack:0.177.0 | 481 | 62.9 | 418 | 44.3K | 13.5K | 1902 | **1.00** |
| msgpack:msgpack-cxx | 44.6 | 19 | 24.9 | 284K | 13.5K | 1817 | **1.00** |
| nlohmann_bson:3.11.3 | 360 | 90.2 | 269 | 88.4K | 20.3K | 1846 | **1.00** |
| nlohmann_cbor:3.11.3 | 233 | 46.8 | 186 | 98.9K | 13.6K | 1850 | **1.00** |
| nlohmann_json:3.11.3 | 308 | 80.6 | 226 | 74.9K | 19.7K | 1838 | **1.00** |
| nlohmann_msgpack:3.11.3 | 237 | 45.9 | 190 | 96.9K | 13.5K | 1836 | **1.00** |
| nlohmann_ubjson:3.11.3 | 262 | 45.8 | 216 | 90K | 15.6K | 1846 | **1.00** |
| protobuf-wire:wire-v2 | 62.1 | 38.5 | 23.3 | 438K | 10.4K | 1885 | **1.00** |
| rapidjson:1.1.0 | 534 | 105 | 429 | 48.5K | 19.7K | 1854 | **1.00** |
| simdjson:3.10.1 | 267 | 4.22 | 260 | 90.9K | 19.7K | 1790 | **1.00** |
| thrift:TBinaryProtocol | 29.3 | 15.2 | 13.8 | 482K | 13.6K | 1786 | **1.00** |
| yas:7.x | 19.1 | 8.55 | **10.3** | 499K | 14.2K | 1849 | **1.00** |
| yyjson:0.10.0 | 287 | 23.5 | 263 | 85.7K | 19.7K | 1787 | **1.00** |
| zpp_bits:4.4.25 | 23.3 | 12.6 | 10.4 | 676K | 11.7K | 1808 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| arduinojson:7.2.1 | 5.05 | 5.02 | 6.93 | 6.95 |
| avro:binary-1.11 | 0.494 | 0.492 | 0.511 | 0.513 |
| avro_c:avro-c | 1.85 | 1.85 | 1.92 | 1.94 |
| bitsery:5.2.4 | **0.244** | **0.246** | **0.275** | **0.274** |
| capnproto:1.0.x | 0.659 | 0.65 | 0.891 | 0.881 |
| cereal:1.3.2 | 1.31 | 1.3 | 0.792 | 0.788 |
| cista:0.15 | 0.389 | 0.384 | 0.404 | 0.406 |
| custom_binary:harness | 0.442 | 0.442 | 0.527 | 0.53 |
| flatbuffers:flatbuffers | 0.592 | 0.582 | 0.624 | 0.624 |
| flexbuffers:flatbuffers-flex | 3.13 | 3.13 | 3.09 | 3.08 |
| jsoncons_bson:0.177.0 | 6.29 | 6.32 | 6.99 | 6.95 |
| jsoncons_cbor:0.177.0 | 6.19 | 6.22 | 6.9 | 6.93 |
| jsoncons_msgpack:0.177.0 | 6 | 5.97 | 6.72 | 6.73 |
| msgpack:msgpack-cxx | 1.12 | 1.11 | 1.34 | 1.34 |
| nlohmann_bson:3.11.3 | 2.84 | 2.82 | 3.05 | 3.02 |
| nlohmann_cbor:3.11.3 | 2.82 | 2.84 | 3.2 | 3.18 |
| nlohmann_json:3.11.3 | 3.63 | 3.6 | 4.41 | 4.35 |
| nlohmann_msgpack:3.11.3 | 2.98 | 2.98 | 3.2 | 3.18 |
| nlohmann_ubjson:3.11.3 | 3.1 | 3.1 | 3.41 | 3.38 |
| protobuf-wire:wire-v2 | 0.528 | 0.534 | 0.554 | 0.554 |
| rapidjson:1.1.0 | 4.73 | 4.7 | 8.39 | 8.35 |
| simdjson:3.10.1 | 3.2 | 3.2 | 3.26 | 3.24 |
| thrift:TBinaryProtocol | 0.614 | 0.62 | 0.643 | 0.643 |
| yas:7.x | 0.629 | 0.628 | 0.665 | 0.67 |
| yyjson:0.10.0 | 3.46 | 3.44 | 3.35 | 3.34 |
| zpp_bits:4.4.25 | 0.455 | 0.459 | 0.473 | 0.474 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| arduinojson:7.2.1 | 0.07M | 0.19K | 0.12M | 0.3K | 0.2M | 2K | 91K | 0.094K | 0.092M | 0.95K |
| avro:binary-1.11 | 1.1M | 19K | 1.1M | 20K | 2M | 71K | 780K | 8.8K | 0.8M | 16K |
| avro_c:avro-c | 0.2M | 3.2K | 0.3M | 4.5K | 0.54M | 12K | 160K | 2.1K | 0.3M | 4.4K |
| bitsery:5.2.4 | **1.6M** | **34K** | **1.3M** | 26K | **4.1M** | 100K | 800K | 12K | 1.3M | **46K** |
| capnproto:1.0.x | 0.56M | 16K | 0.67M | 16K | 1.5M | **110K** | 510K | 8.7K | 0.89M | 22K |
| cereal:1.3.2 | 0.39M | 12K | 0.46M | 14K | 0.76M | 39K | 330K | 5.9K | 0.58M | 22K |
| cista:0.15 | 0.81M | 14K | 0.96M | 16K | 2.6M | 52K | 440K | 7.1K | 0.84M | 18K |
| custom_binary:harness | 0.84M | 13K | 1M | 16K | 2.3M | 45K | 630K | 7.5K | 0.76M | 11K |
| flatbuffers:flatbuffers | 0.65M | 15K | 0.84M | 18K | 1.7M | 61K | 740K | **12K** | 1.1M | 20K |
| flexbuffers:flatbuffers-flex | 0.11M | 1.5K | 0.2M | 3K | 0.32M | 5.4K | 230K | 2.9K | 0.24M | 4K |
| jsoncons_bson:0.177.0 | 0.052M | 0.72K | 0.085M | 1.3K | 0.16M | 2.3K | 62K | 0.79K | 0.061M | 0.74K |
| jsoncons_cbor:0.177.0 | 0.052M | 0.73K | 0.089M | 1.3K | 0.16M | 2.3K | 72K | 0.9K | 0.065M | 0.8K |
| jsoncons_msgpack:0.177.0 | 0.055M | 0.76K | 0.093M | 1.4K | 0.17M | 2.4K | 74K | 0.94K | 0.066M | 0.81K |
| msgpack:msgpack-cxx | 0.37M | 8.4K | 0.55M | 13K | 0.89M | 24K | 520K | 10K | 0.65M | 14K |
| nlohmann_bson:3.11.3 | 0.1M | 0.94K | 0.18M | 1.8K | 0.35M | 3.7K | 120K | 1.1K | 0.16M | 1.6K |
| nlohmann_cbor:3.11.3 | 0.1M | 1.3K | 0.19M | 2.4K | 0.35M | 4.8K | 160K | 2K | 0.23M | 3K |
| nlohmann_json:3.11.3 | 0.11M | 1.4K | 0.19M | 2.7K | 0.28M | 4.2K | 160K | 2K | 0.097M | 1.1K |
| nlohmann_msgpack:3.11.3 | 0.098M | 1.3K | 0.18M | 2.3K | 0.34M | 4.6K | 150K | 1.8K | 0.23M | 3K |
| nlohmann_ubjson:3.11.3 | 0.098M | 1.3K | 0.17M | 2.2K | 0.32M | 4.3K | 130K | 1.6K | 0.22M | 2.9K |
| protobuf-wire:wire-v2 | 0.45M | 6K | 0.68M | 8.7K | 1.9M | 25K | 770K | 6.7K | 0.61M | 7.2K |
| rapidjson:1.1.0 | 0.079M | 1.1K | 0.14M | 2K | 0.21M | 3.1K | 110K | 1.5K | 0.074M | 0.81K |
| simdjson:3.10.1 | 0.11M | 1.4K | 0.21M | 2.9K | 0.31M | 4.4K | 180K | 2.2K | 0.094M | 1.1K |
| thrift:TBinaryProtocol | 0.74M | 17K | 0.84M | 18K | 1.6M | 47K | 740K | 9.9K | 0.83M | 18K |
| yas:7.x | 0.73M | 31K | 0.85M | **27K** | 1.6M | 92K | 620K | 12K | 1.1M | 44K |
| yyjson:0.10.0 | 0.1M | 1.4K | 0.2M | 2.6K | 0.29M | 4.2K | 160K | 1.9K | 0.092M | 1K |
| zpp_bits:4.4.25 | 1.1M | 17K | 1.1M | 20K | 2.2M | 79K | **830K** | 11K | **1.5M** | 36K |

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
    
    - **Source CSV:** `logs/cpp/2026-07-24-202051.csv`
    - run=2026-07-24-202051
    - language=cpp
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: g++=g++ (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, python=3.14.0, node=24.15.0
    - git=40f6a8e dirty
    - seed=42
    - warmup_reps=1
    - serializers=26
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
      - `jsoncons_bson` @ 0.177.0
      - `jsoncons_cbor` @ 0.177.0
      - `jsoncons_msgpack` @ 0.177.0
      - `msgpack` @ msgpack-cxx
      - `nlohmann_bson` @ 3.11.3
      - `nlohmann_cbor` @ 3.11.3
      - `nlohmann_json` @ 3.11.3
      - `nlohmann_msgpack` @ 3.11.3
      - `nlohmann_ubjson` @ 3.11.3
      - `protobuf-wire` @ wire-v2
      - `rapidjson` @ 1.1.0
      - `simdjson` @ 3.10.1
      - `thrift` @ TBinaryProtocol
      - `yas` @ 7.x
      - `yyjson` @ 0.10.0
      - `zpp_bits` @ 4.4.25
