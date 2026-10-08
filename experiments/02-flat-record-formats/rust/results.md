# Experiment 2 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/02-flat-record-formats/rust/logs/rust/2026-09-29-184145.csv`
**Language:** rust
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.16 | 0.31 | 0.47 | 55 | 2142 | Protocol Buffers | fastest | yes | 90 |
| rmp-serde | 1.3.1 | 0.18 | 0.69 | 0.86 | 136 | 2370 | MessagePack | slower | yes | 86 |
| sonic-rs | 0.3.17 | 0.30 | 0.85 | 1.14 | 182 | 2596 | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| serde_json | 1.0.151 | 0.34 | 0.93 | 1.25 | 182 | 2596 | JSON — usual Rust library | slower | yes | 91 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 6.40 | 16.3 | 22.6 | 5102 | 2142 | Protocol Buffers | fastest | yes | 92 |
| rmp-serde | 1.3.1 | 5.98 | 31.8 | 37.7 | 13364 | 2370 | MessagePack | slower | yes | 93 |
| sonic-rs | 0.3.17 | 12.3 | 32.4 | 44.6 | 18070 | 2596 | JSON — fast writer from Experiment 1 | slower | yes | 93 |
| serde_json | 1.0.151 | 17.4 | 48.4 | 66.0 | 18070 | 2596 | JSON — usual Rust library | slower | yes | 88 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| rmp-serde | 1 | 0.27 | 0.74 | 1.02 | copied |
| sonic-rs | 1 | 0.47 | 0.91 | 1.36 | copied |
| serde_json | 1 | 0.82 | 1.73 | 2.56 | real |
| prost | 100 | 6.52 | 16.3 | 23.1 | copied |
| rmp-serde | 100 | 5.96 | 31.9 | 37.9 | copied |
| sonic-rs | 100 | 12.2 | 32.5 | 44.8 | copied |
| serde_json | 100 | 17.5 | 48.7 | 66.2 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

**N = 100, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

