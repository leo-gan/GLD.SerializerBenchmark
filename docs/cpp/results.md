# C++ — Benchmark Results

**Generated:** 2026-07-24T15:54:51.745639

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

## Summary tables

### Summary

One row per serializer (averaged across data types; bytes mode preferred when both exist). Only **high-importance** columns appear here by default ([Metrics catalog](../analysis/METRICS.md)). Times are **µs**. **Bold** = best in that column.

| serializer | Median total (µs) | Median ser (µs) | Median deser (µs) | Ops/s (from mean) | Median size (B) | Samples | Fidelity |
|---|---|---|---|---|---|---|---|
| arduinojson:7.2.1 | 1,970 | 106 | 1,860 | 0.0609M | 17.6K | 1803 | **1.00** |
| avro:binary-1.11 | 20.6 | 8.66 | 11.9 | 1.26M | **9.01K** | 1717 | **1.00** |
| avro_c:avro-c | 127 | 56.7 | 70.4 | 0.291M | **9.01K** | 1787 | **1.00** |
| bitsery:5.2.4 | **12.3** | 4.04 | 8.25 | **2.28M** | 9.75K | 1734 | **1.00** |
| capnproto:1.0.x | 21.3 | 6.16 | 15.2 | 1.04M | 18.3K | 1758 | **1.00** |
| cereal:1.3.2 | 31.6 | 13.2 | 18.2 | 0.834M | 14.2K | 1767 | **1.00** |
| cista:0.15 | 26.2 | 4.13 | 22 | 1.17M | 15.5K | 1766 | **1.00** |
| custom_binary:harness | 33 | 20.8 | 12.3 | 0.897M | 11.7K | 1752 | **1.00** |
| flatbuffers:flatbuffers | 20.9 | **0.507** | 20.4 | 1.22M | 10.4K | 1746 | **1.00** |
| flexbuffers:flatbuffers-flex | 172 | 57.9 | 114 | 0.168M | 17.3K | 1814 | **1.00** |
| jsoncons_bson:0.177.0 | 511 | 92.1 | 418 | 0.05M | 20.3K | 1859 | **1.00** |
| jsoncons_cbor:0.177.0 | 489 | 62.7 | 426 | 0.0546M | 13.6K | 1821 | **1.00** |
| jsoncons_msgpack:0.177.0 | 471 | 59 | 412 | 0.056M | 13.5K | 1845 | **1.00** |
| msgpack:msgpack-cxx | 37.2 | 16.6 | 20.6 | 0.616M | 13.5K | 1755 | **1.00** |
| nlohmann_bson:3.11.3 | 347 | 90 | 257 | 0.128M | 20.3K | 1792 | **1.00** |
| nlohmann_cbor:3.11.3 | 228 | 47.2 | 181 | 0.143M | 13.6K | 1825 | **1.00** |
| nlohmann_json:3.11.3 | 298 | 75.4 | 223 | 0.1M | 19.7K | 1775 | **1.00** |
| nlohmann_msgpack:3.11.3 | 231 | 45.8 | 185 | 0.14M | 13.5K | 1817 | **1.00** |
| nlohmann_ubjson:3.11.3 | 263 | 46.1 | 217 | 0.124M | 15.6K | 1818 | **1.00** |
| protobuf-wire:wire-v2 | 53.1 | 32.6 | 20.5 | 0.705M | 10.4K | 1773 | **1.00** |
| rapidjson:1.1.0 | 533 | 106 | 426 | 0.0634M | 19.7K | 1782 | **1.00** |
| simdjson:3.10.1 | 258 | 8.37 | 250 | 0.121M | 19.7K | 1752 | **1.00** |
| thrift:TBinaryProtocol | 22.9 | 11.6 | 11.2 | 1.07M | 13.6K | 1772 | **1.00** |
| yas:7.x | 12.7 | 5.06 | **7.62** | 1.55M | 14.2K | 1687 | **1.00** |
| yyjson:0.10.0 | 282 | 23.3 | 258 | 0.112M | 19.7K | 1790 | **1.00** |
| zpp_bits:4.4.25 | 16.5 | 8.54 | 7.92 | 1.81M | 11.7K | 1711 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| arduinojson:7.2.1 | 4.02 | 4 | 5.24 | 5.21 |
| avro:binary-1.11 | 0.198 | 0.197 | 0.203 | 0.203 |
| avro_c:avro-c | 0.766 | 0.764 | 0.765 | 0.766 |
| bitsery:5.2.4 | **0.0793** | **0.079** | **0.0898** | **0.086** |
| capnproto:1.0.x | 0.225 | 0.225 | 0.307 | 0.306 |
| cereal:1.3.2 | 0.448 | 0.445 | 0.269 | 0.268 |
| cista:0.15 | 0.168 | 0.168 | 0.175 | 0.174 |
| custom_binary:harness | 0.27 | 0.266 | 0.266 | 0.264 |
| flatbuffers:flatbuffers | 0.206 | 0.208 | 0.216 | 0.217 |
| flexbuffers:flatbuffers-flex | 1.83 | 1.83 | 1.84 | 1.84 |
| jsoncons_bson:0.177.0 | 5.21 | 5.17 | 5.57 | 5.62 |
| jsoncons_cbor:0.177.0 | 4.49 | 4.47 | 5.32 | 5.3 |
| jsoncons_msgpack:0.177.0 | 4.7 | 4.68 | 4.92 | 4.92 |
| msgpack:msgpack-cxx | 0.451 | 0.45 | 0.49 | 0.49 |
| nlohmann_bson:3.11.3 | 1.67 | 1.67 | 1.79 | 1.79 |
| nlohmann_cbor:3.11.3 | 1.78 | 1.78 | 1.85 | 1.85 |
| nlohmann_json:3.11.3 | 2.47 | 2.47 | 3.01 | 3.01 |
| nlohmann_msgpack:3.11.3 | 1.86 | 1.86 | 1.9 | 1.9 |
| nlohmann_ubjson:3.11.3 | 2.05 | 2.05 | 2.11 | 2.08 |
| protobuf-wire:wire-v2 | 0.29 | 0.289 | 0.299 | 0.297 |
| rapidjson:1.1.0 | 3.25 | 3.26 | 5.85 | 5.84 |
| simdjson:3.10.1 | 2.32 | 2.32 | 2.33 | 2.33 |
| thrift:TBinaryProtocol | 0.25 | 0.244 | 0.245 | 0.238 |
| yas:7.x | 0.189 | 0.19 | 0.193 | 0.192 |
| yyjson:0.10.0 | 2.41 | 2.41 | 2.29 | 2.23 |
| zpp_bits:4.4.25 | 0.145 | 0.144 | 0.159 | 0.159 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| arduinojson:7.2.1 | 0.083M | 0.22K | 0.15M | 0.34K | 0.25M | 2.1K | 0.11M | 0.099K | 0.1M | 0.98K |
| avro:binary-1.11 | 2.3M | 30K | 2.5M | 40K | 5M | 150K | 1.4M | 12K | 1.1M | 18K |
| avro_c:avro-c | 0.33M | 3.4K | 0.53M | 5.1K | 1.3M | 13K | 0.23M | 2K | 0.49M | 4.9K |
| bitsery:5.2.4 | **3.9M** | **52K** | 2.5M | 53K | **13M** | **230K** | 1.4M | 16K | 2.8M | **66K** |
| capnproto:1.0.x | 1.7M | 22K | 1.8M | 26K | 4.5M | 230K | 1.2M | 12K | 2M | 31K |
| cereal:1.3.2 | 0.84M | 13K | 1.2M | 18K | 2.2M | 53K | 0.61M | 6.4K | 1.5M | 29K |
| cista:0.15 | 1.5M | 18K | 1.9M | 25K | 5.9M | 82K | 0.89M | 9.6K | 1.5M | 23K |
| custom_binary:harness | 1.1M | 15K | 1.9M | 25K | 3.7M | 53K | 1.2M | 9K | 0.96M | 12K |
| flatbuffers:flatbuffers | 1.5M | 17K | 2M | 25K | 4.8M | 91K | **1.8M** | **18K** | 2M | 24K |
| flexbuffers:flatbuffers-flex | 0.15M | 1.6K | 0.29M | 3K | 0.55M | 5.9K | 0.31M | 2.9K | 0.37M | 4.3K |
| jsoncons_bson:0.177.0 | 0.06M | 0.73K | 0.1M | 1.3K | 0.19M | 2.3K | 0.075M | 0.8K | 0.071M | 0.78K |
| jsoncons_cbor:0.177.0 | 0.062M | 0.72K | 0.11M | 1.3K | 0.22M | 2.3K | 0.09M | 0.93K | 0.078M | 0.83K |
| jsoncons_msgpack:0.177.0 | 0.065M | 0.77K | 0.11M | 1.4K | 0.21M | 2.4K | 0.094M | 0.96K | 0.075M | 0.83K |
| msgpack:msgpack-cxx | 0.76M | 9.2K | 1M | 17K | 2.2M | 29K | 1.2M | 12K | 1.3M | 16K |
| nlohmann_bson:3.11.3 | 0.13M | 0.98K | 0.25M | 1.8K | 0.6M | 3.9K | 0.15M | 1.2K | 0.2M | 1.7K |
| nlohmann_cbor:3.11.3 | 0.14M | 1.3K | 0.26M | 2.4K | 0.56M | 5.4K | 0.24M | 2K | 0.29M | 3.2K |
| nlohmann_json:3.11.3 | 0.13M | 1.5K | 0.24M | 2.6K | 0.41M | 4.7K | 0.21M | 2.1K | 0.12M | 1.2K |
| nlohmann_msgpack:3.11.3 | 0.13M | 1.3K | 0.25M | 2.3K | 0.54M | 5.1K | 0.21M | 1.9K | 0.28M | 3.1K |
| nlohmann_ubjson:3.11.3 | 0.12M | 1.2K | 0.22M | 2.2K | 0.49M | 4.9K | 0.18M | 1.5K | 0.28M | 3.2K |
| protobuf-wire:wire-v2 | 0.65M | 6.5K | 1.1M | 11K | 3.4M | 31K | 1.2M | 8.3K | 0.72M | 7.9K |
| rapidjson:1.1.0 | 0.095M | 1.1K | 0.17M | 2K | 0.31M | 3.2K | 0.15M | 1.6K | 0.086M | 0.83K |
| simdjson:3.10.1 | 0.14M | 1.5K | 0.27M | 2.8K | 0.43M | 4.6K | 0.24M | 2.2K | 0.11M | 1.1K |
| thrift:TBinaryProtocol | 1.6M | 21K | 2.1M | 30K | 4M | 62K | 1.4M | 12K | 1.4M | 21K |
| yas:7.x | 2.2M | 48K | 2.8M | **58K** | 5.3M | 180K | 1.5M | 15K | 3.5M | 64K |
| yyjson:0.10.0 | 0.12M | 1.3K | 0.26M | 2.7K | 0.42M | 4.6K | 0.2M | 1.9K | 0.098M | 1.1K |
| zpp_bits:4.4.25 | 2.5M | 22K | **2.9M** | 36K | 6.9M | 170K | 1.6M | 15K | **4.3M** | 59K |

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
    
    - **Source CSV:** `/home/leo/PycharmProjects/GLD/seriailizer-benchmark/logs/cpp/2026-07-24-155410.csv`
    - run=2026-07-24-155410
    - language=cpp
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: g++=g++ (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, python=3.14.0, node=24.15.0
    - git=04d09d1 dirty
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
