# Experiment 13 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/13-ranking-accident/cpp/logs/cpp/2026-09-04-111858.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 2.86 | 12.1 | 15.1 | 458 | 2615 | same C library as in the C run | fastest | yes | 93 |
| simdjson | 3.10.1 | 5.06 | 12.2 | 17.3 | 458 | 2615 | fast read; write is prepared JSON text | slower | yes | 90 |
| rapidjson | 1.1.0 | 3.96 | 14.3 | 18.4 | 458 | 2608 | fast C++ JSON library | slower | yes | 92 |
| nlohmann_json | 3.11.3 | 5.07 | 16.7 | 21.7 | 458 | 2615 | common C++ JSON library | slower | yes | 88 |
| arduinojson | 7.2.1 | 5.45 | 19.6 | 25.2 | 458 | 2348 | JSON for small devices | slower | yes | 87 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 58.9 | 569 | 629 | 45507 | 2615 | same C library as in the C run | fastest | yes | 82 |
| simdjson | 3.10.1 | 254 | 610 | 875 | 45507 | 2615 | fast read; write is prepared JSON text | slower | yes | 97 |
| rapidjson | 1.1.0 | 172 | 746 | 908 | 45507 | 2608 | fast C++ JSON library | slower | yes | 95 |
| nlohmann_json | 3.11.3 | 235 | 878 | 1123 | 45507 | 2615 | common C++ JSON library | slower | yes | 95 |
| arduinojson | 7.2.1 | 306 | 8768 | 9083 | 45507 | 2348 | JSON for small devices | slower | yes | 84 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 1.56 | 5.95 | 7.46 | 272 | 2615 | same C library as in the C run | fastest | yes | 89 |
| simdjson | 3.10.1 | 3.56 | 6.29 | 9.86 | 272 | 2615 | fast read; write is prepared JSON text | slower | yes | 94 |
| rapidjson | 1.1.0 | 2.57 | 8.15 | 11.0 | 272 | 2608 | fast C++ JSON library | slower | yes | 90 |
| nlohmann_json | 3.11.3 | 3.50 | 9.04 | 12.4 | 272 | 2615 | common C++ JSON library | slower | yes | 91 |
| arduinojson | 7.2.1 | 3.31 | 10.8 | 14.3 | 272 | 2348 | JSON for small devices | slower | yes | 87 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 42.8 | 306 | 349 | 25463 | 2615 | same C library as in the C run | fastest | yes | 85 |
| simdjson | 3.10.1 | 152 | 301 | 455 | 25463 | 2615 | fast read; write is prepared JSON text | slower | yes | 85 |
| rapidjson | 1.1.0 | 102 | 391 | 487 | 25463 | 2608 | fast C++ JSON library | slower | yes | 86 |
| nlohmann_json | 3.11.3 | 183 | 449 | 633 | 25463 | 2615 | common C++ JSON library | slower | yes | 84 |
| arduinojson | 7.2.1 | 182 | 4908 | 5089 | 25463 | 2348 | JSON for small devices | slower | yes | 86 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 0.73 | 3.26 | 4.03 | 168 | 2615 | same C library as in the C run | fastest | yes | 91 |
| simdjson | 3.10.1 | 2.16 | 3.29 | 5.38 | 168 | 2615 | fast read; write is prepared JSON text | slower | yes | 93 |
| rapidjson | 1.1.0 | 1.27 | 4.23 | 5.48 | 168 | 2608 | fast C++ JSON library | slower | yes | 85 |
| nlohmann_json | 3.11.3 | 2.16 | 5.62 | 7.83 | 168 | 2615 | common C++ JSON library | slower | yes | 89 |
| arduinojson | 7.2.1 | 2.26 | 6.02 | 8.34 | 162 | 2348 | JSON for small devices | slower | yes | 91 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 20.9 | 161 | 182 | 16546 | 2615 | same C library as in the C run | fastest | yes | 87 |
| simdjson | 3.10.1 | 88.7 | 164 | 253 | 16546 | 2615 | fast read; write is prepared JSON text | slower | yes | 83 |
| rapidjson | 1.1.0 | 63.4 | 204 | 264 | 16543 | 2608 | fast C++ JSON library | slower | yes | 91 |
| nlohmann_json | 3.11.3 | 105 | 284 | 390 | 16546 | 2615 | common C++ JSON library | slower | yes | 81 |
| arduinojson | 7.2.1 | 107 | 490 | 597 | 15916 | 2348 | JSON for small devices | slower | yes | 89 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 1.35 | 5.74 | 7.12 | 411 | 2615 | same C library as in the C run | fastest | yes | 85 |
| simdjson | 3.10.1 | 3.73 | 5.83 | 9.50 | 411 | 2615 | fast read; write is prepared JSON text | slower | yes | 91 |
| rapidjson | 1.1.0 | 2.42 | 7.71 | 10.1 | 411 | 2608 | fast C++ JSON library | slower | yes | 86 |
| nlohmann_json | 3.11.3 | 3.28 | 8.24 | 11.6 | 411 | 2615 | common C++ JSON library | slower | yes | 87 |
| arduinojson | 7.2.1 | 3.85 | 10.7 | 14.6 | 411 | 2348 | JSON for small devices | slower | yes | 84 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 86.8 | 476 | 568 | 41431 | 2615 | same C library as in the C run | fastest | yes | 95 |
| simdjson | 3.10.1 | 249 | 427 | 669 | 41431 | 2615 | fast read; write is prepared JSON text | slower | yes | 90 |
| rapidjson | 1.1.0 | 137 | 594 | 732 | 41431 | 2608 | fast C++ JSON library | slower | yes | 93 |
| nlohmann_json | 3.11.3 | 330 | 636 | 973 | 41431 | 2615 | common C++ JSON library | slower | yes | 90 |
| arduinojson | 7.2.1 | 341 | 18672 | 19011 | 41431 | 2348 | JSON for small devices | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 2.78 | 6.61 | 9.25 | 658 | 2615 | same C library as in the C run | fastest | yes | 93 |
| simdjson | 3.10.1 | 5.54 | 6.96 | 12.4 | 658 | 2615 | fast read; write is prepared JSON text | slower | yes | 90 |
| arduinojson | 7.2.1 | 3.93 | 9.23 | 13.2 | 455 | 2348 | JSON for small devices | slower | yes | 91 |
| rapidjson | 1.1.0 | 5.93 | 7.28 | 13.4 | 658 | 2608 | fast C++ JSON library | slower | yes | 91 |
| nlohmann_json | 3.11.3 | 5.30 | 14.9 | 20.2 | 658 | 2615 | common C++ JSON library | slower | yes | 88 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 142 | 325 | 467 | 65966 | 2615 | same C library as in the C run | fastest | yes | 82 |
| simdjson | 3.10.1 | 334 | 337 | 674 | 65970 | 2615 | fast read; write is prepared JSON text | slower | yes | 81 |
| rapidjson | 1.1.0 | 302 | 396 | 701 | 65833 | 2608 | fast C++ JSON library | slower | yes | 81 |
| arduinojson | 7.2.1 | 230 | 777 | 1010 | 45907 | 2348 | JSON for small devices | slower | yes | 82 |
| nlohmann_json | 3.11.3 | 354 | 989 | 1347 | 65970 | 2615 | common C++ JSON library | slower | yes | 81 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample A (order), N = 100, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample D (event), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample D (event), N = 100, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample B (flat), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`, `arduinojson`.

**sample B (flat), N = 100, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`, `rapidjson`, `arduinojson`.

**sample E (words), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample E (words), N = 100, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`, `arduinojson`.

**sample C (sensor), N = 100, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`, `rapidjson`, `arduinojson`.

