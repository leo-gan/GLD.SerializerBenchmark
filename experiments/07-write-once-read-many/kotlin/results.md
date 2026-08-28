# Experiment 7 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/07-write-once-read-many/kotlin/logs/kotlin/2026-08-27-181742.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 24.3.25 | 27.5 | 18.9 | 49.0 | 416 | 2136 | FlatBuffers | fastest | yes | 85 |
| protobuf | 4.28.3 | 30.2 | 27.3 | 58.3 | 155 | 2064 | Protocol Buffers | close | yes | 85 |
| capnproto | 0.1.16 | 52.5 | 39.1 | 93.2 | 376 | 2116 | Cap’n Proto | slower | yes | 85 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 24.3.25 | 72.0 | 51.5 | 124 | 4192 | 2136 | FlatBuffers | fastest | yes | 88 |
| protobuf | 4.28.3 | 78.8 | 52.2 | 131 | 4128 | 2064 | Protocol Buffers | similar | yes | 97 |
| capnproto | 0.1.16 | 91.2 | 67.1 | 159 | 4184 | 2116 | Cap’n Proto | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: `protobuf`. Time/size front: `flatbuffers`, `protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `flatbuffers`, `protobuf`. Small gap: —. Time/size front: `flatbuffers`, `protobuf`.

