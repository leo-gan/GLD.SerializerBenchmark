# Experiment 9 results — rust

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/rust/logs/rust/2026-11-12-163746.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.12 | 0.24 | 0.36 | 60 | 78 | positional binary — no field names | fastest | yes | 84 |
| prost | 0.13.5 | 0.18 | 0.46 | 0.65 | 55 | 76 | Protocol Buffers | slower | yes | 83 |
| rmp-serde | 1.3.1 | 0.30 | 1.31 | 1.66 | 136 | 139 | MessagePack | slower | yes | 83 |
| sonic-rs | 0.3.17 | 0.46 | 1.48 | 1.93 | 182 | 148 | JSON — fast writer fast named JSON | slower | yes | 80 |
| serde_json | 1.0.154 | 0.50 | 1.71 | 2.21 | 182 | 148 | JSON — usual Rust library | slower | yes | 83 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.32 | 0.94 | 1.24 | 403 | 278 | positional binary — no field names | fastest | yes | 82 |
| rmp-serde | 1.3.1 | 0.42 | 2.31 | 2.75 | 322 | 259 | MessagePack | slower | yes | 88 |
| prost | 0.13.5 | 0.59 | 2.19 | 2.77 | 335 | 253 | Protocol Buffers | slower | yes | 85 |
| sonic-rs | 0.3.17 | 0.36 | 2.49 | 2.87 | 390 | 274 | JSON — fast writer fast named JSON | slower | yes | 85 |
| serde_json | 1.0.154 | 0.63 | 3.01 | 3.68 | 390 | 274 | JSON — usual Rust library | slower | yes | 87 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.23 | 0.48 | 0.71 | 1066 | 1079 | positional binary — no field names | fastest | yes | 83 |
| prost | 0.13.5 | 0.39 | 1.17 | 1.58 | 1054 | 1067 | Protocol Buffers | slower | yes | 82 |
| rmp-serde | 1.3.1 | 0.57 | 1.64 | 2.19 | 1216 | 1173 | MessagePack | slower | yes | 82 |
| serde_json | 1.0.154 | 2.47 | 6.31 | 8.89 | 2420 | 1241 | JSON — usual Rust library | slower | yes | 83 |
| sonic-rs | 0.3.17 | 3.82 | 5.18 | 8.98 | 2420 | 1241 | JSON — fast writer fast named JSON | slower | yes | 83 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `prost`.

**sample E (words), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `rmp-serde`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `prost`.

