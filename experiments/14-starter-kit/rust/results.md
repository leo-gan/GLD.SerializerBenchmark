# Experiment 14 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/14-starter-kit/rust/logs/rust/2026-09-29-185713.csv`
**Language:** rust
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.53 | 1.04 | 1.57 | 155 | 178 | yes | fastest | yes | 82 |
| rmp-serde | 1.3.1 | 0.58 | 1.69 | 2.27 | 333 | 231 | yes | slower | yes | 85 |
| sonic-rs | 0.3.17 | 0.71 | 1.88 | 2.62 | 460 | 237 | yes | slower | yes | 85 |
| serde_json | 1.0.151 | 0.76 | 2.20 | 2.98 | 460 | 237 | yes | slower | yes | 89 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| rmp-serde | 0.72 | 1.86 | 2.58 | copied |
| sonic-rs | 0.87 | 2.02 | 2.88 | copied |
| serde_json | 2.16 | 4.08 | 6.21 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `prost`.
**Not both slower and larger than another library in the kit:** `prost`.

