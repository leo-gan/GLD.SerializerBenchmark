# Experiment 7 results — python

**Date:** 2026-09-30
**Raw file:** `experiments/07-write-once-read-many/python/logs/python/2026-09-29-184423.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 7.36.1 | 7.26 | 5.77 | 13.4 | 155 | 2064 | Protocol Buffers | fastest | yes | 93 |
| flatbuffers | 25.12.19 | 114 | 36.1 | 150 | 416 | 2136 | FlatBuffers — Python builder is slow; do not reject the format from this row | slower | yes | 93 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 7.36.1 | 9.06 | 6.10 | 15.1 | 4128 | 2064 | Protocol Buffers | fastest | yes | 92 |
| flatbuffers | 25.12.19 | 217 | 60.9 | 277 | 4192 | 2136 | FlatBuffers — Python builder is slow; do not reject the format from this row | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

