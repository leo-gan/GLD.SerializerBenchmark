# Experiment 9 results — javascript

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/javascript/logs/javascript/2026-11-12-100834.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.22.2 | 3.12 | 2.88 | 5.81 | 168 | 137 | JSON — ships with JavaScript | fastest | yes | 89 |
| msgpackr | 1.12.1 | 4.80 | 10.5 | 15.2 | 126 | 129 | MessagePack | slower | yes | 91 |
| gld-kiln | 0.2.0 | 8.59 | 7.38 | 16.1 | 57 | 75 | positional binary — no field names | slower | yes | 89 |
| protobuf-es | 2.16.0 | 11.1 | 8.62 | 20.4 | 50 | 71 | Protocol Buffers | slower | yes | 84 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.22.2 | 3.30 | 5.04 | 8.33 | 411 | 286 | JSON — ships with JavaScript | fastest | yes | 85 |
| msgpackr | 1.12.1 | 5.72 | 10.5 | 16.3 | 348 | 272 | MessagePack | slower | yes | 86 |
| protobuf-es | 2.16.0 | 11.7 | 18.2 | 29.6 | 368 | 275 | Protocol Buffers | slower | yes | 85 |
| gld-kiln | 0.2.0 | 18.5 | 18.9 | 38.5 | 436 | 299 | positional binary — no field names | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpackr | 1.12.1 | 9.62 | 13.8 | 24.6 | 1214 | 1169 | MessagePack | fastest | yes | 90 |
| JSON.stringify | node-24.22.2 | 16.5 | 9.72 | 25.8 | 2407 | 1221 | JSON — ships with JavaScript | similar | yes | 85 |
| gld-kiln | 0.2.0 | 14.1 | 13.7 | 29.3 | 1073 | 1089 | positional binary — no field names | close | yes | 90 |
| protobuf-es | 2.16.0 | 29.2 | 16.8 | 46.8 | 1061 | 1076 | Protocol Buffers | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `gld-kiln`, `protobuf-es`.

**sample E (words), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgpackr`, `JSON.stringify`. Small gap: `gld-kiln`. Time/size front: `msgpackr`, `gld-kiln`, `protobuf-es`.

