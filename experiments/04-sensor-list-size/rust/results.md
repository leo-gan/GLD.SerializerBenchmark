# Experiment 4 results — rust

**Date:** 2026-08-16
**Raw file:** `experiments/04-sensor-list-size/rust/logs/rust/2026-08-16-161217.csv`
**Language:** rust
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| postcard | 1.1.3 | 0.09 | 0.13 | 0.21 | 91 | — | postcard — compact Rust | fastest | yes | 85 |
| prost | 0.13.5 | 0.15 | 0.20 | 0.35 | 94 | — | Protocol Buffers | slower | yes | 86 |
| rmp-serde | 1.3.1 | 0.15 | 0.22 | 0.37 | 135 | — | MessagePack | slower | yes | 85 |
| sonic-rs | 0.3.17 | 0.27 | 0.46 | 0.73 | 234 | — | JSON — fast writer from Experiment 1 | slower | yes | 88 |
| ciborium | 0.2.2 | 0.18 | 0.56 | 0.75 | 135 | — | CBOR | slower | yes | 88 |
| serde_json | 1.0.150 | 0.32 | 0.53 | 0.84 | 234 | — | JSON — usual Rust library | slower | yes | 94 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| postcard | 1.1.3 | 0.12 | 0.17 | 0.29 | 286 | — | postcard — compact Rust | fastest | yes | 93 |
| prost | 0.13.5 | 0.17 | 0.32 | 0.50 | 290 | — | Protocol Buffers | slower | yes | 96 |
| rmp-serde | 1.3.1 | 0.28 | 0.32 | 0.61 | 356 | — | MessagePack | slower | yes | 95 |
| ciborium | 0.2.2 | 0.38 | 0.77 | 1.14 | 355 | — | CBOR | slower | yes | 91 |
| sonic-rs | 0.3.17 | 0.66 | 0.92 | 1.58 | 672 | — | JSON — fast writer from Experiment 1 | slower | yes | 91 |
| serde_json | 1.0.150 | 0.58 | 1.07 | 1.67 | 672 | — | JSON — usual Rust library | slower | yes | 73 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| postcard | 1.1.3 | 0.22 | 0.29 | 0.51 | 1051 | — | postcard — compact Rust | fastest | yes | 93 |
| prost | 0.13.5 | 0.27 | 0.50 | 0.77 | 1054 | — | Protocol Buffers | slower | yes | 89 |
| rmp-serde | 1.3.1 | 0.57 | 0.59 | 1.16 | 1216 | — | MessagePack | slower | yes | 87 |
| ciborium | 0.2.2 | 1.16 | 1.62 | 2.79 | 1215 | — | CBOR | slower | yes | 91 |
| sonic-rs | 0.3.17 | 2.39 | 2.65 | 5.05 | 2420 | — | JSON — fast writer from Experiment 1 | slower | yes | 86 |
| serde_json | 1.0.150 | 2.06 | 3.15 | 5.22 | 2420 | — | JSON — usual Rust library | slower | yes | 76 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| postcard | 1.1.3 | 0.53 | 0.66 | 1.18 | 4128 | — | postcard — compact Rust | fastest | yes | 92 |
| prost | 0.13.5 | 0.69 | 0.90 | 1.58 | 4131 | — | Protocol Buffers | slower | yes | 92 |
| rmp-serde | 1.3.1 | 1.53 | 1.51 | 3.05 | 4677 | — | MessagePack | slower | yes | 87 |
| ciborium | 0.2.2 | 4.14 | 4.63 | 8.78 | 4677 | — | CBOR | slower | yes | 85 |
| serde_json | 1.0.150 | 7.45 | 10.8 | 18.2 | 9415 | — | JSON — usual Rust library | slower | yes | 90 |
| sonic-rs | 0.3.17 | 8.96 | 9.50 | 18.5 | 9415 | — | JSON — fast writer from Experiment 1 | slower | yes | 91 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| postcard | 8 | 0.15 | 0.16 | 0.31 | copied |
| rmp-serde | 8 | 0.24 | 0.27 | 0.51 | copied |
| prost | 8 | 0.29 | 0.24 | 0.52 | copied |
| sonic-rs | 8 | 0.36 | 0.48 | 0.84 | copied |
| ciborium | 8 | 0.38 | 0.64 | 1.02 | real |
| serde_json | 8 | 0.52 | 1.22 | 1.74 | real |
| postcard | 32 | 0.18 | 0.19 | 0.38 | copied |
| prost | 32 | 0.32 | 0.31 | 0.64 | copied |
| rmp-serde | 32 | 0.35 | 0.35 | 0.70 | copied |
| ciborium | 32 | 0.69 | 0.88 | 1.57 | real |
| sonic-rs | 32 | 0.76 | 0.93 | 1.69 | copied |
| serde_json | 32 | 1.06 | 2.48 | 3.54 | real |
| postcard | 128 | 0.25 | 0.34 | 0.58 | copied |
| prost | 128 | 0.34 | 0.57 | 0.91 | copied |
| rmp-serde | 128 | 0.61 | 0.64 | 1.25 | copied |
| ciborium | 128 | 1.97 | 1.85 | 3.81 | real |
| sonic-rs | 128 | 2.40 | 2.62 | 5.00 | copied |
| serde_json | 128 | 2.68 | 7.63 | 10.4 | real |
| postcard | 512 | 0.48 | 0.68 | 1.16 | copied |
| prost | 512 | 0.72 | 1.02 | 1.78 | copied |
| rmp-serde | 512 | 1.71 | 1.57 | 3.28 | copied |
| ciborium | 512 | 6.92 | 5.95 | 12.9 | real |
| sonic-rs | 512 | 9.67 | 9.87 | 19.5 | copied |
| serde_json | 512 | 9.68 | 28.3 | 38.0 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `postcard`. Small gap: —. Time/size front: `postcard`.

**32 numbers, memory** — not clearly slower: `postcard`. Small gap: —. Time/size front: `postcard`.

**128 numbers, memory** — not clearly slower: `postcard`. Small gap: —. Time/size front: `postcard`.

**512 numbers, memory** — not clearly slower: `postcard`. Small gap: —. Time/size front: `postcard`.

