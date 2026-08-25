# Experiment 13 results — cpp

**Date:** 2026-08-17
**Raw file:** `experiments/13-ranking-accident/cpp/logs/cpp/2026-08-17-104819.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| simdjson | 3.10.1 | 0.13 | 9.07 | 9.20 | 458 | — | fast read; write is prepared JSON text | fastest | yes | 99 |
| nlohmann_json | 3.11.3 | 2.29 | 7.07 | 9.42 | 458 | — | common C++ JSON library | similar | yes | 97 |
| yyjson | 0.10.0 | 1.02 | 8.76 | 9.91 | 458 | — | same C library as in the C run | slower | yes | 94 |
| rapidjson | 1.1.0 | 1.30 | 11.5 | 12.9 | 458 | — | fast C++ JSON library | slower | yes | 92 |
| arduinojson | 7.2.1 | 2.44 | 11.7 | 14.2 | 458 | — | JSON for small devices | slower | yes | 95 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| simdjson | 3.10.1 | 8.98 | 677 | 688 | 45507 | — | fast read; write is prepared JSON text | fastest | yes | 76 |
| yyjson | 0.10.0 | 37.3 | 660 | 699 | 45507 | — | same C library as in the C run | close | yes | 79 |
| nlohmann_json | 3.11.3 | 166 | 551 | 728 | 45507 | — | common C++ JSON library | slower | yes | 95 |
| rapidjson | 1.1.0 | 100 | 807 | 908 | 45507 | — | fast C++ JSON library | slower | yes | 93 |
| arduinojson | 7.2.1 | 182 | 4822 | 5011 | 45507 | — | JSON for small devices | slower | yes | 90 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 0.35 | 5.09 | 5.44 | 272 | — | same C library as in the C run | fastest | yes | 89 |
| simdjson | 3.10.1 | 0.13 | 5.63 | 5.75 | 272 | — | fast read; write is prepared JSON text | slower | yes | 89 |
| nlohmann_json | 3.11.3 | 1.71 | 4.33 | 6.04 | 272 | — | common C++ JSON library | slower | yes | 95 |
| rapidjson | 1.1.0 | 0.91 | 7.21 | 8.15 | 272 | — | fast C++ JSON library | slower | yes | 95 |
| arduinojson | 7.2.1 | 1.77 | 7.43 | 9.23 | 272 | — | JSON for small devices | slower | yes | 93 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| simdjson | 3.10.1 | 6.47 | 361 | 368 | 25463 | — | fast read; write is prepared JSON text | fastest | yes | 78 |
| yyjson | 0.10.0 | 29.1 | 373 | 403 | 25463 | — | same C library as in the C run | slower | yes | 89 |
| nlohmann_json | 3.11.3 | 124 | 302 | 429 | 25463 | — | common C++ JSON library | slower | yes | 91 |
| rapidjson | 1.1.0 | 56.4 | 455 | 510 | 25463 | — | fast C++ JSON library | slower | yes | 96 |
| arduinojson | 7.2.1 | 121 | 3346 | 3472 | 25463 | — | JSON for small devices | slower | yes | 95 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 0.27 | 3.39 | 3.65 | 168 | — | same C library as in the C run | fastest | yes | 96 |
| nlohmann_json | 3.11.3 | 1.11 | 2.75 | 3.87 | 168 | — | common C++ JSON library | slower | yes | 86 |
| simdjson | 3.10.1 | 0.09 | 3.85 | 3.94 | 168 | — | fast read; write is prepared JSON text | slower | yes | 81 |
| rapidjson | 1.1.0 | 0.69 | 4.46 | 5.12 | 168 | — | fast C++ JSON library | slower | yes | 97 |
| arduinojson | 7.2.1 | 1.05 | 4.22 | 5.30 | 162 | — | JSON for small devices | slower | yes | 91 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| simdjson | 3.10.1 | 3.46 | 230 | 236 | 16546 | — | fast read; write is prepared JSON text | fastest | yes | 95 |
| nlohmann_json | 3.11.3 | 57.0 | 185 | 242 | 16546 | — | common C++ JSON library | slower | yes | 90 |
| yyjson | 0.10.0 | 14.1 | 228 | 245 | 16546 | — | same C library as in the C run | slower | yes | 92 |
| rapidjson | 1.1.0 | 43.2 | 287 | 329 | 16543 | — | fast C++ JSON library | slower | yes | 96 |
| arduinojson | 7.2.1 | 67.5 | 438 | 510 | 15916 | — | JSON for small devices | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| simdjson | 3.10.1 | 0.14 | 6.66 | 6.81 | 411 | — | fast read; write is prepared JSON text | fastest | yes | 92 |
| yyjson | 0.10.0 | 0.39 | 6.88 | 7.28 | 411 | — | same C library as in the C run | close | yes | 89 |
| nlohmann_json | 3.11.3 | 2.11 | 5.31 | 7.51 | 411 | — | common C++ JSON library | slower | yes | 94 |
| rapidjson | 1.1.0 | 1.10 | 9.07 | 10.2 | 411 | — | fast C++ JSON library | slower | yes | 94 |
| arduinojson | 7.2.1 | 2.33 | 9.71 | 12.1 | 411 | — | JSON for small devices | slower | yes | 93 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| simdjson | 3.10.1 | 14.5 | 462 | 484 | 41431 | — | fast read; write is prepared JSON text | fastest | yes | 96 |
| nlohmann_json | 3.11.3 | 169 | 371 | 544 | 41431 | — | common C++ JSON library | slower | yes | 94 |
| yyjson | 0.10.0 | 51.8 | 520 | 571 | 41431 | — | same C library as in the C run | slower | yes | 91 |
| rapidjson | 1.1.0 | 88.6 | 598 | 692 | 41431 | — | fast C++ JSON library | slower | yes | 91 |
| arduinojson | 7.2.1 | 200 | 10666 | 10857 | 41431 | — | JSON for small devices | slower | yes | 96 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nlohmann_json | 3.11.3 | 2.95 | 8.31 | 11.3 | 658 | — | common C++ JSON library | fastest | yes | 95 |
| arduinojson | 7.2.1 | 2.07 | 9.99 | 12.1 | 455 | — | JSON for small devices | slower | yes | 94 |
| yyjson | 0.10.0 | 1.06 | 11.0 | 12.1 | 658 | — | same C library as in the C run | slower | yes | 95 |
| simdjson | 3.10.1 | 0.18 | 12.0 | 12.2 | 658 | — | fast read; write is prepared JSON text | slower | yes | 86 |
| rapidjson | 1.1.0 | 2.54 | 12.6 | 15.2 | 658 | — | fast C++ JSON library | slower | yes | 86 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nlohmann_json | 3.11.3 | 228 | 674 | 904 | 65970 | — | common C++ JSON library | fastest | yes | 93 |
| simdjson | 3.10.1 | 12.8 | 945 | 959 | 65970 | — | fast read; write is prepared JSON text | slower | yes | 90 |
| yyjson | 0.10.0 | 103 | 915 | 1016 | 65966 | — | same C library as in the C run | slower | yes | 85 |
| arduinojson | 7.2.1 | 155 | 946 | 1102 | 45907 | — | JSON for small devices | slower | yes | 91 |
| rapidjson | 1.1.0 | 213 | 1065 | 1282 | 65833 | — | fast C++ JSON library | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `simdjson`, `nlohmann_json`. Small gap: —. Time/size front: `simdjson`.

**sample A (order), N = 100, memory** — not clearly slower: `simdjson`. Small gap: `yyjson`. Time/size front: `simdjson`.

**sample D (event), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample D (event), N = 100, memory** — not clearly slower: `simdjson`. Small gap: —. Time/size front: `simdjson`.

**sample B (flat), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`, `arduinojson`.

**sample B (flat), N = 100, memory** — not clearly slower: `simdjson`. Small gap: —. Time/size front: `simdjson`, `rapidjson`, `arduinojson`.

**sample E (words), N = 1, memory** — not clearly slower: `simdjson`. Small gap: `yyjson`. Time/size front: `simdjson`.

**sample E (words), N = 100, memory** — not clearly slower: `simdjson`. Small gap: —. Time/size front: `simdjson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `nlohmann_json`. Small gap: —. Time/size front: `nlohmann_json`, `arduinojson`.

**sample C (sensor), N = 100, memory** — not clearly slower: `nlohmann_json`. Small gap: —. Time/size front: `nlohmann_json`, `yyjson`, `arduinojson`.

