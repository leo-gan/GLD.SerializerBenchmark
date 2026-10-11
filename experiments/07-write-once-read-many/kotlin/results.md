# Experiment 7 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/07-write-once-read-many/kotlin/logs/kotlin/2026-10-11-150350.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 24.3.25 | 30.7 | 16.7 | 50.8 | 416 | 2136 | FlatBuffers | fastest | yes | 92 |
| protobuf | 4.35.0 | 33.6 | 29.3 | 63.4 | 155 | 2064 | Protocol Buffers | close | yes | 85 |
| capnproto | 0.1.16 | 61.3 | 37.9 | 101 | 376 | 2116 | Cap’n Proto | slower | yes | 84 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 24.3.25 | 62.9 | 43.4 | 106 | 4192 | 2136 | FlatBuffers | fastest | yes | 93 |
| protobuf | 4.35.0 | 71.2 | 46.4 | 110 | 4128 | 2064 | Protocol Buffers | similar | yes | 95 |
| capnproto | 0.1.16 | 79.3 | 62.0 | 141 | 4184 | 2116 | Cap’n Proto | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: `protobuf`. Time/size front: `flatbuffers`, `protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `flatbuffers`, `protobuf`. Small gap: —. Time/size front: `flatbuffers`, `protobuf`.

