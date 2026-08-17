# Experiment 7 results — rust

**Date:** 2026-08-17
**Raw file:** `experiments/07-write-once-read-many/rust/logs/rust/2026-08-17-110302.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rkyv | 0.8.17 | 0.43 | 0.32 | 0.74 | 272 | — | rkyv — timed read builds a full value | fastest | yes | 93 |
| prost | 0.13.5 | 0.51 | 0.58 | 1.09 | 155 | — | Protocol Buffers | slower | yes | 87 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rkyv | 0.8.17 | 0.33 | 0.20 | 0.52 | 4144 | — | rkyv — timed read builds a full value | fastest | yes | 92 |
| prost | 0.13.5 | 0.76 | 0.95 | 1.71 | 4131 | — | Protocol Buffers | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `rkyv`. Small gap: —. Time/size front: `rkyv`, `prost`.

**sample C (sensor), N = 1, memory** — not clearly slower: `rkyv`. Small gap: —. Time/size front: `rkyv`, `prost`.

