# Experiment 9 results — rust

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/rust/logs/rust/2026-11-12-100837.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.10 | 0.18 | 0.28 | 60 | 78 | positional binary — no field names | fastest | yes | 90 |
| prost | 0.13.5 | 0.14 | 0.35 | 0.49 | 55 | 76 | Protocol Buffers | slower | yes | 79 |
| rmp-serde | 1.3.1 | 0.22 | 0.78 | 1.00 | 136 | 139 | MessagePack | slower | yes | 82 |
| sonic-rs | 0.3.17 | 0.34 | 0.90 | 1.23 | 182 | 148 | JSON — fast writer fast named JSON | slower | yes | 81 |
| serde_json | 1.0.154 | 0.36 | 1.10 | 1.47 | 182 | 148 | JSON — usual Rust library | slower | yes | 86 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.38 | 0.93 | 1.32 | 403 | 278 | positional binary — no field names | fastest | yes | 86 |
| sonic-rs | 0.3.17 | 0.40 | 2.37 | 2.77 | 390 | 274 | JSON — fast writer fast named JSON | slower | yes | 83 |
| rmp-serde | 1.3.1 | 0.41 | 2.41 | 2.82 | 322 | 259 | MessagePack | slower | yes | 81 |
| prost | 0.13.5 | 0.59 | 2.37 | 2.95 | 335 | 253 | Protocol Buffers | slower | yes | 89 |
| serde_json | 1.0.154 | 0.60 | 3.10 | 3.71 | 390 | 274 | JSON — usual Rust library | slower | yes | 87 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.20 | 0.46 | 0.66 | 1066 | 1079 | positional binary — no field names | fastest | yes | 81 |
| prost | 0.13.5 | 0.37 | 1.07 | 1.44 | 1054 | 1067 | Protocol Buffers | slower | yes | 81 |
| rmp-serde | 1.3.1 | 0.56 | 1.39 | 1.98 | 1216 | 1173 | MessagePack | slower | yes | 83 |
| serde_json | 1.0.154 | 2.48 | 4.75 | 7.27 | 2420 | 1241 | JSON — usual Rust library | slower | yes | 82 |
| sonic-rs | 0.3.17 | 3.68 | 4.83 | 8.53 | 2420 | 1241 | JSON — fast writer fast named JSON | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `prost`.

**sample E (words), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `sonic-rs`, `rmp-serde`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `prost`.

