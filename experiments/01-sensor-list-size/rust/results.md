# Experiment 4 results — rust

**Date:** 2026-11-12
**Raw file:** `experiments/01-sensor-list-size/rust/logs/rust/2026-11-12-122311.csv`
**Language:** rust
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.13 | 0.34 | 0.47 | 107 | 702 | positional binary — no field names | fastest | yes | 78 |
| postcard | 1.1.3 | 0.19 | 0.36 | 0.56 | 91 | 688 | postcard — compact Rust | slower | yes | 82 |
| prost | 0.13.5 | 0.20 | 0.47 | 0.67 | 94 | 690 | Protocol Buffers | slower | yes | 80 |
| rmp-serde | 1.3.1 | 0.27 | 0.74 | 1.02 | 135 | 776 | MessagePack | slower | yes | 83 |
| sonic-rs | 0.3.17 | 0.50 | 1.22 | 1.72 | 234 | 825 | JSON — fast writer fast named JSON | slower | yes | 80 |
| serde_json | 1.0.154 | 0.45 | 1.28 | 1.74 | 234 | 825 | JSON — usual Rust library | slower | yes | 85 |
| ciborium | 0.2.2 | 0.44 | 1.34 | 1.80 | 135 | 774 | CBOR | slower | yes | 81 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.14 | 0.34 | 0.48 | 302 | 702 | positional binary — no field names | fastest | yes | 75 |
| postcard | 1.1.3 | 0.22 | 0.41 | 0.63 | 286 | 688 | postcard — compact Rust | slower | yes | 85 |
| prost | 0.13.5 | 0.23 | 0.67 | 0.90 | 290 | 690 | Protocol Buffers | slower | yes | 79 |
| rmp-serde | 1.3.1 | 0.29 | 0.89 | 1.20 | 356 | 776 | MessagePack | slower | yes | 82 |
| ciborium | 0.2.2 | 0.68 | 1.56 | 2.23 | 355 | 774 | CBOR | slower | yes | 83 |
| serde_json | 1.0.154 | 0.85 | 2.00 | 2.89 | 672 | 825 | JSON — usual Rust library | slower | yes | 79 |
| sonic-rs | 0.3.17 | 1.05 | 1.93 | 3.00 | 672 | 825 | JSON — fast writer fast named JSON | slower | yes | 84 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.16 | 0.39 | 0.55 | 1066 | 702 | positional binary — no field names | fastest | yes | 74 |
| postcard | 1.1.3 | 0.34 | 0.56 | 0.90 | 1051 | 688 | postcard — compact Rust | slower | yes | 79 |
| prost | 0.13.5 | 0.30 | 0.98 | 1.29 | 1054 | 690 | Protocol Buffers | slower | yes | 81 |
| rmp-serde | 1.3.1 | 0.47 | 1.18 | 1.67 | 1216 | 776 | MessagePack | slower | yes | 81 |
| ciborium | 0.2.2 | 1.47 | 2.51 | 3.95 | 1215 | 774 | CBOR | slower | yes | 81 |
| serde_json | 1.0.154 | 2.16 | 4.43 | 6.55 | 2420 | 825 | JSON — usual Rust library | slower | yes | 80 |
| sonic-rs | 0.3.17 | 3.27 | 4.27 | 7.55 | 2420 | 825 | JSON — fast writer fast named JSON | slower | yes | 84 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.33 | 0.68 | 1.08 | 4143 | 702 | positional binary — no field names | fastest | yes | 85 |
| postcard | 1.1.3 | 0.81 | 1.25 | 2.09 | 4128 | 688 | postcard — compact Rust | slower | yes | 91 |
| prost | 0.13.5 | 0.92 | 1.94 | 2.84 | 4131 | 690 | Protocol Buffers | slower | yes | 88 |
| rmp-serde | 1.3.1 | 1.12 | 2.80 | 3.88 | 4677 | 776 | MessagePack | slower | yes | 87 |
| ciborium | 0.2.2 | 4.83 | 6.98 | 11.6 | 4677 | 774 | CBOR | slower | yes | 87 |
| serde_json | 1.0.154 | 8.28 | 14.5 | 22.9 | 9415 | 825 | JSON — usual Rust library | slower | yes | 88 |
| sonic-rs | 0.3.17 | 13.0 | 14.4 | 27.5 | 9415 | 825 | JSON — fast writer fast named JSON | slower | yes | 90 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| gld-kiln | 8 | 0.23 | 0.33 | 0.56 | copied |
| postcard | 8 | 0.29 | 0.35 | 0.64 | copied |
| prost | 8 | 0.29 | 0.49 | 0.78 | copied |
| rmp-serde | 8 | 0.35 | 0.75 | 1.10 | copied |
| sonic-rs | 8 | 0.60 | 1.26 | 1.86 | copied |
| ciborium | 8 | 0.84 | 1.37 | 2.21 | real |
| serde_json | 8 | 0.86 | 2.25 | 3.11 | real |
| gld-kiln | 32 | 0.23 | 0.36 | 0.60 | copied |
| postcard | 32 | 0.34 | 0.47 | 0.82 | copied |
| prost | 32 | 0.35 | 0.73 | 1.07 | copied |
| rmp-serde | 32 | 0.44 | 0.89 | 1.33 | copied |
| ciborium | 32 | 1.29 | 1.76 | 3.04 | real |
| sonic-rs | 32 | 1.20 | 2.04 | 3.23 | copied |
| serde_json | 32 | 1.46 | 4.36 | 5.84 | real |
| gld-kiln | 128 | 0.28 | 0.47 | 0.77 | copied |
| postcard | 128 | 0.49 | 0.75 | 1.25 | copied |
| prost | 128 | 0.45 | 1.15 | 1.59 | copied |
| rmp-serde | 128 | 0.61 | 1.40 | 2.03 | copied |
| ciborium | 128 | 2.87 | 2.93 | 5.79 | real |
| sonic-rs | 128 | 3.54 | 4.64 | 8.24 | copied |
| serde_json | 128 | 3.28 | 11.7 | 15.1 | real |
| gld-kiln | 512 | 0.49 | 0.63 | 1.12 | copied |
| postcard | 512 | 0.90 | 1.27 | 2.13 | copied |
| prost | 512 | 0.90 | 2.03 | 2.93 | copied |
| rmp-serde | 512 | 1.24 | 2.67 | 3.89 | copied |
| ciborium | 512 | 9.21 | 7.33 | 16.6 | real |
| sonic-rs | 512 | 13.2 | 13.9 | 27.1 | copied |
| serde_json | 512 | 10.9 | 40.7 | 52.0 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

**32 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

**128 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

**512 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `postcard`.

