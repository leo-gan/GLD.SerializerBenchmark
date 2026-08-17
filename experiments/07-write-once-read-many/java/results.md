# Experiment 7 results — java

**Date:** 2026-08-17
**Raw file:** `experiments/07-write-once-read-many/java/logs/java/2026-08-17-130259.csv`
**Language:** java
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | unknown | 24.7 | 18.1 | 45.4 | 416 | 2136 | FlatBuffers | fastest | yes | 90 |
| protobuf | 4.28.3 | 16.7 | 41.4 | 62.8 | 155 | 2064 | Protocol Buffers | close | yes | 91 |
| capnproto | unknown | 51.9 | 36.3 | 90.0 | 376 | 2116 | Cap’n Proto | slower | yes | 84 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | unknown | 25.7 | 20.9 | 47.0 | 4192 | 2136 | FlatBuffers | fastest | yes | 91 |
| capnproto | unknown | 64.9 | 37.1 | 102 | 4184 | 2116 | Cap’n Proto | slower | yes | 95 |
| protobuf | 4.28.3 | 44.6 | 58.9 | 106 | 4128 | 2064 | Protocol Buffers | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: `protobuf`. Time/size front: `flatbuffers`, `protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: —. Time/size front: `flatbuffers`, `capnproto`, `protobuf`.

