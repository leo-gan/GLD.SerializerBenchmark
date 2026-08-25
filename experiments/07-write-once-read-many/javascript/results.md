# Experiment 7 results — javascript

**Date:** 2026-08-17
**Raw file:** `experiments/07-write-once-read-many/javascript/logs/javascript/2026-08-17-110257.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 24.12.23 | 24.9 | 13.8 | 38.7 | 416 | — | FlatBuffers | fastest | yes | 91 |
| flexbuffers | 24.12.23 | 383 | 55.7 | 438 | 579 | — | FlexBuffers | slower | yes | 74 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 24.12.23 | 31.0 | 17.5 | 48.8 | 4192 | — | FlatBuffers | fastest | yes | 89 |
| flexbuffers | 24.12.23 | 1012 | 615 | 1649 | 19841 | — | FlexBuffers | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: —. Time/size front: `flatbuffers`.

**sample C (sensor), N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: —. Time/size front: `flatbuffers`.

