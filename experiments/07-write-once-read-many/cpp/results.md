# Experiment 7 results — cpp

**Date:** 2026-08-17
**Raw file:** `experiments/07-write-once-read-many/cpp/logs/cpp/2026-08-17-110234.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | flatbuffers | 0.60 | 0.72 | 1.33 | 188 | — | FlatBuffers | fastest | yes | 99 |
| capnproto | 1.0.x | 1.02 | 0.52 | 1.52 | 392 | — | Cap’n Proto | close | yes | 95 |
| protobuf-wire | wire-v2 | 1.34 | 0.67 | 1.98 | 164 | — | Protocol Buffers — in-tree wire helper (official libprotobuf did not run) | slower | yes | 94 |
| flexbuffers | flatbuffers-flex | 3.64 | 5.17 | 8.80 | 467 | — | FlexBuffers | slower | yes | 89 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| capnproto | 1.0.x | 0.98 | 1.70 | 2.70 | 4184 | — | Cap’n Proto | fastest | yes | 96 |
| flatbuffers | flatbuffers | 0.48 | 3.07 | 3.56 | 4660 | — | FlatBuffers | slower | yes | 93 |
| protobuf-wire | wire-v2 | 11.7 | 2.95 | 14.7 | 4636 | — | Protocol Buffers — in-tree wire helper (official libprotobuf did not run) | slower | yes | 85 |
| flexbuffers | flatbuffers-flex | 8.30 | 12.6 | 20.9 | 4743 | — | FlexBuffers | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: `capnproto`. Time/size front: `flatbuffers`, `protobuf-wire`.

**sample C (sensor), N = 1, memory** — not clearly slower: `capnproto`. Small gap: —. Time/size front: `capnproto`.

