# Experiment 9 results — rust

**Date:** 2026-08-17
**Raw file:** `experiments/09-compression-size/rust/logs/rust/2026-08-17-115851.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.65 | 0.76 | 1.36 | 55 | 78 | Protocol Buffers | fastest | yes | 94 |
| rmp-serde | 1.3.1 | 0.68 | 2.11 | 2.70 | 136 | 151 | MessagePack | slower | yes | 96 |
| serde_json | 1.0.150 | 0.70 | 2.27 | 3.06 | 182 | 148 | JSON — usual Rust library | slower | yes | 92 |
| sonic-rs | 0.3.17 | 1.24 | 3.08 | 4.36 | 182 | 148 | JSON — fast writer from Experiment 1 | slower | yes | 96 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rmp-serde | 1.3.1 | 0.29 | 1.67 | 1.96 | 322 | 259 | MessagePack | fastest | yes | 90 |
| sonic-rs | 0.3.17 | 0.28 | 1.69 | 1.98 | 390 | 270 | JSON — fast writer from Experiment 1 | similar | yes | 89 |
| serde_json | 1.0.150 | 0.42 | 2.21 | 2.64 | 390 | 270 | JSON — usual Rust library | slower | yes | 89 |
| prost | 0.13.5 | 1.50 | 1.67 | 3.20 | 335 | 256 | Protocol Buffers | slower | yes | 91 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.44 | 0.82 | 1.26 | 1054 | 1068 | Protocol Buffers | fastest | yes | 94 |
| rmp-serde | 1.3.1 | 0.36 | 0.90 | 1.26 | 1216 | 1174 | MessagePack | similar | yes | 89 |
| serde_json | 1.0.150 | 2.21 | 3.91 | 6.12 | 2420 | 1335 | JSON — usual Rust library | slower | yes | 90 |
| sonic-rs | 0.3.17 | 3.25 | 3.98 | 7.22 | 2420 | 1335 | JSON — fast writer from Experiment 1 | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

**sample E (words), N = 1, memory** — not clearly slower: `rmp-serde`, `sonic-rs`. Small gap: —. Time/size front: `rmp-serde`.

**sample C (sensor), N = 1, memory** — not clearly slower: `prost`, `rmp-serde`. Small gap: —. Time/size front: `prost`.

