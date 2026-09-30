# Experiment 7 results — javascript

**Date:** 2026-09-30
**Raw file:** `experiments/07-write-once-read-many/javascript/logs/javascript/2026-09-29-184429.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 24.12.23 | 37.8 | 17.9 | 58.8 | 416 | 2130 | FlatBuffers | fastest | yes | 89 |
| flexbuffers | 24.12.23 | 181 | 68.5 | 254 | 579 | 5394 | FlexBuffers | slower | yes | 79 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 24.12.23 | 33.1 | 17.9 | 49.6 | 4192 | 2130 | FlatBuffers | fastest | yes | 91 |
| flexbuffers | 24.12.23 | 980 | 494 | 1510 | 19841 | 5394 | FlexBuffers | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: —. Time/size front: `flatbuffers`.

**sample C (sensor), N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: —. Time/size front: `flatbuffers`.

