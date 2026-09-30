# Experiment 13 results — javascript

**Date:** 2026-09-30
**Raw file:** `experiments/13-ranking-accident/javascript/logs/javascript/2026-09-29-185615.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 4.48 | 5.28 | 10.5 | 448 | 2535 | ships with JavaScript | fastest | yes | 90 |
| fast-json-stringify | 6.4.0 | 9.04 | 5.40 | 15.2 | 448 | 2535 | compiled writer; read is JSON.parse | slower | yes | 89 |
| simdjson-parse+JSON.stringify | 0.9.2 | 4.60 | 25.4 | 31.4 | 448 | 2535 | fast read only; write is JSON.stringify | slower | yes | 90 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 118 | 262 | 377 | 45404 | 2535 | ships with JavaScript | fastest | yes | 83 |
| fast-json-stringify | 6.4.0 | 236 | 265 | 503 | 45404 | 2535 | compiled writer; read is JSON.parse | slower | yes | 83 |
| simdjson-parse+JSON.stringify | 0.9.2 | 119 | 610 | 724 | 45404 | 2535 | fast read only; write is JSON.stringify | slower | yes | 88 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.45 | 2.38 | 4.92 | 257 | 2535 | ships with JavaScript | fastest | yes | 93 |
| fast-json-stringify | 6.4.0 | 4.41 | 2.74 | 7.14 | 257 | 2535 | compiled writer; read is JSON.parse | slower | yes | 86 |
| simdjson-parse+JSON.stringify | 0.9.2 | 2.72 | 12.1 | 14.7 | 257 | 2535 | fast read only; write is JSON.stringify | slower | yes | 84 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 75.5 | 188 | 265 | 25746 | 2535 | ships with JavaScript | fastest | yes | 88 |
| fast-json-stringify | 6.4.0 | 122 | 199 | 323 | 25746 | 2535 | compiled writer; read is JSON.parse | slower | yes | 90 |
| simdjson-parse+JSON.stringify | 0.9.2 | 74.4 | 351 | 426 | 25746 | 2535 | fast read only; write is JSON.stringify | slower | yes | 82 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.23 | 2.21 | 4.42 | 168 | 2535 | ships with JavaScript | fastest | yes | 93 |
| fast-json-stringify | 6.4.0 | 3.71 | 2.13 | 6.01 | 168 | 2535 | compiled writer; read is JSON.parse | slower | yes | 89 |
| simdjson-parse+JSON.stringify | 0.9.2 | 2.46 | 11.1 | 13.7 | 168 | 2535 | fast read only; write is JSON.stringify | slower | yes | 87 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 46.9 | 49.7 | 96.8 | 16546 | 2535 | ships with JavaScript | fastest | yes | 89 |
| fast-json-stringify | 6.4.0 | 73.1 | 51.6 | 129 | 16546 | 2535 | compiled writer; read is JSON.parse | slower | yes | 92 |
| simdjson-parse+JSON.stringify | 0.9.2 | 46.0 | 174 | 220 | 16546 | 2535 | fast read only; write is JSON.stringify | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.11 | 2.17 | 4.30 | 411 | 2535 | ships with JavaScript | fastest | yes | 88 |
| fast-json-stringify | 6.4.0 | 5.12 | 2.47 | 7.69 | 411 | 2535 | compiled writer; read is JSON.parse | slower | yes | 91 |
| simdjson-parse+JSON.stringify | 0.9.2 | 2.10 | 12.0 | 14.1 | 411 | 2535 | fast read only; write is JSON.stringify | slower | yes | 81 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 139 | 309 | 447 | 41431 | 2535 | ships with JavaScript | fastest | yes | 83 |
| fast-json-stringify | 6.4.0 | 247 | 297 | 538 | 41431 | 2535 | compiled writer; read is JSON.parse | slower | yes | 83 |
| simdjson-parse+JSON.stringify | 0.9.2 | 137 | 440 | 585 | 41431 | 2535 | fast read only; write is JSON.stringify | slower | yes | 88 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 5.22 | 3.42 | 8.60 | 663 | 2535 | ships with JavaScript | fastest | yes | 93 |
| fast-json-stringify | 6.4.0 | 5.46 | 3.54 | 8.79 | 663 | 2535 | compiled writer; read is JSON.parse | similar | yes | 89 |
| simdjson-parse+JSON.stringify | 0.9.2 | 5.50 | 21.5 | 26.3 | 663 | 2535 | fast read only; write is JSON.stringify | slower | yes | 93 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 357 | 189 | 546 | 65958 | 2535 | ships with JavaScript | fastest | yes | 92 |
| fast-json-stringify | 6.4.0 | 368 | 181 | 554 | 65958 | 2535 | compiled writer; read is JSON.parse | similar | yes | 86 |
| simdjson-parse+JSON.stringify | 0.9.2 | 350 | 490 | 840 | 65958 | 2535 | fast read only; write is JSON.stringify | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`.

**sample A (order), N = 100, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`.

**sample D (event), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`.

**sample D (event), N = 100, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`.

**sample B (flat), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`.

**sample B (flat), N = 100, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`.

**sample E (words), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`.

**sample E (words), N = 100, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`.

**sample C (sensor), N = 1, memory** — not clearly slower: `JSON.stringify`, `fast-json-stringify`. Small gap: —. Time/size front: `JSON.stringify`.

**sample C (sensor), N = 100, memory** — not clearly slower: `JSON.stringify`, `fast-json-stringify`. Small gap: —. Time/size front: `JSON.stringify`.

