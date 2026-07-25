# C++ — Benchmark Results

**Generated:** 2026-07-24T19:44:13.930493

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
| arduinojson:7.2.1 | 2,240 | 115 | 2,120 | 48.6K | 17.6K | 1849 | **1.00** |
| avro:binary-1.11 | 31 | 14.2 | 16.4 | 575K | **9.01K** | 1829 | **1.00** |
| avro_c:avro-c | 139 | 62.9 | 75.6 | 146K | **9.01K** | 1822 | **1.00** |
| bitsery:5.2.4 | **19** | 7.43 | 11.3 | **873K** | 9.75K | 1804 | **1.00** |
| capnproto:1.0.x | 32.6 | 11.6 | 20.2 | 385K | 18.3K | 1826 | **1.00** |
| cereal:1.3.2 | 38.8 | 16.4 | 21.7 | 313K | 14.2K | 1839 | **1.00** |
| cista:0.15 | 36.9 | 6.65 | 29.4 | 558K | 15.5K | 1805 | **1.00** |
| custom_binary:harness | 40.4 | 24.9 | 15.2 | 523K | 11.7K | 1829 | **1.00** |
| flatbuffers:flatbuffers | 28.1 | **3.51** | 24.3 | 498K | 10.4K | 1868 | **1.00** |
| flexbuffers:flatbuffers-flex | 183 | 61.8 | 120 | 109K | 17.3K | 1838 | **1.00** |
| jsoncons_bson:0.177.0 | 538 | 101 | 437 | 40.1K | 20.3K | 1854 | **1.00** |
| jsoncons_cbor:0.177.0 | 510 | 69.6 | 440 | 42.1K | 13.6K | 1896 | **1.00** |
| jsoncons_msgpack:0.177.0 | 493 | 66.1 | 426 | 43.6K | 13.5K | 1901 | **1.00** |
| msgpack:msgpack-cxx | 46.5 | 19.9 | 25.7 | 276K | 13.5K | 1830 | **1.00** |
| nlohmann_bson:3.11.3 | 368 | 95.2 | 272 | 87.2K | 20.3K | 1838 | **1.00** |
| nlohmann_cbor:3.11.3 | 239 | 48.8 | 189 | 96.6K | 13.6K | 1844 | **1.00** |
| nlohmann_json:3.11.3 | 318 | 84.3 | 232 | 73.4K | 19.7K | 1802 | **1.00** |
| nlohmann_msgpack:3.11.3 | 242 | 48.7 | 192 | 95.7K | 13.5K | 1854 | **1.00** |
| nlohmann_ubjson:3.11.3 | 268 | 47.9 | 219 | 88K | 15.6K | 1832 | **1.00** |
| protobuf-wire:wire-v2 | 64.6 | 40.4 | 23.8 | 426K | 10.4K | 1859 | **1.00** |
| rapidjson:1.1.0 | 543 | 108 | 434 | 47.7K | 19.7K | 1868 | **1.00** |
| simdjson:3.10.1 | 271 | 4.83 | 264 | 89.6K | 19.7K | 1820 | **1.00** |
| thrift:TBinaryProtocol | 30.8 | 16.3 | 14.2 | 476K | 13.6K | 1763 | **1.00** |
| yas:7.x | 20.3 | 9.35 | **10.6** | 493K | 14.2K | 1818 | **1.00** |
| yyjson:0.10.0 | 294 | 24.2 | 268 | 83.6K | 19.7K | 1812 | **1.00** |
| zpp_bits:4.4.25 | 24.3 | 13.5 | 10.6 | 664K | 11.7K | 1827 | **1.00** |


### Total Time

| serializer | bytes mode/mean | bytes mode/median | stream mode/mean | stream mode/median |
|---|---|---|---|---|
| arduinojson:7.2.1 | 4.93 | 4.88 | 7.31 | 7.28 |
| avro:binary-1.11 | 0.463 | 0.463 | 0.534 | 0.54 |
| avro_c:avro-c | 1.82 | 1.83 | 2.07 | 2.08 |
| bitsery:5.2.4 | **0.247** | **0.249** | **0.295** | **0.294** |
| capnproto:1.0.x | 0.637 | 0.637 | 0.879 | 0.889 |
| cereal:1.3.2 | 1.4 | 1.4 | 0.85 | 0.86 |
| cista:0.15 | 0.365 | 0.363 | 0.437 | 0.439 |
| custom_binary:harness | 0.415 | 0.412 | 0.558 | 0.556 |
| flatbuffers:flatbuffers | 0.558 | 0.562 | 0.639 | 0.644 |
| flexbuffers:flatbuffers-flex | 3.02 | 3.01 | 3.21 | 3.2 |
| jsoncons_bson:0.177.0 | 6.08 | 6.06 | 7.35 | 7.42 |
| jsoncons_cbor:0.177.0 | 5.88 | 5.85 | 7.27 | 7.25 |
| jsoncons_msgpack:0.177.0 | 5.72 | 5.67 | 6.94 | 6.94 |
| msgpack:msgpack-cxx | 1.09 | 1.08 | 1.39 | 1.39 |
| nlohmann_bson:3.11.3 | 2.59 | 2.55 | 3.32 | 3.33 |
| nlohmann_cbor:3.11.3 | 2.76 | 2.74 | 3.31 | 3.33 |
| nlohmann_json:3.11.3 | 3.47 | 3.45 | 4.64 | 4.65 |
| nlohmann_msgpack:3.11.3 | 2.86 | 2.84 | 3.27 | 3.27 |
| nlohmann_ubjson:3.11.3 | 2.99 | 2.95 | 3.56 | 3.57 |
| protobuf-wire:wire-v2 | 0.517 | 0.523 | 0.604 | 0.598 |
| rapidjson:1.1.0 | 4.59 | 4.52 | 8.8 | 8.78 |
| simdjson:3.10.1 | 3.06 | 3.05 | 3.44 | 3.42 |
| thrift:TBinaryProtocol | 0.593 | 0.594 | 0.672 | 0.673 |
| yas:7.x | 0.595 | 0.602 | 0.694 | 0.688 |
| yyjson:0.10.0 | 3.28 | 3.23 | 3.59 | 3.59 |
| zpp_bits:4.4.25 | 0.43 | 0.425 | 0.491 | 0.494 |


### Ops/Sec

| serializer | Document · 1 instance | Document · 100 instances | Event · 1 instance | Event · 100 instances | Message · 1 instance | Message · 100 instances | Strings · 1 instance | Strings · 100 instances | Telemetry · 1 instance | Telemetry · 100 instances |
|---|---|---|---|---|---|---|---|---|---|---|
| arduinojson:7.2.1 | 0.07M | 0.18K | 0.11M | 0.29K | 0.2M | 2K | 90K | 0.092K | 0.089M | 0.93K |
| avro:binary-1.11 | 1.1M | 18K | 1.1M | 19K | 2.2M | 70K | 770K | 8.6K | 0.78M | 15K |
| avro_c:avro-c | 0.2M | 3.2K | 0.29M | 4.4K | 0.55M | 12K | 160K | 2K | 0.29M | 4.3K |
| bitsery:5.2.4 | **1.7M** | **32K** | **1.2M** | **25K** | **4M** | 97K | 810K | 12K | 1.3M | **44K** |
| capnproto:1.0.x | 0.57M | 16K | 0.62M | 15K | 1.6M | **110K** | 500K | 8.4K | 0.84M | 21K |
| cereal:1.3.2 | 0.36M | 11K | 0.41M | 13K | 0.71M | 38K | 310K | 5.6K | 0.49M | 20K |
| cista:0.15 | 0.85M | 13K | 0.96M | 16K | 2.7M | 55K | 420K | 6.8K | 0.83M | 18K |
| custom_binary:harness | 0.82M | 12K | 1M | 16K | 2.4M | 44K | 610K | 7.7K | 0.75M | 10K |
| flatbuffers:flatbuffers | 0.64M | 15K | 0.82M | 17K | 1.8M | 60K | 730K | **13K** | 1.1M | 20K |
| flexbuffers:flatbuffers-flex | 0.11M | 1.5K | 0.2M | 2.9K | 0.33M | 5.3K | 230K | 2.8K | 0.24M | 3.9K |
| jsoncons_bson:0.177.0 | 0.051M | 0.71K | 0.081M | 1.2K | 0.16M | 2.2K | 60K | 0.77K | 0.059M | 0.73K |
| jsoncons_cbor:0.177.0 | 0.052M | 0.72K | 0.085M | 1.3K | 0.17M | 2.3K | 71K | 0.88K | 0.063M | 0.78K |
| jsoncons_msgpack:0.177.0 | 0.054M | 0.75K | 0.089M | 1.3K | 0.17M | 2.3K | 74K | 0.92K | 0.065M | 0.79K |
| msgpack:msgpack-cxx | 0.37M | 8.2K | 0.52M | 12K | 0.92M | 24K | 530K | 9.4K | 0.62M | 14K |
| nlohmann_bson:3.11.3 | 0.1M | 0.92K | 0.18M | 1.7K | 0.39M | 3.7K | 120K | 1.1K | 0.16M | 1.6K |
| nlohmann_cbor:3.11.3 | 0.1M | 1.3K | 0.18M | 2.3K | 0.36M | 4.7K | 160K | 1.9K | 0.22M | 2.9K |
| nlohmann_json:3.11.3 | 0.1M | 1.4K | 0.18M | 2.5K | 0.29M | 4.1K | 150K | 1.9K | 0.094M | 1.1K |
| nlohmann_msgpack:3.11.3 | 0.098M | 1.3K | 0.17M | 2.2K | 0.35M | 4.5K | 150K | 1.8K | 0.22M | 2.9K |
| nlohmann_ubjson:3.11.3 | 0.097M | 1.2K | 0.16M | 2.1K | 0.33M | 4.3K | 130K | 1.6K | 0.21M | 2.8K |
| protobuf-wire:wire-v2 | 0.46M | 5.8K | 0.66M | 8.5K | 1.9M | 24K | 750K | 6.5K | 0.58M | 6.8K |
| rapidjson:1.1.0 | 0.077M | 1.1K | 0.13M | 2K | 0.22M | 3.1K | 110K | 1.5K | 0.071M | 0.79K |
| simdjson:3.10.1 | 0.11M | 1.5K | 0.2M | 2.9K | 0.33M | 4.3K | 180K | 2.2K | 0.093M | 1.1K |
| thrift:TBinaryProtocol | 0.74M | 17K | 0.82M | 17K | 1.7M | 47K | 740K | 9.7K | 0.83M | 18K |
| yas:7.x | 0.72M | 30K | 0.82M | 25K | 1.7M | 91K | 600K | 11K | 1.1M | 44K |
| yyjson:0.10.0 | 0.1M | 1.4K | 0.19M | 2.6K | 0.31M | 4.1K | 160K | 1.8K | 0.09M | 1K |
| zpp_bits:4.4.25 | 1.1M | 17K | 1.1M | 20K | 2.3M | 75K | **820K** | 11K | **1.4M** | 36K |

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
    
    - **Source CSV:** `logs/cpp/2026-07-24-194011.csv`
    - run=2026-07-24-194011
    - language=cpp
    - os=Linux 6.8.0-124-generic
    - cpu=12th Gen Intel(R) Core(TM) i7-12800H (20 threads)
    - ram=31.0 GiB
    - runtimes: g++=g++ (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0, python=3.14.0, node=24.15.0
    - git=7431b57 dirty
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
