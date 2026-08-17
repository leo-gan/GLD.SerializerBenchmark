# Experiment 10 results — rust

**Date:** 2026-08-17
**Raw file:** `experiments/10-one-vs-hundred/rust/logs/rust/2026-08-17-110703.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rmp-serde | 1.3.1 | 0.15 | 0.50 | 0.68 | 197 | — | MessagePack | fastest | yes | 87 |
| sonic-rs | 0.3.17 | 0.28 | 0.55 | 0.82 | 258 | — | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| prost | 0.13.5 | 0.40 | 0.43 | 0.83 | 114 | — | Protocol Buffers | slower | yes | 84 |
| serde_json | 1.0.150 | 0.32 | 0.73 | 1.06 | 258 | — | JSON — usual Rust library | slower | yes | 86 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 15.9 | 79.8 | 95.4 | 26978 | — | JSON — fast writer from Experiment 1 | fastest | yes | 97 |
| rmp-serde | 1.3.1 | 13.8 | 86.3 | 100 | 20878 | — | MessagePack | slower | yes | 82 |
| prost | 0.13.5 | 40.9 | 70.6 | 112 | 12578 | — | Protocol Buffers | slower | yes | 82 |
| serde_json | 1.0.150 | 31.8 | 110 | 142 | 26978 | — | JSON — usual Rust library | slower | yes | 89 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.11 | 0.11 | 0.22 | 55 | — | Protocol Buffers | fastest | yes | 84 |
| rmp-serde | 1.3.1 | 0.13 | 0.21 | 0.35 | 136 | — | MessagePack | slower | yes | 89 |
| sonic-rs | 0.3.17 | 0.21 | 0.30 | 0.51 | 182 | — | JSON — fast writer from Experiment 1 | slower | yes | 92 |
| serde_json | 1.0.150 | 0.20 | 0.37 | 0.57 | 182 | — | JSON — usual Rust library | slower | yes | 93 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 8.59 | 17.0 | 25.6 | 5102 | — | Protocol Buffers | fastest | yes | 85 |
| rmp-serde | 1.3.1 | 5.86 | 29.9 | 35.9 | 13364 | — | MessagePack | slower | yes | 91 |
| sonic-rs | 0.3.17 | 11.9 | 31.4 | 43.5 | 18070 | — | JSON — fast writer from Experiment 1 | slower | yes | 82 |
| serde_json | 1.0.150 | 17.1 | 46.4 | 63.9 | 18070 | — | JSON — usual Rust library | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `rmp-serde`. Small gap: —. Time/size front: `rmp-serde`, `prost`.

**sample D (event), N = 100, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`, `rmp-serde`, `prost`.

**sample B (flat), N = 1, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

**sample B (flat), N = 100, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

