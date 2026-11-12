# Experiment 9 results — javascript

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/javascript/logs/javascript/2026-11-12-122324.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.22.2 | 2.89 | 2.49 | 5.33 | 168 | 137 | JSON — ships with JavaScript | fastest | yes | 95 |
| msgpackr | 1.12.1 | 4.13 | 9.76 | 13.8 | 126 | 129 | MessagePack | slower | yes | 88 |
| gld-kiln | 0.2.0 | 7.54 | 6.54 | 14.0 | 57 | 75 | positional binary — no field names | slower | yes | 83 |
| protobuf-es | 2.16.0 | 9.20 | 7.36 | 16.7 | 50 | 71 | Protocol Buffers | slower | yes | 86 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.22.2 | 2.95 | 4.05 | 7.45 | 411 | 286 | JSON — ships with JavaScript | fastest | yes | 90 |
| msgpackr | 1.12.1 | 5.10 | 8.27 | 14.4 | 348 | 272 | MessagePack | slower | yes | 86 |
| protobuf-es | 2.16.0 | 9.45 | 13.6 | 24.2 | 368 | 275 | Protocol Buffers | slower | yes | 87 |
| gld-kiln | 0.2.0 | 14.0 | 16.0 | 30.2 | 436 | 299 | positional binary — no field names | slower | yes | 81 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpackr | 1.12.1 | 8.13 | 10.7 | 18.0 | 1214 | 1169 | MessagePack | fastest | yes | 91 |
| gld-kiln | 0.2.0 | 10.8 | 10.4 | 21.9 | 1073 | 1089 | positional binary — no field names | close | yes | 93 |
| JSON.stringify | node-24.22.2 | 15.2 | 8.40 | 23.6 | 2407 | 1221 | JSON — ships with JavaScript | slower | yes | 91 |
| protobuf-es | 2.16.0 | 20.7 | 12.5 | 33.8 | 1061 | 1076 | Protocol Buffers | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `gld-kiln`, `protobuf-es`.

**sample E (words), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgpackr`. Small gap: `gld-kiln`. Time/size front: `msgpackr`, `gld-kiln`, `protobuf-es`.

