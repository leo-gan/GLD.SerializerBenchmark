# Experiment 7 results — cpp

**Date:** 2026-08-17
**Raw file:** `experiments/07-write-once-read-many/cpp/logs/cpp/2026-08-17-120459.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | flatbuffers | 0.33 | 0.94 | 1.26 | 188 | 2192 | FlatBuffers | fastest | yes | 91 |
| capnproto | 1.0.x | 0.78 | 0.76 | 1.55 | 392 | 2116 | Cap’n Proto | slower | yes | 89 |
| protobuf | 3.12.4 | 0.58 | 0.99 | 1.57 | 164 | 2066 | Protocol Buffers — official libprotobuf | slower | yes | 95 |
| protobuf-wire | wire-v2 | 1.65 | 0.87 | 2.55 | 164 | 2171 | Protocol Buffers — in-tree wire helper | slower | yes | 95 |
| flexbuffers | flatbuffers-flex | 6.77 | 6.41 | 13.2 | 467 | 2206 | FlexBuffers | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 3.12.4 | 0.72 | 0.63 | 1.36 | 4127 | 2066 | Protocol Buffers — official libprotobuf | fastest | yes | 88 |
| capnproto | 1.0.x | 1.18 | 1.73 | 2.93 | 4184 | 2116 | Cap’n Proto | slower | yes | 80 |
| flatbuffers | flatbuffers | 0.58 | 3.41 | 4.01 | 4660 | 2192 | FlatBuffers | slower | yes | 82 |
| protobuf-wire | wire-v2 | 11.7 | 3.20 | 14.9 | 4636 | 2171 | Protocol Buffers — in-tree wire helper | slower | yes | 88 |
| flexbuffers | flatbuffers-flex | 9.26 | 13.1 | 22.4 | 4743 | 2206 | FlexBuffers | slower | yes | 81 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: —. Time/size front: `flatbuffers`, `protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

