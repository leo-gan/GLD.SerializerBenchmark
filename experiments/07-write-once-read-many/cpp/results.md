# Experiment 7 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/07-write-once-read-many/cpp/logs/cpp/2026-09-04-111810.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| capnproto | 1.0.x | 1.09 | 1.66 | 2.75 | 392 | 2116 | Cap’n Proto | fastest | yes | 83 |
| flatbuffers | flatbuffers | 1.20 | 2.51 | 3.76 | 188 | 2192 | FlatBuffers | slower | yes | 86 |
| protobuf | 3.12.4 | 2.58 | 3.29 | 5.79 | 164 | 2066 | Protocol Buffers — official libprotobuf | slower | yes | 90 |
| protobuf-wire | wire-v2 | 3.82 | 2.30 | 6.13 | 164 | 2171 | Protocol Buffers — in-tree wire helper | slower | yes | 85 |
| flexbuffers | flatbuffers-flex | 12.5 | 15.0 | 27.7 | 467 | 2206 | FlexBuffers | slower | yes | 89 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| capnproto | 1.0.x | 3.16 | 3.27 | 6.36 | 4184 | 2116 | Cap’n Proto | fastest | yes | 95 |
| protobuf | 3.12.4 | 3.40 | 3.03 | 6.52 | 4127 | 2066 | Protocol Buffers — official libprotobuf | similar | yes | 89 |
| flatbuffers | flatbuffers | 2.18 | 9.13 | 11.4 | 4660 | 2192 | FlatBuffers | slower | yes | 90 |
| protobuf-wire | wire-v2 | 20.5 | 8.89 | 30.0 | 4636 | 2171 | Protocol Buffers — in-tree wire helper | slower | yes | 93 |
| flexbuffers | flatbuffers-flex | 22.9 | 33.6 | 56.5 | 4743 | 2206 | FlexBuffers | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `capnproto`. Small gap: —. Time/size front: `capnproto`, `flatbuffers`, `protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `capnproto`, `protobuf`. Small gap: —. Time/size front: `capnproto`, `protobuf`.

