# Experiment 1 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/01-json-library-bakeoff/rust/logs/rust/2026-09-29-184051.csv`
**Language:** rust
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| sonic-rs | 0.3.17 | 0.70 | 1.94 | 2.66 | 460 | 237 | yes | fastest | yes | 82 |
| serde_json | 1.0.151 | 0.81 | 2.40 | 3.22 | 460 | 237 | yes | slower | yes | 89 |
| simd-json | 0.14.3 | 0.84 | 2.91 | 3.75 | 460 | 237 | yes | slower | yes | 88 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| sonic-rs | 0.93 | 2.03 | 2.98 | copied |
| simd-json | 1.14 | 2.79 | 3.91 | copied |
| serde_json | 2.25 | 4.06 | 6.37 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `sonic-rs`.
**Not both slower and larger than another named-JSON library:** `sonic-rs`.

