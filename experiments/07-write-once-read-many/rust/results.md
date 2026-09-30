# Experiment 7 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/07-write-once-read-many/rust/logs/rust/2026-09-29-184431.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rkyv | 0.8.18 | 0.87 | 0.76 | 1.61 | 272 | 2076 | rkyv — timed read builds a full value | fastest | yes | 85 |
| prost | 0.13.5 | 0.52 | 1.12 | 1.64 | 155 | 2064 | Protocol Buffers | similar | yes | 82 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rkyv | 0.8.18 | 0.80 | 0.62 | 1.46 | 4144 | 2076 | rkyv — timed read builds a full value | fastest | yes | 89 |
| prost | 0.13.5 | 0.89 | 2.13 | 3.10 | 4131 | 2064 | Protocol Buffers | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `rkyv`, `prost`. Small gap: —. Time/size front: `rkyv`, `prost`.

**sample C (sensor), N = 1, memory** — not clearly slower: `rkyv`. Small gap: —. Time/size front: `rkyv`, `prost`.

