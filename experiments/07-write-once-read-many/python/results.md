# Experiment 7 results — python

**Date:** 2026-08-17
**Raw file:** `experiments/07-write-once-read-many/python/logs/python/2026-08-17-110259.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 7.35.1 | 2.55 | 3.00 | 5.56 | 155 | 2064 | Protocol Buffers | fastest | yes | 84 |
| flatbuffers | 25.12.19 | 89.7 | 29.6 | 120 | 416 | 2136 | FlatBuffers — Python builder is slow; do not reject the format from this row | slower | yes | 91 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 7.35.1 | 6.46 | 5.57 | 12.2 | 4128 | 2064 | Protocol Buffers | fastest | yes | 90 |
| flatbuffers | 25.12.19 | 206 | 57.4 | 264 | 4192 | 2136 | FlatBuffers — Python builder is slow; do not reject the format from this row | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

