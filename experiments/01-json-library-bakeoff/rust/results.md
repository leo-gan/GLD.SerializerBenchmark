# Experiment 1 results — rust

**Date:** 2026-08-16
**Raw file:** `experiments/01-json-library-bakeoff/rust/logs/rust/2026-08-16-150530.csv`
**Language:** rust
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.47 | 0.82 | 1.30 | 460 | — | yes | fastest | yes | 90 |
| serde_json | 1.0.150 | 0.52 | 1.10 | 1.63 | 460 | — | yes | slower | yes | 91 |
| simd-json | 0.14.3 | 0.52 | 1.45 | 1.97 | 460 | — | yes | slower | yes | 89 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| sonic-rs | 0.68 | 0.95 | 1.61 | copied |
| simd-json | 0.79 | 1.52 | 2.31 | copied |
| serde_json | 1.50 | 2.85 | 4.38 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `sonic-rs`.
**Not both slower and larger than another named-JSON library:** `sonic-rs`.

