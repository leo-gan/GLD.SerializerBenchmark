# Experiment 10 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/10-one-vs-hundred/rust/logs/rust/2026-09-29-184733.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.32 | 0.77 | 1.09 | 114 | 2169 | Protocol Buffers | fastest | yes | 87 |
| rmp-serde | 1.3.1 | 0.31 | 1.29 | 1.61 | 197 | 2384 | MessagePack | slower | yes | 87 |
| sonic-rs | 0.3.17 | 0.39 | 1.26 | 1.64 | 258 | 2614 | JSON — fast writer from Experiment 1 | slower | yes | 86 |
| serde_json | 1.0.151 | 0.45 | 1.63 | 2.06 | 258 | 2614 | JSON — usual Rust library | slower | yes | 84 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 24.2 | 60.8 | 84.9 | 12578 | 2169 | Protocol Buffers | fastest | yes | 86 |
| sonic-rs | 0.3.17 | 16.8 | 73.0 | 89.6 | 26978 | 2614 | JSON — fast writer from Experiment 1 | close | yes | 87 |
| rmp-serde | 1.3.1 | 14.3 | 79.3 | 93.7 | 20878 | 2384 | MessagePack | slower | yes | 82 |
| serde_json | 1.0.151 | 32.4 | 104 | 136 | 26978 | 2614 | JSON — usual Rust library | slower | yes | 79 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.17 | 0.32 | 0.49 | 55 | 2169 | Protocol Buffers | fastest | yes | 80 |
| rmp-serde | 1.3.1 | 0.19 | 0.72 | 0.92 | 136 | 2384 | MessagePack | slower | yes | 82 |
| sonic-rs | 0.3.17 | 0.30 | 0.89 | 1.20 | 182 | 2614 | JSON — fast writer from Experiment 1 | slower | yes | 79 |
| serde_json | 1.0.151 | 0.34 | 1.02 | 1.38 | 182 | 2614 | JSON — usual Rust library | slower | yes | 78 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| prost | 0.13.5 | 6.80 | 16.6 | 23.3 | 5102 | 2169 | Protocol Buffers | fastest | yes | 95 |
| rmp-serde | 1.3.1 | 6.16 | 32.0 | 38.1 | 13364 | 2384 | MessagePack | slower | yes | 90 |
| sonic-rs | 0.3.17 | 12.3 | 31.9 | 44.5 | 18070 | 2614 | JSON — fast writer from Experiment 1 | slower | yes | 93 |
| serde_json | 1.0.151 | 16.9 | 49.9 | 66.9 | 18070 | 2614 | JSON — usual Rust library | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

**sample D (event), N = 100, memory** — not clearly slower: `prost`. Small gap: `sonic-rs`. Time/size front: `prost`.

**sample B (flat), N = 1, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

**sample B (flat), N = 100, memory** — not clearly slower: `prost`. Small gap: —. Time/size front: `prost`.

