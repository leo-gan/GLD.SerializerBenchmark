# Experiment 10 results — javascript

**Date:** 2026-09-30
**Raw file:** `experiments/10-one-vs-hundred/javascript/logs/javascript/2026-09-29-184722.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.94 | 3.08 | 6.25 | 257 | 2429 | JSON — ships with JavaScript | fastest | yes | 86 |
| msgpackr | 1.12.1 | 5.24 | 8.07 | 13.4 | 209 | 2304 | MessagePack | slower | yes | 86 |
| protobufjs | 7.6.6 | 8.54 | 6.50 | 15.4 | 123 | 2233 | Protocol Buffers | slower | yes | 87 |
| protobuf-es | 2.15.0 | 8.15 | 7.83 | 16.1 | 123 | 2192 | Protocol Buffers | slower | yes | 83 |
| @msgpack/msgpack | 3.1.3 | 8.19 | 12.9 | 21.0 | 199 | 2298 | MessagePack — official package | slower | yes | 87 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpackr | 1.12.1 | 93.8 | 137 | 231 | 20848 | 2304 | MessagePack | fastest | yes | 89 |
| protobuf-es | 2.15.0 | 118 | 161 | 279 | 12477 | 2192 | Protocol Buffers | slower | yes | 92 |
| JSON.stringify | node-24.15.0 | 82.4 | 208 | 289 | 25746 | 2429 | JSON — ships with JavaScript | slower | yes | 89 |
| @msgpack/msgpack | 3.1.3 | 137 | 152 | 293 | 19848 | 2298 | MessagePack — official package | slower | yes | 86 |
| protobufjs | 7.6.6 | 194 | 97.9 | 303 | 12477 | 2233 | Protocol Buffers | slower | yes | 94 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 4.03 | 3.54 | 7.52 | 168 | 2429 | JSON — ships with JavaScript | fastest | yes | 84 |
| msgpackr | 1.12.1 | 6.60 | 14.3 | 20.6 | 126 | 2304 | MessagePack | slower | yes | 85 |
| protobufjs | 7.6.6 | 15.9 | 12.2 | 29.1 | 52 | 2233 | Protocol Buffers | slower | yes | 92 |
| @msgpack/msgpack | 3.1.3 | 14.4 | 15.2 | 31.6 | 124 | 2298 | MessagePack — official package | slower | yes | 88 |
| protobuf-es | 2.15.0 | 20.2 | 17.4 | 39.0 | 50 | 2192 | Protocol Buffers | slower | yes | 91 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 52.5 | 58.9 | 112 | 16546 | 2429 | JSON — ships with JavaScript | fastest | yes | 84 |
| protobufjs | 7.6.6 | 90.0 | 35.4 | 124 | 5047 | 2233 | Protocol Buffers | close | yes | 86 |
| msgpackr | 1.12.1 | 46.7 | 88.1 | 140 | 12231 | 2304 | MessagePack | slower | yes | 88 |
| @msgpack/msgpack | 3.1.3 | 79.9 | 68.4 | 154 | 12031 | 2298 | MessagePack — official package | slower | yes | 88 |
| protobuf-es | 2.15.0 | 116 | 86.3 | 201 | 4841 | 2192 | Protocol Buffers | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `protobufjs`.

**sample D (event), N = 100, memory** — not clearly slower: `msgpackr`. Small gap: —. Time/size front: `msgpackr`, `protobuf-es`.

**sample B (flat), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `protobufjs`, `protobuf-es`.

**sample B (flat), N = 100, memory** — not clearly slower: `JSON.stringify`. Small gap: `protobufjs`. Time/size front: `JSON.stringify`, `protobufjs`, `protobuf-es`.

