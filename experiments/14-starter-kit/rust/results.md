# Experiment 14 results — rust

**Date:** 2026-08-29
**Raw file:** `experiments/14-starter-kit/rust/logs/rust/2026-08-28-182241.csv`
**Language:** rust
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| prost | 0.13.5 | 0.47 | 0.97 | 1.43 | 155 | 178 | yes | fastest | yes | 86 |
| rmp-serde | 1.3.1 | 0.49 | 1.49 | 1.96 | 333 | 231 | yes | slower | yes | 91 |
| sonic-rs | 0.3.17 | 0.60 | 1.64 | 2.23 | 460 | 237 | yes | slower | yes | 91 |
| serde_json | 1.0.150 | 0.67 | 2.06 | 2.74 | 460 | 237 | yes | slower | yes | 89 |

## Stream call (side note)

| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|------------|-----------|-------------------|---------------------------|
| rmp-serde | 0.60 | 1.59 | 2.19 | copied |
| sonic-rs | 0.75 | 1.71 | 2.47 | copied |
| serde_json | 1.93 | 3.61 | 5.55 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `prost`.
**Not both slower and larger than another library in the kit:** `prost`.

