# Experiment 9 results — javascript

**Date:** 2026-08-17
**Raw file:** `experiments/09-compression-size/javascript/logs/javascript/2026-08-17-115850.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 1.75 | 1.75 | 3.59 | 168 | 137 | JSON — ships with JavaScript | fastest | yes | 92 |
| msgpackr | 1.12.1 | 3.50 | 7.67 | 11.2 | 126 | 129 | MessagePack | slower | yes | 91 |
| protobuf-es | 2.12.1 | 11.3 | 10.7 | 21.9 | 50 | 71 | Protocol Buffers | slower | yes | 74 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.52 | 2.92 | 5.54 | 411 | 286 | JSON — ships with JavaScript | fastest | yes | 97 |
| msgpackr | 1.12.1 | 4.21 | 6.75 | 11.0 | 348 | 272 | MessagePack | slower | yes | 80 |
| protobuf-es | 2.12.1 | 24.6 | 16.5 | 43.1 | 368 | 275 | Protocol Buffers | slower | yes | 89 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpackr | 1.12.1 | 6.12 | 7.39 | 13.7 | 1214 | 1169 | MessagePack | fastest | yes | 86 |
| JSON.stringify | node-24.15.0 | 14.4 | 6.56 | 20.9 | 2407 | 1221 | JSON — ships with JavaScript | slower | yes | 88 |
| protobuf-es | 2.12.1 | 55.9 | 17.2 | 76.1 | 1061 | 1076 | Protocol Buffers | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `protobuf-es`.

**sample E (words), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgpackr`. Small gap: —. Time/size front: `msgpackr`, `protobuf-es`.

