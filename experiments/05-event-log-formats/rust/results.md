# Experiment 5 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/05-event-log-formats/rust/logs/rust/2026-09-29-184349.csv`
**Language:** rust
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.30 | 0.77 | 1.07 | 114 | 4350 | Protocol Buffers | fastest | yes | 84 |
| sonic-rs | 0.3.17 | 0.38 | 1.22 | 1.60 | 258 | 4425 | JSON — Experiment 1 | slower | yes | 83 |
| serde_avro_fast | 2.1.1 | 0.63 | 1.01 | 1.67 | 96 | 3840 | Avro | slower | yes | 86 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 18.9 | 62.1 | 81.9 | 12578 | 4350 | Protocol Buffers | fastest | yes | 89 |
| sonic-rs | 0.3.17 | 16.7 | 72.7 | 89.6 | 26978 | 4425 | JSON — Experiment 1 | slower | yes | 86 |
| serde_avro_fast | 2.1.1 | 30.5 | 67.6 | 98.2 | 10778 | 3840 | Avro | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| sonic-rs | 1 | 0.50 | 1.43 | 1.94 | copied |
| serde_avro_fast | 1 | 0.88 | 1.15 | 2.00 | real |
| prost | 100 | 20.5 | 62.2 | 82.9 | copied |
| sonic-rs | 100 | 17.0 | 73.9 | 91.0 | copied |
| serde_avro_fast | 100 | 30.8 | 67.9 | 99.3 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`, `serde_avro_fast`.

**N = 100, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`, `serde_avro_fast`.

