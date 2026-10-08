# Experiment 9 results — javascript

**Date:** 2026-09-30
**Raw file:** `experiments/09-compression-size/javascript/logs/javascript/2026-09-29-184521.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.46 | 2.44 | 5.02 | 168 | 137 | JSON — ships with JavaScript | fastest | yes | 87 |
| msgpackr | 1.12.1 | 4.41 | 9.44 | 14.3 | 126 | 129 | MessagePack | slower | yes | 87 |
| protobuf-es | 2.15.0 | 9.78 | 7.50 | 17.8 | 50 | 71 | Protocol Buffers | slower | yes | 81 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 4.38 | 4.57 | 10.0 | 411 | 286 | JSON — ships with JavaScript | fastest | yes | 89 |
| msgpackr | 1.12.1 | 9.45 | 14.9 | 24.9 | 348 | 272 | MessagePack | slower | yes | 86 |
| protobuf-es | 2.15.0 | 17.2 | 24.0 | 42.5 | 368 | 275 | Protocol Buffers | slower | yes | 90 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpackr | 1.12.1 | 9.97 | 12.5 | 23.0 | 1214 | 1169 | MessagePack | fastest | yes | 90 |
| JSON.stringify | node-24.15.0 | 18.8 | 9.15 | 27.7 | 2407 | 1221 | JSON — ships with JavaScript | close | yes | 88 |
| protobuf-es | 2.15.0 | 25.7 | 14.0 | 39.8 | 1061 | 1076 | Protocol Buffers | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `protobuf-es`.

**sample E (words), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`.

**sample C (sensor), N = 1, memory** — not clearly slower: `msgpackr`. Small gap: `JSON.stringify`. Time/size front: `msgpackr`, `protobuf-es`.

