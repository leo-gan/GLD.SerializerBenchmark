# Experiment 9 results — javascript

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/javascript/logs/javascript/2026-11-12-163748.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.22.2 | 2.77 | 2.97 | 5.53 | 168 | 137 | JSON — ships with JavaScript | fastest | yes | 93 |
| msgpackr | 1.12.1 | 4.49 | 9.83 | 14.3 | 126 | 129 | MessagePack | slower | yes | 83 |
| gld-kiln | 0.2.0 | 8.08 | 7.08 | 15.2 | 57 | 75 | positional binary — no field names | slower | yes | 90 |
| protobuf-es | 2.16.0 | 9.57 | 7.45 | 17.2 | 50 | 71 | Protocol Buffers | slower | yes | 81 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.22.2 | 3.12 | 4.44 | 7.48 | 411 | 286 | JSON — ships with JavaScript | fastest | yes | 84 |
| msgpackr | 1.12.1 | 5.05 | 9.29 | 14.4 | 348 | 272 | MessagePack | slower | yes | 83 |
| protobuf-es | 2.16.0 | 9.78 | 13.5 | 23.4 | 368 | 275 | Protocol Buffers | slower | yes | 86 |
| gld-kiln | 0.2.0 | 15.1 | 17.0 | 32.5 | 436 | 299 | positional binary — no field names | slower | yes | 84 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpackr | 1.12.1 | 7.62 | 10.4 | 18.2 | 1214 | 1169 | MessagePack | fastest | yes | 84 |
| gld-kiln | 0.2.0 | 10.3 | 10.7 | 21.1 | 1073 | 1089 | positional binary — no field names | close | yes | 88 |
| JSON.stringify | node-24.22.2 | 15.2 | 9.00 | 24.2 | 2407 | 1221 | JSON — ships with JavaScript | slower | yes | 84 |
| protobuf-es | 2.16.0 | 20.3 | 11.3 | 32.0 | 1061 | 1076 | Protocol Buffers | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `gld-kiln`, `protobuf-es`.

**sample E (words), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgpackr`. Small gap: `gld-kiln`. Time/size front: `msgpackr`, `gld-kiln`, `protobuf-es`.

