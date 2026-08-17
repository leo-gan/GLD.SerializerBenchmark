# Experiment 13 results — rust

**Date:** 2026-08-17
**Raw file:** `experiments/13-ranking-accident/rust/logs/rust/2026-08-17-104805.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.54 | 0.99 | 1.50 | 460 | — | fast writer | fastest | yes | 95 |
| serde_json | 1.0.150 | 0.58 | 1.26 | 1.86 | 460 | — | usual Rust JSON library | slower | yes | 92 |
| simd-json | 0.14.3 | 0.59 | 1.58 | 2.22 | 460 | — | fast read; write is serde_json | slower | yes | 90 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 39.0 | 110 | 149 | 47101 | — | fast writer | fastest | yes | 88 |
| serde_json | 1.0.150 | 57.1 | 160 | 217 | 47101 | — | usual Rust JSON library | slower | yes | 90 |
| simd-json | 0.14.3 | 57.1 | 180 | 237 | 47101 | — | fast read; write is serde_json | slower | yes | 90 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.29 | 0.59 | 0.89 | 258 | — | fast writer | fastest | yes | 89 |
| serde_json | 1.0.150 | 0.34 | 0.82 | 1.18 | 258 | — | usual Rust JSON library | slower | yes | 91 |
| simd-json | 0.14.3 | 0.35 | 1.37 | 1.72 | 258 | — | fast read; write is serde_json | slower | yes | 93 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 17.5 | 83.9 | 102 | 26978 | — | fast writer | fastest | yes | 96 |
| serde_json | 1.0.150 | 33.8 | 115 | 149 | 26978 | — | usual Rust JSON library | slower | yes | 89 |
| simd-json | 0.14.3 | 34.0 | 148 | 182 | 26978 | — | fast read; write is serde_json | slower | yes | 91 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.23 | 0.33 | 0.56 | 182 | — | fast writer | fastest | yes | 96 |
| serde_json | 1.0.150 | 0.23 | 0.42 | 0.65 | 182 | — | usual Rust JSON library | slower | yes | 92 |
| simd-json | 0.14.3 | 0.24 | 0.62 | 0.86 | 182 | — | fast read; write is serde_json | slower | yes | 91 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 13.0 | 34.1 | 47.1 | 18070 | — | fast writer | fastest | yes | 76 |
| serde_json | 1.0.150 | 17.8 | 49.8 | 67.8 | 18070 | — | usual Rust JSON library | slower | yes | 89 |
| simd-json | 0.14.3 | 17.8 | 69.1 | 87.1 | 18070 | — | fast read; write is serde_json | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.25 | 1.22 | 1.47 | 390 | — | fast writer | fastest | yes | 96 |
| serde_json | 1.0.150 | 0.36 | 1.42 | 1.77 | 390 | — | usual Rust JSON library | slower | yes | 92 |
| simd-json | 0.14.3 | 0.36 | 2.18 | 2.54 | 390 | — | fast read; write is serde_json | slower | yes | 95 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 19.2 | 169 | 188 | 42750 | — | fast writer | fastest | yes | 87 |
| simd-json | 0.14.3 | 55.9 | 203 | 260 | 42750 | — | fast read; write is serde_json | slower | yes | 95 |
| serde_json | 1.0.150 | 55.6 | 241 | 297 | 42750 | — | usual Rust JSON library | slower | yes | 95 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.81 | 1.15 | 1.95 | 672 | — | fast writer | fastest | yes | 92 |
| serde_json | 1.0.150 | 0.71 | 1.31 | 2.03 | 672 | — | usual Rust JSON library | slower | yes | 76 |
| simd-json | 0.14.3 | 0.70 | 1.56 | 2.27 | 672 | — | fast read; write is serde_json | slower | yes | 78 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde_json | 1.0.150 | 67.9 | 148 | 216 | 67763 | — | usual Rust JSON library | fastest | yes | 95 |
| sonic-rs | 0.3.17 | 91.4 | 138 | 230 | 67763 | — | fast writer | slower | yes | 93 |
| simd-json | 0.14.3 | 69.9 | 165 | 235 | 67763 | — | fast read; write is serde_json | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`.

**sample A (order), N = 100, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`.

**sample D (event), N = 1, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`.

**sample D (event), N = 100, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`.

**sample B (flat), N = 1, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`.

**sample B (flat), N = 100, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`.

**sample E (words), N = 1, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`.

**sample E (words), N = 100, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`.

**sample C (sensor), N = 1, memory** — not clearly slower: `sonic-rs`. Small gap: —. Time/size front: `sonic-rs`.

**sample C (sensor), N = 100, memory** — not clearly slower: `serde_json`. Small gap: —. Time/size front: `serde_json`.

