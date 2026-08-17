# Experiment 13 results — javascript

**Date:** 2026-08-17
**Raw file:** `experiments/13-ranking-accident/javascript/logs/javascript/2026-08-17-104754.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 3.08 | 4.07 | 7.01 | 448 | — | ships with JavaScript | fastest | yes | 89 |
| fast-json-stringify | 6.4.0 | 7.39 | 4.15 | 11.8 | 448 | — | compiled writer; read is JSON.parse | slower | yes | 89 |
| simdjson-parse+JSON.stringify | 0.9.2 | 3.32 | 18.1 | 22.6 | 448 | — | fast read only; write is JSON.stringify | slower | yes | 90 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 115 | 263 | 377 | 45404 | — | ships with JavaScript | fastest | yes | 83 |
| fast-json-stringify | 6.4.0 | 243 | 268 | 503 | 45404 | — | compiled writer; read is JSON.parse | slower | yes | 90 |
| simdjson-parse+JSON.stringify | 0.9.2 | 114 | 615 | 731 | 45404 | — | fast read only; write is JSON.stringify | slower | yes | 88 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 1.48 | 1.86 | 3.54 | 257 | — | ships with JavaScript | fastest | yes | 90 |
| fast-json-stringify | 6.4.0 | 3.90 | 1.79 | 5.72 | 257 | — | compiled writer; read is JSON.parse | slower | yes | 87 |
| simdjson-parse+JSON.stringify | 0.9.2 | 1.56 | 10.9 | 12.7 | 257 | — | fast read only; write is JSON.stringify | slower | yes | 85 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 80.5 | 145 | 223 | 25746 | — | ships with JavaScript | fastest | yes | 87 |
| fast-json-stringify | 6.4.0 | 126 | 150 | 278 | 25746 | — | compiled writer; read is JSON.parse | slower | yes | 83 |
| simdjson-parse+JSON.stringify | 0.9.2 | 77.6 | 359 | 438 | 25746 | — | fast read only; write is JSON.stringify | slower | yes | 82 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 1.66 | 1.59 | 3.45 | 168 | — | ships with JavaScript | fastest | yes | 92 |
| fast-json-stringify | 6.4.0 | 3.31 | 1.48 | 4.95 | 168 | — | compiled writer; read is JSON.parse | slower | yes | 92 |
| simdjson-parse+JSON.stringify | 0.9.2 | 1.67 | 10.0 | 11.8 | 168 | — | fast read only; write is JSON.stringify | slower | yes | 85 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 46.4 | 46.4 | 93.1 | 16546 | — | ships with JavaScript | fastest | yes | 88 |
| fast-json-stringify | 6.4.0 | 69.1 | 47.6 | 121 | 16546 | — | compiled writer; read is JSON.parse | slower | yes | 86 |
| simdjson-parse+JSON.stringify | 0.9.2 | 44.6 | 177 | 223 | 16546 | — | fast read only; write is JSON.stringify | slower | yes | 83 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 1.44 | 1.98 | 3.55 | 411 | — | ships with JavaScript | fastest | yes | 94 |
| fast-json-stringify | 6.4.0 | 4.64 | 2.00 | 6.81 | 411 | — | compiled writer; read is JSON.parse | slower | yes | 92 |
| simdjson-parse+JSON.stringify | 0.9.2 | 1.41 | 10.2 | 11.8 | 411 | — | fast read only; write is JSON.stringify | slower | yes | 81 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 114 | 238 | 359 | 41431 | — | ships with JavaScript | fastest | yes | 85 |
| fast-json-stringify | 6.4.0 | 241 | 273 | 520 | 41431 | — | compiled writer; read is JSON.parse | slower | yes | 92 |
| simdjson-parse+JSON.stringify | 0.9.2 | 114 | 427 | 542 | 41431 | — | fast read only; write is JSON.stringify | slower | yes | 83 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 4.55 | 3.13 | 7.81 | 663 | — | ships with JavaScript | fastest | yes | 94 |
| fast-json-stringify | 6.4.0 | 5.61 | 2.88 | 8.81 | 663 | — | compiled writer; read is JSON.parse | close | yes | 89 |
| simdjson-parse+JSON.stringify | 0.9.2 | 4.80 | 14.9 | 20.4 | 663 | — | fast read only; write is JSON.stringify | slower | yes | 94 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 360 | 179 | 540 | 65958 | — | ships with JavaScript | fastest | yes | 92 |
| fast-json-stringify | 6.4.0 | 395 | 184 | 582 | 65958 | — | compiled writer; read is JSON.parse | close | yes | 90 |
| simdjson-parse+JSON.stringify | 0.9.2 | 359 | 501 | 863 | 65958 | — | fast read only; write is JSON.stringify | slower | yes | 89 |

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

**sample C (sensor), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: `fast-json-stringify`. Time/size front: `JSON.stringify`.

**sample C (sensor), N = 100, memory** — not clearly slower: `JSON.stringify`. Small gap: `fast-json-stringify`. Time/size front: `JSON.stringify`.

