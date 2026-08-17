# Experiment 5 results — rust

**Date:** 2026-08-17
**Raw file:** `experiments/05-event-log-formats/rust/logs/rust/2026-08-17-113827.csv`
**Language:** rust
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde_avro_fast | 2.1.0 | 0.35 | 0.47 | 0.83 | 96 | — | Avro | fastest | yes | 85 |
| sonic-rs | 0.3.17 | 0.28 | 0.56 | 0.83 | 258 | — | JSON — Experiment 1 | similar | yes | 89 |
| prost | 0.13.5 | 0.41 | 0.45 | 0.87 | 114 | — | Protocol Buffers | slower | yes | 86 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 16.1 | 78.9 | 95.2 | 26978 | — | JSON — Experiment 1 | fastest | yes | 95 |
| serde_avro_fast | 2.1.0 | 29.3 | 75.3 | 105 | 10778 | — | Avro | slower | yes | 82 |
| prost | 0.13.5 | 41.7 | 70.6 | 112 | 12578 | — | Protocol Buffers | slower | yes | 80 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| sonic-rs | 1 | 0.38 | 0.57 | 0.95 | copied |
| prost | 1 | 0.54 | 0.45 | 0.99 | copied |
| serde_avro_fast | 1 | 0.40 | 0.60 | 1.00 | real |
| sonic-rs | 100 | 16.3 | 80.1 | 96.7 | copied |
| serde_avro_fast | 100 | 29.6 | 76.9 | 106 | copied |
| prost | 100 | 42.5 | 72.0 | 114 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `serde_avro_fast`, `sonic-rs`. Small gap: —. Time/size front: `serde_avro_fast`.

**N = 100, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`, `serde_avro_fast`.

