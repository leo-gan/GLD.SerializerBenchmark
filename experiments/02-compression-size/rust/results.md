# Experiment 9 results — rust

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/rust/logs/rust/2026-11-12-122319.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.08 | 0.15 | 0.24 | 60 | 78 | positional binary — no field names | fastest | yes | 78 |
| prost | 0.13.5 | 0.13 | 0.35 | 0.47 | 55 | 76 | Protocol Buffers | slower | yes | 79 |
| rmp-serde | 1.3.1 | 0.21 | 0.85 | 1.05 | 136 | 139 | MessagePack | slower | yes | 84 |
| sonic-rs | 0.3.17 | 0.31 | 0.98 | 1.28 | 182 | 148 | JSON — fast writer fast named JSON | slower | yes | 82 |
| serde_json | 1.0.154 | 0.38 | 1.13 | 1.51 | 182 | 148 | JSON — usual Rust library | slower | yes | 84 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.27 | 0.76 | 1.05 | 403 | 278 | positional binary — no field names | fastest | yes | 86 |
| rmp-serde | 1.3.1 | 0.32 | 1.94 | 2.25 | 322 | 259 | MessagePack | slower | yes | 85 |
| sonic-rs | 0.3.17 | 0.30 | 2.12 | 2.42 | 390 | 274 | JSON — fast writer fast named JSON | slower | yes | 86 |
| prost | 0.13.5 | 0.44 | 2.01 | 2.45 | 335 | 253 | Protocol Buffers | slower | yes | 85 |
| serde_json | 1.0.154 | 0.49 | 2.65 | 3.16 | 390 | 274 | JSON — usual Rust library | slower | yes | 88 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.15 | 0.39 | 0.56 | 1066 | 1079 | positional binary — no field names | fastest | yes | 82 |
| prost | 0.13.5 | 0.31 | 1.03 | 1.35 | 1054 | 1067 | Protocol Buffers | slower | yes | 81 |
| rmp-serde | 1.3.1 | 0.47 | 1.21 | 1.67 | 1216 | 1173 | MessagePack | slower | yes | 77 |
| serde_json | 1.0.154 | 2.19 | 4.50 | 6.72 | 2420 | 1241 | JSON — usual Rust library | slower | yes | 79 |
| sonic-rs | 0.3.17 | 3.35 | 4.30 | 7.65 | 2420 | 1241 | JSON — fast writer fast named JSON | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `prost`.

**sample E (words), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `rmp-serde`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `prost`.

