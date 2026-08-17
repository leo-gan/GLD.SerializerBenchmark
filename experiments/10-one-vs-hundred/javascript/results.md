# Experiment 10 results — javascript

**Date:** 2026-08-17
**Raw file:** `experiments/10-one-vs-hundred/javascript/logs/javascript/2026-08-17-110659.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.24 | 2.39 | 4.67 | 257 | — | JSON — ships with JavaScript | fastest | yes | 90 |
| msgpackr | 1.12.1 | 4.35 | 6.88 | 11.2 | 209 | — | MessagePack | slower | yes | 75 |
| @msgpack/msgpack | 3.1.3 | 7.29 | 10.9 | 18.9 | 199 | — | MessagePack — official package | slower | yes | 85 |
| protobufjs | 7.6.5 | 7.71 | 13.4 | 21.2 | 123 | — | Protocol Buffers | slower | yes | 82 |
| protobuf-es | 2.12.1 | 17.0 | 12.0 | 29.0 | 123 | — | Protocol Buffers | slower | yes | 82 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgpackr | 1.12.1 | 92.8 | 141 | 235 | 20848 | — | MessagePack | fastest | yes | 88 |
| JSON.stringify | node-24.15.0 | 78.1 | 174 | 249 | 25746 | — | JSON — ships with JavaScript | close | yes | 87 |
| @msgpack/msgpack | 3.1.3 | 141 | 151 | 292 | 19848 | — | MessagePack — official package | slower | yes | 85 |
| protobufjs | 7.6.5 | 159 | 187 | 355 | 12477 | — | Protocol Buffers | slower | yes | 87 |
| protobuf-es | 2.12.1 | 813 | 403 | 1231 | 12477 | — | Protocol Buffers | slower | yes | 80 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.72 | 2.36 | 5.10 | 168 | — | JSON — ships with JavaScript | fastest | yes | 92 |
| msgpackr | 1.12.1 | 3.84 | 9.61 | 13.9 | 126 | — | MessagePack | slower | yes | 86 |
| @msgpack/msgpack | 3.1.3 | 9.51 | 10.3 | 20.2 | 124 | — | MessagePack — official package | slower | yes | 86 |
| protobufjs | 7.6.5 | 8.71 | 16.4 | 26.8 | 52 | — | Protocol Buffers | slower | yes | 86 |
| protobuf-es | 2.12.1 | 20.5 | 16.5 | 37.7 | 50 | — | Protocol Buffers | slower | yes | 86 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 45.8 | 48.3 | 92.9 | 16546 | — | JSON — ships with JavaScript | fastest | yes | 87 |
| msgpackr | 1.12.1 | 43.4 | 79.0 | 123 | 12231 | — | MessagePack | slower | yes | 86 |
| protobufjs | 7.6.5 | 60.4 | 80.3 | 143 | 5047 | — | Protocol Buffers | slower | yes | 84 |
| @msgpack/msgpack | 3.1.3 | 77.3 | 65.4 | 144 | 12031 | — | MessagePack — official package | slower | yes | 83 |
| protobuf-es | 2.12.1 | 268 | 176 | 450 | 4841 | — | Protocol Buffers | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `@msgpack/msgpack`, `protobufjs`.

**sample D (event), N = 100, memory** — not clearly slower: `msgpackr`. Small gap: `JSON.stringify`. Time/size front: `msgpackr`, `@msgpack/msgpack`, `protobufjs`.

**sample B (flat), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `@msgpack/msgpack`, `protobufjs`, `protobuf-es`.

**sample B (flat), N = 100, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `protobufjs`, `protobuf-es`.

