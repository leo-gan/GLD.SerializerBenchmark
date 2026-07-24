# C++ — Benchmark Results

**Generated:** 2026-07-20T12:53:34.778461

This page is a **snapshot of measured numbers** for C++ on one machine. Continuous integration deploys the documentation site; it does **not** re-run analysis when docs are published. Re-running benchmarks on another computer will usually change the numbers a little.

| Topic | Where to read |
|-------|---------------|
| Which libraries we measure, and caveats | [C++ overview](index.md) |
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
| arduinojson:7.2.1 | 2,140 | 114 | 2,030 | 0.0564M | 17.6K | 1836 | **1.00** |
| avro:binary-1.11 | 23.2 | 9.68 | 13.4 | 1.16M | **9.01K** | 1759 | **1.00** |
| avro_c:avro-c | 144 | 66 | 78.1 | 0.269M | **9.01K** | 1813 | **1.00** |
| bitsery:5.2.4 | **13** | 4.25 | 8.71 | **2.04M** | 9.75K | 1799 | **1.00** |
| capnproto:1.0.x | 22.9 | 6.63 | 16.3 | 0.965M | 18.3K | 1765 | **1.00** |
| cereal:1.3.2 | 33.3 | 14 | 19.2 | 0.766M | 14.2K | 1774 | **1.00** |
| cista:0.15 | 27.6 | 4.27 | 23.3 | 1.07M | 15.5K | 1778 | **1.00** |
| custom_binary:harness | 35.1 | 22 | 13 | 0.845M | 11.7K | 1773 | **1.00** |
| flatbuffers:flatbuffers | 22.3 | **0.549** | 21.8 | 1.11M | 10.4K | 1715 | **1.00** |
| flexbuffers:flatbuffers-flex | 185 | 63.2 | 122 | 0.153M | 17.3K | 1784 | **1.00** |
| jsoncons_bson:0.177.0 | 544 | 97.8 | 445 | 0.048M | 20.3K | 1883 | **1.00** |
| jsoncons_cbor:0.177.0 | 516 | 64.6 | 451 | 0.0512M | 13.6K | 1824 | **1.00** |
| jsoncons_msgpack:0.177.0 | 499 | 62.2 | 436 | 0.0517M | 13.5K | 1854 | **1.00** |
| msgpack:msgpack-cxx | 39.7 | 17.6 | 22.1 | 0.584M | 13.5K | 1803 | **1.00** |
| nlohmann_bson:3.11.3 | 371 | 96.8 | 274 | 0.117M | 20.3K | 1806 | **1.00** |
| nlohmann_cbor:3.11.3 | 245 | 51.2 | 193 | 0.131M | 13.6K | 1778 | **1.00** |
| nlohmann_json:3.11.3 | 318 | 80.1 | 238 | 0.0926M | 19.7K | 1752 | **1.00** |
| nlohmann_msgpack:3.11.3 | 251 | 49 | 202 | 0.126M | 13.5K | 1797 | **1.00** |
| nlohmann_ubjson:3.11.3 | 270 | 48.9 | 221 | 0.117M | 15.6K | 1806 | **1.00** |
| protobuf-wire:wire-v2 | 56.6 | 34.6 | 21.9 | 0.655M | 10.4K | 1799 | **1.00** |
| rapidjson:1.1.0 | 571 | 114 | 457 | 0.0598M | 19.7K | 1828 | **1.00** |
| simdjson:3.10.1 | 277 | 6.37 | 271 | 0.112M | 19.7K | 1822 | **1.00** |
| thrift:TBinaryProtocol | 24.8 | 12.6 | 12.2 | 0.988M | 13.6K | 1719 | **1.00** |
| yas:7.x | 13.8 | 5.72 | **8** | 1.42M | 14.2K | 1740 | **1.00** |
| yyjson:0.10.0 | 297 | 25.3 | 272 | 0.103M | 19.7K | 1793 | **1.00** |
| zpp_bits:4.4.25 | 17.5 | 9.14 | 8.4 | 1.65M | 11.7K | 1758 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| arduinojson:7.2.1 | 4.32 | 4.27 | 5.49 | 5.46 |
| avro:binary-1.11 | 0.22 | 0.218 | 0.223 | 0.223 |
| avro_c:avro-c | 0.842 | 0.844 | 0.847 | 0.848 |
| bitsery:5.2.4 | **0.0959** | **0.093** | **0.0975** | **0.097** |
| capnproto:1.0.x | 0.247 | 0.247 | 0.334 | 0.333 |
| cereal:1.3.2 | 0.51 | 0.508 | 0.297 | 0.295 |
| cista:0.15 | 0.184 | 0.184 | 0.195 | 0.194 |
| custom_binary:harness | 0.292 | 0.288 | 0.295 | 0.29 |
| flatbuffers:flatbuffers | 0.229 | 0.229 | 0.236 | 0.237 |
| flexbuffers:flatbuffers-flex | 2.03 | 2.02 | 1.98 | 1.98 |
| jsoncons_bson:0.177.0 | 5.32 | 5.32 | 5.76 | 5.75 |
| jsoncons_cbor:0.177.0 | 5.01 | 4.98 | 5.31 | 5.31 |
| jsoncons_msgpack:0.177.0 | 5.17 | 5.17 | 5.49 | 5.47 |
| msgpack:msgpack-cxx | 0.506 | 0.508 | 0.561 | 0.56 |
| nlohmann_bson:3.11.3 | 1.92 | 1.92 | 2.11 | 2.1 |
| nlohmann_cbor:3.11.3 | 2.06 | 2.06 | 2.23 | 2.23 |
| nlohmann_json:3.11.3 | 2.73 | 2.72 | 3.46 | 3.44 |
| nlohmann_msgpack:3.11.3 | 2.22 | 2.21 | 2.22 | 2.21 |
| nlohmann_ubjson:3.11.3 | 2.19 | 2.17 | 2.39 | 2.38 |
| protobuf-wire:wire-v2 | 0.32 | 0.32 | 0.326 | 0.326 |
| rapidjson:1.1.0 | 3.42 | 3.37 | 6.56 | 6.55 |
| simdjson:3.10.1 | 2.6 | 2.59 | 2.53 | 2.53 |
| thrift:TBinaryProtocol | 0.265 | 0.26 | 0.277 | 0.266 |
| yas:7.x | 0.213 | 0.213 | 0.216 | 0.215 |
| yyjson:0.10.0 | 2.67 | 2.67 | 2.72 | 2.71 |
| zpp_bits:4.4.25 | 0.175 | 0.174 | 0.186 | 0.186 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| arduinojson:7.2.1 | 0.079M | 0.22K | 0.13M | 0.31K | 0.23M | 2K | 0.1M | 0.089K | 0.094M | 0.91K |
| avro:binary-1.11 | 2.2M | 28K | 2.3M | 37K | 4.5M | 140K | 1.2M | 10K | 1.1M | 17K |
| avro_c:avro-c | 0.32M | 3K | 0.49M | 4.4K | 1.2M | 13K | 0.21M | 1.7K | 0.46M | 4.6K |
| bitsery:5.2.4 | **3.5M** | **50K** | 2.3M | 48K | **10M** | **230K** | 1.4M | 15K | 2.6M | **62K** |
| capnproto:1.0.x | 1.6M | 20K | 1.6M | 24K | 4.1M | 220K | 1.1M | 11K | 1.9M | 30K |
| cereal:1.3.2 | 0.83M | 12K | 1.1M | 17K | 2M | 52K | 0.55M | 6K | 1.4M | 27K |
| cista:0.15 | 1.4M | 17K | 1.8M | 24K | 5.4M | 81K | 0.82M | 9.3K | 1.3M | 22K |
| custom_binary:harness | 1.2M | 14K | 1.8M | 24K | 3.4M | 50K | 1M | 8.5K | 0.91M | 11K |
| flatbuffers:flatbuffers | 1.4M | 16K | 1.9M | 24K | 4.4M | 93K | **1.6M** | **16K** | 1.7M | 23K |
| flexbuffers:flatbuffers-flex | 0.14M | 1.5K | 0.26M | 2.9K | 0.49M | 5.7K | 0.28M | 2.6K | 0.33M | 4.1K |
| jsoncons_bson:0.177.0 | 0.061M | 0.68K | 0.098M | 1.2K | 0.19M | 2.2K | 0.071M | 0.77K | 0.066M | 0.73K |
| jsoncons_cbor:0.177.0 | 0.061M | 0.67K | 0.1M | 1.3K | 0.2M | 2.3K | 0.082M | 0.87K | 0.07M | 0.78K |
| jsoncons_msgpack:0.177.0 | 0.063M | 0.72K | 0.11M | 1.3K | 0.19M | 2.3K | 0.086M | 0.91K | 0.071M | 0.78K |
| msgpack:msgpack-cxx | 0.74M | 8.4K | 1.2M | 16K | 2M | 28K | 1.2M | 12K | 1.2M | 15K |
| nlohmann_bson:3.11.3 | 0.13M | 0.92K | 0.24M | 1.7K | 0.52M | 3.8K | 0.14M | 1.1K | 0.18M | 1.6K |
| nlohmann_cbor:3.11.3 | 0.13M | 1.2K | 0.25M | 2.3K | 0.49M | 4.9K | 0.22M | 1.9K | 0.27M | 3K |
| nlohmann_json:3.11.3 | 0.13M | 1.4K | 0.22M | 2.4K | 0.37M | 4.3K | 0.19M | 1.9K | 0.11M | 1.1K |
| nlohmann_msgpack:3.11.3 | 0.13M | 1.1K | 0.23M | 2.2K | 0.45M | 4.7K | 0.2M | 1.8K | 0.26M | 3K |
| nlohmann_ubjson:3.11.3 | 0.13M | 1.2K | 0.22M | 2.1K | 0.46M | 4.6K | 0.17M | 1.6K | 0.26M | 3K |
| protobuf-wire:wire-v2 | 0.63M | 6.1K | 0.98M | 10K | 3.1M | 30K | 1.1M | 8.1K | 0.74M | 7.4K |
| rapidjson:1.1.0 | 0.086M | 1K | 0.18M | 1.9K | 0.29M | 3K | 0.14M | 1.4K | 0.078M | 0.78K |
| simdjson:3.10.1 | 0.14M | 1.5K | 0.25M | 2.7K | 0.39M | 4.6K | 0.23M | 2K | 0.1M | 1.1K |
| thrift:TBinaryProtocol | 1.5M | 19K | 1.9M | 28K | 3.8M | 79K | 1.3M | 10K | 1.4M | 19K |
| yas:7.x | 2.2M | 48K | 2.5M | **54K** | 4.7M | 150K | 1.4M | 14K | 3.3M | 53K |
| yyjson:0.10.0 | 0.13M | 1.3K | 0.23M | 2.5K | 0.37M | 4.2K | 0.19M | 1.9K | 0.094M | 0.99K |
| zpp_bits:4.4.25 | 2.4M | 21K | **2.7M** | 34K | 5.7M | 160K | 1.4M | 14K | **4.2M** | 56K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/cpp/2026-07-20-125238.csv`
    - run=2026-07-20-125238
    - language=cpp
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: g++=g++ (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, python=3.14.0, node=24.15.0
    - git=61a38cf dirty
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
