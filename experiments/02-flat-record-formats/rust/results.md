# Experiment 2 results — rust

**Date:** 2026-08-16
**Raw file:** `experiments/02-flat-record-formats/rust/logs/rust/2026-08-16-154212.csv`
**Language:** rust
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.10 | 0.11 | 0.21 | 55 | — | Protocol Buffers | fastest | yes | 86 |
| rmp-serde | 1.3.1 | 0.11 | 0.20 | 0.32 | 136 | — | MessagePack | slower | yes | 88 |
| sonic-rs | 0.3.17 | 0.19 | 0.27 | 0.46 | 182 | — | JSON — fast writer from Experiment 1 | slower | yes | 91 |
| serde_json | 1.0.150 | 0.19 | 0.34 | 0.53 | 182 | — | JSON — usual Rust library | slower | yes | 92 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 8.02 | 15.7 | 23.8 | 5102 | — | Protocol Buffers | fastest | yes | 88 |
| rmp-serde | 1.3.1 | 5.48 | 28.5 | 34.0 | 13364 | — | MessagePack | slower | yes | 91 |
| sonic-rs | 0.3.17 | 11.4 | 30.4 | 41.9 | 18070 | — | JSON — fast writer from Experiment 1 | slower | yes | 88 |
| serde_json | 1.0.150 | 16.1 | 43.6 | 59.6 | 18070 | — | JSON — usual Rust library | slower | yes | 90 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| prost | 1 | 0.18 | 0.13 | 0.31 | copied |
| rmp-serde | 1 | 0.17 | 0.24 | 0.41 | copied |
| sonic-rs | 1 | 0.23 | 0.30 | 0.53 | copied |
| serde_json | 1 | 0.39 | 0.91 | 1.31 | real |
| prost | 100 | 8.06 | 15.7 | 23.8 | copied |
| rmp-serde | 100 | 5.48 | 28.5 | 34.0 | copied |
| sonic-rs | 100 | 11.3 | 30.1 | 41.6 | copied |
| serde_json | 100 | 16.0 | 43.5 | 60.0 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

**N = 100, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

