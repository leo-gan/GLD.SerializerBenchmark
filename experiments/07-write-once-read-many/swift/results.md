# Experiment 7 results — swift

**Date:** 2026-08-17
**Raw file:** `experiments/07-write-once-read-many/swift/logs/swift/2026-08-17-114046.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| FlatBuffers | 24.3.25 | 3.85 | 3.92 | 7.79 | 440 | — | FlatBuffers | fastest | yes | 77 |
| SwiftProtobuf | 1.38.1 | 4.65 | 4.35 | 9.02 | 155 | — | Protocol Buffers | slower | yes | 80 |
| CapnProto | capnproto-1.0.2 | 15.9 | 10.5 | 26.5 | 376 | — | Cap’n Proto | slower | yes | 69 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 5.73 | 4.90 | 10.8 | 4128 | — | Protocol Buffers | fastest | yes | 92 |
| FlatBuffers | 24.3.25 | 5.62 | 8.36 | 14.0 | 4216 | — | FlatBuffers | slower | yes | 82 |
| CapnProto | capnproto-1.0.2 | 33.9 | 15.2 | 49.2 | 4184 | — | Cap’n Proto | slower | yes | 76 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `FlatBuffers`. Small gap: —. Time/size front: `FlatBuffers`, `SwiftProtobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

