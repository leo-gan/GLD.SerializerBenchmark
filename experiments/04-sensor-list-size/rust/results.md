# Experiment 4 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/04-sensor-list-size/rust/logs/rust/2026-09-29-184156.csv`
**Language:** rust
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| postcard | 1.1.3 | 0.17 | 0.29 | 0.45 | 91 | 688 | postcard — compact Rust | fastest | yes | 85 |
| prost | 0.13.5 | 0.18 | 0.42 | 0.60 | 94 | 690 | Protocol Buffers | slower | yes | 84 |
| rmp-serde | 1.3.1 | 0.25 | 0.71 | 0.98 | 135 | 776 | MessagePack | slower | yes | 87 |
| serde_json | 1.0.151 | 0.41 | 1.05 | 1.47 | 234 | 878 | JSON — usual Rust library | slower | yes | 88 |
| sonic-rs | 0.3.17 | 0.49 | 1.04 | 1.53 | 234 | 878 | JSON — fast writer from Experiment 1 | slower | yes | 83 |
| ciborium | 0.2.2 | 0.44 | 1.14 | 1.57 | 135 | 776 | CBOR | slower | yes | 85 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| postcard | 1.1.3 | 0.23 | 0.38 | 0.61 | 286 | 688 | postcard — compact Rust | fastest | yes | 89 |
| prost | 0.13.5 | 0.23 | 0.63 | 0.87 | 290 | 690 | Protocol Buffers | slower | yes | 85 |
| rmp-serde | 1.3.1 | 0.33 | 0.92 | 1.25 | 356 | 776 | MessagePack | slower | yes | 89 |
| ciborium | 0.2.2 | 0.71 | 1.44 | 2.19 | 355 | 776 | CBOR | slower | yes | 84 |
| serde_json | 1.0.151 | 0.83 | 1.86 | 2.71 | 672 | 878 | JSON — usual Rust library | slower | yes | 88 |
| sonic-rs | 0.3.17 | 1.06 | 1.84 | 2.91 | 672 | 878 | JSON — fast writer from Experiment 1 | slower | yes | 86 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| postcard | 1.1.3 | 0.34 | 0.53 | 0.86 | 1051 | 688 | postcard — compact Rust | fastest | yes | 84 |
| prost | 0.13.5 | 0.30 | 1.08 | 1.38 | 1054 | 690 | Protocol Buffers | slower | yes | 79 |
| rmp-serde | 1.3.1 | 0.45 | 1.27 | 1.73 | 1216 | 776 | MessagePack | slower | yes | 85 |
| ciborium | 0.2.2 | 1.59 | 2.51 | 4.11 | 1215 | 776 | CBOR | slower | yes | 85 |
| serde_json | 1.0.151 | 2.32 | 4.54 | 6.88 | 2420 | 878 | JSON — usual Rust library | slower | yes | 81 |
| sonic-rs | 0.3.17 | 3.53 | 4.43 | 7.97 | 2420 | 878 | JSON — fast writer from Experiment 1 | slower | yes | 78 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| postcard | 1.1.3 | 0.69 | 1.17 | 1.85 | 4128 | 688 | postcard — compact Rust | fastest | yes | 97 |
| prost | 0.13.5 | 0.87 | 2.00 | 2.86 | 4131 | 690 | Protocol Buffers | slower | yes | 98 |
| rmp-serde | 1.3.1 | 1.07 | 2.67 | 3.75 | 4677 | 776 | MessagePack | slower | yes | 97 |
| ciborium | 0.2.2 | 5.10 | 6.56 | 11.6 | 4677 | 776 | CBOR | slower | yes | 95 |
| serde_json | 1.0.151 | 8.54 | 14.1 | 22.7 | 9415 | 878 | JSON — usual Rust library | slower | yes | 89 |
| sonic-rs | 0.3.17 | 13.5 | 14.3 | 27.8 | 9415 | 878 | JSON — fast writer from Experiment 1 | slower | yes | 94 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| postcard | 8 | 0.28 | 0.34 | 0.61 | copied |
| rmp-serde | 8 | 0.34 | 0.72 | 1.07 | copied |
| sonic-rs | 8 | 0.63 | 1.08 | 1.70 | copied |
| ciborium | 8 | 0.84 | 1.29 | 2.16 | real |
| serde_json | 8 | 1.03 | 1.86 | 2.90 | real |
| postcard | 32 | 0.33 | 0.40 | 0.74 | copied |
| rmp-serde | 32 | 0.45 | 0.94 | 1.39 | copied |
| ciborium | 32 | 1.25 | 1.70 | 2.94 | real |
| sonic-rs | 32 | 1.20 | 1.87 | 3.07 | copied |
| serde_json | 32 | 1.70 | 3.54 | 5.28 | real |
| postcard | 128 | 0.46 | 0.69 | 1.15 | copied |
| rmp-serde | 128 | 0.61 | 1.42 | 2.04 | copied |
| ciborium | 128 | 2.77 | 3.03 | 5.81 | real |
| sonic-rs | 128 | 3.74 | 4.66 | 8.38 | copied |
| serde_json | 128 | 3.73 | 9.85 | 13.7 | real |
| postcard | 512 | 0.93 | 1.26 | 2.18 | copied |
| rmp-serde | 512 | 1.31 | 2.83 | 4.13 | copied |
| ciborium | 512 | 8.91 | 8.10 | 17.0 | real |
| sonic-rs | 512 | 14.1 | 14.8 | 29.0 | copied |
| serde_json | 512 | 11.7 | 33.9 | 45.6 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `postcard`. Small gap: —. Time/size front: `postcard`.

**32 numbers, memory** — not clearly slower: `postcard`. Small gap: —. Time/size front: `postcard`.

**128 numbers, memory** — not clearly slower: `postcard`. Small gap: —. Time/size front: `postcard`.

**512 numbers, memory** — not clearly slower: `postcard`. Small gap: —. Time/size front: `postcard`.

