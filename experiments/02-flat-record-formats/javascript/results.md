# Experiment 2 results — javascript

**Date:** 2026-08-16
**Raw file:** `experiments/02-flat-record-formats/javascript/logs/javascript/2026-08-16-154210.csv`
**Language:** javascript
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.52 | 2.27 | 4.84 | 168 | — | JSON — ships with JavaScript | fastest | yes | 95 |
| msgpackr | 1.12.1 | 3.54 | 8.96 | 12.5 | 126 | — | MessagePack | slower | yes | 87 |
| @msgpack/msgpack | 3.1.3 | 8.35 | 7.86 | 15.9 | 124 | — | MessagePack — official package | slower | yes | 80 |
| protobufjs | 7.6.5 | 7.59 | 13.5 | 21.2 | 52 | — | Protocol Buffers | slower | yes | 84 |
| protobuf-es | 2.12.1 | 17.5 | 14.1 | 33.2 | 50 | — | Protocol Buffers | slower | yes | 86 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 43.3 | 45.2 | 90.8 | 16546 | — | JSON — ships with JavaScript | fastest | yes | 89 |
| msgpackr | 1.12.1 | 41.2 | 74.9 | 116 | 12231 | — | MessagePack | slower | yes | 82 |
| @msgpack/msgpack | 3.1.3 | 69.6 | 61.2 | 133 | 12031 | — | MessagePack — official package | slower | yes | 86 |
| protobufjs | 7.6.5 | 57.3 | 74.7 | 134 | 5047 | — | Protocol Buffers | slower | yes | 76 |
| protobuf-es | 2.12.1 | 237 | 167 | 405 | 4841 | — | Protocol Buffers | slower | yes | 81 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `@msgpack/msgpack`, `protobufjs`, `protobuf-es`.

**N = 100, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `@msgpack/msgpack`, `protobufjs`, `protobuf-es`.

