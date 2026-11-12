# Experiment 4 results — rust

**Date:** 2026-11-12
**Raw file:** `experiments/01-sensor-list-size/rust/logs/rust/2026-11-12-100542.csv`
**Language:** rust
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.15 | 0.40 | 0.56 | 107 | 702 | positional binary — no field names | fastest | yes | 82 |
| postcard | 1.1.3 | 0.21 | 0.45 | 0.67 | 91 | 688 | postcard — compact Rust | slower | yes | 84 |
| prost | 0.13.5 | 0.22 | 0.55 | 0.78 | 94 | 690 | Protocol Buffers | slower | yes | 84 |
| rmp-serde | 1.3.1 | 0.29 | 0.92 | 1.21 | 135 | 776 | MessagePack | slower | yes | 85 |
| sonic-rs | 0.3.17 | 0.56 | 1.33 | 1.90 | 234 | 825 | JSON — fast writer fast named JSON | slower | yes | 84 |
| serde_json | 1.0.154 | 0.51 | 1.49 | 2.02 | 234 | 825 | JSON — usual Rust library | slower | yes | 86 |
| ciborium | 0.2.2 | 0.54 | 1.58 | 2.12 | 135 | 774 | CBOR | slower | yes | 85 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.16 | 0.41 | 0.57 | 302 | 702 | positional binary — no field names | fastest | yes | 83 |
| postcard | 1.1.3 | 0.24 | 0.50 | 0.75 | 286 | 688 | postcard — compact Rust | slower | yes | 81 |
| prost | 0.13.5 | 0.30 | 0.70 | 0.97 | 290 | 690 | Protocol Buffers | slower | yes | 80 |
| rmp-serde | 1.3.1 | 0.35 | 1.08 | 1.42 | 356 | 776 | MessagePack | slower | yes | 84 |
| ciborium | 0.2.2 | 0.84 | 1.86 | 2.69 | 355 | 774 | CBOR | slower | yes | 80 |
| serde_json | 1.0.154 | 0.99 | 2.22 | 3.23 | 672 | 825 | JSON — usual Rust library | slower | yes | 82 |
| sonic-rs | 0.3.17 | 1.21 | 2.10 | 3.33 | 672 | 825 | JSON — fast writer fast named JSON | slower | yes | 80 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.19 | 0.46 | 0.65 | 1066 | 702 | positional binary — no field names | fastest | yes | 81 |
| postcard | 1.1.3 | 0.35 | 0.68 | 1.03 | 1051 | 688 | postcard — compact Rust | slower | yes | 84 |
| prost | 0.13.5 | 0.42 | 1.17 | 1.61 | 1054 | 690 | Protocol Buffers | slower | yes | 89 |
| rmp-serde | 1.3.1 | 0.54 | 1.40 | 1.96 | 1216 | 776 | MessagePack | slower | yes | 81 |
| ciborium | 0.2.2 | 1.67 | 2.85 | 4.52 | 1215 | 774 | CBOR | slower | yes | 79 |
| serde_json | 1.0.154 | 2.51 | 4.85 | 7.34 | 2420 | 825 | JSON — usual Rust library | slower | yes | 82 |
| sonic-rs | 0.3.17 | 3.75 | 4.87 | 8.64 | 2420 | 825 | JSON — fast writer fast named JSON | slower | yes | 84 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.28 | 0.62 | 0.90 | 4143 | 702 | positional binary — no field names | fastest | yes | 82 |
| postcard | 1.1.3 | 0.67 | 1.22 | 1.89 | 4128 | 688 | postcard — compact Rust | slower | yes | 92 |
| prost | 0.13.5 | 0.84 | 2.01 | 2.82 | 4131 | 690 | Protocol Buffers | slower | yes | 87 |
| rmp-serde | 1.3.1 | 1.15 | 2.72 | 3.91 | 4677 | 776 | MessagePack | slower | yes | 93 |
| ciborium | 0.2.2 | 5.14 | 7.18 | 12.4 | 4677 | 774 | CBOR | slower | yes | 96 |
| serde_json | 1.0.154 | 8.98 | 14.4 | 23.6 | 9415 | 825 | JSON — usual Rust library | slower | yes | 91 |
| sonic-rs | 0.3.17 | 13.8 | 15.0 | 28.8 | 9415 | 825 | JSON — fast writer fast named JSON | slower | yes | 92 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| gld-kiln | 8 | 0.25 | 0.42 | 0.68 | copied |
| postcard | 8 | 0.32 | 0.45 | 0.78 | copied |
| prost | 8 | 0.40 | 0.56 | 0.96 | copied |
| rmp-serde | 8 | 0.40 | 0.93 | 1.32 | copied |
| sonic-rs | 8 | 0.70 | 1.45 | 2.15 | copied |
| ciborium | 8 | 1.25 | 1.62 | 2.85 | real |
| serde_json | 8 | 0.99 | 2.39 | 3.42 | real |
| gld-kiln | 32 | 0.26 | 0.49 | 0.76 | copied |
| postcard | 32 | 0.38 | 0.52 | 0.92 | copied |
| prost | 32 | 0.47 | 0.75 | 1.22 | copied |
| rmp-serde | 32 | 0.53 | 1.17 | 1.71 | copied |
| ciborium | 32 | 1.72 | 1.86 | 3.60 | real |
| sonic-rs | 32 | 1.40 | 2.30 | 3.70 | copied |
| serde_json | 32 | 1.61 | 4.31 | 5.89 | real |
| gld-kiln | 128 | 0.30 | 0.59 | 0.91 | copied |
| postcard | 128 | 0.50 | 0.85 | 1.35 | copied |
| prost | 128 | 0.68 | 1.26 | 1.97 | copied |
| rmp-serde | 128 | 0.70 | 1.65 | 2.35 | copied |
| ciborium | 128 | 3.56 | 3.16 | 6.79 | real |
| sonic-rs | 128 | 4.05 | 5.29 | 9.39 | copied |
| serde_json | 128 | 3.79 | 11.0 | 14.7 | real |
| gld-kiln | 512 | 0.56 | 0.80 | 1.32 | copied |
| postcard | 512 | 0.99 | 1.41 | 2.45 | copied |
| prost | 512 | 1.11 | 2.07 | 3.22 | copied |
| rmp-serde | 512 | 1.44 | 3.09 | 4.67 | copied |
| ciborium | 512 | 10.8 | 8.01 | 18.7 | real |
| sonic-rs | 512 | 14.7 | 15.6 | 30.5 | copied |
| serde_json | 512 | 12.4 | 36.3 | 48.6 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

**32 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

**128 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

**512 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

