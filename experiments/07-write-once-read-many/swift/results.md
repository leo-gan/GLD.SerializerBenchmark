# Experiment 7 results — swift

**Date:** 2026-10-11
**Raw file:** `experiments/07-write-once-read-many/swift/logs/swift/2026-10-11-150336.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| FlatBuffers | 24.3.25 | 3.84 | 3.94 | 7.80 | 440 | 2146 | FlatBuffers | fastest | yes | 79 |
| SwiftProtobuf | 1.38.1 | 5.64 | 4.95 | 10.6 | 155 | 2064 | Protocol Buffers | slower | yes | 72 |
| CapnProto | capnproto-1.0.2 | 14.2 | 10.3 | 24.5 | 376 | 2116 | Cap’n Proto | slower | yes | 83 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SwiftProtobuf | 1.38.1 | 5.36 | 5.11 | 10.5 | 4128 | 2064 | Protocol Buffers | fastest | yes | 96 |
| FlatBuffers | 24.3.25 | 6.01 | 8.97 | 15.2 | 4216 | 2146 | FlatBuffers | slower | yes | 91 |
| CapnProto | capnproto-1.0.2 | 31.4 | 14.9 | 46.3 | 4184 | 2116 | Cap’n Proto | slower | yes | 84 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `FlatBuffers`. Small gap: —. Time/size front: `FlatBuffers`, `SwiftProtobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `SwiftProtobuf`. Small gap: —. Time/size front: `SwiftProtobuf`.

