# Experiment 4 results — rust

**Date:** 2026-11-12
**Raw file:** `experiments/01-sensor-list-size/rust/logs/rust/2026-11-12-163646.csv`
**Language:** rust
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.23 | 0.58 | 0.83 | 107 | 702 | positional binary — no field names | fastest | yes | 86 |
| postcard | 1.1.3 | 0.38 | 0.60 | 0.99 | 91 | 688 | postcard — compact Rust | close | yes | 88 |
| prost | 0.13.5 | 0.34 | 0.66 | 1.02 | 94 | 690 | Protocol Buffers | slower | yes | 91 |
| rmp-serde | 1.3.1 | 0.51 | 1.37 | 1.83 | 135 | 776 | MessagePack | slower | yes | 95 |
| ciborium | 0.2.2 | 0.73 | 1.88 | 2.62 | 135 | 774 | CBOR | slower | yes | 87 |
| serde_json | 1.0.154 | 0.60 | 2.15 | 2.78 | 234 | 825 | JSON — usual Rust library | slower | yes | 86 |
| sonic-rs | 0.3.17 | 0.82 | 2.16 | 3.04 | 234 | 825 | JSON — fast writer fast named JSON | slower | yes | 86 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.20 | 0.54 | 0.75 | 302 | 702 | positional binary — no field names | fastest | yes | 87 |
| postcard | 1.1.3 | 0.36 | 0.60 | 0.95 | 286 | 688 | postcard — compact Rust | slower | yes | 88 |
| prost | 0.13.5 | 0.32 | 0.80 | 1.14 | 290 | 690 | Protocol Buffers | slower | yes | 87 |
| rmp-serde | 1.3.1 | 0.51 | 1.42 | 1.93 | 356 | 776 | MessagePack | slower | yes | 82 |
| ciborium | 0.2.2 | 0.94 | 2.06 | 3.02 | 355 | 774 | CBOR | slower | yes | 90 |
| sonic-rs | 0.3.17 | 1.34 | 2.67 | 4.01 | 672 | 825 | JSON — fast writer fast named JSON | slower | yes | 86 |
| serde_json | 1.0.154 | 1.03 | 2.94 | 4.02 | 672 | 825 | JSON — usual Rust library | slower | yes | 83 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.26 | 0.57 | 0.85 | 1066 | 702 | positional binary — no field names | fastest | yes | 88 |
| postcard | 1.1.3 | 0.47 | 0.73 | 1.23 | 1051 | 688 | postcard — compact Rust | slower | yes | 84 |
| prost | 0.13.5 | 0.41 | 1.15 | 1.59 | 1054 | 690 | Protocol Buffers | slower | yes | 86 |
| rmp-serde | 1.3.1 | 0.71 | 1.67 | 2.40 | 1216 | 776 | MessagePack | slower | yes | 87 |
| ciborium | 0.2.2 | 1.69 | 2.99 | 4.69 | 1215 | 774 | CBOR | slower | yes | 86 |
| serde_json | 1.0.154 | 2.64 | 6.45 | 9.16 | 2420 | 825 | JSON — usual Rust library | slower | yes | 87 |
| sonic-rs | 0.3.17 | 3.89 | 5.43 | 9.37 | 2420 | 825 | JSON — fast writer fast named JSON | slower | yes | 79 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.34 | 0.77 | 1.11 | 4143 | 702 | positional binary — no field names | fastest | yes | 86 |
| postcard | 1.1.3 | 0.84 | 1.31 | 2.16 | 4128 | 688 | postcard — compact Rust | slower | yes | 89 |
| prost | 0.13.5 | 0.88 | 2.01 | 2.92 | 4131 | 690 | Protocol Buffers | slower | yes | 90 |
| rmp-serde | 1.3.1 | 1.32 | 3.10 | 4.40 | 4677 | 776 | MessagePack | slower | yes | 87 |
| ciborium | 0.2.2 | 5.05 | 6.96 | 12.1 | 4677 | 774 | CBOR | slower | yes | 88 |
| serde_json | 1.0.154 | 8.91 | 19.5 | 28.5 | 9415 | 825 | JSON — usual Rust library | slower | yes | 81 |
| sonic-rs | 0.3.17 | 14.1 | 15.1 | 29.3 | 9415 | 825 | JSON — fast writer fast named JSON | slower | yes | 84 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| gld-kiln | 8 | 0.34 | 0.57 | 0.91 | copied |
| postcard | 8 | 0.47 | 0.58 | 1.04 | copied |
| prost | 8 | 0.43 | 0.67 | 1.10 | copied |
| rmp-serde | 8 | 0.54 | 1.34 | 1.86 | copied |
| sonic-rs | 8 | 0.90 | 2.03 | 2.95 | copied |
| ciborium | 8 | 1.45 | 1.78 | 3.23 | real |
| serde_json | 8 | 1.22 | 3.26 | 4.48 | real |
| gld-kiln | 32 | 0.36 | 0.58 | 0.94 | copied |
| postcard | 32 | 0.51 | 0.63 | 1.14 | copied |
| prost | 32 | 0.47 | 0.90 | 1.38 | copied |
| rmp-serde | 32 | 0.62 | 1.46 | 2.10 | copied |
| ciborium | 32 | 1.92 | 2.22 | 4.16 | real |
| sonic-rs | 32 | 1.53 | 2.80 | 4.33 | copied |
| serde_json | 32 | 1.81 | 5.55 | 7.42 | real |
| gld-kiln | 128 | 0.41 | 0.67 | 1.10 | copied |
| postcard | 128 | 0.61 | 0.86 | 1.49 | copied |
| prost | 128 | 0.57 | 1.35 | 1.93 | copied |
| rmp-serde | 128 | 0.82 | 1.81 | 2.62 | copied |
| ciborium | 128 | 3.47 | 3.41 | 6.88 | real |
| sonic-rs | 128 | 4.08 | 5.48 | 9.59 | copied |
| serde_json | 128 | 3.82 | 14.2 | 18.0 | real |
| gld-kiln | 512 | 0.66 | 0.85 | 1.54 | copied |
| postcard | 512 | 1.09 | 1.36 | 2.39 | copied |
| prost | 512 | 1.14 | 2.15 | 3.30 | copied |
| rmp-serde | 512 | 1.44 | 3.27 | 4.71 | copied |
| ciborium | 512 | 9.90 | 8.26 | 18.2 | real |
| sonic-rs | 512 | 14.4 | 15.1 | 29.3 | copied |
| serde_json | 512 | 11.9 | 47.8 | 59.9 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: `postcard`. Time/size front: `gld-kiln`, `postcard`.

**32 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

**128 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

**512 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

