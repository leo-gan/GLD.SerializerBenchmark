# Experiment 13 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/13-ranking-accident/rust/logs/rust/2026-09-29-185645.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.68 | 1.96 | 2.63 | 460 | 2732 | fast writer | fastest | yes | 91 |
| serde_json | 1.0.151 | 0.80 | 2.37 | 3.18 | 460 | 2732 | usual Rust JSON library | slower | yes | 88 |
| simd-json | 0.14.3 | 0.80 | 2.89 | 3.67 | 460 | 2732 | fast read; write is serde_json | slower | yes | 83 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 37.4 | 98.4 | 136 | 47101 | 2732 | fast writer | fastest | yes | 90 |
| serde_json | 1.0.151 | 53.3 | 142 | 195 | 47101 | 2732 | usual Rust JSON library | slower | yes | 83 |
| simd-json | 0.14.3 | 53.8 | 160 | 214 | 47101 | 2732 | fast read; write is serde_json | slower | yes | 87 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.39 | 1.27 | 1.66 | 258 | 2732 | fast writer | fastest | yes | 89 |
| serde_json | 1.0.151 | 0.44 | 1.57 | 2.00 | 258 | 2732 | usual Rust JSON library | slower | yes | 87 |
| simd-json | 0.14.3 | 0.44 | 1.83 | 2.29 | 258 | 2732 | fast read; write is serde_json | slower | yes | 89 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 17.0 | 71.1 | 88.6 | 26978 | 2732 | fast writer | fastest | yes | 90 |
| serde_json | 1.0.151 | 32.6 | 103 | 136 | 26978 | 2732 | usual Rust JSON library | slower | yes | 92 |
| simd-json | 0.14.3 | 31.9 | 133 | 165 | 26978 | 2732 | fast read; write is serde_json | slower | yes | 90 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.27 | 0.75 | 1.02 | 182 | 2732 | fast writer | fastest | yes | 88 |
| serde_json | 1.0.151 | 0.31 | 0.86 | 1.18 | 182 | 2732 | usual Rust JSON library | slower | yes | 88 |
| simd-json | 0.14.3 | 0.32 | 1.34 | 1.64 | 182 | 2732 | fast read; write is serde_json | slower | yes | 87 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 12.6 | 31.9 | 44.4 | 18070 | 2732 | fast writer | fastest | yes | 91 |
| serde_json | 1.0.151 | 17.1 | 49.0 | 66.2 | 18070 | 2732 | usual Rust JSON library | slower | yes | 93 |
| simd-json | 0.14.3 | 17.1 | 72.1 | 89.4 | 18070 | 2732 | fast read; write is serde_json | slower | yes | 85 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.29 | 1.89 | 2.18 | 390 | 2732 | fast writer | fastest | yes | 82 |
| serde_json | 1.0.151 | 0.44 | 2.36 | 2.80 | 390 | 2732 | usual Rust JSON library | slower | yes | 85 |
| simd-json | 0.14.3 | 0.45 | 2.53 | 2.99 | 390 | 2732 | fast read; write is serde_json | slower | yes | 84 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 17.8 | 138 | 156 | 42750 | 2732 | fast writer | fastest | yes | 92 |
| simd-json | 0.14.3 | 56.8 | 170 | 226 | 42750 | 2732 | fast read; write is serde_json | slower | yes | 87 |
| serde_json | 1.0.151 | 56.2 | 203 | 259 | 42750 | 2732 | usual Rust JSON library | slower | yes | 89 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde_json | 1.0.151 | 0.80 | 1.80 | 2.65 | 672 | 2732 | usual Rust JSON library | fastest | yes | 92 |
| sonic-rs | 0.3.17 | 1.01 | 1.71 | 2.73 | 672 | 2732 | fast writer | close | yes | 88 |
| simd-json | 0.14.3 | 0.79 | 2.47 | 3.27 | 672 | 2732 | fast read; write is serde_json | slower | yes | 90 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde_json | 1.0.151 | 61.9 | 140 | 203 | 67763 | 2732 | usual Rust JSON library | fastest | yes | 88 |
| sonic-rs | 0.3.17 | 89.4 | 134 | 225 | 67763 | 2732 | fast writer | slower | yes | 88 |
| simd-json | 0.14.3 | 61.5 | 166 | 228 | 67763 | 2732 | fast read; write is serde_json | slower | yes | 84 |

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

**sample C (sensor), N = 1, memory** — not clearly slower: `serde_json`. Small gap: `sonic-rs`. Time/size front: `serde_json`.

**sample C (sensor), N = 100, memory** — not clearly slower: `serde_json`. Small gap: —. Time/size front: `serde_json`.

