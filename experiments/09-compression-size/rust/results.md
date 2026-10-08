# Experiment 9 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/09-compression-size/rust/logs/rust/2026-09-29-184525.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.17 | 0.33 | 0.50 | 55 | 78 | Protocol Buffers | fastest | yes | 82 |
| rmp-serde | 1.3.1 | 0.20 | 0.72 | 0.92 | 136 | 151 | MessagePack | slower | yes | 84 |
| sonic-rs | 0.3.17 | 0.30 | 0.86 | 1.19 | 182 | 148 | JSON — fast writer from Experiment 1 | slower | yes | 83 |
| serde_json | 1.0.151 | 0.34 | 0.95 | 1.28 | 182 | 148 | JSON — usual Rust library | slower | yes | 84 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rmp-serde | 1.3.1 | 0.38 | 1.77 | 2.15 | 322 | 259 | MessagePack | fastest | yes | 81 |
| sonic-rs | 0.3.17 | 0.34 | 1.91 | 2.25 | 390 | 270 | JSON — fast writer from Experiment 1 | close | yes | 81 |
| prost | 0.13.5 | 0.53 | 1.89 | 2.42 | 335 | 256 | Protocol Buffers | slower | yes | 84 |
| serde_json | 1.0.151 | 0.46 | 2.42 | 2.87 | 390 | 270 | JSON — usual Rust library | slower | yes | 88 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.35 | 1.10 | 1.48 | 1054 | 1068 | Protocol Buffers | fastest | yes | 83 |
| rmp-serde | 1.3.1 | 0.53 | 1.37 | 1.89 | 1216 | 1174 | MessagePack | slower | yes | 84 |
| serde_json | 1.0.151 | 2.39 | 4.83 | 7.22 | 2420 | 1335 | JSON — usual Rust library | slower | yes | 83 |
| sonic-rs | 0.3.17 | 3.76 | 4.74 | 8.48 | 2420 | 1335 | JSON — fast writer from Experiment 1 | slower | yes | 83 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

**sample E (words), N = 1, memory** — not clearly slower: `rmp-serde`. Small gap: `sonic-rs`. Time/size front: `rmp-serde`.

**sample C (sensor), N = 1, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

