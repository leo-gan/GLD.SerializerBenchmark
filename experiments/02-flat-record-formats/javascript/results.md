# Experiment 2 results — javascript

**Date:** 2026-09-30
**Raw file:** `experiments/02-flat-record-formats/javascript/logs/javascript/2026-09-29-184139.csv`
**Language:** javascript
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 3.10 | 2.99 | 5.81 | 168 | 2406 | JSON — ships with JavaScript | fastest | yes | 90 |
| msgpackr | 1.12.1 | 4.03 | 9.75 | 14.0 | 126 | 2279 | MessagePack | slower | yes | 82 |
| protobufjs | 7.6.6 | 9.27 | 7.03 | 16.7 | 52 | 2200 | Protocol Buffers | slower | yes | 84 |
| @msgpack/msgpack | 3.1.3 | 8.62 | 8.93 | 18.3 | 124 | 2276 | MessagePack — official package | slower | yes | 80 |
| protobuf-es | 2.15.0 | 12.7 | 9.28 | 22.1 | 50 | 2158 | Protocol Buffers | slower | yes | 88 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobufjs | 7.6.6 | 57.4 | 32.1 | 90.7 | 5047 | 2200 | Protocol Buffers | fastest | yes | 82 |
| JSON.stringify | node-24.15.0 | 46.4 | 49.5 | 96.5 | 16546 | 2406 | JSON — ships with JavaScript | similar | yes | 83 |
| msgpackr | 1.12.1 | 42.0 | 77.4 | 121 | 12231 | 2279 | MessagePack | slower | yes | 84 |
| protobuf-es | 2.15.0 | 59.1 | 65.9 | 125 | 4841 | 2158 | Protocol Buffers | slower | yes | 81 |
| @msgpack/msgpack | 3.1.3 | 68.9 | 60.2 | 132 | 12031 | 2276 | MessagePack — official package | slower | yes | 79 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`, `protobufjs`, `protobuf-es`.

**N = 100, memory** — not clearly slower: `protobufjs`, `JSON.stringify`. Small gap: —. Time/size front: `protobufjs`, `protobuf-es`.

